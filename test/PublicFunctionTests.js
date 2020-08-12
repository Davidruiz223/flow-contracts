const flow = artifacts.require("FLOW");
const truffleAssert = require('truffle-assertions');

contract("FLOW", async accounts => {
    beforeEach(async () => {
        this.contract = await flow.new();
    });
    it("has the correct total supply", async () => {
        let supply = await this.contract.totalSupply();
        assert.equal(supply.toString(), '10000000000000000');
    });
    it("mints to owner account", async () => {
        let balance = await this.contract.balanceOf(accounts[0]);
        assert.equal(balance.toString(), '10000000000000000');
    });
    it("does not allow transfer more than balance", async () => {
        let balance = await this.contract.balanceOf(accounts[0]);
        await truffleAssert.fails(this.contract.transfer(accounts[1], balance + 1, {from:accounts[0]}));
    });
    it("does not allow transfer when account has zero balance", async () => {
        await truffleAssert.fails(this.contract.transfer(accounts[2], 1, {from:accounts[1]}));
    });
    it("allows transfer of entire balance", async () => {
        let originalBalance = await this.contract.balanceOf(accounts[0]);
        await this.contract.transfer(accounts[1], originalBalance, {from:accounts[0]});
        let newBalance = await this.contract.balanceOf(accounts[0]);
        assert.equal(newBalance, 0);
        let recipientBalance = await this.contract.balanceOf(accounts[1]);
        assert.equal(recipientBalance.toString(), originalBalance.toString());
    });
    it("allows transfer smallest portion of balance", async () => {
        let originalBalance = await this.contract.balanceOf(accounts[0]);
        await this.contract.transfer(accounts[1], 1, {from:accounts[0]});
        let newBalance = await this.contract.balanceOf(accounts[0]);
        assert.equal(newBalance, originalBalance - 1);
        let recipientBalance = await this.contract.balanceOf(accounts[1]);
        assert.equal(recipientBalance.toString(), 1);
    });
    it("allows approval", async () => {
        let originalBalance = await this.contract.balanceOf(accounts[0]);
        await this.contract.approve(accounts[1], 1, {from:accounts[0]});
        let newBalance = await this.contract.balanceOf(accounts[0]);
        assert.equal(newBalance.toString(), originalBalance.toString());
        let allowance = await this.contract.allowance(accounts[0], accounts[1]);
        assert.equal(allowance.toString(), 1);
    });
    it("allows spending approved funds", async () => {
        let originalBalance = await this.contract.balanceOf(accounts[0]);
        await this.contract.approve(accounts[1], originalBalance.toString(), {from:accounts[0]});
        await this.contract.transferFrom(accounts[0], accounts[1], originalBalance, {from:accounts[1]});
    });
    it("does not allow spending more than approved", async () => {
        let originalBalance = await this.contract.balanceOf(accounts[0]);
        await this.contract.approve(accounts[1], (originalBalance - 10).toString(), {from:accounts[0]});
        await truffleAssert.fails(this.contract.transferFrom(accounts[0], accounts[1], originalBalance, {from:accounts[1]}));
    });
    it("does not allow spending more than balance even if approved", async () => {
        let originalBalance = await this.contract.balanceOf(accounts[0]);
        await this.contract.approve(accounts[1], (originalBalance + 10).toString(), {from:accounts[0]});
        await truffleAssert.fails(this.contract.transferFrom(accounts[0], accounts[1], (originalBalance + 10).toString(), {from:accounts[1]}));
    });
    it("returns the start time", async () => {
        let startTime = await this.contract.startTime();
        assert(startTime > 0);
    });
});