/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IMainRegistry {
    /**
     * @notice Calculates the combined value of a combination of assets, denominated in a given BaseCurrency.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param baseCurrency The contract address of the BaseCurrency.
     * @return valueInBaseCurrency The combined value of the assets, denominated in BaseCurrency.
     * @dev No need to check equality of length of arrays, since they are generated by the Account.
     */
    function getTotalValue(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        address baseCurrency
    ) external view returns (uint256);
}
