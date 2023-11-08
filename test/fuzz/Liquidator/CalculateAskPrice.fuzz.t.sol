/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { LogExpMath } from "../../../src/libraries/LogExpMath.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */
contract CalculateAskPrice_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_calculateAskPrice_startPrice_askPrice(uint128 startPrice) public {
        vm.assume(startPrice > 0);
        vm.assume(startPrice < type(uint256).max / 150);

        uint256[] memory askedAmounts = new uint256[](1);
        askedAmounts[0] = 1;

        uint256[] memory askedIds = new uint256[](1);
        askedIds[0] = 1;

        uint32[] memory assetShares = new uint32[](1);
        assetShares[0] = 1_000_000;

        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = 1;

        uint256[] memory assetIds = new uint256[](1);
        askedIds[0] = 1;

        uint256 timePassed = 0;

        uint256 askPrice =
            liquidator.calculateAskPrice(askedAmounts, askedIds, assetShares, assetAmounts, startPrice, timePassed);
        uint256 rightSide = uint256(startPrice) * liquidator.getStartPriceMultiplier() / 100;
        assertEq(askPrice, rightSide);
    }
}
