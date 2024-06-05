import { ethers } from 'hardhat';
import { Staking } from '../../typechain-types';
import { COOLDOWN_SECONDS, CoinBoxToken, DISTRIBUTION_DURATION, OWNER, UNSTAKE_WINDOW, WETH } from '../helpers/constants';

async function main() {
  console.log('Deploying process: Staking system ------>');
  const StakingImpl = await (await ethers.getContractFactory('Staking')).deploy();

  const StakingEncodedInitialize = StakingImpl.interface.encodeFunctionData('initialize', [
    WETH, CoinBoxToken, COOLDOWN_SECONDS, UNSTAKE_WINDOW, OWNER, OWNER, DISTRIBUTION_DURATION
  ]);
  const StakingProxy = await (await ethers.getContractFactory('CoinBoxProxy')).deploy(
    StakingImpl.target , OWNER, StakingEncodedInitialize
  );
  const staking = StakingImpl.attach(StakingProxy) as Staking;
  
  console.log('Staking implementation address: %s', StakingImpl.target);
  console.log('Staking Proxy address: %s', StakingProxy.target);

  const stakingUI = await (await ethers.getContractFactory('StakeUIHelper')).deploy(WETH, staking.target);
  console.log('Staking UI Helper implementation address: %s', stakingUI.target);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
