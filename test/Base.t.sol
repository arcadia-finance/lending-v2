/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Test } from "../lib/accounts-v2/test/Base.t.sol";

import { AccountV1 } from "./utils/mocks/AccountV1.sol";
import { Asset } from "./utils/mocks/Asset.sol";
import { Events } from "./utils/Events.sol";
import { DebtTokenExtension } from "./utils/Extensions.sol";
import { LendingPoolExtension } from "./utils/Extensions.sol";
import { LiquidatorExtension } from "./utils/Extensions.sol";
import { LiquidatorExtension } from "./utils/Extensions.sol";
import { TrancheExtension } from "./utils/Extensions.sol";
import { Errors } from "./utils/Errors.sol";

/// @notice Base test contract with common logic needed by all tests in Arcadia Lending repo.
abstract contract Base_Lending_Test is Base_Test, Events, Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint16 internal ONE_4 = 10_000;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Asset internal asset;
    DebtTokenExtension internal debt;
    LendingPoolExtension internal pool;
    LiquidatorExtension internal liquidator;
    TrancheExtension internal jrTranche;
    TrancheExtension internal srTranche;
    TrancheExtension internal tranche;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();
    }
}
