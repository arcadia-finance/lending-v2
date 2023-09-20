/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/accounts-v2/src/test/Base_Global.t.sol";

import { Factory } from "../src/mocks/Factory.sol";
import { AccountV1 } from "../src/mocks/AccountV1.sol";
import { Liquidator } from "../src/mocks/Liquidator.sol";
import { Asset } from "../src/mocks/Asset.sol";
import { Tranche } from "../src/Tranche.sol";
 
/// @notice Base test contract with common logic needed by all tests in Arcadia Lending repo.
abstract contract Base_Lending_Test is Base_Global_Test {
/*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Liquidator internal liquidator;
    Tranche internal jrTranche;
    Tranche internal srTranche;
    LendingPoolExtension internal lendingPoolExtension;
    Asset internal asset;

/*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {

        Base_Global_Test.setUp();

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        asset = new Asset("Asset", "ASSET", 18);
        liquidator = new Liquidator();
        lendingPoolExtension = new lendingPoolExtension(asset, users.treasury, address(factory), address(liquidator));
        srTranche = new Tranche(address(pool), "Senior", "SR");
        jrTranche = new Tranche(address(pool), "Junior", "JR");
        vm.stopPrank();

        // Label the base test contracts.
        vm.label({ account: address(asset), newLabel: "Asset" });
        vm.label({ account: address(liquidator), newLabel: "Liquidator" });
        vm.label({ account: address(lendingPoolExtension), newLabel: "Lending Pool Extension" });
        vm.label({ account: address(srTranche), newLabel: "Senior Tranche" });
        vm.label({ account: address(jrTranche), newLabel: "Junior Tranche" });
    }

/*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}