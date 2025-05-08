const MainToken = artifacts.require("MainToken");
const SubToken = artifacts.require("SubToken");
const NFT = artifacts.require("NFT");
const FlashExchange = artifacts.require("FlashExchange");
const GridSystem = artifacts.require("GridSystem");
const WheelSystem = artifacts.require("WheelSystem");
const ReferralSystem = artifacts.require("ReferralSystem");
const LevelDividendAirdrop = artifacts.require("LevelDividendAirdrop");

module.exports = async function(deployer, network, accounts) {
  // 部署账户
  const deployerAccount = accounts[0];
  
  // USDT地址（根据网络设置）
  let usdtAddress;
  if (network === 'development') {
    // 本地测试网络，需要部署一个模拟的USDT合约
    // 这里简化处理，实际应该部署一个ERC20代币作为USDT
    usdtAddress = deployerAccount;
  } else if (network === 'bscTestnet') {
    // BSC测试网USDT地址
    usdtAddress = "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd"; // BSC测试网USDT地址
  } else if (network === 'bsc') {
    // BSC主网USDT地址
    usdtAddress = "0x55d398326f99059fF775485246999027B3197955"; // BSC主网USDT地址
  }
  
  // 部署主币合约
  console.log("部署主币合约...");
  const initialSupply = 36500000; // 3650万
  const distributors = [
    accounts[1], // 1000万
    accounts[2], // 2000万
    accounts[3], // 400万
    accounts[4], // 150万
    accounts[5]  // 100万
  ];
  const amounts = [
    10000000, // 1000万
    20000000, // 2000万
    4000000,  // 400万
    1500000,  // 150万
    1000000   // 100万
  ];
  const feeReceiver = deployerAccount;
  
  await deployer.deploy(
    MainToken,
    "BSC Project Token",
    "BSCP",
    initialSupply,
    distributors,
    amounts,
    feeReceiver
  );
  const mainToken = await MainToken.deployed();
  console.log("主币合约已部署到:", mainToken.address);
  
  // 部署子币合约
  console.log("部署子币合约...");
  await deployer.deploy(
    SubToken,
    "BSC Project Sub Token",
    "BSCS",
    10000000, // 1000万
    usdtAddress
  );
  const subToken = await SubToken.deployed();
  console.log("子币合约已部署到:", subToken.address);
  
  // 部署NFT合约
  console.log("部署NFT合约...");
  await deployer.deploy(
    NFT,
    "BSC Project NFT",
    "BSCNFT",
    "https://bsc-project.example.com/nft/"
  );
  const nft = await NFT.deployed();
  console.log("NFT合约已部署到:", nft.address);
  
  // 部署闪兑合约
  console.log("部署闪兑合约...");
  const initialPrice = web3.utils.toWei("0.01", "ether"); // 初始价格0.01 USDT
  await deployer.deploy(
    FlashExchange,
    mainToken.address,
    usdtAddress,
    initialPrice
  );
  const flashExchange = await FlashExchange.deployed();
  console.log("闪兑合约已部署到:", flashExchange.address);
  
  // 部署格子系统合约
  console.log("部署格子系统合约...");
  await deployer.deploy(
    GridSystem,
    mainToken.address,
    usdtAddress
  );
  const gridSystem = await GridSystem.deployed();
  console.log("格子系统合约已部署到:", gridSystem.address);
  
  // 部署转盘系统合约
  console.log("部署转盘系统合约...");
  await deployer.deploy(
    WheelSystem,
    mainToken.address,
    gridSystem.address
  );
  const wheelSystem = await WheelSystem.deployed();
  console.log("转盘系统合约已部署到:", wheelSystem.address);
  
  // 部署推荐系统合约
  console.log("部署推荐系统合约...");
  await deployer.deploy(
    ReferralSystem,
    mainToken.address,
    usdtAddress,
    gridSystem.address
  );
  const referralSystem = await ReferralSystem.deployed();
  console.log("推荐系统合约已部署到:", referralSystem.address);
  
  // 部署等级分红空投合约
  console.log("部署等级分红空投合约...");
  await deployer.deploy(
    LevelDividendAirdrop,
    mainToken.address,
    gridSystem.address,
    nft.address
  );
  const levelDividendAirdrop = await LevelDividendAirdrop.deployed();
  console.log("等级分红空投合约已部署到:", levelDividendAirdrop.address);
  
  // 设置合约之间的权限
  console.log("设置合约权限...");
  
  // 给转盘系统添加WHEEL角色
  const WHEEL_ROLE = await gridSystem.WHEEL_ROLE();
  await gridSystem.addWheelRole(wheelSystem.address);
  console.log("已将WHEEL角色授予转盘系统合约");
  
  // 给格子系统添加GRID角色
  const GRID_ROLE = await referralSystem.GRID_ROLE();
  await referralSystem.addGridRole(gridSystem.address);
  console.log("已将GRID角色授予格子系统合约");
  
  console.log("所有合约部署完成！");
};