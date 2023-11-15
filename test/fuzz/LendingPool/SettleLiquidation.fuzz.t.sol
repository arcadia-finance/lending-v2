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
        uint128 startDebt,
        address liquidationInitiator,
        address auctionTerminator,
        uint128 remainder,
        address unprivilegedAddress_
    ) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress_ != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(LendingPool_OnlyLiquidator.selector);
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, startDebt, liquidationInitiator, auctionTerminator, 0
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_settleLiquidation_ExcessBadDebt(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 startDebt,
        address liquidationInitiator,
        address auctionTerminator
    ) public {
        // Given: There is liquidity and bad debt
        vm.assume(liquidityJunior > 100);
        vm.assume(liquiditySenior > 100);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(startDebt > totalAmount + 2); // Bad debt should be excess since initiator and terminator rewards are 1 and 1 respectively, it should be added to make the baddebt excess
        // TODO: Fix this shortcut, why uint128 max fails with different error at maxWithdraw - Zeki - 14/11/23
        vm.assume(startDebt <= type(uint128).max / 2);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, users.liquidityProvider);

        // And: There is an auction in progress
        pool.setAuctionsInProgress(2);

        (uint256 liquidationInitiatorReward, uint256 closingReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt);
        // And:Account has a debt
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxyAccount)).checked_write(
            startDebt + liquidationInitiatorReward + closingReward + liquidationPenalty
        );
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(
            startDebt + liquidationInitiatorReward + closingReward + liquidationPenalty
        );

        pool.setRealisedDebt(startDebt + liquidationInitiatorReward + closingReward + liquidationPenalty);

        // When Then: settleLiquidation should fail if there is more debt than the liquidity
        vm.startPrank(address(liquidator));
        vm.expectRevert(stdError.arithmeticError);
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, startDebt, liquidationInitiator, auctionTerminator, 0
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_settleLiquidation_SurplusWithOpenDebt(
        uint128 startDebt,
        uint128 liquidity,
        address liquidationInitiator,
        address auctionTerminator,
        uint128 surplus
    ) public {
        vm.assume(startDebt > 0);
        vm.assume(surplus > 0);
        (uint256 liquidationInitiatorReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt);
        vm.assume(
            uint256(liquidity) >= startDebt + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + surplus + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
                <= type(uint128).max
        );

        vm.assume(
            liquidationInitiator != auctionTerminator && liquidationInitiator != address(srTranche)
                && liquidationInitiator != address(jrTranche) && liquidationInitiator != address(liquidator)
                && liquidationInitiator != pool.getTreasury() && auctionTerminator != address(srTranche)
                && auctionTerminator != address(jrTranche) && auctionTerminator != address(liquidator)
                && auctionTerminator != pool.getTreasury()
        );

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // And:Account has a debt
        pool.setOpenPosition(address(proxyAccount), uint128(startDebt));

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        vm.expectRevert(LendingPool_InvalidSettlement.selector);
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, startDebt, liquidationInitiator, auctionTerminator, surplus
        );
    }

    function testFuzz_Success_settleLiquidation_Surplus(
        uint128 startDebt,
        uint128 liquidity,
        address liquidationInitiator,
        address auctionTerminator,
        uint128 surplus
    ) public {
        vm.assume(startDebt > 0);
        (uint256 liquidationInitiatorReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt);
        vm.assume(
            uint256(liquidity) >= startDebt + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + surplus + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
                <= type(uint128).max
        );

        vm.assume(
            liquidationInitiator != auctionTerminator && liquidationInitiator != address(srTranche)
                && liquidationInitiator != address(jrTranche) && liquidationInitiator != address(liquidator)
                && liquidationInitiator != pool.getTreasury() && auctionTerminator != address(srTranche)
                && auctionTerminator != address(jrTranche) && auctionTerminator != address(liquidator)
                && auctionTerminator != pool.getTreasury()
        );

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, startDebt, liquidationInitiator, auctionTerminator, surplus
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
        assertEq(pool.realisedLiquidityOf(users.accountOwner), surplus);
        // And: The total realised liquidity should be updated
        assertEq(
            pool.totalRealisedLiquidity(),
            liquidity + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty + surplus
        );

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidation_remainderHigherThanTerminationReward(
        uint128 liquidity,
        uint128 startDebt,
        address liquidationInitiator,
        address auctionTerminator
    ) public {
        vm.prank(users.creatorAddress);
        pool.setWeights(2, 5, 2);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(type(uint80).max, type(uint80).max);

        (uint256 liquidationInitiatorReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt);

        // Given: Liquidity is deposited in Lending Pool
        vm.assume(
            uint256(liquidity)
                >= uint256(startDebt) + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
                <= type(uint128).max
        );

        //
        vm.assume(
            liquidationInitiator != auctionTerminator && liquidationInitiator != address(srTranche)
                && liquidationInitiator != address(jrTranche) && liquidationInitiator != address(liquidator)
                && liquidationInitiator != pool.getTreasury() && auctionTerminator != address(srTranche)
                && auctionTerminator != address(jrTranche) && auctionTerminator != address(liquidator)
                && auctionTerminator != pool.getTreasury()
        );

        // There is still open debt
        vm.assume(auctionTerminationReward > 1);
        uint256 openDebt;
        openDebt = bound(uint256(openDebt), uint256(0), uint256(liquidationPenalty - 1));

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // And:Account has a debt
        pool.setOpenPosition(address(proxyAccount), uint128(openDebt));

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, startDebt, liquidationInitiator, auctionTerminator, 0
        );

        // As all liquidation penalty can not be distributed
        uint256 liquidationFee = liquidationPenalty - openDebt;

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
        assertEq(
            pool.totalRealisedLiquidity(),
            liquidity + liquidationInitiatorReward + liquidationFee + auctionTerminationReward
        );

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidation_remainderLowerThanTerminationReward(
        uint128 liquidity,
        uint128 startDebt,
        address liquidationInitiator,
        address auctionTerminator
    ) public {
        vm.prank(users.creatorAddress);
        pool.setWeights(2, 5, 2);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(type(uint80).max, type(uint80).max);

        (uint256 liquidationInitiatorReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt);

        // Given: Liquidity is deposited in Lending Pool
        vm.assume(
            uint256(liquidity)
                >= uint256(startDebt) + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
                <= type(uint128).max
        );

        //
        vm.assume(
            liquidationInitiator != auctionTerminator && liquidationInitiator != address(srTranche)
                && liquidationInitiator != address(jrTranche) && liquidationInitiator != address(liquidator)
                && liquidationInitiator != pool.getTreasury() && auctionTerminator != address(srTranche)
                && auctionTerminator != address(jrTranche) && auctionTerminator != address(liquidator)
                && auctionTerminator != pool.getTreasury()
        );

        // There is still open debt
        vm.assume(auctionTerminationReward > 1);
        vm.assume(liquidationPenalty > 0);
        uint256 openDebt;
        openDebt = bound(
            uint256(openDebt), uint256(liquidationPenalty), uint256(liquidationPenalty + auctionTerminationReward - 1)
        );

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // And:Account has a debt
        pool.setOpenPosition(address(proxyAccount), uint128(openDebt));

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, startDebt, liquidationInitiator, auctionTerminator, 0
        );

        uint256 leftAuctionTerminationReward = (liquidationPenalty + auctionTerminationReward) - openDebt;

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);
        // Then: Terminator should be able to claim his rewards for liquidation termination
        assertEq(pool.realisedLiquidityOf(auctionTerminator), leftAuctionTerminationReward);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
        // And: The jr tranche will get its part of the liquidation penalty
        assertEq(pool.realisedLiquidityOf(address(jrTranche)), 0);
        // And: treasury will get its part of the liquidation penalty
        assertEq(pool.realisedLiquidityOf(address(treasury)), 0);
        // And: The remainder should be claimable by the original owner
        assertEq(pool.realisedLiquidityOf(users.accountOwner), 0);
        // And: The total realised liquidity should be updated
        assertEq(pool.totalRealisedLiquidity(), liquidity + liquidationInitiatorReward + leftAuctionTerminationReward);

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    //
    function testFuzz_Success_settleLiquidation_BadDebt_ProcessDefault(
        uint128 liquidity,
        uint128 startDebt,
        address liquidationInitiator,
        address auctionTerminator,
        uint128 remainder
    ) public {
        vm.prank(users.creatorAddress);
        pool.setWeights(2, 5, 2);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(type(uint80).max, type(uint80).max);

        vm.assume(
            liquidationInitiator != auctionTerminator && liquidationInitiator != address(srTranche)
                && liquidationInitiator != address(jrTranche) && liquidationInitiator != address(liquidator)
                && liquidationInitiator != pool.getTreasury() && auctionTerminator != address(srTranche)
                && auctionTerminator != address(jrTranche) && auctionTerminator != address(liquidator)
                && auctionTerminator != pool.getTreasury()
        );

        (uint256 liquidationInitiatorReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt);

        // Given: Liquidity is deposited in Lending Pool
        vm.assume(
            uint256(liquidity)
                >= uint256(startDebt) + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty
                <= type(uint128).max
        );

        // There is still open debt
        vm.assume(auctionTerminationReward > 1);
        vm.assume(liquidationPenalty > 0);
        uint256 openDebt;
        openDebt =
            bound(uint256(openDebt), uint256(liquidationPenalty + auctionTerminationReward), uint256(liquidity - 1));

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
        pool.settleLiquidation(
            address(proxyAccount), users.accountOwner, startDebt, liquidationInitiator, auctionTerminator, 0
        );

        // Then: Initiator should be able to claim his rewards for liquidation initiation
        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);

        // And: Terminator should not be able to claim his rewards for liquidation termination
        assertEq(pool.realisedLiquidityOf(auctionTerminator), 0);

        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.realisedLiquidityOf(address(srTranche)), liquidity);
    }
}
