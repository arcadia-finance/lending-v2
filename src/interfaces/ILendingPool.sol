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
    function startLiquidation(address account) external returns (uint256 openDebt);
    function repay(uint256 amount, address account) external;
    function auctionRepay(
        uint256 startDebt,
        address initiator,
        address originalOwner,
        uint256 amount,
        address account,
        address bidder
    ) external returns (bool);
    function settleLiquidation(
        address account,
        address originalOwner,
        uint256 startDebt,
        address initiator,
        address terminator,
        uint256 surplus
    ) external;
}
