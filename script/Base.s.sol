/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../lib/accounts-v2/script/Base.s.sol";

import { ArcadiaContracts } from "../lib/accounts-v2/script/utils/Constants.sol";
import { ArcadiaLending } from "./utils/Constants.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { Liquidator } from "../src/Liquidator.sol";
import { Tranche } from "../src/Tranche.sol";

abstract contract Base_Lending_Script is Base_Script {
    LendingPool internal lendingPoolCbbtc = LendingPool(ArcadiaContracts.LENDINGPOOL_CBBTC);
    LendingPool internal lendingPoolUsdc = LendingPool(ArcadiaContracts.LENDINGPOOL_USDC);
    LendingPool internal lendingPoolWeth = LendingPool(ArcadiaContracts.LENDINGPOOL_WETH);
    Liquidator internal liquidator = Liquidator(ArcadiaLending.LIQUIDATOR);
    Tranche internal trancheCbbtc = Tranche(ArcadiaLending.TRANCHE_CBBTC);
    Tranche internal trancheUsdc = Tranche(ArcadiaLending.TRANCHE_USDC);
    Tranche internal trancheWeth = Tranche(ArcadiaLending.TRANCHE_WETH);

    constructor() {
        deployer = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
    }
}
