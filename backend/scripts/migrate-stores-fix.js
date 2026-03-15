/**
 * Migration script to fix Pharmacy Stores, GrabMart Stores, Grocery Categories and Grocery Items
 */
require('dotenv').config();
const mongoose = require('mongoose');

// Import MongoDB models
const PharmacyStore = require('../models/PharmacyStore');
const GrabMartStore = require('../models/GrabMartStore');
const GroceryCategory = require('../models/GroceryCategory');
const GroceryItem = require('../models/GroceryItem');

// Import Prisma client
const prisma = require('../config/prisma');

// Helper to convert MongoDB ObjectId to string
const toStr = (id) => id?.toString() || null;

// Stats tracking
const stats = {};

// ID mapping for foreign keys
const idMap = {
  groceryStores: new Map(),
  groceryCategories: new Map(),
  groceryItems: new Map(),
  pharmacyStores: new Map(),
  grabmartStores: new Map(),
};

// Get mapped ID helper
function getMappedId(collection, mongoId) {
  if (!mongoId) return null;
  return idMap[collection]?.get(toStr(mongoId)) || null;
}

async function loadExistingMappings() {
  console.log('📂 Loading existing grocery store mappings from Phase 1...');
  
  // Load grocery stores that were already migrated
  const groceryStores = await prisma.groceryStore.findMany({
    select: { id: true, storeName: true }
  });
  
  // We need to match by name since we don't have MongoDB IDs stored
  const mongoGroceryStores = await mongoose.connection.db.collection('grocerystores').find({}).toArray();
  
  for (const mongoStore of mongoGroceryStores) {
    const matchingPrismaStore = groceryStores.find(ps => ps.storeName === mongoStore.storeName);
    if (matchingPrismaStore) {
      idMap.groceryStores.set(toStr(mongoStore._id), matchingPrismaStore.id);
    }
  }
  
  console.log(`  ✅ Loaded ${idMap.groceryStores.size} grocery store mappings`);
}

async function migrateGroceryCategories() {
  console.log('📦 Migrating Grocery Categories...');
  const categories = await GroceryCategory.find({}).lean();
  stats.groceryCategories = { total: categories.length, migrated: 0, failed: 0, skipped: 0 };

  for (const cat of categories) {
    try {
      // Check if already exists
      const existing = await prisma.groceryCategory.findFirst({
        where: { name: cat.name }
      });
      
      if (existing) {
        idMap.groceryCategories.set(toStr(cat._id), existing.id);
        stats.groceryCategories.skipped++;
        continue;
      }

      // GroceryCategory in MongoDB is global (no store reference)
      const newCat = await prisma.groceryCategory.create({
        data: {
          name: cat.name,
          emoji: cat.emoji || null,
          description: cat.description || null,
          image: cat.image || null,
          sortOrder: cat.sortOrder || 0,
          isActive: cat.isActive !== false,
          storeId: null, // Global category
          createdAt: cat.createdAt || new Date(),
          updatedAt: cat.updatedAt || new Date(),
        },
      });
      idMap.groceryCategories.set(toStr(cat._id), newCat.id);
      stats.groceryCategories.migrated++;
      console.log(`  ✅ Created category: ${cat.name}`);
    } catch (error) {
      console.error(`  ❌ GroceryCategory failed (${cat.name}):`, error.message);
      stats.groceryCategories.failed++;
    }
  }
  console.log(`  ✅ Grocery Categories: ${stats.groceryCategories.migrated} created, ${stats.groceryCategories.skipped} skipped, ${stats.groceryCategories.failed} failed`);
}

async function migrateGroceryItems() {
  console.log('📦 Migrating Grocery Items...');
  const items = await GroceryItem.find({}).lean();
  stats.groceryItems = { total: items.length, migrated: 0, failed: 0, skipped: 0 };

  for (const item of items) {
    try {
      const storeId = getMappedId('groceryStores', item.store);
      const categoryId = getMappedId('groceryCategories', item.category);
      
      if (!storeId) {
        console.error(`  ⚠️ GroceryItem skipped - no store mapping for: ${item.name}`);
        stats.groceryItems.failed++;
        continue;
      }

      // Check if already exists
      const existing = await prisma.groceryItem.findFirst({
        where: { name: item.name, storeId: storeId }
      });
      
      if (existing) {
        idMap.groceryItems.set(toStr(item._id), existing.id);
        stats.groceryItems.skipped++;
        continue;
      }

      // Map unit to enum
      const unitMap = {
        'kg': 'kg',
        'lbs': 'lbs', 
        'piece': 'piece',
        'pack': 'pack',
        'dozen': 'dozen',
        'liter': 'liter',
        'ml': 'ml',
        'gram': 'gram'
      };
      const unit = unitMap[item.unit] || 'piece';

      const newItem = await prisma.groceryItem.create({
        data: {
          storeId,
          categoryId: categoryId || null,
          name: item.name,
          description: item.description || null,
          thumbnailImage: item.thumbnailImage || item.image || '',
          price: item.price || 0,
          unit: unit,
          brand: item.brand || null,
          stock: item.stock || 0,
          isAvailable: item.isAvailable !== false,
          discountPercentage: item.discountPercentage || 0,
          discountEndDate: item.discountEndDate || null,
          tags: item.tags || [],
          rating: item.rating || 0,
          reviewCount: item.reviewCount || 0,
          orderCount: item.orderCount || 0,
          calories: item.nutritionInfo?.calories || 0,
          protein: item.nutritionInfo?.protein || 0,
          carbs: item.nutritionInfo?.carbs || 0,
          fat: item.nutritionInfo?.fat || 0,
          createdAt: item.createdAt || new Date(),
          updatedAt: item.updatedAt || new Date(),
        },
      });
      idMap.groceryItems.set(toStr(item._id), newItem.id);
      stats.groceryItems.migrated++;
    } catch (error) {
      console.error(`  ❌ GroceryItem failed (${item.name}):`, error.message);
      stats.groceryItems.failed++;
    }
  }
  console.log(`  ✅ Grocery Items: ${stats.groceryItems.migrated} created, ${stats.groceryItems.skipped} skipped, ${stats.groceryItems.failed} failed`);
}

