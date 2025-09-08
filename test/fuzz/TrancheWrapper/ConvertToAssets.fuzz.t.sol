/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

import { TrancheExtension } from "../../utils/extensions/TrancheExtension.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "TrancheWrapper".
 */
contract ConvertToAssets_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
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

    function testFuzz_Success_convertToAssets_NonZeroSupply(
        uint80 vas,
        uint256 totalSupply,
        uint128 totalAssets,
        uint256 shares
    ) public {
        // Given: totalSupply is bigger than zero.
        // And: no overflows.
        totalSupply = bound(totalSupply, 1, type(uint256).max - vas);
        if (uint256(totalAssets) + vas > 0) shares = bound(shares, 0, type(uint256).max / (uint256(totalAssets) + vas));

        // And: Tranche state is set.
        redeployAndSetTrancheState(vas, totalSupply, totalAssets);

        // When: convertToAssets is called with shares.
        uint256 actualAssets = trancheWrapper.convertToAssets(shares);
        uint256 actualAssets_ = tranche.convertToAssets(shares);

        // Then: correct number of shares is returned.
        uint256 expectedAssets = shares * (uint256(totalAssets) + vas) / (totalSupply + vas);
        assertEq(actualAssets, expectedAssets);
        assertEq(actualAssets, actualAssets_);
    }

    function testFuzz_Success_convertToAssets_ZeroSupply(uint80 vas, uint128 totalAssets, uint256 shares) public {
        // And: Tranche state is set.
        redeployAndSetTrancheState(vas, 0, totalAssets);

        // When: convertToAssets is called with shares.
        uint256 actualAssets = trancheWrapper.convertToAssets(shares);
        uint256 actualAssets_ = tranche.convertToAssets(shares);

        // Then: correct number of shares is returned.
        assertEq(actualAssets, shares);
        assertEq(actualAssets, actualAssets_);
    }
}
