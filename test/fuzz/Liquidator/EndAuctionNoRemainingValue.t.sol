/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuctionNoRemainingValue" of contract "Liquidator".
 */

contract EndAuctionNoRemainingValue_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_EndAuctionNoRemainingValue_NotForSale() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator.endAuctionNoRemainingValue(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_EndAuctionNoRemainingValue_AccountValueIsNotZero(
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint256 amountLoaned
    ) public {
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_100, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9099));
        amountLoaned = bound(amountLoaned, 1, (type(uint128).max / 150) * 100); // No overflow when debt is increased

        vm.startPrank(users.creatorAddress);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(proxyAccount));

        // call to EndAuctionNoRemainingValue() should revert as the Account still has a remaining value
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_AccountValueIsNotZero.selector);
        liquidator.endAuctionNoRemainingValue(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Success_EndAuctionNoRemainingValue(
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint256 amountLoaned,
        address randomAddress
    ) public {
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_100, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9099));
        amountLoaned = bound(amountLoaned, 1, (type(uint128).max / 150) * 100);

        vm.startPrank(users.creatorAddress);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(proxyAccount));

        // Set debt back to initial debt to have correct accounting in settleLiquidation.
        debt.setRealisedDebt(uint256(amountLoaned));

        // By setting the minUsdValue of creditor to uint256 max value, remaining assets value should be 0.
        vm.prank(pool.riskManager());
        registryExtension.setMinUsdValueCreditor(address(pool), type(uint256).max);

        // endAuctionNoRemainingValue() should succeed.
        vm.startPrank(randomAddress);
        vm.expectEmit();
        // We use amountLoaned + 1 below as that was the value on the time of liquidateAccount() above.
        emit AuctionFinished(address(proxyAccount), address(pool), uint128(amountLoaned) + 1, 0, 0);
        liquidator.endAuctionNoRemainingValue(address(proxyAccount));
        vm.stopPrank();

        // The remaining tokens should be sent to protocol owner
        assertEq(mockERC20.stable1.balanceOf(liquidator.owner()), amountLoaned);
        assert(liquidator.getAuctionIsActive(address(proxyAccount)) == false);
    }
}
