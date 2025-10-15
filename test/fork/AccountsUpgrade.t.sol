/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountLogic, ArcadiaAccounts, Safes } from "../../lib/accounts-v2/script/utils/constants/Shared.sol";
import { AccountV1 } from "../../lib/accounts-v2/src/accounts/AccountV1.sol";
import { AccountSpot } from "../../lib/accounts-v2/src/accounts/AccountV2.sol";
import { AccountV3 } from "../../lib/accounts-v2/src/accounts/AccountV3.sol";
import { AccountV4 } from "../../lib/accounts-v2/src/accounts/AccountV4.sol";
import { ArcadiaLending } from "../../script/utils/constants/Shared.sol";
import { Base_Test } from "../Base.t.sol";
import { Factory } from "../../lib/accounts-v2/src/Factory.sol";
import { LendingPool } from "../../src/LendingPool.sol";
import { Utils } from "../../lib/accounts-v2/test/utils/Utils.sol";

/**
 * @notice Common logic needed by all fork tests.
 * @dev Each function that interacts with an external and deployed contract, must be fork tested with the actual deployed bytecode of said contract.
 * @dev While not always possible (since unlike with the fuzz tests, it is not possible to work with extension with the necessary getters and setter),
 * as much of the possible state configurations must be tested.
 */
contract Fork_Test is Base_Test {
    /*///////////////////////////////////////////////////////////////
                            CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    // forge-lint: disable-next-line(mixed-case-variable)
    string internal RPC_URL = vm.envString("RPC_URL_BASE");

    Factory internal constant FACTORY = Factory(ArcadiaAccounts.FACTORY);
    LendingPool internal constant POOL = LendingPool(ArcadiaLending.LENDINGPOOL_USDC);

    /*///////////////////////////////////////////////////////////////
                            VARIABLES
    ///////////////////////////////////////////////////////////////*/

    uint256 internal fork;

    AccountV1 internal accountMargin = AccountV1(0x11331c538eab48dd7aC6Fccf556B76CF8E49Ac26);
    AccountSpot internal accountSpot = AccountSpot(payable(0x6Ecd9B061eb01d372E3B75d990821335C0daA9D1));
    AccountV3 internal accountMargin_ = AccountV3(0x11331c538eab48dd7aC6Fccf556B76CF8E49Ac26);
    AccountV4 internal accountSpot_ = AccountV4(payable(0x6Ecd9B061eb01d372E3B75d990821335C0daA9D1));

    struct State {
        address numeraire;
        address owner;
        address liquidator;
        address registry;
        address creditor;
        address[] assetAddresses;
        uint256[] assetIds;
        uint256[] assetAmounts;
    }

    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/
    function setUp() public override { }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFork_AccountUpgrade_StorageLayOut() public {
        bytes32 leaf0 = keccak256(abi.encodePacked(uint256(1), uint256(3)));
        bytes32 leaf1 = keccak256(abi.encodePacked(uint256(2), uint256(4)));
        bytes32 root = Utils.commutativeKeccak256(leaf0, leaf1);

        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        // Set new accounts versions.
        vm.startPrank(Safes.OWNER);
        FACTORY.setNewAccountInfo(ArcadiaAccounts.REGISTRY, AccountLogic.V3, root, "");
        FACTORY.setNewAccountInfo(ArcadiaAccounts.REGISTRY, AccountLogic.V4, root, "");
        POOL.setAccountVersion(1, false);
        POOL.setAccountVersion(3, true);
        vm.stopPrank();

        uint256 freeMarginBefore = accountMargin.getFreeMargin();
        bytes32 stateHashMarginBefore = getState(accountMargin);
        bytes32 stateHashSpotBefore = getState(accountSpot);

        // Upgrade accounts.
        bytes32[] memory proofs = new bytes32[](1);
        proofs[0] = leaf1;
        vm.prank(accountMargin.owner());
        FACTORY.upgradeAccountVersion(address(accountMargin), 3, proofs);
        proofs[0] = leaf0;
        vm.prank(accountSpot.owner());
        FACTORY.upgradeAccountVersion(address(accountSpot), 4, proofs);

        uint256 freeMarginAfter = accountMargin.getFreeMargin();
        bytes32 stateHashMarginAfter = getState(accountMargin_);
        bytes32 stateHashSpotAfter = getState(accountSpot_);

        assertEq(freeMarginBefore, freeMarginAfter);
        assertEq(stateHashMarginBefore, stateHashMarginAfter);
        assertEq(stateHashSpotBefore, stateHashSpotAfter);
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function getState(AccountV1 account) internal view returns (bytes32 stateHash) {
        State memory state;
        state.numeraire = account.numeraire();
        state.owner = account.owner();
        state.liquidator = account.liquidator();
        state.registry = account.registry();
        state.creditor = account.creditor();
        (state.assetAddresses, state.assetIds, state.assetAmounts) = account.generateAssetData();

        stateHash = keccak256(abi.encode(state));
    }

    function getState(AccountSpot account) internal view returns (bytes32 stateHash) {
        State memory state;
        state.numeraire = account.numeraire();
        state.owner = account.owner();
        state.liquidator = account.liquidator();
        state.registry = account.registry();
        state.creditor = account.creditor();

        stateHash = keccak256(abi.encode(state));
    }

    function getState(AccountV3 account) internal view returns (bytes32 stateHash) {
        State memory state;
        state.numeraire = account.numeraire();
        state.owner = account.owner();
        state.liquidator = account.liquidator();
        state.registry = account.registry();
        state.creditor = account.creditor();
        (state.assetAddresses, state.assetIds, state.assetAmounts) = account.generateAssetData();

        stateHash = keccak256(abi.encode(state));
    }

    function getState(AccountV4 account) internal view returns (bytes32 stateHash) {
        State memory state;
        state.numeraire = account.numeraire();
        state.owner = account.owner();
        state.liquidator = account.liquidator();
        state.registry = account.registry();
        state.creditor = account.creditor();

        stateHash = keccak256(abi.encode(state));
    }
}
