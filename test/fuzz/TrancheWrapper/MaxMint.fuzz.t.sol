/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "Tranche".
 */
contract MaxMint_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
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
    function testFuzz_Success_maxMint_AuctionInProgress(address receiver) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        assertEq(trancheWrapper.maxMint(receiver), 0);
    }

    function testFuzz_Success_maxMint_Paused(address receiver) public {
        vm.warp(35 days);
        vm.startPrank(users.owner);
        pool.changeGuardian(users.owner);
        pool.pause();
        vm.stopPrank();

        assertEq(trancheWrapper.maxMint(receiver), 0);
    }

    function testFuzz_Success_maxMint_WithoutSupplyCapZeroSupply(
        address receiver,
        uint128 totalLiquidity,
        uint128 liquidityOf
    ) public {
        vm.assume(liquidityOf > 0);
        vm.assume(liquidityOf <= totalLiquidity);

        vm.prank(users.owner);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), liquidityOf);

        uint256 maxAssets = type(uint128).max - totalLiquidity;
        uint256 maxShares = maxAssets;

        assertEq(trancheWrapper.maxMint(receiver), maxShares);
    }

    function testFuzz_Success_maxMint_WithoutSupplyCapNonZeroShares(
        address receiver,
        uint128 totalLiquidity,
        uint128 liquidityOf,
        uint128 totalShares
    ) public {
        vm.assume(liquidityOf > 0);
        vm.assume(totalShares > 0);
        vm.assume(liquidityOf <= totalLiquidity);

        vm.prank(users.owner);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), liquidityOf);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);

        uint256 maxAssets = type(uint128).max - totalLiquidity;
        uint256 maxShares = maxAssets * totalShares / liquidityOf;

        assertEq(trancheWrapper.maxMint(receiver), maxShares);
    }
}
