/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";
import { BaseGuardian } from "../lib/accounts-v2/src/guardians/BaseGuardian.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract CircuitBreaker is Base_Lending_Script {
    address internal SAFE = Safes.GUARDIAN;

    constructor() Base_Lending_Script() { }

    function run() public {
        // ToDo: uncomment when cooldown period passed.
        // // Pause Lending Pools.
        // bytes memory calldata_ = abi.encodeCall(lendingPoolCbbtc.pause, ());
        // addToBatch(Safes.GUARDIAN, address(lendingPoolCbbtc), calldata_);

        // calldata_ = abi.encodeCall(lendingPoolUsdc.pause, ());
        // addToBatch(Safes.GUARDIAN, address(lendingPoolUsdc), calldata_);

        // calldata_ = abi.encodeCall(lendingPoolWeth.pause, ());
        // addToBatch(Safes.GUARDIAN, address(lendingPoolWeth), calldata_);

        // // Pause Registry.
        // calldata_ = abi.encodeCall(registry.pause, ());
        // addToBatch(Safes.GUARDIAN, address(registry), calldata_);

        // // Pause Factory.
        // calldata_ = abi.encodeCall(factory.pause, ());
        // addToBatch(Safes.GUARDIAN, address(factory), calldata_);

        // Asset Managers.
        pause(Compounders.SLIPSTREAM);
        pause(Compounders.UNISWAP_V3);
        pause(Compounders.UNISWAP_V4);
        pause(Rebalancers.SLIPSTREAM);
        pause(Rebalancers.UNISWAP_V3);
        pause(Rebalancers.UNISWAP_V4);
        pause(YieldClaimers.SLIPSTREAM);
        pause(YieldClaimers.UNISWAP_V3);
        pause(YieldClaimers.UNISWAP_V4);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }

    function pause(address target) internal {
        addToBatch(SAFE, target, abi.encodeCall(BaseGuardian.pause, ()));
    }
}

library Compounders {
    address constant SLIPSTREAM = 0x4694c34d153EE777CC07d01AC433bcC010A20EBd;
    address constant UNISWAP_V3 = 0x80D3548bc54710d46201D554712E8638fD51326D;
    address constant UNISWAP_V4 = 0xCfF15E24a453aFAd454533E6D10889A84e2A68e1;
}

library Rebalancers {
    address constant SLIPSTREAM = 0xEfe600366e9847D405f2238cF9196E33780B3A42;
    address constant UNISWAP_V3 = 0xD8285fC23eFF687B8b618b78d85052f1eD17236E;
    address constant UNISWAP_V4 = 0xa8676C8c197E12a71AE82a08B02DD9e666312cF1;
}

library YieldClaimers {
    address constant SLIPSTREAM = 0x1f75aBF8a24782053B351D9b4EA6d1236ED59105;
    address constant UNISWAP_V3 = 0x40462e71Effd9974Fee04B6b327B701D663f753e;
    address constant UNISWAP_V4 = 0x3BC2B398eEEE9807ff76fdb4E11526dE0Ee80cEa;
}
