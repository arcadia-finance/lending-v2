/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library ArcadiaLending {
    address internal constant ACCOUNT_RECIPIENT = address(0x0f518becFC14125F23b8422849f6393D59627ddB);
    address internal constant LIQUIDATOR = address(0xA4B0b9fD1d91fA2De44F6ABFd59cC14bA1E1a7Af);
    address internal constant TRANCHE_CBBTC = address(0x9c63A4c499B323a25D389Da759c2ac1e385eEc92);
    address internal constant TRANCHE_USDC = address(0xEFE32813dBA3A783059d50e5358b9e3661218daD);
    address internal constant TRANCHE_WETH = address(0x393893caeB06B5C16728bb1E354b6c36942b1382);
    address internal constant WRAPPED_TRANCHE_CBBTC = address(0x7Cc8013e784418dc9771403DD057f55cEb34Ba3A);
    address internal constant WRAPPED_TRANCHE_USDC = address(0xbc10718571fcB3c3F67800e7C0887E450D2Ff398);
    address internal constant WRAPPED_TRANCHE_WETH = address(0xD82BFa27D49e5a394ba371B293DaE65E9B7a8C60);
}

library ArcadiaLendingSafes {
    address internal constant TREASURY = address(0xFd6db26eDc581D8F381f46eF4a6396A762b66E95);
}

library InterestRateParameters {
    uint16 internal constant UTILISATION_THRESHOLD_CBBTC = 8000; // 80%
    uint72 internal constant BASE_RATE_CBBTC = 4 * 1e16; // 4%
    uint72 internal constant LOW_SLOPE_CBBTC = 5 * 1e16; // -> APY goes from 4% to 8% for utilisation of 0 to 80%
    uint72 internal constant HIGH_SLOPE_CBBTC = 200 * 1e16; // -> APY goes from 8% to 48% for utilisation of 80 to 100%

    uint16 internal constant UTILISATION_THRESHOLD_USDC = 8000; // 80%
    uint72 internal constant BASE_RATE_USDC = 8 * 1e16; // 8%
    uint72 internal constant LOW_SLOPE_USDC = 0 * 1e16; // -> APY goes from 8% to 8% for utilisation of 0 to 80%
    uint72 internal constant HIGH_SLOPE_USDC = 200 * 1e16; // -> APY goes from 8% to 48% for utilisation of 80 to 100%

    uint16 internal constant UTILISATION_THRESHOLD_WETH = 8000; // 80%
    uint72 internal constant BASE_RATE_WETH = 6 * 1e16; // 6%
    uint72 internal constant LOW_SLOPE_WETH = 0 * 1e16; // -> APY goes from 6% to 6% for utilisation of 0 to 80%
    uint72 internal constant HIGH_SLOPE_WETH = 200 * 1e16; // -> APY goes from 6% to 46% for utilisation of 80 to 100%
}

library LiquidationParameters {
    uint16 internal constant INITIATION_WEIGHT_CBBTC = 100;
    uint16 internal constant PENALTY_WEIGHT_CBBTC = 500;
    uint16 internal constant TERMINATION_WEIGHT_CBBTC = 50;
    uint16 internal constant MIN_REWARD_WEIGHT_CBBTC = 2500;
    uint80 internal constant MAX_REWARD_CBBTC = 0.001 * 10 ** 8;

    uint16 internal constant INITIATION_WEIGHT_USDC = 100;
    uint16 internal constant PENALTY_WEIGHT_USDC = 500;
    uint16 internal constant TERMINATION_WEIGHT_USDC = 50;
    uint16 internal constant MIN_REWARD_WEIGHT_USDC = 2500;
    uint80 internal constant MAX_REWARD_USDC = 4000 * 10 ** 6;

    uint16 internal constant INITIATION_WEIGHT_WETH = 100;
    uint16 internal constant PENALTY_WEIGHT_WETH = 500;
    uint16 internal constant TERMINATION_WEIGHT_WETH = 50;
    uint16 internal constant MIN_REWARD_WEIGHT_WETH = 2500;
    uint80 internal constant MAX_REWARD_WETH = 1 * 10 ** 18;
}

library MinimumMargins {
    uint96 internal constant CBBTC = 0.00004 * 10 ** 8;
    uint96 internal constant USDC = 2 * 10 ** 6;
    uint96 internal constant WETH = 0.002 * 10 ** 18;
}

library VAS {
    uint256 internal constant CBBTC = 10 ** 2;
    uint256 internal constant USDC = 10 ** 6;
    uint256 internal constant WETH = 10 ** 8;
}
