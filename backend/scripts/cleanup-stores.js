const mongoose = require('mongoose');
require('dotenv').config();

const PharmacyStore = require('../models/PharmacyStore');
const GrabMartStore = require('../models/GrabMartStore');

async function cleanupStores() {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');

        const pharmacyResult = await PharmacyStore.deleteMany({});
        console.log(`✅ Deleted ${pharmacyResult.deletedCount} pharmacy stores`);

        const grabmartResult = await GrabMartStore.deleteMany({});
        console.log(`✅ Deleted ${grabmartResult.deletedCount} grabmart stores`);

        console.log('\n🎉 Cleanup completed! Now run the setup scripts to add fresh data.');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

cleanupStores();
