import { ethers } from 'hardhat';

async function main() {
  console.log('Deploying process: Assets ------>');
  
  const BinanceCoin = await (await ethers.getContractFactory('BinanceCoin')).deploy();
  const Bitcoin = await (await ethers.getContractFactory('Bitcoin')).deploy();
  const Ethereum = await (await ethers.getContractFactory('Ethereum')).deploy();
  const Solana = await (await ethers.getContractFactory('Solana')).deploy();
  const Toncoin = await (await ethers.getContractFactory('Toncoin')).deploy();
  
  console.log('BinanceCoin address: %s', BinanceCoin.target);
  console.log('Bitcoin address: %s', Bitcoin.target);
  console.log('Ethereum address: %s', Ethereum.target);
  console.log('Solana address: %s', Solana.target);
  console.log('Toncoin address: %s', Toncoin.target);
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
