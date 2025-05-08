// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title FlashExchange
 * @dev 闪兑合约，只允许卖币，价格每天自动上涨0.5%
 */
contract FlashExchange is AccessControl, ReentrancyGuard {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // 代币合约地址
    address public mainToken;
    address public usdtToken;
    
    // 价格相关
    uint256 public currentPrice;      // 当前价格（以USDT计价，18位小数）
    uint256 public initialPrice;      // 初始价格
    uint256 public lastPriceUpdateTime; // 上次价格更新时间
    uint256 public constant DAILY_INCREASE_RATE = 50; // 每日增长率 0.5% = 50/10000
    uint256 public constant RATE_DENOMINATOR = 10000;
    
    // 一天的秒数
    uint256 public constant ONE_DAY_SECONDS = 86400; // 24 * 60 * 60
    
    // 事件
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 usdtAmount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PriceAutoIncreased(uint256 oldPrice, uint256 newPrice);
    
    /**
     * @dev 构造函数
     * @param _mainToken 主币合约地址
     * @param _usdtToken USDT合约地址
     * @param _initialPrice 初始价格（以USDT计价，18位小数）
     */
    constructor(
        address _mainToken,
        address _usdtToken,
        uint256 _initialPrice
    ) {
        require(_mainToken != address(0), "Main token address cannot be zero");
        require(_usdtToken != address(0), "USDT token address cannot be zero");
        require(_initialPrice > 0, "Initial price must be greater than zero");
        
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        // 设置代币地址
        mainToken = _mainToken;
        usdtToken = _usdtToken;
        
        // 设置初始价格
        initialPrice = _initialPrice;
        currentPrice = _initialPrice;
        
        // 设置价格更新时间
        lastPriceUpdateTime = block.timestamp;
    }
    
    /**
     * @dev 卖出主币获取USDT
     * @param tokenAmount 主币数量
     */
    function sellTokens(uint256 tokenAmount) external nonReentrant {
        require(tokenAmount > 0, "Token amount must be greater than zero");
        
        // 更新价格（如果需要）
        _updatePriceIfNeeded();
        
        // 计算可以获得的USDT数量
        uint256 usdtAmount = (tokenAmount * currentPrice) / 10**18;
        
        // 检查合约中是否有足够的USDT
        require(IERC20(usdtToken).balanceOf(address(this)) >= usdtAmount, "Insufficient USDT in contract");
        
        // 转移主币到合约
        bool success = IERC20(mainToken).transferFrom(msg.sender, address(this), tokenAmount);
        require(success, "Token transfer failed");
        
        // 转移USDT给卖出者
        success = IERC20(usdtToken).transfer(msg.sender, usdtAmount);
        require(success, "USDT transfer failed");
        
        emit TokensSold(msg.sender, tokenAmount, usdtAmount);
    }
    
    /**
     * @dev 手动更新价格
     * @param newPrice 新价格
     */
    function updatePrice(uint256 newPrice) external onlyRole(ADMIN_ROLE) {
        require(newPrice > 0, "New price must be greater than zero");
        
        uint256 oldPrice = currentPrice;
        currentPrice = newPrice;
        lastPriceUpdateTime = block.timestamp;
        
        emit PriceUpdated(oldPrice, newPrice);
    }
    
    /**
     * @dev 获取当前价格
     * @return 当前价格
     */
    function getCurrentPrice() external view returns (uint256) {
        // 如果不需要更新价格，直接返回当前价格
        if (block.timestamp < lastPriceUpdateTime + ONE_DAY_SECONDS) {
            return currentPrice;
        }
        
        // 计算经过的天数
        uint256 daysPassed = (block.timestamp - lastPriceUpdateTime) / ONE_DAY_SECONDS;
        
        // 计算新价格
        uint256 newPrice = currentPrice;
        for (uint256 i = 0; i < daysPassed; i++) {
            newPrice = newPrice + (newPrice * DAILY_INCREASE_RATE) / RATE_DENOMINATOR;
        }
        
        return newPrice;
    }
    
    /**
     * @dev 内部函数：如果需要，更新价格
     */
    function _updatePriceIfNeeded() internal {
        // 检查是否需要更新价格（是否过了一天）
        if (block.timestamp >= lastPriceUpdateTime + ONE_DAY_SECONDS) {
            // 计算经过的天数
            uint256 daysPassed = (block.timestamp - lastPriceUpdateTime) / ONE_DAY_SECONDS;
            
            // 保存旧价格
            uint256 oldPrice = currentPrice;
            
            // 计算新价格
            for (uint256 i = 0; i < daysPassed; i++) {
                currentPrice = currentPrice + (currentPrice * DAILY_INCREASE_RATE) / RATE_DENOMINATOR;
            }
            
            // 更新价格更新时间
            lastPriceUpdateTime = block.timestamp;
            
            emit PriceAutoIncreased(oldPrice, currentPrice);
        }
    }
    
    /**
     * @dev 提取合约中的主币
     * @param to 接收地址
     * @param amount 提取数量
     */
    function withdrawMainToken(address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(to != address(0), "Cannot withdraw to zero address");
        uint256 tokenBalance = IERC20(mainToken).balanceOf(address(this));
        require(tokenBalance >= amount, "Insufficient token balance");
        
        bool success = IERC20(mainToken).transfer(to, amount);
        require(success, "Token transfer failed");
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
    
    /**
     * @dev 更新主币合约地址
     * @param _mainToken 新的主币合约地址
     */
    function updateMainToken(address _mainToken) external onlyRole(ADMIN_ROLE) {
        require(_mainToken != address(0), "Main token address cannot be zero");
        mainToken = _mainToken;
    }
    
    /**
     * @dev 更新USDT合约地址
     * @param _usdtToken 新的USDT合约地址
     */
    function updateUsdtToken(address _usdtToken) external onlyRole(ADMIN_ROLE) {
        require(_usdtToken != address(0), "USDT token address cannot be zero");
        usdtToken = _usdtToken;
    }
}