// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/automation/KeeperCompatible.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is
    IERC20Metadata,
    Pausable,
    ReentrancyGuard,
    KeeperCompatible,
    Ownable
{
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant PERCENTAGE_DENOMINATOR = 10000;
    uint256 public constant TOKEN_DECIMALS = 1e18;
    uint256 public constant TOKEN_public_DECIMALS = 1e24;

    string public override name;
    string public override symbol;
    uint256 private _decimals;

    uint256 private tSupply;
    uint256 public excludeDebasingSupply;

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => uint256) private _balances;

    uint256 private treasuryBalance;
    address public treasuryWallet;

    uint256 public sellTaxRate;
    uint256 public debaseRate;

    uint256 public tokenScalingFactor;
    uint256 public debaseDuration;

    uint256 public holdingLimit;

    mapping(address => bool) public lpPools;
    mapping(address => bool) public isExcludedFromDebasing;
    mapping(address => bool) public isExcludedFromHoldingLimit;

    mapping(address => bool) public treasuryOperator;

    uint256 public lastTimeStamp;

    event Burn(address indexed from, uint256 amount);
    event Mint(address indexed to, uint256 amount);

    modifier onlyTreasuryOperator() {
        require(treasuryOperator[msg.sender] || msg.sender == owner());
        _;
    }

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _tSupply,
        address _tokenOwner,
        uint256 _sellTaxRate,
        uint256 _debaseRate,
        address _treasuryWallet
    ) Ownable(msg.sender){
        name = _tokenName;
        symbol = _tokenSymbol;
        _decimals = 18;

        tSupply = _tSupply * TOKEN_DECIMALS;
        excludeDebasingSupply = tSupply;

        holdingLimit = (tSupply * 100) / PERCENTAGE_DENOMINATOR;

        sellTaxRate = _sellTaxRate;
        debaseRate = _debaseRate;

        tokenScalingFactor = TOKEN_DECIMALS;
        debaseDuration = 86400;
        treasuryBalance = 0;

        lastTimeStamp = block.timestamp;

        treasuryWallet = _treasuryWallet;

        _excludedFromDebasing(_tokenOwner, true);
        _excludedFromHoldingLimit(_tokenOwner, true);
        _excludedFromDebasing(treasuryWallet, true);
        _excludedFromHoldingLimit(treasuryWallet, true);

        _balances[_tokenOwner] = _fragmentToDebaseToken(tSupply);

        pause();

        emit Transfer(address(0), _tokenOwner, tSupply);
        transferOwnership(_tokenOwner);
    }

    receive() external payable {}

    function withdrawETH(address _to) external onlyOwner {
        require(_to != address(0), "Invalid address: zero address");
        (bool success, ) = payable(_to).call{value: address(this).balance}("");
        if(!success) {
            revert("Transfer Failed");
        }
    }

    function totalSupply() public view override returns (uint256) {
        return tSupply + treasuryBalance;
    }

    function decimals() external view override returns (uint8) {
        return uint8(_decimals);
    }

    function balanceOf(
        address _account
    ) public view override returns (uint256) {
        if (isExcludedFromDebasing[_account]) {
            if (_account == treasuryWallet) {
                return _treasuryBalanceOf();
            }
            return _debaseTokenToFragment(_balances[_account]);
        }
        return _debaseTokenToFragment(_balances[_account]);
    }

    function balanceOfUnderlying(address _account) public view returns (uint256) {
        return _balances[_account];
    }

    function transfer(address _recipient,uint256 _amount) public override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(
        address _holder,
        address _spender
    ) public view override returns (uint256) {
        return _allowances[_holder][_spender];
    }

    function approve(
        address _spender,
        uint256 _amount
    ) public override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _transfer(_sender, _recipient, _amount);
        _approve(_sender,
            msg.sender,
            _allowances[_sender][msg.sender].sub(
                _amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            _spender,
            _allowances[msg.sender][_spender].add(_addedValue)
        );
        return true;
    }

    function decreaseAllowance(address _spender,uint256 _subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, _spender,_allowances[msg.sender][_spender].sub(_subtractedValue,"ERC20: decreased allowance below zero")
        );
        return true;
    }

    function _approve(
        address _holder,
        address _spender,
        uint256 _amount
    ) public virtual {
        require(_holder != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_holder][_spender] = _amount;
        emit Approval(_holder, _spender, _amount);
    }

    function _mint(address _to, uint256 _amount) public {
        require(_to != address(0), "ERC20: mint to the zero address");

        tSupply += _amount;

        uint256 debaseTokenAmount = _fragmentToDebaseToken(_amount);
        if (isExcludedFromDebasing[_to]) {
            excludeDebasingSupply += _amount;
            debaseTokenAmount = _fragmentToDebaseToken(_amount);
        }

        _balances[_to] += debaseTokenAmount;

        emit Mint(_to, _amount);
        if (_to != treasuryWallet) {
            emit Transfer(address(0), _to, _amount);
        }
    }

    function _burn(address _from, uint256 _amount) public {
        require(_from != address(0), "ERC20: burn from the zero address");

        tSupply -= _amount;

        uint256 debaseTokenAmount = _fragmentToDebaseToken(_amount);
        if (isExcludedFromDebasing[_from]) {
            excludeDebasingSupply -= _amount;
            debaseTokenAmount = _fragmentToDebaseToken(_amount);
        }

        _balances[_from] -= debaseTokenAmount;

        emit Burn(_from, _amount);
        emit Transfer(_from, address(0), _amount);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) public whenNotPaused {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");

        if (balanceOf(_from) < _amount) {
            revert("Insufficient Funds For Transfer");
        }

        if (
            balanceOf(_to) >= holdingLimit && !isExcludedFromHoldingLimit[_to]
        ) {
            revert("Holding Tokens exceeded!");
        }

        uint256 amount = _amount;

        if (
            !isExcludedFromHoldingLimit[_to] &&
            balanceOf(_to) + amount > holdingLimit
        ) {
            amount = amount - (balanceOf(_to) + amount - holdingLimit);
        }

        uint256 debaseToken = _fragmentToDebaseToken(amount);
        if (isExcludedFromDebasing[_from]) {
            debaseToken = _fragmentToDebaseToken(amount);
        }

        uint256 sellTax = 0;

        if (_from != owner() && lpPools[_to]) {
            sellTax = (amount * sellTaxRate) / PERCENTAGE_DENOMINATOR;
        }

        uint256 amountAfterTax = amount - sellTax;
        uint256 debaseTokenAfterTax = _fragmentToDebaseToken(amountAfterTax);
        uint256 adjustedBalance = isExcludedFromDebasing[_to]
            ? _fragmentToDebaseToken(amountAfterTax)
            : debaseTokenAfterTax;

        _balances[_from] -= debaseToken;

        if (isExcludedFromDebasing[_to]) {
            _balances[_to] += adjustedBalance;
        } else {
            _balances[_to] += debaseTokenAfterTax;
        }

        treasuryBalance += sellTax;
        tSupply -= sellTax;

        emit Transfer(_from, _to, amountAfterTax);

        if (sellTax > 0) {
            emit Transfer(_from, treasuryWallet, sellTax);
        }

        // Tracking of excluded Debasing
        if (!isExcludedFromDebasing[_from] && isExcludedFromDebasing[_to]) {
            excludeDebasingSupply += amountAfterTax;
        } else if (isExcludedFromDebasing[_from] && !isExcludedFromDebasing[_to]) {
            excludeDebasingSupply -= amountAfterTax;
        } else if (isExcludedFromDebasing[_from] && isExcludedFromDebasing[_to]) {
            // If both are excluded, no need to adjust excludeDebasingSupply
        } else {
            // If both are not excluded, no need to adjust excludeDebasingSupply
        }

        if (treasuryBalance > 0) {
            _sendTokensTreasuryWallet(treasuryBalance, treasuryWallet);
        }
    }

    function _sendTokensTreasuryWallet(uint256 _amount, address _to) public {
        require(treasuryBalance >= _amount, "Insufficient Balance to claim");
        treasuryBalance -= _amount;
        _mint(_to, _amount);
    }

    function claimFromTreasury(
        address _to,
        uint256 _amount
    ) external whenNotPaused onlyTreasuryOperator {
        if (treasuryBalance > 0) {
            _sendTokensTreasuryWallet(treasuryBalance, treasuryWallet);
        }

        if (isExcludedFromDebasing[_to]) {
            _balances[_to] += _fragmentToDebaseToken(_amount);
        } else {
            _balances[_to] += _fragmentToDebaseToken(_amount);
            // adjusting the debasing supply.
            excludeDebasingSupply -= _amount;
        }

        _balances[treasuryWallet] -= _fragmentToDebaseToken(_amount);

        emit Transfer(treasuryWallet, _to, _amount);
    }

    function checkUpkeep(
        bytes calldata checkData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > debaseDuration;
        performData = checkData;

        return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        //We highly recommend revalidating the upkeep in the performUpkeep function
        require(
            (block.timestamp - lastTimeStamp) > debaseDuration,
            "KeepUp requirement is not met!"
        );

        require(tSupply >= excludeDebasingSupply, "tSupply must be greater than or equal to excludeDebasingSupply");

         _debase();

        lastTimeStamp = block.timestamp;
    }

    function _debase() private whenNotPaused {
        
        uint256 ratio = (debaseRate * TOKEN_DECIMALS) / PERCENTAGE_DENOMINATOR;

        uint256 preDebasingSupply = tSupply - excludeDebasingSupply;

        tokenScalingFactor =
            (tokenScalingFactor * (TOKEN_DECIMALS - ratio)) /
            TOKEN_DECIMALS;
        uint256 debasingSupply = (preDebasingSupply *
            (TOKEN_DECIMALS - ratio)) / TOKEN_DECIMALS;

        uint256 debasedTokenAmount = preDebasingSupply - debasingSupply;

        treasuryBalance += debasedTokenAmount;
        tSupply -= debasedTokenAmount;
    }

    // 10^24 --> 10^18
    function _debaseTokenToFragment(uint256 _debaseToken) public view returns (uint256) {
        return _debaseToken.mul(tokenScalingFactor).div(TOKEN_public_DECIMALS);
    }
    
    function _fragmentToDebaseToken(uint256 _value) public pure returns (uint256) {
        return _value.mul(TOKEN_public_DECIMALS).div(TOKEN_DECIMALS);
    }

    /*
     * Contract Owner Settings
     */

    function updateSellTaxRate(uint256 _sellTaxRate) external onlyOwner {
        // 100 : 1%
        require(
            _sellTaxRate <= 5000,
            "Rate should be less than PERCENTAGE_DENOMINATOR"
        );
        sellTaxRate = _sellTaxRate;
    }

    function updateHoldingLimit(uint256 _holdingLimit) external onlyOwner {
        holdingLimit = _holdingLimit;
    }

    function updateDebaseRate(uint256 _debaseRate) external onlyOwner {
        // 100 : 1%
        require(_debaseRate <= PERCENTAGE_DENOMINATOR,"Rate should be less than PERCENTAGE_DENOMINATOR");
        debaseRate = _debaseRate;
    }

    function updateDebaseDuration(uint256 _debaseDuration) external onlyOwner {
        debaseDuration = _debaseDuration;
    }

    function updateLPPool(address _lpPool, bool _isLPPool) external onlyOwner {
        require(_lpPool != address(0), "LP Pool address shouldn't be zero!");
        lpPools[_lpPool] = _isLPPool;
        _excludedFromDebasing(_lpPool, _isLPPool);
        _excludedFromHoldingLimit(_lpPool, _isLPPool);
    }

    function updateTreasuryOperator( address _addr,  bool _isOperator) external onlyOwner {
        require(_addr != address(0), "Operator shouldn't be zero.");
        treasuryOperator[_addr] = _isOperator;
    }

    function _excludedFromDebasing(address _account,bool _isExcluded) public {
        
        require(_account != address(0), "Account shouldn't be zero.");
        bool prevIsExcluded = isExcludedFromDebasing[_account];
        uint256 prevBalance = balanceOf(_account);

        
        if (prevIsExcluded != _isExcluded) {
            isExcludedFromDebasing[_account] = _isExcluded;
    
            if (!prevIsExcluded && _isExcluded) {
  
                excludeDebasingSupply += prevBalance;
                
            } else if (prevIsExcluded && !_isExcluded) {

                excludeDebasingSupply -= prevBalance;
            }
        }
    }

    function multiExcludedFromDebasing(
        address[] memory _accounts,
        bool _isExcluded
    ) public onlyOwner {
        for (uint i = 0; i < _accounts.length; ++i) {
            require(_accounts[i] != treasuryWallet, "Treasury wallet cannot be included in debasing");
            _excludedFromDebasing(_accounts[i], _isExcluded);
        }
    }

    function _excludedFromHoldingLimit(address _account,bool _isExcluded) public {
        
        require(_account != address(0), "Account shouldn't be zero.");
        isExcludedFromHoldingLimit[_account] = _isExcluded;
    }

    function multiExcludedFromHoldingLimit(address[] memory _accounts, bool _isExcluded) public onlyOwner {
        
        for (uint i = 0; i < _accounts.length; ++i) {
            _excludedFromHoldingLimit(_accounts[i], _isExcluded);
        }
    }

    function multiAirdropTokenRequested(
        address[] memory _airdroppers,
        uint256[] memory _amounts
    ) external nonReentrant whenNotPaused {
        require(_airdroppers.length == _amounts.length, "Arrays length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; ++i) {
            totalAmount += _amounts[i];
        }
    
        require(balanceOf(msg.sender) >= totalAmount, "Insufficient balance");

        for (uint256 i = 0; i < _airdroppers.length; ++i) {
            if (balanceOf(msg.sender) > _amounts[i]) {
                if (isExcludedFromDebasing[msg.sender]) {
                    _balances[msg.sender] -= _fragmentToDebaseToken(
                        _amounts[i]
                    );
                    excludeDebasingSupply -= _amounts[i];
                } else {
                    _balances[msg.sender] -= _fragmentToDebaseToken(
                        _amounts[i]
                    );
                }

                if (isExcludedFromDebasing[_airdroppers[i]]) {
                    _balances[
                        _airdroppers[i]
                    ] += _fragmentToDebaseToken(_amounts[i]);
                    excludeDebasingSupply += _amounts[i];
                } else {
                    _balances[_airdroppers[i]] += _fragmentToDebaseToken(
                        _amounts[i]
                    );
                }

                emit Transfer(msg.sender, _airdroppers[i], _amounts[i]);
            }
        }
    }

    function setLastTime() external onlyOwner {
        require(lastTimeStamp <= block.timestamp);
        lastTimeStamp = block.timestamp;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /*
     * View functions
     */
    function getOwner() external view returns (address) {
        return owner();
    }

    function _treasuryBalanceOf() public view returns (uint256) {
        uint256 realBalance = _debaseTokenToFragment(
            _balances[treasuryWallet]
        );
        return treasuryBalance + realBalance;
    }
}
