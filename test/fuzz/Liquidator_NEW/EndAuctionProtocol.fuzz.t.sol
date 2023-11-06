/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test_NEW } from "./_Liquidator.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuctionProtocol" of contract "Liquidator".
 */

contract EndAuctionProtocol_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test_NEW {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test_NEW.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_endAuctionProtocol_NonOwner(address unprivilegedAddress_, address account_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator_new.endAuctionProtocol(address(proxyAccount), account_);
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuctionProtocol_NotForSale(address account_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator_new.endAuctionProtocol(address(proxyAccount), account_);
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
        liquidator_new.setAuctionCurveParameters(uint16(halfLifeTime), uint16(cutoffTime));
        liquidator_new.setStartPriceMultiplier(uint16(startPriceMultiplier));
        liquidator_new.setMinimumPriceMultiplier(minPriceMultiplier);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool_new.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt_new.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator_new.liquidateAccount(address(proxyAccount));

        // Warp to a timestamp when auction is not yet expired
        vm.warp(block.timestamp + timePassed);

        // call to endAuctionProtocol() should revert as the auction is not yet expired.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_AuctionNotExpired.selector);
        liquidator_new.endAuctionProtocol(address(proxyAccount), users.creatorAddress);
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
        liquidator_new.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
        // Set max initiator fee
        pool_new.setMaxLiquidationFees(maxInitiatorFee, 0);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.startPrank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.startPrank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.startPrank(users.accountOwner);
        pool_new.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Calculate initiator reward
        uint256 initiatorReward = amountLoaned * initiatorRewardWeight / 100;
        initiatorReward = initiatorReward > maxInitiatorFee ? maxInitiatorFee : initiatorReward;

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt_new.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator_new.liquidateAccount(address(proxyAccount));

        // Warp to a timestamp when auction is expired
        vm.warp(block.timestamp + liquidator_new.getCutoffTime() + 1);

        // Set total bids on Account < amount owed by the account
        uint256 totalBids = amountLoaned + initiatorReward - 1;
        liquidator_new.setTotalBidsOnAccount(address(proxyAccount), totalBids);

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AuctionFinished_NEW(
            address(proxyAccount),
            address(pool_new),
            address(0),
            uint128(totalBids),
            uint128((amountLoaned + 1) + initiatorReward - totalBids),
            uint128(initiatorReward),
            0,
            0,
            0
        );
        liquidator_new.endAuctionProtocol(address(proxyAccount), users.creatorAddress);
        vm.stopPrank();
    }
}
