import { ethers } from 'hardhat';
import { expect } from 'chai';
import { loadFixture, time } from '@nomicfoundation/hardhat-network-helpers';
import { CoinBoxToken } from '../typechain-types';
import { days } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time/duration';
import * as IWETH from '../artifacts/contracts/token/mock/IWETH.sol/IWETH.json';
import * as IUniswapV2Router02 from '../artifacts/contracts/token/interfaces/IUniswapV2Router02.sol/IUniswapV2Router02.json'

const ROUTER_1 = '0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008';
const ROUTER_2 = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

describe('CoinBoxToken', async () => {
    const zeroAddress = ethers.ZeroAddress;
    const maxUINT256 = ethers.MaxUint256;
    const _tTotal : bigint = BigInt(600) * BigInt(10 ** 6) * BigInt(10 ** 18);
    let _rTotal = maxUINT256 - (maxUINT256 % _tTotal);

    function calculateValues(fee : bigint, amount : bigint, rTotal : bigint) {
        const tFee = amount * fee / BigInt(100);
        const tLiquidity = amount * fee / BigInt(100);
        const tTransferAmount = amount - tFee - tLiquidity;
        const currentRate = rTotal / _tTotal;
        const rAmount = amount * currentRate;
        const rFee = tFee * currentRate;
        const rLiquidity = tLiquidity * currentRate;
        const rTransferAmount = rAmount - rFee - rLiquidity;
       
        return { tFee, tLiquidity, tTransferAmount, currentRate, rAmount, rFee, rLiquidity, rTransferAmount };
    };

    async function deployFixture() {
        const [owner, user1, user2] = await ethers.getSigners();
        
        const CoinBoxTokenImpl = await (await ethers.getContractFactory('CoinBoxToken')).deploy();
        const CBTokenEncodedInitialize = CoinBoxTokenImpl.interface.encodeFunctionData('initialize', [
           ROUTER_1,
           owner.address
        ]);
        const CBTokenProxy = await (await ethers.getContractFactory('CoinBoxProxy')).deploy(
            CoinBoxTokenImpl.target , owner.address, CBTokenEncodedInitialize
        );
        const CBToken = CoinBoxTokenImpl.attach(CBTokenProxy.target) as CoinBoxToken;

        return { CBToken, owner, user1, user2 };
    };

    describe('CoinBoxToken Initializing Phase Test Cases', async () => {
        it('should set the router correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.uniswapV2Router()).to.be.equal(ROUTER_1);
        });

        it('should set an owner correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            expect(await CBToken.owner()).to.be.equal(owner.address);
        });

        it('should get balance of owner correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);         
            let currentRate = BigInt(_rTotal) / BigInt(_tTotal);
            let balanceOwner = BigInt(_rTotal) / BigInt(currentRate);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceOwner);
            expect(await CBToken.balanceOf(owner.address))
                .to.be.emit(CBToken, 'Transfer').withArgs(zeroAddress, owner.address, balanceOwner);
        });

        it('should exclude from fee correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            expect(await CBToken.isExcludedFromFee(owner.address)).to.be.equal(true);
            expect(await CBToken.isExcludedFromFee(CBToken.target)).to.be.equal(true);
        });

        it('should set _maxTxAmount correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.maxTxAmount()).to.be.equal(_tTotal);
        });

        it('should set swap fee correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect((await CBToken.swapFee())._liquidityFee).to.be.equal(5);
            expect((await CBToken.swapFee())._taxFee).to.be.equal(0);
        });

        it('should set transfer fee correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect((await CBToken.transferFee())._liquidityFee).to.be.equal(2);
            expect((await CBToken.transferFee())._taxFee).to.be.equal(0);
        });

        it('should set swapAndLiquifyEnabled correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.swapAndLiquifyEnabled()).to.be.equal(true);
        });

        it('should set token\'s name correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.name()).to.be.equal("CoinBox Token");
        });

        it('should set token\'s symbol correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.symbol()).to.be.equal("CBT");
        });

        it('should set total supply correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.totalSupply()).to.be.equal(_tTotal);
        });

        it('should set decimals correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.decimals()).to.be.equal(18);
        });

        it('should revert if the input\'\'s addresses are zero\'\s', async () => {
            const [ owner ] = await ethers.getSigners();
            const token = await (await ethers.getContractFactory('CoinBoxToken')).deploy();
            await expect(token.initialize(zeroAddress, owner.address))
                .to.be.revertedWithCustomError(token, 'ZeroAddress()');
            await expect(token.initialize(ROUTER_1, zeroAddress))
                .to.be.revertedWithCustomError(token, 'ZeroAddress()');
        });

        it('should revert if an owner want to initialize a SC twice', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await expect(CBToken.initialize(ROUTER_1, owner.address))
                .to.be.revertedWithCustomError(CBToken, 'InvalidInitialization()');
        });
    });

    describe('CoinBoxToken Accessors Functions Phase Test Cases', function () {
        it('should set the threshold correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            expect(await CBToken.connect(owner).setThreshold(5000))
                .to.be.emit(CBToken, 'Threshold').withArgs(5000);
        });
        
        it('shouldn\'t set the threshold if a caller isn\'t an owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).setThreshold(5000)).to.be.reverted;
        });

        it('should deliver the tokens correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            const tAmount = ethers.parseEther("4");
            let currentRate = BigInt(_rTotal) / BigInt(_tTotal);
            const rAmount = BigInt(tAmount) / BigInt(currentRate);
            const _rOwned = BigInt(_rTotal) - BigInt(rAmount);
            currentRate = _rOwned / _tTotal;
            let balanceOwner = _rOwned / currentRate;
            expect(await CBToken.connect(owner).deliver(tAmount))
                .to.be.emit(CBToken, 'Deliver').withArgs(owner.address, _rOwned, _rOwned, tAmount);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceOwner);
            expect(await CBToken.totalFees()).to.be.equal(tAmount);
        });

        it('shouldn\'t deliver if an account isn\'t excluded', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            await CBToken.connect(owner).excludeFromReward(user1.address);
            await expect(CBToken.connect(user1).deliver(ethers.parseEther('4')))
                .to.be.revertedWithCustomError(CBToken, 'ExcludedAccount()');
        });

        it('should exclude an account from rewards without _rOwned correctly', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            expect(await CBToken.connect(owner).excludeFromReward(user1))
                .to.be.emit(CBToken, 'ExcludeFromReward').withArgs(user1.address, 0);
            expect(await CBToken.isExcludedFromReward(user1.address)).to.be.equal(true);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(0);
        });

        it('should exclude an account from rewards with _rOwned correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            const tAmount = ethers.parseEther('10');
            let currentRate = _rTotal / _tTotal;
            const rAmount = tAmount * currentRate;
            const _rOwned = _rTotal - rAmount;
            currentRate = _rOwned / _tTotal;
            const balanceOwner = _rOwned / currentRate;
            await CBToken.connect(owner).deliver(tAmount);
            expect(await CBToken.connect(owner).excludeFromReward(owner.address))
                .to.be.emit(CBToken, 'ExcludeFromReward').withArgs(owner.address, balanceOwner);
            expect(await CBToken.isExcludedFromReward(owner.address)).to.be.equal(true);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceOwner);
        });

        it('shouldn\'t exclude an account from rewards if an account isn\'t excluded', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            await CBToken.connect(owner).excludeFromReward(user1.address);
            await expect(CBToken.connect(owner).excludeFromReward(user1.address))
                .to.be.revertedWithCustomError(CBToken, 'ExcludedAccount()');
        });

        it('shouldn\'t exclude an account from rewards if a caller isn\'t an owner', async () => {
            const { CBToken, user1, user2 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).excludeFromReward(user2.address)).to.be.reverted;
        });

        it('shouldn\'t exclude an account from rewards if zero\'s address', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await expect(CBToken.connect(owner).excludeFromReward(zeroAddress))
                .to.be.revertedWithCustomError(CBToken, 'ZeroAddress()');
        });

        it('should include an account in rewards correctly', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            await CBToken.excludeFromReward(user1.address);
            await CBToken.excludeFromReward(owner.address);
            expect(await CBToken.includeInReward(owner.address))
                .to.be.emit(CBToken, 'IncludeInReward').withArgs(owner.address);
            expect(await CBToken.isExcludedFromReward(owner.address)).to.be.equal(false);
        });

        it('shouldn\'t include an account in rewards if an account is already excluded', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await expect(CBToken.includeInReward(owner.address))
                .to.be.revertedWithCustomError(CBToken, 'IncludedAccount()');
        });

        it('shouldn\'t include an account in rewards if zero\'s address', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await expect(CBToken.connect(owner).includeInReward(zeroAddress))
                .to.be.revertedWithCustomError(CBToken, 'ZeroAddress()');
        });

        it('shouldn\'t include an account in rewards if a caller isn\'t an owner', async () => {
            const { CBToken, user1, user2 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).includeInReward(user2.address)).to.be.reverted;
        });

        it('should set the transfer fee percents correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            expect(await CBToken.connect(owner).setTransferFeePercent(5, 10))
                .to.be.emit(CBToken, 'TranferFeePercents').withArgs(5, 10);
            expect((await CBToken.transferFee())._liquidityFee).to.be.equal(5);
            expect((await CBToken.transferFee())._taxFee).to.be.equal(10);
        });

        it('shouldn\'t set the transfer fee percents if the value more than 100', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await expect(CBToken.connect(owner).setTransferFeePercent(101, 1))
                .to.be.revertedWithCustomError(CBToken, 'ExceededValue()');
            await expect(CBToken.connect(owner).setTransferFeePercent(1, 10111))
                .to.be.revertedWithCustomError(CBToken, 'ExceededValue()');
        });

        it('shouldn\'t set the transfer fee percents if a caller isn\'t an owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).setTransferFeePercent(10, 0)).to.be.reverted;
        });

        it('should set the swap fee percents correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.setSwapFeePercent(10, 9)).to.be.emit(CBToken, 'SwapFeePercents').withArgs(10, 9);
            expect((await CBToken.swapFee())._liquidityFee).to.be.equal(10);
            expect((await CBToken.swapFee())._taxFee).to.be.equal(9);
        });

        it('shouldn\'t set the swap fee percents if the value more than 100', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            await expect(CBToken.setSwapFeePercent(101, 1)).to.be.revertedWithCustomError(CBToken, 'ExceededValue()');
            await expect(CBToken.setSwapFeePercent(11, 991)).to.be.revertedWithCustomError(CBToken, 'ExceededValue()');
        });

        it('shouldn\'t set the swap fee percents if a caller isn\'t an owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).setSwapFeePercent(10, 0)).to.be.reverted;
        });

        it('should set the max tx percent correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            const maxTx = BigInt(10);
            const maxTxAmount = _tTotal * maxTx / BigInt(100);
            expect(await CBToken.setMaxTxPercent(maxTx)).to.be.emit(CBToken, 'MaxTxPercent').withArgs(maxTxAmount);
            expect(await CBToken.maxTxAmount()).to.be.equal(maxTxAmount);
        });

        it('shouldn\'t set the max tx percent if the value more than 100', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            await expect(CBToken.setMaxTxPercent(101)).revertedWithCustomError(CBToken, 'ExceededValue()');
        });

        it('shouldn\'t set the max tx percent if a caller isn\'t an owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).setMaxTxPercent(10)).to.be.reverted;
        });

        it('should update the router correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.setRouter(ROUTER_2)).to.be.emit(CBToken, 'ChangeRouter').withArgs(ROUTER_2);
            expect(await CBToken.uniswapV2Router()).to.be.equal(ROUTER_2);
        });

        it('shouldn\'t update the router if zero\'s address', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            await expect(CBToken.setRouter(zeroAddress)).to.be.revertedWithCustomError(CBToken, 'ZeroAddress()');
        });

        it('shouldn\'t update the router if a caller isn\'t an owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).setRouter(ROUTER_2)).to.be.reverted;
        });

        it('should exclude an account from the fee correctly', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            expect(await CBToken.excludeFromFee(user1.address))
                .to.be.emit(CBToken, 'ExcludeFromFee').withArgs(user1.address, true);
            expect(await CBToken.isExcludedFromFee(user1.address)).to.be.equal(true);
        });

        it('shouldn\'t exclude an account from the fee if an account isn\'t excluded', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            await CBToken.connect(owner).excludeFromFee(user1.address);
            await expect(CBToken.connect(owner).excludeFromFee(user1.address))
                .to.be.revertedWithCustomError(CBToken, 'ExcludedAccount()');
        });

        it('shouldn\'t exclude an account from the fee if zero\'s address', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await expect(CBToken.connect(owner).excludeFromFee(zeroAddress))
                .to.be.revertedWithCustomError(CBToken, 'ZeroAddress()');
        });

        it('shouldn\'t exclude an account from the fee if a caller isn\'t an owner', async () => {
            const { CBToken, user1, user2 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).excludeFromFee(user2.address)).to.be.reverted;
        });

        it('should include an account in the fee correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            expect(await CBToken.includeInFee(owner.address))
                .to.be.emit(CBToken, 'IncludeInFee').withArgs(owner.address, false);
            expect(await CBToken.isExcludedFromFee(owner.address)).to.be.equal(false);
        });

        it('shouldn\'t include an account in the fee if an account is already included', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await CBToken.includeInFee(owner.address);
            await expect(CBToken.includeInFee(owner.address))
                .to.be.revertedWithCustomError(CBToken, 'IncludedAccount()');
        });

        it('shouldn\'t include an account in the fee if zero\'s address', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await expect(CBToken.connect(owner).includeInFee(zeroAddress))
                .to.be.revertedWithCustomError(CBToken, 'ZeroAddress()');
        });

        it('shouldn\'t include an account in the fee if a caller isn\'t an owner', async () => {
            const { CBToken, user1, user2 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).includeInFee(user2.address)).to.be.reverted;
        });

        it('should set enable for swap and liquify operation correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            expect(await CBToken.setSwapAndLiquifyEnabled(true))
                .to.be.emit(CBToken, 'SwapAndLiquifyEnabledUpdated').withArgs(true);
            expect(await CBToken.swapAndLiquifyEnabled()).to.be.equal(true);
        });

        it('shouldn\'t set enable for swap and liquify operation if a caller isn\'t an owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).setSwapAndLiquifyEnabled(true)).to.be.reverted;
        });

        it('should set the lock period correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            await CBToken.lock(days(1));
            let period = (await time.latest())+ days(1);
            expect(await CBToken.owner()).to.be.equal(zeroAddress);
            expect(await CBToken.getUnlockTime()).to.be.equal(period);
        });

        it('shouldn\'t set the lock period if a caller isn\'t an owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user1).lock(days(1))).to.be.reverted;
        });

        it('should unlock the SC correctly', async () => {
            const { CBToken, owner } = await loadFixture(deployFixture);
            await CBToken.lock(1);
            await time.increase(days(1));
            await CBToken.unlock();
            expect(await CBToken.owner()).to.be.equal(owner.address);
        });

        it('shouldn\'t unlock the SC if a caller hasn\'t permission', async () => {
            const { CBToken, user2 } = await loadFixture(deployFixture);
            await expect(CBToken.connect(user2).unlock()).to.be.revertedWithCustomError(CBToken, 'InvalidPermission()');
        });

        it('shouldn\'t unlock if `_lockTime` isn\'t exceeds', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            await CBToken.lock(days(1));
            await expect(CBToken.unlock()).to.be.revertedWithCustomError(CBToken, 'LockedContract()');
        });

        it('should return the reflections per tokens correctly', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            const taxFee = BigInt(0);
            const liquidityFee = BigInt(2);
            const tAmount = ethers.parseEther('5');

            const tFee = tAmount * taxFee / BigInt(100);
            const tLiquidity = tAmount * liquidityFee / BigInt(100);
            const currentRate = _rTotal / _tTotal;
            const rAmount = tAmount * currentRate;
            const rFee = tFee * currentRate;
            const rLiquidity = tLiquidity * currentRate;
            const rTransferAmount = rAmount - rFee - rLiquidity;
            expect(await CBToken.reflectionFromToken(tAmount, true)).to.be.equal(rTransferAmount);
            expect(await CBToken.reflectionFromToken(tAmount, false)).to.be.equal(rAmount);
        });

        it('shouldn\'t return the reflections per tokens if the amount more than supply', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            const tAmount = _tTotal + BigInt(10);
            await expect(CBToken.reflectionFromToken(tAmount, true))
                .to.be.revertedWith('The amount must be less than total supply');
        });

        it('shouldn\'t return the tokens per reflections if the amount more than supply', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            const rAmount = _rTotal + BigInt(10);
            await expect(CBToken.tokenFromReflection(rAmount))
                .to.be.revertedWith('The amount must be less than total reflections');
        });

    });

    describe('CoinBoxToken Transfer Functions Phase Test Cases', function () {

        it('shouldn\'t transfer the amount of tokens if insufficient allowance', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.transferFrom(zeroAddress, user1.address, ethers.parseEther('1'))).to.be.reverted;
        });

        it('shouldn\'t transfer the amount of tokens if zero\'s recipient address', async () => {
            const { CBToken } = await loadFixture(deployFixture);
            await expect(CBToken.transfer(zeroAddress, ethers.parseEther('1'))).to.be.reverted;
        });

        it('shouldn\'t transfer the amount of tokens if the amount is zero', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);
            await expect(CBToken.transfer(user1.address, 0)).to.be.revertedWithCustomError(CBToken, 'ZeroValue()');
        });

        it('shouldn\'t transfer the amount of tokens if the amount exceeds the maxTxAmount', async () => {
            const { CBToken, user1, user2 } = await loadFixture(deployFixture);
            await CBToken.setMaxTxPercent(0);
            await expect(CBToken.connect(user2).transfer(user1.address, ethers.parseEther('1')))
                .to.be.revertedWith('Transfer\'s amount exceeds the maxTxAmount');
        });

        it('should transfer the amount of tokens from an excluded account correctly', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            const fee = BigInt(0);
            const amount = ethers.parseEther('10');

            const calculated = calculateValues(fee, amount, _rTotal);
            let tOwnedS = _rTotal / calculated.currentRate;
            let tOwnedSNew = tOwnedS - amount;
            let rOwnedS = _rTotal - calculated.rAmount;
            let balanceSender = rOwnedS / calculated.currentRate;
            let balanceRecipient = calculated.rTransferAmount / calculated.currentRate;
            
            await CBToken.setMaxTxPercent(0);
            await CBToken.excludeFromReward(owner.address);
            expect(await CBToken.transfer(user1.address, amount))
                .to.be.emit(CBToken, 'TransferFromExcluded')
                .withArgs(owner.address, user1.address, tOwnedSNew, rOwnedS, calculated.rTransferAmount);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceSender);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceRecipient);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(0);
        });

        it('should transfer the amount of tokens from excluded account correctly if contract\'s address is excluded', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            const fee = BigInt(0);
            const amount = ethers.parseEther('10');

            const calculated = calculateValues(fee, amount, _rTotal);
            let rOwnedS = _rTotal - calculated.rAmount;
            let rOwnedR = calculated.rTransferAmount;
            let rOwnedC = calculated.tLiquidity * calculated.currentRate;
            _rTotal = _rTotal - calculated.rFee;
            const currentRate = _rTotal / _tTotal;
            let balanceSender = rOwnedS / currentRate;
            let balanceRecipient = rOwnedR / currentRate;
            let balanceContract = rOwnedC / currentRate;
            
            await CBToken.excludeFromReward(owner.address);
            await CBToken.excludeFromReward(CBToken.target);
            expect(await CBToken.transfer(user1.address, amount))
                .to.be.emit(CBToken, 'Transfer')
                .withArgs(owner.address, user1.address, calculated.tTransferAmount);
            expect(await CBToken.balanceOf(owner)).to.be.equal(balanceSender);
            expect(await CBToken.balanceOf(user1)).to.be.equal(balanceRecipient);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(balanceContract);
        });

        it('should transfer the amount of tokens to excluded account correctly', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            const fee = BigInt(0);
            const amount = ethers.parseEther('10');

            const calculated = calculateValues(fee, amount, _rTotal);
            let rOwnedS = _rTotal - calculated.rAmount;
            let balanceSender = rOwnedS / calculated.currentRate;
            let balanceRecipient = calculated.rTransferAmount / calculated.currentRate;
            await CBToken.excludeFromReward(user1.address);
            expect(await CBToken.transfer(user1.address, amount))
                .to.be.emit(CBToken, 'TransferToExcluded')
                .withArgs(owner.address, user1.address, rOwnedS, calculated.tTransferAmount, calculated.rTransferAmount);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceSender);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceRecipient);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(0);
        });

        it('should transfer the amount of tokens correctly if both accounts are excluded', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            const fee = BigInt(0);
            const amount = ethers.parseEther('10');

            const calculated = calculateValues(fee, amount, _rTotal);
            let tOwnedS = _rTotal / calculated.currentRate;
            let tOwnedSNew = tOwnedS - amount;
            let rOwnedS = _rTotal - calculated.rAmount;
            let rOwnedR = calculated.rTransferAmount;
            let balanceSender = rOwnedS / calculated.currentRate;
            let balanceRecipient = rOwnedR / calculated.currentRate;
            
            await CBToken.excludeFromReward(owner.address);
            await CBToken.excludeFromReward(user1.address);
            expect(await CBToken.transfer(user1.address, amount))
                .to.be.emit(CBToken, 'TransferFromSender').withArgs(owner.address, tOwnedSNew, rOwnedS)
                .to.be.emit(CBToken, 'TransferToRecipient').withArgs(user1.address, calculated.tTransferAmount, rOwnedR);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceSender);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceRecipient);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(0);
        });

        it('should standard transfer the amount of tokens correctly if not satisfying the threshold', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            const fee = BigInt(0);
            const amount = ethers.parseEther('10');

            const calculated = calculateValues(fee, amount, _rTotal);
            let rOwnedS = _rTotal - calculated.rAmount;
            let rOwnedR = calculated.rTransferAmount;
            let balanceSender = rOwnedS / calculated.currentRate;
            let balanceRecipient = rOwnedR / calculated.currentRate;
            let rTotal = _rTotal - calculated.rFee;
            
            expect(await CBToken.transfer(user1.address, amount))
                .to.be.emit(CBToken, 'Transfer').withArgs(owner.address, user1.address, calculated.tTransferAmount)
                .to.be.emit(CBToken, 'TransferStandard').withArgs(owner.address, user1.address, rOwnedS, rOwnedR)
                .to.be.emit(CBToken, 'ReflectFee').withArgs(rTotal, calculated.tFee)
                .to.be.emit(CBToken, 'TakeLiquidity').withArgs(0, 0)
                .to.be.emit(CBToken, 'RemoveAllFee').withArgs(0, 5, calculated.tFee, calculated.tLiquidity)
                .to.be.emit(CBToken, 'RestoreAllFee').withArgs(0, 5);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceSender);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceRecipient);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(0);
        });

        it('should standard transfer the amount of tokens correctly without fee', async () => {
            const { CBToken, user1, user2 } = await loadFixture(deployFixture);
            const fee = BigInt(0);
            const amount = ethers.parseEther('10');

            const calculated1 = calculateValues(fee, amount, _rTotal);
            const rOwnedCT1 = calculated1.tLiquidity * calculated1.currentRate;
            _rTotal = _rTotal - calculated1.rFee;
            let currentRate = _rTotal / _tTotal;

            const calculated2 = calculateValues(fee, amount, _rTotal);
            const rOwnedST2 = calculated1.rTransferAmount - calculated2.rAmount;
            const rOwnedCT2 = rOwnedCT1 + calculated2.tLiquidity * currentRate;
            _rTotal = _rTotal - calculated2.rFee;
            currentRate = _rTotal / _tTotal;
            const balanceUser1T2 = rOwnedST2 / currentRate;
            const balanceUser2T2 = calculated2.rTransferAmount / currentRate;
            const balanceContractT2 = rOwnedCT2 / currentRate;

            await CBToken.setTransferFeePercent(fee, fee);
            await CBToken.transfer(user1.address, amount);
            await CBToken.connect(user1).transfer(user2.address, amount);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceUser1T2);
            expect(await CBToken.balanceOf(user2.address)).to.be.equal(balanceUser2T2);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(balanceContractT2);
        });

        it('should standard transfer the amount of tokens correctly if not satisfying the threshold and with fee', async () => {
            const { CBToken, owner, user1 } = await loadFixture(deployFixture);
            const fee = BigInt(50);
            const amount = ethers.parseEther('10');
            
            const calculated = calculateValues(fee, amount, _rTotal);
            const rOwnedS = _rTotal - calculated.rAmount;
            const rOwnedC = calculated.tLiquidity * calculated.currentRate;
            _rTotal = _rTotal - calculated.rFee;
            const currentRate = _rTotal / _tTotal;
            const balanceSender = rOwnedS / currentRate;
            const balanceRecipient = calculated.rTransferAmount / currentRate;
            const balanceContract = rOwnedC / currentRate;
            
            await CBToken.includeInFee(owner.address);
            await CBToken.setTransferFeePercent(fee, fee);
            await CBToken.transfer(user1.address, amount);
            expect(await CBToken.totalFees()).to.be.equal(calculated.tFee);
            expect(await CBToken.balanceOf(owner.address)).to.be.equal(balanceSender);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceRecipient);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(balanceContract);
        });

        it('should standard transfer the amount of tokens correctly if satisfying the threshold', async () => {
            const { CBToken, owner, user1, user2 } = await loadFixture(deployFixture);
            const fee = BigInt(0);                        
            const amountPairE = ethers.parseEther('10000');
            const amountPairW = ethers.parseEther('10');
            const amountT1 = ethers.parseEther('1000');
            const amountT2 = ethers.parseEther('100');
            const amountT3 = ethers.parseEther('10');
            const deadline = (await time.latest()) + 100_000;

            const provider = new ethers.JsonRpcProvider('https://ethereum-sepolia-rpc.publicnode.com');
            const routerImpl = new ethers.Contract(ROUTER_1, IUniswapV2Router02.abi, provider);
            const wethAddress = await routerImpl.WETH();
            const newWeth = new ethers.Contract(wethAddress, IWETH.abi, provider);
            const pair = await CBToken.uniswapV2Pair();

            const calculatedEP = calculateValues(fee, amountPairE, _rTotal);
            const balancePairEP = calculatedEP.rTransferAmount / calculatedEP.currentRate;

            _rTotal = _rTotal - calculatedEP.rFee;
            const calculatedT1 = calculateValues(fee, amountT1, _rTotal);
            const rOwnedCT1 = calculatedT1.tLiquidity * calculatedT1.currentRate;
            _rTotal = _rTotal - calculatedT1.rFee;
            let currentRate = _rTotal / _tTotal;
            const balanceUser1T1 = calculatedT1.rTransferAmount / currentRate;
            const balanceContractT1 = rOwnedCT1 / currentRate;

            const calculatedT2 = calculateValues(fee, amountT2, _rTotal);
            const rOwnedST2 = calculatedT1.rTransferAmount - calculatedT2.rAmount;
            const rOwnedCT2 = rOwnedCT1 + calculatedT2.tLiquidity * calculatedT2.currentRate;
            _rTotal = _rTotal - calculatedT2.rFee;
            currentRate = _rTotal / _tTotal;
            const balanceUser1T2 = rOwnedST2 / currentRate;
            const balanceUser2T2 = calculatedT2.rTransferAmount / currentRate;
            const balanceContractT2 = rOwnedCT2 / currentRate;

            const calculatedT3 = calculateValues(fee, amountT3, _rTotal);
            const rOwnedST3 = calculatedT2.rTransferAmount - calculatedT3.rAmount;
            const rOwnedRT3 = rOwnedST2 + calculatedT3.rTransferAmount;
            _rTotal = _rTotal - calculatedT3.rFee;
            currentRate = _rTotal / _tTotal;
            const balanceUser2T3 = rOwnedST3 / currentRate;
            const balanceUser1T3 = rOwnedRT3 / currentRate;
            
            await CBToken.setTransferFeePercent(fee, fee);
            await newWeth.deposit({ value: amountPairW, gas: 5500000 });
            await newWeth.approve(routerImpl.address, amountPairW);
            await CBToken.approve(ROUTER_1, amountPairE);
            await CBToken.setThreshold(ethers.parseEther('0.01'));
            await routerImpl.addLiquidity(CBToken.target, newWeth.address, amountPairE, amountPairW, 0, 0, owner.address, deadline);
            expect(await CBToken.balanceOf(pair)).to.be.equal(balancePairEP);

            await CBToken.transfer(user1.address, amountT1);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceUser1T1);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(balanceContractT1);

            await CBToken.connect(user1).transfer(user2.address, amountT2);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceUser1T2);
            expect(await CBToken.balanceOf(user2.address)).to.be.equal(balanceUser2T2);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(balanceContractT2);

            await CBToken.connect(user2).transfer(user1.address, amountT3);
            expect(await CBToken.balanceOf(user2.address)).to.be.equal(balanceUser2T3);
            expect(await CBToken.balanceOf(user1.address)).to.be.equal(balanceUser1T3);
        });

    });

    describe('CoinBoxToken Withdraw Functions Phase Test Cases', function () {

        it('should withdraw leftovers correctly', async () => {
            const { CBToken, owner, user1, user2 } = await loadFixture(deployFixture);

            const amountPairE = ethers.parseEther('10000');
            const amountPairW = ethers.parseEther('10');
            const amountT1 = ethers.parseEther('1000');
            const amountT2 = ethers.parseEther('100');
            const amountT3 = ethers.parseEther('10');
            const fee = BigInt(0);
            const deadline = (await time.latest()) + 100_000;

            const provider = new ethers.JsonRpcProvider('https://ethereum-sepolia-rpc.publicnode.com');
            const routerImpl = new ethers.Contract(ROUTER_1, IUniswapV2Router02.abi, provider);
            const wethAddress = await routerImpl.WETH();
            const newWeth = new ethers.Contract(wethAddress, IWETH.abi, provider);

            const calculatedT1 = calculateValues(fee, amountT1, _rTotal);
            _rTotal = _rTotal - calculatedT1.rFee;

            const calculatedT2 = calculateValues(fee, amountT2, _rTotal);
            const rOwnedST2 = calculatedT1.rTransferAmount - calculatedT2.rAmount;
            _rTotal = _rTotal - calculatedT2.rFee;

            const calculatedT3 = calculateValues(fee, amountT3, _rTotal);
            const rOwnedST3 = calculatedT2.rTransferAmount - calculatedT3.rAmount;
            const rOwnedRT3 = rOwnedST2 + calculatedT3.rTransferAmount;
            _rTotal = _rTotal - calculatedT3.rFee;
            const currentRate = _rTotal / _tTotal;
            const balanceUser2T3 = rOwnedST3 / currentRate;
            const balanceUser1T3 = rOwnedRT3 / currentRate;
            
            await CBToken.setTransferFeePercent(fee, fee);
            await newWeth.deposit({ value: amountPairW, gas: 5500000 });
            await newWeth.approve(routerImpl.address, amountPairW);
            await CBToken.approve(ROUTER_1, amountPairE);
            await CBToken.setThreshold(ethers.parseEther('0.01'));
            await routerImpl.addLiquidity(CBToken.target, newWeth.address, amountPairE, amountPairW, 0, 0, owner.address, deadline);
            await CBToken.transfer(user1.address, amountT1);
            await CBToken.connect(user1).transfer(user2.address, amountT2);
            await CBToken.connect(user2).transfer(user1.address, amountT3);
            expect(await CBToken.balanceOf(user2)).to.be.equal(balanceUser2T3);
            expect(await CBToken.balanceOf(user1)).to.be.equal(balanceUser1T3);
            
            const beforeBalanceC = await ethers.provider.getBalance(CBToken.target);
            expect(await CBToken.withdrawLeftovers())
                .to.be.emit(CBToken, 'WithdrawLeftovers').withArgs(owner.address, beforeBalanceC);
            expect(await ethers.provider.getBalance(CBToken.target)).to.be.equal(0);
        });

        it('should withdraw alien tokens correctly', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);

            const mockToken = await (await ethers.getContractFactory('MockERC20')).deploy(ethers.parseEther('100'));
            await mockToken.mint(CBToken.target, ethers.parseEther('100'));
            expect(await CBToken.withdrawAlienToken(mockToken.target, user1.address, ethers.parseEther('20')))
                .to.be.emit(CBToken, 'WithdrawAlienToken').withArgs(mockToken.target, user1.address, ethers.parseEther('20'));
            expect(await mockToken.balanceOf(user1.address)).to.be.equal(ethers.parseEther('20'));
        });

        it('shouldn\'t withdraw alien tokens if token\'s address is CoinBoxToken and swap&liquify if enabled', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);

            await expect(CBToken.withdrawAlienToken(CBToken.target, user1.address, ethers.parseEther('20')))
                .to.be.revertedWithCustomError(CBToken, 'InvalidToken()');
        });

        it('should withdraw alien tokens by the owner if token\'s address is CoinBoxToken and swap&liquify if disabled', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);

            const amount = ethers.parseEther('1');
            await CBToken.transfer(CBToken.target, amount);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(amount);
            await CBToken.setSwapAndLiquifyEnabled(false);
            await CBToken.withdrawAlienToken(CBToken.target, user1.address, amount);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(0);
        });

        it('shouldn\'t withdraw alien tokens by not the owner', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);

            const amount = ethers.parseEther('1');
            await CBToken.transfer(CBToken.target, amount);
            expect(await CBToken.balanceOf(CBToken.target)).to.be.equal(amount);
            await CBToken.setSwapAndLiquifyEnabled(false);
            await expect(CBToken.connect(user1).withdrawAlienToken(CBToken.target, user1.address, amount)).to.be.reverted;
        });

        it('shouldn\'t withdraw alien tokens if amount is zero', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);

            const mockToken = await (await ethers.getContractFactory('MockERC20')).deploy(ethers.parseEther('100'));
            await mockToken.mint(CBToken.target, ethers.parseEther('100'));
            await expect(CBToken.withdrawAlienToken(mockToken.target, user1.address, 0))
                .to.be.revertedWithCustomError(CBToken, 'ZeroValue()');
        });

        it('shouldn\'t withdraw alien tokens if insufficient balance', async () => {
            const { CBToken, user1 } = await loadFixture(deployFixture);

            const mockToken = await (await ethers.getContractFactory('MockERC20')).deploy(ethers.parseEther('100'));
            await mockToken.mint(CBToken.target, ethers.parseEther('10'));
            await expect(CBToken.withdrawAlienToken(mockToken.target, user1.address, ethers.parseEther('13')))
                .to.be.revertedWithCustomError(CBToken, 'InsufficientBalance()');
        });

    });

});