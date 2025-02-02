import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("BotInteractions Contract", function () {
  let botInteractions: any;
  let owner: any;
  let user: any;
  let erc20Mock: any;
  const tokenAmount = ethers.parseEther("10"); // Amount to use for token transfers

  async function deployBotInteractionsFixture() {
    const [owner, user] = await ethers.getSigners();

    // Deploy ERC20 Mock Token for testing
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    const erc20Mock = await ERC20Mock.deploy(
      "MockToken",
      "MTK",
      ethers.parseEther("100")
    );

    // Deploy the BotInteractions contract
    const BotInteractions = await ethers.getContractFactory("BotInteractions");
    const botInteractions = await BotInteractions.deploy();

    // Mint some tokens to the BotInteractions contract for token transfer tests
    await erc20Mock.transfer(botInteractions.getAddress(), tokenAmount);

    return { botInteractions, owner, user, erc20Mock };
  }

  describe("Deployment", function () {
    it("Should set the owner correctly", async function () {
      const { botInteractions } = await loadFixture(
        deployBotInteractionsFixture
      );
      expect(botInteractions.target).to.not.be.undefined;
    });
  });

  describe("Transfer Funds", function () {
    it("Should transfer Ether to another address", async function () {
      const { botInteractions, user } = await loadFixture(
        deployBotInteractionsFixture
      );
      const initialBalance = await ethers.provider.getBalance(user.address);
      await botInteractions.transferFunds(user.address, {
        value: ethers.parseEther("1"),
      });
      const finalBalance = await ethers.provider.getBalance(user.address);
      expect(finalBalance - initialBalance).to.equal(ethers.parseEther("1"));
    });

    it("Should revert if no value is sent", async function () {
      const { botInteractions, user } = await loadFixture(
        deployBotInteractionsFixture
      );
      await expect(
        botInteractions.transferFunds(user.address)
      ).to.be.revertedWith("Must send some value");
    });
  });

  describe("Token Transfers", function () {
    it("Should transfer ERC20 tokens", async function () {
      const { botInteractions, erc20Mock, user } = await loadFixture(
        deployBotInteractionsFixture
      );
      await erc20Mock.approve(botInteractions.getAddress(), tokenAmount);
      const initialUserBalance = await erc20Mock.balanceOf(user.address);

      await botInteractions.transferERC20(
        erc20Mock.getAddress(),
        user.address,
        tokenAmount
      );

      const finalUserBalance = await erc20Mock.balanceOf(user.address);
      expect(finalUserBalance - initialUserBalance).to.equal(tokenAmount);
    });

    it("Should fail to transfer more tokens than balance", async function () {
      const { botInteractions, erc20Mock, user } = await loadFixture(
        deployBotInteractionsFixture
      );

      const newTokenAmount = ethers.parseEther("10000000"); // Exceed current bot balance
      await erc20Mock.approve(botInteractions.getAddress(), newTokenAmount);

      await expect(
        botInteractions.transferERC20(
          erc20Mock.getAddress(),
          user.address,
          newTokenAmount
        )
      ).to.be.revertedWith("Insufficient token balance");
    });
  });

  describe("Token Approval", function () {
    it("Should approve tokens for spending", async function () {
      const { botInteractions, erc20Mock, owner } = await loadFixture(
        deployBotInteractionsFixture
      );
      await erc20Mock.approve(botInteractions.getAddress(), tokenAmount);
      const allowance = await erc20Mock.allowance(
        owner.address,
        botInteractions.getAddress()
      );
      expect(allowance).to.equal(tokenAmount);
    });
  });

  describe("Deposit and Withdraw", function () {
    it("Should allow contract to receive Ether", async function () {
      const { botInteractions } = await loadFixture(
        deployBotInteractionsFixture
      );
      await botInteractions.depositFunds({ value: ethers.parseEther("1") });
      const balance = await ethers.provider.getBalance(
        botInteractions.getAddress()
      );
      expect(balance).to.equal(ethers.parseEther("1"));
    });

    it("Should allow owner to withdraw all funds", async function () {
      const { botInteractions, owner } = await loadFixture(
        deployBotInteractionsFixture
      );
      await botInteractions.depositFunds({ value: ethers.parseEther("1") });
      const initialOwnerBalance = await ethers.provider.getBalance(
        owner.address
      );

      await botInteractions.withdrawAllFunds();

      const finalOwnerBalance = await ethers.provider.getBalance(owner.address);

      expect(finalOwnerBalance - initialOwnerBalance).to.be.gt(
        ethers.parseEther("0.9")
      );
    });

    it("Should allow owner to withdraw specific funds", async function () {
      const { botInteractions, owner } = await loadFixture(
        deployBotInteractionsFixture
      );

      await botInteractions.depositFunds({ value: ethers.parseEther("2") });
      const initialOwnerBalance = await ethers.provider.getBalance(
        owner.address
      );

      await botInteractions.withdrawFunds(ethers.parseEther("1"));

      const finalOwnerBalance = await ethers.provider.getBalance(owner.address);
      expect(finalOwnerBalance - initialOwnerBalance).to.be.gt(
        ethers.parseEther("0.9")
      );
    });

    it("Should fail if non-owner tries to withdraw funds", async function () {
      const { botInteractions, user } = await loadFixture(
        deployBotInteractionsFixture
      );
      await expect(
        botInteractions.connect(user).withdrawAllFunds()
      ).to.be.revertedWith("Not authorized");
    });
  });

  describe("ERC20 Withdrawals", function () {
    it("Should allow owner to withdraw ERC20 tokens", async function () {
      const { botInteractions, owner, erc20Mock } = await loadFixture(
        deployBotInteractionsFixture
      );
      await erc20Mock.transfer(botInteractions.getAddress(), tokenAmount);
      const initialBalance = await erc20Mock.balanceOf(owner.address);
      await botInteractions.withdrawERC20(erc20Mock.getAddress(), tokenAmount);
      const finalBalance = await erc20Mock.balanceOf(owner.address);
      expect(finalBalance - initialBalance).to.equal(tokenAmount);
    });

    it("Should fail if non-owner tries to withdraw ERC20 tokens", async function () {
      const { botInteractions, erc20Mock, user } = await loadFixture(
        deployBotInteractionsFixture
      );
      await expect(
        botInteractions
          .connect(user)
          .withdrawERC20(erc20Mock.getAddress(), tokenAmount)
      ).to.be.revertedWith("Not authorized");
    });
  });

  describe("Get Contract and Token Balance", function () {
    it("Should return the correct contract balance", async function () {
      const { botInteractions } = await loadFixture(
        deployBotInteractionsFixture
      );
      await botInteractions.depositFunds({ value: ethers.parseEther("2") });
      const balance = await botInteractions.getContractBalance();
      expect(balance).to.equal(ethers.parseEther("2"));
    });

    it("Should return the correct ERC20 token balance", async function () {
      const { botInteractions, erc20Mock, owner } = await loadFixture(
        deployBotInteractionsFixture
      );
      const balance = await botInteractions.getERC20Balance(
        erc20Mock.getAddress(),
        owner.address
      );
      expect(balance).to.equal(ethers.parseEther("100") - tokenAmount);
    });
  });
});
