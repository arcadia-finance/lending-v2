/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";
import { AccountV1Extension } from "../../../../lib/accounts-v2/test/utils/extensions/AccountV1Extension.sol";
import { AssetValueAndRiskFactors } from "../../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { AssetValuationLib } from "../../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { stdError } from "../../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "getAuctionInformationArrays" of contract "LiquidatorL2".
 */
contract GetAuctionInformationArrays_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getAuctionInformationArrays(
        address account_,
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint32[] memory assetShares
    ) public {
        liquidator.setAssetAddresses(account_, assetAddresses);
        liquidator.setAssetIds(account_, assetIds);
        liquidator.setAssetAmounts(account_, assetAmounts);
        liquidator.setAssetShares(account_, assetShares);

        (
            address[] memory assetAddresses_,
            uint256[] memory assetIds_,
            uint256[] memory assetAmounts_,
            uint32[] memory assetShares_
        ) = liquidator.getAuctionInformationArrays(account_);

        for (uint256 i; i < assetAddresses.length; ++i) {
            assertEq(assetAddresses[i], assetAddresses_[i]);
        }

        for (uint256 i; i < assetIds.length; ++i) {
            assertEq(assetIds[i], assetIds_[i]);
        }

        for (uint256 i; i < assetAmounts.length; ++i) {
            assertEq(assetAmounts[i], assetAmounts_[i]);
        }

        for (uint256 i; i < assetShares.length; ++i) {
            assertEq(assetShares[i], assetShares_[i]);
        }
    }
}
