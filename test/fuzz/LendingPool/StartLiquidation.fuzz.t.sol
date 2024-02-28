/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "startLiquidation" of contract "LendingPool".
 */
contract StartLiquidation_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_StartLiquidation_NonAccount(address nonAccount, address liquidationInitiator) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(nonAccount != address(liquidator));
        vm.assume(nonAccount != address(proxyAccount));

        // When: unprivilegedAddress settles a liquidation
        // Then: startLiquidation should revert with error LendingPool_OnlyLiquidator
        vm.startPrank(nonAccount);
        vm.expectRevert(IsNotAnAccountWithDebt.selector);
        pool.startLiquidation(liquidationInitiator, 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_StartLiquidation_NotAnAccountWithDebt(address liquidationInitiator) public {
        vm.startPrank(address(proxyAccount));
        vm.expectRevert(IsNotAnAccountWithDebt.selector);
        pool.startLiquidation(liquidationInitiator, 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_StartLiquidation_Paused(uint112 amountLoaned, address liquidationInitiator) public {
        // Given: Account has debt
        bytes3 emptyBytes4;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes4);

        // And: guardian soft start has passed
        vm.warp(35 days);
        vm.startPrank(users.guardian);
        pool.pause();

        vm.expectRevert(FunctionIsPaused.selector);
        vm.startPrank(address(proxyAccount));
        pool.startLiquidation(liquidationInitiator, 0);
        vm.stopPrank();
    }

    function testFuzz_Success_startLiquidation_NoOngoingAuctions(
        uint112 amountLoaned,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxReward,
        address liquidationInitiator
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes4;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= 1100);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes4);

        // And: Liquidation parameters are set.
        vm.prank(users.creatorAddress);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, 0, maxReward);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidator calls startLiquidation()
        vm.startPrank(address(proxyAccount));
        vm.expectEmit();
        emit AuctionStarted(address(proxyAccount), address(pool), amountLoaned + 1);
        pool.startLiquidation(liquidationInitiator, 0);
        vm.stopPrank();

        // Avoid stack too deep
        uint16 initiationWeightStack = initiationWeight;
        uint16 penaltyWeightStack = penaltyWeight;
        uint16 terminationWeightStack = terminationWeight;
        uint128 amountLoanedStack = amountLoaned;

        // Then: 1 auction should be in progress in LendingPool
        // And: auctionInProgress should be set to true in specific tranche (Junior as first impacted)
        assertEq(pool.getAuctionsInProgress(), 1);
        assertEq(jrTranche.auctionInProgress(), true);

        // And : Liquidation incentives should have been added to openDebt of Account
        uint256 initiationReward = uint256(amountLoanedStack + 1).mulDivDown(initiationWeightStack, 10_000);
        initiationReward = initiationReward > maxReward ? maxReward : initiationReward;
        uint256 liquidationPenalty = (uint256(amountLoanedStack + 1)).mulDivUp(penaltyWeightStack, 10_000);
        uint256 terminationReward = (uint256(amountLoanedStack + 1)).mulDivDown(terminationWeightStack, 10_000);
        terminationReward = terminationReward > maxReward ? maxReward : terminationReward;

        // And: Returned amount should be equal to maxReward
        assertEq(
            pool.getOpenPosition(address(proxyAccount)),
            (amountLoanedStack + 1) + initiationReward + liquidationPenalty + terminationReward
        );
    }

    function testFuzz_Success_startLiquidation_NoOngoingAuctions_NoTranches(
        uint112 amountLoaned,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxReward,
        address liquidationInitiator
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes4;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= 1100);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes4);

        // And: Liquidation parameters are set.
        vm.prank(users.creatorAddress);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, 0, maxReward);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // And: No tranches are available
        vm.startPrank(users.creatorAddress);
        address[] memory tranches = pool.getTranches();
        for (uint256 i = tranches.length; i > 0; i--) {
            pool.popTranche(i - 1, tranches[i - 1]);
        }
        vm.stopPrank();

        // When: Liquidator calls startLiquidation()
        vm.startPrank(address(proxyAccount));
        vm.expectEmit();
        emit AuctionStarted(address(proxyAccount), address(pool), amountLoaned + 1);
        pool.startLiquidation(liquidationInitiator, 0);
        vm.stopPrank();

        // Avoid stack too deep
        uint16 initiationWeightStack = initiationWeight;
        uint16 penaltyWeightStack = penaltyWeight;
        uint16 terminationWeightStack = terminationWeight;
        uint128 amountLoanedStack = amountLoaned;

        // Then: 1 auction should be in progress in LendingPool
        // And: auctionInProgress should not be set to true in any tranche, since there are none connected anymore
        assertEq(pool.getAuctionsInProgress(), 1);
        assertEq(jrTranche.auctionInProgress(), false);
        assertEq(srTranche.auctionInProgress(), false);

        // And : Liquidation incentives should have been added to openDebt of Account
        uint256 initiationReward = uint256(amountLoanedStack + 1).mulDivDown(initiationWeightStack, 10_000);
        initiationReward = initiationReward > maxReward ? maxReward : initiationReward;
        uint256 liquidationPenalty = (uint256(amountLoanedStack + 1)).mulDivUp(penaltyWeightStack, 10_000);
        uint256 terminationReward = (uint256(amountLoanedStack + 1)).mulDivDown(terminationWeightStack, 10_000);
        terminationReward = terminationReward > maxReward ? maxReward : terminationReward;

        // And: Returned amount should be equal to maxReward
        assertEq(
            pool.getOpenPosition(address(proxyAccount)),
            (amountLoanedStack + 1) + initiationReward + liquidationPenalty + terminationReward
        );
    }

    function testFuzz_Success_startLiquidation_OngoingAuctions(
        uint112 amountLoaned,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxReward,
        uint16 auctionsInProgress,
        address liquidationInitiator
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes4;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 150) * 100); // No overflow when debt is increased
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= 1100);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes4);

        // And: Liquidation parameters are set.
        vm.prank(users.creatorAddress);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, 0, maxReward);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        //And: an auction is ongoing
        vm.assume(auctionsInProgress > 0);
        vm.assume(auctionsInProgress < type(uint16).max);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator calls startLiquidation()
        vm.prank(address(proxyAccount));
        pool.startLiquidation(liquidationInitiator, 0);

        // Then: auctionsInProgress should increase
        assertEq(pool.getAuctionsInProgress(), auctionsInProgress + 1);
        // and the most junior tranche should be locked
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }
}
