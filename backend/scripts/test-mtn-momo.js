/**
 * Test script for MTN MOMO payment integration
 * Usage: node scripts/test-mtn-momo.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const mtnMomoService = require('../services/mtn_momo_service');

async function testMTNMomoIntegration() {
  try {
    console.log('🧪 Testing MTN MOMO Integration...\n');

    // Test 1: Check environment variables
    console.log('1. Checking environment variables...');
    const requiredEnvVars = [
      'MTN_MOMO_SUBSCRIPTION_KEY',
      'MTN_MOMO_API_KEY',
      'MTN_MOMO_API_USER'
    ];

    const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);
    if (missingVars.length > 0) {
      console.error('❌ Missing environment variables:', missingVars.join(', '));
      return;
    }
    console.log('✅ Environment variables configured\n');

    // Test 2: Phone number validation
    console.log('2. Testing phone number validation...');
    const testPhoneNumbers = [
      '+233501234567',
      '233501234567',
      '0501234567',
      '501234567',
      'invalid-phone'
    ];

    testPhoneNumbers.forEach(phone => {
      const isValid = mtnMomoService.validateGhanaPhoneNumber(phone);
      const formatted = isValid ? mtnMomoService.formatPhoneNumber(phone) : 'N/A';
      console.log(`   ${phone} -> Valid: ${isValid ? '✅' : '❌'}, Formatted: ${formatted}`);
    });
    console.log();

    // Test 3: Get access token
    console.log('3. Testing access token retrieval...');
    try {
      const token = await mtnMomoService.getAccessToken();
      console.log('✅ Access token retrieved successfully');
      console.log(`   Token: ${token.substring(0, 20)}...`);
    } catch (error) {
      console.error('❌ Failed to get access token:', error.message);
      return;
    }
    console.log();

    // Test 4: Test payment request (will fail in sandbox without proper setup)
    console.log('4. Testing payment request...');
    const testPayment = {
      amount: 1.00, // 1 GHS for testing
      currency: 'GHS',
      phoneNumber: '233501234567',
      externalId: `TEST-${Date.now()}`,
      payerMessage: 'Test payment for GrabGo',
      payeeNote: 'Test payment'
    };

    try {
      const paymentResult = await mtnMomoService.requestToPay(testPayment);
      if (paymentResult.success) {
        console.log('✅ Payment request successful');
        console.log(`   Reference ID: ${paymentResult.referenceId}`);
        
        // Test payment status check
        console.log('\n5. Testing payment status check...');
        setTimeout(async () => {
          try {
            const statusResult = await mtnMomoService.getPaymentStatus(paymentResult.referenceId);
            console.log('✅ Payment status check successful');
            console.log(`   Status: ${statusResult.status}`);
          } catch (error) {
            console.error('❌ Payment status check failed:', error.message);
          }
        }, 2000);
        
      } else {
        console.log('⚠️  Payment request returned error (expected in sandbox)');
        console.log(`   Error: ${paymentResult.error}`);
        console.log(`   Code: ${paymentResult.code}`);
      }
    } catch (error) {
      console.error('❌ Payment request failed:', error.message);
    }

    console.log('\n🎉 MTN MOMO integration test completed!');
    console.log('\nNext steps:');
    console.log('1. Set up proper MTN MOMO sandbox credentials');
    console.log('2. Test with the mobile app');
    console.log('3. Implement proper error handling');
    console.log('4. Set up webhook endpoints');

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

// Run the test
if (require.main === module) {
  testMTNMomoIntegration();
}

module.exports = { testMTNMomoIntegration };