// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../lib/DistributionTypes.sol";

/// @title IDistributionManager interface
/// @notice The interface for the smart contract to manage multiple staking distributions
interface IDistributionManager {
  /// @notice The structure which describes asset data
  /// @dev It is used for saving data about the asset config
  /// @param emissionPerSecond The value of emissions per second
  /// @param lastUpdateTimestamp The last moment distribution was updated
  /// @param index The current index of the distribution
  /// @param users The mapping that returns the index of an user on a distribution
  struct AssetData {
    uint128 emissionPerSecond;
    uint128 lastUpdateTimestamp;
    uint256 index;
    mapping(address => uint256) users;
  }

  /// @notice It is generated when configures the distribution of rewards
  /// @param asset The asset's address for configures
  /// @param emission The value of the emissions per second
  event AssetConfigUpdated(address indexed asset, uint256 emission);

  /// @notice It is generated when the asset's index was updated
  /// @param asset The asset's address for update index
  /// @param index The updated distribution index
  event AssetIndexUpdated(address indexed asset, uint256 index);

  /// @notice It is generated when the user's index was updated
  /// @param user The address of the user for update index
  /// @param asset The address of the reference asset of the distribution
  /// @param index The updated distribution index for the user
  event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);

  /// @notice Configures the distribution of rewards for a list of assets
  /// @param assetsConfigInput The list of configurations to apply
  function configureAssets(DistributionTypes.AssetConfigInput[] calldata assetsConfigInput)
    external;

  /// @notice Returns the data of an user on a distribution
  /// @param user The address of the user
  /// @param asset The address of the reference asset of the distribution
  /// @return The new index
  function getUserAssetData(address user, address asset) external view returns (uint256);
}