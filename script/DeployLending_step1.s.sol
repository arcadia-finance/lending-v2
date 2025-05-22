/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../lib/accounts-v2/lib/forge-std/src/Test.sol";

import { ArcadiaSafes, ExternalContracts, PrimaryAssets } from "../lib/accounts-v2/script/utils/ConstantsBase.sol";
import { ERC20 } from "../src/DebtToken.sol";
import { Factory } from "../lib/accounts-v2/src/Factory.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { Liquidator } from "../src/Liquidator.sol";
import { Tranche } from "../src/Tranche.sol";

contract ArcadiaLendingDeploymentStep1 is Test {
    Factory public factory;
    ERC20 public weth;
    ERC20 public usdc;
    Liquidator public liquidator;

    LendingPool public pool_weth;
    Tranche public srTranche_weth;

    LendingPool public pool_usdc;
    Tranche public srTranche_usdc;

    constructor() {
        weth = ERC20(PrimaryAssets.WETH);
        usdc = ERC20(PrimaryAssets.USDC);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address protocolOwnerAddress = ArcadiaSafes.OWNER;

        assertEq(deployerAddress, protocolOwnerAddress);

        vm.startBroadcast(deployerPrivateKey);

        factory = new Factory();
        liquidator = new Liquidator(address(factory), ExternalContracts.SEQUENCER_UPTIME_ORACLE);

        pool_weth = new LendingPool(
            protocolOwnerAddress, ERC20(address(weth)), protocolOwnerAddress, address(factory), address(liquidator)
        );
        srTranche_weth = new Tranche(address(pool_weth), 10 ** 8, "Senior", "sr");

        pool_weth.addTranche(address(srTranche_weth), 100);
        pool_weth.setLiquidationWeightTranche(100);
        pool_weth.changeGuardian(protocolOwnerAddress);

        pool_usdc = new LendingPool(
            protocolOwnerAddress, ERC20(address(usdc)), protocolOwnerAddress, address(factory), address(liquidator)
        );
        srTranche_usdc = new Tranche(address(pool_usdc), 10 ** 6, "Senior", "sr");

        pool_usdc.addTranche(address(srTranche_usdc), 100);
        pool_usdc.setLiquidationWeightTranche(100);
        pool_usdc.changeGuardian(protocolOwnerAddress);

        vm.stopBroadcast();

        test_deploy();
    }

    function test_deploy() public {
        vm.skip(true);
        address protocolOwnerAddress = ArcadiaSafes.OWNER;

        assertEq(pool_weth.name(), string("ArcadiaV2 Wrapped Ether Debt"));
        assertEq(pool_weth.symbol(), string("darcV2WETH"));
        assertEq(pool_weth.decimals(), 18);
        assertEq(pool_weth.riskManager(), protocolOwnerAddress);

        assertEq(pool_usdc.name(), string("ArcadiaV2 USD Coin Debt"));
        assertEq(pool_usdc.symbol(), string("darcV2USDC"));
        assertEq(pool_usdc.decimals(), 6);
        assertEq(pool_usdc.riskManager(), protocolOwnerAddress);
    }
}
