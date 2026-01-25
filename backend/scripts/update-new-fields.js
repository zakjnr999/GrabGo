/**
 * Update existing records with newly added fields
 */
require('dotenv').config();
const mongoose = require('mongoose');
const prisma = require('../config/prisma');

async function updatePharmacyItems() {
    console.log('📦 Updating Pharmacy Items with unit and expiryDate...\n');

    const mongoItems = await mongoose.connection.db.collection('pharmacyitems').find({}).toArray();
    const prismaItems = await prisma.pharmacyItem.findMany({
        select: { id: true, name: true }
    });

    let updated = 0;
    let skipped = 0;

    for (const mongoItem of mongoItems) {
        const prismaItem = prismaItems.find(p => p.name === mongoItem.name);

        if (!prismaItem) {
            skipped++;
            continue;
        }

        try {
            await prisma.pharmacyItem.update({
                where: { id: prismaItem.id },
                data: {
                    unit: mongoItem.unit || null,
                    expiryDate: mongoItem.expiryDate || null,
                }
            });
            updated++;
            console.log(`  ✅ Updated: ${mongoItem.name} (unit: ${mongoItem.unit || 'N/A'})`);
        } catch (error) {
            console.error(`  ❌ Failed to update ${mongoItem.name}:`, error.message);
        }
    }

    console.log(`\n✅ Pharmacy Items: ${updated} updated, ${skipped} skipped\n`);
    return { updated, skipped };
}

async function updateGrabMartItems() {
    console.log('📦 Updating GrabMart Items with unit, brand, rating, etc...\n');

    const mongoItems = await mongoose.connection.db.collection('grabmartitems').find({}).toArray();
    const prismaItems = await prisma.grabMartItem.findMany({
        select: { id: true, name: true }
    });

    let updated = 0;
    let skipped = 0;

    for (const mongoItem of mongoItems) {
        const prismaItem = prismaItems.find(p => p.name === mongoItem.name);

        if (!prismaItem) {
            skipped++;
            continue;
        }

        try {
            await prisma.grabMartItem.update({
                where: { id: prismaItem.id },
                data: {
                    unit: mongoItem.unit || null,
                    brand: mongoItem.brand || null,
                    rating: mongoItem.rating || 0,
                    reviewCount: mongoItem.reviewCount || 0,
                    orderCount: mongoItem.orderCount || 0,
                    tags: mongoItem.tags || [],
                }
            });
            updated++;
            console.log(`  ✅ Updated: ${mongoItem.name} (unit: ${mongoItem.unit || 'N/A'}, brand: ${mongoItem.brand || 'N/A'})`);
        } catch (error) {
            console.error(`  ❌ Failed to update ${mongoItem.name}:`, error.message);
        }
    }

    console.log(`\n✅ GrabMart Items: ${updated} updated, ${skipped} skipped\n`);
    return { updated, skipped };
}

async function updatePromotionalBanners() {
    console.log('📦 Updating Promotional Banners with subtitle, discount, etc...\n');

    const mongoBanners = await mongoose.connection.db.collection('promotionalbanners').find({}).toArray();
    const prismaBanners = await prisma.promotionalBanner.findMany({
        select: { id: true, title: true }
    });

    let updated = 0;
    let skipped = 0;

    for (const mongoBanner of mongoBanners) {
        const prismaBanner = prismaBanners.find(p => p.title === mongoBanner.title);

        if (!prismaBanner) {
            skipped++;
            continue;
        }

        try {
            await prisma.promotionalBanner.update({
                where: { id: prismaBanner.id },
                data: {
                    subtitle: mongoBanner.subtitle || null,
                    discount: mongoBanner.discount || null,
                    backgroundColor: mongoBanner.backgroundColor || '#FFFFFF',
                    targetAudience: mongoBanner.targetAudience || 'all',
                }
            });
            updated++;
            console.log(`  ✅ Updated: ${mongoBanner.title}`);
        } catch (error) {
            console.error(`  ❌ Failed to update ${mongoBanner.title}:`, error.message);
        }
    }

    console.log(`\n✅ Promotional Banners: ${updated} updated, ${skipped} skipped\n`);
    return { updated, skipped };
}

