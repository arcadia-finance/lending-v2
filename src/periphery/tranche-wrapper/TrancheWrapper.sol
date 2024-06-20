/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { ERC4626 } from "../../../lib/accounts-v2/lib/solmate/src/mixins/ERC4626.sol";
import { FixedPointMathLib } from "../../../lib/accounts-v2/lib/solmate/src/utils/FixedPointMathLib.sol";
import { ITranche } from "./interfaces/ITranche.sol";
import { SafeTransferLib } from "../../../lib/accounts-v2/lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Tranche Wrapper
 * @notice This contract wraps an Arcadia Tranche to make it ERC4626 compliant.
 * @dev Shares minted via the wrapper have a 1:1 ratio to shares minted on the Tranche.
 * All view functions can be called directly on the Tranche view functions.
 * @dev Deposit and Mint functions approve the LendingPool, not the Tranche.
 */
contract TrancheWrapper is ERC4626 {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The contract address of the underlying Arcadia Lending Pool.
    address public immutable LENDING_POOL;
    // The contract address of the underlying Arcadia Tranche.
    address public immutable TRANCHE;

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice The constructor for a TrancheWrapper.
     * @param tranche The contract address of the Tranche.
     */
    constructor(address tranche)
        ERC4626(
            ERC4626(tranche).asset(),
            string(abi.encodePacked("Wrapped ", ERC4626(tranche).asset().name())),
            string(abi.encodePacked("w", ERC4626(tranche).asset().symbol()))
        )
    {
        TRANCHE = tranche;
        LENDING_POOL = ITranche(tranche).LENDING_POOL();
    }

    /* //////////////////////////////////////////////////////////////
                                FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Deposits assets in the underlying Tranche.
     * @param assets The amount of assets of the underlying ERC20 token being deposited.
     * @param receiver The address that receives the minted shares.
     * @return shares The amount of shares minted.
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
     * @notice Mints shares of the underlying Tranche.
     * @param shares The amount of shares minted.
     * @param receiver The address that receives the minted shares.
     * @return assets The amount of assets of the underlying ERC20 token being deposited.
     */
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        assets = ITranche(TRANCHE).previewMintAndSync(shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // Approval has to be given to the Lending Pool for the deposit in the Tranche.
        asset.safeApprove(LENDING_POOL, assets);

        ERC4626(TRANCHE).mint(shares, address(this));
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Withdraws assets from the underlying Tranche.
     * @param assets The amount of assets of the underlying ERC20 token being withdrawn.
     * @param receiver The address of the receiver of the underlying ERC20 tokens.
     * @param owner The address of the owner of the assets being withdrawn.
     * @return shares The corresponding amount of shares redeemed.
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        shares = ITranche(TRANCHE).previewWithdrawAndSync(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);
        ERC4626(TRANCHE).withdraw(assets, address(this), address(this));
        asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @notice Redeems shares of the underlying Tranche.
     * @param shares The amount of shares being redeemed.
     * @param receiver The address of the receiver of the underlying ERC20 tokens.
     * @param owner The address of the owner of the shares being redeemed.
     * @return assets The corresponding amount of assets withdrawn.
     */
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);
        assets = ERC4626(TRANCHE).redeem(shares, address(this), address(this));
        asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount of underlying assets.
     * @return assets The total amount of underlying assets.
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets = ERC4626(TRANCHE).convertToAssets(totalSupply);
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
     * @notice Returns the maximum amount of assets that can be deposited.
     * @param owner The address of the depositor.
     * @return maxAssets The maximum amount of assets that can be deposited.
     */
    function maxDeposit(address owner) public view override returns (uint256 maxAssets) {
        maxAssets = ERC4626(TRANCHE).maxDeposit(owner);
    }

    /**
     * @notice Returns the maximum amount of shares that can be minted.
     * @param owner The address of the minter.
     * @return maxShares The maximum amount of shares that can be minted.
     */
    function maxMint(address owner) public view override returns (uint256 maxShares) {
        maxShares = ERC4626(TRANCHE).maxMint(owner);
    }

    /**
     * @notice Returns the maximum amount of assets that can be withdrawn.
     * @param owner The address from who the assets are withdrawn.
     * @return maxAssets The maximum amount of assets that can be withdrawn.
     */
    function maxWithdraw(address owner) public view override returns (uint256 maxAssets) {
        uint256 availableAssets = ERC4626(TRANCHE).maxWithdraw(address(this));
        uint256 claimableAssets = convertToAssets(balanceOf[owner]);

        maxAssets = availableAssets < claimableAssets ? availableAssets : claimableAssets;
    }

    /**
     * @notice Returns the maximum amount of shares that can be redeemed.
     * @param owner The address from who the shares are redeemed.
     * @return maxShares The maximum amount of shares that can be redeemed.
     */
    function maxRedeem(address owner) public view override returns (uint256 maxShares) {
        uint256 availableShares = ERC4626(TRANCHE).maxRedeem(address(this));
        uint256 claimableShares = balanceOf[owner];

        maxShares = availableShares < claimableShares ? availableShares : claimableShares;
    }
}
