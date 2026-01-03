const mongoose = require('mongoose');
const ReferralCode = require('../models/ReferralCode');
require('dotenv').config();

async function createGrabGo10Code() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Check if GRABGO10 code already exists
        const existing = await ReferralCode.findOne({ code: 'GRABGO10' });

        if (existing) {
            console.log('⚠️  GRABGO10 code already exists!');
            console.log('Code:', existing.code);
            console.log('Discount: GHS', existing.discount);
            console.log('Min Order: GHS', existing.minOrderValue);
            console.log('Is Active:', existing.isActive);
            console.log('Total Referrals:', existing.totalReferrals);
            return;
        }

        // Create new GRABGO10 welcome code
        const grabGo10 = new ReferralCode({
            code: 'GRABGO10',
            isSystemCode: true,
            isActive: true,
            discount: 10.00,
            minOrderValue: 20.00,
            validDays: 365, // Valid for 1 year from when user applies it
            totalReferrals: 0,
            completedReferrals: 0,
            totalEarned: 0
        });

        await grabGo10.save();

        console.log('\n🎉 GRABGO10 Welcome Code Created Successfully!\n');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('Code:          ', grabGo10.code);
        console.log('Discount:      ', 'GHS', grabGo10.discount);
        console.log('Min Order:     ', 'GHS', grabGo10.minOrderValue);
        console.log('Valid Days:    ', grabGo10.validDays, 'days');
        console.log('System Code:   ', grabGo10.isSystemCode);
        console.log('Active:        ', grabGo10.isActive);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        console.log('✅ All new users can now use GRABGO10 for GHS 10 off!');

    } catch (error) {
        console.error('❌ Error creating GRABGO10 code:', error);
    } finally {
        await mongoose.disconnect();
        console.log('\n✅ Disconnected from MongoDB');
    }
}

createGrabGo10Code();
