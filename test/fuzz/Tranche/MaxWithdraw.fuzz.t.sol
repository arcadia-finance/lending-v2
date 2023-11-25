/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "maxWithdraw" of contract "Tranche".
 */
contract MaxWithdraw_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
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
    function testFuzz_Success_maxWithdraw_Locked(address owner) public {
        vm.prank(address(pool));
        tranche.lock();

        assertEq(tranche.maxWithdraw(owner), 0);
    }

    function testFuzz_Success_maxWithdraw_AuctionInProgress(address owner) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        assertEq(tranche.maxWithdraw(owner), 0);
    }

    function testFuzz_Success_maxWithdraw_Paused(address owner) public {
        vm.warp(35 days);
        vm.startPrank(users.creatorAddress);
        pool.changeGuardian(users.creatorAddress);
        pool.pause();
        vm.stopPrank();

        assertEq(tranche.maxWithdraw(owner), 0);
    }

    function testFuzz_Success_maxWithdraw_LimitedByShares(
        address owner,
        uint128 shares,
        uint128 totalShares,
        uint128 totalLiquidity,
        uint128 claimableLiquidityOfTranche,
        uint128 availableLiquidityOfTranche
    ) public {
        vm.assume(shares <= totalShares);
        vm.assume(claimableLiquidityOfTranche <= totalLiquidity);
        vm.assume(availableLiquidityOfTranche <= totalLiquidity);

        stdstore.target(address(tranche)).sig(pool.balanceOf.selector).with_key(owner).checked_write(shares);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), claimableLiquidityOfTranche);
        stdstore.target(address(asset)).sig(pool.balanceOf.selector).with_key(address(pool)).checked_write(
            availableLiquidityOfTranche
        );

        uint256 claimableAssets;
        if (shares == 0) {
            claimableAssets = 0;
        } else {
            claimableAssets = uint256(shares) * claimableLiquidityOfTranche / totalShares;
        }
        vm.assume(availableLiquidityOfTranche >= claimableAssets);

        assertEq(tranche.maxWithdraw(owner), claimableAssets);
    }

    function testFuzz_Success_maxWithdraw_LimitedByUnderlyingAssets(
        address owner,
        uint128 shares,
        uint128 totalShares,
        uint128 totalLiquidity,
        uint128 claimableLiquidityOfTranche,
        uint128 availableLiquidityOfTranche
    ) public {
        vm.assume(shares <= totalShares);
        vm.assume(claimableLiquidityOfTranche <= totalLiquidity);
        vm.assume(availableLiquidityOfTranche <= totalLiquidity);

        stdstore.target(address(tranche)).sig(pool.balanceOf.selector).with_key(owner).checked_write(shares);
        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalShares);
        pool.setTotalRealisedLiquidity(totalLiquidity);
        pool.setRealisedLiquidityOf(address(tranche), claimableLiquidityOfTranche);
        stdstore.target(address(asset)).sig(pool.balanceOf.selector).with_key(address(pool)).checked_write(
            availableLiquidityOfTranche
        );

        uint256 claimableAssets;
        if (shares == 0) {
            claimableAssets = 0;
        } else {
            claimableAssets = uint256(shares) * claimableLiquidityOfTranche / totalShares;
        }
        vm.assume(availableLiquidityOfTranche <= claimableAssets);

        assertEq(tranche.maxWithdraw(owner), availableLiquidityOfTranche);
    }
}
