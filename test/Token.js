const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");

describe("UnPack contract", function () {
  let hardhatToken;
  let owner, pauser, developer, presaler, airdroper;

  beforeEach(async function () {
    [owner, pauser, developer, presaler, airdroper] = await ethers.getSigners();

    const UnPack = await ethers.getContractFactory("UnPack");

    // Deploying the proxy and initializing the contract
    hardhatToken = await upgrades.deployProxy(UnPack, [
      owner.address, pauser.address, developer.address, presaler.address, airdroper.address
    ], { initializer: 'initialize' });

    console.log("UnPack deployed to:", hardhatToken.address);
  });

  it("Deployment should correctly allocate tokens to the developer, presaler, staker, and owner", async function () {
    const totalSupply = await hardhatToken.totalSupply();
    const ownerBalance = await hardhatToken.balanceOf(owner.address);
    const developerBalance = await hardhatToken.balanceOf(developer.address);
    const presalerBalance = await hardhatToken.balanceOf(presaler.address);
    const airdroperBalance = await hardhatToken.balanceOf(airdroper.address);

    const totalSupplyBigInt = BigInt(totalSupply.toString());
    const tenPercentBigInt = totalSupplyBigInt / BigInt(10);
    const thirtyPercentBigInt = totalSupplyBigInt * BigInt(3) / BigInt(10);
    const fiftyPercentBigInt = totalSupplyBigInt / BigInt(2);

    expect(developerBalance.toString()).to.equal(tenPercentBigInt.toString(), "Developer should have 10% of total supply");
    expect(presalerBalance.toString()).to.equal(tenPercentBigInt.toString(), "Presaler should have 10% of total supply");
    expect(airdroperBalance.toString()).to.equal(thirtyPercentBigInt.toString(), "Airdroper should have 30% of total supply");
    expect(ownerBalance.toString()).to.equal(fiftyPercentBigInt.toString(), "Owner should have 50% of total supply");
  });

  it("Should correctly apply tax on transfers", async function () {
    const etherToWei = (etherValue) => BigInt(etherValue) * BigInt("1000000000000000000"); // Convert Ether to Wei
    const transferAmount = etherToWei("1000"); // Convert 1000 Ether to Wei

    const totalSupply = await hardhatToken.totalSupply();
    const ownerBalance = await hardhatToken.balanceOf(owner.address);
    const developerBalance = await hardhatToken.balanceOf(developer.address);
    const presalerBalance = await hardhatToken.balanceOf(presaler.address);
    const airdroperBalance = await hardhatToken.balanceOf(airdroper.address);

    await hardhatToken.connect(developer).transfer(owner.address, transferAmount.toString());

    console.log("totalSupply: ", totalSupply.toString());
    console.log("ownerBalance: ", ownerBalance.toString());
    console.log("developerBalance: ", developerBalance.toString());
    console.log("presalerBalance: ", presalerBalance.toString());
    console.log("airdroperBalance: ", airdroperBalance.toString());

    const taxPercentageBigInt = BigInt(3); // 3%
    const expectedTaxBigInt = transferAmount * taxPercentageBigInt / BigInt(100);

    const developerBalanceAfter = await hardhatToken.balanceOf(developer.address);
    const ownerBalanceAfter = await hardhatToken.balanceOf(owner.address);
    const airdroperBalanceAfter = await hardhatToken.balanceOf(airdroper.address);

    console.log("Transfer amount: ", transferAmount.toString());
    console.log("Tax percentage: ", taxPercentageBigInt.toString());
    console.log("Expected tax: ", expectedTaxBigInt.toString());
    console.log("Developer balance after transfer: ", developerBalanceAfter.toString());
    console.log("Owner balance after transfer: ", ownerBalanceAfter.toString());
    console.log("Airdroper balance after transfer: ", airdroperBalanceAfter.toString());

    const expectedDeveloperBalanceBigInt = developerBalance - transferAmount;
    const expectedOwnerBalanceBigInt = ownerBalance + transferAmount - expectedTaxBigInt;
    const expectedAirdroperBalanceBigInt = airdroperBalance + expectedTaxBigInt;

    expect(developerBalanceAfter.toString()).to.equal(expectedDeveloperBalanceBigInt.toString(), "Incorrect developer balance after transfer");
    expect(ownerBalanceAfter.toString()).to.equal(expectedOwnerBalanceBigInt.toString(), "Incorrect owner balance after transfer");
    expect(airdroperBalanceAfter.toString()).to.equal(expectedAirdroperBalanceBigInt.toString(), "Incorrect airdroper balance after tax deduction");
  });
});
