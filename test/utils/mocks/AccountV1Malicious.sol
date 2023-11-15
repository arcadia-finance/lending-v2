/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

contract AccountV1Malicious {
    address public creditor;
    uint256 public totalOpenDebt;
    uint256 public valueInBaseCurrency;
    uint256 public collateralFactor;
    uint256 public liquidationFactor;
    address public owner;

    constructor(
        address trustedCreditor_,
        uint256 totalOpenDebt_,
        uint256 valueInBaseCurrency_,
        uint256 collateralFactor_,
        uint256 liquidationFactor_
    ) payable {
        creditor = trustedCreditor_;
        totalOpenDebt = totalOpenDebt_;
        valueInBaseCurrency = valueInBaseCurrency_;
        collateralFactor = collateralFactor_;
        liquidationFactor = liquidationFactor_;
        owner = msg.sender;
    }

    function checkAndStartLiquidation()
        external
        view
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address owner_,
            address creditor_,
            uint256 totalOpenDebt_,
            RiskModule.AssetValueAndRiskFactors[] memory assetAndRiskValues
        )
    {
        assetAddresses = new address[](1);
        assetAddresses[0] = address(0);

        assetIds = new uint256[](1);
        assetIds[0] = 0;

        assetAmounts = new uint256[](1);
        assetAmounts[0] = 0;

        creditor_ = creditor;
        owner_ = owner;

        totalOpenDebt_ = totalOpenDebt;

        assetAndRiskValues = new RiskModule.AssetValueAndRiskFactors[](1);
        assetAndRiskValues[0].assetValue = valueInBaseCurrency;
        assetAndRiskValues[0].collateralFactor = collateralFactor;
        assetAndRiskValues[0].liquidationFactor = liquidationFactor;
    }
}
