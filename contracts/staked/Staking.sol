// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./interfaces/IStaking.sol";
import "./DistributionManager.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/// @title Staking contract
/// @notice The contract to stake WETH tokens, tokenize the position and get rewards (CoinBoxToken), 
/// inheriting from a distribution manager contract
contract Staking is IStaking, DistributionManager, ERC20Upgradeable, OwnableUpgradeable {
  using SafeERC20 for IERC20;

  /// @dev The name of the staking contract
  string internal constant NAME = 'Donate staking';
  /// @dev The symbol of the staking contract
  string internal constant SYMBOL = 'stkWETH';

  /// @notice The token's address for stakes (WETH)
  address public STAKED_TOKEN;
  /// @notice The token's address for rewards (CoinBoxToken)
  address public REWARD_TOKEN;
  /// @notice The address to pull from the rewards
  /// @dev Needs to have approved this contract
  address public REWARDS_VAULT;
  /// @notice The general value of cooldown seconds for staking
  uint256 public COOLDOWN_SECONDS;
  /// @notice The seconds available to redeem once the cooldown period is fulfilled
  uint256 public UNSTAKE_WINDOW;

  /// @notice Keeps the information about available rewards for the user
  /// @dev It is used for saving data about user's rewards
  mapping(address => uint256) public stakerRewardsToClaim;
  /// @notice Keeps the data re staked amount by the certain user
  /// @dev This information uses for illustrate the role of user in staking
  mapping(address => uint256) public stakedAmount;
  /// @notice Keeps the information about available cooldown seconds for an user
  /// @dev It is used for saving data about user's cooldown seconds
  mapping(address => uint256) public stakersCooldowns;

  /// @dev The custom error is triggered when the amount is zero 
  error InvalidAmount();

  /// @dev Initialize function: sets config's data for the staking contract.
  /// Called by the proxy contract
  /// @param stakedToken The token's address for stakes (WETH)
  /// @param rewardToken The token's address for rewards (CoinBoxToken)
  /// @param cooldownSeconds The value of cooldown seconds for staking
  /// @param unstakeWindow The value of unstake window for staking
  /// @param rewardsVault The vault's address from which reward tokens will be sent
  /// @param emissionManager The address of emission manager
  /// @param distributionDuration The value of distribution duration for calculate end
  function initialize(
    address stakedToken,
    address rewardToken,
    uint256 cooldownSeconds,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    uint128 distributionDuration
  ) external initializer {
    if(
        stakedToken == address(0) || 
        rewardToken == address(0) || 
        rewardsVault == address(0)
    ) revert InvalidAddress();
    if(cooldownSeconds == 0 || unstakeWindow == 0) 
        revert InvalidAmount();

    __ERC20_init(NAME, SYMBOL);
    __Ownable_init(msg.sender);
    __DistributionManager_init(emissionManager, distributionDuration);

    STAKED_TOKEN = stakedToken;
    REWARD_TOKEN = rewardToken;
    COOLDOWN_SECONDS = cooldownSeconds;
    UNSTAKE_WINDOW = unstakeWindow;
    REWARDS_VAULT = rewardsVault;
  }

  /// @notice Stakes WETH tokens by the `msg.sender`
  /// @param amount The amount to stake
  function stake(uint256 amount) external override {
    if(amount == 0) revert InvalidAmount();
    uint256 balanceOfUser = balanceOf(msg.sender);

    uint256 accruedRewards =
      _updateUserAssetInternal(msg.sender, address(this), balanceOfUser, totalSupply());
    if (accruedRewards != 0) {
      emit RewardsAccrued(msg.sender, accruedRewards);
      stakerRewardsToClaim[msg.sender] += accruedRewards;
    }

    stakersCooldowns[msg.sender] = getNextCooldownTimestamp(0, amount, msg.sender, balanceOfUser);

    _mint(msg.sender, amount);
    IERC20(STAKED_TOKEN).safeTransferFrom(msg.sender, address(this), amount);
    stakedAmount[msg.sender] += amount;

    emit Staked(msg.sender, amount);
  }

  /// @notice Activates the cooldown period to unstake.
  /// It can't be called if the user is not staking
  function cooldown() external override {
    require(balanceOf(msg.sender) != 0, "INVALID_BALANCE_ON_COOLDOWN");
    //solium-disable-next-line
    stakersCooldowns[msg.sender] = block.timestamp;

    emit Cooldown(msg.sender);
  }

  /// @dev Claims an `amount` of `REWARD_TOKEN`
  /// @param amount The amount to claim
  function claimRewards(uint256 amount) external override {
    if(amount == 0) revert InvalidAmount();

    uint256 cooldownStartTimestamp = stakersCooldowns[msg.sender];

    require(
      block.timestamp > cooldownStartTimestamp + COOLDOWN_SECONDS,
      'INSUFFICIENT_COOLDOWN'
    );
    require(
      block.timestamp - cooldownStartTimestamp + COOLDOWN_SECONDS <= UNSTAKE_WINDOW,
      'UNSTAKE_WINDOW_FINISHED'
    );
    
    uint256 newTotalRewards =
      _updateCurrentUnclaimedRewards(msg.sender, balanceOf(msg.sender), true);
    uint256 amountToClaim = (amount > newTotalRewards) ? newTotalRewards : amount;
    
    stakerRewardsToClaim[msg.sender] = newTotalRewards - amountToClaim;

    IERC20(REWARD_TOKEN).safeTransferFrom(REWARDS_VAULT, msg.sender, amountToClaim);

    if (stakerRewardsToClaim[msg.sender] == 0) {
      stakersCooldowns[msg.sender] = 0;
    }

    emit RewardsClaimed(msg.sender, amountToClaim);
  }

  /// @notice Redeems the staked tokens by an owner
  /// @param amount The amount to redeem
  function redeem(uint256 amount) external override onlyOwner {
    if(amount == 0) revert InvalidAmount();

    uint256 balanceOfStaking = IERC20(STAKED_TOKEN).balanceOf(address(this));
    uint256 amountToRedeem = (amount > balanceOfStaking) ? balanceOfStaking : amount;

    IERC20(STAKED_TOKEN).safeTransfer(msg.sender, amountToRedeem);

    emit Redeem(msg.sender, amountToRedeem);
  }

  /// @notice Returns the total rewards pending to claim by an staker
  /// @param staker The staker address
  /// @return The rewards
  function getTotalRewardsBalance(address staker) external view override returns (uint256) {
    DistributionTypes.UserStakeInput[] memory userStakeInputs =
      new DistributionTypes.UserStakeInput[](1);
    
    userStakeInputs[0] = DistributionTypes.UserStakeInput({
      underlyingAsset: address(this),
      stakedByUser: balanceOf(staker),
      totalStaked: totalSupply()
    });
    
    return stakerRewardsToClaim[staker] + _getUnclaimedRewards(staker, userStakeInputs);
  }

  /// @dev Calculates the how is gonna be a new cooldown timestamp depending on the sender/receiver situation
  ///  - If the timestamp of the sender is "better" or the timestamp of the recipient is 0, we take the one of the recipient
  ///  - Weighted average of from/to cooldown timestamps if:
  ///    # The sender doesn't have the cooldown activated (timestamp 0).
  ///    # The sender timestamp is expired
  ///    # The sender has a "worse" timestamp
  ///  - If the receiver's cooldown timestamp expired (too old), the next is 0
  /// @param fromCooldownTimestamp The cooldown timestamp of the sender
  /// @param amountToReceive The amount
  /// @param toAddress The address of the recipient
  /// @param toBalance The current balance of the receiver
  /// @return The new cooldown timestamp
  function getNextCooldownTimestamp(
    uint256 fromCooldownTimestamp,
    uint256 amountToReceive,
    address toAddress,
    uint256 toBalance
  ) public view returns (uint256) {
    uint256 toCooldownTimestamp = stakersCooldowns[toAddress];
    if (toCooldownTimestamp == 0) return 0;

    uint256 minimalValidCooldownTimestamp =
      block.timestamp - COOLDOWN_SECONDS - UNSTAKE_WINDOW;

    if (minimalValidCooldownTimestamp > toCooldownTimestamp) {
      toCooldownTimestamp = 0;
    } else {
      fromCooldownTimestamp =
        (minimalValidCooldownTimestamp > fromCooldownTimestamp)
          ? block.timestamp
          : fromCooldownTimestamp;

      if (fromCooldownTimestamp < toCooldownTimestamp) {
        return toCooldownTimestamp;
      } else {
        toCooldownTimestamp = (
          amountToReceive * fromCooldownTimestamp + (toBalance * toCooldownTimestamp)
        ) / (amountToReceive + toBalance);
      }
    }

    return toCooldownTimestamp;
  }

  /// @dev Internal ERC20 _transfer of the tokenized staked tokens
  /// @param from The address to transfer from
  /// @param to The address to transfer to
  /// @param amount The amount to transfer
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    if(from == address(0) || to == address(0)) revert InvalidAddress();
    if(amount == 0) revert InvalidAmount();
    
    uint256 balanceOfFrom = balanceOf(from);
    // Sender
    _updateCurrentUnclaimedRewards(from, balanceOfFrom, true);

    // Recipient
    if (from != to) {
      uint256 balanceOfTo = balanceOf(to);
      _updateCurrentUnclaimedRewards(to, balanceOfTo, true);

      uint256 previousSenderCooldown = stakersCooldowns[from];
      stakersCooldowns[to] = getNextCooldownTimestamp(
        previousSenderCooldown,
        amount,
        to,
        balanceOfTo
      );
      // if cooldown was set and whole balance of sender was transferred - clear cooldown
      if (balanceOfFrom == amount && previousSenderCooldown != 0) {
        stakersCooldowns[from] = 0;
      }
    }

    super._transfer(from, to, amount);
  }

  /// @dev Updates the user's state related with his accrued rewards
  /// @param user The address of the user
  /// @param userBalance The current balance of the user
  /// @param updateStorage Boolean flag used to update or not the `stakerRewardsToClaim` of the user
  /// @return The unclaimed rewards that were added to the total accrued
  function _updateCurrentUnclaimedRewards(
    address user,
    uint256 userBalance,
    bool updateStorage
  ) internal returns (uint256) {
    uint256 accruedRewards =
      _updateUserAssetInternal(user, address(this), userBalance, totalSupply());
    uint256 unclaimedRewards = stakerRewardsToClaim[user] + accruedRewards;

    if (accruedRewards != 0) {
      if (updateStorage) {
        stakerRewardsToClaim[user] = unclaimedRewards;
      }
      emit RewardsAccrued(user, accruedRewards);
    }

    return unclaimedRewards;
  }
}