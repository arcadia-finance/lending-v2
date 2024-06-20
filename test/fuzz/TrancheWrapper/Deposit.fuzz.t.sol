/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";
import { TrancheErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "Tranche Wrapper".
 */
contract Deposit_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_deposit_Locked(uint128 assets, address receiver) public {
        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(TrancheErrors.Locked.selector);
        trancheWrapper.deposit(assets, receiver);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_ZeroShares(address receiver) public {
        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(TrancheErrors.ZeroShares.selector);
        trancheWrapper.deposit(0, receiver);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_AuctionInProgress(uint128 assets, address receiver) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(TrancheErrors.AuctionOngoing.selector);
        trancheWrapper.deposit(assets, receiver);
        vm.stopPrank();
    }

    function testFuzz_Success_deposit(uint128 assets, address receiver) public {
        vm.assume(assets > 0);

        vm.prank(users.liquidityProvider);
        trancheWrapper.deposit(assets, receiver);

        assertEq(trancheWrapper.maxWithdraw(receiver), assets);
        assertEq(trancheWrapper.maxRedeem(receiver), assets);
        assertEq(trancheWrapper.totalAssets(), assets);
        assertEq(asset.balanceOf(address(pool)), assets);
        assertEq(
            trancheWrapper.convertToShares(trancheWrapper.totalAssets()), tranche.convertToShares(tranche.totalAssets())
        );
    }

    function testFuzz_Success_deposit(
        uint128 initialShares,
        uint128 wrapperShares,
        uint128 initialAssets,
        uint128 depositedAssets,
        address receiver
    ) public {
        wrapperShares = uint128(bound(initialShares, 0, initialShares));
        depositedAssets = uint128(bound(depositedAssets, 1, type(uint128).max - 1));
        initialAssets = uint128(bound(initialAssets, 1, type(uint128).max - depositedAssets));

        setTrancheState(initialShares, wrapperShares, initialAssets);

        uint256 expectedShares = tranche.previewDeposit(depositedAssets);
        vm.assume(expectedShares > 0);

        vm.prank(users.liquidityProvider);
        uint256 actualShares = trancheWrapper.deposit(depositedAssets, receiver);

        assertEq(actualShares, expectedShares);
        assertEq(trancheWrapper.totalAssets(), initialAssets + depositedAssets);
        assertEq(tranche.totalAssets(), initialAssets + depositedAssets);
        assertEq(trancheWrapper.totalSupply(), wrapperShares + actualShares);
        assertEq(tranche.totalSupply(), initialShares + actualShares);
        assertEq(tranche.balanceOf(address(trancheWrapper)), wrapperShares + actualShares);
        assertEq(trancheWrapper.balanceOf(receiver), actualShares);
    }

    function testFuzz_Success_deposit_sync(uint128 assets, address receiver) public {
        vm.assume(assets > 3);

        vm.prank(users.liquidityProvider);
        trancheWrapper.deposit(assets / 3, receiver);

        vm.prank(users.liquidityProvider);
        trancheWrapper.deposit(assets / 3, receiver);

        vm.warp(block.timestamp + 500);

        vm.prank(users.liquidityProvider);
        vm.expectCall(address(pool), abi.encodeWithSignature("liquidityOfAndSync(address)", address(tranche)));
        trancheWrapper.deposit(assets / 3, receiver);
    }
}
