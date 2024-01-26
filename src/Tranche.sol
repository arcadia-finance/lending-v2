/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Owned } from "../lib/solmate/src/auth/Owned.sol";
import { ERC4626 } from "../lib/solmate/src/mixins/ERC4626.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ITranche } from "./interfaces/ITranche.sol";
import { IGuardian } from "./interfaces/IGuardian.sol";
import { TrancheErrors } from "./libraries/Errors.sol";

/**
 * @title Tranche
 * @author Pragma Labs
 * @notice Each Lending Pool has one or more Tranche(s).
 * Different Tranches receive different yields, but also have different protections against losses due to bad debt:
 * In general the most junior Tranche will have the highest yield,
 * but it will be the first Tranche to absorb losses when liquidations result in bad debt.
 * The Liquidity Providers do not provide Liquidity directly to the Lending Pool, but via a Tranche.
 * As such Liquidity Providers with different risk/reward preferences can provide liquidity to the same Lending Pool
 * (benefitting borrowers with deeper liquidity), but via different Tranches.
 * @dev Each Tranche contract will do the accounting of the balances of its Liquidity Providers,
 * while the Lending Pool will do the accounting of the balances of its Tranches.
 * @dev A Tranche is according the ERC4626 standard, with a certain ERC20 as underlying asset.
 */
