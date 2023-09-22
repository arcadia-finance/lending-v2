/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the "maxMint" of contract "Tranche".
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
    function testSuccess_maxMint_AuctionInProgress(address receiver) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        assertEq(tranche.maxMint(receiver), 0);
    }

    function testSuccess_maxMint_Paused(address receiver) public {
        vm.warp(35 days);
        vm.startPrank(users.creatorAddress);
        pool.changeGuardian(users.creatorAddress);
        pool.pause();
        vm.stopPrank();

        assertEq(tranche.maxMint(receiver), 0);
    }

    function testSuccess_maxMint_SupplyCapExceeded(address receiver, uint128 supplyCap, uint128 totalLiquidity)
        public
    {
        vm.assume(supplyCap > 0);
        vm.assume(supplyCap < totalLiquidity);

        vm.prank(users.creatorAddress);
        pool.setSupplyCap(supplyCap);
        pool.setTotalRealisedLiquidity(totalLiquidity);

        assertEq(tranche.maxMint(receiver), 0);
    }

    function testSuccess_maxMint_WithSupplyCapZeroSupply(
        address receiver,
        uint128 supplyCap,
        uint128 totalLiquidity,
        uint128 liquidityOf
    ) public {
        vm.assume(supplyCap > 0);
        vm.assume(liquidityOf > 0);
        vm.assume(supplyCap >= totalLiquidity);
        vm.assume(liquidityOf <= totalLiquidity);

        vm.prank(users.creatorAddress);
        pool.setSupplyCap(supplyCap);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(tranche)).checked_write(
            liquidityOf
        );

        uint256 maxAssets = supplyCap - totalLiquidity;
        uint256 maxShares = maxAssets;

        assertEq(tranche.maxMint(receiver), maxShares);
    }

    function testSuccess_maxMint_WithSupplyCapNonZeroShares(
        address receiver,
        uint128 supplyCap,
        uint128 totalLiquidity,
        uint128 liquidityOf,
        uint128 totalShares
    ) public {
        vm.assume(supplyCap > 0);
        vm.assume(liquidityOf > 0);
        vm.assume(totalShares > 0);
        vm.assume(supplyCap >= totalLiquidity);
        vm.assume(liquidityOf <= totalLiquidity);

        vm.prank(users.creatorAddress);
        pool.setSupplyCap(supplyCap);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(tranche)).checked_write(
            liquidityOf
        );
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);

        uint256 maxAssets = supplyCap - totalLiquidity;
        uint256 maxShares = maxAssets * totalShares / liquidityOf;

        assertEq(tranche.maxMint(receiver), maxShares);
    }

    function testSuccess_maxMint_WithoutSupplyCapZeroSupply(
        address receiver,
        uint128 totalLiquidity,
        uint128 liquidityOf
    ) public {
        vm.assume(liquidityOf > 0);
        vm.assume(liquidityOf <= totalLiquidity);

        vm.prank(users.creatorAddress);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(tranche)).checked_write(
            liquidityOf
        );

        uint256 maxAssets = type(uint128).max - totalLiquidity;
        uint256 maxShares = maxAssets;

        assertEq(tranche.maxMint(receiver), maxShares);
    }

    function testSuccess_maxMint_WithoutSupplyCapNonZeroShares(
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
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(tranche)).checked_write(
            liquidityOf
        );
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);

        uint256 maxAssets = type(uint128).max - totalLiquidity;
        uint256 maxShares = maxAssets * totalShares / liquidityOf;

        assertEq(tranche.maxMint(receiver), maxShares);
    }
}
