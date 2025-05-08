# BSC 项目

这是一个结构复杂的 BSC 区块链项目，包含多种智能合约和收益机制。

## 项目概述

本项目包含以下主要组件：

- **主币合约**：BEP-20 标准代币，总量 3650 万，具有权限管理和交易手续费机制
- **子币合约**：BEP-20 标准代币，总量 1000 万，固定价格 1 USDT
- **NFT 合约**：BEP-721 标准，包含 65 张大 NFT 和 365 张小 NFT
- **闪兑合约**：只允许卖币，价格每天自动上涨 0.5%
- **功能合约**：包含格子系统、转盘系统、推荐系统、等级系统和分红系统

## 合约功能说明

### 主币合约 (MainToken.sol)

- 总量：3650 万
- 分配：1000 万、2000 万、400 万、150 万、100 万
- 权限管理：总管理员与子管理员分工明确
- 交易逻辑：
  - 未开放正式交易前，不能随意卖币，手续费 5%
  - 正式交易开放后，买卖均收 5% 手续费

### 子币合约 (SubToken.sol)

- 总量：1000 万
- 固定价格：1 USDT

### NFT 合约 (NFT.sol)

- 大 NFT：65 张
- 小 NFT：365 张

### 闪兑合约 (FlashExchange.sol)

- 功能：只允许卖币，初始价格固定
- 价格机制：每天（UTC 时间 0 点）自动上涨 0.5%
- 价格可调：管理员权限

### 格子系统 (GridSystem.sol)

- 格子规格分层次，例如：100~500 对应 A-E/A1-E1 级别
- 格子可提现（手续费 5% 主币）
- 格子可拓展

### 转盘系统 (WheelSystem.sol)

- 每格每天可转盘一次
- 收益概率分布：
  - 2.0~2.5：后台设置
  - 1.1~1.5：1%
  - 1.6~1.9：0.1%
- 每次转盘奖励：300 主币

### 推荐系统 (ReferralSystem.sol)

- 直推：格子金额 20%
- 间推：格子金额 10%
- 前提：上级地址也购买过该格子

### 等级与分红系统 (LevelDividendAirdrop.sol)

- 等级制度：
  - 根据格子购买数量激活 A-E/A1-E1 级别
  - 激活后可获得区块收益 5%
- 全网分红：
  - 每次入金的 1% 分配至 A1-E1
  - 比例：A1(35%)、B1(30%)、C1(20%)、D1(10%)、E1(5%)
  - 分红三方分配：
    - 30% 大 NFT
    - 30% 小 NFT
    - 40% 达标会员
- 空投机制：
  - 普通格子用户：每日可领 50 主币
  - 小 NFT 持有者：每日 200 主币
  - 大 NFT 持有者：每日 500 主币

## 项目结构

```
BSCProject/
├── contracts/
│   ├── MainToken.sol         // 主币合约
│   ├── SubToken.sol          // 子币合约
│   ├── NFT.sol               // NFT合约
│   ├── FlashExchange.sol     // 闪兑合约
│   ├── GridSystem.sol        // 格子系统
│   ├── WheelSystem.sol       // 转盘系统
│   ├── ReferralSystem.sol    // 推荐系统
│   └── LevelDividendAirdrop.sol // 等级分红空投系统
├── migrations/               // 部署脚本
│   └── 1_deploy_contracts.js // 部署所有合约
├── truffle-config.js         // Truffle配置
└── package.json              // 项目依赖
```

## 安装与部署

### 前置条件

- Node.js v14+
- npm v6+
- Hardhat v2.0+

### 安装依赖

```bash
npm install
```

### 编译合约

```bash
npx hardhat compile
```

### 部署到本地测试网络

```bash
npx hardhat node
```

### 部署到 BSC 测试网

1. 创建 `.env` 文件，添加以下内容：

```
MNEMONIC=您的助记词
BSC_API_KEY=您的BSC API密钥
```

2. 执行部署命令：

```bash
npx hardhat run scripts/deploy.js --network bscTestnet
```

### 部署到 BSC 主网

```bash
npx hardhat run scripts/deploy.js --network bsc
```

## 测试

```bash
npx hardhat test
```

## 合约交互

部署完成后，可以通过 Hardhat 控制台或前端应用与合约进行交互。

### 使用 Hardhat 控制台

```bash
npx hardhat console --network localhost
```

然后可以使用 JavaScript 与合约交互，例如：

```javascript
// 获取主币合约实例
const MainToken = await ethers.getContractFactory("MainToken");
const mainToken = await MainToken.attach("部署后主币合约地址");

// 查询总供应量
const totalSupply = await mainToken.totalSupply();
console.log(totalSupply.toString());
```

## 安全注意事项

- 在主网部署前，确保所有合约已经过全面审计
- 妥善保管管理员私钥
- 定期检查合约状态和资金安全

## 许可证

MIT
