/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/**
 * @title Errors
 * @author Pragma Labs
 * @notice Library containing all custom errors
 */
library Errors {
    // note: same error for Liquidator_AuctionAlreadyOngoing and generic AuctionOngoing?
    /*//////////////////////////////////////////////////////////////////////////
                                      GENERICS
    //////////////////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error AuctionOngoing();
    /// @notice Thrown when amount of asset would represent zero shares.
    error ZeroShares();

    /*//////////////////////////////////////////////////////////////////////////
                                    DEBT TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when assets to borrow exceeds amount of debt that a single debtor can take on that asset.
    error DebtToken_BorrowCapExceeded();

    /*//////////////////////////////////////////////////////////////////////////
                                  LENDING POOL
    //////////////////////////////////////////////////////////////////////////*/

    error LendingPool_OnlyLiquidator();
    error LendingPool_OnlyTranche();
    error LendingPool_TrancheAlreadyExists();
    error LendingPool_NonExistingTranche();
    error LendingPool_ZeroAmount();
    error LendingPool_InsufficientShares();
    error LendingPool_AmountExceedsBalance();
    error LendingPool_IsNotAnAccount();
    error LendingPool_Reverted();
    error LendingPool_IsNotAnAccountWithDebt();

    /*//////////////////////////////////////////////////////////////////////////
                                   LIQUIDATOR
    //////////////////////////////////////////////////////////////////////////*/

    error Liquidator_WeightsTooHigh();
    error Liquidator_HalfLifeTimeTooLow();
    error Liquidator_HalfLifeTimeTooHigh();
    error Liquidator_CutOffTooLow();
    error Liquidator_CutOffTooHigh();
    error Liquidator_MultiplierTooLow();
    error Liquidator_MultiplierTooHigh();
    error Liquidator_AuctionAlreadyOngoing();
    error Liquidator_NotForSale();
    error Liquidator_AuctionNotExpired();

    /*//////////////////////////////////////////////////////////////////////////
                                    TRANCHE
    //////////////////////////////////////////////////////////////////////////*/

    error Tranche_Locked();
    error Tranche_ZeroAssets();
}
