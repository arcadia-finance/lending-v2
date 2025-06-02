/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";
import { LiquidatorL2 } from "../src/liquidators/LiquidatorL2.sol";
import { LiquidatorParameters, LiquidatorParams } from "./utils/constants/Shared.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract SetAuctionCurveParameters is Base_Lending_Script {
    LiquidatorParams internal LIQUIDATOR = LiquidatorParameters.LIQUIDATOR();

    constructor() Base_Lending_Script() { }

    function run() public {
        // Set auction parameters.
        addToBatch(Safes.OWNER, address(liquidator), setAuctionCurveParameters(LIQUIDATOR));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(Safes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function setAuctionCurveParameters(LiquidatorParams memory liquidator_)
        internal
        pure
        returns (bytes memory calldata_)
    {
        calldata_ = abi.encodeCall(
            LiquidatorL2.setAuctionCurveParameters,
            (
                liquidator_.halfLifeTime,
                liquidator_.cutoffTime,
                liquidator_.startPriceMultiplier,
                liquidator_.minPriceMultiplier
            )
        );
    }
}
