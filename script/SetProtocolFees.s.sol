/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";

import { ArcadiaSafes } from "../lib/accounts-v2/script/utils/ConstantsBase.sol";
import { TrancheWeights, TreasuryWeights } from "./utils/ConstantsBase.sol";

contract SetProtocolFees is Base_Lending_Script {
    constructor() Base_Lending_Script() { }

    function run() public {
        // Set weights Treasury.
        bytes memory calldata_ =
            abi.encodeCall(lendingPoolCbbtc.setTreasuryWeights, (TreasuryWeights.INTEREST, TreasuryWeights.LIQUIDATION));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolCbbtc), calldata_);

        calldata_ =
            abi.encodeCall(lendingPoolUsdc.setTreasuryWeights, (TreasuryWeights.INTEREST, TreasuryWeights.LIQUIDATION));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolUsdc), calldata_);

        calldata_ =
            abi.encodeCall(lendingPoolWeth.setTreasuryWeights, (TreasuryWeights.INTEREST, TreasuryWeights.LIQUIDATION));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolWeth), calldata_);

        // Set interest weights Tranches.
        calldata_ = abi.encodeCall(lendingPoolCbbtc.setInterestWeightTranche, (0, TrancheWeights.INTEREST));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolCbbtc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolUsdc.setInterestWeightTranche, (0, TrancheWeights.INTEREST));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolUsdc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolWeth.setInterestWeightTranche, (0, TrancheWeights.INTEREST));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolWeth), calldata_);

        // Set liquidation weights Tranches.
        calldata_ = abi.encodeCall(lendingPoolCbbtc.setLiquidationWeightTranche, (TrancheWeights.LIQUIDATION));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolCbbtc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolUsdc.setLiquidationWeightTranche, (TrancheWeights.LIQUIDATION));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolUsdc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolWeth.setLiquidationWeightTranche, (TrancheWeights.LIQUIDATION));
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolWeth), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }
}
