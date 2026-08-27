/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

import { LendingPool } from "../../../../src/LendingPool.sol";

/**
 * @notice Fuzz tests for the function "_settleUnhappyFlow" of contract "LiquidatorL2".
 * @dev "_settleUnhappyFlow" has no own reverts, it settles the bad debt and transfers the Account to the recipient.
 */
contract SettleUnhappyFlow_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();

        // Set grace period to 0.
        vm.prank(users.riskManager);
        registry.setRiskParameters(address(pool), 0, 0 minutes, type(uint64).max);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_settleUnhappyFlow(uint112 usedMargin, uint96 minimumMargin, address caller) public {
        // Given: The caller is not the zero address.
        vm.assume(caller != address(0));

        // And: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // When: settleUnhappyFlow is called.
        vm.prank(caller);
        vm.expectEmit(true, true, true, false);
        emit LendingPool.AuctionFinished(address(account), address(pool), uint128(amountLoaned + 1), 0, 0, 0, 0, 0);
        liquidator.settleUnhappyFlow(address(account), amountLoaned + 1, minimumMargin, address(pool));

        // Then: The Account is transferred to the Account recipient.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
    }
}
