/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPoolExtension } from "../../utils/Extensions.sol";
import { Constants } from "../../../lib/accounts-v2/test/utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "LendingPool".
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
    function testFuzz_Success_deployment(address riskManager_, address treasury_, address factory_, address liquidator_)
        public
    {
        LendingPoolExtension pool_ =
            new LendingPoolExtension(riskManager_, ERC20(address(mockERC20.stable1)), treasury_, factory_, liquidator_);

        assertEq(pool_.name(), string("ArcadiaV2 STABLE1 Debt"));
        assertEq(pool_.symbol(), string("darcV2S1"));
        assertEq(pool_.decimals(), Constants.stableDecimals);
        assertEq(pool_.riskManager(), riskManager_);
        assertEq(pool_.getTreasury(), treasury_);
        assertEq(pool_.getAccountFactory(), factory_);
        assertEq(pool_.getLiquidator(), liquidator_);
    }
}
