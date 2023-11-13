/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

interface ILendingPool {
    /**
     * @notice returns the supply cap of the Lending Pool.
     * @return supplyCap The supply cap of the Lending Pool.
     */
    function supplyCap() external view returns (uint128);

    /**
     * @notice returns the total realised liquidity of the Lending Pool.
     * @return totalRealisedLiquidity The total realised liquidity of the Lending Pool.
     */
    function totalRealisedLiquidity() external view returns (uint128);

    /**
     * @notice Deposit assets in the Lending Pool.
     * @param assets The amount of assets of the underlying ERC-20 token being deposited.
     * @param from The address of the Liquidity Provider who deposits the underlying ERC-20 token via a Tranche.
     */
    function depositInLendingPool(uint256 assets, address from) external;

    /**
     * @notice Withdraw assets from the Lending Pool.
     * @param assets The amount of assets of the underlying ERC-20 tokens being withdrawn.
     * @param receiver The address of the receiver of the underlying ERC-20 tokens.
     */
    function withdrawFromLendingPool(uint256 assets, address receiver) external;

    /**
     * @notice Returns the redeemable amount of liquidity in the underlying asset of an address.
     * @param owner The address of the liquidity provider.
     * @return assets The redeemable amount of liquidity in the underlying asset.
     */
    function liquidityOf(address owner) external view returns (uint256);

    /**
     * @notice liquidityOf, but syncs the unrealised interest first.
     * @param owner The address of the liquidity provider.
     * @return assets The redeemable amount of liquidity in the underlying asset.
     */
    function liquidityOfAndSync(address owner) external returns (uint256);

    /**
     * @notice Calculates the unrealised debt (interests).
     * @return unrealisedDebt The unrealised debt.
     */
    function calcUnrealisedDebt() external view returns (uint256);

    /**
     * @notice Start a liquidation for a specific account with debt.
     * @param account The address of the account with debt to be liquidated.
     * @param initiatorRewardWeight Fee paid to the Liquidation Initiator.
     * @param penaltyWeight Penalty the Account owner has to pay to the trusted Creditor on top of the open Debt for being liquidated.
     * @param closingRewardWeight Fee paid to the address that is ending an auction.
     * @return liquidationInitiatorReward Fee paid to the Liquidation Initiator.
     * @return closingReward Fee paid to the address that is ending an auction.
     * @dev This function can only be called by authorized liquidators.
     * @dev To initiate a liquidation, the function checks if the specified account has open debt.
     * @dev If the account has no open debt, the function reverts with an error.
     * @dev If this is the first auction, it hooks to the most junior tranche to inform that auctions are ongoing.
     * @dev The function updates the count of ongoing auctions.
     * @dev Liquidations can only be initiated for accounts with non-zero open debt.
     */
    function startLiquidation(
        address account,
        uint256 initiatorRewardWeight,
        uint256 closingRewardWeight,
        uint256 penaltyWeight
    ) external returns (uint256 liquidationInitiatorReward, uint256 closingReward);
    function repay(uint256 amount, address account) external;
    function auctionRepay(uint256 amount, address account, address bidder) external returns (bool);
    function settleLiquidation(
        address account,
        address originalOwner,
        uint256 badDebt,
        address initiator,
        uint256 liquidationInitiatorReward,
        address terminator,
        uint256 auctionTerminationReward,
        uint256 liquidationFee,
        uint256 remainder
    ) external;
}
