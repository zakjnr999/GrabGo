const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');

console.log('Loading .env...');
const result = dotenv.config({ path: path.resolve(__dirname, '.env') });
console.log('Dotenv result:', result);

const uri = process.env.MONGODB_URI;
console.log('URI:', uri);

if (!uri) {
    console.error('No MONGODB_URI found');
    process.exit(1);
}

mongoose.connect(uri)
    .then(() => {
        console.log('Connected!');
        process.exit(0);
    })
    .catch(err => {
        console.error('Connection error:', err);
        process.exit(1);
    });
