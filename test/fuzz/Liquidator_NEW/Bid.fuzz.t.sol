/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test_NEW } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { AccountV1Malicious } from "../../utils/mocks/AccountV1Malicious.sol";
import { LendingPoolMalicious } from "../../utils/mocks/LendingPoolMalicious.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */
contract Bid_Liquidator_Fuzz_Test_NEW is Liquidator_Fuzz_Test_NEW {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test_NEW.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_bid_(address bidder, address account_)
        public
    {
        // Given: Account is not in the auction
        uint256[] memory assetAmounts = new uint256[](1);
        uint256[] memory assetIds = new uint256[](1);
        // When Then: Bid is called, It should revert
        vm.startPrank(bidder);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator_new.bid(address(account_), assetAmounts, assetIds);
        vm.stopPrank();
    }

}
