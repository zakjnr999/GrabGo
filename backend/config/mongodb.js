const mongoose = require('mongoose');

const connectMongoDB = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');

        console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
    } catch (error) {
        console.error(`❌ MongoDB Connection Error: ${error.message}`);
        // We don't exit(1) here because the app can still function partially with Postgres
    }
};

module.exports = connectMongoDB;
