/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

library LiquidatorErrors {
    // Thrown when the liquidateAccount function is called on an Account that is already in an auction.
    error AuctionOngoing();
    // Thrown when cutOffTime is above the maximum value.
    error CutOffTooHigh();
    // Thrown when cutOffTime is below the minimum value.
    error CutOffTooLow();
    // Thrown if the auction was not successfully ended.
    error EndAuctionFailed();
    // Thrown when halfLifeTime is above the maximum value.
    error HalfLifeTimeTooHigh();
    // Thrown when halfLifeTime is below the minimum value.
    error HalfLifeTimeTooLow();
    // Thrown when the auction has not yet expired.
    error InvalidBid();
    // Thrown when the start price multiplier is above the maximum value.
    error MultiplierTooHigh();
    // Thrown when the start price multiplier is below the minimum value.
    error MultiplierTooLow();
    // Thrown when an Account is not for sale.
    error NotForSale();
}
