/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test_NEW } from "./_Liquidator.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { StdStorage } from "lib/forge-std/src/StdStorage.sol";
import { AccountV1Malicious } from "../../utils/mocks/AccountV1Malicious.sol";
import { LendingPoolMalicious } from "../../utils/mocks/LendingPoolMalicious.sol";

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

    function testFuzz_Revert_liquidateAccount_MaliciousAccount_NoDebtInCreditor(
        address liquidationInitiator,
        uint128 amountLoaned
    ) public {
        // Given: Arcadia Lending pool
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);

        // And: AccountV1Malicious is created
        AccountV1Malicious maliciousAccount = new AccountV1Malicious(address(pool_new));

        // When Then: Liquidation Initiator calls liquidateAccount, It should revert because of malicious account address does not have debt in creditor
        vm.prank(liquidationInitiator);
        vm.expectRevert("LP_SL: Not an Account with debt");
        liquidator_new.liquidateAccount(address(maliciousAccount));
    }

    function testFuzz_Success_liquidateAccount_MaliciousAccount_MaliciousCreditor_NoHarmToProtocol(
        address liquidationInitiator
    ) public {
        // Given: Malicious Lending pool
        LendingPoolMalicious pool_malicious = new LendingPoolMalicious();

        // And: AccountV1Malicious is created
        AccountV1Malicious maliciousAccount = new AccountV1Malicious(address(pool_malicious));

        // When Then: Liquidation Initiator calls liquidateAccount, It will succeed
        vm.prank(liquidationInitiator);
        liquidator_new.liquidateAccount(address(maliciousAccount));

        // And: No harm to protocol
        // Since lending pool is maliciousAccount, it will not represent the real value in the protocol
        // So, no harm to protocol

        // Then: Auction will be set but lending pool will not be in auction mode
        bool isAuctionActive = liquidator_new.getAuctionIsActive(address(maliciousAccount));
        assertEq(isAuctionActive, true);

        assertGe(pool_new.getAuctionsInProgress(), 0);
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt(address liquidationInitiator, uint128 amountLoaned)
        public
    {
        // Given: Account has debt
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 150) * 100); // No overflow when debt is increased
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

        uint256 startDebt = liquidator_new.getAuctionStartDebt(address(proxyAccount));
        uint256 loan = uint256(amountLoaned + 1) * 150 / 100;

        assertEq(startDebt, loan);

        assertGe(pool_new.getAuctionsInProgress(), 1);
    }
}
