/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Base_Test } from "../lib/accounts-v2/test/Base.t.sol";

import { AccountV1 } from "./utils/mocks/AccountV1.sol";
import { Asset } from "./utils/mocks/Asset.sol";
import { Events } from "./utils/Events.sol";
import { DebtToken } from "../src/DebtToken.sol";
import { Factory } from "./utils/mocks/Factory.sol";
import { LendingPoolExtension } from "./utils/Extensions.sol";
import { LiquidatorExtension } from "./utils/Extensions.sol";
import { Tranche } from "../src/Tranche.sol";

/// @notice Base test contract with common logic needed by all tests in Arcadia Lending repo.
abstract contract Base_Lending_Test is Base_Test, Events {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Asset internal asset;
    DebtToken internal debt;
    LendingPoolExtension internal pool;
    LiquidatorExtension internal liquidator;
    Tranche internal jrTranche;
    Tranche internal srTranche;
    Tranche internal tranche;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function deployArcadiaLending() internal virtual {
        // ToDo : move to Types users
        address treasury = address(34_567);

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        asset = new Asset("Asset", "ASSET", 18);
        liquidator = new LiquidatorExtension(address(factory));
        pool = new LendingPoolExtension(asset, treasury, address(factory), address(liquidator));
        srTranche = new Tranche(address(pool), "Senior", "SR");
        jrTranche = new Tranche(address(pool), "Junior", "JR");
        vm.stopPrank();

        // For clarity, some contracts have a generalised name in some tests.
        tranche = srTranche;

        // For clarity, some contracts with multiple functionalities (in different abstract contracts) have a different name in some tests.
        debt = DebtToken(address(pool));

        // Label the base test contracts.
        vm.label({ account: address(asset), newLabel: "Asset" });
        vm.label({ account: address(liquidator), newLabel: "Liquidator" });
        vm.label({ account: address(pool), newLabel: "Lending Pool" });
        vm.label({ account: address(srTranche), newLabel: "Senior Tranche" });
        vm.label({ account: address(jrTranche), newLabel: "Junior Tranche" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
