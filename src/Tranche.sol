/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Owned } from "../lib/solmate/src/auth/Owned.sol";
import { ERC4626 } from "../lib/solmate/src/mixins/ERC4626.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ITranche } from "./interfaces/ITranche.sol";
import { IGuardian } from "./interfaces/IGuardian.sol";

/**
 * @title Tranche
 * @author Pragma Labs
 * @notice The Tranche contract allows for lending of a specified ERC20 token, managed by a lending pool.
 * @dev Protocol is according the ERC4626 standard, with a certain ERC20 as underlying asset.
 * @dev Implementation not vulnerable to ERC4626 inflation attacks,
 * since totalAssets() cannot be manipulated by first minter when total amount of shares are low.
 * For more information, see https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3706
 */
contract Tranche is ITranche, ERC4626, Owned {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    ILendingPool public immutable LENDING_POOL;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Flag indicating if the Tranche is locked or not.
    bool public locked;
    // Flag indicating if there is at least one ongoing auction or none.
    bool public auctionInProgress;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event LockSet(bool status);
    event AuctionInProgressSet(bool status);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    // Thrown when a tranche is locked.
    error Locked();
    // Thrown when amount of shares would represent zero assets.
    error ZeroAssets();
    // Thrown when an auction is in process.
    error AuctionOngoing();
    // Thrown when caller is not valid.
    error Unauthorized();
    // Thrown when amount of asset would represent zero shares.
    error ZeroShares();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Functions with this modifier can only be called when the Tranche is not locked.
     */
    modifier notLocked() {
        if (locked) revert Locked();
        _;
    }

    /**
     * @dev Certain actions (depositing and withdrawing) can be halted on the most junior tranche while auctions are in progress.
     * This prevents front running both in the case there is bad debt (by pulling out the tranche before the bad debt is settled),
     * as in the case there are big payouts to the LPs (mitigate Just In Time attacks, where MEV bots front-run the payout of
     * Liquidation penalties to the most junior tranche and withdraw immediately after).
     */
    modifier notDuringAuction() {
        if (auctionInProgress) revert AuctionOngoing();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice The constructor for a tranche.
     * @param lendingPool_ the Lending Pool of the underlying ERC-20 token, with the lending logic.
     * @param prefix_ The prefix of the contract name (eg. Senior -> Mezzanine -> Junior).
     * @param prefixSymbol_ The prefix of the contract symbol (eg. SR  -> MZ -> JR).
     * @dev The name and symbol of the tranche are automatically generated, based on the name and symbol of the underlying token.
     */
    constructor(address lendingPool_, string memory prefix_, string memory prefixSymbol_)
        ERC4626(
            ERC4626(address(lendingPool_)).asset(),
            string(abi.encodePacked(prefix_, " Arcadia ", ERC4626(lendingPool_).asset().name())),
            string(abi.encodePacked(prefixSymbol_, "arc", ERC4626(lendingPool_).asset().symbol()))
        )
        Owned(msg.sender)
    {
        LENDING_POOL = ILendingPool(lendingPool_);
    }

    /*//////////////////////////////////////////////////////////////
                        LOCKING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks the tranche in case all liquidity of the tranche is written off due to bad debt.
     * @dev This function can only be called by the Lending Pool and is triggered exclusively during a severe default event.
     */
    function lock() external {
        if (msg.sender != address(LENDING_POOL)) revert Unauthorized();

        emit LockSet(locked = true);
        emit AuctionInProgressSet(auctionInProgress = false);
    }

    /**
     * @notice Unlocks the tranche.
     * @dev Only the Owner can call this function, since tranches are locked due to complete defaults.
     * This function will only be called to partially refund existing share-holders after a default.
     */
    function unLock() external onlyOwner {
        emit LockSet(locked = false);
    }

    /**
     * @notice Locks the tranche when an auction is in progress.
     * @param auctionInProgress_ Flag indicating if there are auctions in progress.
     * @dev Only the Lending Pool can call this function.
     * This function is to make sure no JIT liquidity is provided during a positive auction,
     * and that no liquidity can be withdrawn during a negative auction.
     */
    function setAuctionInProgress(bool auctionInProgress_) external {
        if (msg.sender != address(LENDING_POOL)) revert Unauthorized();

        emit AuctionInProgressSet(auctionInProgress = auctionInProgress_);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modification of the standard ERC-4626 deposit implementation.
     * @param assets The amount of assets of the underlying ERC-20 token being deposited.
     * @param receiver The address that receives the minted shares.
     * @return shares The amount of shares minted.
     * @dev This contract does not directly transfer the underlying assets from the sender to the receiver.
     * Instead it calls the deposit of the Lending Pool which calls the transferFrom of the underlying assets.
     * Hence the sender should not give this contract an allowance to transfer the underlying asset but the Lending Pool instead.
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        notLocked
        notDuringAuction
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        if ((shares = previewDepositAndSync(assets)) == 0) revert ZeroShares();

        // Need to transfer (via lendingPool.depositInLendingPool()) before minting or ERC777s could reenter.
        LENDING_POOL.depositInLendingPool(assets, msg.sender);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Modification of the standard ERC-4626 mint implementation.
     * @param shares The amount of shares minted.
     * @param receiver The address that receives the minted shares.
     * @return assets The amount of assets of the underlying ERC-20 token being deposited.
     * @dev This contract does not directly transfer the underlying assets from the sender to the receiver.
     * Instead it calls the deposit of the Lending Pool which calls the transferFrom of the underlying assets.
     * Hence the sender should not give this contract an allowance to transfer the underlying asset but the Lending Pool instead.
     */
    function mint(uint256 shares, address receiver)
        public
        override
        notLocked
        notDuringAuction
        returns (uint256 assets)
    {
        // No need to check for rounding error, previewMint rounds up.
        assets = previewMintAndSync(shares);

        // Need to transfer (via lendingPool.depositInLendingPool()) before minting or ERC777s could reenter.
        LENDING_POOL.depositInLendingPool(assets, msg.sender);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Modification of the standard ERC-4626 withdraw implementation.
     * @param assets The amount of assets of the underlying ERC-20 token being withdrawn.
     * @param receiver The address of the receiver of the underlying ERC-20 tokens.
     * @param owner_ The address of the owner of the assets being withdrawn.
     * @return shares The corresponding amount of shares redeemed.
     */
    function withdraw(uint256 assets, address receiver, address owner_)
        public
        override
        notLocked
        notDuringAuction
        returns (uint256 shares)
    {
        // No need to check for rounding error, previewWithdraw rounds up.
        shares = previewWithdrawAndSync(assets);

        if (msg.sender != owner_) {
            // Saves gas for limited approvals.
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) allowance[owner_][msg.sender] = allowed - shares;
        }

        _burn(owner_, shares);

        LENDING_POOL.withdrawFromLendingPool(assets, receiver);

        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }

    /**
     * @notice Modification of the standard ERC-4626 redeem implementation.
     * @param shares The amount of shares being redeemed.
     * @param receiver The address of the receiver of the underlying ERC-20 tokens.
     * @param owner_ The address of the owner of the shares being redeemed.
     * @return assets The corresponding amount of assets withdrawn.
     */
    function redeem(uint256 shares, address receiver, address owner_)
        public
        override
        notLocked
        notDuringAuction
        returns (uint256 assets)
    {
        if (msg.sender != owner_) {
            // Saves gas for limited approvals.
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) allowance[owner_][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        if ((assets = previewRedeemAndSync(shares)) == 0) revert ZeroAssets();

        _burn(owner_, shares);

        LENDING_POOL.withdrawFromLendingPool(assets, receiver);

        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount of underlying assets, to which liquidity providers have a claim.
     * @return assets The total amount of underlying assets.
     * @dev The Liquidity Pool does the accounting of the outstanding claim on liquidity per tranche.
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets = LENDING_POOL.liquidityOf(address(this));
    }

    /**
     * @notice Returns the total amount of underlying assets, to which liquidity providers have a claim.
     * @return assets The total amount of underlying assets.
     * @dev Modification of totalAssets() where interests are realised (state modification).
     */
    function totalAssetsAndSync() public returns (uint256 assets) {
        assets = LENDING_POOL.liquidityOfAndSync(address(this));
    }

    /**
     * @notice Returns the amount of underlying assets, to which a certain amount of shares have a claim.
     * @return assets The amount of underlying assets.
     * @dev This function is a modification of convertToShares() where interests are realized (state modification).
     */
    function convertToSharesAndSync(uint256 assets) public returns (uint256) {
        // Cache totalSupply
        uint256 supply = totalSupply;

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssetsAndSync());
    }

    /**
     * @notice Returns the amount of underlying assets, to which a certain amount of shares have a claim.
     * @return assets The amount of underlying assets.
     * @dev This function is a modification of convertToAssets() where interests are realized (state modification).
     */
    function convertToAssetsAndSync(uint256 shares) public returns (uint256) {
        // Cache totalSupply
        uint256 supply = totalSupply;

        return supply == 0 ? shares : shares.mulDivDown(totalAssetsAndSync(), supply);
    }

    /**
     * @notice Returns the amount of shares that correspond to a certain amount of underlying assets.
     * @return shares The amount of shares minted.
     * @dev This function is a modification of previewDeposit() where interests are realized (state modification).
     */
    function previewDepositAndSync(uint256 assets) public returns (uint256) {
        return convertToSharesAndSync(assets);
    }

    /**
     * @notice Modification of previewMint() where interests are realized (state modification).
     * @return assets The corresponding amount of assets of the underlying ERC20 token being deposited.
     * @dev This function is a modification of previewMint() where interests are realized (state modification).
     */
    function previewMintAndSync(uint256 shares) public returns (uint256) {
        // Cache totalSupply
        uint256 supply = totalSupply;

        return supply == 0 ? shares : shares.mulDivUp(totalAssetsAndSync(), supply);
    }

    /**
     * @notice Modification of previewWithdraw() where interests are realized (state modification).
     * @return assets The amount of assets of the underlying ERC-20 token being withdrawn.
     * @dev This function is a modification of previewWithdraw() where interests are realized (state modification).
     */
    function previewWithdrawAndSync(uint256 assets) public returns (uint256) {
        // Cache totalSupply
        uint256 supply = totalSupply;

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssetsAndSync());
    }

    /**
     * @notice Modification of previewRedeem() where interests are realized (state modification).
     * @return shares The amount of shares being redeemed.
     * @dev This function is a modification of previewRedeem() where interests are realized (state modification).
     */
    function previewRedeemAndSync(uint256 shares) public returns (uint256) {
        return convertToAssetsAndSync(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev maxDeposit() according the EIP-4626 specification.
     */
    function maxDeposit(address) public view override returns (uint256 maxAssets) {
        if (locked || auctionInProgress || IGuardian(address(LENDING_POOL)).depositPaused()) return 0;

        uint256 supplyCap = LENDING_POOL.supplyCap();
        uint256 realisedLiquidity = LENDING_POOL.totalRealisedLiquidity();
        uint256 interests = LENDING_POOL.calcUnrealisedDebt();

        if (supplyCap > 0) {
            if (realisedLiquidity + interests > supplyCap) return 0;
            maxAssets = supplyCap - realisedLiquidity - interests;
        } else {
            maxAssets = type(uint128).max - realisedLiquidity - interests;
        }
    }

    /**
     * @dev maxMint() according the EIP-4626 specification.
     */
    function maxMint(address) public view override returns (uint256 maxShares) {
        if (locked || auctionInProgress || IGuardian(address(LENDING_POOL)).depositPaused()) return 0;

        uint256 supplyCap = LENDING_POOL.supplyCap();
        uint256 realisedLiquidity = LENDING_POOL.totalRealisedLiquidity();
        uint256 interests = LENDING_POOL.calcUnrealisedDebt();

        if (supplyCap > 0) {
            if (realisedLiquidity + interests > supplyCap) return 0;
            maxShares = convertToShares(supplyCap - realisedLiquidity - interests);
        } else {
            maxShares = convertToShares(type(uint128).max - realisedLiquidity - interests);
        }
    }

    /**
     * @dev maxWithdraw() according the EIP-4626 specification.
     */
    function maxWithdraw(address owner_) public view override returns (uint256 maxAssets) {
        if (locked || auctionInProgress || IGuardian(address(LENDING_POOL)).withdrawPaused()) return 0;

        uint256 availableAssets = asset.balanceOf(address(LENDING_POOL));
        uint256 claimableAssets = convertToAssets(balanceOf[owner_]);

        maxAssets = availableAssets < claimableAssets ? availableAssets : claimableAssets;
    }

    /**
     * @dev maxRedeem() according the EIP-4626 specification.
     */
    function maxRedeem(address owner_) public view override returns (uint256 maxShares) {
        if (locked || auctionInProgress || IGuardian(address(LENDING_POOL)).withdrawPaused()) return 0;

        uint256 claimableShares = balanceOf[owner_];
        if (claimableShares == 0) return 0;
        uint256 availableShares = convertToShares(asset.balanceOf(address(LENDING_POOL)));

        maxShares = availableShares < claimableShares ? availableShares : claimableShares;
    }
}
