/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";

import { ArcadiaSafes } from "../lib/accounts-v2/script/utils/ConstantsBase.sol";
import { LiquidatorParameters } from "./utils/ConstantsBase.sol";

contract SetAuctionCurveParameters is Base_Lending_Script {
    constructor() Base_Lending_Script() { }

    function run() public {
        // Set auction parameters.
        bytes memory calldata_ = abi.encodeCall(
            liquidator.setAuctionCurveParameters,
            (
                LiquidatorParameters.HALF_LIFE_TIME,
                LiquidatorParameters.CUTOFF_TIME,
                LiquidatorParameters.START_PRICE_MULTIPLIER,
                LiquidatorParameters.MIN_PRICE_MULTIPLIER
            )
        );
        addToBatch(ArcadiaSafes.OWNER, address(liquidator), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
