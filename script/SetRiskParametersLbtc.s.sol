/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Lending_Script } from "./Base.s.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { AssetRiskParameters } from "./utils/constants/Base.sol";
import { AssetRiskParams } from "./utils/constants/Shared.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract SetRiskParametersLbtc is Base_Lending_Script {
    address SAFE = Safes.RISK_MANAGER;

    constructor() { }

    function run() public {
        // Set risk parameters.
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.LBTC_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.LBTC_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.LBTC_WETH()));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }

    function setRiskParameters(AssetRiskParams memory params) internal view returns (bytes memory calldata_) {
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (params.creditor, params.asset, 0, params.maxExposure, params.collateralFactor, params.liquidationFactor)
        );
    }
}
