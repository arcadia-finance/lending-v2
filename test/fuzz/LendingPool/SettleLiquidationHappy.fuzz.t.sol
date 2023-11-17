/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "settleLiquidationHappyFlow" of contract "LendingPool".
 */
contract SettleLiquidationHappy_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
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
    function testFuzz_Revert_settleLiquidationHappyFlow_Unauthorised(
        uint128 startDebt,
        address auctionTerminator,
        address unprivilegedAddress_
    ) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress_ != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with "UNAUTHORIZED"
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(LendingPool_OnlyLiquidator.selector);
        pool.settleLiquidationHappyFlow(address(proxyAccount), startDebt, auctionTerminator);
        vm.stopPrank();
    }

    function testFuzz_Success_settleLiquidation_Surplus(
        uint128 startDebt,
        uint128 liquidity,
        address auctionTerminator,
        uint128 surplus
    ) public {
        surplus = uint128(bound(surplus, 1, type(uint128).max));
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
            auctionTerminator != address(srTranche) && auctionTerminator != address(jrTranche)
                && auctionTerminator != address(liquidator) && auctionTerminator != pool.getTreasury()
                && auctionTerminator != users.accountOwner
        );

        // Given: Liquidity is deposited in Lending Pool
        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setAuctionsInProgress(1);
        vm.prank(address(pool));
        jrTranche.setAuctionInProgress(true);

        // When: Liquidator settles a liquidation
        vm.prank(address(liquidator));
        pool.settleLiquidationHappyFlow(address(proxyAccount), startDebt, auctionTerminator, surplus);

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
}