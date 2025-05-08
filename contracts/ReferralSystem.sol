// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GridSystem.sol";

/**
 * @title ReferralSystem
 * @dev 推荐系统合约，实现直推和间推收益机制
 */
contract ReferralSystem is AccessControl, ReentrancyGuard {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GRID_ROLE = keccak256("GRID_ROLE");
    
    // 合约地址
    address public mainToken;
    address public usdtToken;
    address public gridSystem;
    
    // 推荐关系映射
    mapping(address => address) public referrers;
    mapping(address => address[]) public directReferrals;
    
    // 用户收益映射
    mapping(address => uint256) public directReferralEarnings;
    mapping(address => uint256) public indirectReferralEarnings;
    
    // 推荐奖励比例
    uint256 public constant DIRECT_REFERRAL_RATE = 2000; // 20%
    uint256 public constant INDIRECT_REFERRAL_RATE = 1000; // 10%
    uint256 public constant RATE_DENOMINATOR = 10000;
    
    // 事件
    event ReferralRegistered(address indexed user, address indexed referrer);
    event DirectReferralRewardPaid(address indexed referrer, address indexed user, uint256 amount, uint256 gridId);
    event IndirectReferralRewardPaid(address indexed referrer, address indexed user, uint256 amount, uint256 gridId);
    
    /**
     * @dev 构造函数
     * @param _mainToken 主币合约地址
     * @param _usdtToken USDT合约地址
     * @param _gridSystem 格子系统合约地址
     */
    constructor(
        address _mainToken,
        address _usdtToken,
        address _gridSystem
    ) {
        require(_mainToken != address(0), "Main token address cannot be zero");
        require(_usdtToken != address(0), "USDT token address cannot be zero");
        require(_gridSystem != address(0), "Grid system address cannot be zero");
        
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(GRID_ROLE, msg.sender);
        
        // 设置合约地址
        mainToken = _mainToken;
        usdtToken = _usdtToken;
        gridSystem = _gridSystem;
    }
    
    /**
     * @dev 注册推荐关系
     * @param user 用户地址
     * @param referrer 推荐人地址
     */
    function registerReferral(address user, address referrer) external onlyRole(GRID_ROLE) {
        require(user != address(0), "User address cannot be zero");
        require(referrer != address(0), "Referrer address cannot be zero");
        require(user != referrer, "User cannot refer themselves");
        require(referrers[user] == address(0), "User already has a referrer");
        
        // 设置推荐关系
        referrers[user] = referrer;
        directReferrals[referrer].push(user);
        
        emit ReferralRegistered(user, referrer);
    }
    
    /**
     * @dev 处理格子购买的推荐奖励
     * @param buyer 购买者地址
     * @param gridId 格子ID
     * @param amount 购买金额
     */
    function processGridPurchaseReferralReward(address buyer, uint256 gridId, uint256 amount) external onlyRole(GRID_ROLE) {
        // 获取格子等级
        GridSystem.GridLevel gridLevel = GridSystem(gridSystem).grids(gridId).level;
        
        // 处理直推奖励
        address directReferrer = referrers[buyer];
        if (directReferrer != address(0)) {
            // 检查直推人是否购买过该等级的格子
            if (_hasGridOfLevel(directReferrer, gridLevel)) {
                uint256 directReward = (amount * DIRECT_REFERRAL_RATE) / RATE_DENOMINATOR;
                IERC20(usdtToken).transfer(directReferrer, directReward);
                directReferralEarnings[directReferrer] += directReward;
                
                emit DirectReferralRewardPaid(directReferrer, buyer, directReward, gridId);
                
                // 处理间推奖励
                address indirectReferrer = referrers[directReferrer];
                if (indirectReferrer != address(0)) {
                    // 检查间推人是否购买过该等级的格子
                    if (_hasGridOfLevel(indirectReferrer, gridLevel)) {
                        uint256 indirectReward = (amount * INDIRECT_REFERRAL_RATE) / RATE_DENOMINATOR;
                        IERC20(usdtToken).transfer(indirectReferrer, indirectReward);
                        indirectReferralEarnings[indirectReferrer] += indirectReward;
                        
                        emit IndirectReferralRewardPaid(indirectReferrer, buyer, indirectReward, gridId);
                    }
                }
            }
        }
    }
    
    /**
     * @dev 内部函数：检查用户是否拥有特定等级的格子
     * @param user 用户地址
     * @param level 格子等级
     * @return 是否拥有该等级的格子
     */
    function _hasGridOfLevel(address user, GridSystem.GridLevel level) internal view returns (bool) {
        uint256[] memory userGrids = GridSystem(gridSystem).getUserGrids(user);
        
        for (uint256 i = 0; i < userGrids.length; i++) {
            if (GridSystem(gridSystem).grids(userGrids[i]).level == level) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev 获取用户的直推用户
     * @param user 用户地址
     * @return 直推用户地址数组
     */
    function getDirectReferrals(address user) external view returns (address[] memory) {
        return directReferrals[user];
    }
    
    /**
     * @dev 获取用户的推荐人
     * @param user 用户地址
     * @return 推荐人地址
     */
    function getReferrer(address user) external view returns (address) {
        return referrers[user];
    }
    
    /**
     * @dev 获取用户的直推收益
     * @param user 用户地址
     * @return 直推收益
     */
    function getDirectReferralEarnings(address user) external view returns (uint256) {
        return directReferralEarnings[user];
    }
    
    /**
     * @dev 获取用户的间推收益
     * @param user 用户地址
     * @return 间推收益
     */
    function getIndirectReferralEarnings(address user) external view returns (uint256) {
        return indirectReferralEarnings[user];
    }
    
    /**
     * @dev 添加GRID角色
     * @param account 账户地址
     */
    function addGridRole(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(GRID_ROLE, account);
    }
    
    /**
     * @dev 移除GRID角色
     * @param account 账户地址
     */
    function removeGridRole(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(GRID_ROLE, account);
    }
    
    /**
     * @dev 更新格子系统合约地址
     * @param _gridSystem 新的格子系统合约地址
     */
    function updateGridSystem(address _gridSystem) external onlyRole(ADMIN_ROLE) {
        require(_gridSystem != address(0), "Grid system address cannot be zero");
        gridSystem = _gridSystem;
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