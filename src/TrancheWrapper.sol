/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC4626 } from "../lib/solmate/src/mixins/ERC4626.sol";
import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ITranche } from "./interfaces/ITranche.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Tranche Wrapper
 * @notice This contract wraps a Tranche to make it ERC4626 compliant.
 * @dev This contract acts as a wrapper for interactions with the Tranche, ensuring ERC4626-compliance.
 * - Shares minted via the wrapper have a 1:1 ratio to shares minted on the Tranche.
 * - All view functions can be called directly on the Tranche view functions.
 * - Deposit and Mint functions approve the LendingPool, not the Tranche.
 */
contract TrancheWrapper is ERC4626 {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // Address of the Lending Pool.
    address public immutable LENDING_POOL;
    // Address of the underlying Tranche.
    address public immutable TRANCHE;

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice The constructor for a TrancheWrapper.
     * @param asset_ The underlying ERC20 asset.
     * @param name_ The name of the ERC4626 token.
     * @param symbol_ The symbol of the ERC4626 token.
     * @param TRANCHE_ The Tranche contract address.
     */
    constructor(ERC20 asset_, string memory name_, string memory symbol_, address TRANCHE_)
        ERC4626(asset_, name_, symbol_)
    {
        TRANCHE = TRANCHE_;
        LENDING_POOL = address(ITranche(TRANCHE_).LENDING_POOL());
    }

    /* //////////////////////////////////////////////////////////////
                                FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Compliant with the standard ERC-4626 deposit implementation.
     * @param assets The amount of assets of the underlying ERC20 token being deposited.
     * @param receiver The address that receives the minted shares.
     * @return shares The amount of shares minted.
     * @dev This contract does not directly transfer the underlying assets from the sender to the receiver.
     * Instead it calls the deposit of the Lending Pool which calls the transferFrom of the underlying assets.
     * Hence the sender should not give this contract an allowance to transfer the underlying asset but the Lending Pool instead.
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // Approval has to be given to the Lending Pool for the deposit in the Tranche.
        asset.safeApprove(LENDING_POOL, assets);

        shares = ERC4626(TRANCHE).deposit(assets, address(this));

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Compliant with the standard ERC-4626 mint implementation.
     * @param shares The amount of shares minted.
     * @param receiver The address that receives the minted shares.
     * @return assets The amount of assets of the underlying ERC20 token being deposited.
     * @dev This contract does not directly transfer the underlying assets from the sender to the receiver.
     * Instead it calls the deposit of the Lending Pool which calls the transferFrom of the underlying assets.
     * Hence the sender should not give this contract an allowance to transfer the underlying asset but the Lending Pool instead.
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = ITranche(TRANCHE).previewMintAndSync(shares);

        asset.safeTransferFrom(msg.sender, address(this), assets);

        asset.safeApprove(LENDING_POOL, assets);

        ERC4626(TRANCHE).deposit(assets, address(this));

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Compliant with the standard ERC-4626 withdraw implementation.
     * @param assets The amount of assets of the underlying ERC20 token being withdrawn.
     * @param receiver The address of the receiver of the underlying ERC20 tokens.
     * @param owner_ The address of the owner of the assets being withdrawn.
     * @return shares The corresponding amount of shares redeemed.
     */
    function withdraw(uint256 assets, address receiver, address owner_) public override returns (uint256 shares) {
        shares = ERC4626(TRANCHE).withdraw(assets, address(this), address(this));

        if (msg.sender != owner_) {
            // Saves gas for limited approvals.
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) allowance[owner_][msg.sender] = allowed - shares;
        }

        _burn(owner_, shares);

        asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner_, assets, shares);
    }

    /**
     * @notice Compliant with the standard ERC-4626 redeem implementation.
     * @param shares The amount of shares being redeemed.
     * @param receiver The address of the receiver of the underlying ERC20 tokens.
     * @param owner_ The address of the owner of the shares being redeemed.
     * @return assets The corresponding amount of assets withdrawn.
     */
    function redeem(uint256 shares, address receiver, address owner_) public override returns (uint256 assets) {
        assets = ERC4626(TRANCHE).redeem(shares, address(this), address(this));

        if (msg.sender != owner_) {
            // Saves gas for limited approvals.
            uint256 allowed = allowance[owner_][msg.sender];

            if (allowed != type(uint256).max) allowance[owner_][msg.sender] = allowed - shares;
        }

        _burn(owner_, shares);

        asset.safeTransfer(receiver, assets);

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
        assets = ERC4626(TRANCHE).totalAssets();
    }

    /**
     * @notice Conversion rate from assets to shares.
     * @param assets The amount of underlying assets.
     * @return shares The amount of shares.
     */
    function convertToShares(uint256 assets) public view override returns (uint256 shares) {
        shares = ERC4626(TRANCHE).convertToShares(assets);
    }

    /**
     * @notice Conversion rate from shares to assets.
     * @param shares The amount of shares.
     * @return assets The amount of underlying assets.
     */
    function convertToAssets(uint256 shares) public view override returns (uint256 assets) {
        assets = ERC4626(TRANCHE).convertToAssets(shares);
    }

    /**
     * @notice Returns the amount of underlying assets deposited that correspond to a certain amount of shares minted.
     * @param shares The amount of shares minted.
     * @return assets The amount of underlying assets deposited.
     */
    function previewMint(uint256 shares) public view override returns (uint256 assets) {
        assets = ERC4626(TRANCHE).previewMint(shares);
    }

    /**
     * @notice Returns the amount of shares redeemed that correspond to a certain amount of underlying assets withdrawn.
     * @param assets The amount of underlying assets withdrawn.
     * @return shares The amount of shares redeemed.
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256 shares) {
        shares = ERC4626(TRANCHE).previewWithdraw(assets);
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev maxDeposit() according to the Tranche implementation.
     */
    function maxDeposit(address) public view override returns (uint256 maxAssets) {
        maxAssets = ERC4626(TRANCHE).maxDeposit(msg.sender);
    }

    /**
     * @dev maxMint() according to the Tranche implementation.
     */
    function maxMint(address) public view override returns (uint256 maxShares) {
        maxShares = ERC4626(TRANCHE).maxMint(msg.sender);
    }

    /**
     * @dev maxWithdraw() according to the Tranche implementation.
     */
    function maxWithdraw(address owner_) public view override returns (uint256 maxAssets) {
        uint256 availableAssets = ERC4626(TRANCHE).maxWithdraw(address(this));
        uint256 claimableAssets = convertToAssets(balanceOf[owner_]);

        maxAssets = availableAssets < claimableAssets ? availableAssets : claimableAssets;
    }

    /**
     * @dev maxRedeem() according to the Tranche implementation.
     */
    function maxRedeem(address owner_) public view override returns (uint256 maxShares) {
        uint256 availableShares = ERC4626(TRANCHE).maxRedeem(address(this));
        uint256 claimableShares = balanceOf[owner_];

        maxShares = availableShares < claimableShares ? availableShares : claimableShares;
    }
}
