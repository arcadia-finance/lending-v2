/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";
import { TrancheErrors } from "../../../src/libraries/Errors.sol";
import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "Tranche".
 */
contract Mint_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
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

    function testFuzz_Revert_mint_Locked(uint128 shares, address receiver) public {
        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(TrancheErrors.Locked.selector);
        trancheWrapper.mint(shares, receiver);
        vm.stopPrank();
    }

    function testFuzz_Success_mint(uint128 shares, address receiver) public {
        vm.assume(shares > 0);

        vm.prank(users.liquidityProvider);
        trancheWrapper.mint(shares, receiver);

        assertEq(trancheWrapper.maxWithdraw(receiver), shares);
        assertEq(trancheWrapper.maxRedeem(receiver), shares);
        assertEq(trancheWrapper.totalAssets(), shares);
        assertEq(asset.balanceOf(address(pool)), shares);
    }

    function testFuzz_Success_mint(
        uint128 initialShares,
        uint128 wrapperShares,
        uint128 initialAssets,
        uint128 mintedShares,
        address receiver
    ) public {
        initialShares = uint128(bound(initialShares, 1, type(uint128).max - 1));
        wrapperShares = uint128(bound(initialShares, 0, initialShares));
        mintedShares = uint128(bound(mintedShares, 1, type(uint128).max - initialShares));
        initialAssets = uint128(bound(initialAssets, 1, type(uint128).max));

        setTrancheState(initialShares, wrapperShares, initialAssets);

        uint256 expectedAssets = tranche.previewMint(mintedShares);
        vm.assume(expectedAssets <= type(uint128).max - initialAssets);

        vm.prank(users.liquidityProvider);
        uint256 actualAssets = trancheWrapper.mint(mintedShares, receiver);

        assertEq(actualAssets, expectedAssets);
        assertEq(trancheWrapper.totalAssets(), initialAssets + actualAssets);
        assertEq(tranche.totalAssets(), initialAssets + actualAssets);
        assertEq(trancheWrapper.totalSupply(), wrapperShares + mintedShares);
        assertEq(tranche.totalSupply(), initialShares + mintedShares);
        assertEq(tranche.balanceOf(address(trancheWrapper)), wrapperShares + mintedShares);
        assertEq(trancheWrapper.balanceOf(receiver), mintedShares);
    }
}
