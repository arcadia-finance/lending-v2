/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuctionProtocol" of contract "Liquidator".
 */

contract EndAuctionProtocol_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_endAuctionProtocol_NonOwner(address unprivilegedAddress_, address account_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.endAuctionProtocol(address(proxyAccount), account_);
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuctionProtocol_NotForSale(address account_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator.endAuctionProtocol(address(proxyAccount), account_);
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuctionProtocol_AuctionNotExpired(
        uint256 halfLifeTime,
        uint24 timePassed,
        uint256 cutoffTime,
        uint256 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint256 amountLoaned
    ) public {
        // Preprocess: Set up the fuzzed variables
        halfLifeTime = bound(halfLifeTime, (10 * 60) + 1, (8 * 60 * 60) - 1); // > 10 min && < 8 hours
        cutoffTime = bound(cutoffTime, (1 * 60 * 60) + 1, (8 * 60 * 60) - 1); // > 1 hour && < 8 hours
        vm.assume(timePassed <= cutoffTime);
        startPriceMultiplier = bound(startPriceMultiplier, 101, 300);
        vm.assume(minPriceMultiplier < 91);
        amountLoaned = bound(amountLoaned, 1, (type(uint128).max / 150) * 100); // No overflow when debt is increased

        vm.startPrank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(uint16(halfLifeTime), uint16(cutoffTime));
        liquidator.setStartPriceMultiplier(uint16(startPriceMultiplier));
        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(proxyAccount));

        // Warp to a timestamp when auction is not yet expired
        vm.warp(block.timestamp + timePassed);

        // call to endAuctionProtocol() should revert as the auction is not yet expired.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_AuctionNotExpired.selector);
        liquidator.endAuctionProtocol(address(proxyAccount), users.creatorAddress);
        vm.stopPrank();
    }

    function testFuzz_Success_EndAuctionProtocol(
        uint256 amountLoaned,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight,
        uint8 closingRewardWeight,
        uint80 maxInitiatorFee
    ) public {
        vm.assume(initiatorRewardWeight > 0);
        vm.assume(penaltyWeight > 0);
        vm.assume(closingRewardWeight > 0);
        vm.assume(maxInitiatorFee > 0);
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 11);
        amountLoaned = bound(amountLoaned, 1001, (type(uint128).max / 150) * 100); // No overflow when debt is increased

        // Set liquidations incentives weights
        vm.startPrank(users.creatorAddress);
        liquidator.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
        // Set max initiator fee
        pool.setMaxLiquidationFees(maxInitiatorFee, 0);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.startPrank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.startPrank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.startPrank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Calculate initiator reward
        uint256 initiatorReward = (amountLoaned + 1) * initiatorRewardWeight / 100;
        initiatorReward = initiatorReward > maxInitiatorFee ? maxInitiatorFee : initiatorReward;

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(proxyAccount));

        // Warp to a timestamp when auction is expired
        vm.warp(block.timestamp + liquidator.getCutoffTime() + 1);

        // Set total bids on Account < amount owed by the account
        uint256 totalBids = (amountLoaned + 1) + initiatorReward - 1;
        liquidator.setTotalBidsOnAccount(address(proxyAccount), totalBids);

        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit AuctionFinished(
            address(proxyAccount),
            address(pool),
            uint128(amountLoaned + 1),
            uint128(totalBids),
            uint128(amountLoaned + 1 + initiatorReward - totalBids)
        );
        liquidator.endAuctionProtocol(address(proxyAccount), users.creatorAddress);
        vm.stopPrank();
    }
}
