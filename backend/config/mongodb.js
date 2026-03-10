const mongoose = require('mongoose');
const logger = require('../utils/logger');

let mongoReady = false;

const connectMongoDB = async () => {
    const connectionUri = process.env.MONGODB_URI
        || (process.env.NODE_ENV === 'production' ? null : 'mongodb://localhost:27017/grabgo');

    if (!connectionUri) {
        throw new Error('MONGODB_URI is required');
    }

    try {
        const conn = await mongoose.connect(connectionUri);
        mongoReady = true;
        logger.info('mongodb_connected', { host: conn.connection.host });

        try {
            const RiderStatus = require('../models/RiderStatus');
            await RiderStatus.createIndexes();
            logger.info('mongodb_rider_status_indexes_ensured');
        } catch (indexError) {
            logger.warn('mongodb_rider_status_index_creation_warning', { message: indexError.message });
        }

        return conn;
    } catch (error) {
        mongoReady = false;
        throw error;
    }
};

const isMongoReady = () => mongoReady && mongoose.connection.readyState === 1;

const closeMongoDB = async () => {
    if (mongoose.connection.readyState !== 0) {
        await mongoose.disconnect();
    }
    mongoReady = false;
};

connectMongoDB.isReady = isMongoReady;
connectMongoDB.close = closeMongoDB;

module.exports = connectMongoDB;