async function updateCategories() {
    console.log('📦 Updating Categories with description, emoji, sortOrder, isActive...\n');

    const mongoCategories = await mongoose.connection.db.collection('categories').find({}).toArray();
    const prismaCategories = await prisma.category.findMany({
        select: { id: true, name: true }
    });

    let updated = 0;
    let skipped = 0;

    for (const mongoCat of mongoCategories) {
        const prismaCat = prismaCategories.find(p => p.name === mongoCat.name);

        if (!prismaCat) {
            skipped++;
            continue;
        }

        try {
            await prisma.category.update({
                where: { id: prismaCat.id },
                data: {
                    description: mongoCat.description || null,
                    emoji: mongoCat.emoji || null,
                    sortOrder: mongoCat.sortOrder || 0,
                    isActive: mongoCat.isActive !== false,
                }
            });
            updated++;
            console.log(`  ✅ Updated: ${mongoCat.name} (emoji: ${mongoCat.emoji || 'N/A'})`);
        } catch (error) {
            console.error(`  ❌ Failed to update ${mongoCat.name}:`, error.message);
        }
    }

    console.log(`\n✅ Categories: ${updated} updated, ${skipped} skipped\n`);
    return { updated, skipped };
}

async function updateGrabMartCategories() {
    console.log('📦 Updating GrabMart Categories with description, emoji, sortOrder, isActive...\n');

    const mongoCategories = await mongoose.connection.db.collection('grabmartcategories').find({}).toArray();
    const prismaCategories = await prisma.grabMartCategory.findMany({
        select: { id: true, name: true }
    });

    let updated = 0;
    let skipped = 0;

    for (const mongoCat of mongoCategories) {
        const prismaCat = prismaCategories.find(p => p.name === mongoCat.name);

        if (!prismaCat) {
            skipped++;
            continue;
        }

        try {
            await prisma.grabMartCategory.update({
                where: { id: prismaCat.id },
                data: {
                    description: mongoCat.description || null,
                    emoji: mongoCat.emoji || null,
                    sortOrder: mongoCat.sortOrder || 0,
                    isActive: mongoCat.isActive !== false,
                }
            });
            updated++;
            console.log(`  ✅ Updated: ${mongoCat.name} (emoji: ${mongoCat.emoji || 'N/A'})`);
        } catch (error) {
            console.error(`  ❌ Failed to update ${mongoCat.name}:`, error.message);
        }
    }

    console.log(`\n✅ GrabMart Categories: ${updated} updated, ${skipped} skipped\n`);
    return { updated, skipped };
}

async function main() {
    console.log('========================================');
    console.log('🔄 UPDATING EXISTING RECORDS');
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

    // Run updates
    const pharmacyItemsStats = await updatePharmacyItems();
    const grabmartItemsStats = await updateGrabMartItems();
    const bannersStats = await updatePromotionalBanners();
    const categoriesStats = await updateCategories();
    const grabmartCategoriesStats = await updateGrabMartCategories();

    // Print summary
    console.log('========================================');
    console.log('📊 UPDATE SUMMARY');
    console.log('========================================');
    console.log(`✅ Pharmacy Items: ${pharmacyItemsStats.updated} updated`);
    console.log(`✅ GrabMart Items: ${grabmartItemsStats.updated} updated`);
    console.log(`✅ Promotional Banners: ${bannersStats.updated} updated`);
    console.log(`✅ Categories: ${categoriesStats.updated} updated`);
    console.log(`✅ GrabMart Categories: ${grabmartCategoriesStats.updated} updated`);
    console.log('----------------------------------------');
    console.log(`📈 Total updated: ${pharmacyItemsStats.updated +
        grabmartItemsStats.updated +
        bannersStats.updated +
        categoriesStats.updated +
        grabmartCategoriesStats.updated
        }`);

    // Close connections
    await mongoose.connection.close();
    await prisma.$disconnect();
    console.log('\n🔌 Connections closed');
}

main().catch(async (error) => {
    console.error('❌ Update failed:', error);
    await mongoose.connection.close();
    await prisma.$disconnect();
    process.exit(1);
});
