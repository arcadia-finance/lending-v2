/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IAccount {
    /**
     * @notice Returns the address of the owner of the Account.
     */
    function owner() external view returns (address);

    /**
     * @notice Checks if the Account is healthy and still has free margin.
     * @param amount The amount with which the position is increased.
     * @param totalOpenDebt The total open Debt against the Account.
     * @return success Boolean indicating if there is sufficient margin to back a certain amount of Debt.
     * @return trustedCreditor_ The contract address of the trusted creditor.
     * @return accountVersion_ The Account version.
     * @dev Only one of the values can be non-zero, or we check on a certain increase of debt, or we check on a total amount of debt.
     */
    function isAccountHealthy(uint256 amount, uint256 totalOpenDebt) external view returns (bool, address, uint256);

    /**
     * @notice Function called by Liquidator to start liquidation of the Account.
     * @param openDebt The open debt taken by `originalOwner` at moment of liquidation at trustedCreditor
     * @return originalOwner The original owner of this Account.
     * @return baseCurrency The baseCurrency in which the Account is denominated.
     * @return trustedCreditor The account or contract that is owed the debt.
     */
    function liquidateAccount(uint256 openDebt) external returns (address, address, address);

    /**
     * @notice Calls external action handler to execute and interact with external logic.
     * @param actionHandler The address of the action handler.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return trustedCreditor_ The contract address of the trusted creditor.
     * @return accountVersion_ The Account version.
     */
    function accountManagementAction(address actionHandler, bytes calldata actionData, bytes calldata signature)
        external
        returns (address, uint256);
}
