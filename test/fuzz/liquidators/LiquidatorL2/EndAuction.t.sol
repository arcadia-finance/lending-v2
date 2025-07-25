/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

import { LendingPool } from "../../../../src/LendingPool.sol";
import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";
import { stdStorage, StdStorage } from "../../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "LiquidatorL2".
 */
contract EndAuction_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
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

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function initiateLiquidation(uint96 minimumMargin, uint112 amountLoaned) public {
        // Given: Account has a minimumMargin.
        vm.prank(users.owner);
        pool.setMinimumMargin(minimumMargin);
        vm.startPrank(users.accountOwner);
        account.closeMarginAccount();
        account.openMarginAccount(address(pool));
        vm.stopPrank();

        // Account has debt
        bytes3 emptyBytes3;
        uint256 collateralValue = uint256(minimumMargin) + amountLoaned;
        depositERC20InAccount(account, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));
        stdstore.target(address(pool)).sig(pool.liquidityOf.selector).with_key(address(srTranche)).checked_write(
            amountLoaned + 1
        );
        pool.setTotalRealisedLiquidity(uint128(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(account));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_endAuction_NotForSale() public {
        vm.startPrank(users.owner);
        vm.expectRevert(LiquidatorErrors.NotForSale.selector);
        liquidator.endAuction(address(account));
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuction_SequencerDown(address caller, uint112 amountLoaned, uint32 startedAt) public {
        // Given: The account auction is initiated
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(0, amountLoaned);

        // And: The sequencer is down.
        sequencerUptimeOracle.setLatestRoundData(1, startedAt);

        // When Then: Bid is called with the assetAmounts that is not the same as auction, It should revert
        vm.prank(caller);
        vm.expectRevert(LiquidatorErrors.SequencerDown.selector);
        liquidator.endAuction(address(account));
    }

    function testFuzz_Revert_endAuction_Failed_SequencerUpDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, 0, cutoffTime - 1));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: Sequencer did not go down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, 0, block.timestamp));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // And: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // Warp to a timestamp when auction is not yet expired.
        vm.warp(block.timestamp + timePassed);

        // call should revert.
        vm.startPrank(randomAddress);
        vm.expectRevert(LiquidatorErrors.EndAuctionFailed.selector);
        liquidator.endAuction(address(account));
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuction_Failed_SequencerDownDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, 0, cutoffTime - 1));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: Sequencer did go down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, block.timestamp, type(uint32).max - cutoffTime));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // Warp to a timestamp when auction is not yet expired.
        vm.warp(sequencerStartedAt + timePassed);
        // We transmit price to token 1 oracle in order to have the oracle active.
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // call should revert.
        vm.startPrank(randomAddress);
        vm.expectRevert(LiquidatorErrors.EndAuctionFailed.selector);
        liquidator.endAuction(address(account));
        vm.stopPrank();
    }

    function testFuzz_Success_endAuction_ZeroCollateral(
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
        uint256 assets = (totalSupply > 0) ? shares * totalDebt / totalSupply : totalDebt;
        // Have to round up.
        if (shares * totalDebt > assets * totalSupply) assets += 1;
        liquidity = uint128(bound(liquidity, totalDebt, type(uint128).max));

        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(account)).checked_write(shares);
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(totalSupply);
        debt.setRealisedDebt(uint256(totalDebt));
        stdstore.target(address(pool)).sig(pool.liquidityOf.selector).with_key(address(srTranche)).checked_write(
            liquidity
        );
        pool.setTotalRealisedLiquidity(uint128(liquidity));

        // And: All liquidation parameters are 0 (we do not tests want to test _calculateRewards and want to avoid overflows).
        vm.prank(users.owner);
        pool.setLiquidationParameters(0, 0, 0, 0, 0);

        // And: Account has no collateral.

        // And: Liquidation is initiated.
        liquidator.setInAuction(address(account), account.creditor(), startDebt);
        pool.setAuctionsInProgress(1);

        // When: liquidation is ended.
        liquidator.endAuction(address(account));

        // Then: Auction is ended.
        assertFalse(liquidator.getAuctionIsActive(address(account)));

        // And: Account has no debt anymore.
        assertEq(account.getUsedMargin(), 0);
    }

    function testFuzz_Success_endAuction_AccountIsHealthy(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
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

        // Account becomes Healthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned));
        stdstore.target(address(pool)).sig(pool.liquidityOf.selector).with_key(address(srTranche)).checked_write(
            amountLoaned
        );
        pool.setTotalRealisedLiquidity(uint128(amountLoaned));

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // endAuctionNoRemainingValue() should succeed.
        vm.startPrank(randomAddress);
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
        liquidator.endAuction(address(account));
        vm.stopPrank();

        assertEq(liquidator.getAuctionIsActive(address(account)), false);
    }

    function testFuzz_Success_endAuction_NoOpenPosition(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
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

        // Account becomes Healthy (open position is zero)
        debt.setRealisedDebt(0);
        stdstore.target(address(pool)).sig(pool.liquidityOf.selector).with_key(address(srTranche)).checked_write(
            uint256(0)
        );
        pool.setTotalRealisedLiquidity(0);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // endAuctionNoRemainingValue() should succeed.
        vm.startPrank(randomAddress);
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
        liquidator.endAuction(address(account));
        vm.stopPrank();

        assertEq(liquidator.getAuctionIsActive(address(account)), false);
    }

    function testFuzz_Success_endAuction_NoRemainingValue(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
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

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // By setting the minUsdValue of creditor to uint128 max value, remaining assets value will be 0.
        vm.assume(account.getAccountValue(address(0)) <= type(uint128).max);
        vm.prank(pool.riskManager());
        registry.setRiskParameters(address(pool), type(uint128).max, 0, type(uint64).max);

        // endAuctionNoRemainingValue() should succeed.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, false); //ignore exact calculations
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
        liquidator.endAuction(address(account));
        vm.stopPrank();

        assertEq(liquidator.getAuctionIsActive(address(account)), false);
        assertEq(account.inAuction(), false);
    }

    function testFuzz_Success_endAuction_AfterCutoff_SequencerUpDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        // Preprocess: Set up the fuzzed variables
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, cutoffTime + 1, type(uint32).max));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: Sequencer did not go down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, 0, block.timestamp));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // And: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // Warp to a timestamp when auction is expired
        vm.warp(block.timestamp + timePassed);

        // Update oracle to avoid InactiveOracle().
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // call to endAuctionAfterCutoff() should succeed as the auction is now expired.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, false); //ignore exact calculations
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
        liquidator.endAuction(address(account));
        vm.stopPrank();

        // The Account should be transferred to the Account recipient.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
        assertEq(liquidator.getAuctionIsActive(address(account)), false);
        assertEq(account.inAuction(), false);
    }

    function testFuzz_Success_endAuction_AfterCutoff_SequencerDownDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        // Preprocess: Set up the fuzzed variables
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, cutoffTime + 1, type(uint32).max - block.timestamp));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // And: Sequencer did go down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, block.timestamp, type(uint32).max - timePassed));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // Warp to a timestamp when auction is not yet expired.
        vm.warp(sequencerStartedAt + timePassed);
        // We transmit price to token 1 oracle in order to have the oracle active.
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // Update oracle to avoid InactiveOracle().
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // call to endAuctionAfterCutoff() should succeed as the auction is now expired.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, false); //ignore exact calculations
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
        liquidator.endAuction(address(account));
        vm.stopPrank();

        // The Account should be transferred to the Account recipient.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
        assertEq(liquidator.getAuctionIsActive(address(account)), false);
        assertEq(account.inAuction(), false);
    }
}
