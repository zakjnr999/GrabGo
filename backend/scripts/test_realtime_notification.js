const axios = require('axios');
const fs = require('fs');

// Read token from file
const token = fs.readFileSync('auth_token.txt', 'utf8').trim();

async function testNotification(status = 'confirmed') {
    try {
        console.log(`\n🧪 Testing ${status.toUpperCase()} notification...\n`);

        const response = await axios.post(
            'http://localhost:5000/api/test/order-notification',
            { status },
            {
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        console.log('✅ SUCCESS!');
        console.log('─'.repeat(80));
        console.log(`📱 ${response.data.message}`);
        console.log(`📋 Title: ${response.data.notification.title}`);
        console.log(`💬 Message: ${response.data.notification.message}`);
        console.log(`🕐 Created: ${response.data.notification.createdAt}`);
        console.log('─'.repeat(80));
        console.log('\n💡 Check your app NOW - the notification should appear instantly!\n');

    } catch (error) {
        console.error('❌ Test failed:', error.response?.data || error.message);
    }
}

// Get status from command line or use default
const status = process.argv[2] || 'confirmed';
testNotification(status);