contract Tranche is ITranche, ERC4626, Owned {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The amount of Virtual Assets and Shares.
    // Virtual shares/assets (also ghost shares) prevent against inflation attacks of ERC4626 vaults,
    // see https://docs.openzeppelin.com/contracts/4.x/erc4626.
    uint256 internal immutable VAS;
    // The Lending Pool of the underlying ERC20 token, with the lending logic.
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
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Functions with this modifier can only be called when the Tranche is not locked.
     */
    modifier notLocked() {
        if (locked) revert TrancheErrors.Locked();
        _;
    }

    /**
     * @dev Certain actions (depositing and withdrawing) can be halted on the most junior tranche while auctions are in progress.
     * This prevents front running both in the case there is bad debt (by pulling out the tranche before the bad debt is settled),
     * as in the case there are big payouts to the LPs (mitigate Just In Time attacks, where MEV bots front-run the payout of
     * Liquidation penalties to the most junior tranche and withdraw immediately after).
     */
    modifier notDuringAuction() {
        if (auctionInProgress) revert TrancheErrors.AuctionOngoing();
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice The constructor for a tranche.
     * @param lendingPool_ The Lending Pool of the underlying ERC20 token, with the lending logic.
     * @param vas The amount of Virtual Assets and Shares.
     * @param prefix_ The prefix of the contract name (eg. Senior -> Mezzanine -> Junior).
     * @param prefixSymbol_ The prefix of the contract symbol (eg. SR  -> MZ -> JR).
     * @dev The name and symbol of the tranche are automatically generated, based on the name and symbol of the underlying token.
     */
    constructor(address lendingPool_, uint256 vas, string memory prefix_, string memory prefixSymbol_)
        ERC4626(
            ERC4626(address(lendingPool_)).asset(),
            string(abi.encodePacked(prefix_, " ArcadiaV2 ", ERC4626(lendingPool_).asset().name())),
            string(abi.encodePacked(prefixSymbol_, "arcV2", ERC4626(lendingPool_).asset().symbol()))
        )
        Owned(msg.sender)
    {
        LENDING_POOL = ILendingPool(lendingPool_);
        VAS = vas;
    }

    /*//////////////////////////////////////////////////////////////
                        LOCKING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks the tranche in case all liquidity of the tranche is written off due to bad debt.
     * @dev This function can only be called by the Lending Pool and is triggered exclusively during a severe default event.
     */
    function lock() external {
        if (msg.sender != address(LENDING_POOL)) revert TrancheErrors.Unauthorized();

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
        if (msg.sender != address(LENDING_POOL)) revert TrancheErrors.Unauthorized();

        emit AuctionInProgressSet(auctionInProgress = auctionInProgress_);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modification of the standard ERC-4626 deposit implementation.
     * @param assets The amount of assets of the underlying ERC20 token being deposited.
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
        if ((shares = previewDepositAndSync(assets)) == 0) revert TrancheErrors.ZeroShares();

        // Need to transfer (via lendingPool.depositInLendingPool()) before minting or ERC777s could reenter.
        LENDING_POOL.depositInLendingPool(assets, msg.sender);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Modification of the standard ERC-4626 mint implementation.
     * @param shares The amount of shares minted.
     * @param receiver The address that receives the minted shares.
     * @return assets The amount of assets of the underlying ERC20 token being deposited.
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
     * @param assets The amount of assets of the underlying ERC20 token being withdrawn.
     * @param receiver The address of the receiver of the underlying ERC20 tokens.
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
     * @param receiver The address of the receiver of the underlying ERC20 tokens.
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
        if ((assets = previewRedeemAndSync(shares)) == 0) revert TrancheErrors.ZeroAssets();

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
     * @notice Conversion rate from assets to shares.
     * @param assets The amount of underlying assets.
     * @return shares The amount of shares.
     */
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        shares = supply == 0 ? assets : assets.mulDivDown(supply + VAS, totalAssets() + VAS);
    }

    /**
     * @notice Conversion rate from assets to shares.
     * @param assets The amount of underlying assets.
     * @return shares The amount of shares.
     * @dev This function is a modification of convertToShares() where interests are realized (state modification).
     */
    function convertToSharesAndSync(uint256 assets) public returns (uint256 shares) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        shares = supply == 0 ? assets : assets.mulDivDown(supply + VAS, totalAssetsAndSync() + VAS);
    }

    /**
     * @notice Conversion rate from shares to assets.
     * @param shares The amount of shares.
     * @return assets The amount of underlying assets.
     */
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        assets = supply == 0 ? shares : shares.mulDivDown(totalAssets() + VAS, supply + VAS);
    }

    /**
     * @notice Conversion rate from shares to assets.
     * @param shares The amount of shares.
     * @return assets The amount of underlying assets.
     * @dev This function is a modification of convertToAssets() where interests are realized (state modification).
     */
    function convertToAssetsAndSync(uint256 shares) public returns (uint256 assets) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        assets = supply == 0 ? shares : shares.mulDivDown(totalAssetsAndSync() + VAS, supply + VAS);
    }

    /**
     * @notice Returns the amount of shares minted that correspond to a certain amount of underlying assets deposited.
     * @param assets The amount of underlying assets deposited.
     * @return shares The amount of shares minted.
     * @dev This function is a modification of previewDeposit() where interests are realized (state modification).
     */
    function previewDepositAndSync(uint256 assets) public returns (uint256 shares) {
        shares = convertToSharesAndSync(assets);
    }

    /**
     * @notice Returns the amount of underlying assets deposited that correspond to a certain amount of shares minted.
     * @param shares The amount of shares minted.
     * @return assets The amount of underlying assets deposited.
     */
    function previewMint(uint256 shares) public view override returns (uint256 assets) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        assets = supply == 0 ? shares : shares.mulDivUp(totalAssets() + VAS, supply + VAS);
    }

    /**
     * @notice Returns the amount of underlying assets deposited that correspond to a certain amount of shares minted.
     * @param shares The amount of shares minted.
     * @return assets The amount of underlying assets deposited.
     * @dev This function is a modification of previewMint() where interests are realized (state modification).
     */
    function previewMintAndSync(uint256 shares) public returns (uint256 assets) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        assets = supply == 0 ? shares : shares.mulDivUp(totalAssetsAndSync() + VAS, supply + VAS);
    }

    /**
     * @notice Returns the amount of shares redeemed that correspond to a certain amount of underlying assets withdrawn.
     * @param assets The amount of underlying assets withdrawn.
     * @return shares The amount of shares redeemed.
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256 shares) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        shares = supply == 0 ? assets : assets.mulDivUp(supply + VAS, totalAssets() + VAS);
    }

    /**
     * @notice Returns the amount of shares redeemed that correspond to a certain amount of underlying assets withdrawn.
     * @param assets The amount of underlying assets withdrawn.
     * @return shares The amount of shares redeemed.
     * @dev This function is a modification of previewWithdraw() where interests are realized (state modification).
     */
    function previewWithdrawAndSync(uint256 assets) public returns (uint256 shares) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        shares = supply == 0 ? assets : assets.mulDivUp(supply + VAS, totalAssetsAndSync() + VAS);
    }

    /**
     * @notice Returns the amount of underlying assets redeemed that correspond to a certain amount of shares withdrawn.
     * @param shares The amount of shares redeemed.
     * @return assets The amount of underlying assets withdrawn.
     * @dev This function is a modification of previewRedeem() where interests are realized (state modification).
     */
    function previewRedeemAndSync(uint256 shares) public returns (uint256 assets) {
        assets = convertToAssetsAndSync(shares);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev maxDeposit() according the EIP-4626 specification.
     */
    function maxDeposit(address) public view override returns (uint256 maxAssets) {
        if (locked || auctionInProgress || IGuardian(address(LENDING_POOL)).depositPaused()) return 0;

        maxAssets = type(uint128).max - LENDING_POOL.totalLiquidity();
    }

    /**
     * @dev maxMint() according the EIP-4626 specification.
     */
    function maxMint(address) public view override returns (uint256 maxShares) {
        if (locked || auctionInProgress || IGuardian(address(LENDING_POOL)).depositPaused()) return 0;

        maxShares = convertToShares(type(uint128).max - LENDING_POOL.totalLiquidity());
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
