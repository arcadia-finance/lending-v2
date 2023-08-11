/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Test } from "lib/forge-std/src/Test.sol";
import { Factory } from "../src/mocks/Factory.sol";
import { AccountV1 } from "../src/mocks/AccountV1.sol";
import { Liquidator } from "../src/mocks/Liquidator.sol";
import { Asset } from "../src/mocks/Asset.sol";
import { Tranche } from "../src/Tranche.sol";
 
/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Global_Test is Test {
/*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    AccountV1 internal account;
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
        // Create users for testing
        users = Users({
            creatorAddress: createUser("creatorAddress"),
            tokenCreatorAddress: createUser("tokenCreatorAddress"),
            treasury: createUser("treasury"),
            vaultOwner: createUser("vaultOwner"),
            liquidityProvider: createUser("liquidityProvider"),
            liquidationInitiator: createUser("liquidationInitiator")
        });

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        asset = new Asset("Asset", "ASSET", 18);
        factory = new Factory();
        account = new AccountV1();
        liquidator = new Liquidator();
        lendingPoolExtension = new lendingPoolExtension(asset, users.treasury, address(factory), address(liquidator));
        srTranche = new Tranche(address(pool), "Senior", "SR");
        jrTranche = new Tranche(address(pool), "Junior", "JR");
        vm.stopPrank();
    }

/*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

/*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}