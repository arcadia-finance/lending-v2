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

    error TrancheAlreadyExists();
    error NonExistingTranche();
    error ZeroAmount();
    error InsufficientShares();
    error AmountExceedsBalance();
    error IsNotAnAccount();
    error Reverted();
    error IsNotAnAccountWithDebt();
    error LiquidationWeightsTooHigh();
    error OpenPositionNonZero();

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

    /*//////////////////////////////////////////////////////////////////////////
                                    SHARED
    //////////////////////////////////////////////////////////////////////////*/

    error AuctionOngoing();
    error Unauthorized();
    error ZeroShares();
}
