const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const Restaurant = require('../models/Restaurant');
const GroceryStore = require('../models/GroceryStore');
const PharmacyStore = require('../models/PharmacyStore');
const GrabMartStore = require('../models/GrabMartStore');

async function approveAllVendors() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Update all restaurants
        const restaurantsResult = await Restaurant.updateMany(
            {},
            { $set: { status: 'approved', isOpen: true, isAcceptingOrders: true } }
        );
        console.log(`✅ Updated ${restaurantsResult.modifiedCount} restaurants to approved and open status`);

        // Update all grocery stores
        const groceryResult = await GroceryStore.updateMany(
            {},
            { $set: { status: 'approved', isOpen: true, isAcceptingOrders: true } }
        );
        console.log(`✅ Updated ${groceryResult.modifiedCount} grocery stores to approved and open status`);

        // Update all pharmacies
        const pharmacyResult = await PharmacyStore.updateMany(
            {},
            { $set: { status: 'approved', isOpen: true, isAcceptingOrders: true } }
        );
        console.log(`✅ Updated ${pharmacyResult.modifiedCount} pharmacies to approved and open status`);

        // Update all GrabMarts
        const grabmartResult = await GrabMartStore.updateMany(
            {},
            { $set: { status: 'approved', isOpen: true, isAcceptingOrders: true } }
        );
        console.log(`✅ Updated ${grabmartResult.modifiedCount} GrabMarts to approved and open status`);

        console.log('\n✅ All vendors approved successfully!');

        process.exit(0);
    } catch (error) {
        console.error('❌ Error approving vendors:', error);
        process.exit(1);
    }
}

approveAllVendors();
