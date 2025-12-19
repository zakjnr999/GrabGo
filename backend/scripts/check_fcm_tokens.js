/**
 * Check FCM Tokens for User
 * 
 * This script checks the FCM tokens registered for a specific user
 * and shows their status.
 * 
 * Usage:
 *   node scripts/check_fcm_tokens.js <email>
 *   node scripts/check_fcm_tokens.js zakjnr5@gmail.com
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

// Connect to MongoDB
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

// Main function
const main = async () => {
    console.log('📱 Checking FCM Tokens\n');
    console.log('='.repeat(60));

    await connectDB();

    const userIdentifier = process.argv[2] || 'zakjnr5@gmail.com';

    try {
        // Find user
        const user = await User.findOne({
            $or: [
                { email: userIdentifier },
                { username: userIdentifier },
                { _id: mongoose.Types.ObjectId.isValid(userIdentifier) ? userIdentifier : null }
            ]
        });

        if (!user) {
            console.error(`\n❌ User not found: ${userIdentifier}`);
            process.exit(1);
        }

        console.log(`\n✅ User: ${user.username} (${user.email})`);
        console.log(`   ID: ${user._id}`);

        // Check FCM tokens
        const fcmTokens = user.fcmTokens || [];

        console.log(`\n📊 FCM Token Status:`);
        console.log(`   Total Tokens: ${fcmTokens.length}`);

        if (fcmTokens.length === 0) {
            console.log('\n❌ No FCM tokens registered!');
            console.log('\n💡 This is why you\'re not getting push notifications.');
            console.log('\n🔧 To fix:');
            console.log('   1. Open the app');
            console.log('   2. Log out and log back in');
            console.log('   3. Grant notification permissions when prompted');
            console.log('   4. The app should automatically register a new FCM token');
        } else {
            console.log('\n📱 Registered Tokens:');
            fcmTokens.forEach((token, index) => {
                console.log(`\n   Token ${index + 1}:`);
                console.log(`   ${token.substring(0, 50)}...`);
                console.log(`   Length: ${token.length} characters`);
            });

            console.log('\n⚠️  Tokens exist but push notifications failed (0/5 succeeded)');
            console.log('\n🔍 Possible issues:');
            console.log('   1. Tokens are expired/invalid');
            console.log('   2. Firebase credentials in .env are incorrect');
            console.log('   3. FCM service account key is wrong');
            console.log('   4. Device is not connected to internet');
            console.log('   5. App is not properly configured for FCM');

            console.log('\n🔧 To fix:');
            console.log('   1. Check .env file has correct FIREBASE_SERVICE_ACCOUNT_KEY');
            console.log('   2. Verify Firebase project settings');
            console.log('   3. Try logging out and back in to refresh tokens');
            console.log('   4. Check Firebase Console for error logs');
        }

        console.log('\n' + '='.repeat(60));

    } catch (error) {
        console.error('\n❌ Error:', error.message);
    }

    process.exit(0);
};

// Run
main().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
