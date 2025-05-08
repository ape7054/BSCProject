// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GridSystem
 * @dev 格子系统合约，实现格子购买、收益分配和提现功能
 */
contract GridSystem is AccessControl, ReentrancyGuard {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant WHEEL_ROLE = keccak256("WHEEL_ROLE");
    
    // 代币合约地址
    address public mainToken;
    address public usdtToken;
    
    // 格子等级定义
    enum GridLevel { A, B, C, D, E, A1, B1, C1, D1, E1 }
    
    // 格子结构
    struct Grid {
        uint256 id;           // 格子ID
        address owner;        // 所有者
        uint256 price;        // 价格（USDT）
        GridLevel level;      // 等级
        uint256 staticIncome; // 静态收益
        uint256 wheelIncome;  // 转盘收益
        uint256 totalIncome;  // 总收益
        uint256 purchaseTime; // 购买时间
        uint256 lastSpinTime; // 上次转盘时间
        bool isActive;        // 是否激活
    }
    
    // 用户结构
    struct User {
        address userAddress;      // 用户地址
        address referrer;         // 推荐人
        address[] directReferrals; // 直推用户
        uint256[] ownedGrids;     // 拥有的格子ID
        uint256 totalInvestment;  // 总投资
        uint256 totalEarnings;    // 总收益
        uint256 lastAirdropTime;  // 上次空投时间
    }
    
    // 格子价格配置
    mapping(GridLevel => uint256) public gridPrices;
    
    // 格子映射
    mapping(uint256 => Grid) public grids;
    
    // 用户映射
    mapping(address => User) public users;
    
    // 用户推荐关系映射
    mapping(address => address) public referrers;
    
    // 格子ID计数器
    uint256 public gridIdCounter;
    
    // 手续费率 (5%)
    uint256 public constant FEE_RATE = 500; // 基点，5% = 500/10000
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    // 推荐奖励比例
    uint256 public constant DIRECT_REFERRAL_RATE = 2000; // 20%
    uint256 public constant INDIRECT_REFERRAL_RATE = 1000; // 10%
    
    // 重新激活阈值
    uint256 public constant REACTIVATION_THRESHOLD = 3; // 3倍
    
    // 重新激活成本
    uint256 public constant REACTIVATION_USDT_RATE = 5000; // 50%
    
    // 事件
    event GridPurchased(address indexed buyer, uint256 gridId, GridLevel level, uint256 price);
    event GridReactivated(address indexed owner, uint256 gridId, uint256 usdtCost, uint256 tokenCost);
    event EarningsWithdrawn(address indexed user, uint256 amount, uint256 fee);
    event ReferralRewardPaid(address indexed referrer, address indexed buyer, uint256 amount, bool isDirect);
    
    /**
     * @dev 构造函数
     * @param _mainToken 主币合约地址
     * @param _usdtToken USDT合约地址
     */
    constructor(
        address _mainToken,
        address _usdtToken
    ) {
        require(_mainToken != address(0), "Main token address cannot be zero");
        require(_usdtToken != address(0), "USDT token address cannot be zero");
        
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        // 设置代币地址
        mainToken = _mainToken;
        usdtToken = _usdtToken;
        
        // 初始化格子价格
        gridPrices[GridLevel.A] = 100 * 10**18; // 100 USDT
        gridPrices[GridLevel.B] = 200 * 10**18; // 200 USDT
        gridPrices[GridLevel.C] = 300 * 10**18; // 300 USDT
        gridPrices[GridLevel.D] = 400 * 10**18; // 400 USDT
        gridPrices[GridLevel.E] = 500 * 10**18; // 500 USDT
        gridPrices[GridLevel.A1] = 100 * 10**18; // 100 USDT (与A相同)
        gridPrices[GridLevel.B1] = 200 * 10**18; // 200 USDT (与B相同)
        gridPrices[GridLevel.C1] = 300 * 10**18; // 300 USDT (与C相同)
        gridPrices[GridLevel.D1] = 400 * 10**18; // 400 USDT (与D相同)
        gridPrices[GridLevel.E1] = 500 * 10**18; // 500 USDT (与E相同)
    }
    
    /**
     * @dev 购买格子
     * @param level 格子等级
     * @param referrerAddress 推荐人地址
     */
    function purchaseGrid(GridLevel level, address referrerAddress) external nonReentrant {
        require(gridPrices[level] > 0, "Invalid grid level");
        
        // 获取格子价格
        uint256 price = gridPrices[level];
        
        // 检查用户是否有足够的USDT
        require(IERC20(usdtToken).balanceOf(msg.sender) >= price, "Insufficient USDT balance");
        
        // 转移USDT到合约
        bool success = IERC20(usdtToken).transferFrom(msg.sender, address(this), price);
        require(success, "USDT transfer failed");
        
        // 创建新格子
        uint256 gridId = gridIdCounter++;
        grids[gridId] = Grid({
            id: gridId,
            owner: msg.sender,
            price: price,
            level: level,
            staticIncome: 0,
            wheelIncome: 0,
            totalIncome: 0,
            purchaseTime: block.timestamp,
            lastSpinTime: 0,
            isActive: true
        });
        
        // 更新用户信息
        if (users[msg.sender].userAddress == address(0)) {
            // 新用户
            users[msg.sender].userAddress = msg.sender;
            users[msg.sender].ownedGrids = new uint256[](0);
            users[msg.sender].directReferrals = new address[](0);
        }
        
        // 添加格子到用户拥有的格子列表
        users[msg.sender].ownedGrids.push(gridId);
        users[msg.sender].totalInvestment += price;
        
        // 处理推荐关系
        if (referrerAddress != address(0) && referrerAddress != msg.sender && users[referrerAddress].userAddress != address(0)) {
            // 如果是新用户或者还没有推荐人
            if (users[msg.sender].referrer == address(0)) {
                users[msg.sender].referrer = referrerAddress;
                referrers[msg.sender] = referrerAddress;
                users[referrerAddress].directReferrals.push(msg.sender);
            }
            
            // 计算直推奖励
            address directReferrer = users[msg.sender].referrer;
            if (directReferrer != address(0)) {
                // 检查直推人是否购买过该格子
                bool hasGrid = false;
                for (uint256 i = 0; i < users[directReferrer].ownedGrids.length; i++) {
                    if (grids[users[directReferrer].ownedGrids[i]].level == level) {
                        hasGrid = true;
                        break;
                    }
                }
                
                if (hasGrid) {
                    uint256 directReward = (price * DIRECT_REFERRAL_RATE) / FEE_DENOMINATOR;
                    IERC20(usdtToken).transfer(directReferrer, directReward);
                    users[directReferrer].totalEarnings += directReward;
                    emit ReferralRewardPaid(directReferrer, msg.sender, directReward, true);
                }
            }
            
            // 计算间推奖励
            address indirectReferrer = users[directReferrer].referrer;
            if (indirectReferrer != address(0)) {
                // 检查间推人是否购买过该格子
                bool hasGrid = false;
                for (uint256 i = 0; i < users[indirectReferrer].ownedGrids.length; i++) {
                    if (grids[users[indirectReferrer].ownedGrids[i]].level == level) {
                        hasGrid = true;
                        break;
                    }
                }
                
                if (hasGrid) {
                    uint256 indirectReward = (price * INDIRECT_REFERRAL_RATE) / FEE_DENOMINATOR;
                    IERC20(usdtToken).transfer(indirectReferrer, indirectReward);
                    users[indirectReferrer].totalEarnings += indirectReward;
                    emit ReferralRewardPaid(indirectReferrer, msg.sender, indirectReward, false);
                }
            }
        }
        
        emit GridPurchased(msg.sender, gridId, level, price);
    }
    
    /**
     * @dev 添加静态收益
     * @param gridId 格子ID
     * @param amount 收益金额
     */
    function addStaticIncome(uint256 gridId, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(grids[gridId].isActive, "Grid is not active");
        
        grids[gridId].staticIncome += amount;
        grids[gridId].totalIncome += amount;
        
        // 检查是否需要重新激活
        _checkReactivation(gridId);
    }
    
    /**
     * @dev 添加转盘收益
     * @param gridId 格子ID
     * @param amount 收益金额
     */
    function addWheelIncome(uint256 gridId, uint256 amount) external onlyRole(WHEEL_ROLE) {
        require(grids[gridId].isActive, "Grid is not active");
        
        grids[gridId].wheelIncome += amount;
        grids[gridId].totalIncome += amount;
        grids[gridId].lastSpinTime = block.timestamp;
        
        // 检查是否需要重新激活
        _checkReactivation(gridId);
    }
    
    /**
     * @dev 提现收益
     * @param gridId 格子ID
     */
    function withdrawEarnings(uint256 gridId) external nonReentrant {
        require(grids[gridId].owner == msg.sender, "Not the grid owner");
        require(grids[gridId].isActive, "Grid is not active");
        require(grids[gridId].totalIncome > 0, "No earnings to withdraw");
        
        // 计算可提现金额
        uint256 amount = grids[gridId].totalIncome;
        
        // 计算手续费
        uint256 fee = (amount * FEE_RATE) / FEE_DENOMINATOR;
        uint256 netAmount = amount - fee;
        
        // 重置收益
        grids[gridId].staticIncome = 0;
        grids[gridId].wheelIncome = 0;
        grids[gridId].totalIncome = 0;
        
        // 转移主币给用户
        bool success = IERC20(mainToken).transfer(msg.sender, netAmount);
        require(success, "Token transfer failed");
        
        emit EarningsWithdrawn(msg.sender, netAmount, fee);
    }
    
    /**
     * @dev 重新激活格子
     * @param gridId 格子ID
     */
    function reactivateGrid(uint256 gridId) external nonReentrant {
        require(grids[gridId].owner == msg.sender, "Not the grid owner");
        require(!grids[gridId].isActive, "Grid is already active");
        
        // 计算重新激活成本
        uint256 usdtCost = (grids[gridId].price * REACTIVATION_USDT_RATE) / FEE_DENOMINATOR;
        
        // 计算等值主币
        uint256 tokenCost = usdtCost; // 假设1:1兑换，实际应根据当前汇率计算
        
        // 检查用户是否有足够的USDT和主币
        require(IERC20(usdtToken).balanceOf(msg.sender) >= usdtCost, "Insufficient USDT balance");
        require(IERC20(mainToken).balanceOf(msg.sender) >= tokenCost, "Insufficient token balance");
        
        // 转移USDT和主币到合约
        bool success = IERC20(usdtToken).transferFrom(msg.sender, address(this), usdtCost);
        require(success, "USDT transfer failed");
        
        success = IERC20(mainToken).transferFrom(msg.sender, address(this), tokenCost);
        require(success, "Token transfer failed");
        
        // 重新激活格子
        grids[gridId].isActive = true;
        grids[gridId].staticIncome = 0;
        grids[gridId].wheelIncome = 0;
        grids[gridId].totalIncome = 0;
        
        emit GridReactivated(msg.sender, gridId, usdtCost, tokenCost);
    }
    
    /**
     * @dev 检查是否需要重新激活
     * @param gridId 格子ID
     */
    function _checkReactivation(uint256 gridId) internal {
        if (grids[gridId].totalIncome >= grids[gridId].price * REACTIVATION_THRESHOLD) {
            grids[gridId].isActive = false;
        }
    }
    
    /**
     * @dev 获取用户拥有的格子
     * @param user 用户地址
     * @return 格子ID数组
     */
    function getUserGrids(address user) external view returns (uint256[] memory) {
        return users[user].ownedGrids;
    }
    
    /**
     * @dev 获取用户的直推用户
     * @param user 用户地址
     * @return 直推用户地址数组
     */
    function getUserDirectReferrals(address user) external view returns (address[] memory) {
        return users[user].directReferrals;
    }
    
    /**
     * @dev 检查格子是否可以转盘
     * @param gridId 格子ID
     * @return 是否可以转盘
     */
    function canSpin(uint256 gridId) external view returns (bool) {
        if (!grids[gridId].isActive) {
            return false;
        }
        
        // 检查是否已经过了一天
        uint256 oneDaySeconds = 86400; // 24 * 60 * 60
        return block.timestamp >= grids[gridId].lastSpinTime + oneDaySeconds;
    }
    
    /**
     * @dev 更新格子价格
     * @param level 格子等级
     * @param price 新价格
     */
    function updateGridPrice(GridLevel level, uint256 price) external onlyRole(ADMIN_ROLE) {
        require(price > 0, "Price must be greater than zero");
        gridPrices[level] = price;
    }
    
    /**
     * @dev 添加WHEEL角色
     * @param account 账户地址
     */
    function addWheelRole(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(WHEEL_ROLE, account);
    }
    
    /**
     * @dev 移除WHEEL角色
     * @param account 账户地址
     */
    function removeWheelRole(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(WHEEL_ROLE, account);
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
}