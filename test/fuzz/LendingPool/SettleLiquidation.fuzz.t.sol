/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";
import { Errors } from "../../utils/Errors.sol";

/**
 * @notice Fuzz tests for the function "settleLiquidation" of contract "LendingPool".
 */
contract SettleLiquidation_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_settleLiquidation_Unauthorised(
        uint128 badDebt,
        uint128 liquidationInitiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder,
        address unprivilegedAddress_
    ) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress_ != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(Errors.LendingPool_OnlyLiquidator.selector);
        pool.settleLiquidation(
            address(proxyAccount),
            users.accountOwner,
            badDebt,
            liquidationInitiatorReward,
            liquidationPenalty,
            remainder
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_settleLiquidation_ExcessBadDebt(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 badDebt
    ) public {
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(badDebt > totalAmount);
        vm.assume(badDebt > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, users.liquidityProvider);

        vm.expectRevert(stdError.arithmeticError);
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(proxyAccount), users.accountOwner, badDebt, 0, 0, 0);
    }

    function testFuzz_Success_settleLiquidation_Surplus(
        uint128 liquidity,
        uint128 liquidationInitiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder,
        address initiator
    ) public {
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) <= type(uint128).max - uint256(liquidationPenalty)
        );
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) + uint256(liquidationPenalty)
                <= type(uint128).max - uint256(remainder)
        );

        vm.assume(liquidationInitiatorReward > 0);
        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setLiquidationInitiator(address(proxyAccount), initiator);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, 0, liquidationInitiatorReward, liquidationPenalty, remainder
        );

        // round up
        uint256 liqPenaltyTreasury =
            uint256(liquidationPenalty) * pool.getLiquidationWeightTreasury() / pool.getTotalLiquidationWeight();
        if (
            uint256(liqPenaltyTreasury) * pool.getTotalLiquidationWeight()
                < uint256(liquidationPenalty) * pool.getLiquidationWeightTreasury()
        ) {
            liqPenaltyTreasury++;
        }

        uint256 liqPenaltyJunior =
            uint256(liquidationPenalty) * pool.getLiquidationWeightTranches(1) / pool.getTotalLiquidationWeight();
        if (
            uint256(liqPenaltyTreasury) * pool.getTotalLiquidationWeight()
                < uint256(liquidationPenalty) * pool.getLiquidationWeightTranches(1)
        ) {
            liqPenaltyTreasury--;
        }

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(initiator), liquidationInitiatorReward);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
        // And: The jr tranche will get its part of the liquidationpenalty
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), liqPenaltyJunior);
        // And: treasury will get its part of the liquidationpenalty
        assertEq(pool.realisedLiquidityOf(address(treasury)), liqPenaltyTreasury);
        // And: The remaindershould be claimable by the original owner
        assertEq(pool.realisedLiquidityOf(users.accountOwner), remainder);
        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), liquidity + liquidationInitiatorReward + liquidationPenalty + remainder);

        //ToDo: check emit Tranche
        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidation_ProcessDefault(
        uint128 liquidity,
        uint128 badDebt,
        uint128 liquidationInitiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder,
        address initiator
    ) public {
        vm.assume(uint256(liquidity) + uint256(liquidationInitiatorReward) <= type(uint128).max + uint256(badDebt));
        // Given: provided liquidity is bigger than the default amount (Should always be true)
        vm.assume(liquidity >= badDebt);
        // And: badDebt is bigger than 0
        vm.assume(badDebt > 0);
        // And: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setLiquidationInitiator(address(proxyAccount), initiator);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(
            address(proxyAccount),
            users.accountOwner,
            badDebt,
            liquidationInitiatorReward,
            liquidationPenalty,
            remainder
        );

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(initiator), liquidationInitiatorReward);

        // And: The badDebt amount should be discounted from the most junior tranche
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity - badDebt);

        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), uint256(liquidity) + liquidationInitiatorReward - badDebt);
    }

    function testFuzz_Success_settleLiquidation_MultipleAuctionsOngoing(uint128 liquidity, uint16 auctionsInProgress)
        public
    {
        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        // And multiple auctions are ongoing
        vm.assume(auctionsInProgress > 1);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(proxyAccount), users.accountOwner, 0, 0, 0, 0);

        //ToDo: check emit Tranche
        assertEq(pool.getAuctionsInProgress(), auctionsInProgress - 1);
        assertTrue(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidation_ProcessDefaultNoTrancheWiped(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 badDebt
    ) public {
        vm.assume(liquiditySenior <= type(uint128).max - liquidityJunior);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(badDebt < liquidityJunior);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, users.liquidityProvider);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(proxyAccount), users.accountOwner, badDebt, 0, 0, 0);

        // Then: realisedLiquidityOf for srTranche should be liquiditySenior, realisedLiquidityOf jrTranche should be liquidityJunior minus badDebt,
        // totalRealisedLiquidity should be equal to totalAmount minus badDebt
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquiditySenior);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), liquidityJunior - badDebt);
        assertEq(pool.totalRealisedLiquidity(), totalAmount - badDebt);
    }

    function testFuzz_Success_settleLiquidation_ProcessDefaultOneTrancheWiped(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 badDebt,
        uint16 auctionsInProgress
    ) public {
        vm.assume(badDebt > 0);
        vm.assume(liquiditySenior <= type(uint128).max - liquidityJunior);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(badDebt < totalAmount);
        vm.assume(badDebt >= liquidityJunior);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, users.liquidityProvider);

        // And multiple auctions are ongoing
        vm.assume(auctionsInProgress > 1);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // Before settling the liquidation that will wipe out the jr tranche, we ensure that the jr tranche has an interestWeight > 0
        // This will ensure our testing below of liquidityOf() is valid
        pool.setInterestWeight(address(jrTranche), 100);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(proxyAccount), users.accountOwner, badDebt, 0, 0, 0);

        // Then: supplyBalances srTranche should be totalAmount minus badDebt, supplyBalances jrTranche should be 0,
        // totalSupply should be equal to totalAmount minus badDebt, isTranche for jrTranche should return false
        assertEq(pool.realisedLiquidityOf(address(srTranche)), totalAmount - badDebt);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        assertEq(pool.totalRealisedLiquidity(), totalAmount - badDebt);
        assertFalse(pool.getIsTranche(address(jrTranche)));

        //ToDo: check emits Tranche
        assertEq(pool.getAuctionsInProgress(), auctionsInProgress - 1);
        assertFalse(jrTranche.auctionInProgress());
        assertTrue(srTranche.auctionInProgress());

        // Here we ensure that interests are available, but liquidityOf() should return 0 for junior tranche as it was wiped.
        pool.setInterestRate(10 ether);
        pool.setRealisedDebt(10_000 ether);
        vm.warp(block.timestamp + 30 days);
        assertEq(pool.liquidityOf(address(jrTranche)), 0);
    }

    function testFuzz_Success_settleLiquidation_ProcessDefaultAllTranchesWiped(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint16 auctionsInProgress
    ) public {
        vm.assume(liquiditySenior <= type(uint128).max - liquidityJunior);
        uint128 badDebt = liquiditySenior + liquidityJunior;
        vm.assume(badDebt > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, users.liquidityProvider);

        // And multiple auctions are ongoing
        vm.assume(auctionsInProgress > 1);
        pool.setAuctionsInProgress(auctionsInProgress);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(address(proxyAccount), users.accountOwner, badDebt, 0, 0, 0);

        // Then: supplyBalances srTranche should be totalAmount minus badDebt, supplyBalances jrTranche should be 0,
        // totalSupply should be equal to totalAmount minus badDebt, isTranche for jrTranche should return false
        assertEq(pool.realisedLiquidityOf(address(srTranche)), 0);
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        assertEq(pool.totalRealisedLiquidity(), 0);
        assertFalse(pool.getIsTranche(address(jrTranche)));
        assertFalse(pool.getIsTranche(address(srTranche)));

        //ToDo: check emits Tranche
        assertEq(pool.getAuctionsInProgress(), auctionsInProgress - 1);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }
}
