/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "Tranche".
 */
contract Mint_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_mint_Locked(uint128 shares, address receiver) public {
        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(Locked.selector);
        tranche.mint(shares, receiver);
        vm.stopPrank();
    }

    function testFuzz_Success_mint(uint128 shares, address receiver) public {
        vm.assume(shares > 0);

        vm.prank(users.liquidityProvider);
        tranche.mint(shares, receiver);

        assertEq(tranche.maxWithdraw(receiver), shares);
        assertEq(tranche.maxRedeem(receiver), shares);
        assertEq(tranche.totalAssets(), shares);
        assertEq(asset.balanceOf(address(pool)), shares);
    }
}
