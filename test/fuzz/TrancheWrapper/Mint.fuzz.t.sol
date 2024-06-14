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
        vm.expectRevert(Locked.selector);
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
}
