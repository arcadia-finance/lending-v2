/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";
import { SafeCastLib } from "../lib/solmate/src/utils/SafeCastLib.sol";
import { FixedPointMathLib } from "../lib/solmate/src/utils/FixedPointMathLib.sol";
import { LogExpMath } from "./libraries/LogExpMath.sol";
import { ITranche } from "./interfaces/ITranche.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { Creditor } from "./Creditor.sol";
import { ERC20, ERC4626, DebtToken } from "./DebtToken.sol";
import { InterestRateModule } from "./InterestRateModule.sol";
import { LendingPoolGuardian } from "./guardians/LendingPoolGuardian.sol";

/**
 * @title Arcadia LendingPool.
 * @author Pragma Labs
 * @notice The Lending pool contains the main logic to provide liquidity and take or repay loans for a certain asset
 * and does the accounting of the debtTokens (ERC4626).
 * @dev Implementation not vulnerable to ERC4626 inflation attacks,
 * since totalAssets() cannot be manipulated by the first minter.
 * For more information, see https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3706.
 */
contract LendingPool is LendingPoolGuardian, Creditor, DebtToken, InterestRateModule, ILendingPool {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Seconds per year, leap years ignored.
    uint256 internal constant YEARLY_SECONDS = 31_536_000;
    // Contract address of the Arcadia Account Factory.
    address internal immutable ACCOUNT_FACTORY;
    // Contract address of the Liquidator contract.
    address internal immutable LIQUIDATOR;

    // Last timestamp that interests were realized.
    uint32 internal lastSyncedTimestamp;
    // Origination fee, 4 decimals precision (10 equals 0.001 or 0.1%), capped at 255 (2.55%).
    uint8 internal originationFee;
    // Sum of all the interest weights of the tranches + treasury.
    uint24 internal totalInterestWeight;
    // Fraction (interestWeightTreasury / totalInterestWeight) of the interest fees that go to the treasury.
    uint16 internal interestWeightTreasury;
    // Sum of the liquidation weights of the tranches + treasury.
    uint24 internal totalLiquidationWeight;
    // Fraction (liquidationWeightTreasury / totalLiquidationWeight) of the liquidation fees that goes to the treasury.
    uint16 internal liquidationWeightTreasury;

    // Total amount of `underlying asset` that is claimable by the LPs. Does not take into account pending interests.
    uint128 public totalRealisedLiquidity;
    // Conservative estimate of the maximal gas cost to liquidate a position (fixed cost, independent of openDebt).
    uint96 internal fixedLiquidationCost;

    // Address of the protocol treasury.
    address internal treasury;
    // Number of auctions that are currently in progress.
    uint16 internal auctionsInProgress;
    // Maximum amount of `underlying asset` that is paid as fee to the initiator of a liquidation.
    uint80 internal maxInitiationFee;
    // Maximum amount of `underlying asset` that is paid as fee to the terminator of a liquidation.
    uint80 internal maxTerminationFee;
    // Fee paid to the Liquidation Initiator.
    // Defined as a fraction of the openDebt with 4 decimals precision.
    // Absolute fee can be further capped to a max amount by the creditor.
    uint16 internal initiatorRewardWeight;
    // Penalty the Account owner has to pay to the Creditor on top of the open Debt for being liquidated.
    // Defined as a fraction of the openDebt with 4 decimals precision.
    uint16 internal penaltyWeight;
    // Fee paid to the address that is ending an auction.
    // Defined as a fraction of the openDebt with 4 decimals precision.
    uint16 internal closingRewardWeight;

    // Array of the interest weights of each Tranche.
    // Fraction (interestWeightTranches[i] / totalInterestWeight) of the interest fees that go to Tranche i.
    uint16[] internal interestWeightTranches;
    // Array of the liquidation weights of each Tranche.
    // Fraction (liquidationWeightTranches[i] / totalLiquidationWeight) of the liquidation fees that go to Tranche i.
    uint16[] internal liquidationWeightTranches;
    // Array of the contract addresses of the Tranches.
    address[] internal tranches;

    // Map tranche => status.
    mapping(address => bool) internal isTranche;
    // Map tranche => interestWeight.
    // Fraction (interestWeightTranches[i] / totalInterestWeight) of the interest fees that go to Tranche i.
    mapping(address => uint256) internal interestWeight;
    // Map tranche => realisedLiquidity.
    // Amount of `underlying asset` that is claimable by the liquidity providers.
    // Does not take into account pending interests.
    mapping(address => uint256) public realisedLiquidityOf;
    // Map Account => owner => beneficiary => amount.
    // Stores the credit allowances for a beneficiary per Account and per Owner.
    mapping(address => mapping(address => mapping(address => uint256))) public creditAllowance;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event WeightsSet(uint16 initiatorRewardWeight, uint16 penaltyWeight, uint16 closingRewardWeight);
    event TrancheAdded(address indexed tranche, uint8 indexed index);
    event InterestWeightSet(uint256 indexed trancheIndex, uint16 weight);
    event LiquidationWeightSet(uint256 indexed trancheIndex, uint16 weight);
    event MaxLiquidationFeesSet(uint80 maxInitiationFee, uint80 maxTerminationFee);
    event TranchePopped(address tranche);
    event TreasuryInterestWeightSet(uint16 weight);
    event TreasuryLiquidationWeightSet(uint16 weight);
    event OriginationFeeSet(uint8 originationFee);
    event BorrowCapSet(uint128 borrowCap);
    event SupplyCapSet(uint128 supplyCap);
    event CreditApproval(address indexed account, address indexed owner, address indexed beneficiary, uint256 amount);
    event Borrow(
        address indexed account, address indexed by, address to, uint256 amount, uint256 fee, bytes3 indexed referrer
    );
    event Repay(address indexed account, address indexed from, uint256 amount);
    event FixedLiquidationCostSet(uint96 fixedLiquidationCost);
    event LendingPoolWithdrawal(address indexed receiver, uint256 assets);
    event AuctionStarted(address indexed account, address indexed creditor, uint128 openDebt);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    // Thrown when maximum amount of asset that can be supplied to the pool would be exceeded.
    error LendingPool_SupplyCapExceeded();
    // Thrown when the tranche of the lending pool already exists.
    error LendingPool_TrancheAlreadyExists();
    // Thrown when a specific tranche does not exist.
    error LendingPool_NonExistingTranche();
    // Thrown when asset amount in input is zero.
    error LendingPool_ZeroAmount();
    // Thrown when less than 1 share outstanding to mitigate share manipulation.
    error LendingPool_InsufficientShares();
    // Thrown when amount available to withdraw of an asset is less than amount requested to withdraw.
    error LendingPool_AmountExceedsBalance();
    // Thrown when account specified is not an Arcadia Account.
    error LendingPool_IsNotAnAccount();
    // Thrown when an Account would become unhealthy OR the creditor of the Account is not the specific lending pool OR the Account version would not be valid.
    error LendingPool_Reverted();
    // Thrown when an account has zero debt.
    error LendingPool_IsNotAnAccountWithDebt();
    // Thrown when caller is not authorized.
    error LendingPool_Unauthorized();
    // Thrown when an auction is in process.
    error LendingPool_AuctionOngoing();
    // Thrown when liquidation weights are above maximum value.
    error LendingPool_WeightsTooHigh();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks if caller is the Liquidator.
     */
    modifier onlyLiquidator() {
        if (LIQUIDATOR != msg.sender) revert LendingPool_Unauthorized();
        _;
    }

    /**
     * @notice Checks if caller is a Tranche.
     */
    modifier onlyTranche() {
        if (!isTranche[msg.sender]) revert LendingPool_Unauthorized();
        _;
    }

    /**
     * @notice Syncs interest to LPs and treasury and updates the interest rate.
     */
    modifier processInterests() {
        _syncInterests();
        _;
        //_updateInterestRate() modifies the state (effect), but can safely be called after interactions.
        //Cannot be exploited by re-entrancy attack.
        _updateInterestRate(realisedDebt, totalRealisedLiquidity);
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice The constructor for a lending pool.
     * @param riskManager_ The address of the new Risk Manager.
     * @param asset_ The underlying ERC20 token of the Lending Pool.
     * @param treasury_ The address of the protocol treasury.
     * @param ACCOUNT_FACTORY_ The address of the Account Factory.
     * @param LIQUIDATOR_ The address of the Liquidator.
     * @dev The name and symbol of the DebtToken are automatically generated, based on the name and symbol of the underlying token.
     */
    constructor(address riskManager_, ERC20 asset_, address treasury_, address ACCOUNT_FACTORY_, address LIQUIDATOR_)
        LendingPoolGuardian()
        Creditor(riskManager_)
        DebtToken(asset_)
    {
        treasury = treasury_;
        ACCOUNT_FACTORY = ACCOUNT_FACTORY_;
        LIQUIDATOR = LIQUIDATOR_;
        initiatorRewardWeight = 100;
        penaltyWeight = 500;
        // note: to discuss
        closingRewardWeight = 100;

        emit WeightsSet(initiatorRewardWeight, penaltyWeight, closingRewardWeight);
    }

    /* //////////////////////////////////////////////////////////////
                            TRANCHES LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Adds a tranche to the Lending Pool.
     * @param tranche The address of the Tranche.
     * @param interestWeight_ The interest weight of the specific Tranche.
     * @param liquidationWeight The liquidation weight of the specific Tranche.
     * @dev The order of the tranches is important, the most senior tranche is added first at index 0, the most junior at the last index.
     * @dev Each Tranche is an ERC4626 contract.
     * @dev The interest weight of each Tranche determines the relative share of the yield (interest payments) that goes to its Liquidity providers.
     * @dev The liquidation weight of each Tranche determines the relative share of the liquidation fee that goes to its Liquidity providers.
     */
    function addTranche(address tranche, uint16 interestWeight_, uint16 liquidationWeight) external onlyOwner {
        if (isTranche[tranche]) revert LendingPool_TrancheAlreadyExists();

        totalInterestWeight += interestWeight_;
        interestWeightTranches.push(interestWeight_);
        interestWeight[tranche] = interestWeight_;

        totalLiquidationWeight += liquidationWeight;
        liquidationWeightTranches.push(liquidationWeight);

        tranches.push(tranche);
        isTranche[tranche] = true;

        emit TrancheAdded(tranche, uint8(tranches.length - 1));
        emit InterestWeightSet(tranches.length - 1, interestWeight_);
        emit LiquidationWeightSet(tranches.length - 1, liquidationWeight);
    }

    /**
     * @notice Changes the interest weight of a specific Tranche.
     * @param index The index of the Tranche for which a new interest weight is being set.
     * @param weight The new interest weight of the Tranche at the index.
     * @dev The interest weight of each Tranche determines the relative share of yield (interest payments) that goes to its Liquidity providers.
     */
    function setInterestWeight(uint256 index, uint16 weight) external onlyOwner {
        if (index >= tranches.length) revert LendingPool_NonExistingTranche();
        totalInterestWeight = totalInterestWeight - interestWeightTranches[index] + weight;
        interestWeightTranches[index] = weight;
        interestWeight[tranches[index]] = weight;

        emit InterestWeightSet(index, weight);
    }

    /**
     * @notice Changes the liquidation weight of a specific tranche.
     * @param index The index of the Tranche for which a new liquidation weight is being set.
     * @param weight The new liquidation weight of the Tranche at the index.
     * @dev The liquidation weight determines the relative share of the liquidation fee that goes to its Liquidity providers.
     */
    function setLiquidationWeight(uint256 index, uint16 weight) external onlyOwner {
        if (index >= tranches.length) revert LendingPool_NonExistingTranche();
        totalLiquidationWeight = totalLiquidationWeight - liquidationWeightTranches[index] + weight;
        liquidationWeightTranches[index] = weight;

        emit LiquidationWeightSet(index, weight);
    }

    /**
     * @notice Removes the Tranche at the last index (most junior).
     * @param index The index of the last Tranche.
     * @param tranche The address of the last Tranche.
     * @dev This function can only be called by the function _processDefault(uint256 assets),
     * when there is a default as big as (or bigger than) the complete amount of liquidity of the most junior Tranche.
     * @dev Passing the input parameters to the function saves gas compared to reading the address and index of the last Tranche from storage.
     * No need to check if index and Tranche are indeed of the last tranche since function is only called by _processDefault.
     */
    function _popTranche(uint256 index, address tranche) internal {
        totalInterestWeight -= interestWeightTranches[index];
        totalLiquidationWeight -= liquidationWeightTranches[index];
        isTranche[tranche] = false;
        interestWeightTranches.pop();
        liquidationWeightTranches.pop();
        tranches.pop();
        interestWeight[tranche] = 0;

        emit TranchePopped(tranche);
    }

    /* ///////////////////////////////////////////////////////////////
                    TREASURY FEE CONFIGURATION
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Changes the fraction of the interest payments that go to the treasury.
     * @param interestWeightTreasury_ The new interestWeight of the treasury.
     * @dev The interestWeight determines the relative share of the yield (interest payments) that goes to the protocol treasury.
     * @dev Setting interestWeightTreasury to a very high value will cause the treasury to collect all interest fees from that moment on.
     * Although this will affect the future profits of liquidity providers, no funds nor realized interest are at risk for LPs.
     */
    function setTreasuryInterestWeight(uint16 interestWeightTreasury_) external onlyOwner {
        totalInterestWeight = totalInterestWeight - interestWeightTreasury + interestWeightTreasury_;

        emit TreasuryInterestWeightSet(interestWeightTreasury = interestWeightTreasury_);
    }

    /**
     * @notice Changes the fraction of the liquidation fees that go to the treasury.
     * @param liquidationWeightTreasury_ The new liquidationWeight of the liquidation fee.
     * @dev The liquidationWeight determines the relative share of the liquidation fee that goes to the protocol treasury.
     * @dev Setting liquidationWeightTreasury to a very high value will cause the treasury to collect all liquidation fees from that moment on.
     * Although this will affect the future profits of liquidity providers in the tranches, no funds nor realized interest are at risk for LPs.
     */
    function setTreasuryLiquidationWeight(uint16 liquidationWeightTreasury_) external onlyOwner {
        totalLiquidationWeight = totalLiquidationWeight - liquidationWeightTreasury + liquidationWeightTreasury_;

        emit TreasuryLiquidationWeightSet(liquidationWeightTreasury = liquidationWeightTreasury_);
    }

    /**
     * @notice Sets new treasury address.
     * @param treasury_ The new address of the treasury.
     */
    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
    }

    /**
     * @notice Sets the new origination fee.
     * @param originationFee_ The new origination fee.
     * @dev originationFee is limited by being a uint8 -> max value is 2.55%
     * 4 decimal precision (10 = 0.1%).
     */
    function setOriginationFee(uint8 originationFee_) external onlyOwner {
        emit OriginationFeeSet(originationFee = originationFee_);
    }

    /* //////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Deposit assets in the Lending Pool.
     * @param assets The amount of assets of the underlying ERC20 tokens being deposited.
     * @param from The address of the Liquidity Provider who deposits the underlying ERC20 token via a Tranche.
     * @dev This function can only be called by Tranches.
     */
    function depositInLendingPool(uint256 assets, address from)
        external
        whenDepositNotPaused
        onlyTranche
        processInterests
    {
        // Need to transfer before minting or ERC777s could reenter.
        // Address(this) is trusted -> no risk on re-entrancy attack after transfer.
        asset.safeTransferFrom(from, address(this), assets);

        unchecked {
            realisedLiquidityOf[msg.sender] += assets;
            totalRealisedLiquidity = SafeCastLib.safeCastTo128(assets + totalRealisedLiquidity);
        }

        //Event emitted by Tranche.
    }

    /**
     * @notice Donate assets to the Lending Pool.
     * @param trancheIndex The index of the tranche to donate to.
     * @param assets The amount of assets of the underlying ERC20 tokens being deposited.
     * @dev Can be used by anyone to donate assets to the Lending Pool.
     * It is supposed to serve as a way to compensate the jrTranche after an
     * auction didn't get sold and was manually Liquidated by the Protocol after cutoffTime.
     * @dev First minter of a tranche could abuse this function by minting only 1 share,
     * frontrun next minter by calling this function and inflate the share price.
     * This is mitigated by checking that there are at least 10 ** decimals shares outstanding.
     */
    function donateToTranche(uint256 trancheIndex, uint256 assets) external whenDepositNotPaused processInterests {
        if (assets == 0) revert LendingPool_ZeroAmount();

        address tranche = tranches[trancheIndex];
        //Mitigate share manipulation, where first Liquidity Provider mints just 1 share.
        //See https://github.com/OpenZeppelin/openzeppelin-contracts/issues/3706 for more information.
        if (ERC4626(tranche).totalSupply() < 10 ** decimals) revert LendingPool_InsufficientShares();

        asset.safeTransferFrom(msg.sender, address(this), assets);

        unchecked {
            realisedLiquidityOf[tranche] += assets; //[̲̅$̲̅(̲̅ ͡° ͜ʖ ͡°̲̅)̲̅$̲̅]
            totalRealisedLiquidity = SafeCastLib.safeCastTo128(assets + totalRealisedLiquidity);
        }
    }

    /**
     * @notice Withdraw assets from the Lending Pool.
     * @param assets The amount of assets of the underlying ERC20 tokens being withdrawn.
     * @param receiver The address of the receiver of the underlying ERC20 tokens.
     * @dev This function can be called by anyone with an open balance (realisedLiquidityOf[address] bigger than 0),
     * which can be both Tranches as other address (treasury, Liquidation Initiators, Liquidated Account Owner...).
     */
    function withdrawFromLendingPool(uint256 assets, address receiver)
        external
        whenWithdrawNotPaused
        processInterests
    {
        if (realisedLiquidityOf[msg.sender] < assets) revert LendingPool_AmountExceedsBalance();

        unchecked {
            realisedLiquidityOf[msg.sender] -= assets;
        }
        totalRealisedLiquidity -= SafeCastLib.safeCastTo128(assets);

        asset.safeTransfer(receiver, assets);

        //Event emitted by Tranche.

        emit LendingPoolWithdrawal(receiver, assets);
    }

    /* //////////////////////////////////////////////////////////////
                            LENDING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Approve a beneficiary to take out debt against an Arcadia Account.
     * @param beneficiary The address of the beneficiary who can take out debt backed by an Arcadia Account.
     * @param amount The amount of underlying ERC20 tokens to be lent out.
     * @param account The address of the Arcadia Account backing the debt.
     */
    function approveBeneficiary(address beneficiary, uint256 amount, address account) external {
        //If Account is not an actual address of an Arcadia Account, ownerOfAccount(address) will return the zero address.
        if (IFactory(ACCOUNT_FACTORY).ownerOfAccount(account) != msg.sender) revert LendingPool_Unauthorized();

        creditAllowance[account][msg.sender][beneficiary] = amount;

        emit CreditApproval(account, msg.sender, beneficiary, amount);
    }

    /**
     * @notice Takes out debt backed by collateral in an Arcadia Account.
     * @param amount The amount of underlying ERC20 tokens to be lent out.
     * @param account The address of the Arcadia Account backing the debt.
     * @param to The address who receives the lent out underlying tokens.
     * @param referrer A unique identifier of the referrer, who will receive part of the fees generated by this transaction.
     * @dev The sender might be different than the owner if they have the proper allowances.
     */
    function borrow(uint256 amount, address account, address to, bytes3 referrer)
        external
        whenBorrowNotPaused
        processInterests
    {
        //If Account is not an actual address of an Account, ownerOfAccount(address) will return the zero address.
        address accountOwner = IFactory(ACCOUNT_FACTORY).ownerOfAccount(account);
        if (accountOwner == address(0)) revert LendingPool_IsNotAnAccount();

        uint256 amountWithFee = amount + amount.mulDivUp(originationFee, ONE_4);

        //Check allowances to take debt.
        if (accountOwner != msg.sender) {
            uint256 allowed = creditAllowance[account][accountOwner][msg.sender];
            if (allowed != type(uint256).max) {
                creditAllowance[account][accountOwner][msg.sender] = allowed - amountWithFee;
            }
        }

        //Mint debt tokens to the Account.
        _deposit(amountWithFee, account);

        //Add origination fee to the treasury.
        unchecked {
            if (amountWithFee - amount > 0) {
                totalRealisedLiquidity = SafeCastLib.safeCastTo128(amountWithFee + totalRealisedLiquidity - amount);
                realisedLiquidityOf[treasury] += amountWithFee - amount;
            }
        }

        //Call Account to check if it is still healthy after the debt is increased with amountWithFee.
        (bool isHealthy, address creditor, uint256 accountVersion) =
            IAccount(account).isAccountHealthy(0, maxWithdraw(account));
        if (!isHealthy || creditor != address(this) || !isValidVersion[accountVersion]) {
            revert LendingPool_Reverted();
        }

        //Transfer fails if there is insufficient liquidity in the pool.
        asset.safeTransfer(to, amount);

        emit Borrow(account, msg.sender, to, amount, amountWithFee - amount, referrer);
    }

    /**
     * @notice Repays debt.
     * @param amount The amount of underlying ERC20 tokens to be repaid.
     * @param account The contract address of the Arcadia Account backing the debt.
     * @dev if Account is not an actual address of an Arcadia Account, maxWithdraw(account) will always return 0.
     * Function will not revert, but amount is always 0.
     * @dev Anyone (EOAs and contracts) can repay debt in the name of an Account.
     */
    function repay(uint256 amount, address account) external whenRepayNotPaused processInterests {
        uint256 accountDebt = maxWithdraw(account);
        amount = accountDebt > amount ? amount : accountDebt;

        // Need to transfer before burning debt or ERC777s could reenter.
        // Address(this) is trusted -> no risk on re-entrancy attack after transfer.
        asset.safeTransferFrom(msg.sender, address(this), amount);

        _withdraw(amount, account, account);

        emit Repay(account, msg.sender, amount);
    }

    /**
     * @notice Repays debt via an auction.
     * @param startDebt The amount of debt of the Account the moment the liquidation was initiated.
     * @param amount The amount repaid by a bidder during the auction.
     * @param account The contract address of the Arcadia Account backing the debt.
     * @param bidder The address of the bidder.
     * @return earlyTerminate Bool indicating whether the full amount of debt was repaid.
     * @dev This function allows a liquidator to repay a specified amount of debt for a user.
     */
    function auctionRepay(uint256 startDebt, uint256 amount, address account, address bidder)
        external
        whenLiquidationNotPaused
        onlyLiquidator
        processInterests
        returns (bool earlyTerminate)
    {
        // Need to transfer before burning debt or ERC777s could reenter.
        // Address(this) is trusted -> no risk on re-entrancy attack after transfer.
        asset.safeTransferFrom(bidder, address(this), amount);

        uint256 accountDebt = maxWithdraw(account);
        if (accountDebt == 0) revert LendingPool_IsNotAnAccountWithDebt();
        if (accountDebt <= amount) {
            // The amount recovered by selling assets during the auction is bigger than the total debt of the Account.
            // -> Terminate the auction and make the surplus available to the Account-Owner.
            earlyTerminate = true;
            _settleLiquidationHappyFlow(account, startDebt, bidder, (amount - accountDebt));
            amount = accountDebt;
        }

        _withdraw(amount, account, account);

        emit Repay(account, bidder, amount);
    }

    /* //////////////////////////////////////////////////////////////
                        LEVERAGED ACTIONS LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Execute and interact with external logic on leverage.
     * @param amountBorrowed The amount of underlying ERC20 tokens to be lent out.
     * @param account The address of the Arcadia Account backing the debt.
     * @param actionHandler The address of the action handler to call.
     * @param actionData A bytes object containing three actionAssetData structs, an address array and a bytes array.
     * @param referrer A unique identifier of the referrer, who will receive part of the fees generated by this transaction.
     * @dev The sender might be different than the owner if they have the proper allowances.
     * @dev accountManagementAction() works similar to flash loans, this function optimistically calls external logic and checks for the Account state at the very end.
     */
    function doActionWithLeverage(
        uint256 amountBorrowed,
        address account,
        address actionHandler,
        bytes calldata actionData,
        bytes calldata signature,
        bytes3 referrer
    ) external whenBorrowNotPaused processInterests {
        // If Account is not an actual address of a Account, ownerOfAccount(address) will return the zero address.
        address accountOwner = IFactory(ACCOUNT_FACTORY).ownerOfAccount(account);
        if (accountOwner == address(0)) revert LendingPool_IsNotAnAccount();

        uint256 amountBorrowedWithFee = amountBorrowed + amountBorrowed.mulDivUp(originationFee, ONE_4);

        // Check allowances to take debt.
        if (accountOwner != msg.sender) {
            // Since calling accountManagementAction() gives the sender full control over all assets in the Account,
            // Only Beneficiaries with maximum allowance can call the doActionWithLeverage function.
            if (creditAllowance[account][accountOwner][msg.sender] != type(uint256).max) {
                revert LendingPool_Unauthorized();
            }
        }

        // Mint debt tokens to the Account, debt must be minted before the actions in the Account are performed.
        if (borrowCap > 0 && maxWithdraw(account) + amountBorrowedWithFee > borrowCap) {
            revert DebtToken_BorrowCapExceeded();
        }
        _deposit(amountBorrowedWithFee, account);

        // Add origination fee to the treasury.
        unchecked {
            if (amountBorrowedWithFee - amountBorrowed > 0) {
                totalRealisedLiquidity += SafeCastLib.safeCastTo128(amountBorrowedWithFee - amountBorrowed);
                realisedLiquidityOf[treasury] += amountBorrowedWithFee - amountBorrowed;
            }
        }

        // Send Borrowed funds to the actionHandler.
        asset.safeTransfer(actionHandler, amountBorrowed);

        // The actionHandler will use the borrowed funds (optionally with additional assets withdrawn from the Account)
        // to execute one or more actions (swap, deposit, mint...).
        // Next the actionHandler will deposit any of the remaining funds or any of the recipient token
        // resulting from the actions back into the Account.
        // As last step, after all assets are deposited back into the Account a final health check is done:
        // The Collateral Value of all assets in the Account is bigger than the total liabilities against the Account (including the debt taken during this function).
        {
            (address creditor, uint256 accountVersion) =
                IAccount(account).accountManagementAction(actionHandler, actionData, signature);
            if (creditor != address(this) || !isValidVersion[accountVersion]) revert LendingPool_Reverted();
        }

        emit Borrow(
            account, msg.sender, actionHandler, amountBorrowed, amountBorrowedWithFee - amountBorrowed, referrer
        );
    }

    /* //////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Returns the total amount of outstanding debt in the underlying asset.
     * @return totalDebt The total debt in underlying assets.
     */
    function totalAssets() public view override returns (uint256 totalDebt) {
        // Avoid a second calculation of unrealised debt (expensive)
        // if interests are already synced this block.
        if (lastSyncedTimestamp != uint32(block.timestamp)) {
            totalDebt = realisedDebt + calcUnrealisedDebt();
        } else {
            totalDebt = realisedDebt;
        }
    }

    /**
     * @notice Returns the redeemable amount of liquidity in the underlying asset of an address.
     * @param owner_ The address of the liquidity provider.
     * @return assets The redeemable amount of liquidity in the underlying asset.
     * @dev This function syncs the interests to prevent calculating UnrealisedDebt twice when depositing/withdrawing through the Tranches.
     * @dev After calling this function, the interest rate will not be updated until the next processInterests() call.
     */
    function liquidityOfAndSync(address owner_) external returns (uint256 assets) {
        _syncInterests();
        assets = realisedLiquidityOf[owner_];
    }

    /**
     * @notice Returns the redeemable amount of liquidity in the underlying asset of an address.
     * @param owner_ The address of the liquidity provider.
     * @return assets The redeemable amount of liquidity in the underlying asset.
     */
    function liquidityOf(address owner_) external view returns (uint256 assets) {
        // Avoid a second calculation of unrealised debt (expensive).
        // if interests are already synced this block.
        if (lastSyncedTimestamp != uint32(block.timestamp)) {
            // The total liquidity of a tranche equals the sum of the realised liquidity
            // of the tranche, and its pending interests.
            uint256 interest = calcUnrealisedDebt().mulDivUp(interestWeight[owner_], totalInterestWeight);
            unchecked {
                assets = realisedLiquidityOf[owner_] + interest;
            }
        } else {
            assets = realisedLiquidityOf[owner_];
        }
    }

    /**
     * @notice Skims any surplus funds in the LendingPool to the treasury.
     * @dev In normal conditions (when there are no ongoing auctions), the total Claimable Liquidity should be equal
     * to the sum of the available funds (the balanceOf() the underlying asset) in the pool and the total open debt.
     * In practice the actual sum of available funds and total open debt will always be bigger than the total Claimable Liquidity.
     * This because of the rounding errors of the ERC4626 calculations (conversions between assets and shares),
     * or because someone accidentally sent funds directly to the pool instead of depositing via a Tranche.
     * This functions makes the surplus available to the Treasury (otherwise they would be lost forever).
     * @dev In case you accidentally sent funds to the pool, contact the current treasury manager.
     */
    function skim() external processInterests {
        //During auction initiation, debt tokens representing the liquidation incentives are minted at start of the auction
        // yet not accounted for in the totalRealisedLiquidity.
        // -> skim function must be blocked during auctions.
        if (auctionsInProgress != 0) revert LendingPool_AuctionOngoing();

        // Pending interests are synced via the processInterests modifier.
        uint256 delta = asset.balanceOf(address(this)) + realisedDebt - totalRealisedLiquidity;

        // Add difference to the treasury.
        unchecked {
            totalRealisedLiquidity += SafeCastLib.safeCastTo128(delta + totalRealisedLiquidity);
            realisedLiquidityOf[treasury] += delta;
        }
    }

    /* //////////////////////////////////////////////////////////////
                            INTERESTS LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Syncs all unrealised debt (= interest for LP and treasury).
     * @dev Calculates the unrealised debt since last sync, and realises it by minting an equal amount of
     * debt tokens to all debt holders and interests to LPs and the treasury.
     */
    function _syncInterests() internal {
        // Only Sync interests once per block.
        if (lastSyncedTimestamp != uint32(block.timestamp)) {
            uint256 unrealisedDebt = calcUnrealisedDebt();
            lastSyncedTimestamp = uint32(block.timestamp);

            // Sync interests for borrowers.
            unchecked {
                realisedDebt += unrealisedDebt;
            }

            // Sync interests for LPs and Protocol Treasury.
            _syncInterestsToLiquidityProviders(unrealisedDebt);
        }
    }

    /**
     * @notice Calculates the unrealised debt (interests).
     * @return unrealisedDebt The unrealised debt.
     * @dev To calculate the unrealised debt over an amount of time, you need to calculate D[(1+r)^x-1].
     * The base of the exponential: 1 + r, is a 18 decimals fixed point number
     * with r the yearly interest rate.
     * The exponent of the exponential: x, is a 18 decimals fixed point number.
     * The exponent x is calculated as: the amount of seconds passed since last sync timestamp divided by the average of
     * seconds per year.
     */
    function calcUnrealisedDebt() public view returns (uint256 unrealisedDebt) {
        unchecked {
            //gas: Can't overflow for reasonable interest rates.
            uint256 base = 1e18 + interestRate;

            // gas: Only overflows when (block.timestamp - lastSyncedBlockTimestamp) > 1e59
            // in practice: exponent in LogExpMath lib is limited to 130e18,
            // Corresponding to a delta of timestamps of 4099680000 (or 130 years),
            // much bigger than any realistic time difference between two syncs.
            uint256 exponent = ((block.timestamp - lastSyncedTimestamp) * 1e18) / YEARLY_SECONDS;

            // gas: Taking an imaginary worst-case scenario with max interest of 1000%
            // over a period of 5 years.
            // This won't overflow as long as openDebt < 3402823669209384912995114146594816
            // which is 3.4 million billion *10**18 decimals.
            unrealisedDebt = (realisedDebt * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18;
        }

        return SafeCastLib.safeCastTo128(unrealisedDebt);
    }

    /**
     * @notice Syncs interest payments to the Lending providers and the treasury.
     * @param assets The total amount of underlying assets to be paid out as interests.
     * @dev The interestWeight of each Tranche determines the relative share of yield (interest payments) that goes to its Liquidity providers.
     */
    function _syncInterestsToLiquidityProviders(uint256 assets) internal {
        uint256 remainingAssets = assets;

        uint256 trancheShare;
        uint24 totalInterestWeight_ = totalInterestWeight;
        uint256 trancheLength = tranches.length;
        for (uint256 i; i < trancheLength;) {
            trancheShare = assets.mulDivDown(interestWeightTranches[i], totalInterestWeight_);
            unchecked {
                realisedLiquidityOf[tranches[i]] += trancheShare;
                remainingAssets -= trancheShare;
                ++i;
            }
        }
        unchecked {
            totalRealisedLiquidity = SafeCastLib.safeCastTo128(totalRealisedLiquidity + assets);

            // Add the remainingAssets to the treasury balance.
            realisedLiquidityOf[treasury] += remainingAssets;
        }
    }

    /* //////////////////////////////////////////////////////////////
                        INTEREST RATE LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the configuration parameters of InterestRateConfiguration struct.
     * @param newConfig New set of configuration parameters.
     */
    function setInterestConfig(InterestRateConfiguration calldata newConfig) external processInterests onlyOwner {
        _setInterestConfig(newConfig);
    }

    /**
     * @notice Updates the interest rate.
     * @dev Any address can call this, it will sync unrealised interests and update the interest rate.
     */
    function updateInterestRate() external processInterests { }

    /* //////////////////////////////////////////////////////////////
                        LIQUIDATION LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the maxInitiationFee and maxTerminationFee.
     * @param maxInitiationFee_ The maximum fee that is paid to the initiator of a liquidation.
     * @param maxTerminationFee_ The maximum fee that is paid to the closer of a liquidation.
     * @dev The liquidator sets the % of the debt that is paid to the initiator and terminator of a liquidation.
     * This fee is capped by the maxInitiationFee respectively maxTerminationFee.
     */
    function setMaxLiquidationFees(uint80 maxInitiationFee_, uint80 maxTerminationFee_) external onlyOwner {
        emit MaxLiquidationFeesSet(maxInitiationFee = maxInitiationFee_, maxTerminationFee = maxTerminationFee_);
    }

    /**
     * @notice Sets the estimated max network transaction cost to liquidate a position, denominated in baseCurrency.
     * @param fixedLiquidationCost_ The new fixedLiquidationCost.
     * @dev Conservative estimate of the maximal gas cost to liquidate a position (fixed cost, independent of openDebt).
     * The fixedLiquidationCost prevents dusting attacks, and ensures that upon Liquidations positions are big enough to cover
     * gas costs of the Liquidator without resulting in badDebt.
     */
    function setFixedLiquidationCost(uint96 fixedLiquidationCost_) external onlyOwner {
        emit FixedLiquidationCostSet(fixedLiquidationCost = fixedLiquidationCost_);
    }

    /**
     * @notice Initiates the liquidation process for an Account.
     * @param initiator The address of the liquidation initiator.
     * @return startDebt The initial debt of the liquidated Account.
     * @dev This function is only callable by an Arcadia Account with debt.
     * The liquidation process involves assessing the Account's debt and calculating liquidation incentives,
     * which are considered as extra debt.
     * The extra debt is then minted towards the Account to encourage the liquidation process and bring the Account to a healthy state.
     * @dev Only Accounts with non-zero balances can have debt, and debtTokens are non-transferrable.
     * @dev If the provided Account has a debt balance of 0, the function reverts with the error "LendingPool_IsNotAnAccountWithDebt."
     */
    function startLiquidation(address initiator)
        external
        override
        whenLiquidationNotPaused
        processInterests
        returns (uint256 startDebt)
    {
        // Only Accounts can have debt, and debtTokens are non-transferrable.
        // Hence by checking that the balance of the msg.sender is not 0,
        // we know that the sender is indeed an Account and has debt.
        startDebt = maxWithdraw(msg.sender);
        if (startDebt == 0) revert LendingPool_IsNotAnAccountWithDebt();

        // Calculate liquidation incentives which have to be paid by the Account owner and are minted
        // as extra debt to the Account.
        (uint256 liquidationInitiatorReward, uint256 closingReward, uint256 liquidationPenalty) =
            _calculateRewards(startDebt);

        // Mint the liquidation incentives as extra debt towards the Account.
        _deposit(liquidationInitiatorReward + liquidationPenalty + closingReward, msg.sender);

        // Increase the realised liquidity for the initiator.
        // The other incentives will only be added as realised liquidity for the respective actors
        // after the auction is finished.
        realisedLiquidityOf[initiator] += liquidationInitiatorReward;
        totalRealisedLiquidity = SafeCastLib.safeCastTo128(totalRealisedLiquidity + liquidationInitiatorReward);

        // If only ongoing auction, inform most Jr tranche that auctions are ongoing
        if (auctionsInProgress == 0) ITranche(tranches[tranches.length - 1]).setAuctionInProgress(true);

        unchecked {
            ++auctionsInProgress;
        }

        // Emit event
        emit AuctionStarted(msg.sender, address(this), uint128(startDebt));
    }

    /**
     * @notice Ends the liquidation process for a specific Account and settles the liquidation incentives.
     * @param account The address of the Account undergoing liquidation settlement.
     * @param startDebt The initial debt amount of the liquidated Account.
     * @param terminator The address of the liquidation terminator.
     * @dev In the happy flow, the auction proceeds are sufficient to pay off enough debt
     *  to bring the Account in a healthy position, and pay out all liquidation incentives to the
     *  relevant actors.
     */
    function settleLiquidationHappyFlow(address account, uint256 startDebt, address terminator)
        external
        whenLiquidationNotPaused
        onlyLiquidator
        processInterests
    {
        _settleLiquidationHappyFlow(account, startDebt, terminator, 0);
    }

    /**
     * @notice Ends the liquidation process for a specific Account and settles the liquidation incentives.
     * @param account The address of the Account undergoing liquidation settlement.
     * @param startDebt The initial debt amount of the liquidated Account.
     * @param terminator The address of the liquidation terminator.
     * @param surplus The surplus amount obtained from the liquidation process.
     * @dev In the happy flow, the auction proceeds are sufficient to pay off enough debt
     *  to bring the Account in a healthy position, and pay out all liquidation incentives to the
     *  relevant actors.
     * @dev The following pending incentives are made claimable:
     *   - The "auctionTerminationReward", going towards the terminator of the auction.
     *   - The "liquidationFee", going towards LPs and the Treasury.
     *   - If there are still remaining assets after paying off all debt and incentives,
     *   the surplus goes towards the owner of the account.
     */
    function _settleLiquidationHappyFlow(address account, uint256 startDebt, address terminator, uint256 surplus)
        internal
    {
        (, uint256 auctionTerminationReward, uint256 liquidationPenalty) = _calculateRewards(startDebt);

        // Pay out the "liquidationPenalty" to the LPs and Treasury.
        _syncLiquidationFeeToLiquidityProviders(liquidationPenalty);

        // Unsafe cast: sum will revert if it overflows.
        totalRealisedLiquidity =
            uint128(totalRealisedLiquidity + auctionTerminationReward + liquidationPenalty + surplus);

        // Decrement the number of auctions in progress.
        unchecked {
            // Pay out any surplus to the current Account Owner.
            if (surplus > 0) realisedLiquidityOf[IAccount(account).owner()] += surplus;
            // Pay out the "auctionTerminationReward" to the "terminator".
            realisedLiquidityOf[terminator] += auctionTerminationReward;

            --auctionsInProgress;
        }

        // Hook to the most junior Tranche to inform that there are no ongoing auctions.
        if (auctionsInProgress == 0 && tranches.length > 0) {
            ITranche(tranches[tranches.length - 1]).setAuctionInProgress(false);
        }
        // Event emitted by Liquidator.
    }

    /**
     * @notice Ends the liquidation process for a specific Account and settles the liquidation incentives/bad debt.
     * @param account The address of the Account undergoing liquidation settlement.
     * @param startDebt The initial debt amount of the liquidated Account.
     * @param terminator The address of the auction terminator.
     * @dev In the unhappy flow, the auction proceeds are not sufficient to pay out all liquidation incentives
     *  and maybe not even to pay off all debt.
     * @dev The order in which incentives are not paid out/ bad debt is settled is fixed:
     *   - First, the "liquidationFee", going towards LPs and the Treasury is not paid out.
     *   - Next, the "auctionTerminationReward", going towards the terminator of the auction is not paid out.
     *   - Next, the underlying assets of LPs in the most junior Tranche are written off pro rata.
     *   - Next, the underlying assets of LPs in the second most junior Tranche are written off pro rata.
     *   - etc.
     */
    function settleLiquidationUnhappyFlow(address account, uint256 startDebt, address terminator)
        external
        whenLiquidationNotPaused
        onlyLiquidator
        processInterests
    {
        (, uint256 auctionTerminationReward, uint256 liquidationPenalty) = _calculateRewards(startDebt);

        // Any remaining debt that was not recovered during the auction must be written off.
        // Depending on the size of the remaining debt, different stakeholders will be impacted.
        uint256 openDebt = maxWithdraw(account);
        if (openDebt > auctionTerminationReward + liquidationPenalty) {
            // "openDebt" is bigger than pending liquidation incentives.
            // No incentives will be paid out, and a default event is triggered.
            uint256 badDebt;
            unchecked {
                badDebt = openDebt - auctionTerminationReward - liquidationPenalty;
            }

            totalRealisedLiquidity = uint128(totalRealisedLiquidity - badDebt);
            _processDefault(badDebt);
        } else {
            uint256 remainder = liquidationPenalty + auctionTerminationReward - openDebt;
            if (openDebt >= liquidationPenalty) {
                // "openDebt" is bigger than the "liquidationPenalty" but smaller than the total pending liquidation incentives.
                // Don't pay out the "liquidationPenalty" to Lps, partially pay out the "terminator".
                realisedLiquidityOf[terminator] += remainder;
            } else {
                // "openDebt" is smaller than the "liquidationPenalty".
                // Fully pay out the "terminator" and partially pay out the "liquidationPenalty" to Lps.
                realisedLiquidityOf[terminator] += auctionTerminationReward;
                _syncLiquidationFeeToLiquidityProviders(remainder - auctionTerminationReward);
            }
            // Unsafe cast: sum will revert if it overflows.
            totalRealisedLiquidity = uint128(totalRealisedLiquidity + remainder);
        }
        _withdraw(openDebt, account, account);

        // Decrement the number of auctions in progress.
        unchecked {
            --auctionsInProgress;
        }

        // Hook to the most junior Tranche to inform that there are no ongoing auctions.
        if (auctionsInProgress == 0 && tranches.length > 0) {
            ITranche(tranches[tranches.length - 1]).setAuctionInProgress(false);
        }
        // Event emitted by Liquidator.
    }

    /**
     * @notice Handles the accounting in case of bad debt (Account became undercollateralised).
     * @param badDebt The total amount of underlying assets that need to be written off as bad debt.
     * @dev The order of the Tranches is important, the most senior Tranche is at index 0, the most junior at the last index.
     * @dev The most junior tranche will lose its underlying assets first. If all liquidity of a certain Tranche is written off,
     * the complete tranche is locked and removed. If there is still remaining bad debt, the next Tranche starts losing capital.
     */
    function _processDefault(uint256 badDebt) internal {
        address tranche;
        uint256 maxBurnable;
        for (uint256 i = tranches.length; i > 0;) {
            unchecked {
                --i;
            }
            tranche = tranches[i];
            maxBurnable = realisedLiquidityOf[tranche];
            if (badDebt < maxBurnable) {
                // Deduct badDebt from the balance of the most junior Tranche.
                unchecked {
                    realisedLiquidityOf[tranche] -= badDebt;
                }
                break;
            } else {
                // Unhappy flow, should never occur in practice!
                // badDebt is bigger than the balance of most junior Tranche -> tranche is completely wiped out
                // and temporarily locked (no new deposits or withdraws possible).
                // DAO or insurance might refund (Part of) the losses, and add Tranche back.
                realisedLiquidityOf[tranche] = 0;
                _popTranche(i, tranche);
                unchecked {
                    badDebt -= maxBurnable;
                }
                ITranche(tranche).lock();
                // Hook to the new most junior Tranche to inform that auctions are ongoing.
                if (i != 0) ITranche(tranches[i - 1]).setAuctionInProgress(true);
            }
        }
    }

    /**
     * @notice Syncs liquidation penalties to the Lending providers and the treasury.
     * @param assets The total amount of underlying assets to be paid out as liquidation fee.
     * @dev The liquidationWeight of each Tranche determines the relative share of yield (liquidation penalties)
     * that goes to its Liquidity providers.
     */
    function _syncLiquidationFeeToLiquidityProviders(uint256 assets) internal {
        uint256 remainingAssets = assets;

        uint256 trancheShare;
        uint256 weightOfTranche;
        for (uint256 i; i < tranches.length;) {
            weightOfTranche = liquidationWeightTranches[i];

            if (weightOfTranche != 0) {
                trancheShare = assets.mulDivDown(weightOfTranche, totalLiquidationWeight);
                unchecked {
                    realisedLiquidityOf[tranches[i]] += trancheShare;
                    remainingAssets -= trancheShare;
                }
            }

            unchecked {
                ++i;
            }
        }

        unchecked {
            // Add the remainingAssets to the treasury balance.
            realisedLiquidityOf[treasury] += remainingAssets;
        }
    }

    /**
     * @notice Calculates the rewards and penalties for the liquidation process based on the given debt amount.
     * @param debt The debt amount of the Account at the time of liquidation initiation.
     * @return liquidationInitiatorReward The reward for the liquidation initiator, capped by the maximum initiator fee.
     * @return liquidationTerminationReward The reward for closing the liquidation process, capped by the maximum closing fee.
     * @return liquidationPenalty The penalty paid by the Account owner towards the liquidity providers and the protocol treasury.
     */
    function _calculateRewards(uint256 debt)
        internal
        view
        returns (uint256 liquidationInitiatorReward, uint256 liquidationTerminationReward, uint256 liquidationPenalty)
    {
        uint256 maxInitiationFee_ = maxInitiationFee;
        uint256 maxTerminationFee_ = maxTerminationFee;
        liquidationInitiatorReward = debt.mulDivDown(initiatorRewardWeight, ONE_4);
        liquidationInitiatorReward =
            liquidationInitiatorReward > maxInitiationFee_ ? maxInitiationFee_ : liquidationInitiatorReward;

        liquidationTerminationReward = debt.mulDivDown(closingRewardWeight, ONE_4);
        liquidationTerminationReward =
            liquidationTerminationReward > maxTerminationFee_ ? maxTerminationFee_ : liquidationTerminationReward;

        liquidationPenalty = debt.mulDivUp(penaltyWeight, ONE_4);
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the liquidation weights.
     * @param initiatorRewardWeight_ Fee paid to the Liquidation Initiator.
     * @param penaltyWeight_ Penalty paid by the Account owner to the Creditor.
     * @param closingRewardWeight_ Fee paid to the Liquidation closer.
     * @dev Each weight has 4 decimals precision (50 equals 0,005 or 0,5%).
     */
    function setWeights(uint256 initiatorRewardWeight_, uint256 penaltyWeight_, uint256 closingRewardWeight_)
        external
        onlyOwner
    {
        if (initiatorRewardWeight_ + penaltyWeight_ + closingRewardWeight_ > 1100) revert LendingPool_WeightsTooHigh();

        initiatorRewardWeight = uint16(initiatorRewardWeight_);
        penaltyWeight = uint16(penaltyWeight_);
        closingRewardWeight = uint16(closingRewardWeight_);

        emit WeightsSet(uint16(initiatorRewardWeight_), uint16(penaltyWeight_), uint16(closingRewardWeight_));
    }

    /* //////////////////////////////////////////////////////////////
                            ACCOUNT LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets a new Risk Manager.
     * @param riskManager_ The address of the new Risk Manager.
     */
    function setRiskManager(address riskManager_) external onlyOwner {
        _setRiskManager(riskManager_);
    }

    /**
     * @notice Enables or disables a certain Account version to be used as margin account.
     * @param accountVersion the Account version to be enabled/disabled.
     * @param valid The validity of the respective accountVersion.
     */
    function setAccountVersion(uint256 accountVersion, bool valid) external onlyOwner {
        _setAccountVersion(accountVersion, valid);
    }

    /**
     * @inheritdoc Creditor
     */
    function openMarginAccount(uint256 accountVersion)
        external
        view
        override
        returns (bool success, address baseCurrency, address liquidator_, uint256 fixedLiquidationCost_)
    {
        if (isValidVersion[accountVersion]) {
            success = true;
            baseCurrency = address(asset);
            liquidator_ = LIQUIDATOR;
            fixedLiquidationCost_ = fixedLiquidationCost;
        }
    }

    /**
     * @inheritdoc Creditor
     */
    function getOpenPosition(address account) external view override returns (uint256 openPosition) {
        openPosition = maxWithdraw(account);
    }
}
