/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";
import { stdError } from "../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";
import { Tranche } from "../../../src/Tranche.sol";

/**
 * @notice Fuzz tests for the function "donateToTranche" of contract "LendingPool".
 */
// forge-lint: disable-next-item(unsafe-typecast)
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
        index = bound(index, pool.numberOfTranches(), type(uint256).max);

        vm.expectRevert(stdError.indexOOBError);
        pool.donateToTranche(index, 1);
    }

    function testFuzz_Revert_donateToTranche_zeroAssets() public {
        vm.expectRevert(LendingPoolErrors.ZeroAmount.selector);
        pool.donateToTranche(1, 0);
    }

    function testFuzz_Success_donateToTranche(uint8 index, uint128 assets, address donator, uint128 initialShares)
        public
    {
        initialShares = uint128(bound(initialShares, 0, type(uint128).max - pool.totalLiquidity() - 1));
        assets = uint128(bound(assets, 1, type(uint128).max - pool.totalLiquidity() - initialShares));
        index = uint8(bound(index, 0, pool.numberOfTranches() - 1));

        address tranche_ = pool.getTranches(index);
        vm.startPrank(users.liquidityProvider);
        Tranche(tranche_).mint(initialShares, users.liquidityProvider);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        mockERC20.stable1.transfer(donator, assets);
        vm.stopPrank();

        uint256 donatorBalancePre = mockERC20.stable1.balanceOf(donator);
        uint256 poolBalancePre = mockERC20.stable1.balanceOf(address(pool));
        uint256 realisedLiqOfPre = pool.liquidityOf(tranche_);
        uint256 totalRealisedLiqPre = pool.totalLiquidity();

        vm.startPrank(donator);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // When: donateToPool
        pool.donateToTranche(index, assets);
        vm.stopPrank();

        uint256 donatorBalancePost = mockERC20.stable1.balanceOf(donator);
        uint256 poolBalancePost = mockERC20.stable1.balanceOf(address(pool));
        uint256 realisedLiqOfPost = pool.liquidityOf(tranche_);
        uint256 totalRealisedLiqPost = pool.totalLiquidity();

        assertEq(donatorBalancePost + assets, donatorBalancePre);
        assertEq(poolBalancePost - assets, poolBalancePre);
        assertEq(realisedLiqOfPost - assets, realisedLiqOfPre);
        assertEq(totalRealisedLiqPost - assets, totalRealisedLiqPre);
    }
}
