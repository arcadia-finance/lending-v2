/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuctionNoRemainingValue" of contract "Liquidator".
 */

contract EndAuctionNoRemainingValue_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
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
    function testFuzz_Revert_EndAuctionNoRemainingValue_NotForSale() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator.endAuctionNoRemainingValue(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_EndAuctionNoRemainingValue_AccountValueIsNotZero(
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint256 amountLoaned
    ) public {
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 101, 300));
        vm.assume(minPriceMultiplier < 91);
        amountLoaned = bound(amountLoaned, 1, (type(uint128).max / 150) * 100); // No overflow when debt is increased

        vm.startPrank(users.creatorAddress);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
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

        // call to EndAuctionNoRemainingValue() should revert as the Account still has a remaining value
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_AccountValueIsNotZero.selector);
        liquidator.endAuctionNoRemainingValue(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Success_EndAuctionNoRemainingValue(
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint256 amountLoaned,
        address randomAddress
    ) public {
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 101, 300));
        vm.assume(minPriceMultiplier < 91);
        amountLoaned = bound(amountLoaned, 1, (type(uint128).max / 150) * 100); // No overflow when debt is increased

        vm.startPrank(users.creatorAddress);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
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

        // Set price of stable1 to 0.
        vm.prank(users.defaultTransmitter);
        mockOracles.stable1ToUsd.transmit(1);
        vm.stopPrank();

        // endAuctionNoRemainingValue() should succeed.
        vm.startPrank(randomAddress);
        vm.expectEmit();
        emit AuctionFinished(address(proxyAccount), address(creditorStable1), uint128(amountLoaned), 0, 0);
        liquidator.endAuctionNoRemainingValue(address(proxyAccount));
        vm.stopPrank();

        // The remaining tokens should be sent to protocol owner
        assertEq(mockERC20.stable1.balanceOf(liquidator.owner()), amountLoaned);
        assert(liquidator.getAuctionIsActive(address(proxyAccount)) == false);
    }

    // TODO: Solve this test, issue is bringing the account to liquidation state without using whole liquidty is not straight forward anymore - Zeki - 14/11/23
    //    function testFuzz_Success_EndAuctionProtocol(
    //        uint256 amountLoaned,
    //        uint8 initiatorRewardWeight,
    //        uint8 penaltyWeight,
    //        uint8 closingRewardWeight,
    //        uint80 maxInitiatorFee
    //    ) public {
    //        vm.assume(initiatorRewardWeight > 0);
    //        vm.assume(penaltyWeight > 0);
    //        vm.assume(closingRewardWeight > 0);
    //        vm.assume(maxInitiatorFee > 0);
    //        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 11);
    //        amountLoaned = bound(amountLoaned, 1001, (type(uint128).max / 150) * 100); // No overflow when debt is increased
    //        vm.startPrank(users.creatorAddress);
    //        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
    //
    //        // Set liquidations incentives weights
    //        vm.startPrank(users.creatorAddress);
    //        liquidator.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
    //        // Set max initiator fee
    //        pool.setMaxLiquidationFees(maxInitiatorFee, 0);
    //
    //        // Account has debt
    //        bytes3 emptyBytes3;
    //        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
    //        vm.startPrank(users.liquidityProvider);
    //        mockERC20.stable1.approve(address(pool), type(uint256).max);
    //        vm.startPrank(address(srTranche));
    //        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
    //        vm.startPrank(users.accountOwner);
    //        pool.borrow(amountLoaned / 3, address(proxyAccount), users.accountOwner, emptyBytes3);
    //
    //        // Calculate initiator reward
    //        uint256 initiatorReward = (amountLoaned + 1) * initiatorRewardWeight / 100;
    //        initiatorReward = initiatorReward > maxInitiatorFee ? maxInitiatorFee : initiatorReward;
    //
    //        // Account becomes Unhealthy (High Fixed cost will resul in account to be considered as unhealthy)
    //        //        debt.setRealisedDebt()
    //        //        debt.setRealisedDebt(uint256(amountLoaned - 10));
    //        //        stdstore.target(address(proxyAccount)).sig(proxyAccount.fixedLiquidationCost.selector).checked_write(
    //        //            badDebt
    //        //        );
    //        //        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(badDebt);
    //        proxyAccount.setFixedLiquidationCost(uint96(type(uint96).max - 1 ));
    //
    //        // Initiate liquidation
    //        liquidator.liquidateAccount(address(proxyAccount));
    //
    //        // Warp to a timestamp when auction is expired
    //        vm.warp(block.timestamp + liquidator.getCutoffTime() + 1);
    //
    //        // Set total bids on Account < amount owed by the account
    //        uint256 totalBids = (amountLoaned + 1) + initiatorReward - 1;
    //
    //        vm.startPrank(users.creatorAddress);
    //        vm.expectEmit();
    //        emit AuctionFinished(address(proxyAccount), address(pool), uint128(amountLoaned + 1), 0, 0);
    //        liquidator.endAuctionProtocol(address(proxyAccount), users.creatorAddress);
    //        vm.stopPrank();
    //    }
}
