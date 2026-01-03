require('dotenv').config();
const mongoose = require('mongoose');
const ReferralCode = require('../models/ReferralCode');

// Helper function to generate random referral code (same as in routes/referrals.js)
const generateReferralCode = async () => {
    // Characters to use: uppercase letters and numbers (excluding similar-looking ones)
    // Excluded: 0, O, I, 1, L to avoid confusion
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

    // Try to generate a unique 8-character code
    for (let attempt = 0; attempt < 20; attempt++) {
        let code = '';
        for (let i = 0; i < 8; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }

        // Check if code already exists
        const exists = await ReferralCode.findOne({ code });
        if (!exists) {
            return code;
        }
    }

    // Fallback: use timestamp-based code (very unlikely to reach here)
    const timestamp = Date.now().toString(36).toUpperCase();
    const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `${timestamp}${randomSuffix}`.substring(0, 8);
};

async function updateReferralCodes() {
    try {
        console.log('🔄 Starting referral code update...\n');

        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB\n');

        // Get all referral codes
        const allCodes = await ReferralCode.find({});
        console.log(`📊 Found ${allCodes.length} referral codes to update\n`);

        if (allCodes.length === 0) {
            console.log('ℹ️  No referral codes found in database');
            process.exit(0);
        }

        let updatedCount = 0;
        let skippedCount = 0;

        for (const referralCode of allCodes) {
            const oldCode = referralCode.code;

            // Check if code is already in new format (8 chars, alphanumeric)
            const isNewFormat = /^[A-Z0-9]{8}$/.test(oldCode) &&
                !oldCode.includes('2024') &&
                !oldCode.includes('USER');

            if (isNewFormat) {
                console.log(`⏭️  Skipping ${oldCode} (already in new format)`);
                skippedCount++;
                continue;
            }

            // Generate new random code
            const newCode = await generateReferralCode();

            // Update the code
            referralCode.code = newCode;
            await referralCode.save();

            console.log(`✅ Updated: ${oldCode} → ${newCode}`);
            updatedCount++;
        }

        console.log('\n' + '='.repeat(50));
        console.log('📊 Update Summary:');
        console.log('='.repeat(50));
        console.log(`Total codes found:     ${allCodes.length}`);
        console.log(`Codes updated:         ${updatedCount}`);
        console.log(`Codes skipped:         ${skippedCount}`);
        console.log('='.repeat(50) + '\n');

        console.log('✅ All referral codes updated successfully!');
        console.log('ℹ️  All referrals and stats are preserved\n');

        await mongoose.connection.close();
        console.log('✅ Database connection closed');
        process.exit(0);

    } catch (error) {
        console.error('❌ Error updating referral codes:', error);
        process.exit(1);
    }
}

// Run the update
updateReferralCodes();
