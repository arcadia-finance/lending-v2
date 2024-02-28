/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { TrancheExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "previewWithdraw" of contract "Tranche".
 */
contract PreviewWithdraw_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_previewWithdraw_NonZeroSupply(
        uint80 vas,
        uint256 totalSupply,
        uint128 totalAssets,
        uint256 assets
    ) public {
        // Given: totalSupply is bigger than zero.
        // And: no overflows.
        totalSupply = bound(totalSupply, 1, type(uint256).max - vas);
        assets = bound(assets, 0, type(uint256).max / (totalSupply + vas));

        // And: totalAssets() + VAS is non-zero.
        vm.assume(uint256(totalAssets) + vas > 0);

        // And: Tranche state is set.
        tranche = TrancheExtension(setTrancheState(vas, totalSupply, totalAssets));

        // When: previewWithdraw is called with assets.
        uint256 actualShares = tranche.previewWithdraw(assets);
        uint256 actualShares_ = tranche.previewWithdrawAndSync(assets);

        // Then: correct number of shares is returned.
        uint256 expectedShares = assets * (totalSupply + vas) / (uint256(totalAssets) + vas);
        // Rounds up.
        if ((uint256(totalAssets) + vas) * expectedShares < assets * (totalSupply + vas)) expectedShares++;
        assertEq(actualShares, expectedShares);
        assertEq(actualShares, actualShares_);
    }

    function testFuzz_Success_previewWithdraw_ZeroSupply(uint80 vas, uint128 totalAssets, uint256 assets) public {
        // And: Tranche state is set.
        tranche = TrancheExtension(setTrancheState(vas, 0, totalAssets));

        // When: previewWithdraw is called with assets.
        uint256 actualShares = tranche.previewWithdraw(assets);
        uint256 actualShares_ = tranche.previewWithdrawAndSync(assets);

        // Then: correct number of shares is returned.
        assertEq(actualShares, assets);
        assertEq(actualShares, actualShares_);
    }
}
