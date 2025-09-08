/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Test } from "../lib/accounts-v2/test/Base.t.sol";

import { DebtTokenExtension } from "./utils/extensions/DebtTokenExtension.sol";
import { LendingPoolExtension } from "./utils/extensions/LendingPoolExtension.sol";
import { LiquidatorL2Extension } from "./utils/extensions/LiquidatorL2Extension.sol";
import { TrancheExtension } from "./utils/extensions/TrancheExtension.sol";

/// @notice Base test contract with common logic needed by all tests in Arcadia Lending repo.
abstract contract Base_Lending_Test is Base_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint16 internal ONE_4 = 10_000;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    DebtTokenExtension internal debt;
    LendingPoolExtension internal pool;
    LiquidatorL2Extension internal liquidator;
    TrancheExtension internal tranche;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Test.setUp();
    }
}
