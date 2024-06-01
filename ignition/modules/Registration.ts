import { ethers } from 'hardhat';
import { Registration } from '../../typechain-types';

const OWNER = '0xba4196B4e04D73530baE835509aDcE0f54Aca3CD';

async function main() {
  console.log('Deploying process: Registration system ------>');
  const RegistrationImpl = await (await ethers.getContractFactory('Registration')).deploy();
  const RegistrationEncodedInitialize = RegistrationImpl.interface.encodeFunctionData('initialize', []);
  const RegistrationProxy = await (await ethers.getContractFactory('CoinBoxProxy')).deploy(
      RegistrationImpl.target , OWNER, RegistrationEncodedInitialize
  );
  const registry = RegistrationImpl.attach(RegistrationProxy.target) as Registration;
  console.log('Registration implementation address: %s', RegistrationImpl.target);
  console.log('Registration Proxy address: %s', registry.target);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
