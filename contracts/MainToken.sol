// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title MainToken
 * @dev 主币合约，实现BEP-20标准，包含权限管理和交易逻辑
 */
contract MainToken is ERC20, AccessControl, Pausable {
    using SafeMath for uint256;
    
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUB_ADMIN_ROLE = keccak256("SUB_ADMIN_ROLE");
    
    // 交易状态
    bool public tradingEnabled = false;
    
    // 手续费率 (5%)
    uint256 public constant FEE_RATE = 500; // 基点，5% = 500/10000
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    // 手续费接收地址
    address public feeReceiver;
    
    // 白名单地址（免手续费）
    mapping(address => bool) public isWhitelisted;
    
    // 事件
    event TradingEnabled(bool enabled);
    event FeeReceiverUpdated(address indexed previousReceiver, address indexed newReceiver);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    
    /**
     * @dev 构造函数
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param initialSupply 初始供应量
     * @param distributor 分配地址数组
     * @param amounts 分配数量数组
     * @param _feeReceiver 手续费接收地址
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address[] memory distributor,
        uint256[] memory amounts,
        address _feeReceiver
    ) ERC20(name_, symbol_) {
        require(distributor.length == amounts.length, "Arrays length mismatch");
        require(distributor.length > 0, "No distribution specified");
        
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        // 设置手续费接收地址
        feeReceiver = _feeReceiver;
        
        // 铸造代币并分配
        _mint(address(this), initialSupply * 10**decimals());
        
        // 分配代币
        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < distributor.length; i++) {
            require(distributor[i] != address(0), "Cannot distribute to zero address");
            uint256 amount = amounts[i] * 10**decimals();
            _transfer(address(this), distributor[i], amount);
            totalDistributed = totalDistributed.add(amount);
        }
        
        // 验证分配总量
        require(totalDistributed == initialSupply * 10**decimals(), "Distribution amount mismatch");
        
        // 将创建者加入白名单
        isWhitelisted[msg.sender] = true;
        isWhitelisted[address(this)] = true;
        isWhitelisted[_feeReceiver] = true;
    }
    
    /**
     * @dev 重写transfer函数，添加手续费逻辑
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        return _transferWithFee(msg.sender, recipient, amount);
    }
    
    /**
     * @dev 重写transferFrom函数，添加手续费逻辑
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = allowance(sender, msg.sender);
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance.sub(amount));
        return _transferWithFee(sender, recipient, amount);
    }
    
    /**
     * @dev 内部转账函数，处理手续费逻辑
     */
    function _transferWithFee(address sender, address recipient, uint256 amount) internal whenNotPaused returns (bool) {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");
        
        // 检查交易是否启用
        if (!tradingEnabled) {
            require(
                isWhitelisted[sender] || isWhitelisted[recipient],
                "Trading not enabled yet"
            );
        }
        
        // 如果发送者或接收者在白名单中，则不收取手续费
        if (isWhitelisted[sender] || isWhitelisted[recipient]) {
            _transfer(sender, recipient, amount);
            return true;
        }
        
        // 计算手续费
        uint256 fee = amount.mul(FEE_RATE).div(FEE_DENOMINATOR);
        uint256 netAmount = amount.sub(fee);
        
        // 转账净额给接收者
        _transfer(sender, recipient, netAmount);
        
        // 转账手续费给手续费接收地址
        if (fee > 0) {
            _transfer(sender, feeReceiver, fee);
        }
        
        return true;
    }
    
    /**
     * @dev 启用或禁用交易
     * @param _enabled 是否启用
     */
    function setTradingEnabled(bool _enabled) external onlyRole(ADMIN_ROLE) {
        tradingEnabled = _enabled;
        emit TradingEnabled(_enabled);
    }
    
    /**
     * @dev 更新手续费接收地址
     * @param _newFeeReceiver 新的手续费接收地址
     */
    function setFeeReceiver(address _newFeeReceiver) external onlyRole(ADMIN_ROLE) {
        require(_newFeeReceiver != address(0), "Cannot set fee receiver to zero address");
        address oldFeeReceiver = feeReceiver;
        feeReceiver = _newFeeReceiver;
        emit FeeReceiverUpdated(oldFeeReceiver, _newFeeReceiver);
    }
    
    /**
     * @dev 更新白名单状态
     * @param _account 账户地址
     * @param _status 白名单状态
     */
    function updateWhitelist(address _account, bool _status) external onlyRole(ADMIN_ROLE) {
        isWhitelisted[_account] = _status;
        emit WhitelistUpdated(_account, _status);
    }
    
    /**
     * @dev 批量更新白名单状态
     * @param _accounts 账户地址数组
     * @param _status 白名单状态
     */
    function batchUpdateWhitelist(address[] calldata _accounts, bool _status) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < _accounts.length; i++) {
            isWhitelisted[_accounts[i]] = _status;
            emit WhitelistUpdated(_accounts[i], _status);
        }
    }
    
    /**
     * @dev 添加子管理员
     * @param _account 账户地址
     */
    function addSubAdmin(address _account) external onlyRole(ADMIN_ROLE) {
        grantRole(SUB_ADMIN_ROLE, _account);
    }
    
    /**
     * @dev 移除子管理员
     * @param _account 账户地址
     */
    function removeSubAdmin(address _account) external onlyRole(ADMIN_ROLE) {
        revokeRole(SUB_ADMIN_ROLE, _account);
    }
    
    /**
     * @dev 暂停所有转账
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复所有转账
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}