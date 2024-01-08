/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { LogExpMath } from "../../../src/libraries/LogExpMath.sol";
import { AssetValueAndRiskFactors } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_calculateTotalShare" of contract "Liquidator".
 */
contract CalculateTotalShare_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_calculateTotalShare_InvalidBid(
        address account_,
        uint256[] memory askedAssetAmounts,
        uint256[] memory assetAmounts
    ) public {
        vm.assume(askedAssetAmounts.length != assetAmounts.length);

        liquidator.setAssetAmounts(account_, assetAmounts);

        vm.expectRevert(InvalidBid.selector);
        liquidator.calculateTotalShare(account_, askedAssetAmounts);
    }

    function testFuzz_Success_calculateTotalShare(
        address account_,
        uint256 askedAssetAmountsSeed,
        uint256[] memory assetAmounts,
        AssetValueAndRiskFactors[] memory assetValues
    ) public {
        // Given: all values per asset are smaller as type(uint112).max.
        vm.assume(assetValues.length > 0);
        for (uint256 i; i < assetValues.length; ++i) {
            assetValues[i].assetValue = bound(assetValues[i].assetValue, 0, type(uint112).max);
        }

        // And: The Asset Shares are stored.
        AssetValueAndRiskFactors[] memory assetValues_ = new AssetValueAndRiskFactors[](assetAmounts.length);
        for (uint256 i; i < assetAmounts.length; ++i) {
            // If assetValues was shorter than assetAmounts, concatenate with a new assetValues array.
            uint256 j = bound(i, 0, assetValues.length - 1);
            assetValues_[i] = assetValues[j];
        }
        uint32[] memory assetShares = liquidator.getAssetShares(assetValues_);
        liquidator.setAssetShares(account_, assetShares);

        // And: All assetAmounts are smaller as type(uint112).max and bigger as 0.
        // And: askedAssetAmounts are smaller as assetAmounts.
        uint256[] memory askedAssetAmounts = new uint256[](assetAmounts.length);
        for (uint256 i; i < assetAmounts.length; ++i) {
            assetAmounts[i] = bound(assetAmounts[i], 1, type(uint112).max);

            askedAssetAmounts[i] = bound(askedAssetAmountsSeed, 0, assetAmounts[i]);
        }
        liquidator.setAssetAmounts(account_, assetAmounts);

        // When: calculateTotalShare is called.
        uint256 actualTotalShare = liquidator.calculateTotalShare(account_, askedAssetAmounts);

        // Then: The asset share are correctly calculated.
        uint256 expectedTotalShare;
        for (uint256 i; i < assetAmounts.length; ++i) {
            uint256 share = assetShares[i] * askedAssetAmounts[i] / assetAmounts[i];
            // Round up.
            if (share * assetAmounts[i] < assetShares[i] * askedAssetAmounts[i]) share += 1;

            expectedTotalShare += share;
        }
        assertEq(actualTotalShare, expectedTotalShare);
    }
}
