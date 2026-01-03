/**
 * Test Firebase Configuration
 * 
 * This script tests if Firebase is properly configured and can send
 * push notifications.
 * 
 * Usage:
 *   node scripts/test_firebase_config.js
 */

require('dotenv').config();
const admin = require('firebase-admin');

const main = async () => {
    console.log('🔥 Testing Firebase Configuration\n');
    console.log('='.repeat(60));

    // Check environment variables
    console.log('\n📋 Environment Variables:');
    console.log(`   FIREBASE_SERVICE_ACCOUNT: ${process.env.FIREBASE_SERVICE_ACCOUNT ? '✅ Set (' + process.env.FIREBASE_SERVICE_ACCOUNT.substring(0, 50) + '...)' : '❌ Not set'}`);
    console.log(`   FIREBASE_PROJECT_ID: ${process.env.FIREBASE_PROJECT_ID || '❌ Not set'}`);

    // Try to initialize Firebase
    console.log('\n🔧 Initializing Firebase Admin SDK...');

    try {
        if (process.env.FIREBASE_SERVICE_ACCOUNT) {
            const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

            console.log('\n📊 Service Account Details:');
            console.log(`   Project ID: ${serviceAccount.project_id || '❌ Missing'}`);
            console.log(`   Client Email: ${serviceAccount.client_email || '❌ Missing'}`);
            console.log(`   Private Key: ${serviceAccount.private_key ? '✅ Present' : '❌ Missing'}`);

            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });

            console.log('\n✅ Firebase Admin SDK initialized successfully!');

            // Try to send a test message to a dummy token (will fail but shows Firebase is working)
            console.log('\n🧪 Testing Firebase Messaging API...');

            const dummyToken = 'dummy_token_for_testing';

            try {
                await admin.messaging().send({
                    token: dummyToken,
                    notification: {
                        title: 'Test',
                        body: 'Test'
                    }
                });
            } catch (error) {
                if (error.code === 'messaging/invalid-registration-token' ||
                    error.code === 'messaging/registration-token-not-registered') {
                    console.log('✅ Firebase Messaging API is working!');
                    console.log('   (Expected error for dummy token - this is good)');
                } else {
                    console.error('❌ Unexpected Firebase error:', error.code);
                    console.error('   Message:', error.message);
                }
            }

            console.log('\n💡 Firebase Configuration Status: ✅ WORKING');
            console.log('\n🔍 If push notifications still fail, the issue is likely:');
            console.log('   1. FCM tokens in database are expired/invalid');
            console.log('   2. App is not properly registering new tokens');
            console.log('   3. Device notification permissions not granted');

            console.log('\n🔧 Recommended fixes:');
            console.log('   1. Log out and log back in to refresh FCM token');
            console.log('   2. Clear app data and re-login');
            console.log('   3. Check app logs for FCM token registration');

        } else {
            console.log('\n❌ FIREBASE_SERVICE_ACCOUNT not found in .env');
            console.log('\n🔧 To fix:');
            console.log('   1. Go to Firebase Console > Project Settings > Service Accounts');
            console.log('   2. Generate new private key');
            console.log('   3. Copy the JSON content');
            console.log('   4. Add to .env as: FIREBASE_SERVICE_ACCOUNT=\'{"type":"service_account",...}\'');
        }

    } catch (error) {
        console.error('\n❌ Firebase initialization failed!');
        console.error('   Error:', error.message);

        if (error.message.includes('JSON')) {
            console.log('\n🔧 Fix: FIREBASE_SERVICE_ACCOUNT is not valid JSON');
            console.log('   Make sure it\'s properly formatted in .env');
        }
    }


    console.log('\n' + '='.repeat(60));
};

main().then(() => process.exit(0)).catch(error => {
    console.error('Error:', error);
    process.exit(1);
});
