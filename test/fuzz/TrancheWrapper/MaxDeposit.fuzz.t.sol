/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "Tranche".
 */
contract MaxDeposit_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
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

    function testFuzz_Success_maxDeposit_Locked(address receiver) public {
        vm.prank(address(pool));
        tranche.lock();

        assertEq(trancheWrapper.maxDeposit(receiver), 0);
    }

    function testFuzz_Success_maxDeposit_AuctionInProgress(address receiver) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        assertEq(trancheWrapper.maxDeposit(receiver), 0);
    }

    function testFuzz_Success_maxDeposit_Paused(address receiver) public {
        vm.warp(35 days);
        vm.startPrank(users.owner);
        pool.changeGuardian(users.owner);
        pool.pause();
        vm.stopPrank();

        assertEq(trancheWrapper.maxDeposit(receiver), 0);
    }

    function testFuzz_Success_maxDeposit(address receiver, uint128 totalLiquidity) public {
        pool.setTotalRealisedLiquidity(totalLiquidity);

        assertEq(trancheWrapper.maxDeposit(receiver), type(uint128).max - totalLiquidity);
    }

    function testFuzz_Success_maxMint_Locked(address receiver) public {
        vm.prank(address(pool));
        tranche.lock();

        assertEq(trancheWrapper.maxMint(receiver), 0);
    }
}
