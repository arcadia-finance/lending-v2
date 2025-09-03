/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "Tranche".
 */
contract TotalAssets_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
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

    function testFuzz_Success_totalAssets_NonZeroSupply(
        uint128 initialShares,
        uint128 wrapperShares,
        uint128 initialAssets
    ) public {
        initialShares = uint128(bound(initialShares, 1, type(uint128).max));
        wrapperShares = uint128(bound(wrapperShares, 0, initialShares));

        setTrancheState(initialShares, wrapperShares, initialAssets);

        uint256 expectedAssets = uint256(wrapperShares) * initialAssets / initialShares;

        assertEq(trancheWrapper.totalAssets(), expectedAssets);
    }

    function testFuzz_Success_totalAssets_ZeroSupply(uint128 initialAssets) public {
        setTrancheState(0, 0, initialAssets);

        assertEq(trancheWrapper.totalAssets(), 0);
    }
}
