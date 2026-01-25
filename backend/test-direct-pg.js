const { Client } = require('pg');
require('dotenv').config();

async function debugConnection() {
    const fullUrl = process.env.DATABASE_URL;
    const baseUrl = fullUrl.split('?')[0];

    console.log('--- Supabase Pooler Debug ---');
    console.log('Base URL (port 6543):', baseUrl.replace(/:[^:]+@/, ':****@'));

    const tests = [
        {
            name: '1. Manual SSL Object (rejectUnauthorized: false) + Base URL',
            config: { connectionString: baseUrl, ssl: { rejectUnauthorized: false } }
        },
        {
            name: '2. Force Bypass via Global Env (NODE_TLS_REJECT_UNAUTHORIZED=0)',
            config: { connectionString: fullUrl },
            setup: () => { process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'; }
        },
        {
            name: '3. Standard SSL Mode Require (URL only)',
            config: { connectionString: fullUrl }
        }
    ];

    for (const test of tests) {
        console.log(`\nTesting: ${test.name}`);
        if (test.setup) test.setup();

        const client = new Client(test.config);

        try {
            await client.connect();
            console.log('✅ Success!');
            const res = await client.query('SELECT 1 as test');
            console.log('Query Result:', res.rows[0]);
            await client.end();
            // If any of these work, we can apply the logic to prisma.js
        } catch (err) {
            console.error('❌ Failed:', err.message);
        }
    }
}

debugConnection();
