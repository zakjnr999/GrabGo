const prisma = require('../config/prisma');

/**
 * Address Service
 * Handles user address management (CRUD)
 */

/**
 * Get all addresses for a user
 * @param {string} userId
 */
const getUserAddresses = async (userId) => {
    try {
        return await prisma.userAddress.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
        });
    } catch (error) {
        console.error('Error in getUserAddresses:', error.message);
        throw error;
    }
};

/**
 * Add a new address for a user
 * @param {string} userId
 * @param {Object} addressData
 */
const addUserAddress = async (userId, addressData) => {
    try {
        return await prisma.$transaction(async (tx) => {
            // If this is set as default, unset others
            if (addressData.isDefault) {
                await tx.userAddress.updateMany({
                    where: { userId, isDefault: true },
                    data: { isDefault: false },
                });
            }

            return await tx.userAddress.create({
                data: {
                    ...addressData,
                    userId,
                },
            });
        });
    } catch (error) {
        console.error('Error in addUserAddress:', error.message);
        throw error;
    }
};

/**
 * Update an existing address
 * @param {string} userId
 * @param {string} addressId
 * @param {Object} addressData
 */
const updateUserAddress = async (userId, addressId, addressData) => {
    try {
        return await prisma.$transaction(async (tx) => {
            // If this is set as default, unset others
            if (addressData.isDefault) {
                await tx.userAddress.updateMany({
                    where: { userId, isDefault: true },
                    data: { isDefault: false },
                });
            }

            return await tx.userAddress.update({
                where: { id: addressId, userId },
                data: addressData,
            });
        });
    } catch (error) {
        console.error('Error in updateUserAddress:', error.message);
        throw error;
    }
};

/**
 * Delete an address
 * @param {string} userId
 * @param {string} addressId
 */
const deleteUserAddress = async (userId, addressId) => {
    try {
        return await prisma.userAddress.delete({
            where: { id: addressId, userId },
        });
    } catch (error) {
        console.error('Error in deleteUserAddress:', error.message);
        throw error;
    }
};

/**
 * Set an address as default
 * @param {string} userId
 * @param {string} addressId
 */
const setDefaultAddress = async (userId, addressId) => {
    try {
        return await prisma.$transaction(async (tx) => {
            await tx.userAddress.updateMany({
                where: { userId, isDefault: true },
                data: { isDefault: false },
            });

            return await tx.userAddress.update({
                where: { id: addressId, userId },
                data: { isDefault: true },
            });
        });
    } catch (error) {
        console.error('Error in setDefaultAddress:', error.message);
        throw error;
    }
};

module.exports = {
    getUserAddresses,
    addUserAddress,
    updateUserAddress,
    deleteUserAddress,
    setDefaultAddress,
};