async function migratePharmacyStores() {
  console.log('📦 Migrating Pharmacy Stores...');
  const stores = await PharmacyStore.find({}).lean();
  stats.pharmacyStores = { total: stores.length, migrated: 0, failed: 0, skipped: 0 };

  for (const store of stores) {
    try {
      // Check if already exists
      const existing = await prisma.pharmacyStore.findFirst({
        where: { email: store.email }
      });
      
      if (existing) {
        idMap.pharmacyStores.set(toStr(store._id), existing.id);
        stats.pharmacyStores.skipped++;
        continue;
      }

      const coords = store.location?.coordinates || [0, 0];
      
      const newStore = await prisma.pharmacyStore.create({
        data: {
          storeName: store.storeName,
          logo: store.logo,
          description: store.description || null,
          phone: store.phone,
          email: store.email,
          password: store.password || '',
          status: store.status || 'pending',
          rating: store.rating || 0,
          ratingCount: store.ratingCount || 0,
          isOpen: store.isOpen !== false,
          deliveryFee: store.deliveryFee || 0,
          minOrder: store.minOrder || 0,
          longitude: coords[0],
          latitude: coords[1],
          address: store.location?.address || '',
          city: store.location?.city || '',
          area: store.location?.area || '',
          licenseNumber: store.licenseNumber || null,
          pharmacistName: store.pharmacistName || null,
          createdAt: store.createdAt || new Date(),
          updatedAt: store.updatedAt || new Date(),
        },
      });
      idMap.pharmacyStores.set(toStr(store._id), newStore.id);
      stats.pharmacyStores.migrated++;
      console.log(`  ✅ Created pharmacy: ${store.storeName}`);
    } catch (error) {
      console.error(`  ❌ PharmacyStore failed (${store.storeName}):`, error.message);
      stats.pharmacyStores.failed++;
    }
  }
  console.log(`  ✅ Pharmacy Stores: ${stats.pharmacyStores.migrated} created, ${stats.pharmacyStores.skipped} skipped, ${stats.pharmacyStores.failed} failed`);
}

async function migrateGrabMartStores() {
  console.log('📦 Migrating GrabMart Stores...');
  const stores = await GrabMartStore.find({}).lean();
  stats.grabmartStores = { total: stores.length, migrated: 0, failed: 0, skipped: 0 };

  for (const store of stores) {
    try {
      // Check if already exists
      const existing = await prisma.grabMartStore.findFirst({
        where: { email: store.email }
      });
      
      if (existing) {
        idMap.grabmartStores.set(toStr(store._id), existing.id);
        stats.grabmartStores.skipped++;
        continue;
      }

      const coords = store.location?.coordinates || [0, 0];
      
      const newStore = await prisma.grabMartStore.create({
        data: {
          storeName: store.storeName,
          logo: store.logo,
          description: store.description || null,
          phone: store.phone,
          email: store.email,
          password: store.password || null,
          status: store.status || 'pending',
          rating: store.rating || 0,
          ratingCount: store.ratingCount || 0,
          isOpen: store.isOpen !== false,
          deliveryFee: store.deliveryFee || 0,
          minOrder: store.minOrder || 0,
          longitude: coords[0],
          latitude: coords[1],
          address: store.location?.address || '',
          city: store.location?.city || '',
          area: store.location?.area || '',
          createdAt: store.createdAt || new Date(),
          updatedAt: store.updatedAt || new Date(),
        },
      });
      idMap.grabmartStores.set(toStr(store._id), newStore.id);
      stats.grabmartStores.migrated++;
      console.log(`  ✅ Created GrabMart: ${store.storeName}`);
    } catch (error) {
      console.error(`  ❌ GrabMartStore failed (${store.storeName}):`, error.message);
      stats.grabmartStores.failed++;
    }
  }
  console.log(`  ✅ GrabMart Stores: ${stats.grabmartStores.migrated} created, ${stats.grabmartStores.skipped} skipped, ${stats.grabmartStores.failed} failed`);
}

async function main() {
  console.log('========================================');
  console.log('🔄 STORE FIX MIGRATION');
  console.log('========================================\n');

  // Connect to MongoDB
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('MONGODB_URI not found in environment');
  }
  
  console.log('📡 Connecting to MongoDB...');
  await mongoose.connect(mongoUri);
  console.log('✅ MongoDB connected\n');

  // Load existing mappings from Phase 1
  await loadExistingMappings();

  // Run migrations
  await migrateGroceryCategories();
  await migrateGroceryItems();
  await migratePharmacyStores();
  await migrateGrabMartStores();

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
