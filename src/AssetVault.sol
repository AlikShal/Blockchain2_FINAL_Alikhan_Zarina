// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AssetToken.sol";

contract AssetVault is ERC4626, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    AssetToken public immutable assetToken;

    uint256 public totalDeposited;
    uint256 public constant RESERVE_RATIO = 100;

    mapping(address => uint256) public userDeposits;

    event DepositRecorded(address indexed user, uint256 amount);
    event WithdrawalRecorded(address indexed user, uint256 amount);
    event TokensMinted(address indexed user, uint256 amount);

    constructor(address backingAsset_, address assetToken_)
        ERC20("Reserve Vault Share", "rvASSET")
        ERC4626(IERC20(backingAsset_))
    {
        require(backingAsset_ != address(0), "AssetVault: backing zero");
        require(assetToken_ != address(0), "AssetVault: token zero");
        assetToken = AssetToken(assetToken_);
    }

    function backingAsset() external view returns (IERC20) {
        return IERC20(asset());
    }

    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        shares = _depositReserve(_msgSender(), amount);
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256 shares) {
        shares = _depositReserve(receiver, assets);
    }

    // slither-disable-next-line reentrancy-benign
    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256 assets) {
        assets = previewMint(shares);
        require(assets > 0, "AssetVault: zero assets");
        super.mint(shares, receiver);
        _recordDeposit(receiver, assets);
        assetToken.mint(receiver, assets);
        emit TokensMinted(receiver, assets);
    }

    function withdraw(uint256 amount) external nonReentrant returns (uint256 shares) {
        shares = _withdrawReserve(_msgSender(), _msgSender(), amount);
    }

    function withdraw(uint256 assets, address receiver, address owner_)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        shares = _withdrawReserve(receiver, owner_, assets);
    }

    // slither-disable-next-line reentrancy-benign
    function redeem(uint256 shares, address receiver, address owner_)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        assets = previewRedeem(shares);
        require(assets > 0, "AssetVault: zero assets");
        _burnAssetToken(owner_, assets);
        super.redeem(shares, receiver, owner_);
        _recordWithdrawal(owner_, assets);
    }

    function getReserveRatio() public view returns (uint256) {
        if (totalDeposited < 1) return 0;
        return (totalAssets() * 100) / totalDeposited;
    }

    function isHealthy() external view returns (bool) {
        return getReserveRatio() >= RESERVE_RATIO;
    }

    // slither-disable-next-line reentrancy-benign
    function _depositReserve(address receiver, uint256 assets) internal returns (uint256 shares) {
        require(assets > 0, "AssetVault: zero assets");
        shares = super.deposit(assets, receiver);
        _recordDeposit(receiver, assets);
        assetToken.mint(receiver, assets);
        emit TokensMinted(receiver, assets);
    }

    // slither-disable-next-line reentrancy-eth, reentrancy-benign
    function _withdrawReserve(address receiver, address owner_, uint256 assets) internal returns (uint256 shares) {
        require(assets > 0, "AssetVault: zero assets");
        require(userDeposits[owner_] >= assets, "AssetVault: insufficient deposit");
        _burnAssetToken(owner_, assets);
        // slither-disable-next-line reentrancy-benign
        shares = super.withdraw(assets, receiver, owner_);
        _recordWithdrawal(owner_, assets);
    }

    function _recordDeposit(address receiver, uint256 assets) internal {
        userDeposits[receiver] += assets;
        totalDeposited += assets;
        emit DepositRecorded(receiver, assets);
    }

    function _recordWithdrawal(address owner_, uint256 assets) internal {
        userDeposits[owner_] -= assets;
        totalDeposited -= assets;
        emit WithdrawalRecorded(owner_, assets);
    }

    function _burnAssetToken(address owner_, uint256 assets) internal {
        assetToken.burnBackingFrom(owner_, assets);
    }
}
