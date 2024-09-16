/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Lending_Script } from "../Base.s.sol";

import {
    ArcadiaContracts,
    ArcadiaSafes,
    ExternalContracts,
    PrimaryAssets
} from "../../lib/accounts-v2/script/utils/Constants.sol";
import {
    ArcadiaLending,
    ArcadiaLendingSafes,
    InterestRateParameters,
    LiquidationParameters,
    MinimumMargins,
    VAS
} from "../utils/Constants.sol";
import { ERC20 } from "../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { LendingPool } from "../../src/LendingPool.sol";
import { Tranche } from "../../src/Tranche.sol";
import { TrancheWrapper } from "../../src/periphery/tranche-wrapper/TrancheWrapper.sol";

contract AddCbbtc is Base_Lending_Script {
    ERC20 internal cbbtc;
    TrancheWrapper internal wrappedTrancheCbbtc;

    constructor() Base_Lending_Script() {
        cbbtc = ERC20(PrimaryAssets.CBBTC);
    }

    function run() public {
        address deployerAddress = vm.addr(deployer);

        vm.startBroadcast(deployer);
        lendingPoolCbbtc = new LendingPool(
            deployerAddress,
            ERC20(address(cbbtc)),
            ArcadiaLendingSafes.TREASURY,
            ArcadiaContracts.FACTORY,
            address(liquidator)
        );
        trancheCbbtc = new Tranche(address(lendingPoolCbbtc), VAS.CBBTC, "Senior", "sr");
        wrappedTrancheCbbtc = new TrancheWrapper(address(trancheCbbtc));

        lendingPoolCbbtc.setAccountVersion(1, true);
        lendingPoolCbbtc.setMinimumMargin(MinimumMargins.CBBTC);
        lendingPoolCbbtc.setLiquidationParameters(
            LiquidationParameters.INITIATION_WEIGHT_CBBTC,
            LiquidationParameters.PENALTY_WEIGHT_CBBTC,
            LiquidationParameters.TERMINATION_WEIGHT_CBBTC,
            LiquidationParameters.MIN_REWARD_WEIGHT_CBBTC,
            LiquidationParameters.MAX_REWARD_CBBTC
        );
        lendingPoolCbbtc.setInterestParameters(
            InterestRateParameters.BASE_RATE_CBBTC,
            InterestRateParameters.LOW_SLOPE_CBBTC,
            InterestRateParameters.HIGH_SLOPE_CBBTC,
            InterestRateParameters.UTILISATION_THRESHOLD_CBBTC
        );

        lendingPoolCbbtc.changeGuardian(ArcadiaSafes.GUARDIAN);
        liquidator.setAccountRecipient(address(lendingPoolCbbtc), ArcadiaLending.ACCOUNT_RECIPIENT);
        lendingPoolCbbtc.setRiskManager(ArcadiaSafes.RISK_MANAGER);
        lendingPoolCbbtc.transferOwnership(ArcadiaSafes.OWNER);
        trancheCbbtc.transferOwnership(ArcadiaSafes.OWNER);
        vm.stopBroadcast();

        test_deploy();
    }

    function test_deploy() public {
        vm.skip(true);

        assertEq(lendingPoolCbbtc.name(), string("ArcadiaV2 Coinbase Wrapped BTC Debt"));
        assertEq(lendingPoolCbbtc.symbol(), string("darcV2cbBTC"));
        assertEq(lendingPoolCbbtc.decimals(), 8);

        assertEq(wrappedTrancheCbbtc.LENDING_POOL(), address(lendingPoolCbbtc));
        assertEq(wrappedTrancheCbbtc.TRANCHE(), address(trancheCbbtc));

        assertTrue(lendingPoolCbbtc.isValidVersion(1));
        (,,, uint256 minimumMargin) = lendingPoolCbbtc.openMarginAccount(1);
        assertEq(minimumMargin, MinimumMargins.CBBTC);

        (
            uint16 initiationWeight,
            uint16 penaltyWeight,
            uint16 terminationWeight,
            uint16 minRewardWeight,
            uint80 maxReward
        ) = lendingPoolCbbtc.getLiquidationParameters();
        assertEq(initiationWeight, LiquidationParameters.INITIATION_WEIGHT_CBBTC);
        assertEq(penaltyWeight, LiquidationParameters.PENALTY_WEIGHT_CBBTC);
        assertEq(terminationWeight, LiquidationParameters.TERMINATION_WEIGHT_CBBTC);
        assertEq(minRewardWeight, LiquidationParameters.MIN_REWARD_WEIGHT_CBBTC);
        assertEq(maxReward, LiquidationParameters.MAX_REWARD_CBBTC);

        (uint72 baseRatePerYear, uint72 lowSlopePerYear, uint72 highSlopePerYear, uint16 utilisationThreshold) =
            lendingPoolCbbtc.getInterestRateConfig();
        assertEq(baseRatePerYear, InterestRateParameters.BASE_RATE_CBBTC);
        assertEq(lowSlopePerYear, InterestRateParameters.LOW_SLOPE_CBBTC);
        assertEq(highSlopePerYear, InterestRateParameters.HIGH_SLOPE_CBBTC);
        assertEq(utilisationThreshold, InterestRateParameters.UTILISATION_THRESHOLD_CBBTC);

        assertEq(lendingPoolCbbtc.guardian(), ArcadiaSafes.GUARDIAN);
        assertEq(lendingPoolCbbtc.riskManager(), ArcadiaSafes.RISK_MANAGER);
        assertEq(lendingPoolCbbtc.owner(), ArcadiaSafes.OWNER);
        assertEq(trancheCbbtc.owner(), ArcadiaSafes.OWNER);
    }
}
