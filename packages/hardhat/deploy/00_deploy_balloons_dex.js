// deploy/00_deploy_balloons_dex.js

const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy("Balloons", {
    from: deployer,
    log: true,
  });

  await deploy("Halwa", {
    from: deployer,
    log: true,
  });

  console.log("working here address: ", deployer);
  const balloons = await ethers.getContract("Balloons", deployer);
  const halwa = await ethers.getContract("Halwa", deployer);

  await deploy("DEX", {
    from: deployer,
    args: [balloons.address, halwa.address],
    log: true,
  });

  const dex = await ethers.getContract("DEX", deployer);

  // get 10 balloons on deploy
  await balloons.transfer(
    "0x988C2204BE3c39fDb67c2C67e0596f3fB142E938",
    "" + 10 * 10 ** 18
  );

  await balloons.transfer(
    "0x61BD02abf75B6bF8BA141Da1D2b52E1Fdf444D6e",
    "" + 10 * 10 ** 18
  );

  await balloons.transfer(
    "0x428b1752dcDc1332F36Fc1cD0bF5815fD0Ac13A9",
    "" + 10 * 10 ** 18
  );

  console.log(
    "Approving DEX (" + dex.address + ") to take Balloons from main account..."
  );
  // If you are going to the testnet make sure your deployer account has enough ETH
  await balloons.approve(dex.address, ethers.utils.parseEther("100"));
  await halwa.approve(dex.address, ethers.utils.parseEther("1000000"));
  console.log("INIT exchange...");
  await dex.init("" + 3 * 10 ** 18, {
    value: ethers.utils.parseEther("3"),
    gasLimit: 200000,
  });

  await deploy("MetaMultiSigWallet", {
    from: deployer,
    args: [31337, [deployer], 1],
    log: true,
  });

  const multiSig = await ethers.getContract("MetaMultiSigWallet", deployer);
};
module.exports.tags = ["Balloons", "DEX", "Halwa"];
