/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

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
     * @notice Repays debt via an auction.
     * @param startDebt The amount of debt of the Account the moment the liquidation was initiated.
     * @param originalOwner The address of the Account owner.
     * @param amount The amount of debt repaid by a bidder during the auction.
     * @param account The contract address of the Arcadia Account backing the loan.
     * @param bidder The address of the bidder.
     * @return earlyTerminate Bool indicating of the full amount of debt was repaid.
     */
    function auctionRepay(uint256 startDebt, address originalOwner, uint256 amount, address account, address bidder)
        external
        returns (bool);

    /**
     * @notice Settles the liquidation process for a specific Account.
     * @param account The address of the Account undergoing liquidation settlement.
     * @param originalOwner The original owner of the liquidated debt.
     * @param startDebt The initial debt amount of the liquidated Account.
     * @param terminator The address of the liquidation terminator.
     * @param surplus The surplus amount obtained from the liquidation process.
     */
    function settleLiquidation(
        address account,
        address originalOwner,
        uint256 startDebt,
        address terminator,
        uint256 surplus
    ) external;
}
