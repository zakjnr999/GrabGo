const path = require('path');
const dotenv = require('dotenv');

// Load env vars
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const mongoose = require('mongoose');
const PharmacyCategory = require('../models/PharmacyCategory');
const GrabMartCategory = require('../models/GrabMartCategory');

const pharmacyCategories = [
    { name: 'Medicines', emoji: '💊', description: 'Over-the-counter and prescription medicines', sortOrder: 1 },
    { name: 'Wellness', emoji: '🧘', description: 'Vitamins, supplements, and wellness products', sortOrder: 2 },
    { name: 'Personal Care', emoji: '🧴', description: 'Skincare, haircare, and personal hygiene', sortOrder: 3 },
    { name: 'First Aid', emoji: '🩹', description: 'Bandages, antiseptics, and emergency kits', sortOrder: 4 },
    { name: 'Baby Care', emoji: '👶', description: 'Diapers, baby food, and infant care', sortOrder: 5 },
    { name: 'Health Devices', emoji: '🌡️', description: 'Thermometers, BP monitors, and health tech', sortOrder: 6 },
];

const grabMartCategories = [
    { name: 'Snacks', emoji: '🍿', description: 'Chips, nuts, and quick bites', sortOrder: 1 },
    { name: 'Beverages', emoji: '🥤', description: 'Sodas, juices, and energy drinks', sortOrder: 2 },
    { name: 'Electronics', emoji: '🔌', description: 'Cables, chargers, and small gadgets', sortOrder: 3 },
    { name: 'Personal Care', emoji: '🪥', description: 'Toothbrushes, soaps, and toiletries', sortOrder: 4 },
    { name: 'Household', emoji: '🧻', description: 'Cleaning supplies and home essentials', sortOrder: 5 },
    { name: 'Stationery', emoji: '📓', description: 'Pens, notebooks, and office supplies', sortOrder: 6 },
    { name: 'Ice Cream & Desserts', emoji: '🍦', description: 'Frozen treats and sweets', sortOrder: 7 },
];

async function seedCategories() {
    try {
        const mongoUri = process.env.MONGODB_URI || "mongodb://localhost:27017/grabgo";
        await mongoose.connect(mongoUri);
        console.log('✅ Connected to MongoDB');

        // Seed Pharmacy Categories
        await PharmacyCategory.deleteMany({});
        const insertedPharmacy = await PharmacyCategory.insertMany(pharmacyCategories);
        console.log(`✅ Seeded ${insertedPharmacy.length} Pharmacy categories`);

        // Seed GrabMart Categories
        await GrabMartCategory.deleteMany({});
        const insertedGrabMart = await GrabMartCategory.insertMany(grabMartCategories);
        console.log(`✅ Seeded ${insertedGrabMart.length} GrabMart categories`);

        console.log('\n🎉 Pharmacy and GrabMart categories seeded successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error seeding categories:', error);
        process.exit(1);
    }
}

seedCategories();
