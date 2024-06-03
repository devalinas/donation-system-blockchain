import { ethers } from 'hardhat';
import { CoinBoxToken } from '../../typechain-types';
import { OWNER, ROUTER } from '../helpers/constants';


async function main() {
  console.log('Deploying process: CoinBoxToken ------>');
  const CoinBoxTokenImpl = await (await ethers.getContractFactory('CoinBoxToken')).deploy();
  const CBTokenEncodedInitialize = CoinBoxTokenImpl.interface.encodeFunctionData('initialize', [
      ROUTER,
      OWNER
  ]);
  const CBTokenProxy = await (await ethers.getContractFactory('CoinBoxProxy')).deploy(
      CoinBoxTokenImpl.target , OWNER, CBTokenEncodedInitialize
  );
  const CBToken = CoinBoxTokenImpl.attach(CBTokenProxy.target) as CoinBoxToken;
  console.log('CoinBoxToken implementation address: %s', CoinBoxTokenImpl.target);
  console.log('CoinBoxToken Proxy address: %s', CBToken.target);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
