/**
 * Migration script for orphaned Pharmacy and GrabMart items
 * Assigns orphaned items to existing stores
 */
require('dotenv').config();
const mongoose = require('mongoose');

// Import Prisma client
const prisma = require('../config/prisma');

// Helper to convert MongoDB ObjectId to string
const toStr = (id) => id?.toString() || null;

async function migrateOrphanedPharmacyItems() {
    console.log('📦 Migrating Orphaned Pharmacy Items...\n');

    // Get all pharmacy items from MongoDB
    const items = await mongoose.connection.db.collection('pharmacyitems').find({}).toArray();
    console.log(`Found ${items.length} pharmacy items in MongoDB`);

    // Get all pharmacy stores from PostgreSQL
    const pharmacyStores = await prisma.pharmacyStore.findMany({
        select: { id: true, storeName: true }
    });
    console.log(`Found ${pharmacyStores.length} pharmacy stores in PostgreSQL\n`);

    if (pharmacyStores.length === 0) {
        console.log('⚠️ No pharmacy stores found in PostgreSQL. Skipping...');
        return { migrated: 0, failed: 0, skipped: 0 };
    }

    // Get all pharmacy categories from PostgreSQL
    const categories = await prisma.pharmacyCategory.findMany({
        select: { id: true, name: true }
    });
    const categoryMap = new Map(categories.map(c => [c.name.toLowerCase(), c.id]));

    let migrated = 0;
    let failed = 0;
    let skipped = 0;
    let storeIndex = 0;

    for (const item of items) {
        try {
            // Check if already exists
            const existing = await prisma.pharmacyItem.findFirst({
                where: { name: item.name }
            });

            if (existing) {
                skipped++;
                continue;
            }

            // Assign to a store in round-robin fashion
            const assignedStore = pharmacyStores[storeIndex % pharmacyStores.length];
            storeIndex++;

            // Try to match category by name
            let categoryId = null;
            if (item.category) {
                const mongoCategory = await mongoose.connection.db.collection('pharmacycategories')
                    .findOne({ _id: item.category });
                if (mongoCategory) {
                    categoryId = categoryMap.get(mongoCategory.name.toLowerCase()) || null;
                }
            }

            await prisma.pharmacyItem.create({
                data: {
                    storeId: assignedStore.id,
                    categoryId: categoryId,
                    name: item.name,
                    description: item.description || null,
                    image: item.image || '',
                    price: item.price || 0,
                    brand: item.brand || null,
                    stock: item.stock || 0,
                    isAvailable: item.isAvailable !== false,
                    requiresPrescription: item.requiresPrescription || false,
                    discountPercentage: item.discountPercentage || 0,
                    discountEndDate: item.discountEndDate || null,
                    rating: item.rating || 0,
                    reviewCount: item.reviewCount || 0,
                    orderCount: item.orderCount || 0,
                    createdAt: item.createdAt || new Date(),
                    updatedAt: item.updatedAt || new Date(),
                },
            });

            migrated++;
            console.log(`  ✅ ${item.name} → ${assignedStore.storeName}`);
        } catch (error) {
            console.error(`  ❌ Failed to migrate ${item.name}:`, error.message);
            failed++;
        }
    }

    return { migrated, failed, skipped };
}

async function migrateOrphanedGrabMartItems() {
    console.log('\n📦 Migrating Orphaned GrabMart Items...\n');

    // Get all grabmart items from MongoDB
    const items = await mongoose.connection.db.collection('grabmartitems').find({}).toArray();
    console.log(`Found ${items.length} grabmart items in MongoDB`);

    // Get all grabmart stores from PostgreSQL
    const grabmartStores = await prisma.grabMartStore.findMany({
        select: { id: true, storeName: true }
    });
    console.log(`Found ${grabmartStores.length} grabmart stores in PostgreSQL\n`);

    if (grabmartStores.length === 0) {
        console.log('⚠️ No grabmart stores found in PostgreSQL. Skipping...');
        return { migrated: 0, failed: 0, skipped: 0 };
    }

    // Get all grabmart categories from PostgreSQL
    const categories = await prisma.grabMartCategory.findMany({
        select: { id: true, name: true }
    });
    const categoryMap = new Map(categories.map(c => [c.name.toLowerCase(), c.id]));

    let migrated = 0;
    let failed = 0;
    let skipped = 0;
    let storeIndex = 0;

    for (const item of items) {
        try {
            // Check if already exists
            const existing = await prisma.grabMartItem.findFirst({
                where: { name: item.name }
            });

            if (existing) {
                skipped++;
                continue;
            }

            // Assign to a store in round-robin fashion
            const assignedStore = grabmartStores[storeIndex % grabmartStores.length];
            storeIndex++;

            // Try to match category by name
            let categoryId = null;
            if (item.category) {
                const mongoCategory = await mongoose.connection.db.collection('grabmartcategories')
                    .findOne({ _id: item.category });
                if (mongoCategory) {
                    categoryId = categoryMap.get(mongoCategory.name.toLowerCase()) || null;
                }
            }

            await prisma.grabMartItem.create({
                data: {
                    storeId: assignedStore.id,
                    categoryId: categoryId,
                    name: item.name,
                    description: item.description || null,
                    image: item.image || '',
                    price: item.price || 0,
                    stock: item.stock || 0,
                    isAvailable: item.isAvailable !== false,
                    discountPercentage: item.discountPercentage || 0,
                    discountEndDate: item.discountEndDate || null,
                    createdAt: item.createdAt || new Date(),
                    updatedAt: item.updatedAt || new Date(),
                },
            });

            migrated++;
            console.log(`  ✅ ${item.name} → ${assignedStore.storeName}`);
        } catch (error) {
            console.error(`  ❌ Failed to migrate ${item.name}:`, error.message);
            failed++;
        }
    }

    return { migrated, failed, skipped };
}

async function main() {
    console.log('========================================');
    console.log('🔄 ORPHANED ITEMS MIGRATION');
    console.log('========================================\n');

    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
        throw new Error('MONGODB_URI not found in environment');
    }

    console.log('📡 Connecting to MongoDB...');
    await mongoose.connect(mongoUri);
    console.log('✅ MongoDB connected');
    console.log('✅ PostgreSQL Connected via Prisma\n');

    // Run migrations
    const pharmacyStats = await migrateOrphanedPharmacyItems();
    const grabmartStats = await migrateOrphanedGrabMartItems();

    // Print summary
    console.log('\n========================================');
    console.log('📊 MIGRATION SUMMARY');
    console.log('========================================');
    console.log(`✅ Pharmacy Items: ${pharmacyStats.migrated} created, ${pharmacyStats.skipped} skipped, ${pharmacyStats.failed} failed`);
    console.log(`✅ GrabMart Items: ${grabmartStats.migrated} created, ${grabmartStats.skipped} skipped, ${grabmartStats.failed} failed`);
    console.log('----------------------------------------');
    console.log(`📈 Total created: ${pharmacyStats.migrated + grabmartStats.migrated}`);
    console.log(`⏭️  Total skipped: ${pharmacyStats.skipped + grabmartStats.skipped}`);
    console.log(`⚠️  Total failed: ${pharmacyStats.failed + grabmartStats.failed}`);

    // Close connections
    await mongoose.connection.close();
    await prisma.$disconnect();
    console.log('\n🔌 Connections closed');
}

main().catch(async (error) => {
    console.error('❌ Migration failed:', error);
    await mongoose.connection.close();
    await prisma.$disconnect();
    process.exit(1);
});
