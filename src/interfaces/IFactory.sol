/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IFactory {
    /**
     * @notice View function returning if an address is a Account.
     * @param account The address to be checked.
     * @return bool Whether the address is a Account or not.
     */
    function isAccount(address account) external view returns (bool);

    /**
     * @notice Returns the owner of a Account.
     * @param account The Account address.
     * @return owner The Account owner.
     */
    function ownerOfAccount(address account) external view returns (address);

    /**
     * @notice Function used to transfer a Account between users.
     * @param from The sender.
     * @param to The target.
     * @param account The address of the Account that is transferred.
     */
    function safeTransferFrom(address from, address to, address account) external;
}
