/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Base_Test } from "../lib/accounts-v2/test/Base.t.sol";

import { AccountV1 } from "./utils/mocks/AccountV1.sol";
import { Asset } from "./utils/mocks/Asset.sol";
import { Errors } from "./utils/Errors.sol";
import { Events } from "./utils/Events.sol";
import { DebtTokenExtension } from "./utils/Extensions.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { LendingPoolExtension } from "./utils/Extensions.sol";
import { LendingPoolExtension_NEW } from "./utils/Extensions.sol";
import { LiquidatorExtension } from "./utils/Extensions.sol";
import { LiquidatorExtension_NEW } from "./utils/Extensions.sol";
import { Tranche } from "../src/Tranche.sol";

/// @notice Base test contract with common logic needed by all tests in Arcadia Lending repo.
abstract contract Base_Lending_Test is Base_Test, Errors, Events {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Asset internal asset;
    DebtTokenExtension internal debt;
    DebtTokenExtension internal debt_new;
    LendingPoolExtension internal pool;
    LendingPoolExtension_NEW internal pool_new;
    LiquidatorExtension internal liquidator;
    LiquidatorExtension_NEW internal liquidator_new;
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

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
