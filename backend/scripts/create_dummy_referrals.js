require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const ReferralCode = require('../models/ReferralCode');
const Referral = require('../models/Referral');
const UserCredit = require('../models/UserCredit');

async function createDummyReferralData() {
    try {
        console.log('🔄 Starting dummy referral data creation...\n');

        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB\n');

        // Get your user
        const yourEmail = 'zakjnr5@gmail.com';
        const user = await User.findOne({ email: yourEmail });

        if (!user) {
            console.error('❌ User not found with email:', yourEmail);
            process.exit(1);
        }

        console.log(`✅ Found user: ${user.username} (${user.email})\n`);

        // Get or create referral code
        let referralCode = await ReferralCode.findOne({ user: user._id });
        if (!referralCode) {
            console.log('📝 Creating referral code...');
            referralCode = await ReferralCode.create({
                user: user._id,
                code: 'BOSS2024'
            });
        }
        console.log(`✅ Referral code: ${referralCode.code}\n`);

        // Ask how many referrals to create
        const numReferrals = parseInt(process.argv[2]) || 3;
        console.log(`📊 Creating ${numReferrals} dummy referrals...\n`);

        // Create dummy users and referrals
        const dummyNames = [
            'John Doe', 'Jane Smith', 'Mike Johnson', 'Sarah Williams',
            'David Brown', 'Emily Davis', 'Chris Wilson', 'Lisa Anderson',
            'Tom Martinez', 'Anna Taylor', 'James Moore', 'Maria Garcia',
            'Robert Lee', 'Jennifer White', 'Michael Harris'
        ];

        let completedCount = 0;

        for (let i = 0; i < numReferrals; i++) {
            const name = dummyNames[i % dummyNames.length];
            const email = `dummy${i + 1}@test.com`;
            const username = name.toLowerCase().replace(' ', '_');

            // Check if dummy user already exists
            let dummyUser = await User.findOne({ email });

            if (!dummyUser) {
                // Create dummy user
                dummyUser = await User.create({
                    username,
                    email,
                    password: '$2a$10$dummyhashedpassword', // Dummy hash
                    isEmailVerified: true
                });
                console.log(`✅ Created dummy user: ${name} (${email})`);
            } else {
                console.log(`ℹ️  Dummy user already exists: ${name} (${email})`);
            }

            // Check if referral already exists
            let existingReferral = await Referral.findOne({
                referrer: user._id,
                referee: dummyUser._id
            });

            if (!existingReferral) {
                // Determine status (make some completed, some pending)
                const status = i < Math.floor(numReferrals * 0.7) ? 'completed' : 'pending_order';

                // Set expiry date (30 days from now)
                const expiresAt = new Date();
                expiresAt.setDate(expiresAt.getDate() + 30);

                // Create referral
                const referral = await Referral.create({
                    referrer: user._id,
                    referee: dummyUser._id,
                    referralCode: referralCode.code,
                    status,
                    referrerCreditAmount: 10.00,
                    refereeCreditAmount: 10.00,
                    expiresAt,
                    completedAt: status === 'completed' ? new Date() : null
                });

                console.log(`   ➕ Created referral: ${name} - ${status}`);

                if (status === 'completed') {
                    completedCount++;

                    // Add credit for completed referral
                    const creditExpiry = new Date();
                    creditExpiry.setDate(creditExpiry.getDate() + 90);

                    await UserCredit.create({
                        user: user._id,
                        amount: 10.00,
                        source: 'referral_earned',
                        expiresAt: creditExpiry,
                        description: `Referral credit from ${name}`
                    });

                    console.log(`   💰 Added GHS 10.00 credit`);

                    // Check for milestone bonus (every 5 completed)
                    if (completedCount % 5 === 0) {
                        const bonusExpiry = new Date();
                        bonusExpiry.setDate(bonusExpiry.getDate() + 90);

                        await UserCredit.create({
                            user: user._id,
                            amount: 5.00,
                            source: 'bonus',
                            expiresAt: bonusExpiry,
                            description: `Milestone bonus - ${completedCount} referrals completed!`
                        });

                        console.log(`   🏆 MILESTONE BONUS! GHS 5.00 added (${completedCount} referrals)`);
                    }
                }
            } else {
                console.log(`   ℹ️  Referral already exists for ${name}`);
            }
        }

        // Update referral code stats
        const totalReferrals = await Referral.countDocuments({ referrer: user._id });
        const completedReferrals = await Referral.countDocuments({
            referrer: user._id,
            status: 'completed'
        });

        const totalEarned = (completedReferrals * 10) + (Math.floor(completedReferrals / 5) * 5);

        await ReferralCode.findByIdAndUpdate(referralCode._id, {
            totalReferrals,
            completedReferrals,
            totalEarned
        });

        console.log('\n📊 Final Statistics:');
        console.log(`   Total Referrals: ${totalReferrals}`);
        console.log(`   Completed Referrals: ${completedReferrals}`);
        console.log(`   Total Earned: GHS ${totalEarned.toFixed(2)}`);
        console.log(`   Milestones Achieved: ${Math.floor(completedReferrals / 5)}`);
        console.log(`   Progress to Next: ${completedReferrals % 5}/5`);

        console.log('\n✅ Dummy referral data created successfully!');
        console.log('\n💡 Tip: Run the app and check the referral page to see the milestone tracker!');

        process.exit(0);
    } catch (error) {
        console.error('\n❌ Error creating dummy data:', error);
        process.exit(1);
    }
}

// Usage: node create_dummy_referrals.js [number_of_referrals]
// Example: node create_dummy_referrals.js 8
createDummyReferralData();
