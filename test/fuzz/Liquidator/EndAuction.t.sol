/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */

contract EndAuction_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function initiateLiquidation(uint112 amountLoaned) public {
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
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(srTranche)).checked_write(
            amountLoaned + 1
        );
        pool.setTotalRealisedLiquidity(uint128(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(proxyAccount));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_endAuction_NotForSale() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(NotForSale.selector);
        liquidator.endAuction(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuction_Failed(
        uint32 halfLifeTime,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 amountLoaned
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, 0, cutoffTime - 1));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        amountLoaned = uint112(bound(amountLoaned, 1, (type(uint112).max / 150) * 100)); // No overflow when debt is increased

        vm.prank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        initiateLiquidation(amountLoaned);

        // Warp to a timestamp when auction is not yet expired.
        vm.warp(block.timestamp + timePassed);

        // call should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(EndAuctionFailed.selector);
        liquidator.endAuction(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Success_endAuction_AccountIsHealthy(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 amountLoaned,
        address randomAddress
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        amountLoaned = uint112(bound(amountLoaned, 1, (type(uint112).max / 150) * 100));

        vm.prank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        initiateLiquidation(amountLoaned);

        // Account becomes Healthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned));
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(srTranche)).checked_write(
            amountLoaned
        );
        pool.setTotalRealisedLiquidity(uint128(amountLoaned));

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1);

        // endAuctionNoRemainingValue() should succeed.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, true);
        emit AuctionFinished(
            address(proxyAccount),
            address(pool),
            uint128(amountLoaned + 1),
            initiationReward,
            terminationReward,
            liquidationPenalty,
            0,
            0
        );
        liquidator.endAuction(address(proxyAccount));
        vm.stopPrank();

        assert(liquidator.getAuctionIsActive(address(proxyAccount)) == false);
    }

    function testFuzz_Success_endAuction_NoRemainingValue(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 amountLoaned,
        address randomAddress
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        amountLoaned = uint112(bound(amountLoaned, 1, (type(uint112).max / 150) * 100));

        vm.prank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        initiateLiquidation(amountLoaned);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1);

        // By setting the minUsdValue of creditor to uint256 max value, remaining assets value should be 0.
        vm.prank(pool.riskManager());
        registryExtension.setMinUsdValueCreditor(address(pool), type(uint256).max);

        // endAuctionNoRemainingValue() should succeed.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, false); //ignore exact calculations
        emit AuctionFinished(
            address(proxyAccount),
            address(pool),
            uint128(amountLoaned + 1),
            initiationReward,
            terminationReward,
            liquidationPenalty,
            0,
            0
        );
        liquidator.endAuction(address(proxyAccount));
        vm.stopPrank();

        assert(liquidator.getAuctionIsActive(address(proxyAccount)) == false);
        assert(proxyAccount.inAuction() == false);
    }

    function testFuzz_Success_endAuction_AfterCutoff(
        uint32 halfLifeTime,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 amountLoaned
    ) public {
        // Preprocess: Set up the fuzzed variables
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, cutoffTime + 1, type(uint32).max));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        amountLoaned = uint112(bound(amountLoaned, 1, (type(uint112).max / 150) * 100)); // No overflow when debt is increased

        vm.prank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        initiateLiquidation(amountLoaned);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1);

        // Warp to a timestamp when auction is expired
        vm.warp(block.timestamp + timePassed);

        // call to endAuctionAfterCutoff() should succeed as the auction is now expired.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, false); //ignore exact calculations
        emit AuctionFinished(
            address(proxyAccount),
            address(pool),
            uint128(amountLoaned + 1),
            initiationReward,
            terminationReward,
            liquidationPenalty,
            0,
            0
        );
        liquidator.endAuction(address(proxyAccount));
        vm.stopPrank();

        // The remaining tokens should be sent to protocol owner
        assertEq(mockERC20.stable1.balanceOf(liquidator.getAssetRecipient(address(pool))), amountLoaned);
        assert(liquidator.getAuctionIsActive(address(proxyAccount)) == false);
        assert(proxyAccount.inAuction() == false);
    }
}
