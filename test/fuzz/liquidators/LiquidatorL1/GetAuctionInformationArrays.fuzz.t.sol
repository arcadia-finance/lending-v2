/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getAuctionInformationArrays" of contract "LiquidatorL1".
 */
contract GetAuctionInformationArrays_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();
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
        liquidator_.setAssetAddresses(account_, assetAddresses);
        liquidator_.setAssetIds(account_, assetIds);
        liquidator_.setAssetAmounts(account_, assetAmounts);
        liquidator_.setAssetShares(account_, assetShares);

        (
            address[] memory assetAddresses_,
            uint256[] memory assetIds_,
            uint256[] memory assetAmounts_,
            uint32[] memory assetShares_
        ) = liquidator_.getAuctionInformationArrays(account_);

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
