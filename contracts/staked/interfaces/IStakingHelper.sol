 // SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IStakingHelper interface
/// @notice The interface to SC that responsible for staking CBT tokens, tokenize the position and get rewards
/// @dev The interface uses to receive correct data from SC on the front end part
interface IStakingHelper {
  /// @notice The structure which describes asset data
  /// @dev It is used for saving data about the asset config by front end part
  /// @param emissionPerSecond The value of the emissions per second
  /// @param lastUpdateTimestamp The last moment distribution was updated
  /// @param index The current index of the distribution
  struct AssetData {
    uint128 emissionPerSecond;
    uint128 lastUpdateTimestamp;
    uint256 index;
  }

  /// @notice Shows the value of the total supply in the contract
  /// @return The value of the total supply
  function totalSupply() external view returns (uint256);

  /// @notice Receives the general cooldown period to redeem
  /// @return The value of the available seconds to redeem
  function COOLDOWN_SECONDS() external view returns (uint256);

  /// @notice Shows the available seconds to redeem once the cooldown period is fullfilled
  /// @return The value of the available seconds
  function UNSTAKE_WINDOW() external view returns (uint256);

  /// @notice Shows the value of the distribution end in the staking contract
  /// @return The value of the distribution end
  function DISTRIBUTION_END() external view returns (uint256);

  /// @notice Shows the data about asset
  /// @param asset The address of the asset for gets data
  /// @return The structure with asset's data
  function assets(address asset) external view returns (AssetData memory);

  /// @notice Shows the balance of the user
  /// @param user The address of the user for gets data about available balance
  /// @return The amount of the user's balance
  function balanceOf(address user) external view returns (uint256);

  /// @notice Shows the available reward's amount for the user
  /// @param user The address of the user for gets data about available rewards
  /// @return The amount of the rewards
  function getTotalRewardsBalance(address user) external view returns (uint256);

  /// @notice Shows the available cooldown seconds to redeem for the user
  /// @param user The address of the user for receives data about cooldown seconds
  /// @return The value of the available cooldown period for the user's address
  function stakersCooldowns(address user) external view returns (uint256);

  /// @notice Receives the general staked amount by a certain user
  /// @param user The address of user for receive correct data
  /// @return The value of staked amount
  function stakedAmount(address user) external view returns (uint256);
}