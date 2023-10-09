/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/**
 * @title Errors
 * @author Pragma Labs
 * @notice Library containing all custom errors for lending-v2
 */
library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when caller is not valid.
    error Unauthorized();
    /// @notice Thrown when an auction is in process.
    error AuctionOngoing();
    /// @notice Thrown when amount of asset would represent zero shares.
    error ZeroShares();

    /*//////////////////////////////////////////////////////////////////////////
                                    DEBT TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  LENDING POOL
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when caller is not Liquidator.
    error LendingPool_OnlyLiquidator();
    /// @notice Thrown when caller is not Tranche.
    error LendingPool_OnlyTranche();
    /// @notice Thrown when maximum amount of asset that can be supplied to the pool would be exceeded.
    error LendingPool_SupplyCapExceeded();
    /// @notice Thrown when the tranche of the lending pool already exists.
    error LendingPool_TrancheAlreadyExists();
    /// @notice Thrown when a specified tranche does not exist.
    error LendingPool_NonExistingTranche();
    /// @notice Thrown when asset amount in input is zero.
    error LendingPool_ZeroAmount();
    /// @notice Thrown when less than 1 share outstanding to mitigate share manipulation.
    error LendingPool_InsufficientShares();
    /// @notice Thrown when amount available to withdraw of an asset is less than amount requested to withdraw.
    error LendingPool_AmountExceedsBalance();
    /// @notice Thrown when account specified is not an Arcadia Account.
    error LendingPool_IsNotAnAccount();
    /// @notice Thrown when an Account would become unhealthy OR the trusted creditor of the Account is not the specific lending pool OR the Account version would not be valid.
    error LendingPool_Reverted();
    /// @notice Thrown when an account has zero debt.
    error LendingPool_IsNotAnAccountWithDebt();

    /*//////////////////////////////////////////////////////////////////////////
                                   LIQUIDATOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when liquidation weights are above maximum value.
    error Liquidator_WeightsTooHigh();
    /// @notice Thrown when halfLifeTime is below minimum value.
    error Liquidator_HalfLifeTimeTooLow();
    /// @notice Thrown when halfLifeTime is above maximum value.
    error Liquidator_HalfLifeTimeTooHigh();
    /// @notice Thrown when cutOffTime is below minimum value.
    error Liquidator_CutOffTooLow();
    /// @notice Thrown when cutOffTime is above maximum value.
    error Liquidator_CutOffTooHigh();
    /// @notice Thrown when the start price multiplier is below minimum value.
    error Liquidator_MultiplierTooLow();
    /// @notice Thrown when the start price multiplier is above the maximum value.
    error Liquidator_MultiplierTooHigh();
    /// @notice Thrown when an Account is not for sale.
    error Liquidator_NotForSale();
    /// @notice Thrown when the auction did not yet expire.
    error Liquidator_AuctionNotExpired();

    /*//////////////////////////////////////////////////////////////////////////
                                    TRANCHE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a tranche is locked.
    error Tranche_Locked();
    /// @notice Thrown when amount of shares would represent zero assets.
    error Tranche_ZeroAssets();
}
