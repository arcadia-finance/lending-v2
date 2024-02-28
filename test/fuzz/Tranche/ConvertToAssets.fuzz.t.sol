/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { TrancheExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "convertToAssets" of contract "Tranche".
 */
contract ConvertToAssets_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
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
        tranche = TrancheExtension(setTrancheState(vas, totalSupply, totalAssets));

        // When: convertToAssets is called with shares.
        uint256 actualAssets = tranche.convertToAssets(shares);
        uint256 actualAssets_ = tranche.convertToAssetsAndSync(shares);

        // Then: correct number of shares is returned.
        uint256 expectedAssets = shares * (uint256(totalAssets) + vas) / (totalSupply + vas);
        assertEq(actualAssets, expectedAssets);
        assertEq(actualAssets, actualAssets_);
    }

    function testFuzz_Success_convertToAssets_ZeroSupply(uint80 vas, uint128 totalAssets, uint256 shares) public {
        // And: Tranche state is set.
        tranche = TrancheExtension(setTrancheState(vas, 0, totalAssets));

        // When: convertToAssets is called with shares.
        uint256 actualAssets = tranche.convertToAssets(shares);
        uint256 actualAssets_ = tranche.convertToAssetsAndSync(shares);

        // Then: correct number of shares is returned.
        assertEq(actualAssets, shares);
        assertEq(actualAssets, actualAssets_);
    }
}
