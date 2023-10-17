/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test_NEW } from "./_Liquidator.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { StdStorage } from "lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */
contract LiquidateAccount_Liquidator_Fuzz_Test_NEW is Liquidator_Fuzz_Test_NEW {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test_NEW.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_liquidateAccount_Account_Not_Exist(address liquidationInitiator, address account_)
        public
    {
        // Given: Account does not exist
        vm.assume(account_ != address(proxyAccount));
        // When Then: Liquidate Account is called, It should revert
        vm.startPrank(liquidationInitiator);
        vm.expectRevert();
        liquidator_new.liquidateAccount(address(account_));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotLiquidatable_NoDebt(address liquidationInitiator) public {
        // Given: Account has no debt
        vm.startPrank(liquidationInitiator);
        vm.expectRevert("A_CASL, Account not liquidatable");
        liquidator_new.liquidateAccount(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotLiquidatable_Healthy(
        address liquidationInitiator,
        uint128 amountLoaned
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint128).max - 2); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool_new.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // When Then: Liquidation Initiator calls liquidateAccount, Account is not liquidatable
        vm.prank(liquidationInitiator);
        vm.expectRevert("A_CASL, Account not liquidatable");
        liquidator_new.liquidateAccount(address(proxyAccount));
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt(address liquidationInitiator, uint128 amountLoaned)
        public
    {
        // Given: Account has debt
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint128).max - 2); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool_new.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt_new.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator_new.liquidateAccount(address(proxyAccount));

        // Then: Auction should be set and started
        bool isAuctionActive = liquidator_new.getAuctionIsActive(address(proxyAccount));
        assertEq(isAuctionActive, true);

        uint128 startDebt = liquidator_new.getAuctionStartDebt(address(proxyAccount));
        assertEq(startDebt, uint128(amountLoaned + 1));

        assertGe(pool_new.getAuctionsInProgress(), 0);
    }
}
