const mongoose = require('mongoose');

const connectMongoDB = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');

        console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
        
        try {
            const RiderStatus = require('../models/RiderStatus');
            await RiderStatus.createIndexes();
            console.log('✅ RiderStatus indexes ensured');
        } catch (indexError) {
            console.log('⚠️ RiderStatus index creation:', indexError.message);
        }
    } catch (error) {
        console.error(`❌ MongoDB Connection Error: ${error.message}`);
    }
};

module.exports = connectMongoDB;
