/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPool } from "../../../src/LendingPool.sol";
import { Constants } from "../../../lib/accounts-v2/test/utils/Constants.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "LendingPool".
 */
contract Constructor_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address treasury_, address factory_, address liquidator_) public {
        LendingPool pool_ = new LendingPool(ERC20(address(mockERC20.stable1)), treasury_, factory_, liquidator_);

        assertEq(pool_.name(), string("Arcadia STABLE1 Debt"));
        assertEq(pool_.symbol(), string("darcS1"));
        assertEq(pool_.decimals(), Constants.stableDecimals);
        assertEq(pool_.treasury(), treasury_);
        assertEq(pool_.accountFactory(), factory_);
        assertEq(pool_.liquidator(), liquidator_);
    }
}
