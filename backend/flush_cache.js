const path = require('path');
const dotenv = require('dotenv');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const cache = require('./utils/cache');

async function flush() {
    console.log('Attempting to flush cache...');
    const result = await cache.flushAll();
    console.log('Flush result:', result);
    process.exit(0);
}

flush();
