import { expect } from "chai";
import { ethers } from "hardhat";
import { 
    loadFixture, 
    time 
} from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { VerixTimelock } from "../typechain-types";

describe("VerixTimelock", function () {
    // Test fixtures
    async function deployTimelockFixture() {
        const [admin, proposer, executor, canceller, other] = await ethers.getSigners();
        
        const minDelay = 24 * 60 * 60; // 1 day
        const proposers = [proposer.address];
        const executors = [executor.address];
        
        const VerixTimelock = await ethers.getContractFactory("VerixTimelock");
        const timelock = await VerixTimelock.deploy(
            minDelay,
            proposers,
            executors,
            admin.address
        );
        
        await timelock.deployed();
        
        // Grant roles
        await timelock.grantRole(await timelock.CANCELLER_ROLE(), canceller.address);
        
        // Sample operation parameters
        const target = other.address;
        const value = ethers.utils.parseEther("1");
        const data = "0x";
        const predecessor = ethers.constants.HashZero;
        const salt = ethers.utils.id("salt");
        
        return { 
            timelock, 
            admin, 
            proposer, 
            executor, 
            canceller, 
            other,
            target,
            value,
            data,
            predecessor,
            salt,
            minDelay
        };
    }

    describe("Deployment", function () {
        it("Should set the correct minimum delay", async function () {
            const { timelock, minDelay } = await loadFixture(deployTimelockFixture);
            expect(await timelock.getMinDelay()).to.equal(minDelay);
        });

        it("Should assign the correct roles", async function () {
            const { timelock, admin, proposer, executor, canceller } = await loadFixture(deployTimelockFixture);
            
            expect(await timelock.hasRole(await timelock.DEFAULT_ADMIN_ROLE(), admin.address)).to.be.true;
            expect(await timelock.hasRole(await timelock.PROPOSAL_ROLE(), proposer.address)).to.be.true;
            expect(await timelock.hasRole(await timelock.EXECUTOR_ROLE(), executor.address)).to.be.true;
            expect(await timelock.hasRole(await timelock.CANCELLER_ROLE(), canceller.address)).to.be.true;
        });
    });

    describe("Operation Management", function () {
        describe("Scheduling", function () {
            it("Should allow proposer to schedule an operation", async function () {
                const { timelock, proposer, target, value, data, predecessor, salt } = 
                    await loadFixture(deployTimelockFixture);

                const tx = await timelock.connect(proposer).schedule(
                    target,
                    value,
                    data,
                    predecessor,
                    salt
                );

                const id = await timelock.hashOperation(target, value, data, predecessor, salt);
                await expect(tx)
                    .to.emit(timelock, "OperationQueued")
                    .withArgs(id, target, value, data, await time.latest() + await timelock.getMinDelay());
            });

            it("Should not allow non-proposer to schedule", async function () {
                const { timelock, other, target, value, data, predecessor, salt } = 
                    await loadFixture(deployTimelockFixture);

                await expect(
                    timelock.connect(other).schedule(target, value, data, predecessor, salt)
                ).to.be.revertedWith(
                    `AccessControl: account ${other.address.toLowerCase()} is missing role ${await timelock.PROPOSAL_ROLE()}`
                );
            });
        });

        describe("Execution", function () {
            it("Should execute scheduled operation after delay", async function () {
                const { timelock, proposer, executor, target, value, data, predecessor, salt } = 
                    await loadFixture(deployTimelockFixture);

                // Schedule operation
                await timelock.connect(proposer).schedule(
                    target,
                    value,
                    data,
                    predecessor,
                    salt
                );

                // Advance time
                await time.increase(await timelock.getMinDelay());

                // Execute operation
                const tx = await timelock.connect(executor).execute(
                    target,
                    value,
                    data,
                    predecessor,
                    salt
                );

                const id = await timelock.hashOperation(target, value, data, predecessor, salt);
                await expect(tx)
                    .to.emit(timelock, "OperationExecuted")
                    .withArgs(id, target, value, data);
            });

            it("Should not execute before delay", async function () {
                const { timelock, proposer, executor, target, value, data, predecessor, salt } = 
                    await loadFixture(deployTimelockFixture);

                await timelock.connect(proposer).schedule(
                    target,
                    value,
                    data,
                    predecessor,
                    salt
                );

                await expect(
                    timelock.connect(executor).execute(
                        target,
                        value,
                        data,
                        predecessor,
                        salt
                    )
                ).to.be.revertedWith("TimelockController: operation is not ready");
            });
        });

        describe("Cancellation", function () {
            it("Should allow canceller to cancel operation", async function () {
                const { timelock, proposer, canceller, target, value, data, predecessor, salt } = 
                    await loadFixture(deployTimelockFixture);

                await timelock.connect(proposer).schedule(
                    target,
                    value,
                    data,
                    predecessor,
                    salt
                );

                const tx = await timelock.connect(canceller).cancel(
                    target,
                    value,
                    data,
                    predecessor,
                    salt
                );

                const id = await timelock.hashOperation(target, value, data, predecessor, salt);
                await expect(tx)
                    .to.emit(timelock, "OperationCancelled")
                    .withArgs(id);
            });
        });
    });

    describe("Delay Management", function () {
        it("Should update delay within bounds", async function () {
            const { timelock, admin } = await loadFixture(deployTimelockFixture);
            const newDelay = 2 * 24 * 60 * 60; // 2 days

            const tx = await timelock.connect(admin).updateDelay(newDelay);
            const oldDelay = await timelock.getMinDelay();

            await expect(tx)
                .to.emit(timelock, "MinDelayChanged")
                .withArgs(oldDelay, newDelay);

            expect(await timelock.getMinDelay()).to.equal(newDelay);
        });

        it("Should not allow delay outside bounds", async function () {
            const { timelock, admin } = await loadFixture(deployTimelockFixture);
            const invalidDelay = 12 * 60 * 60; // 12 hours

            await expect(
                timelock.connect(admin).updateDelay(invalidDelay)
            ).to.be.revertedWith("Invalid delay");
        });
    });

    describe("Pause Functionality", function () {
        it("Should pause and unpause operations", async function () {
            const { timelock, admin, proposer, target, value, data, predecessor, salt } = 
                await loadFixture(deployTimelockFixture);

            // Pause
            await timelock.connect(admin).pause();

            // Try to schedule while paused
            await expect(
                timelock.connect(proposer).schedule(target, value, data, predecessor, salt)
            ).to.be.revertedWith("Pausable: paused");

            // Unpause
            await timelock.connect(admin).unpause();

            // Should work after unpause
            await expect(
                timelock.connect(proposer).schedule(target, value, data, predecessor, salt)
            ).to.not.be.reverted;
        });
    });
});
