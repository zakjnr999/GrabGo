/**
 * MongoDB to PostgreSQL Migration Script - Phase 2
 * 
 * Migrates remaining collections not covered in Phase 1
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

// Prisma 7 requires adapter
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// Import MongoDB models
const Comment = require('../models/Comment');
const Reaction = require('../models/Reaction');
const Status = require('../models/Status');
const Notification = require('../models/Notification');
const Payment = require('../models/Payment');
const Rider = require('../models/Rider');
const RiderWallet = require('../models/RiderWallet');
const PromoCode = require('../models/PromoCode');
const PromotionalBanner = require('../models/PromotionalBanner');
const Referral = require('../models/Referral');
const ReferralCode = require('../models/ReferralCode');
const UserCredit = require('../models/UserCredit');
const OrderTracking = require('../models/OrderTracking');
const ScheduledNotification = require('../models/ScheduledNotification');
const GroceryCategory = require('../models/GroceryCategory');
const GroceryItem = require('../models/GroceryItem');
const PharmacyStore = require('../models/PharmacyStore');
const PharmacyCategory = require('../models/PharmacyCategory');
const PharmacyItem = require('../models/PharmacyItem');
const GrabMartStore = require('../models/GrabMartStore');
const GrabMartCategory = require('../models/GrabMartCategory');
const GrabMartItem = require('../models/GrabMartItem');
const Cart = require('../models/Cart');

// Helper functions
const toStr = (id) => id ? id.toString() : null;

// Build ID maps from existing PostgreSQL data
const idMap = {
  users: new Map(),
  restaurants: new Map(),
  foods: new Map(),
  categories: new Map(),
  orders: new Map(),
  groceryStores: new Map(),
  groceryCategories: new Map(),
  groceryItems: new Map(),
  pharmacyStores: new Map(),
  pharmacyCategories: new Map(),
  pharmacyItems: new Map(),
  grabmartStores: new Map(),
  grabmartCategories: new Map(),
  grabmartItems: new Map(),
  statuses: new Map(),
  promoCodes: new Map(),
};

const getMappedId = (collection, mongoId) => {
  if (!mongoId) return null;
  return idMap[collection].get(toStr(mongoId)) || null;
};

// Stats tracking
let stats = {};

// Load existing ID mappings from Phase 1
async function loadExistingMappings() {
  console.log('📋 Loading existing ID mappings from Phase 1...');
  
  // We need to rebuild mappings by matching unique fields
  // For users, match by email
  const mongoUsers = await mongoose.connection.db.collection('users').find({}).toArray();
  const pgUsers = await prisma.user.findMany({ select: { id: true, email: true } });
  const pgUserMap = new Map(pgUsers.map(u => [u.email, u.id]));
  
  for (const mu of mongoUsers) {
    if (mu.email && pgUserMap.has(mu.email)) {
      idMap.users.set(toStr(mu._id), pgUserMap.get(mu.email));
    }
  }
  console.log(`  Users mapped: ${idMap.users.size}`);

  // For restaurants, match by email
  const mongoRests = await mongoose.connection.db.collection('restaurants').find({}).toArray();
  const pgRests = await prisma.restaurant.findMany({ select: { id: true, email: true } });
  const pgRestMap = new Map(pgRests.map(r => [r.email, r.id]));
  
  for (const mr of mongoRests) {
    if (mr.email && pgRestMap.has(mr.email)) {
      idMap.restaurants.set(toStr(mr._id), pgRestMap.get(mr.email));
    }
  }
  console.log(`  Restaurants mapped: ${idMap.restaurants.size}`);

  // For categories, match by name
  const mongoCats = await mongoose.connection.db.collection('categories').find({}).toArray();
  const pgCats = await prisma.category.findMany({ select: { id: true, name: true } });
  const pgCatMap = new Map(pgCats.map(c => [c.name, c.id]));
  
  for (const mc of mongoCats) {
    if (mc.name && pgCatMap.has(mc.name)) {
      idMap.categories.set(toStr(mc._id), pgCatMap.get(mc.name));
    }
  }
  console.log(`  Categories mapped: ${idMap.categories.size}`);

  // For foods, match by name + restaurantId combo (use first match)
  const mongoFoods = await mongoose.connection.db.collection('foods').find({}).toArray();
  const pgFoods = await prisma.food.findMany({ select: { id: true, name: true } });
  const pgFoodMap = new Map(pgFoods.map(f => [f.name, f.id]));
  
  for (const mf of mongoFoods) {
    if (mf.name && pgFoodMap.has(mf.name)) {
      idMap.foods.set(toStr(mf._id), pgFoodMap.get(mf.name));
    }
  }
  console.log(`  Foods mapped: ${idMap.foods.size}`);

  // For orders, match by orderNumber
  const mongoOrders = await mongoose.connection.db.collection('orders').find({}).toArray();
  const pgOrders = await prisma.order.findMany({ select: { id: true, orderNumber: true } });
  const pgOrderMap = new Map(pgOrders.map(o => [o.orderNumber, o.id]));
  
  for (const mo of mongoOrders) {
    if (mo.orderNumber && pgOrderMap.has(mo.orderNumber)) {
      idMap.orders.set(toStr(mo._id), pgOrderMap.get(mo.orderNumber));
    }
  }
  console.log(`  Orders mapped: ${idMap.orders.size}`);

  // For grocery stores, match by email
  const mongoGrocery = await mongoose.connection.db.collection('grocerystores').find({}).toArray();
  const pgGrocery = await prisma.groceryStore.findMany({ select: { id: true, email: true } });
  const pgGroceryMap = new Map(pgGrocery.map(g => [g.email, g.id]));
  
  for (const mg of mongoGrocery) {
    if (mg.email && pgGroceryMap.has(mg.email)) {
      idMap.groceryStores.set(toStr(mg._id), pgGroceryMap.get(mg.email));
    }
  }
  console.log(`  Grocery Stores mapped: ${idMap.groceryStores.size}`);

  console.log('✅ ID mappings loaded\n');
}

// Migration functions for Phase 2

async function migrateRiders() {
  console.log('📦 Migrating Riders...');
  const riders = await Rider.find({}).select('+password').lean();
  stats.riders = { total: riders.length, migrated: 0, failed: 0 };

  for (const rider of riders) {
    try {
      const userId = getMappedId('users', rider.user);
      const coords = rider.currentLocation?.coordinates || [0, 0];

      await prisma.rider.create({
        data: {
          userId,
          vehicleType: rider.vehicleType || 'motorcycle',
          vehiclePlateNumber: rider.vehiclePlateNumber,
          licenseNumber: rider.licenseNumber,
          isAvailable: rider.isAvailable !== false,
          isOnline: rider.isOnline || false,
          currentLongitude: coords[0],
          currentLatitude: coords[1],
          totalDeliveries: rider.totalDeliveries || 0,
          rating: rider.rating || 0,
          ratingCount: rider.ratingCount || 0,
          status: rider.status || 'pending',
          createdAt: rider.createdAt || new Date(),
          updatedAt: rider.updatedAt || new Date(),
        },
      });
      stats.riders.migrated++;
    } catch (error) {
      console.error(`  ❌ Rider failed:`, error.message);
      stats.riders.failed++;
    }
  }
  console.log(`  ✅ Riders: ${stats.riders.migrated}/${stats.riders.total}`);
}

async function migrateRiderWallets() {
  console.log('📦 Migrating Rider Wallets...');
  const wallets = await RiderWallet.find({}).lean();
  stats.riderWallets = { total: wallets.length, migrated: 0, failed: 0 };

  for (const wallet of wallets) {
    try {
      const riderId = getMappedId('users', wallet.rider);
      if (!riderId) {
        stats.riderWallets.failed++;
        continue;
      }

      await prisma.riderWallet.create({
        data: {
          riderId,
          balance: wallet.balance || 0,
          currency: wallet.currency || 'GHS',
          createdAt: wallet.createdAt || new Date(),
          updatedAt: wallet.updatedAt || new Date(),
        },
      });
      stats.riderWallets.migrated++;
    } catch (error) {
      console.error(`  ❌ Wallet failed:`, error.message);
      stats.riderWallets.failed++;
    }
  }
  console.log(`  ✅ Rider Wallets: ${stats.riderWallets.migrated}/${stats.riderWallets.total}`);
}

async function migrateStatuses() {
  console.log('📦 Migrating Statuses...');
  const statuses = await Status.find({}).lean();
  stats.statuses = { total: statuses.length, migrated: 0, failed: 0 };

  for (const status of statuses) {
    try {
      const userId = getMappedId('users', status.user);
      if (!userId) {
        stats.statuses.failed++;
        continue;
      }

      const newStatus = await prisma.status.create({
        data: {
          userId,
          mediaType: status.mediaType || 'image',
          mediaUrl: status.mediaUrl,
          blurHash: status.blurHash,
          thumbnailUrl: status.thumbnailUrl,
          caption: status.caption,
          backgroundColor: status.backgroundColor,
          fontStyle: status.fontStyle,
          duration: status.duration || 15000,
          expiresAt: status.expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000),
          createdAt: status.createdAt || new Date(),
        },
      });

      idMap.statuses.set(toStr(status._id), newStatus.id);

      // Migrate views
      if (status.views && status.views.length > 0) {
        for (const view of status.views) {
          const viewerId = getMappedId('users', view.user);
          if (viewerId) {
            await prisma.statusView.create({
              data: {
                statusId: newStatus.id,
                userId: viewerId,
                viewedAt: view.viewedAt || new Date(),
              },
            });
          }
        }
      }

      // Migrate likes
      if (status.likes && status.likes.length > 0) {
        for (const like of status.likes) {
          const likerId = getMappedId('users', like.user);
          if (likerId) {
            await prisma.statusLike.create({
              data: {
                statusId: newStatus.id,
                userId: likerId,
                createdAt: like.createdAt || new Date(),
              },
            });
          }
        }
      }

      stats.statuses.migrated++;
    } catch (error) {
      console.error(`  ❌ Status failed:`, error.message);
      stats.statuses.failed++;
    }
  }
  console.log(`  ✅ Statuses: ${stats.statuses.migrated}/${stats.statuses.total}`);
}

async function migrateComments() {
  console.log('📦 Migrating Comments...');
  const comments = await Comment.find({}).lean();
  stats.comments = { total: comments.length, migrated: 0, failed: 0 };

  for (const comment of comments) {
    try {
      const userId = getMappedId('users', comment.user);
      const statusId = getMappedId('statuses', comment.status);
      
      if (!userId || !statusId) {
        stats.comments.failed++;
        continue;
      }

      await prisma.comment.create({
        data: {
          statusId,
          userId,
          text: comment.text,
          createdAt: comment.createdAt || new Date(),
          updatedAt: comment.updatedAt || new Date(),
        },
      });
      stats.comments.migrated++;
    } catch (error) {
      stats.comments.failed++;
    }
  }
  console.log(`  ✅ Comments: ${stats.comments.migrated}/${stats.comments.total}`);
}

async function migrateReactions() {
  console.log('📦 Migrating Reactions...');
  const reactions = await Reaction.find({}).lean();
  stats.reactions = { total: reactions.length, migrated: 0, failed: 0 };

  for (const reaction of reactions) {
    try {
      const userId = getMappedId('users', reaction.user);
      const statusId = getMappedId('statuses', reaction.status);
      
      if (!userId || !statusId) {
        stats.reactions.failed++;
        continue;
      }

      await prisma.reaction.create({
        data: {
          statusId,
          userId,
          emoji: reaction.emoji || '❤️',
          createdAt: reaction.createdAt || new Date(),
        },
      });
      stats.reactions.migrated++;
    } catch (error) {
      stats.reactions.failed++;
    }
  }
  console.log(`  ✅ Reactions: ${stats.reactions.migrated}/${stats.reactions.total}`);
}

async function migrateNotifications() {
  console.log('📦 Migrating Notifications...');
  const notifications = await Notification.find({}).lean();
  stats.notifications = { total: notifications.length, migrated: 0, failed: 0 };

  for (const notif of notifications) {
    try {
      const userId = getMappedId('users', notif.user);
      if (!userId) {
        stats.notifications.failed++;
        continue;
      }

      await prisma.notification.create({
        data: {
          userId,
          type: notif.type || 'general',
          title: notif.title || '',
          body: notif.body || '',
          data: notif.data ? JSON.stringify(notif.data) : null,
          imageUrl: notif.imageUrl,
          referenceId: notif.referenceId,
          referenceModel: notif.referenceModel,
          isRead: notif.isRead || false,
          readAt: notif.readAt,
          createdAt: notif.createdAt || new Date(),
        },
      });
      stats.notifications.migrated++;
    } catch (error) {
      stats.notifications.failed++;
    }
  }
  console.log(`  ✅ Notifications: ${stats.notifications.migrated}/${stats.notifications.total}`);
}

async function migratePayments() {
  console.log('📦 Migrating Payments...');
  const payments = await Payment.find({}).lean();
  stats.payments = { total: payments.length, migrated: 0, failed: 0 };

  for (const payment of payments) {
    try {
      const orderId = getMappedId('orders', payment.order);
      const userId = getMappedId('users', payment.user);
      
      if (!orderId || !userId) {
        stats.payments.failed++;
        continue;
      }

      await prisma.payment.create({
        data: {
          orderId,
          userId,
          amount: payment.amount || 0,
          currency: payment.currency || 'GHS',
          provider: payment.provider || 'cash',
          providerReference: payment.providerReference,
          method: payment.method || 'cash',
          status: payment.status || 'pending',
          metadata: payment.metadata ? JSON.stringify(payment.metadata) : null,
          paidAt: payment.paidAt,
          createdAt: payment.createdAt || new Date(),
          updatedAt: payment.updatedAt || new Date(),
        },
      });
      stats.payments.migrated++;
    } catch (error) {
      console.error(`  ❌ Payment failed:`, error.message);
      stats.payments.failed++;
    }
  }
  console.log(`  ✅ Payments: ${stats.payments.migrated}/${stats.payments.total}`);
}

async function migratePromoCodes() {
  console.log('📦 Migrating Promo Codes...');
  const promoCodes = await PromoCode.find({}).lean();
  stats.promoCodes = { total: promoCodes.length, migrated: 0, failed: 0 };

  for (const promo of promoCodes) {
    try {
      const creatorId = getMappedId('users', promo.createdBy);
      const restaurantId = getMappedId('restaurants', promo.restaurant);

      const newPromo = await prisma.promoCode.create({
        data: {
          code: promo.code,
          description: promo.description,
          discountType: promo.discountType || 'percentage',
          discountValue: promo.discountValue || 0,
          minOrderAmount: promo.minOrderAmount || 0,
          maxDiscountAmount: promo.maxDiscountAmount,
          maxUsageCount: promo.maxUsageCount,
          usageCount: promo.usageCount || 0,
          maxUsagePerUser: promo.maxUsagePerUser || 1,
          isActive: promo.isActive !== false,
          scope: promo.scope || 'all',
          orderType: promo.orderType || 'food',
          restaurantId,
          startDate: promo.startDate || new Date(),
          endDate: promo.endDate,
          createdById: creatorId,
          createdAt: promo.createdAt || new Date(),
          updatedAt: promo.updatedAt || new Date(),
        },
      });

      idMap.promoCodes.set(toStr(promo._id), newPromo.id);
      stats.promoCodes.migrated++;
    } catch (error) {
      console.error(`  ❌ PromoCode failed:`, error.message);
      stats.promoCodes.failed++;
    }
  }
  console.log(`  ✅ Promo Codes: ${stats.promoCodes.migrated}/${stats.promoCodes.total}`);
}

async function migratePromotionalBanners() {
  console.log('📦 Migrating Promotional Banners...');
  const banners = await PromotionalBanner.find({}).lean();
  stats.banners = { total: banners.length, migrated: 0, failed: 0 };

  for (const banner of banners) {
    try {
      const restaurantId = getMappedId('restaurants', banner.restaurant);

      await prisma.promotionalBanner.create({
        data: {
          title: banner.title,
          description: banner.description,
          imageUrl: banner.imageUrl,
          blurHash: banner.blurHash,
          linkType: banner.linkType || 'none',
          linkValue: banner.linkValue,
          restaurantId,
          promoCodeId: getMappedId('promoCodes', banner.promoCode),
          categoryId: getMappedId('categories', banner.category),
          backgroundColor: banner.backgroundColor,
          textColor: banner.textColor,
          priority: banner.priority || 0,
          isActive: banner.isActive !== false,
          startDate: banner.startDate,
          endDate: banner.endDate,
          createdAt: banner.createdAt || new Date(),
          updatedAt: banner.updatedAt || new Date(),
        },
      });
      stats.banners.migrated++;
    } catch (error) {
      console.error(`  ❌ Banner failed:`, error.message);
      stats.banners.failed++;
    }
  }
  console.log(`  ✅ Promotional Banners: ${stats.banners.migrated}/${stats.banners.total}`);
}

async function migrateReferralCodes() {
  console.log('📦 Migrating Referral Codes...');
  const codes = await ReferralCode.find({}).lean();
  stats.referralCodes = { total: codes.length, migrated: 0, failed: 0 };

  for (const code of codes) {
    try {
      const userId = getMappedId('users', code.user);
      if (!userId) {
        stats.referralCodes.failed++;
        continue;
      }

      await prisma.referralCode.create({
        data: {
          userId,
          code: code.code,
          usageCount: code.usageCount || 0,
          maxUsage: code.maxUsage,
          isActive: code.isActive !== false,
          createdAt: code.createdAt || new Date(),
        },
      });
      stats.referralCodes.migrated++;
    } catch (error) {
      console.error(`  ❌ ReferralCode failed:`, error.message);
      stats.referralCodes.failed++;
    }
  }
  console.log(`  ✅ Referral Codes: ${stats.referralCodes.migrated}/${stats.referralCodes.total}`);
}

async function migrateReferrals() {
  console.log('📦 Migrating Referrals...');
  const referrals = await Referral.find({}).lean();
  stats.referrals = { total: referrals.length, migrated: 0, failed: 0 };

  for (const ref of referrals) {
    try {
      const referrerId = getMappedId('users', ref.referrer);
      const refereeId = getMappedId('users', ref.referee);
      
      if (!referrerId || !refereeId) {
        stats.referrals.failed++;
        continue;
      }

      await prisma.referral.create({
        data: {
          referrerId,
          refereeId,
          code: ref.code,
          status: ref.status || 'pending',
          referrerReward: ref.referrerReward || 0,
          refereeReward: ref.refereeReward || 0,
          completedAt: ref.completedAt,
          createdAt: ref.createdAt || new Date(),
        },
      });
      stats.referrals.migrated++;
    } catch (error) {
      console.error(`  ❌ Referral failed:`, error.message);
      stats.referrals.failed++;
    }
  }
  console.log(`  ✅ Referrals: ${stats.referrals.migrated}/${stats.referrals.total}`);
}

async function migrateUserCredits() {
  console.log('📦 Migrating User Credits...');
  const credits = await UserCredit.find({}).lean();
  stats.userCredits = { total: credits.length, migrated: 0, failed: 0 };

  for (const credit of credits) {
    try {
      const userId = getMappedId('users', credit.user);
      if (!userId) {
        stats.userCredits.failed++;
        continue;
      }

      await prisma.userCredit.create({
        data: {
          userId,
          balance: credit.balance || 0,
          currency: credit.currency || 'GHS',
          createdAt: credit.createdAt || new Date(),
          updatedAt: credit.updatedAt || new Date(),
        },
      });
      stats.userCredits.migrated++;
    } catch (error) {
      console.error(`  ❌ UserCredit failed:`, error.message);
      stats.userCredits.failed++;
    }
  }
  console.log(`  ✅ User Credits: ${stats.userCredits.migrated}/${stats.userCredits.total}`);
}

async function migrateOrderTracking() {
  console.log('📦 Migrating Order Tracking...');
  const trackings = await OrderTracking.find({}).lean();
  stats.orderTracking = { total: trackings.length, migrated: 0, failed: 0 };

  for (const tracking of trackings) {
    try {
      const orderId = getMappedId('orders', tracking.order);
      const riderId = getMappedId('users', tracking.rider);
      
      if (!orderId) {
        stats.orderTracking.failed++;
        continue;
      }

      const riderCoords = tracking.riderLocation?.coordinates || [0, 0];
      const destCoords = tracking.destinationLocation?.coordinates || [0, 0];

      const newTracking = await prisma.orderTracking.create({
        data: {
          orderId,
          riderId,
          status: tracking.status || 'pending',
          riderLongitude: riderCoords[0],
          riderLatitude: riderCoords[1],
          destinationLongitude: destCoords[0],
          destinationLatitude: destCoords[1],
          estimatedDeliveryTime: tracking.estimatedDeliveryTime,
          actualDeliveryTime: tracking.actualDeliveryTime,
          createdAt: tracking.createdAt || new Date(),
          updatedAt: tracking.updatedAt || new Date(),
        },
      });

      // Migrate history
      if (tracking.history && tracking.history.length > 0) {
        for (const hist of tracking.history) {
          const histCoords = hist.location?.coordinates || [0, 0];
          await prisma.orderTrackingHistory.create({
            data: {
              orderTrackingId: newTracking.id,
              status: hist.status,
              longitude: histCoords[0],
              latitude: histCoords[1],
              note: hist.note,
              timestamp: hist.timestamp || new Date(),
            },
          });
        }
      }

      stats.orderTracking.migrated++;
    } catch (error) {
      console.error(`  ❌ OrderTracking failed:`, error.message);
      stats.orderTracking.failed++;
    }
  }
  console.log(`  ✅ Order Tracking: ${stats.orderTracking.migrated}/${stats.orderTracking.total}`);
}

async function migrateScheduledNotifications() {
  console.log('📦 Migrating Scheduled Notifications...');
  const scheduled = await ScheduledNotification.find({}).lean();
  stats.scheduledNotifications = { total: scheduled.length, migrated: 0, failed: 0 };

  for (const notif of scheduled) {
    try {
      const userId = getMappedId('users', notif.userId);
      if (!userId) {
        stats.scheduledNotifications.failed++;
        continue;
      }

      await prisma.scheduledNotification.create({
        data: {
          userId,
          type: notif.type || 'general',
          title: notif.title,
          body: notif.body,
          data: notif.data ? JSON.stringify(notif.data) : null,
          scheduledFor: notif.scheduledFor,
          sent: notif.sent || false,
          sentAt: notif.sentAt,
          cancelled: notif.cancelled || false,
          createdAt: notif.createdAt || new Date(),
        },
      });
      stats.scheduledNotifications.migrated++;
    } catch (error) {
      stats.scheduledNotifications.failed++;
    }
  }
  console.log(`  ✅ Scheduled Notifications: ${stats.scheduledNotifications.migrated}/${stats.scheduledNotifications.total}`);
}

async function migrateGroceryCategories() {
  console.log('📦 Migrating Grocery Categories...');
  const categories = await GroceryCategory.find({}).lean();
  stats.groceryCategories = { total: categories.length, migrated: 0, failed: 0 };

  for (const cat of categories) {
    try {
      const storeId = getMappedId('groceryStores', cat.store);
      if (!storeId) {
        stats.groceryCategories.failed++;
        continue;
      }

      const newCat = await prisma.groceryCategory.create({
        data: {
          storeId,
          name: cat.name,
          description: cat.description,
          image: cat.image,
          isActive: cat.isActive !== false,
          sortOrder: cat.sortOrder || 0,
          createdAt: cat.createdAt || new Date(),
          updatedAt: cat.updatedAt || new Date(),
        },
      });
      idMap.groceryCategories.set(toStr(cat._id), newCat.id);
      stats.groceryCategories.migrated++;
    } catch (error) {
      console.error(`  ❌ GroceryCategory failed:`, error.message);
      stats.groceryCategories.failed++;
    }
  }
  console.log(`  ✅ Grocery Categories: ${stats.groceryCategories.migrated}/${stats.groceryCategories.total}`);
}

async function migrateGroceryItems() {
  console.log('📦 Migrating Grocery Items...');
  const items = await GroceryItem.find({}).lean();
  stats.groceryItems = { total: items.length, migrated: 0, failed: 0 };

  for (const item of items) {
    try {
      const storeId = getMappedId('groceryStores', item.store);
      const categoryId = getMappedId('groceryCategories', item.category);
      
      if (!storeId) {
        stats.groceryItems.failed++;
        continue;
      }

      const newItem = await prisma.groceryItem.create({
        data: {
          storeId,
          categoryId,
          name: item.name,
          description: item.description,
          price: item.price || 0,
          compareAtPrice: item.compareAtPrice,
          images: item.images || [],
          blurHashes: item.blurHashes || [],
          unit: item.unit || 'piece',
          stock: item.stock || 0,
          isAvailable: item.isAvailable !== false,
          isFeatured: item.isFeatured || false,
          tags: item.tags || [],
          createdAt: item.createdAt || new Date(),
          updatedAt: item.updatedAt || new Date(),
        },
      });
      idMap.groceryItems.set(toStr(item._id), newItem.id);
      stats.groceryItems.migrated++;
    } catch (error) {
      console.error(`  ❌ GroceryItem failed:`, error.message);
      stats.groceryItems.failed++;
    }
  }
  console.log(`  ✅ Grocery Items: ${stats.groceryItems.migrated}/${stats.groceryItems.total}`);
}

async function migratePharmacyStores() {
  console.log('📦 Migrating Pharmacy Stores...');
  const stores = await PharmacyStore.find({}).select('+password').lean();
  stats.pharmacyStores = { total: stores.length, migrated: 0, failed: 0 };

  for (const store of stores) {
    try {
      const coords = store.location?.coordinates || [0, 0];
      
      const newStore = await prisma.pharmacyStore.create({
        data: {
          storeName: store.storeName,
          logo: store.logo,
          description: store.description,
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
          licenseNumber: store.licenseNumber,
          pharmacistName: store.pharmacistName,
          createdAt: store.createdAt || new Date(),
          updatedAt: store.updatedAt || new Date(),
        },
      });
      idMap.pharmacyStores.set(toStr(store._id), newStore.id);
      stats.pharmacyStores.migrated++;
    } catch (error) {
      console.error(`  ❌ PharmacyStore failed:`, error.message);
      stats.pharmacyStores.failed++;
    }
  }
  console.log(`  ✅ Pharmacy Stores: ${stats.pharmacyStores.migrated}/${stats.pharmacyStores.total}`);
}

async function migratePharmacyCategories() {
  console.log('📦 Migrating Pharmacy Categories...');
  const categories = await PharmacyCategory.find({}).lean();
  stats.pharmacyCategories = { total: categories.length, migrated: 0, failed: 0 };

  for (const cat of categories) {
    try {
      const storeId = getMappedId('pharmacyStores', cat.store);
      if (!storeId) {
        stats.pharmacyCategories.failed++;
        continue;
      }

      const newCat = await prisma.pharmacyCategory.create({
        data: {
          storeId,
          name: cat.name,
          description: cat.description,
          image: cat.image,
          isActive: cat.isActive !== false,
          sortOrder: cat.sortOrder || 0,
          createdAt: cat.createdAt || new Date(),
          updatedAt: cat.updatedAt || new Date(),
        },
      });
      idMap.pharmacyCategories.set(toStr(cat._id), newCat.id);
      stats.pharmacyCategories.migrated++;
    } catch (error) {
      console.error(`  ❌ PharmacyCategory failed:`, error.message);
      stats.pharmacyCategories.failed++;
    }
  }
  console.log(`  ✅ Pharmacy Categories: ${stats.pharmacyCategories.migrated}/${stats.pharmacyCategories.total}`);
}

async function migratePharmacyItems() {
  console.log('📦 Migrating Pharmacy Items...');
  const items = await PharmacyItem.find({}).lean();
  stats.pharmacyItems = { total: items.length, migrated: 0, failed: 0 };

  for (const item of items) {
    try {
      const storeId = getMappedId('pharmacyStores', item.store);
      const categoryId = getMappedId('pharmacyCategories', item.category);
      
      if (!storeId) {
        stats.pharmacyItems.failed++;
        continue;
      }

      await prisma.pharmacyItem.create({
        data: {
          storeId,
          categoryId,
          name: item.name,
          description: item.description,
          price: item.price || 0,
          images: item.images || [],
          blurHashes: item.blurHashes || [],
          requiresPrescription: item.requiresPrescription || false,
          dosage: item.dosage,
          manufacturer: item.manufacturer,
          stock: item.stock || 0,
          isAvailable: item.isAvailable !== false,
          createdAt: item.createdAt || new Date(),
          updatedAt: item.updatedAt || new Date(),
        },
      });
      stats.pharmacyItems.migrated++;
    } catch (error) {
      console.error(`  ❌ PharmacyItem failed:`, error.message);
      stats.pharmacyItems.failed++;
    }
  }
  console.log(`  ✅ Pharmacy Items: ${stats.pharmacyItems.migrated}/${stats.pharmacyItems.total}`);
}

async function migrateGrabMartStores() {
  console.log('📦 Migrating GrabMart Stores...');
  const stores = await GrabMartStore.find({}).select('+password').lean();
  stats.grabmartStores = { total: stores.length, migrated: 0, failed: 0 };

  for (const store of stores) {
    try {
      const coords = store.location?.coordinates || [0, 0];
      
      const newStore = await prisma.grabMartStore.create({
        data: {
          storeName: store.storeName,
          logo: store.logo,
          description: store.description,
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
          createdAt: store.createdAt || new Date(),
          updatedAt: store.updatedAt || new Date(),
        },
      });
      idMap.grabmartStores.set(toStr(store._id), newStore.id);
      stats.grabmartStores.migrated++;
    } catch (error) {
      console.error(`  ❌ GrabMartStore failed:`, error.message);
      stats.grabmartStores.failed++;
    }
  }
  console.log(`  ✅ GrabMart Stores: ${stats.grabmartStores.migrated}/${stats.grabmartStores.total}`);
}

async function migrateGrabMartCategories() {
  console.log('📦 Migrating GrabMart Categories...');
  const categories = await GrabMartCategory.find({}).lean();
  stats.grabmartCategories = { total: categories.length, migrated: 0, failed: 0 };

  for (const cat of categories) {
    try {
      const storeId = getMappedId('grabmartStores', cat.store);
      if (!storeId) {
        stats.grabmartCategories.failed++;
        continue;
      }

      const newCat = await prisma.grabMartCategory.create({
        data: {
          storeId,
          name: cat.name,
          description: cat.description,
          image: cat.image,
          isActive: cat.isActive !== false,
          sortOrder: cat.sortOrder || 0,
          createdAt: cat.createdAt || new Date(),
          updatedAt: cat.updatedAt || new Date(),
        },
      });
      idMap.grabmartCategories.set(toStr(cat._id), newCat.id);
      stats.grabmartCategories.migrated++;
    } catch (error) {
      console.error(`  ❌ GrabMartCategory failed:`, error.message);
      stats.grabmartCategories.failed++;
    }
  }
  console.log(`  ✅ GrabMart Categories: ${stats.grabmartCategories.migrated}/${stats.grabmartCategories.total}`);
}

async function migrateGrabMartItems() {
  console.log('📦 Migrating GrabMart Items...');
  const items = await GrabMartItem.find({}).lean();
  stats.grabmartItems = { total: items.length, migrated: 0, failed: 0 };

  for (const item of items) {
    try {
      const storeId = getMappedId('grabmartStores', item.store);
      const categoryId = getMappedId('grabmartCategories', item.category);
      
      if (!storeId) {
        stats.grabmartItems.failed++;
        continue;
      }

      await prisma.grabMartItem.create({
        data: {
          storeId,
          categoryId,
          name: item.name,
          description: item.description,
          price: item.price || 0,
          compareAtPrice: item.compareAtPrice,
          images: item.images || [],
          blurHashes: item.blurHashes || [],
          unit: item.unit || 'piece',
          stock: item.stock || 0,
          isAvailable: item.isAvailable !== false,
          isFeatured: item.isFeatured || false,
          tags: item.tags || [],
          createdAt: item.createdAt || new Date(),
          updatedAt: item.updatedAt || new Date(),
        },
      });
      stats.grabmartItems.migrated++;
    } catch (error) {
      console.error(`  ❌ GrabMartItem failed:`, error.message);
      stats.grabmartItems.failed++;
    }
  }
  console.log(`  ✅ GrabMart Items: ${stats.grabmartItems.migrated}/${stats.grabmartItems.total}`);
}

async function migrateCarts() {
  console.log('📦 Migrating Carts...');
  const carts = await Cart.find({}).lean();
  stats.carts = { total: carts.length, migrated: 0, failed: 0 };

  for (const cart of carts) {
    try {
      const userId = getMappedId('users', cart.user);
      if (!userId) {
        stats.carts.failed++;
        continue;
      }

      const newCart = await prisma.cart.create({
        data: {
          userId,
          restaurantId: getMappedId('restaurants', cart.restaurant),
          groceryStoreId: getMappedId('groceryStores', cart.groceryStore),
          pharmacyStoreId: getMappedId('pharmacyStores', cart.pharmacyStore),
          grabMartStoreId: getMappedId('grabmartStores', cart.grabMartStore),
          orderType: cart.orderType || 'food',
          lastActivityAt: cart.lastActivityAt || new Date(),
          createdAt: cart.createdAt || new Date(),
          updatedAt: cart.updatedAt || new Date(),
        },
      });

      // Migrate cart items
      if (cart.items && cart.items.length > 0) {
        for (const item of cart.items) {
          await prisma.cartItem.create({
            data: {
              cartId: newCart.id,
              foodId: getMappedId('foods', item.food),
              groceryItemId: getMappedId('groceryItems', item.groceryItem),
              pharmacyItemId: getMappedId('pharmacyItems', item.pharmacyItem),
              grabMartItemId: getMappedId('grabmartItems', item.grabMartItem),
              quantity: item.quantity || 1,
              specialInstructions: item.specialInstructions,
              addons: item.addons ? JSON.stringify(item.addons) : null,
              createdAt: item.addedAt || new Date(),
            },
          });
        }
      }

      stats.carts.migrated++;
    } catch (error) {
      console.error(`  ❌ Cart failed:`, error.message);
      stats.carts.failed++;
    }
  }
  console.log(`  ✅ Carts: ${stats.carts.migrated}/${stats.carts.total}`);
}

// Main function
async function runPhase2Migration() {
  console.log('🚀 Starting Phase 2 Migration...');
  console.log('================================\n');

  try {
    // Connect to MongoDB
    console.log('📡 Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ MongoDB connected\n');

    // Load existing ID mappings from Phase 1
    await loadExistingMappings();

    // Run migrations in order
    await migrateRiders();
    await migrateRiderWallets();
    await migrateStatuses();
    await migrateComments();
    await migrateReactions();
    await migrateNotifications();
    await migratePayments();
    await migratePromoCodes();
    await migratePromotionalBanners();
    await migrateReferralCodes();
    await migrateReferrals();
    await migrateUserCredits();
    await migrateOrderTracking();
    await migrateScheduledNotifications();
    await migrateGroceryCategories();
    await migrateGroceryItems();
    await migratePharmacyStores();
    await migratePharmacyCategories();
    await migratePharmacyItems();
    await migrateGrabMartStores();
    await migrateGrabMartCategories();
    await migrateGrabMartItems();
    await migrateCarts();

    // Print summary
    console.log('\n================================');
    console.log('📊 PHASE 2 MIGRATION SUMMARY');
    console.log('================================');
    Object.entries(stats).forEach(([collection, s]) => {
      if (s.total > 0) {
        const status = s.failed === 0 ? '✅' : '⚠️';
        console.log(`${status} ${collection}: ${s.migrated}/${s.total} (${s.failed} failed)`);
      }
    });

  } catch (error) {
    console.error('\n❌ Migration failed:', error);
  } finally {
    await mongoose.disconnect();
    await prisma.$disconnect();
    await pool.end();
    console.log('\n🔌 Connections closed');
  }
}

// Run
runPhase2Migration()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
