/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import { RiskModule } from "../../lib/accounts-v2/src/RiskModule.sol";

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
     * @return trustedCreditor_ The contract address of the creditor.
     * @return accountVersion_ The Account version.
     * @dev Only one of the values can be non-zero, or we check on a certain increase of debt, or we check on a total amount of debt.
     */
    function isAccountHealthy(uint256 amount, uint256 totalOpenDebt) external view returns (bool, address, uint256);

    /**
     * @notice Function called by Liquidator to start liquidation of the Account.
     * @param openDebt The open debt taken by `originalOwner` at moment of liquidation at creditor
     * @return originalOwner The original owner of this Account.
     * @return baseCurrency The baseCurrency in which the Account is denominated.
     * @return creditor The account or contract that is owed the debt.
     */
    function liquidateAccount(uint256 openDebt) external returns (address, address, address);

    /**
     * @notice Calls external action handler to execute and interact with external logic.
     * @param actionHandler The address of the action handler.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return trustedCreditor_ The contract address of the creditor.
     * @return accountVersion_ The Account version.
     */
    function accountManagementAction(address actionHandler, bytes calldata actionData, bytes calldata signature)
        external
        returns (address, uint256);

    /**
     * @notice Checks if an Account is liquidatable and continues the liquidation flow.
     * @param initiator The address of the liquidation initiator.
     * @return assetAddresses Array of the contract addresses of the assets in Account.
     * @return assetIds Array of the IDs of the assets in Account.
     * @return assetAmounts Array with the amounts of the assets in Account.
     * @return owner Owner of the account.
     * @return creditor The creditor, address 0 if no active Creditor.
     * @return openDebt The open Debt issued against the Account.
     * @return assetAndRiskValues Array of asset values and corresponding collateral factors.
     */
    function startLiquidation(address initiator)
        external
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address owner,
            address creditor,
            uint256 openDebt,
            RiskModule.AssetValueAndRiskFactors[] memory assetAndRiskValues
        );

    /**
     * @notice Transfers the asset bought by a bidder during a liquidation event.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param bidder The address of the bidder.
     */
    function auctionBid(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address bidder
    ) external;

    /**
     * @notice Transfers all assets of the Account in case the auction did not end successful (= Bought In).
     * @param to The recipient's address to receive the assets, set by the Creditor.
     */
    function auctionBoughtIn(address to) external;

    /**
     * @notice Generates three arrays of all the stored assets in the Account.
     * @return assetAddresses Array of the contract addresses of the assets.
     * @return assetIds Array of the IDs of the assets.
     * @return assetAmounts Array with the amounts of the assets.
     * @dev Balances are stored on the contract to prevent working around the deposit limits.
     * @dev Loops through the stored asset addresses and fills the arrays.
     * @dev There is no importance of the order in the arrays, but all indexes of the arrays correspond to the same asset.
     */
    function generateAssetData()
        external
        view
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts);
    function baseCurrency() external view returns (address baseCurrency);
    function registry() external view returns (address registry);
    function getAccountValue(address baseCurrency_) external view returns (uint256 accountValue);
}
