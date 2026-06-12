/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "Tranche Wrapper".
 */
contract PreviewMint_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_previewMint_NonZeroSupply(
        uint80 vas,
        uint256 totalSupply,
        uint128 totalAssets,
        uint256 shares
    ) public {
        // Given: totalSupply is bigger than zero.
        // And: no overflows.
        totalSupply = bound(totalSupply, 1, type(uint256).max - vas);
        if (uint256(totalAssets) + vas > 0) {
            shares = bound(shares, 0, type(uint256).max / (uint256(totalAssets) + vas));
        }

        // And: Tranche state is set.
        redeployAndSetTrancheState(vas, totalSupply, totalAssets);

        // When: previewMint is called with shares.
        uint256 actualAssets = trancheWrapper.previewMint(shares);
        uint256 actualAssets_ = tranche.previewMint(shares);

        // Then: correct number of shares is returned.
        uint256 expectedAssets = shares * (uint256(totalAssets) + vas) / (totalSupply + vas);
        // Rounds up.
        if ((totalSupply + vas) * expectedAssets < shares * (uint256(totalAssets) + vas)) expectedAssets++;
        assertEq(actualAssets, expectedAssets);
        assertEq(actualAssets, actualAssets_);
    }

    function testFuzz_Success_previewMint_ZeroSupply(uint80 vas, uint128 totalAssets, uint256 shares) public {
        // And: Tranche state is set.
        redeployAndSetTrancheState(vas, 0, totalAssets);

        // When: previewMint is called with shares.
        uint256 actualAssets = trancheWrapper.previewMint(shares);
        uint256 actualAssets_ = tranche.previewMint(shares);

        // Then: correct number of shares is returned.
        assertEq(actualAssets, shares);
        assertEq(actualAssets, actualAssets_);
    }
}
