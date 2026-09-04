/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

import { LendingPool } from "../../../../src/LendingPool.sol";
import { stdStorage, StdStorage } from "../../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "_settleAuction" of contract "LiquidatorL2".
 * @dev "_settleAuction" has no own reverts, it returns a bool indicating if a termination condition was met.
 * Each test asserts the returned bool and the side effects of the matched condition.
 */
// forge-lint: disable-next-item(unsafe-typecast,divide-before-multiply)
contract SettleAuction_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();

        // Set grace period to 0.
        vm.prank(users.riskManager);
        registry.setRiskParameters(address(pool), 0, 0 minutes, type(uint64).max);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_settleAuction_AfterCutoff(
        uint32 halfLifeTime,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, cutoffTime + 1, type(uint32).max));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: The auction did not end within the cutoffTime.
        vm.warp(block.timestamp + timePassed);
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // When: settleAuction is called.
        vm.expectEmit(true, true, true, false);
        emit LendingPool.AuctionFinished(address(account), address(pool), uint128(amountLoaned + 1), 0, 0, 0, 0, 0);
        bool success = liquidator.settleAuction(address(account));

        // Then: It returns true.
        assertTrue(success);

        // And: The Account is transferred to the Account recipient.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
    }

    function testFuzz_Success_settleAuction_Healthy_CollateralGeUsedMargin(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: Account becomes healthy (collateral value is equal or greater than the used margin).
        debt.setRealisedDebt(uint256(amountLoaned));
        stdstore.target(address(pool))
            .sig(pool.liquidityOf.selector)
            .with_key(address(srTranche))
            .checked_write(amountLoaned);
        pool.setTotalRealisedLiquidity(uint128(amountLoaned));

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // When: settleAuction is called.
        vm.expectEmit(true, true, true, true);
        emit LendingPool.AuctionFinished(
            address(account),
            address(pool),
            uint128(amountLoaned + 1),
            initiationReward,
            terminationReward,
            liquidationPenalty,
            0,
            0
        );
        bool success = liquidator.settleAuction(address(account));

        // Then: It returns true.
        assertTrue(success);
    }

    function testFuzz_Success_settleAuction_Healthy_UsedMarginEqMinimumMargin(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: The open position is repaid (used margin equals minimum margin).
        debt.setRealisedDebt(0);
        stdstore.target(address(pool))
            .sig(pool.liquidityOf.selector)
            .with_key(address(srTranche))
            .checked_write(uint256(0));
        pool.setTotalRealisedLiquidity(0);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // When: settleAuction is called.
        vm.expectEmit(true, true, true, true);
        emit LendingPool.AuctionFinished(
            address(account),
            address(pool),
            uint128(amountLoaned + 1),
            initiationReward,
            terminationReward,
            liquidationPenalty,
            0,
            0
        );
        bool success = liquidator.settleAuction(address(account));

        // Then: It returns true.
        assertTrue(success);
    }

    function testFuzz_Success_settleAuction_NoRemainingValue(uint112 usedMargin, uint96 minimumMargin) public {
        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: The remaining assets have no more value.
        vm.assume(account.getAccountValue(address(0)) <= type(uint128).max);
        vm.prank(pool.riskManager());
        registry.setRiskParameters(address(pool), type(uint128).max, 0, type(uint64).max);

        // When: settleAuction is called.
        vm.expectEmit(true, true, true, false);
        emit LendingPool.AuctionFinished(address(account), address(pool), uint128(amountLoaned + 1), 0, 0, 0, 0, 0);
        bool success = liquidator.settleAuction(address(account));

        // Then: It returns true.
        assertTrue(success);

        // And: The Account is transferred to the Account recipient.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
    }

    function testFuzz_Success_settleAuction_ReturnsFalse_NoConditionMet(uint112 usedMargin, uint96 minimumMargin)
        public
    {
        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: The collateral value is 0 but the remaining assets still have value.
        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(address(pool), address(mockERC20.stable1), 0, type(uint112).max, 0, 0);

        // When: settleAuction is called.
        bool success = liquidator.settleAuction(address(account));

        // Then: It returns false.
        assertFalse(success);

        // And: The auction is still active.
        assertTrue(liquidator.getAuctionIsActive(address(account)));
    }

    function testFuzz_Success_settleAuction_NoRemainingAssets(address bidder, uint112 amountLoaned) public {
        // Given: Bidder is an EOA.
        vm.assume(bidder.code.length == 0);
        vm.assume(bidder != address(0));

        // And: The account auction is initiated.
        amountLoaned = uint112(bound(amountLoaned, 12 + 1, (type(uint112).max / 300) * 100));
        // forge-lint: disable-next-line(divide-before-multiply)
        initiateLiquidation(amountLoaned);

        // And: The auction price decayed below the open debt, within the cutoffTime.
        vm.warp(block.timestamp + 3 hours);

        // And: A bidder bought all assets without repaying all debt.
        uint256[] memory bidAssetAmounts = liquidator.getAuctionAssetAmounts(address(account));
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        liquidator.bid(address(account), bidAssetAmounts, false, "");
        vm.stopPrank();

        // When: settleAuction is called.
        bool success = liquidator.settleAuction(address(account));

        // Then: It returns true.
        assertTrue(success);

        // And: The Account is transferred to the Account recipient.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
    }

    function testFuzz_Success_settleAuction_ZeroCollateral(
        uint256 shares,
        uint256 totalSupply,
        uint128 totalDebt,
        uint128 startDebt,
        uint128 liquidity
    ) public {
        // Given: totalDebt is not 0.
        totalDebt = uint128(bound(totalDebt, 1, type(uint128).max));

        // And: invariant ERC20.
        shares = bound(shares, 0, totalSupply);
        // And: convertToAssets does not overflow.
        shares = bound(shares, 0, type(uint256).max / totalDebt);

        // And: liquidityOf is bigger or equal as totalDebt (invariant).
        liquidity = uint128(bound(liquidity, totalDebt, type(uint128).max));

        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(account)).checked_write(shares);
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(totalSupply);
        debt.setRealisedDebt(uint256(totalDebt));
        stdstore.target(address(pool))
            .sig(pool.liquidityOf.selector)
            .with_key(address(srTranche))
            .checked_write(liquidity);
        pool.setTotalRealisedLiquidity(uint128(liquidity));

        // And: All liquidation parameters are 0 (we do not want to test _calculateRewards and want to avoid overflows).
        vm.prank(users.owner);
        pool.setLiquidationParameters(0, 0, 0, 0, 0);

        // And: Account has no collateral and the liquidation is initiated.
        liquidator.setInAuction(address(account), account.creditor(), startDebt);
        pool.setAuctionsInProgress(1);

        // When: settleAuction is called.
        bool success = liquidator.settleAuction(address(account));

        // Then: It returns true.
        assertTrue(success);

        // And: Account has no debt anymore.
        assertEq(account.getUsedMargin(), 0);
    }
}
