/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "startAuction" of contract "Liquidator".
 */

contract StartAuction_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_startAuction_AuctionOngoing(uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxyAccount), openDebt, type(uint80).max);

        vm.startPrank(address(pool));
        vm.expectRevert(Liquidator_AuctionOngoing.selector);
        liquidator.startAuction(address(proxyAccount), openDebt, type(uint80).max);
        vm.stopPrank();
    }

    function testFuzz_Revert_startAuction_NonCreditor(address unprivilegedAddress_, uint128 openDebt) public {
        vm.assume(openDebt > 0);

        vm.assume(unprivilegedAddress_ != address(pool));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(Liquidator_Unauthorized.selector);
        liquidator.startAuction(address(proxyAccount), openDebt, type(uint80).max);
        vm.stopPrank();
    }

    function testFuzz_Success_startAuction(uint128 openDebt, uint80 maxInitiatorFee) public {
        vm.assume(openDebt > 0);

        vm.startPrank(address(pool));
        vm.expectEmit(true, true, true, true);
        emit AuctionStarted(address(proxyAccount), address(pool), address(mockERC20.stable1), openDebt);
        liquidator.startAuction(address(proxyAccount), openDebt, maxInitiatorFee);
        vm.stopPrank();

        assertEq(proxyAccount.owner(), address(liquidator));
        {
            uint256 index = factory.accountIndex(address(proxyAccount));
            assertEq(factory.ownerOf(index), address(liquidator));
        }

        {
            (uint128 openDebt_, uint32 startTime, bool inAuction, uint80 maxInitiatorFee_, address baseCurrency) =
                liquidator.getAuctionInformationPartOne(address(proxyAccount));

            assertEq(openDebt_, openDebt);
            assertEq(startTime, uint128(block.timestamp));
            assertEq(inAuction, true);
            assertEq(maxInitiatorFee_, maxInitiatorFee);
            assertEq(baseCurrency, address(mockERC20.stable1));
        }

        {
            (
                uint16 startPriceMultiplier,
                uint8 minPriceMultiplier,
                uint8 initiatorRewardWeight,
                uint8 penaltyWeight,
                uint16 cutoffTime,
                address originalOwner,
                address trustedCreditor,
                uint64 base
            ) = liquidator.getAuctionInformationPartTwo(address(proxyAccount));

            assertEq(startPriceMultiplier, liquidator.getStartPriceMultiplier());
            assertEq(minPriceMultiplier, liquidator.getMinPriceMultiplier());
            assertEq(initiatorRewardWeight, liquidator.getInitiatorRewardWeight());
            assertEq(penaltyWeight, liquidator.getPenaltyWeight());
            assertEq(cutoffTime, liquidator.getCutoffTime());
            assertEq(originalOwner, users.accountOwner);
            assertEq(trustedCreditor, address(pool));
            assertEq(base, liquidator.getBase());
        }
    }
}
