const { accessControl, admin, other } = await loadFixture(deployAccessControlFixture);
            const role = await accessControl.OPERATOR_ROLE();

            // Pause
            await accessControl.connect(admin).pause();

            // Try to grant role while paused
            await expect(
                accessControl.connect(admin).grantRole(role, other.address)
            ).to.be.revertedWith("Pausable: paused");

            // Unpause
            await accessControl.connect(admin).unpause();

            // Should work after unpause
            await expect(
                accessControl.connect(admin).grantRole(role, other.address)
            ).to.not.be.reverted;
        });

        it("Should only allow SYSTEM_ADMIN to pause/unpause", async function () {
            const { accessControl, other } = await loadFixture(deployAccessControlFixture);

            await expect(
                accessControl.connect(other).pause()
            ).to.be.revertedWith("AccessControl:");

            await expect(
                accessControl.connect(other).unpause()
            ).to.be.revertedWith("AccessControl:");
        });
    });

    describe("Role Hierarchy", function () {
        it("Should enforce correct role hierarchy", async function () {
            const { accessControl, admin, gasManager, other } = await loadFixture(deployAccessControlFixture);
            const operatorRole = await accessControl.OPERATOR_ROLE();

            // GasManager should not be able to grant roles
            await expect(
                accessControl.connect(gasManager).grantRole(operatorRole, other.address)
            ).to.be.revertedWith("AccessControl:");

            // SystemAdmin should be able to grant roles
            await expect(
                accessControl.connect(admin).grantRole(operatorRole, other.address)
            ).to.not.be.reverted;
        });

        it("Should maintain role relationships after transfer", async function () {
            const { accessControl, admin, other } = await loadFixture(deployAccessControlFixture);
            const systemAdminRole = await accessControl.SYSTEM_ADMIN_ROLE();
            const operatorRole = await accessControl.OPERATOR_ROLE();

            // Transfer system admin role
            await accessControl.connect(admin).initiateRoleTransfer(systemAdminRole, other.address);
            await time.increase(2 * 24 * 60 * 60);
            await accessControl.connect(other).completeRoleTransfer(systemAdminRole);

            // New admin should be able to manage roles
            await expect(
                accessControl.connect(other).grantRole(operatorRole, admin.address)
            ).to.not.be.reverted;
        });
    });

    describe("Role Information", function () {
        it("Should return correct role members", async function () {
            const { accessControl, admin, gasManager } = await loadFixture(deployAccessControlFixture);
            
            expect(await accessControl.getRoleMember(await accessControl.SYSTEM_ADMIN_ROLE(), 0))
                .to.equal(admin.address);
            expect(await accessControl.getRoleMember(await accessControl.GAS_MANAGER_ROLE(), 0))
                .to.equal(gasManager.address);
        });

        it("Should track role member count correctly", async function () {
            const { accessControl, admin, other } = await loadFixture(deployAccessControlFixture);
            const operatorRole = await accessControl.OPERATOR_ROLE();

            const initialCount = await accessControl.getRoleMemberCount(operatorRole);
            await accessControl.connect(admin).grantRole(operatorRole, other.address);
            
            expect(await accessControl.getRoleMemberCount(operatorRole))
                .to.equal(initialCount.add(1));
        });
    });

    describe("Edge Cases", function () {
        it("Should handle multiple pending transfers correctly", async function () {
            const { accessControl, admin, other, gasManager } = await loadFixture(deployAccessControlFixture);
            const role1 = await accessControl.SYSTEM_ADMIN_ROLE();
            const role2 = await accessControl.GAS_MANAGER_ROLE();

            // Initiate transfers for different roles
            await accessControl.connect(admin).initiateRoleTransfer(role1, other.address);
            await accessControl.connect(admin).initiateRoleTransfer(role2, gasManager.address);

            const transfer1 = await accessControl.getRoleTransferStatus(role1);
            const transfer2 = await accessControl.getRoleTransferStatus(role2);

            expect(transfer1.pending).to.be.true;
            expect(transfer2.pending).to.be.true;
            expect(transfer1.newAdmin).to.equal(other.address);
            expect(transfer2.newAdmin).to.equal(gasManager.address);
        });

        it("Should not allow transfer to zero address", async function () {
            const { accessControl, admin } = await loadFixture(deployAccessControlFixture);
            const role = await accessControl.SYSTEM_ADMIN_ROLE();

            await expect(
                accessControl.connect(admin).initiateRoleTransfer(role, ethers.constants.AddressZero)
            ).to.be.revertedWith("Invalid new admin address");
        });

        it("Should handle consecutive role transfers", async function () {
            const { accessControl, admin, other, gasManager } = await loadFixture(deployAccessControlFixture);
            const role = await accessControl.SYSTEM_ADMIN_ROLE();

            // First transfer
            await accessControl.connect(admin).initiateRoleTransfer(role, other.address);
            await time.increase(2 * 24 * 60 * 60);
            await accessControl.connect(other).completeRoleTransfer(role);

            // Second transfer
            await accessControl.connect(other).initiateRoleTransfer(role, gasManager.address);
            await time.increase(2 * 24 * 60 * 60);
            await accessControl.connect(gasManager).completeRoleTransfer(role);

            expect(await accessControl.hasRole(role, gasManager.address)).to.be.true;
            expect(await accessControl.hasRole(role, other.address)).to.be.false;
            expect(await accessControl.hasRole(role, admin.address)).to.be.false;
        });
    });
});
