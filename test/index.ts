import { assert } from "chai";
import {
  BN,
  expectEvent,
  expectRevert,
  // @ts-ignore
} from "@openzeppelin/test-helpers";
import { parseEther } from "ethers/lib/utils";
import { artifacts, contract, ethers } from "hardhat";

const MockERC20 = artifacts.require("./test/MockERC20.sol");
const URAGame = artifacts.require("./URAGame.sol");

contract("URAGame", ([root, charity, alice, bob, carol, deployer]) => {
  let tbccGame: any;
  let mockBUSD: any;
  let rootBalance: any;
  let charityBalance: any;
  let result: any;

  before(async () => {
    // Deploy ERC20s
    mockBUSD = await MockERC20.new("BUSD", "BUSD", parseEther("1000000"), {
      from: deployer,
    });

    // Deploy TBCCGame
    tbccGame = await URAGame.new(root, charity, mockBUSD.address, {
      from: deployer,
    });

    await mockBUSD.transfer(alice, parseEther("10000"), { from: deployer });
    await mockBUSD.transfer(bob, parseEther("10000"), { from: deployer });
    await mockBUSD.transfer(carol, parseEther("10000"), { from: deployer });
  });

  describe("INIT Game", async () => {
    it("Initial parameters are correct", async () => {
      assert.equal(String(await tbccGame.getTablesCount()), "11");
      assert.equal(String(await tbccGame.rootAddress()), root);
      assert.equal(String(await tbccGame.charityAddress()), charity);
      assert.equal(String(await tbccGame.busdToken()), mockBUSD.address);
      assert.equal(
        String(await tbccGame.verificationCost()),
        parseEther("10").toString()
      );
    });

    it("Verification", async () => {
      result = await mockBUSD.approve(
        tbccGame.address,
        parseEther("10").toString(),
        { from: alice }
      );

      expectEvent(result, "Approval");

      result = await tbccGame.verification({ from: alice });

      expectEvent(result, "UserVerification", {
        user: alice,
      });

      await mockBUSD.approve(tbccGame.address, parseEther("10").toString(), {
        from: bob,
      });

      await tbccGame.verification({ from: bob });
    });

    it("buy table by transfer", async () => {
      const signerAlice = await ethers.getSigner(alice);

      assert.equal(
        String(await ethers.provider.getBalance(tbccGame.address)),
        "0"
      );

      rootBalance = await ethers.provider.getBalance(root);
      charityBalance = await ethers.provider.getBalance(charity);

      assert.equal(String(rootBalance), parseEther("10000").toString());

      assert.equal(String(charityBalance), parseEther("10000").toString());

      await signerAlice.sendTransaction({
        to: tbccGame.address,
        value: ethers.utils.parseEther("0.1"),
      });

      assert.equal(
        String(await ethers.provider.getBalance(tbccGame.address)),
        parseEther("0.025").toString()
      );

      assert.equal(
        String(await ethers.provider.getBalance(root)),
        new BN(rootBalance.toString())
          .add(new BN(parseEther("0.065").toString()))
          .toString()
      );

      assert.equal(
        String(await ethers.provider.getBalance(charity)),
        new BN(charityBalance.toString())
          .add(new BN(parseEther("0.01").toString()))
          .toString()
      );
    });

    it("buy table by function", async () => {
      rootBalance = await ethers.provider.getBalance(root);
      charityBalance = await ethers.provider.getBalance(charity);

      await expectRevert(
        tbccGame.buy(carol, {
          from: bob,
          value: parseEther("50").toString(),
        }),
        "Only to next table"
      );

      result = await tbccGame.buy(alice, {
        from: bob,
        value: parseEther("0.1").toString(),
      });

      expectEvent(result, "InvestmentReceived", {
        table: "1",
      });

      expectEvent(result, "ReferralRewardSent", {
        to: alice,
        value: parseEther("0.025").toString(),
        table: "1",
      });

      expectEvent(result, "DonationRewardSent", {
        to: alice || root,
        value: parseEther("0.008").toString(),
        table: "1",
      });

      expectEvent(result, "DonationReferralRewardSent", {
        to: root,
        value: parseEther("0.005").toString(),
        table: "1",
      });

      expectEvent(result, "CharitySent", {
        to: charity,
        table: "1",
      });

      assert.equal(
        String(await ethers.provider.getBalance(charity)),
        new BN(charityBalance.toString())
          .add(new BN(parseEther("0.01").toString()))
          .toString()
      );

      // Errors
      await expectRevert(
        tbccGame.buy(alice, {
          from: carol,
          value: parseEther("0.1").toString(),
        }),
        "Only verified users"
      );

      await expectRevert(
        tbccGame.buy(carol, {
          from: bob,
          value: parseEther("50").toString(),
        }),
        "Only to next table"
      );

      result = await tbccGame.buy(carol, {
        from: bob,
        value: parseEther("0.2").toString(),
      });

      expectEvent(result, "InvestmentReceived", {
        table: "2",
      });

      expectEvent(result, "ReferralRewardSent", {
        to: alice,
        value: parseEther("0.05").toString(),
        table: "2",
      });

      expectEvent(result, "DonationRewardSent", {
        to: root,
        value: parseEther("0.016").toString(),
        table: "2",
      });

      expectEvent(result, "CharitySent", {
        to: charity,
        table: "2",
      });
    });

    it("Getting table address count", async () => {
      assert.equal(String(await tbccGame.getTableAddressesCount("1")), "3");
    });

    it("Getting table Threshold", async () => {
      assert.equal(
        String(await tbccGame.getTableThreshold("1")),
        parseEther("0.1").toString()
      );
    });

    it("Getting customer information", async () => {
      result = await tbccGame.info(alice);
      console.log("result", result);
    });

    it("Getting table information", async () => {
      result = await tbccGame.infoTable(1, alice);
      console.log("result", result);
    });
  });
});
