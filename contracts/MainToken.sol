// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITRC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }
}

contract BTOKEN is ITRC20 {
    using SafeMath for uint256;

    string public constant name = "NEXT TOKEN";
    string public constant symbol = "NEXT";
    uint8 public constant decimals = 6;

    uint256 private totalSupply_;
    mapping(address => uint256) private balanceOf_;
    mapping(address => mapping(address => uint256)) private allowance_;

    address public owner;
    mapping(address => bool) public subAdmins;
    bool public tradingOpen = false;
    address public feeReceiver;

    uint256 public constant FEE_PERCENT = 5;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner || subAdmins[msg.sender], "Not admin");
        _;
    }

    constructor(address[5] memory recipients, address _feeReceiver) {
        owner = msg.sender;
        feeReceiver = _feeReceiver;

        totalSupply_ = 36_500_000 * (10 ** decimals);

        uint256[5] memory allocations = [
            10_000_000 * (10 ** decimals),  // 1000 万
            20_000_000 * (10 ** decimals),  // 2000 万
            4_000_000 * (10 ** decimals),   // 400 万
            1_500_000 * (10 ** decimals),   // 150 万
            1_000_000 * (10 ** decimals)    // 100 万
        ];

        for (uint i = 0; i < recipients.length; i++) {
            balanceOf_[recipients[i]] = allocations[i];
            emit Transfer(address(0), recipients[i], allocations[i]);
        }
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address guy) public view returns (uint256) {
        return balanceOf_[guy];
    }

    function allowance(address owner_, address spender) public view returns (uint256) {
        return allowance_[owner_][spender];
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance_[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(balanceOf_[from] >= value, "Insufficient balance");

        // 检查 allowance 限额
        if (from != msg.sender && allowance_[from][msg.sender] != type(uint256).max) {
            require(allowance_[from][msg.sender] >= value, "Allowance too low");
            allowance_[from][msg.sender] = allowance_[from][msg.sender].sub(value, "Allowance underflow");
        }

        // 卖出前交易未开放时禁止发送给非 admin
        if (!tradingOpen && !subAdmins[to] && to != owner) {
            revert("Trading not open");
        }

        uint256 fee = value * FEE_PERCENT / 100;
        uint256 netAmount = value - fee;

        // 扣除手续费并转账
        balanceOf_[from] = balanceOf_[from].sub(value, "Transfer underflow");
        balanceOf_[to] = balanceOf_[to].add(netAmount, "Receive overflow");
        balanceOf_[feeReceiver] = balanceOf_[feeReceiver].add(fee, "Fee overflow");

        emit Transfer(from, to, netAmount);
        emit Transfer(from, feeReceiver, fee);
        return true;
    }

    // 管理功能
    function openTrading() external onlyAdmin {
        tradingOpen = true;
    }

    function setSubAdmin(address admin, bool status) external onlyOwner {
        subAdmins[admin] = status;
    }

    function setFeeReceiver(address newReceiver) external onlyOwner {
        feeReceiver = newReceiver;
    }
}
