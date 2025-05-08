// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GridSystem.sol";
import "./NFT.sol";

/**
 * @title LevelDividendAirdrop
 * @dev 等级系统、分红系统和空投系统的综合合约
 */
contract LevelDividendAirdrop is AccessControl, ReentrancyGuard {
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // 合约地址
    address public mainToken;
    address public gridSystem;
    address public nftContract;
    
    // 等级定义
    enum UserLevel { NONE, A, B, C, D, E, A1, B1, C1, D1, E1 }
    
    // 用户等级映射
    mapping(address => UserLevel) public userLevels;
    
    // 等级要求（格子数量）
    mapping(UserLevel => uint256) public levelRequirements;
    
    // 等级分红比例
    mapping(UserLevel => uint256) public levelDividendRates;
    
    // 分红池
    uint256 public dividendPool;
    
    // 分红比例
    uint256 public constant DIVIDEND_RATE = 100; // 1%
    uint256 public constant RATE_DENOMINATOR = 10000;
    
    // 分红分配比例
    uint256 public constant LARGE_NFT_SHARE = 3000; // 30%
    uint256 public constant SMALL_NFT_SHARE = 3000; // 30%
    uint256 public constant QUALIFIED_MEMBERS_SHARE = 4000; // 40%
    
    // 空投金额
    uint256 public regularUserAirdrop = 50 * 10**18; // 50个主币
    uint256 public smallNftAirdrop = 200 * 10**18; // 200个主币
    uint256 public largeNftAirdrop = 500 * 10**18; // 500个主币
    
    // 上次空投时间映射
    mapping(address => uint256) public lastAirdropTime;
    
    // 事件
    event UserLevelUpdated(address indexed user, UserLevel level);
    event DividendDistributed(uint256 totalAmount, uint256 largeNftAmount, uint256 smallNftAmount, uint256 membersAmount);
    event AirdropClaimed(address indexed user, uint256 amount, string airdropType);
    event LevelRequirementUpdated(UserLevel level, uint256 requirement);
    event DividendRateUpdated(UserLevel level, uint256 rate);
    event AirdropAmountUpdated(string airdropType, uint256 amount);
    
    /**
     * @dev 构造函数
     * @param _mainToken 主币合约地址
     * @param _gridSystem 格子系统合约地址
     * @param _nftContract NFT合约地址
     */
    constructor(
        address _mainToken,
        address _gridSystem,
        address _nftContract
    ) {
        require(_mainToken != address(0), "Main token address cannot be zero");
        require(_gridSystem != address(0), "Grid system address cannot be zero");
        require(_nftContract != address(0), "NFT contract address cannot be zero");
        
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
        
        // 设置合约地址
        mainToken = _mainToken;
        gridSystem = _gridSystem;
        nftContract = _nftContract;
        
        // 初始化等级要求
        levelRequirements[UserLevel.A] = 1;
        levelRequirements[UserLevel.B] = 2;
        levelRequirements[UserLevel.C] = 3;
        levelRequirements[UserLevel.D] = 4;
        levelRequirements[UserLevel.E] = 5;
        levelRequirements[UserLevel.A1] = 10;
        levelRequirements[UserLevel.B1] = 20;
        levelRequirements[UserLevel.C1] = 30;
        levelRequirements[UserLevel.D1] = 40;
        levelRequirements[UserLevel.E1] = 50;
        
        // 初始化分红比例
        levelDividendRates[UserLevel.A1] = 3500; // 35%
        levelDividendRates[UserLevel.B1] = 3000; // 30%
        levelDividendRates[UserLevel.C1] = 2000; // 20%
        levelDividendRates[UserLevel.D1] = 1000; // 10%
        levelDividendRates[UserLevel.E1] = 500;  // 5%
    }
    
    /**
     * @dev 更新用户等级
     * @param user 用户地址
     */
    function updateUserLevel(address user) external {
        require(user != address(0), "User address cannot be zero");
        
        // 获取用户拥有的格子数量
        uint256[] memory userGrids = GridSystem(gridSystem).getUserGrids(user);
        uint256 gridCount = userGrids.length;
        
        // 确定用户等级
        UserLevel newLevel = UserLevel.NONE;
        
        if (gridCount >= levelRequirements[UserLevel.E1]) {
            newLevel = UserLevel.E1;
        } else if (gridCount >= levelRequirements[UserLevel.D1]) {
            newLevel = UserLevel.D1;
        } else if (gridCount >= levelRequirements[UserLevel.C1]) {
            newLevel = UserLevel.C1;
        } else if (gridCount >= levelRequirements[UserLevel.B1]) {
            newLevel = UserLevel.B1;
        } else if (gridCount >= levelRequirements[UserLevel.A1]) {
            newLevel = UserLevel.A1;
        } else if (gridCount >= levelRequirements[UserLevel.E]) {
            newLevel = UserLevel.E;
        } else if (gridCount >= levelRequirements[UserLevel.D]) {
            newLevel = UserLevel.D;
        } else if (gridCount >= levelRequirements[UserLevel.C]) {
            newLevel = UserLevel.C;
        } else if (gridCount >= levelRequirements[UserLevel.B]) {
            newLevel = UserLevel.B;
        } else if (gridCount >= levelRequirements[UserLevel.A]) {
            newLevel = UserLevel.A;
        }
        
        // 更新用户等级
        userLevels[user] = newLevel;
        
        emit UserLevelUpdated(user, newLevel);
    }
    
    /**
     * @dev 添加分红金额
     * @param amount 分红金额
     */
    function addDividend(uint256 amount) external onlyRole(OPERATOR_ROLE) {
        require(amount > 0, "Amount must be greater than zero");
        
        // 转移主币到合约
        bool success = IERC20(mainToken).transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
        
        // 增加分红池
        dividendPool += amount;
    }
    
    /**
     * @dev 分配分红
     */
    function distributeDividend() external onlyRole(ADMIN_ROLE) nonReentrant {
        require(dividendPool > 0, "Dividend pool is empty");
        
        uint256 totalAmount = dividendPool;
        dividendPool = 0;
        
        // 计算各部分分红金额
        uint256 largeNftAmount = (totalAmount * LARGE_NFT_SHARE) / RATE_DENOMINATOR;
        uint256 smallNftAmount = (totalAmount * SMALL_NFT_SHARE) / RATE_DENOMINATOR;
        uint256 membersAmount = (totalAmount * QUALIFIED_MEMBERS_SHARE) / RATE_DENOMINATOR;
        
        // 分配给大NFT持有者
        _distributeTolargeNftHolders(largeNftAmount);
        
        // 分配给小NFT持有者
        _distributeToSmallNftHolders(smallNftAmount);
        
        // 分配给达标会员
        _distributeToQualifiedMembers(membersAmount);
        
        emit DividendDistributed(totalAmount, largeNftAmount, smallNftAmount, membersAmount);
    }
    
    /**
     * @dev 内部函数：分配给大NFT持有者
     * @param amount 分配金额
     */
    function _distributeTolargeNftHolders(uint256 amount) internal {
        // 获取大NFT总数
        uint256 largeNftCount = NFT(nftContract).getLargeNFTCount();
        if (largeNftCount == 0) return;
        
        // 计算每个大NFT的分红金额
        uint256 amountPerNft = amount / largeNftCount;
        
        // 遍历所有大NFT，分配分红
        for (uint256 i = 1; i <= largeNftCount; i++) {
            address owner = IERC721(nftContract).ownerOf(i);
            IERC20(mainToken).transfer(owner, amountPerNft);
        }
    }
    
    /**
     * @dev 内部函数：分配给小NFT持有者
     * @param amount 分配金额
     */
    function _distributeToSmallNftHolders(uint256 amount) internal {
        // 获取小NFT总数
        uint256 smallNftCount = NFT(nftContract).getSmallNFTCount();
        if (smallNftCount == 0) return;
        
        // 计算每个小NFT的分红金额
        uint256 amountPerNft = amount / smallNftCount;
        
        // 遍历所有小NFT，分配分红
        for (uint256 i = 1; i <= smallNftCount; i++) {
            uint256 tokenId = i + NFT(nftContract).MAX_LARGE_NFT();
            address owner = IERC721(nftContract).ownerOf(tokenId);
            IERC20(mainToken).transfer(owner, amountPerNft);
        }
    }
    
    /**
     * @dev 内部函数：分配给达标会员
     * @param amount 分配金额
     */
    function _distributeToQualifiedMembers(uint256 amount) internal {
        // 计算各等级的分红金额
        uint256 a1Amount = (amount * levelDividendRates[UserLevel.A1]) / RATE_DENOMINATOR;
        uint256 b1Amount = (amount * levelDividendRates[UserLevel.B1]) / RATE_DENOMINATOR;
        uint256 c1Amount = (amount * levelDividendRates[UserLevel.C1]) / RATE_DENOMINATOR;
        uint256 d1Amount = (amount * levelDividendRates[UserLevel.D1]) / RATE_DENOMINATOR;
        uint256 e1Amount = (amount * levelDividendRates[UserLevel.E1]) / RATE_DENOMINATOR;
        
        // 获取各等级的用户数量
        address[] memory a1Users = _getUsersByLevel(UserLevel.A1);
        address[] memory b1Users = _getUsersByLevel(UserLevel.B1);
        address[] memory c1Users = _getUsersByLevel(UserLevel.C1);
        address[] memory d1Users = _getUsersByLevel(UserLevel.D1);
        address[] memory e1Users = _getUsersByLevel(UserLevel.E1);
        
        // 分配给各等级用户
        _distributeToUsers(a1Users, a1Amount);
        _distributeToUsers(b1Users, b1Amount);
        _distributeToUsers(c1Users, c1Amount);
        _distributeToUsers(d1Users, d1Amount);
        _distributeToUsers(e1Users, e1Amount);
    }
    
    /**
     * @dev 内部函数：分配给用户
     * @param users 用户地址数组
     * @param amount 分配金额
     */
    function _distributeToUsers(address[] memory users, uint256 amount) internal {
        if (users.length == 0) return;
        
        // 计算每个用户的分红金额
        uint256 amountPerUser = amount / users.length;
        
        // 分配给每个用户
        for (uint256 i = 0; i < users.length; i++) {
            IERC20(mainToken).transfer(users[i], amountPerUser);
        }
    }
    
    /**
     * @dev 内部函数：获取特定等级的用户
     * @param level 用户等级
     * @return 用户地址数组
     */
    function _getUsersByLevel(UserLevel level) internal view returns (address[] memory) {
        // 这里简化实现，实际应该使用动态数组或映射来存储各等级用户
        // 这个函数需要在实际部署时优化，以避免遍历所有用户
        return new address[](0);
    }
    
    /**
     * @dev 领取空投
     */
    function claimAirdrop() external nonReentrant {
        require(block.timestamp >= lastAirdropTime[msg.sender] + 1 days, "Already claimed today");
        
        uint256 airdropAmount = 0;
        string memory airdropType = "";
        
        // 检查是否持有大NFT
        bool hasLargeNft = NFT(nftContract).hasLargeNFT(msg.sender);
        if (hasLargeNft) {
            airdropAmount = largeNftAirdrop;
            airdropType = "LargeNFT";
        } else {
            // 检查是否持有小NFT
            bool hasSmallNft = NFT(nftContract).hasSmallNFT(msg.sender);
            if (hasSmallNft) {
                airdropAmount = smallNftAirdrop;
                airdropType = "SmallNFT";
            } else {
                // 检查是否是普通格子用户
                uint256[] memory userGrids = GridSystem(gridSystem).getUserGrids(msg.sender);
                if (userGrids.length > 0) {
                    airdropAmount = regularUserAirdrop;
                    airdropType = "RegularUser";
                }
            }
        }
        
        require(airdropAmount > 0, "Not eligible for airdrop");
        
        // 更新上次空投时间
        lastAirdropTime[msg.sender] = block.timestamp;
        
        // 转移主币给用户
        bool success = IERC20(mainToken).transfer(msg.sender, airdropAmount);
        require(success, "Token transfer failed");
        
        emit AirdropClaimed(msg.sender, airdropAmount, airdropType);
    }
    
    /**
     * @dev 更新等级要求
     * @param level 用户等级
     * @param requirement 要求（格子数量）
     */
    function updateLevelRequirement(UserLevel level, uint256 requirement) external onlyRole(ADMIN_ROLE) {
        require(level != UserLevel.NONE, "Cannot update NONE level");
        require(requirement > 0, "Requirement must be greater than zero");
        
        levelRequirements[level] = requirement;
        
        emit LevelRequirementUpdated(level, requirement);
    }
    
    /**
     * @dev 更新分红比例
     * @param level 用户等级
     * @param rate 分红比例
     */
    function updateDividendRate(UserLevel level, uint256 rate) external onlyRole(ADMIN_ROLE) {
        require(level == UserLevel.A1 || level == UserLevel.B1 || level == UserLevel.C1 || level == UserLevel.D1 || level == UserLevel.E1, "Invalid level");
        
        levelDividendRates[level] = rate;
        
        emit DividendRateUpdated(level, rate);
    }
    
    /**
     * @dev 更新空投金额
     * @param airdropType 空投类型（"Regular", "SmallNFT", "LargeNFT"）
     * @param amount 空投金额
     */
    function updateAirdropAmount(string memory airdropType, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(amount > 0, "Amount must be greater than zero");
        
        if (keccak256(abi.encodePacked(airdropType)) == keccak256(abi.encodePacked("Regular"))) {
            regularUserAirdrop = amount;
        } else if (keccak256(abi.encodePacked(airdropType)) == keccak256(abi.encodePacked("SmallNFT"))) {
            smallNftAirdrop = amount;
        } else if (keccak256(abi.encodePacked(airdropType)) == keccak256(abi.encodePacked("LargeNFT"))) {
            largeNftAirdrop = amount;
        } else {
            revert("Invalid airdrop type");
        }
        
        emit AirdropAmountUpdated(airdropType, amount);
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

// ERC721接口
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
}