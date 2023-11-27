/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "maxMint" of contract "Tranche".
 */
contract MaxMint_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
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
    function testFuzz_Success_maxMint_AuctionInProgress(address receiver) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        assertEq(tranche.maxMint(receiver), 0);
    }

    function testFuzz_Success_maxMint_Paused(address receiver) public {
        vm.warp(35 days);
        vm.startPrank(users.creatorAddress);
        pool.changeGuardian(users.creatorAddress);
        pool.pause();
        vm.stopPrank();

        assertEq(tranche.maxMint(receiver), 0);
    }

    function testFuzz_Success_maxMint_WithoutSupplyCapZeroSupply(
        address receiver,
        uint128 totalLiquidity,
        uint128 liquidityOf
    ) public {
        vm.assume(liquidityOf > 0);
        vm.assume(liquidityOf <= totalLiquidity);

        vm.prank(users.creatorAddress);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), liquidityOf);

        uint256 maxAssets = type(uint128).max - totalLiquidity;
        uint256 maxShares = maxAssets;

        assertEq(tranche.maxMint(receiver), maxShares);
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

        vm.prank(users.creatorAddress);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), liquidityOf);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);

        uint256 maxAssets = type(uint128).max - totalLiquidity;
        uint256 maxShares = maxAssets * totalShares / liquidityOf;

        assertEq(tranche.maxMint(receiver), maxShares);
    }
}
