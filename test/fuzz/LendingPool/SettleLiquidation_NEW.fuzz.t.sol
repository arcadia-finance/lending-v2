/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "settleLiquidation" of contract "LendingPool".
 */
contract SettleLiquidation_NEW_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
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
    function testFuzz_Revert_settleLiquidation_NEW_Unauthorised(
        uint128 badDebt,
        address liquidationInitiator,
        uint128 liquidationInitiatorReward,
        address auctionTerminator,
        uint128 auctionTerminationReward,
        uint128 liquidationPenalty,
        uint128 remainder,
        address unprivilegedAddress_
    ) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress_ != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(LendingPool_OnlyLiquidator.selector);
        pool.settleLiquidation_NEW(
            address(proxyAccount),
            users.accountOwner,
            badDebt,
            liquidationInitiator,
            liquidationInitiatorReward,
            auctionTerminator,
            auctionTerminationReward,
            liquidationPenalty,
            remainder
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_settleLiquidation_NEW_ExcessBadDebt(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 badDebt,
        address liquidationInitiator,
        address auctionTerminator
    ) public {
        // Given: There is liquidity and bad debt
        vm.assume(liquidityJunior > 0);
        vm.assume(liquiditySenior > 0);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(badDebt > totalAmount + 2); // Bad debt should be excess since initiator and terminator rewards are 1 and 1 respectively, it should be added to make the baddebt excess
        vm.assume(badDebt > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, users.liquidityProvider);

        // And: There is an auction in progress
        pool.setAuctionsInProgress(2);

        // And:Account has a debt
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxyAccount)).checked_write(
            badDebt
        );
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(badDebt);
        pool.setRealisedDebt(badDebt);

        // When Then: settleLiquidation should fail if there is more debt than the liquidity
        vm.startPrank(address(liquidator));
        vm.expectRevert(stdError.arithmeticError);
        pool.settleLiquidation_NEW(
            address(proxyAccount), users.accountOwner, badDebt, liquidationInitiator, 1, auctionTerminator, 1, 0, 0
        );
        vm.stopPrank();
    }

    function testFuzz_Success_settleLiquidation_NEW_Surplus(
        uint128 liquidity,
        address liquidationInitiator,
        uint128 liquidationInitiatorReward,
        address auctionTerminator,
        uint128 auctionTerminationReward,
        uint128 liquidationPenalty,
        uint128 remainder
    ) public {
        vm.assume(liquidationInitiatorReward > 0);
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) + uint256(liquidationPenalty)
                + uint256(auctionTerminationReward) < type(uint128).max - uint256(remainder)
        );
        vm.assume(remainder >= auctionTerminationReward + liquidationPenalty);

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation_NEW(
            address(proxyAccount),
            users.accountOwner,
            0,
            liquidationInitiator,
            liquidationInitiatorReward,
            auctionTerminator,
            auctionTerminationReward,
            liquidationPenalty,
            remainder
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
        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);
        // Then: Terminator should be able to claim his rewards for liquidation termination
        assertEq(pool.realisedLiquidityOf(auctionTerminator), auctionTerminationReward);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
        // And: The jr tranche will get its part of the liquidationpenalty
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), liqPenaltyJunior);
        // And: treasury will get its part of the liquidationpenalty
        assertEq(pool.realisedLiquidityOf(address(treasury)), liqPenaltyTreasury);
        // And: The remaindershould be claimable by the original owner
        assertEq(
            pool.realisedLiquidityOf(users.accountOwner), remainder - auctionTerminationReward - liquidationPenalty
        );
        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), liquidity + liquidationInitiatorReward + remainder);

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidation_NEW_remainderHigherThanTerminationReward(
        uint128 liquidity,
        address liquidationInitiator,
        uint80 liquidationInitiatorReward,
        address auctionTerminator,
        uint80 auctionTerminationReward,
        uint128 liquidationPenalty,
        uint256 remainder
    ) public {
        vm.assume(liquidationInitiator != auctionTerminator);
        vm.assume(liquidationInitiator != address(srTranche));
        vm.assume(liquidationInitiator != address(jrTranche));
        vm.assume(liquidationInitiator != address(liquidator));
        vm.assume(liquidity > 0);
        // Here we validate the scenario in which the remaining amount to be distributed after a liquidation is > terminationReward but does not cover all of the liquidation fees.
        vm.assume(liquidationInitiatorReward > 0);
        // Otherwise we can have max is less than min value in bound.
        vm.assume(liquidationPenalty > 1);
        vm.assume(remainder <= type(uint128).max);
        remainder = bound(
            uint256(remainder),
            uint256(auctionTerminationReward) + 1,
            uint256(auctionTerminationReward) + uint256(liquidationPenalty) - 1
        );
        vm.assume(uint256(liquidity) + uint256(liquidationInitiatorReward) + uint256(remainder) < type(uint128).max);

        assert(remainder > auctionTerminationReward);
        assert(remainder < uint256(auctionTerminationReward) + uint256(liquidationPenalty));

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation_NEW(
            address(proxyAccount),
            users.accountOwner,
            0,
            liquidationInitiator,
            liquidationInitiatorReward,
            auctionTerminator,
            uint256(auctionTerminationReward),
            liquidationPenalty,
            remainder
        );

        // As all liquidation penalty can not be distributed
        uint256 liquidationFee = remainder - auctionTerminationReward;

        // round up
        uint256 liqPenaltyTreasury =
            liquidationFee * pool.getLiquidationWeightTreasury() / pool.getTotalLiquidationWeight();
        if (
            uint256(liqPenaltyTreasury) * pool.getTotalLiquidationWeight()
                < liquidationFee * pool.getLiquidationWeightTreasury()
        ) {
            liqPenaltyTreasury++;
        }

        uint256 liqPenaltyJunior =
            liquidationFee * pool.getLiquidationWeightTranches(1) / pool.getTotalLiquidationWeight();
        if (
            uint256(liqPenaltyTreasury) * pool.getTotalLiquidationWeight()
                < liquidationFee * pool.getLiquidationWeightTranches(1)
        ) {
            liqPenaltyTreasury--;
        }

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);
        // Then: Terminator should be able to claim his rewards for liquidation termination
        assertEq(pool.realisedLiquidityOf(auctionTerminator), auctionTerminationReward);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
        // And: The jr tranche will get its part of the liquidation penalty
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), liqPenaltyJunior);
        // And: treasury will get its part of the liquidation penalty
        assertEq(pool.realisedLiquidityOf(address(treasury)), liqPenaltyTreasury);
        // And: The remainder should be claimable by the original owner
        assertEq(pool.realisedLiquidityOf(users.accountOwner), 0);
        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), liquidity + liquidationInitiatorReward + remainder);

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidation_NEW_remainderLowerThanTerminationReward(
        uint128 liquidity,
        address liquidationInitiator,
        uint80 liquidationInitiatorReward,
        address auctionTerminator,
        uint80 auctionTerminationReward,
        uint128 liquidationPenalty,
        uint128 remainder
    ) public {
        // Here we validate the scenario in which the remaining amount to be distributed after a liquidation is < terminationReward
        vm.assume(liquidationInitiatorReward > 0);
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) + uint256(liquidationPenalty)
                + uint256(auctionTerminationReward) < type(uint128).max - uint256(remainder)
        );
        vm.assume(remainder <= auctionTerminationReward);

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation_NEW(
            address(proxyAccount),
            users.accountOwner,
            0,
            liquidationInitiator,
            liquidationInitiatorReward,
            auctionTerminator,
            auctionTerminationReward,
            liquidationPenalty,
            remainder
        );

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);
        // Then: Terminator should be able to claim his rewards for liquidation termination
        assertEq(pool.realisedLiquidityOf(auctionTerminator), remainder);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
        // And: The jr tranche will get its part of the liquidation penalty
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        // And: treasury will get its part of the liquidation penalty
        assertEq(pool.realisedLiquidityOf(address(treasury)), 0);
        // And: The remainder should be claimable by the original owner
        assertEq(pool.realisedLiquidityOf(users.accountOwner), 0);
        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), liquidity + liquidationInitiatorReward + remainder);

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidation_NEW_BadDebt_ProcessDefault(
        uint128 liquidity,
        uint128 badDebt,
        address liquidationInitiator,
        uint128 liquidationInitiatorReward,
        address auctionTerminator,
        uint128 auctionTerminationReward,
        uint128 liquidationPenalty,
        uint128 remainder
    ) public {
        vm.assume(badDebt > 0);
        vm.assume(badDebt <= type(uint128).max);
        vm.assume(liquidationInitiatorReward > 0);
        vm.assume(liquidationPenalty > 0);
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) + uint256(liquidationPenalty)
                + uint256(auctionTerminationReward) <= uint256(badDebt) + type(uint128).max
        );
        vm.assume(liquidity >= badDebt);
        vm.assume(uint256(badDebt) >= uint256(liquidationPenalty) + uint256(auctionTerminationReward));

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        // And : The Account has some debt
        depositTokenInAccount(proxyAccount, mockERC20.stable1, liquidity);
        vm.prank(users.accountOwner);
        pool.borrow(
            uint256(liquidationPenalty) + uint256(auctionTerminationReward),
            address(proxyAccount),
            users.accountOwner,
            emptyBytes3
        );

        // Pool is inAuction
        pool.setAuctionsInProgress(2);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation_NEW(
            address(proxyAccount),
            users.accountOwner,
            uint256(badDebt),
            liquidationInitiator,
            uint256(liquidationInitiatorReward),
            auctionTerminator,
            uint256(auctionTerminationReward),
            uint256(liquidationPenalty),
            uint256(remainder)
        );

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);

        // And: Terminator should not be able to claim his rewards for liquidation termination
        assertEq(pool.realisedLiquidityOf(auctionTerminator), 0);

        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity - badDebt);
    }

    function testFuzz_Success_settleLiquidation_NEW_NoBadDebt_RemainderIsHigherThanRewards(
        uint128 liquidity,
        address liquidationInitiator,
        uint80 liquidationInitiatorReward,
        address auctionTerminator,
        uint80 auctionTerminationReward,
        uint128 liquidationPenalty,
        uint128 remainder
    ) public {
        vm.assume(liquidity > 1);
        vm.assume(
            uint256(liquidity) + uint256(liquidationInitiatorReward) + uint256(auctionTerminationReward)
                + uint256(liquidationPenalty) <= (type(uint128).max / 150) * 100
        );
        vm.assume(uint256(remainder) > uint256(auctionTerminationReward) + uint256(liquidationPenalty));
        vm.assume(remainder <= liquidity);

        // Given: Account has collateral debt and pool has liquidity
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, liquidity);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(liquidity, address(proxyAccount), users.accountOwner, emptyBytes3);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(liquidity + 1));

        // Pool is inAuction
        pool.setAuctionsInProgress(2);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation_NEW(
            address(proxyAccount),
            users.accountOwner,
            0,
            liquidationInitiator,
            liquidationInitiatorReward,
            auctionTerminator,
            auctionTerminationReward,
            liquidationPenalty,
            remainder
        );

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);
        // And: Terminator should be able to claim his rewards for liquidation termination
        assertEq(pool.realisedLiquidityOf(auctionTerminator), auctionTerminationReward);
        // And: The liquidity amount from the most senior tranche should remain the same

        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
    }
}
