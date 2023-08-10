/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

/**
 * @title Trusted Creditor implementation.
 * @author Pragma Labs
 * @notice This contract contains the minimum functionality a Trusted Creditor, interacting with Arcadia Accounts, needs to implement.
 * @dev For the implementation of Arcadia Accounts, see: https://github.com/arcadia-finance/accounts-v2.
 */
abstract contract TrustedCreditor {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Map accountVersion => status.
    mapping(uint256 => bool) public isValidVersion;

    /* //////////////////////////////////////////////////////////////
                            Account LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the validity of Account version to valid.
     * @param accountVersion The version current version of the Account.
     * @param valid The validity of the respective accountVersion.
     */
    function _setAccountVersion(uint256 accountVersion, bool valid) internal {
        isValidVersion[accountVersion] = valid;
    }

    /**
     * @notice Checks if Account fulfills all requirements and returns application settings.
     * @param accountVersion The current version of the Account.
     * @return success Bool indicating if all requirements are met.
     * @return baseCurrency The base currency of the application.
     * @return liquidator The liquidator of the application.
     * @return fixedLiquidationCost Estimated fixed costs (independent of size of debt) to liquidate a position.
     */
    function openMarginAccount(uint256 accountVersion)
        external
        virtual
        returns (bool success, address baseCurrency, address liquidator, uint256 fixedLiquidationCost);

    /**
     * @notice Returns the open position of the Account.
     * @param account The Account address.
     * @return openPosition The open position of the Account.
     */
    function getOpenPosition(address account) external view virtual returns (uint256 openPosition);
}
