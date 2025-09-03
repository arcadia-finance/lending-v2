/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";
import { TrancheExtension } from "../../utils/extensions/TrancheExtension.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "Tranche".
 */
contract PreviewWithdraw_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
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
        redeployAndSetTrancheState(vas, totalSupply, totalAssets);

        // When: previewWithdraw is called with assets.
        uint256 actualShares = trancheWrapper.previewWithdraw(assets);
        uint256 actualShares_ = tranche.previewWithdraw(assets);

        // Then: correct number of shares is returned.
        uint256 expectedShares = assets * (totalSupply + vas) / (uint256(totalAssets) + vas);
        // Rounds up.
        if ((uint256(totalAssets) + vas) * expectedShares < assets * (totalSupply + vas)) expectedShares++;
        assertEq(actualShares, expectedShares);
        assertEq(actualShares, actualShares_);
    }

    function testFuzz_Success_previewWithdraw_ZeroSupply(uint80 vas, uint128 totalAssets, uint256 assets) public {
        // And: Tranche state is set.
        redeployAndSetTrancheState(vas, 0, totalAssets);

        // When: previewWithdraw is called with assets.
        uint256 actualShares = trancheWrapper.previewWithdraw(assets);
        uint256 actualShares_ = tranche.previewWithdraw(assets);

        // Then: correct number of shares is returned.
        assertEq(actualShares, assets);
        assertEq(actualShares, actualShares_);
    }
}
