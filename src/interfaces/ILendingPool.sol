/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface ILendingPool {
    /**
     * @notice Returns the total redeemable amount of liquidity in the underlying asset.
     * @return totalLiquidity The total redeemable amount of liquidity in the underlying asset.
     */
    function totalLiquidity() external view returns (uint256);

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
     * @notice Repays debt via an auction.
     * @param startDebt The amount of debt of the Account the moment the liquidation was initiated.
     * @param minimumMargin The minimum margin of the Account.
     * @param minimumMargin The minimum margin of the Account.
     * @param amount The amount of debt repaid by a bidder during the auction.
     * @param account The contract address of the Arcadia Account backing the loan.
     * @param bidder The address of the bidder.
     * @return earlyTerminate Bool indicating of the full amount of debt was repaid.
     */
    function auctionRepay(uint256 startDebt, uint256 minimumMargin, uint256 amount, address account, address bidder)
        external
        returns (bool);

    /**
     * @notice Settles the liquidation process for a specific Account.
     * @param account The address of the Account undergoing liquidation settlement.
     * @param startDebt The initial debt amount of the liquidated Account.
     * @param minimumMargin The minimum margin of the Account.
     * @param terminator The address of the liquidation terminator.
     */
    function settleLiquidationHappyFlow(address account, uint256 startDebt, uint256 minimumMargin, address terminator)
        external;

    /**
     * @notice Settles the liquidation process for a specific Account.
     * @param account The address of the Account undergoing liquidation settlement.
     * @param startDebt The initial debt amount of the liquidated Account.
     * @param minimumMargin The minimum margin of the Account.
     * @param terminator The address of the liquidation terminator.
     */
    function settleLiquidationUnhappyFlow(address account, uint256 startDebt, uint256 minimumMargin, address terminator)
        external;
}
