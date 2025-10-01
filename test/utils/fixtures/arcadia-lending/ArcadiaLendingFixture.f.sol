/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Lending_Test } from "../../../Base.t.sol";

import { ERC20 } from "../../../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { DebtTokenExtension } from "../../extensions/DebtTokenExtension.sol";
import { LendingPoolExtension } from "../../extensions/LendingPoolExtension.sol";
import { LiquidatorL2Extension } from "../../extensions/LiquidatorL2Extension.sol";
import { TrancheExtension } from "../../extensions/TrancheExtension.sol";

contract ArcadiaLendingFixture is Base_Lending_Test {
    function deployArcadiaLending(address numeraire) internal {
        vm.startPrank(users.owner);
        liquidator = new LiquidatorL2Extension(users.owner, address(factory), address(sequencerUptimeOracle));
        pool = new LendingPoolExtension(
            users.owner, users.riskManager, ERC20(numeraire), users.treasury, address(factory), address(liquidator)
        );
        pool.changeGuardian(users.guardian);
        vm.stopPrank();

        debt = DebtTokenExtension(address(pool));

        vm.label({ account: address(liquidator), newLabel: "Liquidator" });
        vm.label({ account: address(pool), newLabel: "Lending Pool" });
    }

    function initArcadiaLending() internal {
        vm.startPrank(users.owner);
        pool.setTreasuryWeights(10, 80);
        pool.setLiquidationParameters(100, 500, 50, 0, 0);
        pool.setLiquidationWeightTranche(20);
        pool.setAccountVersion(3, true);
        vm.stopPrank();

        vm.startPrank(users.riskManager);
        registry.setRiskParameters(address(pool), 0, 0 minutes, type(uint64).max);
        registry.setRiskParametersOfPrimaryAsset(address(pool), address(pool.asset()), 0, type(uint112).max, 1e4, 1e4);
        liquidator.setAccountRecipient(address(pool), users.riskManager);
        vm.stopPrank();

        // Open Margin Account.
        vm.prank(users.accountOwner);
        account.openMarginAccount(address(pool));
    }

    function createTranche(string memory prefix, string memory prefixSymbol, uint16 interestWeight)
        internal
        returns (TrancheExtension tranche_)
    {
        vm.startPrank(users.owner);
        tranche_ = new TrancheExtension(users.owner, address(pool), 0, prefix, prefixSymbol);
        pool.addTranche(address(tranche_), interestWeight);
        vm.stopPrank();

        vm.label({ account: address(tranche_), newLabel: string(abi.encodePacked(prefix, " Tranche")) });
    }
}
