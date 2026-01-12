/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../lib/accounts-v2/src/libraries/Errors.sol";
import { AccountV3 } from "../../../../lib/accounts-v2/src/accounts/AccountV3.sol";
import { FixedPointMathLib } from "../../../../lib/accounts-v2/lib/solmate/src/utils/FixedPointMathLib.sol";
import { LendingPoolErrors } from "../../../../src/libraries/Errors.sol";
import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";
import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "liquidateAccount" of contract "LiquidatorL1".
 */
// forge-lint: disable-next-item(divide-before-multiply)
contract LiquidateAccount_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_liquidateAccount_NotAnAccount(address nonAccount, address caller) public {
        vm.assume(nonAccount != address(account));
        vm.assume(nonAccount != address(accountV3Logic));

        vm.prank(caller);
        vm.expectRevert(LiquidatorErrors.IsNotAnAccount.selector);
        liquidator_.liquidateAccount(nonAccount);
    }

    function testFuzz_Revert_liquidateAccount_AuctionOngoing(address liquidationInitiator, uint112 amountLoaned)
        public
    {
        // Given: Account auction is already started
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 150) * 100); // No overflow when debt is increased
        depositErc20InAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // And: Pool rewards are set to zero
        vm.prank(users.owner);
        pool.setLiquidationParameters(0, 0, 0, 0, 0);

        vm.prank(liquidationInitiator);
        liquidator_.liquidateAccount(address(account));

        bool isAuctionActive = liquidator_.getAuctionIsActive(address(account));
        assertEq(isAuctionActive, true);

        assertGe(pool.getAuctionsInProgress(), 1);

        // When Then: Liquidation Initiator calls liquidateAccount again, It should revert
        vm.startPrank(liquidationInitiator);
        vm.expectRevert(LiquidatorErrors.AuctionOngoing.selector);
        liquidator_.liquidateAccount(address(account));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_Account_Not_Exist(address liquidationInitiator, address account_) public {
        // Given: Account does not exist
        vm.assume(account_ != address(account));
        // When Then: Liquidate Account is called, It should revert
        vm.startPrank(liquidationInitiator);
        vm.expectRevert();
        liquidator_.liquidateAccount(address(account_));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NoCreditorInAccount(address liquidationInitiator) public {
        // Given: Account is there and no creditor
        address proxy_ = factory.createAccount(2, 0, address(0));
        AccountV3 proxyAccount_ = AccountV3(proxy_);

        // When Then: LiquidatorL1 tries to liquidate, It should revert because there is no creditor to call to get the account debt
        vm.startPrank(liquidationInitiator);
        vm.expectRevert();
        liquidator_.liquidateAccount(address(proxyAccount_));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotLiquidatable_NoDebt(address liquidationInitiator) public {
        // Given: Account has no debt
        vm.startPrank(liquidationInitiator);
        vm.expectRevert(LendingPoolErrors.IsNotAnAccountWithDebt.selector);
        liquidator_.liquidateAccount(address(account));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotLiquidatable_Healthy(
        address liquidationInitiator,
        uint112 amountLoaned
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint112).max - 2); // No overflow when debt is increased
        depositErc20InAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // And: Pool rewards are set to zero
        vm.prank(users.owner);
        pool.setLiquidationParameters(0, 0, 0, 0, 0);

        // When Then: Liquidation Initiator calls liquidateAccount, Account is not liquidatable
        vm.prank(liquidationInitiator);
        vm.expectRevert(AccountErrors.AccountNotLiquidatable.selector);
        liquidator_.liquidateAccount(address(account));
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt_ONE(
        uint112 amountLoaned,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxReward,
        address liquidationInitiator
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= 1100);

        // Given: Account has debt
        bytes3 emptyBytes3;
        depositErc20InAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // And: Liquidation parameters are set.
        vm.prank(users.owner);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, 0, maxReward);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator_.liquidateAccount(address(account));

        // Avoid stack too deep
        uint128 amountLoanedStack = amountLoaned;

        assertGe(pool.getAuctionsInProgress(), 1);

        // Then: Auction should be set and started
        (uint128 startDebt_, uint32 cutoffTime_, uint32 startTime_, bool inAuction_) =
            liquidator_.getAuctionInformationPartOne(address(account));

        assertEq(startDebt_, amountLoanedStack + 1);
        assertEq(inAuction_, true);
        assertEq(startTime_, block.timestamp);
        assertEq(cutoffTime_, liquidator_.getCutoffTime());
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt_PartTwo(
        uint112 amountLoaned,
        uint16 initiationWeight,
        uint16 penaltyWeight,
        uint16 terminationWeight,
        uint80 maxReward,
        address liquidationInitiator
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint256(amountLoaned) * initiationWeight <= (type(uint256).max));
        vm.assume(uint256(amountLoaned) * terminationWeight <= (type(uint256).max));
        vm.assume(uint256(amountLoaned) * penaltyWeight <= (type(uint256).max));
        vm.assume(uint32(initiationWeight) + penaltyWeight + terminationWeight <= 1100);

        // Given: Account has debt
        bytes3 emptyBytes3;
        depositErc20InAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // And: Liquidation parameters are set.
        vm.prank(users.owner);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, 0, maxReward);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator_.liquidateAccount(address(account));

        // Avoid stack too deep
        uint16 terminationWeightStack = terminationWeight;
        uint80 maxRewardStack = maxReward;
        uint16 penaltyWeightStack = penaltyWeight;
        uint16 initiationWeightStack = initiationWeight;
        uint128 openDebt_ = amountLoaned + 1;

        // Then: Auction should be set and started
        (uint256 initiationReward_, uint256 terminationReward_, uint256 liquidationPenaltyReward_) =
            pool.getCalculateRewards(openDebt_, 0);

        uint256 initiationReward = uint256(openDebt_).mulDivDown(initiationWeightStack, 10_000);
        initiationReward = initiationReward > maxRewardStack ? maxRewardStack : initiationReward;

        assertEq(initiationReward, initiationReward_);
        uint256 terminationReward = uint256(openDebt_).mulDivDown(terminationWeightStack, 10_000);
        terminationReward = terminationReward > maxRewardStack ? maxRewardStack : terminationReward;

        uint256 liquidationPenaltyReward = uint256(openDebt_).mulDivUp(penaltyWeightStack, 10_000);

        assertEq(terminationReward_, terminationReward);
        assertEq(liquidationPenaltyReward, liquidationPenaltyReward_);

        // And : Liquidation incentives should have been added to openDebt of Account
        assertEq(
            pool.getOpenPosition(address(account)),
            openDebt_ + initiationReward + liquidationPenaltyReward + terminationReward
        );
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt_PartThree(
        uint112 amountLoaned,
        uint8 initiationWeight,
        uint8 penaltyWeight,
        uint8 terminationWeight,
        uint80 maxReward,
        address liquidationInitiator
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint16(initiationWeight) + penaltyWeight + terminationWeight <= 1100);

        // Given: Account has debt
        bytes3 emptyBytes3;
        depositErc20InAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // And: Liquidation parameters are set.
        vm.prank(users.owner);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, 0, maxReward);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator_.liquidateAccount(address(account));

        // Avoid stack too deep
        uint256 amountLoanedStack = amountLoaned;

        (
            address trustedCreditor_,
            address[] memory assetAddresses_,
            uint32[] memory assetShares_,
            uint256[] memory assetAmounts_,
            uint256[] memory assetIds_
        ) = liquidator_.getAuctionInformationPartTwo(address(account));

        assertEq(trustedCreditor_, address(pool));
        assertEq(assetAddresses_[0], address(mockERC20.stable1));
        assertEq(assetShares_[0], ONE_4);
        assertEq(assetAmounts_[0], amountLoanedStack);
        assertEq(assetIds_[0], 0);
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt_ZeroTotalValue(
        uint112 amountLoaned,
        uint8 initiationWeight,
        uint8 penaltyWeight,
        uint8 terminationWeight,
        uint80 maxReward,
        address liquidationInitiator
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint16(initiationWeight) + penaltyWeight + terminationWeight <= 1100);

        // Given: Account has debt
        bytes3 emptyBytes3;
        depositErc20InAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // And: Liquidation parameters are set.
        vm.prank(users.owner);
        pool.setLiquidationParameters(initiationWeight, penaltyWeight, terminationWeight, 0, maxReward);

        // And : erc20Balances for mockERC20.stable1 is set to zero (in order for totalValue to equal 0 in _getAssetShares()).
        uint256 slot = stdstore.target(address(accountV3Logic)).sig(accountV3Logic.erc20Balances.selector)
            .with_key(address(mockERC20.stable1)).find();
        vm.store(address(account), bytes32(slot), bytes32(0));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator_.liquidateAccount(address(account));

        (,, uint32[] memory assetShares_,,) = liquidator_.getAuctionInformationPartTwo(address(account));

        // Then : assetShares should return 0.
        assertEq(assetShares_[0], 0);
    }
}
