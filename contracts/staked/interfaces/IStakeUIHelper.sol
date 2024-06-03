// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title IStakeUIHelper interface
/// @notice The designed interface for contract to get the user's info about tokens
interface IStakeUIHelper {
  /// @notice The structure which describes general and user's data for UI
  /// @dev It is used for saving general and user's data for UI
  /// @param stakeTokenTotalSupply The total supply from staking contract
  /// @param stakeCooldownSeconds The value of cooldown seconds from staking
  /// @param stakeUnstakeWindow The value of unstake window from staking
  /// @param stakeApy The value of the calculated APY
  /// @param distributionPerSecond The value of the distribution per second
  /// @param distributionEnd The value of the end distribution from staking
  /// @param stakeTokenUserBalance The user's balance on the staking contract
  /// @param generalStakedAmountByUser The general staked amount by a certain user
  /// @param underlyingTokenUserBalance The user's balance on the token contract
  /// @param userCooldown The value of cooldown seconds for user
  /// @param userIncentivesToClaim The value of user's rewards for claim
  struct AssetUIData {
    uint256 stakeTokenTotalSupply;
    uint256 stakeCooldownSeconds;
    uint256 stakeUnstakeWindow;
    uint256 stakeApy;
    uint128 distributionPerSecond;
    uint256 distributionEnd;
    uint256 stakeTokenUserBalance;
    uint256 generalStakedAmountByUser;
    uint256 underlyingTokenUserBalance;
    uint256 userCooldown;
    uint256 userIncentivesToClaim;
  }

  /// @dev Shows all user's info about staked WETH tokens
  /// @param user The address of the user for get user's data
  /// @return The user's data about values of the staked WETH tokens
  function getUserUIData(address user) external view returns (AssetUIData memory);
}
