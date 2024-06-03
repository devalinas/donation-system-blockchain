// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IStaking interface
/// @notice The interface to SC that responsible for staking CBT tokens, tokenize the position and get rewards
interface IStaking {
  /// @notice This event is triggered whenether an user stakes tokens
  /// @param from The address from whose balance tokens will be sent and the staking is being executed
  /// @param amount The amount to stake
  event Staked(address indexed from, uint256 amount);

  /// @notice It is generated when accrued rewards for an user
  /// @param user The user's address for accrued rewards
  /// @param amount The reward's amount for user
  event RewardsAccrued(address indexed user, uint256 amount);

  /// @notice This event is triggered whenether an user claims rewards
  /// @param to The address to claim rewards to
  /// @param amount The reward's amount for claim
  event RewardsClaimed(address indexed to, uint256 amount);

  /// @notice It is generated when user activates the cooldown period to redeem
  /// @param user The user's address for activate
  event Cooldown(address indexed user);

  /// @notice Stakes WETH tokens by the `msg.sender`
  /// @param amount The amount to stake
  function stake(uint256 amount) external;

  /// @notice Activates the cooldown period to unstake
  /// It can't be called if the user is not in staking
  function cooldown() external;

  /// @dev Claims an `amount` of `REWARD_TOKEN` to the address `to`
  /// @param amount Amount to stake
  function claimRewards(uint256 amount) external;

  /// @dev Return the total rewards pending to claim by an staker
  /// @param staker The staker address
  /// @return The rewards
  function getTotalRewardsBalance(address staker) external view returns (uint256);
}