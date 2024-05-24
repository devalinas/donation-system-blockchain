// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

/// @title The smart contract CoinBoxToken that describes the personal reflection token
///         based on the ERC-20 standard
contract CoinBoxToken is ERC20Upgradeable, OwnableUpgradeable {

    /// @notice The structure keeps the values of the fee. The fee are used while operations
    /// @param _liquidityFee The liquidity value of fee
    /// @param _taxFee The tax value of fee
    struct FeeValues {
        uint256 _liquidityFee;
        uint256 _taxFee;
    }

    /// @dev The max possible value that can be saved in the `uint256` type
    uint256 private constant _MAX = type(uint256).max;
    /// @dev The total possible value of tokens: 600m
    uint256 private constant _T_Total = 600 * 10**6 * 10**18;

    /// @notice The router address of uniswap V2
    IUniswapV2Router02 public uniswapV2Router;
    /// @notice The pair address: WETH & CoinBoxToken
    address public uniswapV2Pair;

    /// @notice The value of max tx percent (<= 100)
    uint256 public maxTxAmount;

    /// @notice The values of the swap fee: liquidity & tax
    FeeValues public swapFee;
    /// @notice The values of the transfer fee: liquidity & tax
    FeeValues public transferFee;

    /// @notice The boolean value keeps the info re enable for swap and liquify 
    bool public swapAndLiquifyEnabled;
    
    /// @dev The value saves possible decimals of the token
    uint8 private _decimals;
    /// @dev The threshold for the accumulation
    uint256 private _numTokensSellToAddToLiquidity;

    /// @dev The structure keeps the previous values of fee while swaps
    FeeValues private _previousSwapFee;
    /// @dev The structure keeps the previous values of fee while transfers
    FeeValues private _previousTransferFee;

    /// @dev The variable keeps total amount of the reflections
    uint256 private _rTotal;
    /// @dev The variable keeps total amount of the token's fee collected through transfers
    uint256 private _tFeeTotal;

    /// @dev The saved address of previous token's owner
    address private _previousOwner;
    /// @dev The value of time for locking SC
    uint256 private _lockTime;

    /// @dev The excluded accounts from the rewards
    address[] private _excluded;
    /// @dev The boolean value re possible approve for swap and liquify
    bool private _inSwapAndLiquify;

    /// @dev The account's balance of the reflection tokens
    mapping(address => uint256) private _rOwned;
    /// @dev The account's balance of the tokens
    mapping(address => uint256) private _tOwned;
    /// @dev The mapping with the addresses which are excluded from fee
    mapping(address => bool) private _isExcludedFromFee;
    /// @dev The mapping with the addresses which are excluded from rewards
    mapping(address => bool) private _isExcluded;

    /// @dev The event is triggered whenever an owner sets threshold value
    /// @param threshold The value of threshold for approve to swap
    event Threshold(uint256 threshold);
    /// @dev The event is triggered whenever an owner sets enable for swap and liquify
    /// @param enabled The boolean value about enable for swap and liquify
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    /// @dev The event is triggered whenever swap and liquify are executed
    /// @param tokensSwapped The value of swapped tokens
    /// @param ethReceived The amount of ETH after swaps tokens to ETH
    /// @param tokensIntoLiquidity The leftovers tokens on the contract's balance
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    /// @dev The event is triggered whenever an account want to burn the reflection tokens
    /// @param sender The address of account who call function to burn tokens
    /// @param rAmount The leftovers of reflection tokens on the account's balance after burning
    /// @param rTotal The total amount of reflection tokens
    /// @param tFeeTotal The token's fee collected through transfers
    event Deliver(
        address indexed sender,
        uint256 rAmount,
        uint256 rTotal,
        uint256 tFeeTotal
    );
    /// @dev The event is triggered whenever an owner excludes the certain address from rewards
    /// @param account The address of account to exclude
    /// @param tOwned The calculated tokens on the account's balance if reflection tokens are existed
    event ExcludeFromReward(address indexed account, uint256 tOwned);
    /// @dev The event is triggered whenever an owner includes the certain address for rewards
    /// @param account The address of account to include
    event IncludeInReward(address indexed account);
    /// @dev The event is triggered whenever the certain account transfers tokens to the certain recipient
    /// @param sender The address of sender
    /// @param tOwned The calculated tokens on the sender's balance
    /// @param rOwned The calculated reflection tokens on the sender's balance
    event TransferFromSender(
        address indexed sender,
        uint256 tOwned,
        uint256 rOwned
    );
    /// @dev The event is triggered whenever the certain account transfers tokens to the certain recipient
    /// @param recipient The address of recipient
    /// @param tOwned The calculated tokens on the recipient's balance after transfer
    /// @param rOwned The calculated reflection tokens on the recipient's balance
    event TransferToRecipient(
        address indexed recipient,
        uint256 tOwned,
        uint256 rOwned
    );
    /// @dev The event is triggered whenever the owner excludes a certain account from fee
    /// @param account The address of excluded account
    /// @param isExcludedFromFee The boolean value if a certain account is excluded
    event ExcludeFromFee(address indexed account, bool isExcludedFromFee);
    /// @dev The event is triggered whenever the owner includes a certain account in fee
    /// @param account The address of included account
    /// @param isExcludedFromFee The boolean value if a certain account is excluded or included
    event IncludeInFee(address indexed account, bool isExcludedFromFee);
    /// @dev The event is triggered whenever the owner sets transfer liquidity and tax fee percent
    /// @param liquidityFee The set new value of liquidity fee
    /// @param taxFee The set new value of tax fee
    event TranferFeePercents(uint256 liquidityFee, uint256 taxFee);
    /// @dev The event is triggered whenever the owner sets swap liquidity and tax fee percent
    /// @param liquidityFee The set new value of liquidity fee
    /// @param taxFee The set new value of tax fee
    event SwapFeePercents(uint256 liquidityFee, uint256 taxFee);
    /// @dev The event is triggered whenever the owner sets max tx percent
    /// @param maxTxAmount The value of max tx percent (<= 100)
    event MaxTxPercent(uint256 maxTxAmount);
    /// @dev The event is triggered whenever transfer operation is executed
    /// @param rTotal The set new value of total reflection tokens after substraction
    /// @param tFeeTotal The set new value of total fee after addition
    event ReflectFee(uint256 rTotal, uint256 tFeeTotal);
    /// @dev The event is triggered whenever liquidity is added while transfer operation
    /// @param rOwned The amount of reflection tokens on the account's balance after adding liquidity
    /// @param tOwned The amount of tokens on the account's balance after adding liquidity
    event TakeLiquidity(uint256 rOwned, uint256 tOwned);
    /// @dev The event is triggered whenever all fee (swap & transfer) is removed
    /// @param previousSwapFee The previous values of swap liquidity and tax fee percent before changing
    /// @param previousTransferFee The previous values of transfer liquidity and tax fee percent before changing
    /// @param swapFee The current values of swap liquidity and tax fee percent after changing
    /// @param transferFee The current values of transfer liquidity and tax fee percent after changing
    event RemoveAllFee(
        FeeValues previousSwapFee,
        FeeValues previousTransferFee,
        FeeValues swapFee,
        FeeValues transferFee
    );
    /// @dev The event is triggered whenever all fee (swap & transfer) are restored
    /// @param swapFee The previous values of swap liquidity and tax fee percent before changing
    /// @param transferFee The previous values of transfer liquidity and tax fee percent before changing
    event RestoreAllFee(FeeValues swapFee, FeeValues transferFee);
    /// @dev The event is triggered whenever the standard transfer operation is executed
    /// @param sender The address of token's sender
    /// @param recipient The address of token's recipient
    /// @param rOwnedSender The leftovers reflection tokens of sender after transfer operation
    /// @param rOwnedRecipient The amount of reflection tokens of recipient after transfer operation
    event TransferStandard(
        address indexed sender,
        address indexed recipient,
        uint256 rOwnedSender,
        uint256 rOwnedRecipient
    );
    /// @dev The event is triggered whenever a sender transfers tokens to account that excluded from rewards
    /// @param sender The address of token's sender
    /// @param recipient The address of token's recipient
    /// @param rOwnedSender The leftovers reflection tokens of sender after transfer operation
    /// @param tOwnedRecipient The amount of tokens of recipient after transfer operation
    /// @param rOwnedRecipient The amount of reflection tokens of recipient after transfer operation
    event TransferToExcluded(
        address indexed sender,
        address indexed recipient,
        uint256 rOwnedSender,
        uint256 tOwnedRecipient,
        uint256 rOwnedRecipient
    );
    /// @dev The event is triggered whenever an excluded from rewards sender transfers tokens to a certain account
    /// @param sender The address of token's sender
    /// @param recipient The address of token's recipient
    /// @param tOwnedSender The leftovers tokens of sender after transfer operation
    /// @param rOwnedSender The leftovers reflection tokens of sender after transfer operation
    /// @param rOwnedRecipient The amount of reflection tokens of recipient after transfer operation
    event TransferFromExcluded(
        address indexed sender,
        address indexed recipient,
        uint256 tOwnedSender,
        uint256 rOwnedSender,
        uint256 rOwnedRecipient
    );
    /// @dev The event is triggered whenever an owner want to withdraw the leftovers of native currency
    /// @param recipient The owner's address for receiving ETH
    /// @param amount The amount of leftovers ETH that was withdrawn
    event WithdrawLeftovers(address indexed recipient, uint256 amount);
    /// @dev The event is triggered whenever an owner want to withdraw alien or even native tokens from SC's balance
    /// @param token The address of token
    /// @param recipient The account's address for receiving token
    /// @param amount The withdrawn amount of tokens
    event WithdrawAlienToken(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    /// @dev The event is triggered whenever an owner want to change the router's address
    /// @param router The updated address of router
    event ChangeRouter(address indexed router);
    /// @dev The event is triggered whenever the liquidity is added to an CoinBoxToken⇄WETH pool with ETH
    /// @param amountToken The amount of tokens sent to the pool
    /// @param amountETH The amount of ETH converted to WETH and sent to the pool
    /// @param liquidity The amount of liquidity tokens minted
    event AddLiquidity(
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    /// @dev The custom error is triggered when the input address is zero's 
    error ZeroAddress();
    /// @dev The custom error is triggered when the certain account is included in rewards
    error IncludedAccount();
    /// @dev The custom error is triggered when the certain account is excluded from rewards
    error ExcludedAccount();
    /// @dev The custom error is triggered when an owner want to set up the bounded value of fee or percent
    error ExceededValue();
    /// @dev The custom error is triggered when the input amount is zero
    error ZeroValue();
    /// @dev The custom error is triggered when the tokens of CoinBoxToken SC can not be withdrawn
    error InvalidToken();
    /// @dev The custom error is triggered when the expected amount exceeds the current balance's state
    error InsufficientBalance();
    /// @dev The custom error is triggered when an account has not access to unlock the SC
    error InvalidPermission();
    /// @dev The custom error is triggered when the locking period is not expired yet
    error LockedContract();

    /// @dev The modifier is appointmented for correct execution swap and liquify operation
    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    /// @dev The modifier is appointmented for сhecking the input address for a zero value
    /// @param account The address of account for checking
    modifier checkZeroAddress(address account) {
        if (account == address(0)) revert ZeroAddress();
        _;
    }

    /// @notice The function to receive ETH when msg.data is empty
    receive() external payable {}

    /// @notice Fallback function to receive ETH when msg.data is not empty
    /// @dev Receives ETH from uniswapV2Router when swapping
    fallback() external payable {}

    /// @notice Initialization
    /// @dev Sets the address of router, creates an uniswap pair
    /// and excludes from fee an owner and CoinBoxToken contract addresses.
    /// Sets default Buy/Sell and any router interactions fee as _liquidityFee = 5%, _taxFee = 0%
    /// Sets default Transfer fee as _liquidityFee = 2%, _taxfee = 0%
    /// @param _router The address of router for initialize
    /// @param _owner The address of owner. This address will receive all tokens and ownership
    function initialize(address _router, address _owner)
        external
        initializer
        checkZeroAddress(_router)
        checkZeroAddress(_owner)
    {
        _decimals = 18;
        maxTxAmount = _T_Total; // 600m
        _numTokensSellToAddToLiquidity = 5 * 10**5 * 10**18; // 500k
        
        swapFee._liquidityFee = 5;
        transferFee._liquidityFee = 2;
        
        swapAndLiquifyEnabled = true;
        _previousSwapFee._liquidityFee = swapFee._liquidityFee;
        _previousTransferFee._liquidityFee = transferFee._liquidityFee;
        
        _rTotal = _MAX - (_MAX % _T_Total);
        _rOwned[_owner] = _rTotal;
        
        __ERC20_init("CoinBox Token", "CBT");
        __Ownable_init(_owner);
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[address(this)] = true;
        
        emit Transfer(address(0), _owner, _T_Total);
    }

    /// @notice Determines the threshold for the accumulation before swapping
    /// @dev Sets the threshold by an owner
    /// @param threshold The value of threshold (min amount) for next swap
    function setThreshold(uint256 threshold) external onlyOwner {
        _numTokensSellToAddToLiquidity = threshold;
        emit Threshold(threshold);
    }

    /// @notice Includes the account in rewards
    /// @dev Sets the address of account in rewards and checks previous exclude
    /// @param account The address for include in reward
    function includeInReward(address account) external onlyOwner checkZeroAddress(account) {
        if (!_isExcluded[account]) revert IncludedAccount();
        for (uint256 i; i < _excluded.length;) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                emit IncludeInReward(account);
                break;
            }
            unchecked {
                i++;
            }
        }
    }

    /// @notice Sets swap liquidity and tax fee percent
    /// @param liquidityFee The value of liquidity fee
    /// @param taxFee The value of tax fee
    function setSwapFeePercent(uint256 liquidityFee, uint256 taxFee)
        external
        onlyOwner
    {
        if (liquidityFee > 100 || taxFee > 100) revert ExceededValue();
        swapFee._liquidityFee = liquidityFee;
        swapFee._taxFee = taxFee;
        emit SwapFeePercents(liquidityFee, taxFee);
    }

    /// @notice Sets transfer liquidity and tax fee percent
    /// @param liquidityFee The value of liquidity fee
    /// @param taxFee The value of tax fee
    function setTransferFeePercent(uint256 liquidityFee, uint256 taxFee)
        external
        onlyOwner
    {
        if (liquidityFee > 100 || taxFee > 100) revert ExceededValue();
        transferFee._liquidityFee = liquidityFee;
        transferFee._taxFee = taxFee;
        emit TranferFeePercents(liquidityFee, taxFee);
    }

    /// @notice Sets max tx percent
    /// @dev Sets max tx percent with the previous calculation by an owner
    /// @param maxTxPercent The value for max tx percent
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        if (maxTxPercent > 100) revert ExceededValue();
        maxTxAmount = (_T_Total * maxTxPercent) / 10 ** 2;
        emit MaxTxPercent(maxTxAmount);
    }

    /// @notice Sets the new router's address
    /// @dev Sets the address of router with the previous check the input's address
    /// @param _router The address of router
    function setRouter(address _router)
        external
        onlyOwner
        checkZeroAddress(_router)
    {
        uniswapV2Router = IUniswapV2Router02(_router);
        emit ChangeRouter(_router);
    }

    /// @notice Withdraws the native currency from the SC's balance
    /// @dev Withdraws amount of ETH that is as remainder in the contract
    function withdrawLeftovers() external onlyOwner {
        uint256 leftovers = address(this).balance;
        if (leftovers == 0) revert ZeroValue();
        payable(owner()).transfer(leftovers);
        emit WithdrawLeftovers(owner(), leftovers);
    }

    /// @notice Withdraws the alien tokens from the balance of the contract
    /// @dev Withdraws the alien tokens that may have been mistakenly sent to the contract.
    /// Or withdraws of CoinBox tokens in case if `swapAndLiquifyEnabled` is disable
    /// @param token The address of alien token
    /// @param recipient The address of account that gets the transfer's amount
    /// @param amount The amount for transfer
    function withdrawAlienToken(
        address token,
        address recipient,
        uint256 amount
    ) 
        external 
        onlyOwner 
        checkZeroAddress(token) 
        checkZeroAddress(recipient) 
    {
        if (swapAndLiquifyEnabled) {
            if (token == address(this)) revert InvalidToken();
        }
        if (amount == 0) revert ZeroValue();
        if (IERC20(token).balanceOf(address(this)) < amount)
            revert InsufficientBalance();
        IERC20(token).transfer(recipient, amount);
        emit WithdrawAlienToken(token, recipient, amount);
    }

    /// @notice Burns the reflection tokens from the balance
    /// @dev This function can only be called by non excluded addresses (SC's and SC owner's addresses)
    /// @param tAmount The amount of tokens for calculating the reflection tokens to burn
    function deliver(uint256 tAmount) external {
        address sender = _msgSender();
        if (_isExcluded[sender]) revert ExcludedAccount();
        (uint256 rAmount, , , , , ) = _getValues(tAmount, transferFee);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rTotal = _rTotal - rAmount;
        _tFeeTotal = _tFeeTotal + tAmount;
        emit Deliver(sender, _rOwned[sender], _rTotal, _tFeeTotal);
    }

    /// @notice Excludes the account from rewards
    /// @dev Changes the values of _isExcluded, _tOwned (if need) and pushes the account
    /// @param account The address of account
    function excludeFromReward(address account) external onlyOwner checkZeroAddress(account) {
        if (_isExcluded[account]) revert ExcludedAccount();
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
        emit ExcludeFromReward(account, _tOwned[account]);
    }

    /// @notice Excludes the account from fee
    /// @dev Changes the value of _isExcludedFromFee for this account
    /// @param account The address of account
    function excludeFromFee(address account) external onlyOwner checkZeroAddress(account) {
        if (_isExcludedFromFee[account]) revert ExcludedAccount();
        _isExcludedFromFee[account] = true;
        emit ExcludeFromFee(account, _isExcludedFromFee[account]);
    }

    /// @notice Includes the account in fee
    /// @dev Changes the value of _isExcludedFromFee for this account
    /// @param account The address of account
    function includeInFee(address account) external onlyOwner checkZeroAddress(account) {
        if (!_isExcludedFromFee[account]) revert IncludedAccount();
        _isExcludedFromFee[account] = false;
        emit IncludeInFee(account, _isExcludedFromFee[account]);
    }

    /// @notice Sets the enable for swap and liquify operation
    /// @dev Sets the correct value of swapAndLiquifyEnabled
    /// @param _enabled Sets whether `_swapAndLiquify()` function is enables.
    /// `True` - if enable, `false` - if disable
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /// @notice Locks the contract by an owner
    /// @dev Locks the contract by an owner for the provided value of time
    /// @param time The value for sets the time for locking
    function lock(uint256 time) external onlyOwner {
        _previousOwner = owner();
        _transferOwnership(address(0));
        _lockTime = block.timestamp + time;
    }

    /// @notice Unlocks the contract by an owner
    /// @dev Unlocks the contract by a previous owner when _lockTime is exceeded
    function unlock() external {
        if (_previousOwner != _msgSender()) revert InvalidPermission();
        if (block.timestamp <= _lockTime) revert LockedContract();
        _transferOwnership(_previousOwner);
    }

    /// @notice Returns the info if the account is excluded from fee
    /// @param account The address of account
    /// @return The boolean value of `_isExcludedFromFee`
    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /// @notice Returns the set lock time
    /// @return The value of variable `_lockTime`
    function getUnlockTime() external view returns (uint256) {
        return _lockTime;
    }

    /// @notice Returns the info if the account is excluded from reward
    /// @dev Returns the saved value re info if the account is excluded from rewards
    /// @param account The address of account
    /// @return The boolean value about account
    function isExcludedFromReward(address account)
        external
        view
        returns (bool)
    {
        return _isExcluded[account];
    }

    /// @notice Returns the value of total fees
    /// @return The value of variable `_tFeeTotal`
    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    /// @notice Returns the reflection per token
    /// @dev Returns the reflections per tokens depending on `deductTransferFee`
    /// @param tAmount The value of token's amount
    /// @param deductTransferFee The boolean value for gets the desired result (with/without fee)
    /// @return The calculated value of reflections (with or without transfer fee)
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        external
        view
        returns (uint256)
    {
        require(tAmount <= _T_Total, "The amount must be less than total supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount, transferFee);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(
                tAmount,
                transferFee
            );
            return rTransferAmount;
        }
    }

    /// @notice Returns the balance of account
    /// @dev Returns the account's balance depending on result if account is excluded from rewards
    /// @param account The address of account
    /// @return The balance of account
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /// @notice Returns the value of decimals
    /// @return The set value of variable `_decimals`
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Returns the tokens per reflections
    /// @dev Returns the tokens per reflections as a result of calculation
    /// @param rAmount The value of amount for calculation
    /// @return Result of calculation
    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "The amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    /// @notice Returns the value of token's total supply
    /// @return The value of variable `_T_Total`
    function totalSupply() public pure override returns (uint256) {
        return _T_Total;
    }

    /// @dev Transfers the amount, adds the liquidity, transfer will take fee
    /// @param from The address of account that transfers the amount
    /// @param to The address of account that receives the transfer's amount
    /// @param amount The value of amount for transfer
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override checkZeroAddress(from) checkZeroAddress(to) {
        if (amount == 0) revert ZeroValue();
        if (from != owner() && to != owner()) {
            require(
                amount <= maxTxAmount,
                "Transfer's amount exceeds the maxTxAmount"
            );
        }
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= maxTxAmount) {
            contractTokenBalance = maxTxAmount;
        }
        bool overMinTokenBalance = contractTokenBalance >=
            _numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !_inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            _swapAndLiquify(_numTokensSellToAddToLiquidity);
        }
        bool takeFee = true;
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
    }

    /// @dev Reflects the fee. Changes the values of `_rTotal` and `_tFeeTotal`
    /// @param rFee The value for subtract from `_rTotal`
    /// @param tFee The value for add to `_tFeeTotal`
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
        emit ReflectFee(_rTotal, _tFeeTotal);
    }

    /// @dev Should increase the reflection and transfer balance of SC by `rLiquidity` and `tLiquidity`
    /// @param tLiquidity The value for correct calculating the values of variables
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + tLiquidity;
        emit TakeLiquidity(_rOwned[address(this)], _tOwned[address(this)]);
    }

    /// @dev Removes all fee. Changes the values of variables relationed swap and transfer fee
    function _removeAllFee() private {
        FeeValues memory empty = FeeValues(0, 0);
        _previousSwapFee = swapFee;
        _previousTransferFee = transferFee;
        swapFee = empty;
        transferFee = empty;
        emit RemoveAllFee(
            _previousSwapFee,
            _previousTransferFee,
            swapFee,
            transferFee
        );
    }

    /// @dev Restores all fee. Changes the values of variables relationed swap and transfer fee
    function _restoreAllFee() private {
        swapFee = _previousSwapFee;
        transferFee = _previousTransferFee;
        emit RestoreAllFee(swapFee, transferFee);
    }

    /// @dev Should swap tokens, execute liquify. Split the balance, exchange tokens for ETH and add liquidity
    /// @param contractTokenBalance The contract's balance
    function _swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;
        uint256 initialBalance = address(this).balance;
        _swapTokensForETH(half);
        uint256 newBalance = address(this).balance - initialBalance;
        _addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    /// @dev Should swap tokens for chain's native token. Add approve, generate uniswap pair and swap
    /// @param tokenAmount The amount of tokens for swap
    function _swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /// @dev Should add liquidity. Add approve and liquidity in ETH tokens
    /// @param tokenAmount The amount of tokens for approve and liquidity
    /// @param ethAmount The amount of ETH for correct add liquidity
    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        ) = uniswapV2Router.addLiquidityETH{value: ethAmount}(
                address(this),
                tokenAmount,
                0,
                0,
                owner(),
                block.timestamp
            );
        emit AddLiquidity(amountToken, amountETH, liquidity);
    }

    /// @dev Should transfer tokens. This method is responsible for taking all fee, if `takeFee` is true
    /// @param sender The address of account that transfers the amount
    /// @param recipient The address of account that receives the transfer's amount
    /// @param amount The value of amount for transfer
    /// @param takeFee The value that indicates the possibility of deducting fee
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) _removeAllFee();
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        if (!takeFee) _restoreAllFee();
    }

    /// @dev Standard transfer amount
    /// @param sender The address of account that transfers the amount
    /// @param recipient The address of account that receives the transfer's amount
    /// @param tAmount The value of amount for transfer
    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        FeeValues memory fees = _getFeeAmountBasedOnTransferType(
            sender,
            recipient
        );
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount, fees);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferStandard(
            sender,
            recipient,
            _rOwned[sender],
            _rOwned[recipient]
        );
    }

    /// @dev Transfer the amount if a recipient is excluded from rewards
    /// @param sender The address of account that transfers the amount
    /// @param recipient The address of account that receives the transfer's amount
    /// @param tAmount The value of amount for transfer
    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        FeeValues memory fees = _getFeeAmountBasedOnTransferType(
            sender,
            recipient
        );
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount, fees);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferToExcluded(
            sender,
            recipient,
            _rOwned[sender],
            _tOwned[recipient],
            _rOwned[recipient]
        );
    }

    /// @dev Transfer the amount if a sender is excluded from rewards
    /// @param sender The address of account that transfers the amount
    /// @param recipient The address of account that receives the transfer's amount
    /// @param tAmount The value of amount for transfer
    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        FeeValues memory fees = _getFeeAmountBasedOnTransferType(
            sender,
            recipient
        );
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount, fees);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferFromExcluded(
            sender,
            recipient,
            _tOwned[sender],
            _rOwned[sender],
            _rOwned[recipient]
        );
    }

    /// @dev Transfer the amount if both accounts are excluded from rewards
    /// @param sender The address of account that transfers the amount
    /// @param recipient The address of account that receives the transfer's amount
    /// @param tAmount The value of amount for transfer
    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        FeeValues memory fees = _getFeeAmountBasedOnTransferType(
            sender,
            recipient
        );
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount, fees);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferFromSender(sender, _tOwned[sender], _rOwned[sender]);
        emit TransferToRecipient(
            recipient,
            _tOwned[recipient],
            _rOwned[recipient]
        );
    }
  
    /// @dev Returns the calculated Transfer and Reflection values
    /// @param tAmount The value of total transfer amount
    /// @param fees The input's values of fee for correct calculating
    /// @return rAmount The value of reflection tokens
    /// @return rTransferAmount The value of reflection transfer amount
    /// @return rFee The value of reflection fees
    /// @return tTransferAmount The value of transfer amount
    /// @return tFee The value of transfer fees
    /// @return tLiquidity The value of transfer liquidity
    function _getValues(uint256 tAmount, FeeValues memory fees)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getTValues(tAmount, fees);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    /// @dev Returns the calculated current rate of token
    /// @return Current rate by simple formula (reflection remaining supply / total remaining supply)
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    /// @dev Returns the current supply depending on the `r` and `t` values
    /// @return `r` and `t` values of supply
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _T_Total;
        for (uint256 i; i < _excluded.length;) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _T_Total);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
            unchecked {
                i++;
            }
        }
        if (rSupply < _rTotal / _T_Total) return (_rTotal, _T_Total);
        return (rSupply, tSupply);
    }

    /// @dev Returns the fee based on the transfer type
    /// @param sender The address of sender's account
    /// @param recipient The address of recipient's account
    /// @return The fee value
    function _getFeeAmountBasedOnTransferType(address sender, address recipient)
        private
        view
        returns (FeeValues memory)
    {
        if (
            sender == address(uniswapV2Pair) ||
            recipient == address(uniswapV2Pair)
        ) {
            // buy/sell add/remove liquidity action
            return swapFee;
        } else {
            // simple transfer action
            return transferFee;
        }
    }

    /// @dev Calculates the amount of fee
    /// @param _amount The amount to take fee from
    /// @param _fee The percents of fee
    /// @return The calculated value of fee
    function _calculateFee(uint256 _amount, uint256 _fee)
        private
        pure
        returns (uint256)
    {
        return (_amount * _fee) / 10 ** 2;
    }

    /// @dev Returns Transfer values
    /// @param tAmount The value of total transfer amount
    /// @param fees The input's values of fee for correct calculating
    /// @return tTransferAmount The value of transfer amount
    /// @return tFee The value of transfer fees
    /// @return tLiquidity The value of transfer liquidity
    function _getTValues(uint256 tAmount, FeeValues memory fees)
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = _calculateFee(tAmount, fees._taxFee);
        uint256 tLiquidity = _calculateFee(tAmount, fees._liquidityFee);
        uint256 tTransferAmount = tAmount - tFee - tLiquidity;
        return (tTransferAmount, tFee, tLiquidity);
    }

    /// @dev Returns Reflection values
    /// @param tAmount The value of transfer amount to calculate `rAmount`
    /// @param tFee The value of taxFee to calculate `rFee`
    /// @param tLiquidity The value of liquidityFee to calculate `rLiquidity`
    /// @param currentRate The value of current rate to calculate the return's values
    /// @return rAmount The value of reflection tokens
    /// @return rTransferAmount The value of reflection transfer amount
    /// @return rFee The value of reflection fees
    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rTransferAmount = rAmount - rFee - rLiquidity;
        return (rAmount, rTransferAmount, rFee);
    }
}
