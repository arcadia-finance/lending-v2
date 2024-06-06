/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC4626 } from "../lib/solmate/src/mixins/ERC4626.sol";

/**
 * @title Tranche
 * @author Pragma Labs
 * @notice Each Lending Pool has one or more Tranche(s).
 * @dev
 */
contract TrancheWrapper is ERC4626 {
    // TODO : Main objective is to make our Tranche an ERC4626 compliant Vault. In as-is situation for the tranche, the safeTransferFrom function, used to transfer the assets from the account, is called in the Lending Pool and not the Tranche itself.
    // This deviates from ERC4626 compliance where the safeTransferFrom has to be called on the contract that mints the shares (the Tranche).
    // Therefore we are implementing a contract that acts as a wrapper for interactions with the Tranche and will be fully compliant.
    // Note :
    // - all view functions can be directly called on the tranche view functions
    // - Shares minted via the wrapper should be 1:1 with shares minted on the Tranche
    // - Deposit and Mint functions have to approve the LendingPool and not the Tranche (safeTransferFrom is called in Lending Pool)

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() { }

    /* //////////////////////////////////////////////////////////////
                                FUNCTIONS
    ////////////////////////////////////////////////////////////// */

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) { }
}
