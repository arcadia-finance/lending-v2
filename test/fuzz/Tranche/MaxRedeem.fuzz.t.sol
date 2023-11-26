/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "maxRedeem" of contract "Tranche".
 */
contract MaxRedeem_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_maxRedeem_Locked(address owner) public {
        vm.prank(address(pool));
        tranche.lock();

        assertEq(tranche.maxRedeem(owner), 0);
    }

    function testFuzz_Success_maxRedeem_AuctionInProgress(address owner) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        assertEq(tranche.maxRedeem(owner), 0);
    }

    function testFuzz_Success_maxRedeem_Paused(address owner) public {
        vm.warp(35 days);
        vm.startPrank(users.creatorAddress);
        pool.changeGuardian(users.creatorAddress);
        pool.pause();
        vm.stopPrank();

        assertEq(tranche.maxRedeem(owner), 0);
    }

    function testFuzz_Success_maxRedeem_LimitedByShares(
        address owner,
        uint128 shares,
        uint128 totalShares,
        uint128 totalLiquidity,
        uint128 claimableLiquidityOfTranche,
        uint128 availableLiquidityOfTranche
    ) public {
        vm.assume(shares <= totalShares);
        vm.assume(claimableLiquidityOfTranche <= totalLiquidity);
        vm.assume(availableLiquidityOfTranche <= totalLiquidity);
        if (totalShares > 0) vm.assume(claimableLiquidityOfTranche > 0);

        stdstore.target(address(tranche)).sig(pool.balanceOf.selector).with_key(owner).checked_write(shares);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), claimableLiquidityOfTranche);
        stdstore.target(address(asset)).sig(pool.balanceOf.selector).with_key(address(pool)).checked_write(
            availableLiquidityOfTranche
        );

        uint256 availableShares;
        if (claimableLiquidityOfTranche == 0) {
            availableShares = 0;
        } else {
            availableShares = uint256(availableLiquidityOfTranche) * totalShares / claimableLiquidityOfTranche;
        }
        vm.assume(availableShares >= shares);

        assertEq(tranche.maxRedeem(owner), shares);
    }

    function testFuzz_Success_maxRedeem_LimitedByUnderlyingAssets(
        address owner,
        uint128 shares,
        uint128 totalShares,
        uint128 totalLiquidity,
        uint128 claimableLiquidityOfTranche,
        uint128 availableLiquidityOfTranche
    ) public {
        vm.assume(shares <= totalShares);
        vm.assume(claimableLiquidityOfTranche <= totalLiquidity);
        vm.assume(availableLiquidityOfTranche <= totalLiquidity);
        if (totalShares > 0) vm.assume(claimableLiquidityOfTranche > 0);

        stdstore.target(address(tranche)).sig(pool.balanceOf.selector).with_key(owner).checked_write(shares);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), claimableLiquidityOfTranche);
        stdstore.target(address(asset)).sig(pool.balanceOf.selector).with_key(address(pool)).checked_write(
            availableLiquidityOfTranche
        );

        uint256 availableShares;
        if (claimableLiquidityOfTranche == 0) {
            availableShares = 0;
        } else {
            availableShares = uint256(availableLiquidityOfTranche) * totalShares / claimableLiquidityOfTranche;
        }
        vm.assume(availableShares <= shares);

        assertEq(tranche.maxRedeem(owner), availableShares);
    }
}
