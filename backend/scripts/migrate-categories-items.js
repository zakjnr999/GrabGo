/**
 * Migration script for Pharmacy Categories/Items and GrabMart Categories/Items
 */
require('dotenv').config();
const mongoose = require('mongoose');

// Import MongoDB models
const PharmacyCategory = require('../models/PharmacyCategory');
const PharmacyItem = require('../models/PharmacyItem');
const GrabMartCategory = require('../models/GrabMartCategory');
const GrabMartItem = require('../models/GrabMartItem');

// Import Prisma client
const prisma = require('../config/prisma');

// Helper to convert MongoDB ObjectId to string
const toStr = (id) => id?.toString() || null;

// Stats tracking
const stats = {};

// ID mapping for foreign keys
const idMap = {
  pharmacyStores: new Map(),
  pharmacyCategories: new Map(),
  grabmartStores: new Map(),
  grabmartCategories: new Map(),
};

// Get mapped ID helper
function getMappedId(collection, mongoId) {
  if (!mongoId) return null;
  return idMap[collection]?.get(toStr(mongoId)) || null;
}

async function loadExistingMappings() {
  console.log('📂 Loading existing store mappings...');
  
  // Load pharmacy stores
  const pharmacyStores = await prisma.pharmacyStore.findMany({
    select: { id: true, storeName: true }
  });
  const mongoPharmacyStores = await mongoose.connection.db.collection('pharmacystores').find({}).toArray();
  for (const mongoStore of mongoPharmacyStores) {
    const match = pharmacyStores.find(ps => ps.storeName === mongoStore.storeName);
    if (match) {
      idMap.pharmacyStores.set(toStr(mongoStore._id), match.id);
    }
  }
  console.log(`  ✅ Loaded ${idMap.pharmacyStores.size} pharmacy store mappings`);

  // Load grabmart stores
  const grabmartStores = await prisma.grabMartStore.findMany({
    select: { id: true, storeName: true }
  });
  const mongoGrabmartStores = await mongoose.connection.db.collection('grabmartstores').find({}).toArray();
  for (const mongoStore of mongoGrabmartStores) {
    const match = grabmartStores.find(gs => gs.storeName === mongoStore.storeName);
    if (match) {
      idMap.grabmartStores.set(toStr(mongoStore._id), match.id);
    }
  }
  console.log(`  ✅ Loaded ${idMap.grabmartStores.size} grabmart store mappings`);
}

async function migratePharmacyCategories() {
  console.log('📦 Migrating Pharmacy Categories...');
  const categories = await PharmacyCategory.find({}).lean();
  stats.pharmacyCategories = { total: categories.length, migrated: 0, failed: 0, skipped: 0 };

  for (const cat of categories) {
    try {
      const storeId = getMappedId('pharmacyStores', cat.store);
      
      // Check if already exists
      const existing = await prisma.pharmacyCategory.findFirst({
        where: { name: cat.name, storeId: storeId || undefined }
      });
      
      if (existing) {
        idMap.pharmacyCategories.set(toStr(cat._id), existing.id);
        stats.pharmacyCategories.skipped++;
        continue;
      }

      const newCat = await prisma.pharmacyCategory.create({
        data: {
          name: cat.name,
          description: cat.description || null,
          image: cat.image || null,
          sortOrder: cat.sortOrder || 0,
          isActive: cat.isActive !== false,
          storeId: storeId || null,
          createdAt: cat.createdAt || new Date(),
          updatedAt: cat.updatedAt || new Date(),
        },
      });
      idMap.pharmacyCategories.set(toStr(cat._id), newCat.id);
      stats.pharmacyCategories.migrated++;
      console.log(`  ✅ Created category: ${cat.name}`);
    } catch (error) {
      console.error(`  ❌ PharmacyCategory failed (${cat.name}):`, error.message);
      stats.pharmacyCategories.failed++;
    }
  }
  console.log(`  ✅ Pharmacy Categories: ${stats.pharmacyCategories.migrated} created, ${stats.pharmacyCategories.skipped} skipped, ${stats.pharmacyCategories.failed} failed`);
}

async function migratePharmacyItems() {
  console.log('📦 Migrating Pharmacy Items...');
  const items = await PharmacyItem.find({}).lean();
  stats.pharmacyItems = { total: items.length, migrated: 0, failed: 0, skipped: 0 };

  for (const item of items) {
    try {
      const storeId = getMappedId('pharmacyStores', item.store);
      const categoryId = getMappedId('pharmacyCategories', item.category);
      
      if (!storeId) {
        console.error(`  ⚠️ PharmacyItem skipped - no store mapping for: ${item.name}`);
        stats.pharmacyItems.failed++;
        continue;
      }

      // Check if already exists
      const existing = await prisma.pharmacyItem.findFirst({
        where: { name: item.name, storeId: storeId }
      });
      
      if (existing) {
        stats.pharmacyItems.skipped++;
        continue;
      }

      const newItem = await prisma.pharmacyItem.create({
        data: {
          storeId,
          categoryId: categoryId || null,
          name: item.name,
          description: item.description || null,
          image: item.image || '',
          price: item.price || 0,
          stock: item.stock || 0,
          isAvailable: item.isAvailable !== false,
          requiresPrescription: item.requiresPrescription || false,
          dosage: item.dosage || null,
          manufacturer: item.manufacturer || null,
          discountPercentage: item.discountPercentage || 0,
          discountEndDate: item.discountEndDate || null,
          createdAt: item.createdAt || new Date(),
          updatedAt: item.updatedAt || new Date(),
        },
      });
      stats.pharmacyItems.migrated++;
    } catch (error) {
      console.error(`  ❌ PharmacyItem failed (${item.name}):`, error.message);
      stats.pharmacyItems.failed++;
    }
  }
  console.log(`  ✅ Pharmacy Items: ${stats.pharmacyItems.migrated} created, ${stats.pharmacyItems.skipped} skipped, ${stats.pharmacyItems.failed} failed`);
}

