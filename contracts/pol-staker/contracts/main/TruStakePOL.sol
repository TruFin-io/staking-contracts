// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.28;

// OpenZeppelin
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// Polygon
import {IValidatorShare} from "../interfaces/IValidatorShare.sol";
import {IStakeManager} from "../interfaces/IStakeManager.sol";
import {IDelegateRegistry} from "../interfaces/IDelegateRegistry.sol";

// TruFin
import {ITruStakePOL} from "../interfaces/ITruStakePOL.sol";
import {TruStakePOLStorage} from "./TruStakePOLStorage.sol";
import {StakerInfo, ValidatorState, Validator, Withdrawal} from "./Types.sol";
import {IMasterWhitelist} from "../interfaces/IMasterWhitelist.sol";

uint256 constant FEE_PRECISION = 1e4;
uint256 constant MAX_EPSILON = 1e12;
uint256 constant ONE_POL = 1e18;
uint256 constant WAD = 1e18;

/// @title TruStakePOL
/// @notice An auto-compounding liquid staking POL vault.
contract TruStakePOL is
    TruStakePOLStorage,
    ITruStakePOL,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    //************************************************************************//
    // Libraries
    //************************************************************************//

    using SafeERC20 for IERC20;

    //************************************************************************//
    // Storage
    //************************************************************************//

    // keccak256(abi.encode(uint256(keccak256("trufin.storage.TruStakePOL")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TruStakePOLStorageLocation =
        0x2d27943992ce797a3601911eb0653a18c3311f54cf95fc9eb4503583f50b2300;

    function _getTruStakePOLStorage() private pure returns (TruStakePOLStorageStruct storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := TruStakePOLStorageLocation
        }
    }

    //************************************************************************//
    // Modifiers
    //************************************************************************//

    // Reverts call if caller is not whitelisted
    modifier onlyWhitelist() {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();

        if (!IMasterWhitelist($._whitelistAddress).isUserWhitelisted(msg.sender)) {
            revert UserNotWhitelisted();
        }
        _;
    }

    //************************************************************************//
    // Constructor & Initializer
    //************************************************************************//

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Vault state initializer.
    /// @param _stakingTokenAddress POL token address.
    /// @param _stakeManagerContractAddress Polygon's StakeManager contract address.
    /// @param _validator Share contract address of the validator the vault delegates to.
    /// @param _whitelistAddress The vault's whitelist contract address.
    /// @param _treasuryAddress Treasury address that receives vault fees.
    /// @param _fee Fee taken on restake in basis points.
    function initialize(
        address _stakingTokenAddress,
        address _stakeManagerContractAddress,
        address _validator,
        address _whitelistAddress,
        address _treasuryAddress,
        address _delegateRegistry,
        uint16 _fee
    ) external initializer {
        // Initialize derived state
        __ERC20_init("TruStake POL Vault Shares", "TruPOL");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        // Ensure addresses are non-zero
        _checkNotZeroAddress(_stakingTokenAddress);
        _checkNotZeroAddress(_stakeManagerContractAddress);
        _checkNotZeroAddress(_validator);
        _checkNotZeroAddress(_whitelistAddress);
        _checkNotZeroAddress(_treasuryAddress);
        _checkNotZeroAddress(_delegateRegistry);

        if (_fee > FEE_PRECISION) revert FeeTooLarge();

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();

        // Initialize contract state
        $._stakingTokenAddress = _stakingTokenAddress;
        $._stakeManagerContractAddress = _stakeManagerContractAddress;
        $._defaultValidatorAddress = _validator;
        $._validatorAddresses.push(_validator);
        $._validators[_validator].state = ValidatorState.ENABLED;
        $._whitelistAddress = _whitelistAddress;
        $._treasuryAddress = _treasuryAddress;
        $._delegateRegistry = _delegateRegistry;
        $._fee = _fee;
        $._epsilon = 1e4;
        $._minDeposit = ONE_POL; // default minimum is 1 POL

        emit StakerInitialized(
            msg.sender,
            _stakingTokenAddress,
            _stakeManagerContractAddress,
            _validator,
            _whitelistAddress,
            _treasuryAddress,
            _delegateRegistry,
            _fee,
            ONE_POL
        );
    }

    //************************************************************************//
    // View/Pure Functions
    //************************************************************************//

    // Vault State

    /// @inheritdoc ITruStakePOL
    function stakerInfo() external view override returns (StakerInfo memory) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        return StakerInfo({
            stakingTokenAddress: $._stakingTokenAddress,
            stakeManagerContractAddress: $._stakeManagerContractAddress,
            treasuryAddress: $._treasuryAddress,
            defaultValidatorAddress: $._defaultValidatorAddress,
            whitelistAddress: $._whitelistAddress,
            delegateRegistry: $._delegateRegistry,
            epsilon: $._epsilon,
            fee: $._fee,
            minDeposit: $._minDeposit
        });
    }

    /// @inheritdoc ITruStakePOL
    function getDust() external view override returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        return (totalRewards() * $._fee) / FEE_PRECISION;
    }

    /// @inheritdoc ITruStakePOL
    function totalAssets() public view override returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        return IERC20($._stakingTokenAddress).balanceOf(address(this));
    }

    /// @inheritdoc ITruStakePOL
    function totalStaked() public view override returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        uint256 validatorCount = $._validatorAddresses.length;
        uint256 stake;
        for (uint256 i; i < validatorCount; ++i) {
            stake += $._validators[$._validatorAddresses[i]].stakedAmount;
        }
        return stake;
    }

    /// @inheritdoc ITruStakePOL
    function totalRewards() public view override returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        uint256 validatorCount = $._validatorAddresses.length;
        uint256 validatorRewards;
        for (uint256 i; i < validatorCount; ++i) {
            validatorRewards += IValidatorShare($._validatorAddresses[i]).getLiquidRewards(address(this));
        }
        return validatorRewards;
    }

    /// @inheritdoc ITruStakePOL
    function sharePrice() public view override returns (uint256, uint256) {
        if (totalSupply() == 0) return (WAD, 1);

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();

        uint256 totalCapitalTimesFeePrecision =
            (totalStaked() + totalAssets()) * FEE_PRECISION + (FEE_PRECISION - $._fee) * totalRewards();

        return (totalCapitalTimesFeePrecision * WAD, totalSupply() * FEE_PRECISION);
    }

    /// @inheritdoc ITruStakePOL
    function getCurrentEpoch() public view override returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        return IStakeManager($._stakeManagerContractAddress).epoch();
    }

    // Validator and Withdrawal

    /// @inheritdoc ITruStakePOL
    function getValidators() external view override returns (address[] memory) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        return $._validatorAddresses;
    }

    /// @inheritdoc ITruStakePOL
    function getAllValidators() external view override returns (Validator[] memory) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        uint256 validatorCount = $._validatorAddresses.length;
        Validator[] memory validatorArray = new Validator[](validatorCount);
        for (uint256 i; i < validatorCount; ++i) {
            address validatorAddress = $._validatorAddresses[i];
            Validator memory validator = $._validators[validatorAddress];
            validator.validatorAddress = validatorAddress;
            validatorArray[i] = validator;
        }
        return validatorArray;
    }

    /// @inheritdoc ITruStakePOL
    function validatorAddresses(uint256 index) external view override returns (address) {
        return _getTruStakePOLStorage()._validatorAddresses[index];
    }

    /// @inheritdoc ITruStakePOL
    function validators(address validator) external view override returns (Validator memory) {
        return _getTruStakePOLStorage()._validators[validator];
    }

    /// @inheritdoc ITruStakePOL
    function withdrawals(address validator, uint256 nonce) external view override returns (Withdrawal memory) {
        return _getTruStakePOLStorage()._withdrawals[validator][nonce];
    }

    /// @inheritdoc ITruStakePOL
    function isClaimable(uint256 _unbondNonce, address _validator) external view override returns (bool) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        // Get epoch at which unbonding of delegated POL was initiated
        (, uint256 withdrawEpoch) = IValidatorShare(_validator).unbonds_new(address(this), _unbondNonce);

        // Check required epochs have passed
        bool epochsPassed =
            getCurrentEpoch() >= withdrawEpoch + IStakeManager($._stakeManagerContractAddress).withdrawalDelay();

        bool withdrawalPresent = $._withdrawals[_validator][_unbondNonce].user != address(0);

        return withdrawalPresent && epochsPassed;
    }

    /// @inheritdoc ITruStakePOL
    function getUnbondNonce(address _validator) external view override returns (uint256) {
        return IValidatorShare(_validator).unbondNonces(address(this));
    }

    /// @inheritdoc ITruStakePOL
    function getRewardsFromValidator(address _validator) public view override returns (uint256) {
        return IValidatorShare(_validator).getLiquidRewards(address(this));
    }

    // User

    /// @inheritdoc ITruStakePOL
    function getUserInfo(address _user) external view override returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 globalPriceNum, uint256 globalPriceDenom) = sharePrice();
        uint256 maxRedeemable = balanceOf(_user);
        uint256 maxWithdrawAmount = maxWithdraw(_user);
        uint256 epoch = getCurrentEpoch();

        return (maxRedeemable, maxWithdrawAmount, globalPriceNum, globalPriceDenom, epoch);
    }

    /// @inheritdoc ITruStakePOL
    function previewWithdraw(uint256 _assets) external view override returns (uint256) {
        return _convertToShares(_assets, Math.Rounding.Ceil);
    }

    /// @inheritdoc ITruStakePOL
    function maxWithdraw(address _user) public view override returns (uint256) {
        uint256 preview = previewRedeem(balanceOf(_user));
        if (preview == 0) return 0;

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();

        return preview + $._epsilon;
    }

    /// @inheritdoc ITruStakePOL
    function previewRedeem(uint256 _shares) public view override returns (uint256) {
        return _convertToAssets(_shares, Math.Rounding.Ceil);
    }

    /// @inheritdoc ITruStakePOL
    function convertToShares(uint256 _assets) public view override returns (uint256) {
        return _convertToShares(_assets, Math.Rounding.Floor);
    }

    /// @inheritdoc ITruStakePOL
    function convertToAssets(uint256 _shares) public view override returns (uint256) {
        return _convertToAssets(_shares, Math.Rounding.Floor);
    }

    //************************************************************************//
    // Vault Owner Admin Actions
    //************************************************************************//

    /// @notice Allows owner to pause the contract. Requires the contract to be unpaused.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Allows owner to unpause the contract. Requires the contract to be paused.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets the whitelist used to check user status.
    /// @param _whitelistAddress to point to.
    function setWhitelist(address _whitelistAddress) external onlyOwner {
        _checkNotZeroAddress(_whitelistAddress);
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        emit SetWhitelist($._whitelistAddress, _whitelistAddress);
        $._whitelistAddress = _whitelistAddress;
    }

    /// @notice Sets the treasury used to accumulate rewards.
    /// @param _treasuryAddress to receive rewards and fees.
    function setTreasury(address _treasuryAddress) external onlyOwner {
        _checkNotZeroAddress(_treasuryAddress);
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        emit SetTreasury($._treasuryAddress, _treasuryAddress);
        $._treasuryAddress = _treasuryAddress;
    }

    /// @notice Sets the default validator used for staking.
    /// @param _validator New default validator to stake to and withdraw from.
    function setDefaultValidator(address _validator) external onlyOwner {
        _checkNotZeroAddress(_validator);
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if ($._validators[_validator].state != ValidatorState.ENABLED) revert ValidatorNotEnabled();

        emit SetDefaultValidator($._defaultValidatorAddress, _validator);
        $._defaultValidatorAddress = _validator;
    }

    /// @notice Sets the fee on certain actions within the protocol.
    /// @param _fee New fee cannot be larger than fee precision.
    function setFee(uint16 _fee) external onlyOwner {
        if (_fee > FEE_PRECISION) revert FeeTooLarge();

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        emit SetFee($._fee, _fee);
        $._fee = _fee;
    }

    /// @notice Sets the epsilon for rounding.
    /// @param _epsilon Buffer amount for rounding.
    function setEpsilon(uint256 _epsilon) external onlyOwner {
        if (_epsilon > MAX_EPSILON) revert EpsilonTooLarge();

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        emit SetEpsilon($._epsilon, _epsilon);
        $._epsilon = _epsilon;
    }

    /// @notice Sets the lower deposit limit.
    /// @param _newMinDeposit New minimum amount of POL one has to deposit (default 1e18 = 1 POL).
    function setMinDeposit(uint256 _newMinDeposit) external onlyOwner {
        if (_newMinDeposit < ONE_POL) revert MinDepositTooSmall();

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        emit SetMinDeposit($._minDeposit, _newMinDeposit);
        $._minDeposit = _newMinDeposit;
    }

    /// @notice Adds a new validator to the list of validators supported by the Staker.
    /// @param _validator The share contract address of the validator to add.
    /// @dev Newly added validators are considered enabled by default.
    /// @dev This function reverts when a validator with the same share contract address already exists.
    function addValidator(address _validator) external onlyOwner {
        _checkNotZeroAddress(_validator);

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if ($._validators[_validator].state != ValidatorState.NONE) revert ValidatorAlreadyExists();

        $._validatorAddresses.push(_validator);
        $._validators[_validator].state = ValidatorState.ENABLED;

        emit ValidatorAdded(_validator);
    }

    /// @notice Disable an enabled validator to prevent depositing and staking to it.
    /// @param _validator The share contract address of the validator to disable.
    function disableValidator(address _validator) external onlyOwner {
        _checkNotZeroAddress(_validator);

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if ($._validators[_validator].state == ValidatorState.NONE) revert ValidatorDoesNotExist();
        if ($._validators[_validator].state != ValidatorState.ENABLED) revert ValidatorNotEnabled();

        $._validators[_validator].state = ValidatorState.DISABLED;

        emit ValidatorStateChanged(_validator, ValidatorState.ENABLED, ValidatorState.DISABLED);
    }

    /// @notice Enable a disabled validator to allow depositing and staking to it.
    /// @param _validator The share contract address of the validator to enable.
    function enableValidator(address _validator) external onlyOwner {
        _checkNotZeroAddress(_validator);

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if ($._validators[_validator].state == ValidatorState.NONE) revert ValidatorDoesNotExist();
        if ($._validators[_validator].state != ValidatorState.DISABLED) revert ValidatorNotDisabled();

        $._validators[_validator].state = ValidatorState.ENABLED;

        emit ValidatorStateChanged(_validator, ValidatorState.DISABLED, ValidatorState.ENABLED);
    }

    /// @notice Sets the delegate registry.
    /// @param _delegateRegistry Address of the delegate registry.
    function setDelegateRegistry(address _delegateRegistry) external onlyOwner {
        _checkNotZeroAddress(_delegateRegistry);
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        emit SetDelegateRegistry($._delegateRegistry, _delegateRegistry);
        $._delegateRegistry = _delegateRegistry;
    }

    /// @notice Sets the governance delegation for the vault.
    /// @param context Context for the delegation.
    /// @param delegates Array of delegations.
    /// @param expirationTimestamp Expiration timestamp for the delegation.
    function setGovernanceDelegation(
        string calldata context,
        IDelegateRegistry.Delegation[] calldata delegates,
        uint256 expirationTimestamp
    ) external onlyOwner {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if (delegates.length == 0) {
            IDelegateRegistry($._delegateRegistry).clearDelegation(context);
            emit GovernanceDelegationCleared(context);
            return;
        }
        IDelegateRegistry($._delegateRegistry).setDelegation(context, delegates, expirationTimestamp);
        emit GovernanceDelegationSet(context, delegates, expirationTimestamp);
    }

    //************************************************************************//
    // External Functions
    //************************************************************************//

    /// @inheritdoc ITruStakePOL
    function deposit(uint256 _assets) external override onlyWhitelist nonReentrant whenNotPaused returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if (_assets < $._minDeposit) revert DepositBelowMinDeposit();
        return _deposit(msg.sender, _assets, $._defaultValidatorAddress);
    }

    /// @inheritdoc ITruStakePOL
    function depositToSpecificValidator(uint256 _assets, address _validator)
        external
        override
        onlyWhitelist
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if (_assets < $._minDeposit) revert DepositBelowMinDeposit();
        return _deposit(msg.sender, _assets, _validator);
    }

    /// @inheritdoc ITruStakePOL
    function withdraw(uint256 _assets)
        external
        override
        onlyWhitelist
        nonReentrant
        whenNotPaused
        returns (uint256, uint256)
    {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        return _withdrawRequest(msg.sender, _assets, $._defaultValidatorAddress);
    }

    /// @inheritdoc ITruStakePOL
    function withdrawFromSpecificValidator(uint256 _assets, address _validator)
        external
        override
        onlyWhitelist
        nonReentrant
        whenNotPaused
        returns (uint256, uint256)
    {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if ($._validators[_validator].state == ValidatorState.NONE) revert ValidatorDoesNotExist();
        return _withdrawRequest(msg.sender, _assets, _validator);
    }

    /// @inheritdoc ITruStakePOL
    function compoundRewards(address _validator) external override nonReentrant whenNotPaused {
        (uint256 globalPriceNum, uint256 globalPriceDenom) = sharePrice();
        uint256 amountRestaked = _restake();

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();

        // To keep share price constant when rewards are staked, new shares need to be minted
        uint256 shareIncrease = (amountRestaked * $._fee * WAD * globalPriceDenom) / (globalPriceNum * FEE_PRECISION);

        // Minted shares are given to the treasury to effectively take a fee
        _mint($._treasuryAddress, shareIncrease);

        // if there is POL in the vault, stake it with the provided validator
        if (totalAssets() > 0) {
            _deposit(address(0), 0, _validator);
        }

        emit RewardsCompounded(
            amountRestaked,
            shareIncrease,
            balanceOf($._treasuryAddress),
            totalStaked(),
            totalSupply(),
            totalRewards(),
            totalAssets()
        );
    }

    /// @inheritdoc ITruStakePOL
    function withdrawClaim(uint256 _unbondNonce, address _validator)
        external
        override
        onlyWhitelist
        nonReentrant
        whenNotPaused
    {
        _withdrawClaim(_unbondNonce, _validator);
    }

    /// @inheritdoc ITruStakePOL
    function claimList(uint256[] calldata _unbondNonces, address _validator)
        external
        override
        onlyWhitelist
        nonReentrant
        whenNotPaused
    {
        uint256 len = _unbondNonces.length;

        for (uint256 i; i < len; ++i) {
            _withdrawClaim(_unbondNonces[i], _validator);
        }
    }

    //************************************************************************//
    // Private Functions
    //************************************************************************//

    /// @notice Private deposit function which stakes and mints shares for the user + treasury.
    /// @param _user User depositing the amount.
    /// @param _amount Amount to be deposited.
    /// @param _validator Address of the validator to stake to.
    function _deposit(address _user, uint256 _amount, address _validator) private returns (uint256 shareIncreaseUser) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        if ($._validators[_validator].state != ValidatorState.ENABLED) revert ValidatorNotEnabled();

        (uint256 globalPriceNum, uint256 globalPriceDenom) = sharePrice();

        // calculate share increase
        shareIncreaseUser = convertToShares(_amount);
        uint256 shareIncreaseTsy =
            (getRewardsFromValidator(_validator) * $._fee * WAD * globalPriceDenom) / (globalPriceNum * FEE_PRECISION);

        // piggyback previous withdrawn rewards in this staking call
        uint256 stakeAmount = _amount + totalAssets();

        _mint($._treasuryAddress, shareIncreaseTsy);

        // mint shares to user and transfer staking token from user to Staker
        if (_user != address(0)) {
            _mint(_user, shareIncreaseUser);
            IERC20($._stakingTokenAddress).safeTransferFrom(_user, address(this), _amount);
        }

        // approve funds to Stake Manager
        IERC20($._stakingTokenAddress).safeIncreaseAllowance($._stakeManagerContractAddress, stakeAmount);

        // interact with Validator Share contract to stake
        _stake(stakeAmount, _validator);
        // claimed rewards increase here as liquid rewards on validator share contract
        // are set to zero rewards and transferred to this vault

        emit Deposited(
            _user,
            _amount,
            stakeAmount,
            shareIncreaseUser,
            balanceOf(_user),
            shareIncreaseTsy,
            balanceOf($._treasuryAddress),
            _validator,
            totalAssets(),
            totalStaked(),
            totalSupply(),
            totalRewards()
        );
    }

    /// @notice Private function to handle withdrawals and burning shares.
    /// @param _user The user that is making the request.
    /// @param _amount The amount to be withdrawn.
    /// @param _validator Address of the validator to withdraw from.
    function _withdrawRequest(address _user, uint256 _amount, address _validator)
        private
        returns (uint256 shareDecreaseUser, uint256 unbondNonce)
    {
        if (_amount == 0) revert WithdrawalRequestAmountCannotEqualZero();

        (uint256 globalPriceNum, uint256 globalPriceDenom) = sharePrice();

        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();

        // If remaining user balance is below 1 POL, entire balance is withdrawn and all shares
        // are burnt. We allow the user to withdraw their deposited amount + epsilon
        {
            uint256 maxWithdrawal = maxWithdraw(_user);
            if (_amount > maxWithdrawal) revert WithdrawalAmountTooLarge();

            if (maxWithdrawal - _amount < ONE_POL) {
                _amount = maxWithdrawal;
                shareDecreaseUser = balanceOf(_user);
            } else {
                // calculate share decrease
                shareDecreaseUser = (_amount * globalPriceDenom * WAD) / globalPriceNum;
            }

            // check if the validator has enough staked assets to withdraw
            uint256 validatorStake = $._validators[_validator].stakedAmount;
            if (_amount > validatorStake) revert WithdrawalAmountAboveValidatorStake();
        }

        uint256 shareIncreaseTsy =
            (getRewardsFromValidator(_validator) * $._fee * globalPriceDenom * WAD) / (globalPriceNum * FEE_PRECISION);

        _burn(_user, shareDecreaseUser);

        _mint($._treasuryAddress, shareIncreaseTsy);

        // interact with staking contract to initiate unbonding
        unbondNonce = _unbond(_amount, _validator);

        // store user under unbond nonce, used for fair claiming
        $._withdrawals[_validator][unbondNonce] = Withdrawal(_user, _amount);

        emit WithdrawalRequested(
            _user,
            _amount,
            shareDecreaseUser,
            balanceOf(_user),
            shareIncreaseTsy,
            balanceOf($._treasuryAddress),
            _validator,
            unbondNonce,
            getCurrentEpoch(), // only once 80 epochs have passed can this be claimed
            totalAssets(),
            totalStaked(),
            totalSupply(),
            totalRewards()
        );
    }

    /// @notice Handles withdraw claims internally according to unbond nonces (once unbonding period has passed).
    /// @param _unbondNonce The claim number the user got when initiating the withdrawal.
    /// @param _validator Address of the validator to claim from.
    function _withdrawClaim(uint256 _unbondNonce, address _validator) private {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        Withdrawal memory withdrawal = $._withdrawals[_validator][_unbondNonce];

        if (withdrawal.user == address(0)) {
            // withdraw claim does not exist
            revert WithdrawClaimNonExistent();
        }

        delete $._withdrawals[_validator][_unbondNonce];

        if (withdrawal.user != msg.sender) revert SenderMustHaveInitiatedWithdrawalRequest();

        // claim will revert if unbonding not finished for this unbond nonce
        uint256 receivedAmount = _claimStake(_unbondNonce, _validator);

        // transfer claimed POL to claimer
        IERC20($._stakingTokenAddress).safeTransfer(msg.sender, receivedAmount);

        emit WithdrawalClaimed(msg.sender, _validator, _unbondNonce, withdrawal.amount, receivedAmount);
    }

    /// @notice Validator function that transfers the _amount to the stake manager and stakes the assets onto the validator.
    /// @param _amount Amount of POL to stake.
    /// @param _validator Address of the validator to stake with.
    function _stake(uint256 _amount, address _validator) private {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        uint256 amountToDeposit = IValidatorShare(_validator).buyVoucherPOL(_amount, _amount);
        $._validators[_validator].stakedAmount += amountToDeposit;
    }

    /// @notice Requests to unstake a certain amount of POL from the specified validator.
    /// @param _amount Amount of POL to initiate the unstaking of.
    /// @param _validator Address of the validator to unstake from.
    function _unbond(uint256 _amount, address _validator) private returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        $._validators[_validator].stakedAmount -= _amount;
        IValidatorShare(_validator).sellVoucher_newPOL(_amount, _amount);
        return IValidatorShare(_validator).unbondNonces(address(this));
    }

    /// @notice Internal function for claiming the POL from a withdrawal request made previously.
    /// @param _unbondNonce Unbond nonce of the withdrawal request being claimed.
    /// @param _validator Address of the validator to claim from.
    /// @return The amount of POL received by the vault from the validator.
    function _claimStake(uint256 _unbondNonce, address _validator) private returns (uint256) {
        uint256 assetsBefore = totalAssets();
        IValidatorShare(_validator).unstakeClaimTokens_newPOL(_unbondNonce);
        return totalAssets() - assetsBefore;
    }

    /// @notice Calls the validator share contract's restake functionality on all enabled validators
    /// to turn earned rewards into staked POL.
    /// @dev Logs a RestakeError event when an exception occurs while calling restake on a validator.
    function _restake() private returns (uint256) {
        TruStakePOLStorageStruct storage $ = _getTruStakePOLStorage();
        uint256 validatorCount = $._validatorAddresses.length;
        uint256 totalAmountRestaked;
        for (uint256 i; i < validatorCount; ++i) {
            address validator = $._validatorAddresses[i];
            if ($._validators[validator].state == ValidatorState.ENABLED) {
                // log an event on "Too small rewards to restake" and other exceptions
                try IValidatorShare(validator).restakePOL() returns (uint256 amountRestaked, uint256 liquidRewards) {
                    $._validators[validator].stakedAmount += amountRestaked;
                    totalAmountRestaked += liquidRewards;
                } catch Error(string memory reason) {
                    emit RestakeError(validator, reason);
                }
            }
        }
        return totalAmountRestaked;
    }

    //************************************************************************//
    // Private View Functions
    //************************************************************************//

    /// @notice Private function to convert POL to TruPOL.
    /// @param assets Assets in POL to be converted into TruPOL.
    function _convertToShares(uint256 assets, Math.Rounding rounding) private view returns (uint256) {
        (uint256 globalPriceNum, uint256 globalPriceDenom) = sharePrice();
        return Math.mulDiv(assets * WAD, globalPriceDenom, globalPriceNum, rounding);
    }

    /// @notice Private function to convert TruPOL to POL.
    /// @param shares TruPOL shares to be converted into POL.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) private view returns (uint256) {
        (uint256 globalPriceNum, uint256 globalPriceDenom) = sharePrice();
        return Math.mulDiv(shares, globalPriceNum, globalPriceDenom * WAD, rounding);
    }

    /// @notice Checks whether an address is the zero address.
    /// @dev Gas-efficient way to check using assembly.
    /// @param toCheck Address to be checked.
    function _checkNotZeroAddress(address toCheck) private pure {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            //more gas efficient to use assembly for zero address check
            if iszero(toCheck) {
                let ptr := mload(0x40)
                mstore(ptr, 0x1cb411bc00000000000000000000000000000000000000000000000000000000) // selector for `ZeroAddressNotSupported()`
                revert(ptr, 0x4)
            }
        }
    }
}
