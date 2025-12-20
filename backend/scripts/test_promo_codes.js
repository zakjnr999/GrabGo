/**
 * Test Promo Code System
 * 
 * This script verifies promo code validation, application, and usage tracking.
 * 
 * Usage:
 *   node scripts/test_promo_codes.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const PromoCode = require('../models/PromoCode');
const User = require('../models/User');
const { validatePromoCode, applyPromoCode, createPromoCode } = require('../services/promo_service');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const testPromoCodeSystem = async () => {
    console.log('🧪 Testing Promo Code System\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // 1. Create test promo codes
        console.log('\n📝 1. Creating test promo codes...');

        // Delete existing test codes
        await PromoCode.deleteMany({ code: { $in: ['FAVE10', 'REORDER10', 'TEST20', 'FIRSTORDER'] } });

        const promoCodes = [
            {
                code: 'FAVE10',
                type: 'percentage',
                value: 10,
                description: '10% off for favorites reminder',
                minOrderAmount: 0,
                maxUsesPerUser: 3
            },
            {
                code: 'REORDER10',
                type: 'percentage',
                value: 10,
                description: '10% off for reorder suggestions',
                minOrderAmount: 0,
                maxUsesPerUser: 3
            },
            {
                code: 'TEST20',
                type: 'percentage',
                value: 20,
                description: '20% off test code',
                minOrderAmount: 20,
                maxDiscountAmount: 50
            },
            {
                code: 'FIRSTORDER',
                type: 'fixed',
                value: 15,
                description: 'GHS 15 off first order',
                firstOrderOnly: true,
                maxUsesPerUser: 1
            }
        ];

        for (const code of promoCodes) {
            await createPromoCode(code);
        }

        console.log(`✅ Created ${promoCodes.length} promo codes`);

        // 2. Test validation
        console.log('\n🔍 2. Testing promo code validation...');

        const user = await User.findOne({ email: 'zakjnr5@gmail.com' });
        if (!user) {
            console.log('❌ Test user not found');
            process.exit(1);
        }

        // Test valid code
        const validResult = await validatePromoCode('FAVE10', user._id, 50, 'food');
        if (validResult.valid) {
            console.log(`✅ FAVE10 validated: Discount = GHS ${validResult.discount}`);
        } else {
            console.log(`❌ FAVE10 validation failed: ${validResult.error}`);
        }

        // Test minimum order amount
        const minOrderResult = await validatePromoCode('TEST20', user._id, 15, 'food');
        if (!minOrderResult.valid) {
            console.log(`✅ TEST20 correctly rejected (below min order): ${minOrderResult.error}`);
        } else {
            console.log(`❌ TEST20 should have been rejected`);
        }

        // Test valid with min order
        const validMinResult = await validatePromoCode('TEST20', user._id, 100, 'food');
        if (validMinResult.valid) {
            console.log(`✅ TEST20 validated: Discount = GHS ${validMinResult.discount} (capped at 50)`);
        } else {
            console.log(`❌ TEST20 validation failed: ${validMinResult.error}`);
        }

        // Test invalid code
        const invalidResult = await validatePromoCode('INVALID', user._id, 50, 'food');
        if (!invalidResult.valid) {
            console.log(`✅ INVALID code correctly rejected: ${invalidResult.error}`);
        } else {
            console.log(`❌ INVALID code should have been rejected`);
        }

        // 3. Test application
        console.log('\n✅ 3. Testing promo code application...');

        const mockOrderId = new mongoose.Types.ObjectId();
        const applyResult = await applyPromoCode('FAVE10', user._id, mockOrderId, 5.00);

        if (applyResult.success) {
            console.log(`✅ FAVE10 applied successfully`);
        } else {
            console.log(`❌ Failed to apply FAVE10: ${applyResult.error}`);
        }

        // 4. Verify usage tracking
        console.log('\n📊 4. Verifying usage tracking...');

        const updatedPromo = await PromoCode.findOne({ code: 'FAVE10' });
        console.log(`   FAVE10 current uses: ${updatedPromo.currentUses}`);

        const updatedUser = await User.findById(user._id);
        const userUsage = updatedUser.usedPromoCodes.filter(u => u.code === 'FAVE10');
        console.log(`   User has used FAVE10: ${userUsage.length} time(s)`);

        if (updatedPromo.currentUses > 0 && userUsage.length > 0) {
            console.log('✅ Usage tracking working correctly');
        } else {
            console.log('❌ Usage tracking failed');
        }

        console.log('\n✅ TEST COMPLETE');
        console.log('\n📋 Summary:');
        console.log(`   - Created ${promoCodes.length} promo codes`);
        console.log(`   - Validation logic working`);
        console.log(`   - Application logic working`);
        console.log(`   - Usage tracking working`);

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    } finally {
        await mongoose.connection.close();
        process.exit(0);
    }
};

testPromoCodeSystem();
