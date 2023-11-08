/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { AccountV1Malicious } from "../../utils/mocks/AccountV1Malicious.sol";
import { LendingPoolMalicious } from "../../utils/mocks/LendingPoolMalicious.sol";
import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */
contract GetAssetDistribution_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_GetAssetDistribution(uint256 totalValue_, uint8 totalAssetNumber) public {
        vm.assume(totalAssetNumber < 16);
        vm.assume(totalAssetNumber > 0);
        vm.assume(totalValue_ > totalAssetNumber);
        vm.assume(totalValue_ < type(uint256).max / 1e6);

        RiskModule.AssetValueAndRiskVariables[] memory riskValues_ =
            new RiskModule.AssetValueAndRiskVariables[](totalAssetNumber);
        for (uint256 i; i < totalAssetNumber;) {
            riskValues_[i].valueInBaseCurrency = totalValue_ / totalAssetNumber;

            unchecked {
                ++i;
            }
        }

        uint32[] memory distribution = liquidator.getAssetDistribution(riskValues_);

        uint256 totalDistribution;
        for (uint256 i; i < totalAssetNumber;) {
            totalDistribution += distribution[i];

            unchecked {
                ++i;
            }
        }

        // Then: The sum of the distribution should be 1_000_000 with a tolerance of 0.00001e18 = % 0,001 difference
        assertApproxEqRel(totalDistribution, 1_000_000, 0.00001e18);
    }
}
