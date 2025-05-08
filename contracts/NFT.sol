// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title NFT
 * @dev NFT合约，实现BEP-721标准，支持大NFT和小NFT
 */
contract NFT is ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    
    // 角色定义
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // NFT类型
    enum NFTType { LARGE, SMALL }
    
    // NFT计数器
    Counters.Counter private _largeNftIdCounter;
    Counters.Counter private _smallNftIdCounter;
    
    // NFT最大数量
    uint256 public constant MAX_LARGE_NFT = 65;
    uint256 public constant MAX_SMALL_NFT = 365;
    
    // NFT元数据
    string private _baseTokenURI;
    
    // NFT类型映射
    mapping(uint256 => NFTType) public nftTypes;
    
    // 事件
    event NFTMinted(address indexed to, uint256 tokenId, NFTType nftType);
    event BaseURIUpdated(string newBaseURI);
    
    /**
     * @dev 构造函数
     * @param name_ NFT名称
     * @param symbol_ NFT符号
     * @param baseTokenURI_ 基础URI
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_
    ) ERC721(name_, symbol_) {
        // 设置角色
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        
        // 设置基础URI
        _baseTokenURI = baseTokenURI_;
    }
    
    /**
     * @dev 铸造大NFT
     * @param to 接收地址
     * @return tokenId 代币ID
     */
    function mintLargeNFT(address to) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(_largeNftIdCounter.current() < MAX_LARGE_NFT, "Maximum large NFTs minted");
        
        _largeNftIdCounter.increment();
        uint256 tokenId = _largeNftIdCounter.current();
        
        _safeMint(to, tokenId);
        nftTypes[tokenId] = NFTType.LARGE;
        
        emit NFTMinted(to, tokenId, NFTType.LARGE);
        
        return tokenId;
    }
    
    /**
     * @dev 铸造小NFT
     * @param to 接收地址
     * @return tokenId 代币ID
     */
    function mintSmallNFT(address to) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(_smallNftIdCounter.current() < MAX_SMALL_NFT, "Maximum small NFTs minted");
        
        _smallNftIdCounter.increment();
        uint256 tokenId = MAX_LARGE_NFT + _smallNftIdCounter.current();
        
        _safeMint(to, tokenId);
        nftTypes[tokenId] = NFTType.SMALL;
        
        emit NFTMinted(to, tokenId, NFTType.SMALL);
        
        return tokenId;
    }
    
    /**
     * @dev 批量铸造大NFT
     * @param to 接收地址数组
     */
    function batchMintLargeNFT(address[] calldata to) external onlyRole(MINTER_ROLE) {
        require(_largeNftIdCounter.current() + to.length <= MAX_LARGE_NFT, "Exceeds maximum large NFTs");
        
        for (uint256 i = 0; i < to.length; i++) {
            _largeNftIdCounter.increment();
            uint256 tokenId = _largeNftIdCounter.current();
            
            _safeMint(to[i], tokenId);
            nftTypes[tokenId] = NFTType.LARGE;
            
            emit NFTMinted(to[i], tokenId, NFTType.LARGE);
        }
    }
    
    /**
     * @dev 批量铸造小NFT
     * @param to 接收地址数组
     */
    function batchMintSmallNFT(address[] calldata to) external onlyRole(MINTER_ROLE) {
        require(_smallNftIdCounter.current() + to.length <= MAX_SMALL_NFT, "Exceeds maximum small NFTs");
        
        for (uint256 i = 0; i < to.length; i++) {
            _smallNftIdCounter.increment();
            uint256 tokenId = MAX_LARGE_NFT + _smallNftIdCounter.current();
            
            _safeMint(to[i], tokenId);
            nftTypes[tokenId] = NFTType.SMALL;
            
            emit NFTMinted(to[i], tokenId, NFTType.SMALL);
        }
    }
    
    /**
     * @dev 获取NFT类型
     * @param tokenId 代币ID
     * @return NFT类型
     */
    function getNFTType(uint256 tokenId) external view returns (NFTType) {
        require(_exists(tokenId), "NFT does not exist");
        return nftTypes[tokenId];
    }
    
    /**
     * @dev 获取已铸造的大NFT数量
     * @return 大NFT数量
     */
    function getLargeNFTCount() external view returns (uint256) {
        return _largeNftIdCounter.current();
    }
    
    /**
     * @dev 获取已铸造的小NFT数量
     * @return 小NFT数量
     */
    function getSmallNFTCount() external view returns (uint256) {
        return _smallNftIdCounter.current();
    }
    
    /**
     * @dev 设置基础URI
     * @param newBaseURI 新的基础URI
     */
    function setBaseURI(string memory newBaseURI) external onlyRole(ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }
    
    /**
     * @dev 获取代币URI
     * @param tokenId 代币ID
     * @return 代币URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        
        return string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId)));
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
     * @dev 检查地址是否拥有大NFT
     * @param owner 所有者地址
     * @return 是否拥有大NFT
     */
    function hasLargeNFT(address owner) external view returns (bool) {
        uint256 balance = balanceOf(owner);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            if (nftTypes[tokenId] == NFTType.LARGE) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev 检查地址是否拥有小NFT
     * @param owner 所有者地址
     * @return 是否拥有小NFT
     */
    function hasSmallNFT(address owner) external view returns (bool) {
        uint256 balance = balanceOf(owner);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            if (nftTypes[tokenId] == NFTType.SMALL) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev 支持接口查询
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}