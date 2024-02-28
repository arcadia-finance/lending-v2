/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

/// @notice Contract containing all custom errors for lending-v2
abstract contract Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                    DEBT TOKEN
    //////////////////////////////////////////////////////////////////////////*/

    error BorrowCapExceeded();

    /*//////////////////////////////////////////////////////////////////////////
                                  LENDING POOL
    //////////////////////////////////////////////////////////////////////////*/

    error TrancheAlreadyExists();
    error NonExistingTranche();
    error ZeroAmount();
    error AmountExceedsBalance();
    error IsNotAnAccount();
    error InvalidVersion();
    error IsNotAnAccountWithDebt();
    error LiquidationWeightsTooHigh();

    /*//////////////////////////////////////////////////////////////////////////
                                   LIQUIDATOR
    //////////////////////////////////////////////////////////////////////////*/

    error NotForSale();
    error InvalidBid();
    error HalfLifeTimeTooLow();
    error HalfLifeTimeTooHigh();
    error CutOffTooLow();
    error CutOffTooHigh();
    error MultiplierTooLow();
    error MultiplierTooHigh();
    error EndAuctionFailed();

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
