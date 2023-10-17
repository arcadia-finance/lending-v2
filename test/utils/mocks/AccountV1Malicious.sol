/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

contract AccountV1Malicious {
    address public trustedCreditor;

    constructor(address _trustedCreditor) payable {
        trustedCreditor = _trustedCreditor;
    }

    function checkAndStartLiquidation()
        external
        view
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address creditor_,
            uint256 totalOpenDebt,
            RiskModule.AssetValueAndRiskVariables[] memory assetAndRiskValues
        )
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(0);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 0;

        creditor_ = trustedCreditor;

        totalOpenDebt = 10_000_000_000_000_000_000;

        assetAndRiskValues = new RiskModule.AssetValueAndRiskVariables[](1);
        assetAndRiskValues[0].valueInBaseCurrency = 100_000_000_000_000_000_000;
        assetAndRiskValues[0].collateralFactor = 50;
        assetAndRiskValues[0].liquidationFactor = 60;
    }
}
