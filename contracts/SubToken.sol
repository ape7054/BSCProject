// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SubToken
 * @dev 子币合约，实现BEP-20标准，固定价格为1 USDT
 */
contract SubToken is ERC20, AccessControl, Pausable {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // 固定价格 (1 USDT)
    uint256 public constant TOKEN_PRICE = 1 * 10**18; // 1 USDT，假设USDT有18位小数
    
    // USDT合约地址
    address public usdtToken;
    
    // 事件
    event TokensPurchased(address indexed buyer, uint256 usdtAmount, uint256 tokensAmount);
    event TokensRedeemed(address indexed seller, uint256 tokensAmount, uint256 usdtAmount);
    
    /**
     * @dev 构造函数
     * @param name_ 代币名称
     * @param symbol_ 代币符号
     * @param initialSupply 初始供应量
     * @param _usdtToken USDT合约地址
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address _usdtToken
    ) ERC20(name_, symbol_) {
        require(_usdtToken != address(0), "USDT token address cannot be zero");
        
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        
        // 设置USDT合约地址
        usdtToken = _usdtToken;
        
        // 铸造初始代币
        _mint(msg.sender, initialSupply * 10**decimals());
    }
    
    /**
     * @dev 使用USDT购买代币
     * @param usdtAmount USDT数量
     */
    function purchaseTokens(uint256 usdtAmount) external whenNotPaused {
        require(usdtAmount > 0, "USDT amount must be greater than zero");
        
        // 计算可以购买的代币数量
        uint256 tokensAmount = (usdtAmount * 10**decimals()) / TOKEN_PRICE;
        
        // 转移USDT到合约
        bool success = IERC20(usdtToken).transferFrom(msg.sender, address(this), usdtAmount);
        require(success, "USDT transfer failed");
        
        // 铸造代币给购买者
        _mint(msg.sender, tokensAmount);
        
        emit TokensPurchased(msg.sender, usdtAmount, tokensAmount);
    }
    
    /**
     * @dev 赎回代币获取USDT
     * @param tokensAmount 代币数量
     */
    function redeemTokens(uint256 tokensAmount) external whenNotPaused {
        require(tokensAmount > 0, "Token amount must be greater than zero");
        require(balanceOf(msg.sender) >= tokensAmount, "Insufficient token balance");
        
        // 计算可以赎回的USDT数量
        uint256 usdtAmount = (tokensAmount * TOKEN_PRICE) / 10**decimals();
        
        // 检查合约中是否有足够的USDT
        require(IERC20(usdtToken).balanceOf(address(this)) >= usdtAmount, "Insufficient USDT in contract");
        
        // 销毁代币
        _burn(msg.sender, tokensAmount);
        
        // 转移USDT给赎回者
        bool success = IERC20(usdtToken).transfer(msg.sender, usdtAmount);
        require(success, "USDT transfer failed");
        
        emit TokensRedeemed(msg.sender, tokensAmount, usdtAmount);
    }
    
    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    
    /**
     * @dev 销毁代币
     * @param amount 销毁数量
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev 从指定地址销毁代币
     * @param account 账户地址
     * @param amount 销毁数量
     */
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance(account, msg.sender);
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, msg.sender, currentAllowance - amount);
        _burn(account, amount);
    }
    
    /**
     * @dev 更新USDT合约地址
     * @param _usdtToken 新的USDT合约地址
     */
    function updateUsdtToken(address _usdtToken) external onlyRole(ADMIN_ROLE) {
        require(_usdtToken != address(0), "USDT token address cannot be zero");
        usdtToken = _usdtToken;
    }
    
    /**
     * @dev 添加铸币者角色
     * @param account 账户地址
     */
    function addMinter(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
    }
    
    /**
     * @dev 移除铸币者角色
     * @param account 账户地址
     */
    function removeMinter(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
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
    
    /**
     * @dev 提取合约中的USDT
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawUsdt(address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(to != address(0), "Cannot withdraw to zero address");
        uint256 usdtBalance = IERC20(usdtToken).balanceOf(address(this));
        require(usdtBalance >= amount, "Insufficient USDT balance");
        
        bool success = IERC20(usdtToken).transfer(to, amount);
        require(success, "USDT transfer failed");
    }
}

// USDT接口
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}