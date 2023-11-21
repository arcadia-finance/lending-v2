/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/// @notice Contract containing all custom errors for lending-v2
abstract contract Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                    DEBT TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    error BorrowCapExceeded();
    error FunctionNotImplemented();

    /*//////////////////////////////////////////////////////////////////////////
                                  LENDING POOL
    //////////////////////////////////////////////////////////////////////////*/

    error LendingPool_OnlyLiquidator();
    error LendingPool_OnlyTranche();
    error LendingPool_SupplyCapExceeded();
    error LendingPool_TrancheAlreadyExists();
    error LendingPool_NonExistingTranche();
    error LendingPool_ZeroAmount();
    error LendingPool_InsufficientShares();
    error LendingPool_AmountExceedsBalance();
    error LendingPool_IsNotAnAccount();
    error LendingPool_Reverted();
    error LendingPool_IsNotAnAccountWithDebt();
    error LendingPool_Unauthorized();
    error LendingPool_AuctionOngoing();
    error LendingPool_WeightsTooHigh();

    /*//////////////////////////////////////////////////////////////////////////
                                   LIQUIDATOR
    //////////////////////////////////////////////////////////////////////////*/

    error Liquidator_AuctionOngoing();
    error Liquidator_NotForSale();
    error Liquidator_InvalidBid();
    error Liquidator_HalfLifeTimeTooLow();
    error Liquidator_HalfLifeTimeTooHigh();
    error Liquidator_CutOffTooLow();
    error Liquidator_CutOffTooHigh();
    error Liquidator_MultiplierTooLow();
    error Liquidator_MultiplierTooHigh();
    error Liquidator_Unauthorized();
    error Liquidator_EndAuctionFailed();

    /*//////////////////////////////////////////////////////////////////////////
                                    TRANCHE
    //////////////////////////////////////////////////////////////////////////*/

    error Locked();
    error ZeroAssets();
    error AuctionOngoing();
    error Unauthorized();
    error ZeroShares();
}
