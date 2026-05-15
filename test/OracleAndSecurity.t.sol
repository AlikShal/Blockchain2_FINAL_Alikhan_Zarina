// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../src/PriceOracle.sol";
import "../src/mocks/MockV3Aggregator.sol";

contract VulnerableAccessControl {
    address public admin;
    uint256 public privilegedValue;

    constructor() {
        admin = msg.sender;
    }

    function setAdmin(address newAdmin) external {
        admin = newAdmin;
    }

    function setPrivilegedValue(uint256 newValue) external {
        require(msg.sender == admin, "VulnerableAccessControl: not admin");
        privilegedValue = newValue;
    }
}

contract HardenedAccessControl is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public privilegedValue;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
    }

    function setPrivilegedValue(uint256 newValue) external onlyRole(OPERATOR_ROLE) {
        privilegedValue = newValue;
    }
}

contract VulnerableEtherVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "VulnerableEtherVault: empty");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "VulnerableEtherVault: send failed");
        balances[msg.sender] = 0;
    }
}

contract HardenedEtherVault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "HardenedEtherVault: empty");
        balances[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "HardenedEtherVault: send failed");
    }
}

contract ReentrancyAttacker {
    VulnerableEtherVault public vulnerableVault;
    HardenedEtherVault public hardenedVault;
    uint256 public calls;
    bool public attackHardened;

    constructor(VulnerableEtherVault vulnerableVault_, HardenedEtherVault hardenedVault_) {
        vulnerableVault = vulnerableVault_;
        hardenedVault = hardenedVault_;
    }

    function attackVulnerable() external payable {
        vulnerableVault.deposit{value: msg.value}();
        vulnerableVault.withdraw();
    }

    function attackHardenedVault() external payable {
        attackHardened = true;
        hardenedVault.deposit{value: msg.value}();
        hardenedVault.withdraw();
    }

    receive() external payable {
        calls++;
        if (attackHardened) {
            if (calls < 2) hardenedVault.withdraw();
        } else if (calls < 4 && address(vulnerableVault).balance >= 1 ether) {
            vulnerableVault.withdraw();
        }
    }
}

contract OracleAndSecurityTest is Test {
    MockV3Aggregator public feed;
    PriceOracle public oracle;

    function setUp() public {
        feed = new MockV3Aggregator(8, 2_000e8);
        oracle = new PriceOracle(address(feed), 1 hours);
    }

    function testOracleReturnsFreshPrice() public view {
        (int256 price, uint8 decimals, uint256 updatedAt) = oracle.latestPrice();
        assertEq(price, 2_000e8);
        assertEq(decimals, 8);
        assertEq(updatedAt, block.timestamp);
    }

    function testOracleRejectsStalePrice() public {
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.StalePrice.selector, uint256(1), uint256(7201)));
        oracle.latestPrice();
    }

    function testOracleRejectsNegativePrice() public {
        feed.updateAnswer(-1);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.latestPrice();
    }

    function testOracleRejectsIncompleteRound() public {
        feed.setRoundData(10, 2_000e8, block.timestamp, block.timestamp, 9);
        vm.expectRevert(abi.encodeWithSelector(PriceOracle.IncompleteRound.selector, uint80(10), uint80(9)));
        oracle.latestPrice();
    }

    function testVulnerableAccessControlCanBeTakenOver() public {
        VulnerableAccessControl vulnerable = new VulnerableAccessControl();
        address attacker = address(0xBAD);

        vm.prank(attacker);
        vulnerable.setAdmin(attacker);
        vm.prank(attacker);
        vulnerable.setPrivilegedValue(99);

        assertEq(vulnerable.admin(), attacker);
        assertEq(vulnerable.privilegedValue(), 99);
    }

    function testHardenedAccessControlBlocksUnauthorizedUser() public {
        HardenedAccessControl hardened = new HardenedAccessControl(address(this));
        vm.prank(address(0xBAD));
        vm.expectRevert();
        hardened.setPrivilegedValue(99);
    }

    function testHardenedAccessControlAllowsOperator() public {
        HardenedAccessControl hardened = new HardenedAccessControl(address(this));
        hardened.grantRole(hardened.OPERATOR_ROLE(), address(0xB0B));
        vm.prank(address(0xB0B));
        hardened.setPrivilegedValue(11);
        assertEq(hardened.privilegedValue(), 11);
    }

    function testReentrancyCaseStudyDrainsVulnerableVault() public {
        VulnerableEtherVault vulnerable = new VulnerableEtherVault();
        HardenedEtherVault hardened = new HardenedEtherVault();
        ReentrancyAttacker attacker = new ReentrancyAttacker(vulnerable, hardened);

        vulnerable.deposit{value: 5 ether}();
        uint256 attackerBefore = address(attacker).balance;
        attacker.attackVulnerable{value: 1 ether}();

        assertGt(address(attacker).balance, attackerBefore + 1 ether);
        assertLt(address(vulnerable).balance, 5 ether);
    }

    function testReentrancyCaseStudyHardenedVaultRevertsAttack() public {
        VulnerableEtherVault vulnerable = new VulnerableEtherVault();
        HardenedEtherVault hardened = new HardenedEtherVault();
        ReentrancyAttacker attacker = new ReentrancyAttacker(vulnerable, hardened);

        hardened.deposit{value: 5 ether}();
        vm.expectRevert();
        attacker.attackHardenedVault{value: 1 ether}();
    }
}
