/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { ArcadiaLending } from "./utils/constants/Shared.sol";
import { Base_Script } from "../lib/accounts-v2/script/Base.s.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { LiquidatorL2 } from "../src//liquidators/LiquidatorL2.sol";
import { Tranche } from "../src/Tranche.sol";

abstract contract Base_Lending_Script is Base_Script {
    LendingPool internal lendingPoolCbbtc = LendingPool(ArcadiaLending.LENDINGPOOL_CBBTC);
    LendingPool internal lendingPoolUsdc = LendingPool(ArcadiaLending.LENDINGPOOL_USDC);
    LendingPool internal lendingPoolWeth = LendingPool(ArcadiaLending.LENDINGPOOL_WETH);
    LiquidatorL2 internal liquidator = LiquidatorL2(ArcadiaLending.LIQUIDATOR);
    Tranche internal trancheCbbtc = Tranche(ArcadiaLending.TRANCHE_CBBTC);
    Tranche internal trancheUsdc = Tranche(ArcadiaLending.TRANCHE_USDC);
    Tranche internal trancheWeth = Tranche(ArcadiaLending.TRANCHE_WETH);

    constructor() {
        deployer = vm.envUint("PRIVATE_KEY_DEPLOYER");
    }
}
