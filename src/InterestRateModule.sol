/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/**
 * @title Interest Rate Module.
 * @author Pragma Labs
 * @notice The Logic to calculate and store the interest rate of the Lending Pool.
 */
contract InterestRateModule {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The unit for fixed point numbers with 4 decimals precision.
    uint16 internal constant ONE_4 = 10_000;
    // The current interest rate, 18 decimals precision.
    uint256 public interestRate;

    // A struct with the configuration of the interest rate curves,
    // which give the interest rate in function of the utilisation of the Lending Pool.
    InterestRateConfiguration public interestRateConfig;

    struct InterestRateConfiguration {
        // The interest rate when utilisation is 0.
        // 18 decimals precision.
        uint72 baseRatePerYear;
        // The slope of the first curve, defined as the delta in interest rate for a delta in utilisation of 100%.
        // 18 decimals precision.
        uint72 lowSlopePerYear;
        // The slope of the second curve, defined as the delta in interest rate for a delta in utilisation of 100%.
        // 18 decimals precision.
        uint72 highSlopePerYear;
        // The optimal capital utilisation, where we go from the first curve to the steeper second curve.
        // 4 decimal precision.
        uint16 utilisationThreshold;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event InterestRate(uint80 interestRate);

    /* //////////////////////////////////////////////////////////////
                        INTEREST RATE LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the configuration parameters of InterestRateConfiguration struct.
     * @param newConfig A struct with a new set of interest rate configuration parameters:
     * - baseRatePerYear The interest rate when utilisation is 0, 18 decimals precision.
     * - lowSlopePerYear The slope of the first curve, defined as the delta in interest rate for a delta in utilisation of 100%,
     *   18 decimals precision.
     * - highSlopePerYear The slope of the second curve, defined as the delta in interest rate for a delta in utilisation of 100%,
     *   18 decimals precision.
     * - utilisationThreshold the optimal utilisation, where we go from the flat first curve to the steeper second curve,
     *   4 decimal precision.
     */
    function _setInterestConfig(InterestRateConfiguration calldata newConfig) internal {
        interestRateConfig = newConfig;
    }

    /**
     * @notice Calculates the interest rate.
     * @param utilisation Utilisation rate, 4 decimal precision.
     * @return interestRate The current interest rate, 18 decimal precision.
     * @dev The interest rate is a function of the utilisation of the Lending Pool.
     * We use two linear curves: one below the optimal utilisation with low slope and a steep one above.
     */
    function _calculateInterestRate(uint256 utilisation) internal view returns (uint256) {
        uint256 utilisationThreshold = interestRateConfig.utilisationThreshold;
        uint256 lowSlopePerYear = interestRateConfig.lowSlopePerYear;
        uint256 highSlopePerYear = interestRateConfig.highSlopePerYear;
        uint256 baseRatePerYear = interestRateConfig.baseRatePerYear;
        unchecked {
            if (utilisation >= utilisationThreshold) {
                // 1e22 = uT (1e4) * ls (1e18).
                uint256 lowSlopeInterest = uint256(utilisationThreshold) * lowSlopePerYear;
                // 1e22 = (uT - u) (1e4) * hs (e18).
                uint256 highSlopeInterest = uint256((utilisation - utilisationThreshold)) * highSlopePerYear;
                // 1e18 = bs (1e18) + (lsIR (e22) + hsIR (1e22)) / 1e4.
                return uint256(baseRatePerYear) + ((lowSlopeInterest + highSlopeInterest) / ONE_4);
            } else {
                // 1e18 = br (1e18) + (ls (1e18) * u (1e4)) / 1e4.
                return uint256(uint256(baseRatePerYear) + ((uint256(lowSlopePerYear) * utilisation) / ONE_4));
            }
        }
    }

    /**
     * @notice Updates the interest rate.
     * @param totalDebt Total amount of debt.
     * @param totalLiquidity Total amount of Liquidity (sum of borrowed out assets and assets still available in the Lending Pool).
     * @dev This function is only be called by the function _processInterests modifier to update the interest rate,
     * if the totalRealisedLiquidity_ is zero then utilisation is zero.
     */
    function _updateInterestRate(uint256 totalDebt, uint256 totalLiquidity) internal {
        uint256 utilisation; // 4 decimals precision
        if (totalLiquidity > 0) utilisation = (ONE_4 * totalDebt) / totalLiquidity;

        //Calculates and stores interestRate as a uint256, emits interestRate as a uint80 (interestRate is maximally equal to uint72 + uint72).
        //_updateInterestRate() will be called a lot, saves a read from from storage or a write+read from memory.
        emit InterestRate(uint80(interestRate = _calculateInterestRate(utilisation)));
    }
}
