/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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
    // Thrown when account specified is not an Arcadia Account.
    error IsNotAnAccount();
    // Thrown when the start price multiplier is above the maximum value.
    error MultiplierTooHigh();
    // Thrown when the start price multiplier is below the minimum value.
    error MultiplierTooLow();
    // Thrown when an Account is not for sale.
    error NotForSale();
    // Thrown when not authorized.
    error NotAuthorized();
}

library DebtTokenErrors {
    // Thrown when function called has not be implemented.
    error FunctionNotImplemented();
    // Thrown when amount of asset would represent zero shares.
    error ZeroShares();
}

library LendingPoolErrors {
    // Thrown when amount available to withdraw of an asset is less than amount requested to withdraw.
    error AmountExceedsBalance();
    // Thrown when an auction is in process.
    error AuctionOngoing();
    // Thrown when an Account would become unhealthy OR the creditor of the Account is not the specific lending pool OR the Account version would not be valid.
    error InvalidVersion();
    // Thrown when account specified is not an Arcadia Account.
    error IsNotAnAccount();
    // Thrown when an account has zero debt.
    error IsNotAnAccountWithDebt();
    // Thrown when liquidation weights are above maximum value.
    error LiquidationWeightsTooHigh();
    // Thrown when a specific tranche does not exist.
    error NonExistingTranche();
    // Thrown when address has an open position
    error OpenPositionNonZero();
    // Thrown when the tranche of the lending pool already exists.
    error TrancheAlreadyExists();
    // Thrown when caller is not authorized.
    error Unauthorized();
    // Thrown when asset amount in input is zero.
    error ZeroAmount();
}

library TrancheErrors {
    // Thrown when a tranche is locked.
    error Locked();
    // Thrown when amount of shares would represent zero assets.
    error ZeroAssets();
    // Thrown when an auction is in process.
    error AuctionOngoing();
    // Thrown when caller is not valid.
    error Unauthorized();
    // Thrown when amount of asset would represent zero shares.
    error ZeroShares();
}
