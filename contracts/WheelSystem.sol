// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GridSystem.sol";

/**
 * @title WheelSystem
 * @dev 转盘系统合约，实现每格每天可转盘一次的收益机制
 */
contract WheelSystem is AccessControl, ReentrancyGuard {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // 合约地址
    address public mainToken;
    address public gridSystem;
    
    // 转盘奖励配置
    struct RewardConfig {
        uint256 minMultiplier;  // 最小倍数 (乘以100，例如1.1倍 = 110)
        uint256 maxMultiplier;  // 最大倍数 (乘以100，例如2.5倍 = 250)
        uint256 probability;    // 概率 (基点，例如1% = 100)
    }
    
    // 转盘奖励配置数组
    RewardConfig[] public rewardConfigs;
    
    // 基础奖励金额
    uint256 public baseRewardAmount = 300 * 10**18; // 300个主币
    
    // 事件
    event WheelSpun(address indexed user, uint256 gridId, uint256 multiplier, uint256 rewardAmount);
    event RewardConfigUpdated(uint256 index, uint256 minMultiplier, uint256 maxMultiplier, uint256 probability);
    event BaseRewardAmountUpdated(uint256 oldAmount, uint256 newAmount);
    
    /**
     * @dev 构造函数
     * @param _mainToken 主币合约地址
     * @param _gridSystem 格子系统合约地址
     */
    constructor(
        address _mainToken,
        address _gridSystem
    ) {
        require(_mainToken != address(0), "Main token address cannot be zero");
        require(_gridSystem != address(0), "Grid system address cannot be zero");
        
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
        
        // 设置合约地址
        mainToken = _mainToken;
        gridSystem = _gridSystem;
        
        // 初始化奖励配置
        // 2.0~2.5倍：后台设置
        rewardConfigs.push(RewardConfig(200, 250, 0)); // 概率由后台设置
        
        // 1.1~1.5倍：1%
        rewardConfigs.push(RewardConfig(110, 150, 100)); // 1%
        
        // 1.6~1.9倍：0.1%
        rewardConfigs.push(RewardConfig(160, 190, 10)); // 0.1%
    }
    
    /**
     * @dev 转盘抽奖
     * @param gridId 格子ID
     * @return multiplier 倍数
     * @return rewardAmount 奖励金额
     */
    function spin(uint256 gridId) external nonReentrant returns (uint256 multiplier, uint256 rewardAmount) {
        // 检查格子是否可以转盘
        bool canSpin = GridSystem(gridSystem).canSpin(gridId);
        require(canSpin, "Grid cannot spin now");
        
        // 获取格子所有者
        address gridOwner = GridSystem(gridSystem).grids(gridId).owner;
        require(gridOwner == msg.sender, "Not the grid owner");
        
        // 随机选择奖励倍数
        (multiplier, rewardAmount) = _getRandomReward();
        
        // 转移奖励给用户
        bool success = IERC20(mainToken).transfer(msg.sender, rewardAmount);
        require(success, "Token transfer failed");
        
        // 更新格子的转盘收益
        GridSystem(gridSystem).addWheelIncome(gridId, rewardAmount);
        
        emit WheelSpun(msg.sender, gridId, multiplier, rewardAmount);
        
        return (multiplier, rewardAmount);
    }
    
    /**
     * @dev 内部函数：获取随机奖励
     * @return multiplier 倍数
     * @return rewardAmount 奖励金额
     */
    function _getRandomReward() internal view returns (uint256 multiplier, uint256 rewardAmount) {
        // 生成随机数
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender))) % 10000;
        
        // 默认奖励倍数为1倍
        multiplier = 100;
        
        // 累计概率
        uint256 cumulativeProbability = 0;
        
        // 遍历奖励配置
        for (uint256 i = 0; i < rewardConfigs.length; i++) {
            cumulativeProbability += rewardConfigs[i].probability;
            
            if (randomNumber < cumulativeProbability) {
                // 在最小和最大倍数之间生成随机倍数
                uint256 range = rewardConfigs[i].maxMultiplier - rewardConfigs[i].minMultiplier;
                uint256 randomMultiplier = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, i))) % (range + 1);
                multiplier = rewardConfigs[i].minMultiplier + randomMultiplier;
                break;
            }
        }
        
        // 计算奖励金额
        rewardAmount = (baseRewardAmount * multiplier) / 100;
        
        return (multiplier, rewardAmount);
    }
    
    /**
     * @dev 更新奖励配置
     * @param index 配置索引
     * @param minMultiplier 最小倍数
     * @param maxMultiplier 最大倍数
     * @param probability 概率
     */
    function updateRewardConfig(uint256 index, uint256 minMultiplier, uint256 maxMultiplier, uint256 probability) external onlyRole(ADMIN_ROLE) {
        require(index < rewardConfigs.length, "Invalid index");
        require(minMultiplier <= maxMultiplier, "Min multiplier must be less than or equal to max multiplier");
        
        rewardConfigs[index].minMultiplier = minMultiplier;
        rewardConfigs[index].maxMultiplier = maxMultiplier;
        rewardConfigs[index].probability = probability;
        
        emit RewardConfigUpdated(index, minMultiplier, maxMultiplier, probability);
    }
    
    /**
     * @dev 添加奖励配置
     * @param minMultiplier 最小倍数
     * @param maxMultiplier 最大倍数
     * @param probability 概率
     */
    function addRewardConfig(uint256 minMultiplier, uint256 maxMultiplier, uint256 probability) external onlyRole(ADMIN_ROLE) {
        require(minMultiplier <= maxMultiplier, "Min multiplier must be less than or equal to max multiplier");
        
        rewardConfigs.push(RewardConfig(minMultiplier, maxMultiplier, probability));
        
        emit RewardConfigUpdated(rewardConfigs.length - 1, minMultiplier, maxMultiplier, probability);
    }
    
    /**
     * @dev 更新基础奖励金额
     * @param newAmount 新的基础奖励金额
     */
    function updateBaseRewardAmount(uint256 newAmount) external onlyRole(ADMIN_ROLE) {
        uint256 oldAmount = baseRewardAmount;
        baseRewardAmount = newAmount;
        
        emit BaseRewardAmountUpdated(oldAmount, newAmount);
    }
    
    /**
     * @dev 添加操作员角色
     * @param account 账户地址
     */
    function addOperator(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(OPERATOR_ROLE, account);
    }
    
    /**
     * @dev 移除操作员角色
     * @param account 账户地址
     */
    function removeOperator(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(OPERATOR_ROLE, account);
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