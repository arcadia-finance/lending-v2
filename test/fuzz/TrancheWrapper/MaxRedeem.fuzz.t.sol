/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "Tranche".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract MaxRedeem_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_maxRedeem_Locked(address owner) public {
        vm.prank(address(pool));
        tranche.lock();

        assertEq(trancheWrapper.maxRedeem(owner), 0);
    }

    function testFuzz_Success_maxRedeem_AuctionInProgress(address owner) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        assertEq(trancheWrapper.maxRedeem(owner), 0);
    }

    function testFuzz_Success_maxRedeem_Paused(address owner) public {
        vm.warp(35 days);
        vm.startPrank(users.owner);
        pool.changeGuardian(users.owner);
        pool.pause();
        vm.stopPrank();

        assertEq(trancheWrapper.maxRedeem(owner), 0);
    }

    function testFuzz_Success_maxRedeem_LimitedByShares(
        address owner,
        uint128 shares,
        uint128 totalShares,
        uint128 totalLiquidity,
        uint128 claimableLiquidityOfTranche,
        uint128 availableLiquidityOfTranche
    ) public {
        if (totalShares > 0) {
            totalLiquidity = uint128(bound(totalLiquidity, 1, type(uint128).max));
        }
        shares = uint128(bound(shares, 0, totalShares));
        claimableLiquidityOfTranche =
            uint128(bound(claimableLiquidityOfTranche, totalShares > 0 ? 1 : 0, totalLiquidity));
        availableLiquidityOfTranche = uint128(bound(availableLiquidityOfTranche, 0, totalLiquidity));

        stdstore.target(address(tranche))
            .sig(pool.balanceOf.selector)
            .with_key(address(trancheWrapper))
            .checked_write(totalShares);
        stdstore.target(address(trancheWrapper)).sig(pool.balanceOf.selector).with_key(owner).checked_write(shares);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);
        stdstore.target(address(trancheWrapper)).sig(pool.totalSupply.selector).checked_write(totalShares);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), claimableLiquidityOfTranche);
        stdstore.target(address(asset))
            .sig(pool.balanceOf.selector)
            .with_key(address(pool))
            .checked_write(availableLiquidityOfTranche);

        uint256 availableShares;
        if (claimableLiquidityOfTranche == 0) {
            availableShares = 0;
        } else {
            availableShares = uint256(availableLiquidityOfTranche) * totalShares / claimableLiquidityOfTranche;
        }
        vm.assume(availableShares >= shares);

        assertEq(trancheWrapper.maxRedeem(owner), shares);
    }

    function testFuzz_Success_maxRedeem_LimitedByUnderlyingAssets(
        address owner,
        uint128 shares,
        uint128 totalShares,
        uint128 totalLiquidity,
        uint128 claimableLiquidityOfTranche,
        uint128 availableLiquidityOfTranche
    ) public {
        if (totalShares > 0) {
            totalLiquidity = uint128(bound(totalLiquidity, 1, type(uint128).max));
        }
        shares = uint128(bound(shares, 0, totalShares));
        claimableLiquidityOfTranche =
            uint128(bound(claimableLiquidityOfTranche, totalShares > 0 ? 1 : 0, totalLiquidity));
        availableLiquidityOfTranche = uint128(bound(availableLiquidityOfTranche, 0, totalLiquidity));

        stdstore.target(address(tranche))
            .sig(pool.balanceOf.selector)
            .with_key(address(trancheWrapper))
            .checked_write(totalShares);
        stdstore.target(address(trancheWrapper)).sig(pool.balanceOf.selector).with_key(owner).checked_write(shares);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);
        stdstore.target(address(trancheWrapper)).sig(pool.totalSupply.selector).checked_write(totalShares);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), claimableLiquidityOfTranche);
        stdstore.target(address(asset))
            .sig(pool.balanceOf.selector)
            .with_key(address(pool))
            .checked_write(availableLiquidityOfTranche);

        uint256 availableShares;
        if (claimableLiquidityOfTranche == 0) {
            availableShares = 0;
        } else {
            availableShares = uint256(availableLiquidityOfTranche) * totalShares / claimableLiquidityOfTranche;
        }
        vm.assume(availableShares <= shares);

        assertEq(trancheWrapper.maxRedeem(owner), availableShares);
    }
}
