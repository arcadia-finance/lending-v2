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
     * @notice Calculates the total collateral value (MTM discounted with a haircut) of the Account.
     * @return collateralValue The collateral value, returned in the decimal precision of the Numeraire.
     */
    function getCollateralValue() external view returns (uint256);

    /**
     * @notice Returns the used margin of the Account.
     * @return usedMargin The total amount of Margin that is currently in use to back liabilities.
     */
    function getUsedMargin() external view returns (uint256);

    /**
     * @notice Updates the actionTimestamp
     */
    function updateActionTimestampByCreditor() external;

    /**
     * @notice Checks if the Account is still healthy for an updated open position.
     * @param openPosition The new open position.
     * @return accountVersion The current Account version.
     */
    function increaseOpenPosition(uint256 openPosition) external returns (uint256);

    /**
     * @notice Executes a flash action initiated by the Creditor.
     * @param actionTarget The contract address of the flashAction.
     * @param actionData A bytes object containing three structs and two bytes objects.
     * The first struct contains the info about the assets to withdraw from this Account to the actionTarget.
     * The second struct contains the info about the owner's assets that need to be transferred from the owner to the actionTarget.
     * The third struct contains the permit for the Permit2 transfer.
     * The first bytes object contains the signature for the Permit2 transfer.
     * The second bytes object contains the encoded input for the actionTarget.
     * @return accountVersion The current Account version.
     */
    function flashActionByCreditor(address actionTarget, bytes calldata actionData) external returns (uint256);

    /**
     * @notice Checks if an Account is liquidatable and continues the liquidation flow.
     * @param initiator The address of the liquidation initiator.
     * @return assetAddresses Array of the contract addresses of the assets in Account.
     * @return assetIds Array of the IDs of the assets in Account.
     * @return assetAmounts Array with the amounts of the assets in Account.
     * @return creditor_ The contract address of the Creditor.
     * @return minimumMargin_ The minimum margin.
     * @return openPosition The open position (liabilities) issued against the Account.
     * @return assetAndRiskValues Array of asset values and corresponding collateral and liquidation factors.
     */
    function startLiquidation(address initiator)
        external
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory,
            address,
            uint96,
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
     * @notice Sets the "inAuction" flag to false when an auction ends.
     */
    function endAuction() external;
}
