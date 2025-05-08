const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("部署账户:", deployer.address);

  // USDT地址（根据网络设置）
  let usdtAddress;
  const network = hre.network.name;
  
  if (network === 'development') {
    usdtAddress = deployer.address;
  } else if (network === 'bscTestnet') {
    usdtAddress = "0x337610d27c682E347C9cD60BD4b3b107C9d34dDd";
  } else if (network === 'bsc') {
    usdtAddress = "0x55d398326f99059fF775485246999027B3197955";
  }

  // 部署主币合约
  console.log("部署主币合约...");
  const MainToken = await ethers.getContractFactory("MainToken");
  const initialSupply = 36500000;
  const distributors = [
    // 这里需要替换为实际地址
    "0x...", // 1000万
    "0x...", // 2000万
    "0x...", // 400万
    "0x...", // 150万
    "0x..."  // 100万
  ];
  const amounts = [
    10000000, // 1000万
    20000000, // 2000万
    4000000,  // 400万
    1500000,  // 150万
    1000000   // 100万
  ];
  const mainToken = await MainToken.deploy(
    "BSC Project Token",
    "BSCP",
    initialSupply,
    distributors,
    amounts,
    deployer.address
  );
  await mainToken.deployed();
  console.log("主币合约已部署到:", mainToken.address);

  // 部署其他合约...
  // ... 其他合约的部署代码与原来类似，只需要将语法改为ethers.js的方式
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });