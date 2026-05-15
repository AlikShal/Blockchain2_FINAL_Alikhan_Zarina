// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/Governance.sol";

contract TimelockTarget {
    uint256 public value;

    function store(uint256 newValue) external {
        value = newValue;
    }
}

contract GovernanceTokenTest is Test {
    GovernanceToken public govToken;
    ProtocolGovernor public governor;
    TimelockController public timelock;
    TimelockTarget public target;

    address public user1;
    address public user2;

    function setUp() public {
        user1 = address(0x1);
        user2 = address(0x2);

        govToken = new GovernanceToken();

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(2 days, proposers, executors, address(this));
        governor = new ProtocolGovernor(govToken, timelock);
        target = new TimelockTarget();

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        assertTrue(govToken.transfer(user1, 100_000 * 10 ** 18));
        assertTrue(govToken.transfer(user2, 50_000 * 10 ** 18));
    }

    function testDelegateCreatesVotingPower() public {
        vm.prank(user1);
        govToken.delegate(user1);

        assertEq(govToken.getVotes(user1), 100_000 * 10 ** 18);
    }

    function testPermitDomainHasNonces() public view {
        assertEq(govToken.nonces(user1), 0);
    }

    function testOwnerCanMintWithinMaxSupply() public {
        govToken.mint(user1, 1_000 * 10 ** 18);
        assertEq(govToken.balanceOf(user1), 101_000 * 10 ** 18);
    }

    function testMintCannotExceedMaxSupply() public {
        uint256 excessiveAmount = govToken.MAX_SUPPLY();
        vm.expectRevert(bytes("GovernanceToken: max supply"));
        govToken.mint(user1, excessiveAmount);
    }

    function testGovernorParameters() public view {
        assertEq(governor.name(), "ProtocolGovernor");
        assertEq(governor.votingDelay(), governor.VOTING_DELAY_BLOCKS());
        assertEq(governor.votingPeriod(), governor.VOTING_PERIOD_BLOCKS());
        assertEq(governor.proposalThreshold(), governor.PROPOSAL_THRESHOLD());
        assertEq(governor.quorumNumerator(), governor.QUORUM_PERCENT());
        assertTrue(governor.supportsInterface(0x01ffc9a7));
    }

    function testTimelockDelayMatchesSpec() public view {
        assertEq(timelock.getMinDelay(), 2 days);
    }

    function testGovernorOwnsTimelockRoles() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.CANCELLER_ROLE(), address(governor)));
    }

    function testProposalThresholdMatchesOnePercentOfInitialSupply() public view {
        assertEq(governor.proposalThreshold(), 10_000 * 10 ** 18);
    }

    function testNonOwnerCannotMintGovernanceToken() public {
        vm.prank(user1);
        vm.expectRevert();
        govToken.mint(user1, 1 ether);
    }

    function testFullGovernorTimelockExecution() public {
        vm.prank(user1);
        govToken.delegate(user1);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(target);
        calldatas[0] = abi.encodeCall(TimelockTarget.store, (42));
        string memory description = "store value";

        vm.prank(user1);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(user1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(target.value(), 42);
    }

    function testGovernorRejectsBeforeVotingStarts() public {
        vm.prank(user1);
        govToken.delegate(user1);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(target);
        calldatas[0] = abi.encodeCall(TimelockTarget.store, (7));

        vm.prank(user1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "early vote");

        vm.prank(user1);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }
}
