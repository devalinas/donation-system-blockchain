import { ethers } from 'hardhat';
import { CoinBoxToken } from '../../typechain-types';

const ROUTER = '0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008';
const OWNER = '0xba4196B4e04D73530baE835509aDcE0f54Aca3CD';

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
