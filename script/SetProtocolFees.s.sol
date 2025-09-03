/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { LendingPoolParams } from "./utils/constants/Shared.sol";
import { LendingPoolParameters } from "./utils/constants/Base.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract SetProtocolFees is Base_Lending_Script {
    constructor() Base_Lending_Script() { }

    function run() public {
        //Set fees.
        LendingPoolParams memory POOL = LendingPoolParameters.CBBTC();
        addToBatch(Safes.OWNER, address(lendingPoolCbbtc), setTreasuryWeights(POOL));
        addToBatch(Safes.OWNER, address(lendingPoolCbbtc), setInterestWeightTranche(POOL));
        addToBatch(Safes.OWNER, address(lendingPoolCbbtc), setLiquidationWeightTranche(POOL));

        POOL = LendingPoolParameters.USDC();
        addToBatch(Safes.OWNER, address(lendingPoolUsdc), setTreasuryWeights(POOL));
        addToBatch(Safes.OWNER, address(lendingPoolUsdc), setInterestWeightTranche(POOL));
        addToBatch(Safes.OWNER, address(lendingPoolUsdc), setLiquidationWeightTranche(POOL));

        POOL = LendingPoolParameters.WETH();
        addToBatch(Safes.OWNER, address(lendingPoolWeth), setTreasuryWeights(POOL));
        addToBatch(Safes.OWNER, address(lendingPoolWeth), setInterestWeightTranche(POOL));
        addToBatch(Safes.OWNER, address(lendingPoolWeth), setLiquidationWeightTranche(POOL));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(Safes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function setTreasuryWeights(LendingPoolParams memory pool_) internal pure returns (bytes memory calldata_) {
        calldata_ = abi.encodeCall(
            LendingPool.setTreasuryWeights, (pool_.treasury.interestWeight, pool_.treasury.liquidationWeight)
        );
    }

    function setInterestWeightTranche(LendingPoolParams memory pool_) internal pure returns (bytes memory calldata_) {
        calldata_ = abi.encodeCall(LendingPool.setInterestWeightTranche, (0, pool_.tranche.interestWeight));
    }

    function setLiquidationWeightTranche(LendingPoolParams memory pool_)
        internal
        pure
        returns (bytes memory calldata_)
    {
        calldata_ = abi.encodeCall(LendingPool.setLiquidationWeightTranche, (pool_.liquidationWeightTranche));
    }
}
