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
  const name = "MainToken";
  const symbol = "MTK";
  const initialSupply = 36500000;
  const distributor = [
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222",
    "0x3333333333333333333333333333333333333333",
    "0x4444444444444444444444444444444444444444",
    "0x5555555555555555555555555555555555555555"
  ];
  const amounts = [10000000, 20000000, 4000000, 1500000, 1000000];
  const feeReceiver = "0xFEE0000000000000000000000000000000000000";

  const MainToken = await ethers.getContractFactory("MainToken");
  const mainToken = await MainToken.deploy(name, symbol, initialSupply, distributor, amounts, feeReceiver);
  await mainToken.deployed();
  console.log("MainToken deployed to:", mainToken.address);

  // 部署其他合约...
  // ... 其他合约的部署代码与原来类似，只需要将语法改为ethers.js的方式
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });