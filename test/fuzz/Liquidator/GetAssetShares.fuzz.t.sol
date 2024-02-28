/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { AssetValueAndRiskFactors } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getAssetShares" of contract "Liquidator".
 */
contract GetAssetShares_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetShare_EmptyArray() public {
        // When: getAssetShares is called.
        uint32[] memory assetShares = liquidator.getAssetShares(new AssetValueAndRiskFactors[](0));

        // Then: Empty asset shares array is returned.
        assertEq(assetShares.length, 0);
    }

    function testFuzz_Success_getAssetShare_NonEmptyArray_ZeroTotalValue(uint8 length) public {
        AssetValueAndRiskFactors[] memory assetValues = new AssetValueAndRiskFactors[](length);

        // When: getAssetShares is called.
        uint32[] memory assetShares = liquidator.getAssetShares(assetValues);

        // Then: The asset shares are 0.
        for (uint256 i; i < assetValues.length; ++i) {
            assertEq(assetShares[i], 0);
        }
    }

    function testFuzz_Success_getAssetShare_NonEmptyArray_NonZeroTotalValue(
        AssetValueAndRiskFactors[] memory assetValues
    ) public {
        // Given: all values per asset are smaller as type(uint112).max.
        uint256 totalValue;
        vm.assume(assetValues.length > 0);
        for (uint256 i; i < assetValues.length; ++i) {
            assetValues[i].assetValue = bound(assetValues[i].assetValue, 0, type(uint112).max);
            totalValue += assetValues[i].assetValue;
        }
        vm.assume(totalValue > 0);

        vm.assume(totalValue != 0);

        // When: getAssetShares is called.
        uint32[] memory assetShares = liquidator.getAssetShares(assetValues);

        // Then: The asset shares are correctly calculated.
        uint256 expectedValue;
        uint256 totalShares;
        for (uint256 i; i < assetValues.length; ++i) {
            expectedValue = assetValues[i].assetValue * ONE_4 / totalValue;
            // Round up.
            if (expectedValue * totalValue < assetValues[i].assetValue * ONE_4) expectedValue += 1;

            assertEq(assetShares[i], expectedValue);

            totalShares += assetShares[i];
        }

        // And: The sum of the distribution should be approximately equal to 10_000.
        assertGe(totalShares, 10_000);
        assertLe(totalShares, 10_000 + assetValues.length);
    }
}
