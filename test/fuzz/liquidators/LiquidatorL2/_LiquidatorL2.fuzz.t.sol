/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Fuzz_Lending_Test } from "../../Fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Common logic needed by all "LiquidatorL2" fuzz tests.
 */
abstract contract LiquidatorL2_Fuzz_Test is Fuzz_Lending_Test {
    using stdStorage for StdStorage;

    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithAccounts();

        vm.prank(users.tokenCreator);
        mockERC20.stable1.mint(users.liquidityProvider, type(uint256).max);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function initiateLiquidation(uint112 amountLoaned) public {
        initiateLiquidation(0, amountLoaned);
    }

    function initiateLiquidation(uint96 minimumMargin, uint112 amountLoaned) public {
        // Given: Account has a minimumMargin.
        vm.prank(users.owner);
        pool.setMinimumMargin(minimumMargin);
        vm.startPrank(users.accountOwner);
        account.closeMarginAccount();
        account.openMarginAccount(address(pool));
        vm.stopPrank();

        // And: Account has debt.
        bytes3 emptyBytes3;
        uint256 collateralValue = uint256(minimumMargin) + amountLoaned;
        depositErc20InAccount(account, mockERC20.stable1, collateralValue);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value).
        debt.setRealisedDebt(uint256(amountLoaned + 1));
        stdstore.target(address(pool)).sig(pool.liquidityOf.selector).with_key(address(srTranche))
            .checked_write(amountLoaned + 1);
        pool.setTotalRealisedLiquidity(uint128(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount.
        liquidator.liquidateAccount(address(account));
    }
}
