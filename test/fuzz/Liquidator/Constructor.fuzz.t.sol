/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { LiquidatorExtension } from "../../utils/Extensions.sol";
import { LiquidatorErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "Liquidator".
 */
contract Constructor_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    LiquidatorExtension internal liquidator_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_deployment_SequencerDown(address factory_, uint32 startedAt) public {
        sequencerUptimeOracle.setLatestRoundData(1, startedAt);

        vm.expectRevert(LiquidatorErrors.SequencerDown.selector);
        new LiquidatorExtension(factory_, address(sequencerUptimeOracle));
    }

    function testFuzz_Revert_deployment_OracleReverting(address factory_, int256 answer, uint32 startedAt) public {
        sequencerUptimeOracle.setLatestRoundData(answer, startedAt);

        sequencerUptimeOracle.setRevertsFlag(true);

        vm.expectRevert(LiquidatorErrors.OracleReverting.selector);
        new LiquidatorExtension(factory_, address(sequencerUptimeOracle));
    }

    function testFuzz_Success_deployment(address factory_, uint32 startedAt) public {
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        vm.expectEmit(true, true, true, true);
        emit AuctionCurveParametersSet(999_807_477_651_317_446, 14_400, 15_000, 6000);
        liquidator_ = new LiquidatorExtension(factory_, address(sequencerUptimeOracle));

        assertEq(liquidator_.getSequencerUptimeOracle(), address(sequencerUptimeOracle));
        assertEq(liquidator_.getAccountFactory(), factory_);
        assertEq(liquidator_.getBase(), 999_807_477_651_317_446);
        assertEq(liquidator_.getCutoffTime(), 14_400);
        assertEq(liquidator_.getStartPriceMultiplier(), 15_000);
        assertEq(liquidator_.getMinPriceMultiplier(), 6000);
    }
}
