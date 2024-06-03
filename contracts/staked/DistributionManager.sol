// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./lib/DistributionTypes.sol";
import "./interfaces/IDistributionManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title DistributionManager smart contract
/// @notice The accounting contract to manage multiple staking distributions
contract DistributionManager is IDistributionManager, Initializable {

  /// @notice The value of precision for calculates in formulas
  uint256 public constant PRECISION = 18;
  
  /// @notice The value of distribution end
  /// @dev It is used for save the calculated distribution end
  /// now + distribution duration
  uint256 public DISTRIBUTION_END;
  
  /// @notice The address of emission manager
  address public EMISSION_MANAGER;

  /// @notice Keeps the information about the user's assets
  /// @dev It is used for saving data about the asset config for the user
  mapping(address => AssetData) public assets;

  /// @dev The custom error is triggered when the input address of manager is zero 
  error InvalidAddress();
  /// @dev The custom error is triggered when the set distribution duration is zero 
  error InvalidDuration();

  /// @notice Initialize function: sets emission manager and distribution end.
  /// Called by the proxy contract
  /// @param emissionManager The address of emission manager
  /// @param distributionDuration The value of distribution duration for calculate end
  function __DistributionManager_init(address emissionManager, uint256 distributionDuration)
    public
    initializer
  {
    if(emissionManager == address(0)) revert InvalidAddress();
    if(distributionDuration == 0) revert InvalidDuration();
    
    DISTRIBUTION_END = block.timestamp + distributionDuration;
    EMISSION_MANAGER = emissionManager;
  }

  /// @notice Configures the distribution of rewards for a list of assets
  /// @param assetsConfigInput The list of configurations to apply
  function configureAssets(DistributionTypes.AssetConfigInput[] calldata assetsConfigInput)
    external
    override
  {
    require(msg.sender == EMISSION_MANAGER, "ONLY_EMISSION_MANAGER");

    for (uint256 i; i < assetsConfigInput.length;) {
      AssetData storage assetConfig = assets[assetsConfigInput[i].underlyingAsset];

      _updateAssetStateInternal(
        assetsConfigInput[i].underlyingAsset,
        assetConfig,
        assetsConfigInput[i].totalStaked
      );

      assetConfig.emissionPerSecond = assetsConfigInput[i].emissionPerSecond;

      emit AssetConfigUpdated(
        assetsConfigInput[i].underlyingAsset,
        assetsConfigInput[i].emissionPerSecond
      );

      i++;
    }
  }

  /// @notice Returns the data of an user on a distribution
  /// @param user The address of the user
  /// @param asset The address of the reference asset of the distribution
  /// @return The new index
  function getUserAssetData(address user, address asset) external view override returns (uint256) {
    return assets[asset].users[user];
  }

  /// @dev Updates the state of one distribution, mainly rewards index and timestamp
  /// @param underlyingAsset The address used as key in the distribution
  /// @param assetConfig The storage pointer to the distribution's config
  /// @param totalStaked The current total of staked assets for this distribution
  /// @return The new distribution index
  function _updateAssetStateInternal(
    address underlyingAsset,
    AssetData storage assetConfig,
    uint256 totalStaked
  ) internal returns (uint256) {
    uint256 oldIndex = assetConfig.index;
    uint128 lastUpdateTimestamp = assetConfig.lastUpdateTimestamp;

    if (block.timestamp == lastUpdateTimestamp) {
      return oldIndex;
    }

    uint256 newIndex =
      _getAssetIndex(oldIndex, assetConfig.emissionPerSecond, lastUpdateTimestamp, totalStaked);

    if (newIndex != oldIndex) {
      assetConfig.index = newIndex;
      emit AssetIndexUpdated(underlyingAsset, newIndex);
    }

    assetConfig.lastUpdateTimestamp = uint128(block.timestamp);

    return newIndex;
  }

  /// @dev Updates the state of an user in a distribution
  /// @param user The user's address
  /// @param asset The address of the reference asset of the distribution
  /// @param stakedByUser The amount of tokens staked by the user in the distribution at the moment
  /// @param totalStaked The total tokens staked in the distribution
  /// @return The accrued rewards for the user until the moment
  function _updateUserAssetInternal(
    address user,
    address asset,
    uint256 stakedByUser,
    uint256 totalStaked
  ) internal returns (uint256) {
    AssetData storage assetData = assets[asset];
    uint256 userIndex = assetData.users[user];
    uint256 accruedRewards;

    uint256 newIndex = _updateAssetStateInternal(asset, assetData, totalStaked);

    if (userIndex != newIndex) {
      if (stakedByUser != 0) {
        accruedRewards = _getRewards(stakedByUser, newIndex, userIndex);
      }

      assetData.users[user] = newIndex;
      emit UserIndexUpdated(user, asset, newIndex);
    }

    return accruedRewards;
  }

  /// @dev Used by "frontend" stake contracts to update the data of an user when claiming rewards from there
  /// @param user The address of the user
  /// @param stakes The list of structs of the user data related with his stake
  /// @return The accrued rewards for the user until the moment
  function _claimRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    returns (uint256)
  {
    uint256 accruedRewards;

    for (uint256 i; i < stakes.length;) {
      accruedRewards = accruedRewards + (
        _updateUserAssetInternal(
          user,
          stakes[i].underlyingAsset,
          stakes[i].stakedByUser,
          stakes[i].totalStaked
        )
      );
      i++;
    }

    return accruedRewards;
  }

  /// @dev Returns the accrued rewards for an user over a list of distribution
  /// @param user The address of the user
  /// @param stakes The list of structs of the user data related with his stake
  /// @return The accrued rewards for the user until the moment
  function _getUnclaimedRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    view
    returns (uint256)
  {
    uint256 accruedRewards;

    for (uint256 i; i < stakes.length;) {
      AssetData storage assetConfig = assets[stakes[i].underlyingAsset];
      uint256 assetIndex =
        _getAssetIndex(
          assetConfig.index,
          assetConfig.emissionPerSecond,
          assetConfig.lastUpdateTimestamp,
          stakes[i].totalStaked
        );

      accruedRewards = accruedRewards + (
        _getRewards(stakes[i].stakedByUser, assetIndex, assetConfig.users[user])
      );

      i++;
    }
    return accruedRewards;
  }

  /// @dev Calculates the next value of an specific distribution index with validations
  /// @param currentIndex The current index of the distribution
  /// @param emissionPerSecond The total rewards distributed per second per asset unit on the distribution
  /// @param lastUpdateTimestamp The last moment this distribution was updated
  /// @param totalBalance The tokens considered for the distribution
  /// @return The new index
  function _getAssetIndex(
    uint256 currentIndex,
    uint256 emissionPerSecond,
    uint128 lastUpdateTimestamp,
    uint256 totalBalance
  ) internal view returns (uint256) {
    if (
      emissionPerSecond == 0 ||
      totalBalance == 0 ||
      lastUpdateTimestamp == block.timestamp ||
      lastUpdateTimestamp >= DISTRIBUTION_END
    ) {
      return currentIndex;
    }

    uint256 currentTimestamp =
      block.timestamp > DISTRIBUTION_END ? DISTRIBUTION_END : block.timestamp;
    uint256 timeDelta = currentTimestamp - lastUpdateTimestamp;
    return (emissionPerSecond * timeDelta * 10**PRECISION / totalBalance) + currentIndex;
  }

  /// @dev Internal function for calculation of the user's rewards on a distribution
  /// @param principalUserBalance The amount staked by the user on a distribution
  /// @param reserveIndex The current index of the distribution
  /// @param userIndex The index stored for the user, representation his staking moment
  /// @return The rewards
  function _getRewards(
    uint256 principalUserBalance,
    uint256 reserveIndex,
    uint256 userIndex
  ) internal pure returns (uint256) {
    return principalUserBalance * (reserveIndex - userIndex) / 10**PRECISION;
  }
}