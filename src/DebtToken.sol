/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20, ERC4626 } from "../lib/solmate/src/mixins/ERC4626.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { DebtTokenErrors } from "./libraries/Errors.sol";

/**
 * @title Debt Token.
 * @author Pragma Labs
 * @notice The Logic to do the debt accounting for a lending pool for a certain ERC20 token.
 * @dev Protocol is according the ERC4626 standard, with a certain ERC20 as underlying.
 * @dev Implementation slightly deviates from the ERC4626 specifications,
 * maxDeposit() and maxMint() are not implemented.
 */
abstract contract DebtToken is ERC4626 {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Total amount of `underlying asset` that debtors have in debt, does not take into account pending interests.
    uint256 internal realisedDebt;

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice The constructor for the debt token.
     * @param asset_ The underlying ERC20 token in which the debt is denominated.
     */
    constructor(ERC20 asset_)
        ERC4626(
            asset_,
            string(abi.encodePacked("ArcadiaV2 ", asset_.name(), " Debt")),
            string(abi.encodePacked("darcV2", asset_.symbol()))
        )
    { }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount of outstanding debt in the underlying asset.
     * @return totalDebt The total debt in underlying assets.
     * @dev Implementation overwritten in LendingPool.sol which inherits DebtToken.sol.
     * Implementation not vulnerable to ERC4626 inflation attacks,
     * totalAssets() does not rely on balanceOf call.
     */
    function totalAssets() public view virtual override returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modification of the standard ERC4626 deposit implementation.
     * @dev No public deposit allowed.
     */
    function deposit(uint256, address) public pure override returns (uint256) {
        revert DebtTokenErrors.FunctionNotImplemented();
    }

    /**
     * @notice Modification of the standard ERC4626 deposit implementation.
     * @param assets The amount of assets of the underlying ERC20 token being loaned out.
     * @param receiver The Arcadia Account with collateral covering the debt.
     * @return shares The corresponding amount of debt shares minted.
     * @dev Only the Lending Pool (which inherits this contract) can issue debt.
     */
    function _deposit(uint256 assets, address receiver) internal returns (uint256 shares) {
        // No need to check for rounding error, previewDeposit rounds up.
        shares = previewDeposit(assets);

        _mint(receiver, shares);

        realisedDebt += assets;

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Modification of the standard ERC4626 deposit implementation.
     * @dev No public mint allowed.
     */
    function mint(uint256, address) public pure override returns (uint256) {
        revert DebtTokenErrors.FunctionNotImplemented();
    }

    /**
     * @notice Modification of the standard ERC4626 withdraw implementation.
     * @dev No public withdraw allowed.
     */
    function withdraw(uint256, address, address) public pure override returns (uint256) {
        revert DebtTokenErrors.FunctionNotImplemented();
    }

    /**
     * @notice Modification of the standard ERC4626 withdraw implementation.
     * @param assets The amount of assets of the underlying ERC20 token being paid back.
     * @param receiver Will always be the Lending Pool.
     * @param account The Arcadia Account with collateral covering the debt.
     * @return shares The corresponding amount of debt shares redeemed.
     * @dev Only the Lending Pool (which inherits this contract) can issue debt.
     */
    function _withdraw(uint256 assets, address receiver, address account) internal returns (uint256 shares) {
        // Check for rounding error since we round down in previewWithdraw.
        if ((shares = previewWithdraw(assets)) == 0) revert DebtTokenErrors.ZeroShares();

        _burn(account, shares);

        realisedDebt -= assets;

        emit Withdraw(msg.sender, receiver, account, assets, shares);
    }

    /**
     * @notice Modification of the standard ERC4626 redeem implementation.
     * @dev No public redeem allowed.
     */
    function redeem(uint256, address, address) public pure override returns (uint256) {
        revert DebtTokenErrors.FunctionNotImplemented();
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modification of the standard ERC4626 convertToShares implementation.
     * @dev Since debt is a liability instead of an asset, roundUp and roundDown are inverted compared to the standard implementation.
     */
    function convertToShares(uint256 assets) public view override returns (uint256) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    /**
     * @notice Modification of the standard ERC4626 convertToShares implementation.
     * @dev Since debt is a liability instead of an asset, roundUp and roundDown are inverted compared to the standard implementation.
     */
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    /**
     * @notice Modification of the standard ERC4626 previewMint implementation.
     * @dev Since debt is a liability instead of an asset, roundUp and roundDown are inverted compared to the standard implementation.
     */
    function previewMint(uint256 shares) public view override returns (uint256) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    /**
     * @notice Modification of the standard ERC4626 previewWithdraw implementation.
     * @dev Since debt is a liability instead of an asset, roundUp and roundDown are inverted compared to the standard implementation.
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        // Cache totalSupply.
        uint256 supply = totalSupply;

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modification of the standard ERC4626 transfer implementation.
     * @dev No public transfer allowed.
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert DebtTokenErrors.FunctionNotImplemented();
    }

    /**
     * @notice Modification of the standard ERC4626 transferFrom implementation.
     * @dev No public transferFrom allowed.
     * @dev The functions approve() and permit() will not revert, but since transferFrom() reverts,
     * it can never be used to transfer tokens.
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert DebtTokenErrors.FunctionNotImplemented();
    }
}
