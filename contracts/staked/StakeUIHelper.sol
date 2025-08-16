// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./interfaces/IStakeUIHelper.sol";
import "./interfaces/IStakingHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title StakeUIHelper contract
/// @notice The contract for get the user's info about tokens
contract StakeUIHelper is IStakeUIHelper {

    /// @notice The address of the WETH token
    address public immutable WETH;
    /// @notice The address of the Staking contract
    IStakingHelper public immutable STAKED_WETH;

    /// @dev The value of the year in seconds
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    /// @dev The value of the precision: 10 000 - 100%
    uint256 internal constant PRECISION = 10_000;
    
    /// @dev Constructor: initialize contract
    /// @param weth The address of the WETH token
    /// @param stkWeth The address of the CBStaking contract
    constructor(address weth, address stkWeth) {
        if(weth == address(0) || stkWeth == address(0)) 
            revert ("InvalidAddress");
        
        WETH = weth;
        STAKED_WETH = IStakingHelper(stkWeth);
    }

    /// @notice Receives all user's info about staked tokens
    /// @param user The address of the user for get user's data
    /// @return User's data about values of the staked weth tokens
    function getUserUIData(address user)
        external
        view
        override
        returns (AssetUIData memory)
    {
        AssetUIData memory data = _getStakedAssetData(
            STAKED_WETH,
            WETH,
            user
        );

        data.stakeApy = _calculateApy(
            data.distributionPerSecond,
            data.stakeTokenTotalSupply
        );
        return data;
    }

    /// @dev Receives all user's staked asset data
    /// @param stakeToken The address of the staking contract
    /// @param underlyingToken The address of the WETH token
    /// @param user The address of the user for get user's data
    /// @return User's data about values of the staked tokens and time frame
    function _getStakedAssetData(
        IStakingHelper stakeToken,
        address underlyingToken,
        address user
    ) internal view returns (AssetUIData memory) {
        AssetUIData memory data;

        data.stakeTokenTotalSupply = stakeToken.totalSupply();
        data.stakeCooldownSeconds = stakeToken.COOLDOWN_SECONDS();
        data.stakeUnstakeWindow = stakeToken.UNSTAKE_WINDOW();
        data.distributionEnd = stakeToken.DISTRIBUTION_END();
        if (block.timestamp < data.distributionEnd) {
            data.distributionPerSecond = stakeToken
                .assets(address(stakeToken))
                .emissionPerSecond;
        }

        if (user != address(0)) {
            data.generalStakedAmountByUser = stakeToken.stakedAmount(user);
            data.underlyingTokenUserBalance = IERC20(underlyingToken).balanceOf(
                user
            );
            data.stakeTokenUserBalance = stakeToken.balanceOf(user);
            data.userIncentivesToClaim = stakeToken.getTotalRewardsBalance(
                user
            );
            data.userCooldown = stakeToken.stakersCooldowns(user);
        }
        return data;
    }

    /// @dev Receives the result from calculation APY
    /// @param distributionPerSecond The value of the distribution tokens per seconds
    /// @param stakeTokenTotalSupply The value of the token's total supply
    /// @return The calculated APY
    function _calculateApy(
        uint256 distributionPerSecond,
        uint256 stakeTokenTotalSupply
    ) internal pure returns (uint256) {
        return
            distributionPerSecond * SECONDS_PER_YEAR * PRECISION / stakeTokenTotalSupply;
    }
}