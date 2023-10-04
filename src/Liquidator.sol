/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LogExpMath } from "./libraries/LogExpMath.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { ERC20, SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { Owned } from "lib/solmate/src/auth/Owned.sol";
import { Errors } from "./libraries/Errors.sol";
/**
 * @title Liquidator
 * @author Pragma Labs
 * @notice The liquidator holds the execution logic and storage of all things related to liquidating Arcadia Accounts.
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 */

contract Liquidator is Owned {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The contract address of the Factory.
    address public immutable factory;
    // Sets the begin price of the auction.
    // Defined as a percentage of openDebt, 2 decimals precision -> 150 = 150%.
    uint16 public startPriceMultiplier;
    // Sets the minimum price the auction converges to.
    // Defined as a percentage of openDebt, 2 decimals precision -> 60 = 60%.
    uint8 public minPriceMultiplier;
    // The base of the auction price curve (exponential).
    // Determines how fast the auction price drops per second, 18 decimals precision.
    uint64 public base;
    // Maximum time that the auction declines, after which price is equal to the minimum price set by minPriceMultiplier.
    // Time in seconds, with 0 decimals precision.
    uint16 public cutoffTime;
    // Fee paid to the Liquidation Initiator.
    // Defined as a fraction of the openDebt with 2 decimals precision.
    // Absolute fee can be further capped to a max amount by the creditor.
    uint8 public initiatorRewardWeight;
    // Penalty the Account owner has to pay to the trusted Creditor on top of the open Debt for being liquidated.
    // Defined as a fraction of the openDebt with 2 decimals precision.
    uint8 public penaltyWeight;

    // Map Account => auctionInformation.
    mapping(address => AuctionInformation) public auctionInformation;

    // Struct with additional information about the auction of a specific Account.
    struct AuctionInformation {
        uint128 openDebt; // The open debt, same decimal precision as baseCurrency.
        uint32 startTime; // The timestamp the auction started.
        bool inAuction; // Flag indicating if the auction is still ongoing.
        uint80 maxInitiatorFee; // The max initiation fee, same decimal precision as baseCurrency.
        address baseCurrency; // The contract address of the baseCurrency.
        uint16 startPriceMultiplier; // 2 decimals precision.
        uint8 minPriceMultiplier; // 2 decimals precision.
        uint8 initiatorRewardWeight; // 2 decimals precision.
        uint8 penaltyWeight; // 2 decimals precision.
        uint16 cutoffTime; // Maximum time that the auction declines.
        address originalOwner; // The original owner of the Account.
        address trustedCreditor; // The creditor that issued the debt.
        uint64 base; // Determines how fast the auction price drops over time.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event WeightsSet(uint8 initiatorRewardWeight, uint8 penaltyWeight);
    event AuctionCurveParametersSet(uint64 base, uint16 cutoffTime);
    event StartPriceMultiplierSet(uint16 startPriceMultiplier);
    event MinimumPriceMultiplierSet(uint8 minPriceMultiplier);
    event AuctionStarted(address indexed account, address indexed creditor, address baseCurrency, uint128 openDebt);
    event AuctionFinished(
        address indexed account,
        address indexed creditor,
        address baseCurrency,
        uint128 price,
        uint128 badDebt,
        uint128 initiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder
    );

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(address factory_) Owned(msg.sender) {
        factory = factory_;
        initiatorRewardWeight = 1;
        penaltyWeight = 5;
        startPriceMultiplier = 150;
        minPriceMultiplier = 60;
        cutoffTime = 14_400; //4 hours
        base = 999_807_477_651_317_446; //3600s halflife, 14_400 cutoff
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the liquidation weights.
     * @param initiatorRewardWeight_ Fee paid to the Liquidation Initiator.
     * @param penaltyWeight_ Penalty paid by the Account owner to the trusted Creditor.
     * @dev Each weight has 2 decimals precision (50 equals 0,5 or 50%).
     */
    function setWeights(uint256 initiatorRewardWeight_, uint256 penaltyWeight_) external onlyOwner {
        if (initiatorRewardWeight_ + penaltyWeight_ > 11) revert Errors.Liquidator_WeightsTooHigh();

        initiatorRewardWeight = uint8(initiatorRewardWeight_);
        penaltyWeight = uint8(penaltyWeight_);

        emit WeightsSet(uint8(initiatorRewardWeight_), uint8(penaltyWeight_));
    }

    /**
     * @notice Sets the parameters (base and cutOffTime) of the auction price curve (decreasing power function).
     * @param halfLifeTime The base is not set directly, but it's derived from a more intuitive parameter, the halfLifeTime:
     * The time ΔT_hl (in seconds with 0 decimals) it takes for the power function to halve in value.
     * @dev The relation between the base and the halfLife time (ΔT_hl):
     * The power function is defined as: N(t) = N(0) * (1/2)^(t/ΔT_hl).
     * Or simplified: N(t) = N(O) * base^t => base = 1/[2^(1/ΔT_hl)].
     * @param cutoffTime_ The Maximum time that the auction declines,
     * after which price is equal to the minimum price set by minPriceMultiplier.
     * @dev Setting a very short cutoffTime can be used by rogue owners to rug the junior tranche!!
     * Therefore the cutoffTime has hardcoded constraints.
     * @dev All calculations are done with 18 decimals precision.
     */
    function setAuctionCurveParameters(uint16 halfLifeTime, uint16 cutoffTime_) external onlyOwner {
        //Checks that new parameters are within reasonable boundaries.
        if (halfLifeTime < 120) revert Errors.Liquidator_HalfLifeTimeTooLow(); // 2 minutes
        if (halfLifeTime > 28_800) revert Errors.Liquidator_HalfLifeTimeTooHigh(); // 8 hours
        if (cutoffTime_ < 3600) revert Errors.Liquidator_CutOffTooLow(); // 1 hour
        if (cutoffTime_ > 64_800) revert Errors.Liquidator_CutOffTooHigh(); // 18 hours

        //Derive base from the halfLifeTime.
        uint64 base_ = uint64(1e18 * 1e18 / LogExpMath.pow(2 * 1e18, 1e18 / halfLifeTime));

        //Check that LogExpMath.pow(base, timePassed) does not error at cutoffTime (due to numbers smaller than minimum precision).
        //Since LogExpMath.pow is a strictly decreasing function checking the power function at cutoffTime
        //guarantees that the function does not revert on all timestamps between start of the auction and the cutoffTime.
        LogExpMath.pow(base_, uint256(cutoffTime_) * 1e18);

        //Store the new parameters.
        base = base_;
        cutoffTime = cutoffTime_;

        emit AuctionCurveParametersSet(base_, cutoffTime_);
    }

    /**
     * @notice Sets the start price multiplier for the liquidator.
     * @param startPriceMultiplier_ The new start price multiplier, with 2 decimals precision.
     * @dev The start price multiplier is a multiplier that is used to increase the initial price of the auction.
     * Since the value of all assets are discounted with the liquidation factor, and because pricing modules will take a conservative
     * approach to price assets (eg. floor-prices for NFTs), the actual value of the assets being auctioned might be substantially higher
     * as the open debt. Hence the auction starts at a multiplier of the openDebt, but decreases rapidly (exponential decay).
     */
    function setStartPriceMultiplier(uint16 startPriceMultiplier_) external onlyOwner {
        if (startPriceMultiplier_ < 100) revert Errors.Liquidator_MultiplierTooLow();
        if (startPriceMultiplier_ > 301) revert Errors.Liquidator_MultiplierTooHigh();
        startPriceMultiplier = startPriceMultiplier_;

        emit StartPriceMultiplierSet(startPriceMultiplier_);
    }

    /**
     * @notice Sets the minimum price multiplier for the liquidator.
     * @param minPriceMultiplier_ The new minimum price multiplier, with 2 decimals precision.
     * @dev The minimum price multiplier sets a lower bound to which the auction price converges.
     */
    function setMinimumPriceMultiplier(uint8 minPriceMultiplier_) external onlyOwner {
        if (minPriceMultiplier_ > 91) revert Errors.Liquidator_MultiplierTooHigh();
        minPriceMultiplier = minPriceMultiplier_;

        emit MinimumPriceMultiplierSet(minPriceMultiplier_);
    }

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Called by a Creditor to start an auction to liquidate collateral of a Account.
     * @param account The contract address of the Account to liquidate.
     * @param openDebt The open debt taken by `originalOwner`.
     * @param maxInitiatorFee The upper limit for the fee paid to the Liquidation Initiator, set by the trusted Creditor.
     * @dev This function is called by the Creditor who is owed the debt issued against the Account.
     */
    function startAuction(address account, uint256 openDebt, uint80 maxInitiatorFee) public {
        if (auctionInformation[account].inAuction) revert Errors.AuctionOngoing();

        //Avoid possible re-entrance with the same Account address.
        auctionInformation[account].inAuction = true;

        //A malicious msg.sender can pass a self created contract as Account (not an actual Arcadia-Account) that returns true on liquidateAccount().
        //This would successfully start an auction, but as long as no collision with an actual Arcadia-Account contract address is found, this is not an issue.
        //The malicious non-Account would be in auction indefinitely, but does not block any 'real' auctions of Arcadia-Accounts.
        //One exception is if an attacker finds a pre-image of his custom contract with the same contract address of an Arcadia-Account (deployed via create2).
        //The attacker could in theory: start auction of malicious contract, self-destruct and create Arcadia-Account with identical contract address.
        //This Account could never be auctioned since auctionInformation[account].inAuction would return true.
        //Finding such a collision requires finding a collision of the keccak256 hash function.
        (address originalOwner, address baseCurrency, address trustedCreditor) =
            IAccount(account).liquidateAccount(openDebt);

        //Check that msg.sender is indeed the Creditor of the Account.
        if (trustedCreditor != msg.sender) revert Errors.Unauthorized();

        auctionInformation[account].openDebt = uint128(openDebt);
        auctionInformation[account].startTime = uint32(block.timestamp);
        auctionInformation[account].maxInitiatorFee = maxInitiatorFee;
        auctionInformation[account].baseCurrency = baseCurrency;
        auctionInformation[account].startPriceMultiplier = startPriceMultiplier;
        auctionInformation[account].minPriceMultiplier = minPriceMultiplier;
        auctionInformation[account].initiatorRewardWeight = initiatorRewardWeight;
        auctionInformation[account].penaltyWeight = penaltyWeight;
        auctionInformation[account].cutoffTime = cutoffTime;
        auctionInformation[account].originalOwner = originalOwner;
        auctionInformation[account].trustedCreditor = msg.sender;
        auctionInformation[account].base = base;

        emit AuctionStarted(account, trustedCreditor, baseCurrency, uint128(openDebt));
    }

    /**
     * @notice Function returns the current auction price of a Account.
     * @param account The contract address of the Account.
     * @return price the total price for which the Account can be purchased.
     * @return inAuction returns false when the Account is not being auctioned.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the Account
     * and immediately ends the auction.
     */
    function getPriceOfAccount(address account) public view returns (uint256 price, bool inAuction) {
        inAuction = auctionInformation[account].inAuction;

        if (!inAuction) {
            return (0, false);
        }

        price = _calcPriceOfAccount(auctionInformation[account]);
    }

    /**
     * @notice Function returns the current auction price given time passed and the openDebt.
     * @param auctionInfo The auction information.
     * @return price The total price for which the Account can be purchased.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the Account and immediately ends the auction.
     * @dev Price P(t) decreases exponentially over time: P(t) = openDebt * [(SPM - MPM) * base^t + MPM]:
     * SPM: The startPriceMultiplier defines the initial price: P(0) = openDebt * SPM (2 decimals precision).
     * MPM: The minPriceMultiplier defines the asymptotic end price for P(∞) = openDebt * MPM (2 decimals precision).
     * base: defines how fast the exponential curve decreases (18 decimals precision).
     * t: time passed since start auction (in seconds, 18 decimals precision).
     * @dev LogExpMath was made in solidity 0.7, where operations were unchecked.
     */
    function _calcPriceOfAccount(AuctionInformation memory auctionInfo) internal view returns (uint256 price) {
        //Time passed is a difference of two Uint32 -> can't overflow.
        uint256 timePassed;
        unchecked {
            timePassed = block.timestamp - auctionInfo.startTime; //time duration in seconds.

            if (timePassed > auctionInfo.cutoffTime) {
                //Cut-off time passed -> return the minimal value defined by minPriceMultiplier (2 decimals precision).
                //No overflow possible: uint128 * uint8.
                price = uint256(auctionInfo.openDebt) * auctionInfo.minPriceMultiplier / 1e2;
            } else {
                //Bring to 18 decimals precision for LogExpMath.pow()
                //No overflow possible: uin32 * uint64.
                timePassed = timePassed * 1e18;

                //pow(base, timePassed) has 18 decimals and is strictly smaller than 1 (-> smaller as 1e18).
                //No overflow possible: uint128 * uint64 * uint8.
                //Multipliers have 2 decimals precision and LogExpMath.pow() has 18 decimals precision,
                //hence we need to divide the result by 1e20.
                price = auctionInfo.openDebt
                    * (
                        LogExpMath.pow(auctionInfo.base, timePassed)
                            * (auctionInfo.startPriceMultiplier - auctionInfo.minPriceMultiplier)
                            + 1e18 * uint256(auctionInfo.minPriceMultiplier)
                    ) / 1e20;
            }
        }
    }

    /**
     * @notice Function a user (the bidder) calls to buy the Account and end the auction.
     * @param account The contract address of the Account.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the Account
     * And immediately ends the auction.
     */
    function buyAccount(address account) external {
        AuctionInformation memory auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert Errors.Liquidator_NotForSale();

        uint256 priceOfAccount = _calcPriceOfAccount(auctionInformation_);
        //Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation[account].inAuction = false;

        //Transfer funds, equal to the current auction price from the bidder to the Creditor contract.
        //The bidder should have approved the Liquidation contract for at least an amount of priceOfAccount.
        ERC20(auctionInformation_.baseCurrency).safeTransferFrom(
            msg.sender, auctionInformation_.trustedCreditor, priceOfAccount
        );

        (uint256 badDebt, uint256 liquidationInitiatorReward, uint256 liquidationPenalty, uint256 remainder) =
        calcLiquidationSettlementValues(
            auctionInformation_.openDebt,
            priceOfAccount,
            auctionInformation_.maxInitiatorFee,
            auctionInformation_.initiatorRewardWeight,
            auctionInformation_.penaltyWeight
        );

        ILendingPool(auctionInformation_.trustedCreditor).settleLiquidation(
            account,
            auctionInformation_.originalOwner,
            badDebt,
            liquidationInitiatorReward,
            liquidationPenalty,
            remainder
        );

        //Change ownership of the auctioned Account to the bidder.
        IFactory(factory).safeTransferFrom(address(this), msg.sender, account);

        emit AuctionFinished(
            account,
            auctionInformation_.trustedCreditor,
            auctionInformation_.baseCurrency,
            uint128(priceOfAccount),
            uint128(badDebt),
            uint128(liquidationInitiatorReward),
            uint128(liquidationPenalty),
            uint128(remainder)
        );
    }

    /**
     * @notice End an unsuccessful auction after the cutoffTime has passed.
     * @param account The contract address of the Account.
     * @param to The address to which the Account will be transferred.
     * @dev This is an emergency process, and can not be triggered under normal operation.
     * The auction will be stopped and the Account will be transferred to the provided address.
     * The junior tranche of the liquidity pool will pay for the bad debt.
     * The protocol will sell/auction the Account in another way to recover the debt.
     * The protocol will later "donate" these proceeds back to the junior tranche and/or other
     * impacted Tranches, this last step is not enforced by the smart contracts.
     * While this process is not fully trustless, it is the only way to solve an extreme unhappy flow,
     * where an auction did not end within cutoffTime (due to market or technical reasons).
     */
    function endAuction(address account, address to) external onlyOwner {
        AuctionInformation memory auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert Errors.Liquidator_NotForSale();

        uint256 timePassed;
        unchecked {
            timePassed = block.timestamp - auctionInformation_.startTime;
        }
        if (timePassed <= cutoffTime) revert Errors.Liquidator_AuctionNotExpired();

        //Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation[account].inAuction = false;

        (uint256 badDebt, uint256 liquidationInitiatorReward, uint256 liquidationPenalty, uint256 remainder) =
        calcLiquidationSettlementValues(
            auctionInformation_.openDebt,
            0,
            auctionInformation_.maxInitiatorFee,
            auctionInformation_.initiatorRewardWeight,
            auctionInformation_.penaltyWeight
        ); //priceOfAccount is zero.

        ILendingPool(auctionInformation_.trustedCreditor).settleLiquidation(
            account,
            auctionInformation_.originalOwner,
            badDebt,
            liquidationInitiatorReward,
            liquidationPenalty,
            remainder
        );

        //Change ownership of the auctioned account to the protocol owner.
        IFactory(factory).safeTransferFrom(address(this), to, account);

        emit AuctionFinished(
            account,
            auctionInformation_.trustedCreditor,
            auctionInformation_.baseCurrency,
            0,
            uint128(badDebt),
            uint128(liquidationInitiatorReward),
            uint128(liquidationPenalty),
            uint128(remainder)
        );
    }

    /**
     * @notice Calculates how the liquidation needs to be further settled with the Creditor, Original owner and Service providers.
     * @param openDebt The open debt taken by `originalOwner`.
     * @param priceOfAccount The final selling price of the Account.
     * @return badDebt The amount of liabilities that was not recouped by the auction.
     * @return liquidationInitiatorReward The Reward for the Liquidation Initiator.
     * @return liquidationPenalty The additional penalty the `originalOwner` has to pay to the protocol.
     * @return remainder Any funds remaining after the auction are returned back to the `originalOwner`.
     * @dev All values are denominated in the baseCurrency of the Account.
     * @dev We use a dutch auction: price constantly decreases and the first bidder buys the account
     * And immediately ends the auction.
     */
    function calcLiquidationSettlementValues(
        uint256 openDebt,
        uint256 priceOfAccount,
        uint88 maxInitiatorFee,
        uint8 initiatorRewardWeight_,
        uint8 penaltyWeight_
    )
        public
        pure
        returns (uint256 badDebt, uint256 liquidationInitiatorReward, uint256 liquidationPenalty, uint256 remainder)
    {
        //openDebt is a uint128 -> all calculations can be unchecked.
        unchecked {
            //Liquidation Initiator Reward is always paid out, independent of the final auction price.
            //The reward is calculated as a fixed percentage of open debt, but capped on the upside (maxInitiatorFee).
            liquidationInitiatorReward = openDebt * initiatorRewardWeight_ / 100;
            liquidationInitiatorReward =
                liquidationInitiatorReward > maxInitiatorFee ? maxInitiatorFee : liquidationInitiatorReward;

            //Final Auction price should at least cover the original debt and Liquidation Initiator Reward.
            //Otherwise there is bad debt.
            if (priceOfAccount < openDebt + liquidationInitiatorReward) {
                badDebt = openDebt + liquidationInitiatorReward - priceOfAccount;
            } else {
                liquidationPenalty = openDebt * penaltyWeight_ / 100;
                remainder = priceOfAccount - openDebt - liquidationInitiatorReward;

                //Check if the remainder can cover the full liquidation penalty.
                if (remainder > liquidationPenalty) {
                    //If yes, calculate the final remainder.
                    remainder -= liquidationPenalty;
                } else {
                    //If not, there is no remainder for the originalOwner.
                    liquidationPenalty = remainder;
                    remainder = 0;
                }
            }
        }
    }
}
