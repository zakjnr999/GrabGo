const prisma = require('../config/prisma');

/**
 * Promo Code Service
 * 
 * Handles validation, application, and tracking of promotional codes
 */

/**
 * Validate a promo code for a user and order
 * @param {string} code - Promo code to validate
 * @param {string} userId - User ID
 * @param {number} orderAmount - Order subtotal
 * @param {string} orderType - 'food' or 'grocery'
 * @returns {Promise<Object>} Validation result with discount info
 */
const validatePromoCode = async (code, userId, orderAmount, orderType) => {
    try {
        // Find the promo code (case-insensitive)
        const promo = await prisma.promoCode.findUnique({
            where: { code: code.toUpperCase() },
            include: {
                targetedUsers: true
            }
        });

        if (!promo || !promo.isActive) {
            return {
                valid: false,
                error: 'Invalid or inactive promo code'
            };
        }

        // Check date validity
        const now = new Date();
        if (promo.startDate && now < promo.startDate) {
            return {
                valid: false,
                error: 'This promo code is not yet active'
            };
        }
        if (promo.endDate && now > promo.endDate) {
            return {
                valid: false,
                error: 'This promo code has expired'
            };
        }

        // Check global usage limit
        if (promo.maxUses !== null && promo.currentUses >= promo.maxUses) {
            return {
                valid: false,
                error: 'This promo code has reached its usage limit'
            };
        }

        // Check order type applicability
        if (promo.applicableOrderTypes.length > 0 &&
            !promo.applicableOrderTypes.includes(orderType)) {
            return {
                valid: false,
                error: `This promo code is only valid for ${promo.applicableOrderTypes.join(' or ')} orders`
            };
        }

        // Check minimum order amount
        if (orderAmount < promo.minOrderAmount) {
            return {
                valid: false,
                error: `Minimum order amount is GHS ${promo.minOrderAmount}`
            };
        }

        // Check user-specific restrictions
        if (promo.targetedUsers.length > 0) {
            const isTargeted = promo.targetedUsers.some(
                target => target.userId === userId
            );
            if (!isTargeted) {
                return {
                    valid: false,
                    error: 'This promo code is not available for your account'
                };
            }
        }

        // Check first order only restriction
        if (promo.firstOrderOnly) {
            const orderCount = await prisma.order.count({
                where: {
                    customerId: userId,
                    status: { in: ['delivered', 'confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way'] }
                }
            });
            if (orderCount > 0) {
                return {
                    valid: false,
                    error: 'This promo code is only valid for first-time orders'
                };
            }
        }

        // Check per-user usage limit
        const userUsageCount = await prisma.order.count({
            where: {
                customerId: userId,
                promoCode: code.toUpperCase(),
                status: { not: 'cancelled' }
            }
        });

        if (userUsageCount >= promo.maxUsesPerUser) {
            return {
                valid: false,
                error: 'You have already used this promo code'
            };
        }

        // Calculate discount
        const discount = calculateDiscount(promo, orderAmount);

        return {
            valid: true,
            discount,
            type: promo.type,
            description: promo.description,
            message: getSuccessMessage(promo, discount)
        };

    } catch (error) {
        console.error('Error validating promo code:', error.message);
        return {
            valid: false,
            error: 'Failed to validate promo code'
        };
    }
};

/**
 * Calculate discount amount based on promo type
 * @param {Object} promo - PromoCode object
 * @param {number} orderAmount - Order subtotal
 * @returns {number} Discount amount
 */
const calculateDiscount = (promo, orderAmount) => {
    let discount = 0;

    switch (promo.type) {
        case 'percentage':
            discount = (orderAmount * promo.value) / 100;
            break;
        case 'fixed':
            discount = promo.value;
            break;
        case 'free_delivery':
            // Delivery fee will be handled separately in order creation
            discount = 0;
            break;
    }

    // Apply max discount cap if set
    if (promo.maxDiscountAmount !== null && discount > promo.maxDiscountAmount) {
        discount = promo.maxDiscountAmount;
    }

    // Ensure discount doesn't exceed order amount
    if (discount > orderAmount) {
        discount = orderAmount;
    }

    return Math.round(discount * 100) / 100; // Round to 2 decimals
};

/**
 * Generate success message for valid promo code
 * @param {Object} promo - PromoCode object
 * @param {number} discount - Calculated discount
 * @returns {string} Success message
 */