async function migrateGrabMartCategories() {
  console.log('📦 Migrating GrabMart Categories...');
  const categories = await GrabMartCategory.find({}).lean();
  stats.grabmartCategories = { total: categories.length, migrated: 0, failed: 0, skipped: 0 };

  for (const cat of categories) {
    try {
      const storeId = getMappedId('grabmartStores', cat.store);
      
      // Check if already exists
      const existing = await prisma.grabMartCategory.findFirst({
        where: { name: cat.name, storeId: storeId || undefined }
      });
      
      if (existing) {
        idMap.grabmartCategories.set(toStr(cat._id), existing.id);
        stats.grabmartCategories.skipped++;
        continue;
      }

      const newCat = await prisma.grabMartCategory.create({
        data: {
          name: cat.name,
          image: cat.image || null,
          storeId: storeId || null,
          createdAt: cat.createdAt || new Date(),
          updatedAt: cat.updatedAt || new Date(),
        },
      });
      idMap.grabmartCategories.set(toStr(cat._id), newCat.id);
      stats.grabmartCategories.migrated++;
      console.log(`  ✅ Created category: ${cat.name}`);
    } catch (error) {
      console.error(`  ❌ GrabMartCategory failed (${cat.name}):`, error.message);
      stats.grabmartCategories.failed++;
    }
  }
  console.log(`  ✅ GrabMart Categories: ${stats.grabmartCategories.migrated} created, ${stats.grabmartCategories.skipped} skipped, ${stats.grabmartCategories.failed} failed`);
}

async function migrateGrabMartItems() {
  console.log('📦 Migrating GrabMart Items...');
  const items = await GrabMartItem.find({}).lean();
  stats.grabmartItems = { total: items.length, migrated: 0, failed: 0, skipped: 0 };

  for (const item of items) {
    try {
      const storeId = getMappedId('grabmartStores', item.store);
      const categoryId = getMappedId('grabmartCategories', item.category);
      
      if (!storeId) {
        console.error(`  ⚠️ GrabMartItem skipped - no store mapping for: ${item.name}`);
        stats.grabmartItems.failed++;
        continue;
      }

      // Check if already exists
      const existing = await prisma.grabMartItem.findFirst({
        where: { name: item.name, storeId: storeId }
      });
      
      if (existing) {
        stats.grabmartItems.skipped++;
        continue;
      }

      const newItem = await prisma.grabMartItem.create({
        data: {
          storeId,
          categoryId: categoryId || null,
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
      stats.grabmartItems.migrated++;
    } catch (error) {
      console.error(`  ❌ GrabMartItem failed (${item.name}):`, error.message);
      stats.grabmartItems.failed++;
    }
  }
  console.log(`  ✅ GrabMart Items: ${stats.grabmartItems.migrated} created, ${stats.grabmartItems.skipped} skipped, ${stats.grabmartItems.failed} failed`);
}

async function main() {
  console.log('========================================');
  console.log('🔄 CATEGORIES & ITEMS MIGRATION');
  console.log('========================================\n');

  // Connect to MongoDB
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('MONGODB_URI not found in environment');
  }
  
  console.log('📡 Connecting to MongoDB...');
  await mongoose.connect(mongoUri);
  console.log('✅ MongoDB connected\n');

  // Load existing mappings
  await loadExistingMappings();

  // Run migrations
  await migratePharmacyCategories();
  await migratePharmacyItems();
  await migrateGrabMartCategories();
  await migrateGrabMartItems();

  // Print summary
  console.log('\n========================================');
  console.log('📊 MIGRATION SUMMARY');
  console.log('========================================');
  
  let totalMigrated = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  
  for (const [name, stat] of Object.entries(stats)) {
    const status = stat.failed > 0 ? '⚠️' : '✅';
    console.log(`${status} ${name}: ${stat.migrated} created, ${stat.skipped || 0} skipped, ${stat.failed} failed (${stat.total} total)`);
    totalMigrated += stat.migrated;
    totalFailed += stat.failed;
    totalSkipped += stat.skipped || 0;
  }
  
  console.log('----------------------------------------');
  console.log(`📈 Total created: ${totalMigrated}`);
  console.log(`⏭️  Total skipped: ${totalSkipped}`);
  console.log(`⚠️  Total failed: ${totalFailed}`);

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
