const mongoose = require('mongoose');

const connectMongoDB = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');

        console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
        
        // Ensure indexes are created for RiderStatus
        try {
            const RiderStatus = require('../models/RiderStatus');
            await RiderStatus.createIndexes();
            console.log('✅ RiderStatus indexes ensured');
        } catch (indexError) {
            console.log('⚠️ RiderStatus index creation:', indexError.message);
        }
    } catch (error) {
        console.error(`❌ MongoDB Connection Error: ${error.message}`);
        // We don't exit(1) here because the app can still function partially with Postgres
    }
};

module.exports = connectMongoDB;
