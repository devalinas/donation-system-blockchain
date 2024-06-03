// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title DistributionTypes library
/// @notice The special library for distribution manager that keeps structure with configuration data
library DistributionTypes {
  /// @notice The structure which describes asset config
  /// @dev It is used for saving data about the asset config
  /// @param emissionPerSecond The value of the emissions per second
  /// @param totalStaked The general staked amount
  /// @param underlyingAsset The address of the staking contract
  struct AssetConfigInput {
    uint128 emissionPerSecond;
    uint256 totalStaked;
    address underlyingAsset;
  }

  /// @notice The structure which describes stakes by an user
  /// @dev It is used for saving data about the user's staked tokens
  /// @param underlyingAsset The address of the staking contract
  /// @param stakedByUser The staked user's amount
  /// @param totalStaked The general staked amount
  struct UserStakeInput {
    address underlyingAsset;
    uint256 stakedByUser;
    uint256 totalStaked;
  }
}