/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Lending_Script } from "../Base.s.sol";
import { Deployers, Safes } from "../../lib/accounts-v2/script/utils/constants/Shared.sol";
import { ERC20 } from "../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { LendingPool } from "../../src/LendingPool.sol";
import { LendingPoolParameters } from "../utils/constants/Base.sol";
import { LendingPoolParams, TrancheParams } from "../utils/constants/Shared.sol";
import { Tranche } from "../../src/Tranche.sol";
import { TrancheWrapper } from "../../src/periphery/tranche-wrapper/TrancheWrapper.sol";

contract AddCbbtc is Base_Lending_Script {
    /// forge-lint: disable-start(mixed-case-variable)
    LendingPool internal pool;
    LendingPoolParams internal POOL = LendingPoolParameters.CBBTC();
    Tranche internal tranche;
    TrancheParams internal TRANCHE = POOL.tranche;
    TrancheWrapper internal wrappedTranche;
    /// forge-lint: disable-end(mixed-case-variable)

    constructor() { }

    function run() public {
        require(vm.addr(deployer) == Deployers.ARCADIA, "Wrong deployer.");

        vm.startBroadcast(deployer);
        pool = new LendingPool(
            Safes.OWNER, Deployers.ARCADIA, ERC20(POOL.asset), Safes.TREASURY, address(factory), address(liquidator)
        );
        tranche = new Tranche(Safes.OWNER, address(pool), TRANCHE.vas, TRANCHE.prefix, TRANCHE.prefixSymbol);
        wrappedTranche = new TrancheWrapper(address(tranche));

        pool.addTranche(address(tranche), TRANCHE.interestWeight);
        pool.setLiquidationWeightTranche(POOL.liquidationWeightTranche);
        pool.setAccountVersion(1, true);
        pool.setMinimumMargin(POOL.minimumMargin);
        pool.setLiquidationParameters(
            POOL.liquidationParameters.initiationWeight,
            POOL.liquidationParameters.penaltyWeight,
            POOL.liquidationParameters.terminationWeight,
            POOL.liquidationParameters.minRewardWeight,
            POOL.liquidationParameters.maxReward
        );
        pool.setInterestParameters(
            POOL.interestRateParameters.baseRatePerYear,
            POOL.interestRateParameters.lowSlopePerYear,
            POOL.interestRateParameters.highSlopePerYear,
            POOL.interestRateParameters.utilisationThreshold
        );

        pool.changeGuardian(Safes.GUARDIAN);
        liquidator.setAccountRecipient(address(pool), Deployers.ARCADIA);
        pool.setRiskManager(Safes.RISK_MANAGER);
        pool.transferOwnership(Safes.OWNER);
        tranche.transferOwnership(Safes.OWNER);
        vm.stopBroadcast();

        test_deploy();
    }

    function test_deploy() public {
        vm.skip(false);

        assertEq(pool.name(), string("ArcadiaV2 Coinbase Wrapped BTC Debt"));
        assertEq(pool.symbol(), string("darcV2cbBTC"));
        assertEq(pool.decimals(), 8);

        assertEq(wrappedTranche.LENDING_POOL(), address(pool));
        assertEq(wrappedTranche.TRANCHE(), address(tranche));

        assertTrue(pool.isValidVersion(1));
        (,,, uint256 minimumMargin) = pool.openMarginAccount(1);
        assertEq(minimumMargin, POOL.minimumMargin);

        (
            uint16 initiationWeight,
            uint16 penaltyWeight,
            uint16 terminationWeight,
            uint16 minRewardWeight,
            uint80 maxReward
        ) = pool.getLiquidationParameters();
        assertEq(initiationWeight, POOL.liquidationParameters.initiationWeight);
        assertEq(penaltyWeight, POOL.liquidationParameters.penaltyWeight);
        assertEq(terminationWeight, POOL.liquidationParameters.terminationWeight);
        assertEq(minRewardWeight, POOL.liquidationParameters.minRewardWeight);
        assertEq(maxReward, POOL.liquidationParameters.maxReward);

        (uint72 baseRatePerYear, uint72 lowSlopePerYear, uint72 highSlopePerYear, uint16 utilisationThreshold) =
            pool.getInterestRateConfig();
        assertEq(baseRatePerYear, POOL.interestRateParameters.baseRatePerYear);
        assertEq(lowSlopePerYear, POOL.interestRateParameters.lowSlopePerYear);
        assertEq(highSlopePerYear, POOL.interestRateParameters.highSlopePerYear);
        assertEq(utilisationThreshold, POOL.interestRateParameters.utilisationThreshold);

        assertEq(pool.guardian(), Safes.GUARDIAN);
        assertEq(pool.riskManager(), Safes.RISK_MANAGER);
        assertEq(pool.owner(), Safes.OWNER);
        assertEq(tranche.owner(), Safes.OWNER);
    }
}
