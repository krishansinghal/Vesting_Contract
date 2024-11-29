const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VestingContract", function () {
  let owner, beneficiary, partner, team;
  let VestingContract, vestingContract, MyVestToken, myVestToken;

  const initialSupply = ethers.parseEther("1000000");

  beforeEach(async function () {
    [owner, beneficiary, partner, team] = await ethers.getSigners();

    // Deploy MyVestToken
    MyVestToken = await ethers.getContractFactory("MyVestToken");
    myVestToken = await MyVestToken.deploy(initialSupply);

    // Deploy VestingContract
    VestingContract = await ethers.getContractFactory("VestingContract");
    vestingContract = await VestingContract.deploy(myVestToken.target);

    // Approve tokens for the VestingContract
    await myVestToken.approve(vestingContract.target, initialSupply);
  });

  describe("Deployment", function () {
    it("should set the correct token address", async function () {
      expect(await vestingContract.token()).to.equal(myVestToken.target);
    });

    it("should initialize vestingStarted to false", async function () {
      expect(await vestingContract.vestingStarted()).to.be.false;
    });
  });

  describe("startVesting", function () {
    it("should allow the owner to start vesting", async function () {
      await expect(vestingContract.startVesting())
        .to.emit(vestingContract, "VestingStarted")
        .withArgs(await ethers.provider.getBlock("latest").then(block => block.timestamp));

      expect(await vestingContract.vestingStarted()).to.be.true;
    });

    it("should not allow starting vesting twice", async function () {
      await vestingContract.startVesting();
      expect(vestingContract.startVesting()).to.be.revertedWith("Vesting has already started");
    });
  });

  describe("setRole", function () {
    it("should allow the owner to set roles before vesting starts", async function () {
      await vestingContract.setRole(beneficiary.address, 1); // Role.User
      expect(await vestingContract.roles(beneficiary.address)).to.equal(1); // Role.User
    });

    it("should not allow setting roles after vesting starts", async function () {
      await vestingContract.startVesting();
      expect(vestingContract.setRole(beneficiary.address, 1)).to.be.revertedWith(
        "Cannot set roles after vesting has started"
      );
    });
  });

  describe("addBeneficiary", function () {
    it("should allow adding a beneficiary before vesting starts", async function () {
      await vestingContract.setRole(beneficiary.address, 1); // Role.User

      const totalTokens = ethers.parseEther("1000");
      await expect(vestingContract.addBeneficiary(beneficiary.address, totalTokens))
        .to.emit(vestingContract, "BeneficiaryAdded")
        .withArgs(beneficiary.address, 1, totalTokens / BigInt(2)); // User: 50%

      const schedule = await vestingContract.vestingSchedules(beneficiary.address);
      expect(schedule.totalAmount).to.equal(totalTokens/ BigInt(2));
    });

    it("should revert if vesting has started", async function () {
      await vestingContract.startVesting();
      expect(vestingContract.addBeneficiary(beneficiary.address, ethers.parseEther("1000"))).to.be.revertedWith(
        "Cannot add beneficiaries after vesting has started"
      );
    });
  });

  describe("releaseTokens", function () {
    beforeEach(async function () {
      await vestingContract.setRole(beneficiary.address, 1); // Role.User
      const totalTokens = ethers.parseEther("1000");
      await vestingContract.addBeneficiary(beneficiary.address, totalTokens);
      await vestingContract.startVesting();
    });
  

    it("should not release tokens before cliff period", async function () {
      expect(vestingContract.connect(beneficiary).releaseTokens()).to.be.revertedWith(
        "Cliff period not reached"
      );
    });
  });

  describe("releasableAmount", function () {

    it("should return the correct amount based on elapsed time", async function () {
      await vestingContract.setRole(beneficiary.address, 1); // Role.User
      const totalTokens = ethers.parseEther("1000");
      await vestingContract.addBeneficiary(beneficiary.address, totalTokens);
      await vestingContract.startVesting();

      const oneYear = 365 * 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [oneYear]);
      await ethers.provider.send("evm_mine", []);

      const releasable = await vestingContract.releasableAmount(beneficiary.address);
      expect(releasable).to.be.closeTo(totalTokens / BigInt(2), ethers.parseEther("0.1")); // 50% vested after 1 year
    });
  });
});