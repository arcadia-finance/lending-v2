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
        uint128 liquidationInitiatorReward,
        address auctionTerminator,
        uint128 auctionTerminationReward
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
        pool.settleLiquidation_NEW(
            address(proxyAccount), users.accountOwner, badDebt, liquidationInitiator, 0, auctionTerminator, 0, 0, 0
        );
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
                + uint256(auctionTerminationReward) <= type(uint128).max - uint256(remainder)
        );

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
        assertEq(pool.realisedLiquidityOf(users.accountOwner), remainder);
        // And: The total realised liquidity should be updated
        assertEq(
            pool.totalRealisedLiquidity(),
            liquidity + liquidationInitiatorReward + auctionTerminationReward + liquidationPenalty + remainder
        );

        //ToDo: check emit Tranche
        assertEq(pool.getAuctionsInProgress(), 0);
        assertFalse(jrTranche.auctionInProgress());
        assertFalse(srTranche.auctionInProgress());
    }

    /*     function testFuzz_Success_settleLiquidation_NEW_ProcessDefault(
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
        // TODO : we have Debt_TokenZeroShares error, to fix
        pool.borrow(
            uint256(liquidationPenalty) + uint256(auctionTerminationReward),
            address(proxyAccount),
            users.accountOwner,
            emptyBytes3
        );

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
        //
        //        // Then: Initiator should be able to claim his rewards for liquidation initiation
        //        assertEq(pool.realisedLiquidityOf(liquidationInitiator), liquidationInitiatorReward);

        // And: Terminator should not be able to claim his rewards for liquidation termination
        //        assertEq(pool.realisedLiquidityOf(auctionTerminator), 0);
    } */
}
