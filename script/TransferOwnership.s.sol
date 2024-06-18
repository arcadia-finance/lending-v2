/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../lib/accounts-v2/lib/forge-std/src/Test.sol";

import { ArcadiaContracts, ArcadiaSafes } from "../lib/accounts-v2/script/utils/Constants.sol";
import { ArcadiaLending, ArcadiaLendingSafes } from "./utils/Constants.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { Liquidator } from "../src/Liquidator.sol";
import { Tranche } from "../src/Tranche.sol";

contract ArcadiaLendingTransferOwnership is Test {
    LendingPool internal lendingPool_usdc;
    LendingPool internal lendingPool_weth;
    Tranche internal srTranche_usdc;
    Tranche internal srTranche_weth;
    Liquidator internal liquidator;

    constructor() {
        lendingPool_usdc = LendingPool(ArcadiaContracts.LENDINGPOOL_USDC);
        lendingPool_weth = LendingPool(ArcadiaContracts.LENDINGPOOL_WETH);
        srTranche_usdc = Tranche(ArcadiaLending.TRANCHE_USDC);
        srTranche_weth = Tranche(ArcadiaLending.TRANCHE_WETH);
        liquidator = Liquidator(ArcadiaLending.LIQUIDATOR);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        vm.startBroadcast(ownerPrivateKey);

        // Set guardian
        lendingPool_usdc.changeGuardian(ArcadiaSafes.GUARDIAN);
        lendingPool_weth.changeGuardian(ArcadiaSafes.GUARDIAN);

        // Set account recipient
        liquidator.setAccountRecipient(address(lendingPool_usdc), ArcadiaLending.ACCOUNT_RECIPIENT);
        liquidator.setAccountRecipient(address(lendingPool_weth), ArcadiaLending.ACCOUNT_RECIPIENT);

        // Set risk manager
        lendingPool_usdc.setRiskManager(ArcadiaSafes.RISK_MANAGER);
        lendingPool_weth.setRiskManager(ArcadiaSafes.RISK_MANAGER);

        // Set treasury
        lendingPool_usdc.setTreasury(ArcadiaLendingSafes.TREASURY);
        lendingPool_weth.setTreasury(ArcadiaLendingSafes.TREASURY);

        // Transfer ownership to respected addresses
        lendingPool_usdc.transferOwnership(ArcadiaSafes.OWNER);
        lendingPool_weth.transferOwnership(ArcadiaSafes.OWNER);
        srTranche_usdc.transferOwnership(ArcadiaSafes.OWNER);
        srTranche_weth.transferOwnership(ArcadiaSafes.OWNER);
        liquidator.transferOwnership(ArcadiaSafes.OWNER);
        vm.stopBroadcast();
    }

    function test_transferOwnership() public {
        vm.skip(true);

        assertEq(lendingPool_usdc.guardian(), ArcadiaSafes.GUARDIAN);
        assertEq(lendingPool_weth.guardian(), ArcadiaSafes.GUARDIAN);

        assertEq(lendingPool_usdc.riskManager(), ArcadiaSafes.RISK_MANAGER);
        assertEq(lendingPool_usdc.riskManager(), ArcadiaSafes.RISK_MANAGER);

        assertEq(lendingPool_usdc.owner(), ArcadiaSafes.OWNER);
        assertEq(lendingPool_weth.owner(), ArcadiaSafes.OWNER);
        assertEq(srTranche_usdc.owner(), ArcadiaSafes.OWNER);
        assertEq(srTranche_weth.owner(), ArcadiaSafes.OWNER);
        assertEq(liquidator.owner(), ArcadiaSafes.OWNER);
    }
}
