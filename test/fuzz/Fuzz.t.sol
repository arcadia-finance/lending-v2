/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Base_Lending_Test } from "../Base.t.sol";
import { Base_IntegrationAndUnit_Test } from "../../lib/accounts-v2/src/test/Base_IntegrationAndUnit.t.sol";

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

import { AccountV1 } from "../../lib/accounts-v2/src/AccountV1.sol";
import { LendingPoolExtension } from "../utils/Extensions.sol";
import { LiquidatorExtension } from "../utils/Extensions.sol";
import { Tranche } from "../../src/Tranche.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 * @dev Each function must be fuzz tested over its full space of possible state configurations
 * (both the state variables of the contract being tested
 * as the state variables of any external contract with which the function interacts).
 * @dev in practice each input parameter and state variable (as explained above) must be tested over its full range
 * (eg. a uint256 from 0 to type(uint256).max), unless the parameter/variable is bound by an invariant.
 * If this case, said invariant must be explicitly tested in the invariant tests.
 */
abstract contract Fuzz_Lending_Test is Base_Lending_Test, Base_IntegrationAndUnit_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    AccountV1 internal proxyAccount;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override(Base_Lending_Test, Base_IntegrationAndUnit_Test) {
        Base_Lending_Test.setUp();
        Base_IntegrationAndUnit_Test.setUp();

        deployArcadiaLending();

        proxyAccount = AccountV1(deployedAccountInputs0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function deployArcadiaLending() internal override {
        // ToDo : move to Types users
        address treasury = address(34_567);

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        liquidator = new LiquidatorExtension(address(factory));
        pool =
            new LendingPoolExtension(ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator));
        srTranche = new Tranche(address(pool), "Senior", "SR");
        jrTranche = new Tranche(address(pool), "Junior", "JR");
        vm.stopPrank();

        // Label the base test contracts.
        vm.label({ account: address(liquidator), newLabel: "Liquidator" });
        vm.label({ account: address(pool), newLabel: "Lending Pool" });
        vm.label({ account: address(srTranche), newLabel: "Senior Tranche" });
        vm.label({ account: address(jrTranche), newLabel: "Junior Tranche" });
    }
}
