/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "settleLiquidationUnhappyFlow" of contract "LendingPool".
 */
contract SettleLiquidationUnhappy_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
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
    function testFuzz_Revert_settleLiquidationUnhappyFlow_Unauthorised(
        uint128 startDebt,
        address auctionTerminator,
        address unprivilegedAddress_
    ) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress_ != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(Unauthorized.selector);
        pool.settleLiquidationUnhappyFlow(address(proxyAccount), startDebt, 0, auctionTerminator);
        vm.stopPrank();
    }

    function testFuzz_Revert_settleLiquidationUnhappyFlow_ExcessBadDebt(
        uint128 liquiditySenior,
        uint128 liquidityJunior,
        uint128 startDebt,
        address auctionTerminator
    ) public {
        // Given: There is liquidity and bad debt
        vm.assume(liquidityJunior > 100);
        vm.assume(liquiditySenior > 100);
        uint256 totalAmount = uint256(liquiditySenior) + uint256(liquidityJunior);
        vm.assume(startDebt > totalAmount + 2); // Bad debt should be excess since initiator and terminator rewards are 1 and 1 respectively, it should be added to make the baddebt excess
        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt, 0);
        uint256 openDebt = startDebt + initiationReward + terminationReward + liquidationPenalty;
        vm.assume(openDebt <= type(uint128).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquiditySenior, users.liquidityProvider);
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidityJunior, users.liquidityProvider);

        // And: There is an auction in progress
        pool.setAuctionsInProgress(2);

        // And:Account has a debt
        pool.setOpenPosition(address(proxyAccount), uint128(openDebt));
        debt.setRealisedDebt(openDebt);

        // When Then: settleLiquidation should fail if there is more debt than the liquidity
        vm.startPrank(address(liquidator));
        vm.expectRevert(stdError.arithmeticError);
        pool.settleLiquidationUnhappyFlow(address(proxyAccount), startDebt, 0, auctionTerminator);
        vm.stopPrank();
    }

    function testFuzz_Success_settleLiquidationUnhappyFlow_remainderHigherThanTerminationReward(
        uint128 liquidity,
        uint128 startDebt,
        uint128 openDebt,
        address auctionTerminator
    ) public {
        vm.prank(users.creatorAddress);
        pool.setLiquidationParameters(2, 5, 2, 0, type(uint80).max);

        (uint256 initiationReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt, 0);

        // Given: Liquidity is deposited in Lending Pool
        vm.assume(
            uint256(liquidity) >= uint256(startDebt) + initiationReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + initiationReward + auctionTerminationReward + liquidationPenalty <= type(uint128).max
        );

        //
        vm.assume(
            auctionTerminator != address(srTranche) && auctionTerminator != address(jrTranche)
                && auctionTerminator != address(liquidator) && auctionTerminator != pool.getTreasury()
                && auctionTerminator != users.accountOwner
        );

        // There is still open debt
        vm.assume(auctionTerminationReward > 1);
        openDebt = uint128(bound(openDebt, 1, liquidationPenalty - 1));

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(jrTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // And:Account has a debt
        pool.setOpenPosition(address(proxyAccount), openDebt);
        debt.setRealisedDebt(openDebt);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidationUnhappyFlow(address(proxyAccount), startDebt, 0, auctionTerminator);

        // As all liquidation penalty can not be distributed
        uint256 liquidationFee = liquidationPenalty - openDebt;

        // round up
        uint256 totalLiquidationWeight = pool.getLiquidationWeightTreasury() + pool.getLiquidationWeightTranche();
        uint256 liqPenaltyTreasury =
            uint256(liquidationFee) * pool.getLiquidationWeightTreasury() / totalLiquidationWeight;
        if (
            uint256(liqPenaltyTreasury) * totalLiquidationWeight
                < uint256(liquidationFee) * pool.getLiquidationWeightTreasury()
        ) {
            liqPenaltyTreasury++;
        }

        uint256 liqPenaltyJunior = uint256(liquidationFee) * pool.getLiquidationWeightTranche() / totalLiquidationWeight;
        if (
            uint256(liqPenaltyTreasury) * totalLiquidationWeight
                < uint256(liquidationFee) * pool.getLiquidationWeightTranche()
        ) {
            liqPenaltyTreasury--;
        }

        // Then: Terminator should be able to claim his rewards for liquidation termination
        assertEq(pool.liquidityOf(auctionTerminator), auctionTerminationReward);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.liquidityOf(address(srTranche)), 0);

        // And: The jr tranche will get its part of the liquidation penalty
        assertEq(pool.liquidityOf(address(jrTranche)), liquidity + liqPenaltyJunior);
        // And: treasury will get its part of the liquidation penalty
        assertEq(pool.liquidityOf(address(treasury)), liqPenaltyTreasury);
        // And: The remainder should be claimable by the original owner
        assertEq(pool.liquidityOf(users.accountOwner), 0);
        // And: The total realised liquidity should be updated
        assertEq(pool.totalLiquidity(), liquidity + liquidationFee + auctionTerminationReward);

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    function testFuzz_Success_settleLiquidationUnhappyFlow_remainderLowerThanTerminationReward(
        uint128 liquidity,
        uint128 startDebt,
        uint128 openDebt,
        address auctionTerminator
    ) public {
        vm.prank(users.creatorAddress);
        pool.setLiquidationParameters(2, 5, 2, 0, type(uint80).max);

        (uint256 initiationReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt, 0);

        // Given: Liquidity is deposited in Lending Pool
        vm.assume(
            uint256(liquidity) >= uint256(startDebt) + initiationReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + initiationReward + auctionTerminationReward + liquidationPenalty <= type(uint128).max
        );

        //
        vm.assume(
            auctionTerminator != address(srTranche) && auctionTerminator != address(jrTranche)
                && auctionTerminator != address(liquidator) && auctionTerminator != pool.getTreasury()
                && auctionTerminator != users.accountOwner
        );

        // There is still open debt
        vm.assume(auctionTerminationReward > 1);
        vm.assume(liquidationPenalty > 0);

        openDebt = uint128(bound(openDebt, liquidationPenalty, liquidationPenalty + auctionTerminationReward - 1));

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // And:Account has a debt
        pool.setOpenPosition(address(proxyAccount), openDebt);
        debt.setRealisedDebt(openDebt);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidationUnhappyFlow(address(proxyAccount), startDebt, 0, auctionTerminator);

        uint256 leftAuctionTerminationReward = (liquidationPenalty + auctionTerminationReward) - openDebt;

        // Then: Terminator should be able to claim his rewards for liquidation termination
        assertEq(pool.liquidityOf(auctionTerminator), leftAuctionTerminationReward);
        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.liquidityOf(address(srTranche)), liquidity);
        // And: The jr tranche will get its part of the liquidation penalty
        assertEq(pool.liquidityOf(address(jrTranche)), 0);
        // And: treasury will get its part of the liquidation penalty
        assertEq(pool.liquidityOf(address(treasury)), 0);
        // And: The remainder should be claimable by the original owner
        assertEq(pool.liquidityOf(users.accountOwner), 0);
        // And: The total realised liquidity should be updated
        assertEq(pool.totalLiquidity(), liquidity + leftAuctionTerminationReward);

        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    //
    function testFuzz_Success_settleLiquidationUnhappyFlow_BadDebt_ProcessDefault(
        uint112 liquidity,
        uint128 startDebt,
        uint128 openDebt,
        address auctionTerminator
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        liquidity = uint112(bound(liquidity, 0, type(uint112).max - 1));

        vm.prank(users.creatorAddress);
        pool.setLiquidationParameters(2, 5, 2, 0, type(uint80).max);

        vm.assume(
            auctionTerminator != address(srTranche) && auctionTerminator != address(jrTranche)
                && auctionTerminator != address(liquidator) && auctionTerminator != pool.getTreasury()
                && auctionTerminator != users.accountOwner
        );

        (uint256 initiationReward, uint256 auctionTerminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(startDebt, 0);

        // Given: Liquidity is deposited in Lending Pool
        vm.assume(
            uint256(liquidity) >= uint256(startDebt) + initiationReward + auctionTerminationReward + liquidationPenalty
        );
        vm.assume(
            uint256(liquidity) + initiationReward + auctionTerminationReward + liquidationPenalty <= type(uint112).max
        );

        // There is still open debt
        vm.assume(auctionTerminationReward > 1);
        vm.assume(liquidationPenalty > 0);
        openDebt = uint128(bound(openDebt, liquidationPenalty + auctionTerminationReward, liquidity - 1));

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
        pool.settleLiquidationUnhappyFlow(address(proxyAccount), startDebt, 0, auctionTerminator);

        // And: Terminator should not be able to claim his rewards for liquidation termination
        assertEq(pool.liquidityOf(auctionTerminator), 0);

        // And: The liquidity amount from the most senior tranche should remain the same
        assertEq(pool.liquidityOf(address(srTranche)), liquidity);
    }
}
