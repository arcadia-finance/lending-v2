/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";

interface IAccount {
    /**
     * @notice Returns the address of the owner of the Account.
     */
    function owner() external view returns (address);

    /**
     * @notice Checks if the Account is healthy and still has free margin.
     * @param debtIncrease The amount with which the debt is increased.
     * @param openDebt The total open Debt against the Account.
     * @return success Boolean indicating if there is sufficient margin to back a certain amount of Debt.
     * @return creditor_ The contract address of the creditor.
     * @return accountVersion_ The Account version.
     */
    function isAccountHealthy(uint256 debtIncrease, uint256 openDebt) external view returns (bool, address, uint256);

    /**
     * @notice Calculates the total collateral value (MTM discounted with a haircut) of the Account.
     * @return collateralValue The collateral value, returned in the decimals of the base currency.
     */
    function getCollateralValue() external view returns (uint256);

    /**
     * @notice Returns the used margin of the Account.
     * @return usedMargin The total amount of Margin that is currently in use to back liabilities.
     */
    function getUsedMargin() external view returns (uint256);

    /**
     * @notice Checks if an Account is liquidatable and continues the liquidation flow.
     * @param initiator The address of the liquidation initiator.
     * @return assetAddresses Array of the contract addresses of the assets in Account.
     * @return assetIds Array of the IDs of the assets in Account.
     * @return assetAmounts Array with the amounts of the assets in Account.
     * @return creditor_ The creditor, address 0 if no active Creditor.
     * @return openDebt The open Debt issued against the Account.
     * @return assetAndRiskValues Array of asset values and corresponding collateral factors.
     */
    function startLiquidation(address initiator)
        external
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory,
            address,
            uint256,
            AssetValueAndRiskFactors[] memory
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
     * @notice Calls external action handler to execute and interact with external logic.
     * @param actionHandler The address of the action handler.
     * @param actionData A bytes object containing three actionAssetData structs, an address array and a bytes array.
     * The first struct contains the info about the assets to withdraw from this Account to the actionHandler.
     * The second struct contains the info about the owner's assets that are not in this Account and needs to be transferred to the actionHandler.
     * The third struct contains the info about the assets that needs to be deposited from the actionHandler back into the Account.
     * @param signature The signature to verify.
     * @return creditor_ The contract address of the creditor.
     * @return accountVersion_ The Account version.
     */
    function accountManagementAction(address actionHandler, bytes calldata actionData, bytes calldata signature)
        external
        returns (address, uint256);

    /**
     * @notice Sets the "inAuction" flag to false when an auction ends.
     */
    function endAuction() external;
}
