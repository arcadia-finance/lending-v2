/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";

import { Tranche } from "../../../src/Tranche.sol";

/**
 * @notice Fuzz tests for the function "donateToTranche" of contract "LendingPool".
 */
contract DonateToTranche_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_donateToTranche_indexIsNoTranche(uint256 index) public {
        vm.assume(index >= pool.numberOfTranches());

        vm.expectRevert(stdError.indexOOBError);
        pool.donateToTranche(index, 1);
    }

    function testFuzz_Revert_donateToTranche_zeroAssets() public {
        vm.expectRevert("LP_DTT: Amount is 0");
        pool.donateToTranche(1, 0);
    }

    function testFuzz_Revert_donateToTranche_SupplyCap(uint256 amount, uint128 supplyCap) public {
        // Given: amount should be greater than 1
        vm.assume(amount > 1);
        vm.assume(pool.totalRealisedLiquidity() + amount > supplyCap);
        vm.assume(supplyCap > 0);

        // When: supply cap is set to 1
        vm.prank(users.creatorAddress);
        pool.setSupplyCap(supplyCap);

        // Then: depositInLendingPool is reverted with supplyCapExceeded()
        vm.expectRevert(supplyCapExceeded.selector);
        pool.donateToTranche(1, amount);
    }

    function testFuzz_Revert_donateToTranche_InsufficientShares(uint32 initialShares, uint128 assets, address donator)
        public
    {
        vm.assume(assets > 0);
        vm.assume(assets < type(uint128).max - pool.totalRealisedLiquidity() - initialShares);
        vm.assume(initialShares < 10 ** pool.decimals());

        vm.prank(users.creatorAddress);
        pool.setSupplyCap(type(uint128).max);

        vm.startPrank(users.liquidityProvider);
        srTranche.mint(initialShares, users.liquidityProvider);
        mockERC20.stable1.transfer(donator, assets);
        vm.stopPrank();

        vm.startPrank(donator);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.expectRevert("LP_DTT: Insufficient shares");
        pool.donateToTranche(0, assets);
        vm.stopPrank();
    }

    function testFuzz_Success_donateToTranche(uint8 index, uint128 assets, address donator, uint128 initialShares)
        public
    {
        vm.assume(assets > 0);
        vm.assume(assets <= type(uint128).max - pool.totalRealisedLiquidity() - initialShares);
        vm.assume(index < pool.numberOfTranches());
        vm.assume(initialShares >= 10 ** pool.decimals());

        vm.prank(users.creatorAddress);
        pool.setSupplyCap(type(uint128).max);

        address tranche_ = pool.getTranches(index);
        vm.startPrank(users.liquidityProvider);
        Tranche(tranche_).mint(initialShares, users.liquidityProvider);
        mockERC20.stable1.transfer(donator, assets);
        vm.stopPrank();

        uint256 donatorBalancePre = mockERC20.stable1.balanceOf(donator);
        uint256 poolBalancePre = mockERC20.stable1.balanceOf(address(pool));
        uint256 realisedLiqOfPre = pool.realisedLiquidityOf(tranche_);
        uint256 totalRealisedLiqPre = pool.totalRealisedLiquidity();

        vm.startPrank(donator);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // When: donateToPool
        pool.donateToTranche(index, assets);
        vm.stopPrank();

        uint256 donatorBalancePost = mockERC20.stable1.balanceOf(donator);
        uint256 poolBalancePost = mockERC20.stable1.balanceOf(address(pool));
        uint256 realisedLiqOfPost = pool.realisedLiquidityOf(tranche_);
        uint256 totalRealisedLiqPost = pool.totalRealisedLiquidity();

        assertEq(donatorBalancePost + assets, donatorBalancePre);
        assertEq(poolBalancePost - assets, poolBalancePre);
        assertEq(realisedLiqOfPost - assets, realisedLiqOfPre);
        assertEq(totalRealisedLiqPost - assets, totalRealisedLiqPre);
    }
}
