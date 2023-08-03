/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.13;

interface IFactory {
    /**
     * @notice View function returning if an address is a vault.
     * @param vault The address to be checked.
     * @return bool Whether the address is a vault or not.
     */
    function isVault(address vault) external view returns (bool);

    /**
     * @notice Returns the owner of a vault.
     * @param vault The Vault address.
     * @return owner The Vault owner.
     */
    function ownerOfVault(address vault) external view returns (address);

    /**
     * @notice Function used to transfer a vault between users.
     * @param from The sender.
     * @param to The target.
     * @param vault The address of the vault that is transferred.
     */
    function safeTransferFrom(address from, address to, address vault) external;
}
