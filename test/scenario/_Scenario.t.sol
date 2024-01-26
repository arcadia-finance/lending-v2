/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Lending_Test } from "../fuzz/Fuzz.t.sol";

import { Constants } from "../utils/Constants.sol";

/**
 * @notice Common logic needed by all scenario tests.
 * @dev Scenario's test some common end-to-end flows of multiple user interactions.
 */
abstract contract Scenario_Lending_Test is Fuzz_Lending_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    bytes3 internal emptyBytes3;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithAccounts();

        vm.prank(users.creatorAddress);
        pool.addTranche(address(tranche), 50);

        // Deposit funds in the pool.
        deal(address(mockERC20.stable1), users.liquidityProvider, type(uint128).max, true);

        vm.startPrank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        tranche.mint(type(uint128).max, users.liquidityProvider);
        vm.stopPrank();

        vm.startPrank(users.creatorAddress);
        pool.setAccountVersion(1, true);
        pool.setInterestParameters(
            Constants.interestRate, Constants.interestRate, Constants.interestRate, Constants.utilisationThreshold
        );
        vm.stopPrank();

        vm.prank(users.accountOwner);
        proxyAccount.openMarginAccount(address(pool));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/
}
