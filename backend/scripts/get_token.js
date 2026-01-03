const axios = require('axios');

async function getToken() {
    try {
        const response = await axios.post('http://localhost:5000/api/users/login', {
            email: 'zakjnr5@gmail.com',
            password: 'Daddy@20033'
        });

        console.log('\n✅ Login successful!\n');
        console.log('📋 Your auth token:');
        console.log('─'.repeat(80));
        console.log(response.data.token);
        console.log('─'.repeat(80));
        console.log('\n💡 Copy the token above and use it in your test commands!\n');

        // Also save to file for easy access
        const fs = require('fs');
        fs.writeFileSync('auth_token.txt', response.data.token);
        console.log('✅ Token also saved to: auth_token.txt\n');

    } catch (error) {
        console.error('❌ Login failed:', error.response?.data || error.message);
    }
}

getToken();