const getSuccessMessage = (promo, discount) => {
    switch (promo.type) {
        case 'percentage':
            return `${promo.value}% discount applied! You save GHS ${discount.toFixed(2)}`;
        case 'fixed':
            return `GHS ${promo.value} discount applied!`;
        case 'free_delivery':
            return 'Free delivery applied!';
        default:
            return 'Promo code applied successfully!';
    }
};

/**
 * Apply promo code to an order (after order creation)
 * @param {string} code - Promo code
 * @param {string} userId - User ID
 * @param {string} orderId - Order ID
 * @param {number} discountAmount - Pre-calculated discount
 * @returns {Promise<Object>} Application result
 */
const applyPromoCode = async (code, userId, orderId, discountAmount) => {
    try {
        const promo = await prisma.promoCode.findUnique({
            where: { code: code.toUpperCase() }
        });

        if (!promo || !promo.isActive) {
            throw new Error('Promo code not found or inactive');
        }

        // Atomic update for usage count
        const updated = await prisma.promoCode.update({
            where: {
                id: promo.id,
                isActive: true,
                AND: [
                    { OR: [{ maxUses: null }, { currentUses: { lt: promo.maxUses } }] }
                ]
            },
            data: { currentUses: { increment: 1 } }
        }).catch(() => null);

        if (!updated) {
            throw new Error('Promo code usage limit reached');
        }

        // Note: In Prisma, we don't have a direct equivalent of $push to a JSON field on User 
        // if user history is not a separate model. Instead, we rely on the Order record 
        // which now contains promoCode and promoDiscount.

        console.log(`✅ Promo code ${code} applied to order ${orderId}`);

        return {
            success: true,
            discountApplied: discountAmount
        };

    } catch (error) {
        console.error('Error applying promo code:', error.message);
        return {
            success: false,
            error: error.message
        };
    }
};

/**
 * Create a new promo code (admin function)
 * @param {Object} codeData - Promo code data
 * @returns {Promise<Object>} Created promo code
 */
const createPromoCode = async (codeData) => {
    try {
        const { targetedUsers, ...rest } = codeData;

        const promo = await prisma.promoCode.create({
            data: {
                ...rest,
                targetedUsers: {
                    create: targetedUsers ? targetedUsers.map(userId => ({ userId })) : []
                }
            }
        });

        console.log(`✅ Created promo code: ${promo.code}`);
        return promo;
    } catch (error) {
        if (error.code === 'P2002') {
            throw new Error('Promo code already exists');
        }
        throw error;
    }
};

/**
 * Get all active promo codes available to a user
 * @param {string} userId - User ID
 * @returns {Promise<Array>} List of available promo codes
 */
const getAvailablePromoCodes = async (userId) => {
    try {
        const now = new Date();

        const promos = await prisma.promoCode.findMany({
            where: {
                isActive: true,
                AND: [
                    { OR: [{ startDate: null }, { startDate: { lte: now } }] },
                    { OR: [{ endDate: null }, { endDate: { gte: now } }] },
                    {
                        OR: [
                            { targetedUsers: { none: {} } },
                            { targetedUsers: { some: { userId } } }
                        ]
                    }
                ]
            },
            select: {
                code: true,
                description: true,
                type: true,
                value: true,
                minOrderAmount: true,
                endDate: true
            }
        });

        return promos;
    } catch (error) {
        console.error('Error fetching available promo codes:', error.message);
        return [];
    }
};

/**
 * Get all promo codes (admin function)
 * @returns {Promise<Array>} All promo codes
 */
const getAllPromoCodes = async () => {
    try {
        return await prisma.promoCode.findMany({
            orderBy: { createdAt: 'desc' }
        });
    } catch (error) {
        console.error('Error fetching all promo codes:', error.message);
        return [];
    }
};

/**
 * Deactivate a promo code
 * @param {string} code - Promo code to deactivate
 * @returns {Promise<boolean>} Success status
 */
const deactivatePromoCode = async (code) => {
    try {
        await prisma.promoCode.update({
            where: { code: code.toUpperCase() },
            data: { isActive: false }
        });
        console.log(`✅ Deactivated promo code: ${code}`);
        return true;
    } catch (error) {
        console.error('Error deactivating promo code:', error.message);
        return false;
    }
};

module.exports = {
    validatePromoCode,
    applyPromoCode,
    createPromoCode,
    getAvailablePromoCodes,
    getAllPromoCodes,
    deactivatePromoCode,
    calculateDiscount
};
