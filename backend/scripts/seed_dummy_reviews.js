const path = require("path");
const dotenv = require("dotenv");

dotenv.config({ path: path.resolve(__dirname, "../.env") });

const prisma = require("../config/prisma");
const { submitVendorRating } = require("../services/vendor_rating_service");
const { submitItemReviews } = require("../services/item_review_service");

const ORDER_NOTE_MARKER = "[seed-review-demo]";
const DEFAULT_VENDOR_REVIEWS_PER_VENDOR = 4;
const DEFAULT_FOOD_REVIEWS_PER_ITEM = 3;
const DEFAULT_MIN_SEED_USERS = 6;
const MAX_REVIEWERS = 12;
const SCRIPT_TRANSACTION_OPTIONS = {
  maxWait: 15000,
  timeout: 30000,
};

const REVIEWER_PROFILES = [
  { username: "AmaReview", email: "reviews+ama@grabgo.test" },
  { username: "KwesiEats", email: "reviews+kwesi@grabgo.test" },
  { username: "EfuaOrders", email: "reviews+efua@grabgo.test" },
  { username: "KojoFoodie", email: "reviews+kojo@grabgo.test" },
  { username: "AbenaTaste", email: "reviews+abena@grabgo.test" },
  { username: "YawBuyer", email: "reviews+yaw@grabgo.test" },
  { username: "AdwoaCooks", email: "reviews+adwoa@grabgo.test" },
  { username: "KobbyFresh", email: "reviews+kobby@grabgo.test" },
  { username: "AkosuaFork", email: "reviews+akosua@grabgo.test" },
  { username: "NanaBasket", email: "reviews+nana@grabgo.test" },
  { username: "AkuaDaily", email: "reviews+akua@grabgo.test" },
  { username: "MensahTable", email: "reviews+mensah@grabgo.test" },
];

const VENDOR_REVIEW_TAGS = {
  5: ["Well packaged", "Order accurate", "Good quality"],
  4: ["Good quality", "Good packaging", "Prepared on time"],
  3: ["Decent quality", "Could improve packaging", "Average experience"],
};

const ITEM_REVIEW_TAGS = {
  5: ["Great taste", "Worth it", "Fresh"],
  4: ["Tasty", "Good portion", "Well prepared"],
  3: ["Decent", "Could be better", "Average"],
};

const VENDOR_COMMENT_TEMPLATES = {
  5: [
    "{name} handled the order really well. The packaging was neat and everything felt carefully prepared.",
    "Very solid order from {name}. The items arrived in good condition and the packaging held up well.",
    "{name} got the order right and the presentation was clean. I would order from here again.",
  ],
  4: [
    "Good experience with {name}. The order was accurate and the packaging was decent for delivery.",
    "{name} did well overall. Product quality was good and the order was packed properly.",
    "I enjoyed ordering from {name}. It was a smooth experience, though the packaging could be a little tighter.",
  ],
  3: [
    "{name} got the order right, but the packaging could be improved for delivery.",
    "Decent experience with {name}. The order was okay, though the packaging needs more attention.",
    "{name} was fine overall, but there is room to improve consistency and presentation.",
  ],
};

const ITEM_COMMENT_TEMPLATES = {
  5: [
    "{name} had great flavor and a good portion size. I would order this again.",
    "Really enjoyed {name}. It tasted fresh and felt worth the price.",
    "{name} stood out for me. Good texture, solid portion, and very satisfying overall.",
  ],
  4: [
    "{name} was tasty and fresh. I would order it again, though it could use a little more punch.",
    "Good item overall. {name} arrived in good shape and the portion was fair.",
    "I liked {name}. It was well prepared and enjoyable from start to finish.",
  ],
  3: [
    "{name} was decent, but it did not fully stand out this time.",
    "Not bad overall. {name} was okay, though I expected a bit more flavor.",
    "{name} was fine for the price, but it could be more consistent.",
  ],
};

const VENDOR_CONFIG = {
  restaurant: {
    orderType: "food",
    orderVendorField: "restaurantId",
    model: "restaurant",
    nameField: "restaurantName",
    itemTypeEnum: "Food",
    orderItemField: "foodId",
    itemImageField: "foodImage",
    itemUnitField: null,
  },
  grocery: {
    orderType: "grocery",
    orderVendorField: "groceryStoreId",
    model: "groceryStore",
    nameField: "storeName",
    itemTypeEnum: "GroceryItem",
    orderItemField: "groceryItemId",
    itemImageField: "image",
    itemUnitField: "unit",
  },
  pharmacy: {
    orderType: "pharmacy",
    orderVendorField: "pharmacyStoreId",
    model: "pharmacyStore",
    nameField: "storeName",
    itemTypeEnum: "PharmacyItem",
    orderItemField: "pharmacyItemId",
    itemImageField: "image",
    itemUnitField: "unit",
  },
  grabmart: {
    orderType: "grabmart",
    orderVendorField: "grabMartStoreId",
    model: "grabMartStore",
    nameField: "storeName",
    itemTypeEnum: "GrabMartItem",
    orderItemField: "grabMartItemId",
    itemImageField: "image",
    itemUnitField: "unit",
  },
};

function hashString(input) {
  let hash = 0;
  const value = String(input || "");
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
  }
  return hash;
}

function seededInt(seed, min, max) {
  if (max <= min) return min;
  const range = max - min + 1;
  return min + (hashString(seed) % range);
}

function pickBySeed(items, seed) {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error("pickBySeed requires a non-empty array");
  }
  return items[seededInt(seed, 0, items.length - 1)];
}

function roundToTwo(value) {
  return Math.round((Number(value || 0) + Number.EPSILON) * 100) / 100;
}

function parseIntegerFlag(args, name, fallback) {
  const entry = args.find((arg) => arg.startsWith(`--${name}=`));
  if (!entry) return fallback;
  const parsed = Number.parseInt(entry.split("=")[1], 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseArgs(argv) {
  return {
    dryRun: argv.includes("--dry-run"),
    vendorReviewsPerVendor: parseIntegerFlag(
      argv,
      "vendor-reviews",
      DEFAULT_VENDOR_REVIEWS_PER_VENDOR
    ),
    foodReviewsPerItem: parseIntegerFlag(
      argv,
      "food-reviews",
      DEFAULT_FOOD_REVIEWS_PER_ITEM
    ),
    seedUsers: Math.min(
      MAX_REVIEWERS,
      Math.max(
        DEFAULT_MIN_SEED_USERS,
        parseIntegerFlag(argv, "seed-users", DEFAULT_MIN_SEED_USERS)
      )
    ),
  };
}

function buildVendorComment({ vendorName, rating, seed }) {
  const template = pickBySeed(VENDOR_COMMENT_TEMPLATES[rating], seed);
  return template.replaceAll("{name}", vendorName);
}

function buildItemComment({ itemName, rating, seed }) {
  const template = pickBySeed(ITEM_COMMENT_TEMPLATES[rating], seed);
  return template.replaceAll("{name}", itemName);
}

function buildVendorReviewPayload({ vendorName, seed }) {
  const rating = pickBySeed([5, 5, 4, 4, 4, 3], seed);
  return {
    rating,
    feedbackTags: VENDOR_REVIEW_TAGS[rating],
    comment: buildVendorComment({ vendorName, rating, seed }),
  };
}

function buildItemReviewPayload({ itemName, seed }) {
  const rating = pickBySeed([5, 5, 4, 4, 4, 3], seed);
  return {
    rating,
    feedbackTags: ITEM_REVIEW_TAGS[rating],
    comment: buildItemComment({ itemName, rating, seed }),
  };
}

async function ensureSeedUsers(seedUsers, { dryRun = false } = {}) {
  const profiles = REVIEWER_PROFILES.slice(0, seedUsers);
  const users = [];

  for (const profile of profiles) {
    if (dryRun) {
      const existingUser = await prisma.user.findUnique({
        where: { email: profile.email },
        select: {
          id: true,
          username: true,
          email: true,
        },
      });

      users.push(
        existingUser || {
          id: `dry-run-${profile.username}`,
          username: profile.username,
          email: profile.email,
        }
      );
      continue;
    }

    const user = await prisma.user.upsert({
      where: { email: profile.email },
      update: {
        username: profile.username,
        role: "customer",
        isActive: true,
        isEmailVerified: true,
      },
      create: {
        username: profile.username,
        email: profile.email,
        role: "customer",
        isActive: true,
        isEmailVerified: true,
      },
      select: {
        id: true,
        username: true,
        email: true,
      },
    });

    users.push(user);
  }

  return users;
}

async function loadExistingSeedCounts(seedUserIds) {
  const [vendorReviews, foodItemReviews] = await Promise.all([
    prisma.vendorReview.findMany({
      where: {
        customerId: { in: seedUserIds },
        isHidden: false,
      },
      select: {
        restaurantId: true,
        groceryStoreId: true,
        pharmacyStoreId: true,
        grabMartStoreId: true,
      },
    }),
    prisma.itemReview.findMany({
      where: {
        customerId: { in: seedUserIds },
        isHidden: false,
        itemType: "food",
        foodId: { not: null },
      },
      select: {
        foodId: true,
      },
    }),
  ]);

  const vendorCounts = {
    restaurant: new Map(),
    grocery: new Map(),
    pharmacy: new Map(),
    grabmart: new Map(),
  };

  for (const review of vendorReviews) {
    if (review.restaurantId) {
      vendorCounts.restaurant.set(
        review.restaurantId,
        (vendorCounts.restaurant.get(review.restaurantId) || 0) + 1
      );
    }
    if (review.groceryStoreId) {
      vendorCounts.grocery.set(
        review.groceryStoreId,
        (vendorCounts.grocery.get(review.groceryStoreId) || 0) + 1
      );
    }
    if (review.pharmacyStoreId) {
      vendorCounts.pharmacy.set(
        review.pharmacyStoreId,
        (vendorCounts.pharmacy.get(review.pharmacyStoreId) || 0) + 1
      );
    }
    if (review.grabMartStoreId) {
      vendorCounts.grabmart.set(
        review.grabMartStoreId,
        (vendorCounts.grabmart.get(review.grabMartStoreId) || 0) + 1
      );
    }
  }

  const foodCounts = new Map();
  for (const review of foodItemReviews) {
    if (!review.foodId) continue;
    foodCounts.set(review.foodId, (foodCounts.get(review.foodId) || 0) + 1);
  }

  return { vendorCounts, foodCounts };
}

async function loadTargets() {
  const [restaurants, groceryStores, pharmacyStores, grabMartStores] =
    await Promise.all([
      prisma.restaurant.findMany({
        where: {
          isDeleted: false,
          foods: {
            some: {
              isAvailable: true,
            },
          },
        },
        select: {
          id: true,
          restaurantName: true,
          deliveryFee: true,
          city: true,
          area: true,
          latitude: true,
          longitude: true,
          foods: {
            where: {
              isAvailable: true,
            },
            orderBy: {
              name: "asc",
            },
            select: {
              id: true,
              name: true,
              price: true,
              foodImage: true,
            },
          },
        },
        orderBy: {
          restaurantName: "asc",
        },
      }),
      prisma.groceryStore.findMany({
        where: {
          isDeleted: false,
          items: {
            some: {
              isAvailable: true,
            },
          },
        },
        select: {
          id: true,
          storeName: true,
          deliveryFee: true,
          city: true,
          area: true,
          latitude: true,
          longitude: true,
          items: {
            where: {
              isAvailable: true,
            },
            orderBy: {
              name: "asc",
            },
            take: 3,
            select: {
              id: true,
              name: true,
              price: true,
              image: true,
              unit: true,
            },
          },
        },
        orderBy: {
          storeName: "asc",
        },
      }),
      prisma.pharmacyStore.findMany({
        where: {
          isDeleted: false,
          items: {
            some: {
              isAvailable: true,
            },
          },
        },
        select: {
          id: true,
          storeName: true,
          deliveryFee: true,
          city: true,
          area: true,
          latitude: true,
          longitude: true,
          items: {
            where: {
              isAvailable: true,
            },
            orderBy: {
              name: "asc",
            },
            take: 3,
            select: {
              id: true,
              name: true,
              price: true,
              image: true,
              unit: true,
            },
          },
        },
        orderBy: {
          storeName: "asc",
        },
      }),
      prisma.grabMartStore.findMany({
        where: {
          isDeleted: false,
          items: {
            some: {
              isAvailable: true,
            },
          },
        },
        select: {
          id: true,
          storeName: true,
          deliveryFee: true,
          city: true,
          area: true,
          latitude: true,
          longitude: true,
          items: {
            where: {
              isAvailable: true,
            },
            orderBy: {
              name: "asc",
            },
            take: 3,
            select: {
              id: true,
              name: true,
              price: true,
              image: true,
              unit: true,
            },
          },
        },
        orderBy: {
          storeName: "asc",
        },
      }),
    ]);

  return { restaurants, groceryStores, pharmacyStores, grabMartStores };
}

let orderCounter = 0;

function buildOrderNumber(prefix) {
  orderCounter += 1;
  return `${prefix}-${Date.now()}-${String(orderCounter).padStart(5, "0")}`;
}

function buildSyntheticTimeline(seed) {
  const daysAgo = seededInt(seed, 2, 45);
  const minutesAfterOrder = seededInt(`${seed}:minutes`, 35, 110);
  const orderDate = new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000);
  orderDate.setUTCHours(seededInt(`${seed}:hour`, 9, 19), seededInt(`${seed}:minute`, 0, 59), 0, 0);
  const deliveredDate = new Date(orderDate.getTime() + minutesAfterOrder * 60 * 1000);
  return { orderDate, deliveredDate };
}

async function createDeliveredOrder({
  customerId,
  vendorType,
  vendor,
  item,
  seed,
  dryRun,
}) {
  const config = VENDOR_CONFIG[vendorType];
  const { orderDate, deliveredDate } = buildSyntheticTimeline(seed);
  const subtotal = roundToTwo(Number(item.price || 0));
  const deliveryFee = roundToTwo(Number(vendor.deliveryFee || 0));
  const totalAmount = roundToTwo(subtotal + deliveryFee);
  const orderNumber = buildOrderNumber(`RVW-${vendorType.toUpperCase()}`);

  if (dryRun) {
    return {
      id: `dry-run-${orderNumber}`,
      orderNumber,
      items: [{ id: `dry-run-item-${orderNumber}` }],
    };
  }

  return prisma.order.create({
    data: {
      orderNumber,
      orderType: config.orderType,
      customerId,
      [config.orderVendorField]: vendor.id,
      subtotal,
      deliveryFee,
      totalAmount,
      paymentMethod: "card",
      paymentProvider: "paystack",
      paymentStatus: "successful",
      status: "delivered",
      orderDate,
      deliveredDate,
      notes: `${ORDER_NOTE_MARKER} ${vendorType} ${vendor.id} ${item.id}`,
      deliveryStreet: "12 Review Seed Lane",
      deliveryCity: vendor.city || "Accra",
      deliveryState: vendor.area || "Greater Accra",
      deliveryLatitude: Number(vendor.latitude || 5.6037),
      deliveryLongitude: Number(vendor.longitude || -0.187),
      items: {
        create: [
          {
            itemType: config.itemTypeEnum,
            [config.orderItemField]: item.id,
            name: item.name,
            quantity: 1,
            price: subtotal,
            image: item[config.itemImageField] || null,
            unit: config.itemUnitField ? item[config.itemUnitField] || null : null,
          },
        ],
      },
    },
    select: {
      id: true,
      orderNumber: true,
      items: {
        select: {
          id: true,
        },
      },
    },
  });
}

async function createRestaurantReviewOrder({
  restaurant,
  food,
  customer,
  vendorSeed,
  itemSeed,
  createVendorReview,
  dryRun,
}) {
  const order = await createDeliveredOrder({
    customerId: customer.id,
    vendorType: "restaurant",
    vendor: restaurant,
    item: food,
    seed: itemSeed,
    dryRun,
  });

  if (dryRun) {
    return {
      orderCreated: 1,
      vendorReviewCreated: createVendorReview ? 1 : 0,
      itemReviewCreated: 1,
    };
  }

  try {
    await submitItemReviews({
      orderId: order.id,
      customerId: customer.id,
      reviews: [
        {
          orderItemId: order.items[0].id,
          ...buildItemReviewPayload({
            itemName: food.name,
            seed: itemSeed,
          }),
        },
      ],
      transactionOptions: SCRIPT_TRANSACTION_OPTIONS,
    });

    if (createVendorReview) {
      await submitVendorRating({
        orderId: order.id,
        customerId: customer.id,
        ...buildVendorReviewPayload({
          vendorName: restaurant.restaurantName,
          seed: vendorSeed,
        }),
        transactionOptions: SCRIPT_TRANSACTION_OPTIONS,
      });
    }

    return {
      orderCreated: 1,
      vendorReviewCreated: createVendorReview ? 1 : 0,
      itemReviewCreated: 1,
    };
  } catch (error) {
    await prisma.order.delete({ where: { id: order.id } }).catch(() => null);
    throw error;
  }
}

async function createVendorOnlyReviewOrder({
  vendorType,
  vendor,
  item,
  customer,
  vendorSeed,
  dryRun,
}) {
  const order = await createDeliveredOrder({
    customerId: customer.id,
    vendorType,
    vendor,
    item,
    seed: vendorSeed,
    dryRun,
  });

  if (dryRun) {
    return {
      orderCreated: 1,
      vendorReviewCreated: 1,
    };
  }

  try {
    const nameField = VENDOR_CONFIG[vendorType].nameField;
    await submitVendorRating({
      orderId: order.id,
      customerId: customer.id,
      ...buildVendorReviewPayload({
        vendorName: vendor[nameField],
        seed: vendorSeed,
      }),
      transactionOptions: SCRIPT_TRANSACTION_OPTIONS,
    });

    return {
      orderCreated: 1,
      vendorReviewCreated: 1,
    };
  } catch (error) {
    await prisma.order.delete({ where: { id: order.id } }).catch(() => null);
    throw error;
  }
}

function getNextSeedUser(seedUsers, index) {
  return seedUsers[index % seedUsers.length];
}

async function seedRestaurantTargets({
  restaurants,
  seedUsers,
  vendorCounts,
  foodCounts,
  vendorReviewsPerVendor,
  foodReviewsPerItem,
  dryRun,
}) {
  const summary = {
    vendorsProcessed: 0,
    foodItemsProcessed: 0,
    ordersCreated: 0,
    vendorReviewsCreated: 0,
    itemReviewsCreated: 0,
  };

  let reviewerIndex = 0;

  for (const restaurant of restaurants) {
    const foods = Array.isArray(restaurant.foods) ? restaurant.foods : [];
    if (foods.length === 0) continue;

    summary.vendorsProcessed += 1;

    let vendorCount = vendorCounts.get(restaurant.id) || 0;

    for (const food of foods) {
      summary.foodItemsProcessed += 1;

      let itemCount = foodCounts.get(food.id) || 0;
      while (itemCount < foodReviewsPerItem) {
        const customer = getNextSeedUser(seedUsers, reviewerIndex);
        const shouldAlsoReviewVendor = vendorCount < vendorReviewsPerVendor;
        const vendorSeed = `${restaurant.id}:vendor:${vendorCount}:${customer.id}`;
        const itemSeed = `${food.id}:item:${itemCount}:${customer.id}`;

        const result = await createRestaurantReviewOrder({
          restaurant,
          food,
          customer,
          vendorSeed,
          itemSeed,
          createVendorReview: shouldAlsoReviewVendor,
          dryRun,
        });

        reviewerIndex += 1;
        itemCount += 1;
        foodCounts.set(food.id, itemCount);
        summary.ordersCreated += result.orderCreated;
        summary.itemReviewsCreated += result.itemReviewCreated;

        if (shouldAlsoReviewVendor) {
          vendorCount += 1;
          vendorCounts.set(restaurant.id, vendorCount);
          summary.vendorReviewsCreated += result.vendorReviewCreated;
        }
      }
    }

    const fallbackItem = foods[0];
    while (vendorCount < vendorReviewsPerVendor && fallbackItem) {
      const customer = getNextSeedUser(seedUsers, reviewerIndex);
      const vendorSeed = `${restaurant.id}:vendor-only:${vendorCount}:${customer.id}`;

      const result = await createVendorOnlyReviewOrder({
        vendorType: "restaurant",
        vendor: restaurant,
        item: fallbackItem,
        customer,
        vendorSeed,
        dryRun,
      });

      reviewerIndex += 1;
      vendorCount += 1;
      vendorCounts.set(restaurant.id, vendorCount);
      summary.ordersCreated += result.orderCreated;
      summary.vendorReviewsCreated += result.vendorReviewCreated;
    }
  }

  return summary;
}

async function seedVendorOnlyTargets({
  vendorType,
  vendors,
  seedUsers,
  vendorCounts,
  vendorReviewsPerVendor,
  dryRun,
}) {
  const summary = {
    vendorsProcessed: 0,
    ordersCreated: 0,
    vendorReviewsCreated: 0,
    vendorsSkipped: 0,
  };

  let reviewerIndex = 0;
  const nameField = VENDOR_CONFIG[vendorType].nameField;

  for (const vendor of vendors) {
    const items = Array.isArray(vendor.items) ? vendor.items : [];
    if (items.length === 0) {
      summary.vendorsSkipped += 1;
      continue;
    }

    summary.vendorsProcessed += 1;
    let vendorCount = vendorCounts.get(vendor.id) || 0;

    while (vendorCount < vendorReviewsPerVendor) {
      const customer = getNextSeedUser(seedUsers, reviewerIndex);
      const item = items[vendorCount % items.length];
      const vendorSeed = `${vendorType}:${vendor.id}:${vendorCount}:${customer.id}:${vendor[nameField]}`;

      const result = await createVendorOnlyReviewOrder({
        vendorType,
        vendor,
        item,
        customer,
        vendorSeed,
        dryRun,
      });

      reviewerIndex += 1;
      vendorCount += 1;
      vendorCounts.set(vendor.id, vendorCount);
      summary.ordersCreated += result.orderCreated;
      summary.vendorReviewsCreated += result.vendorReviewCreated;
    }
  }

  return summary;
}

async function main() {
  if (!process.env.DATABASE_URL) {
    throw new Error(
      "DATABASE_URL is required. Load backend/.env or export DATABASE_URL before running this script."
    );
  }

  const options = parseArgs(process.argv.slice(2));
  const seedUsers = await ensureSeedUsers(options.seedUsers, {
    dryRun: options.dryRun,
  });
  const seedUserIds = seedUsers.map((user) => user.id);
  const existingCounts = await loadExistingSeedCounts(seedUserIds);
  const targets = await loadTargets();

  console.log("[seed-dummy-reviews] Starting seed run");
  console.log(
    `[seed-dummy-reviews] Mode: ${options.dryRun ? "dry-run" : "write"} | vendor reviews/vendor=${options.vendorReviewsPerVendor} | food reviews/item=${options.foodReviewsPerItem} | seed users=${seedUsers.length}`
  );

  const restaurantSummary = await seedRestaurantTargets({
    restaurants: targets.restaurants,
    seedUsers,
    vendorCounts: existingCounts.vendorCounts.restaurant,
    foodCounts: existingCounts.foodCounts,
    vendorReviewsPerVendor: options.vendorReviewsPerVendor,
    foodReviewsPerItem: options.foodReviewsPerItem,
    dryRun: options.dryRun,
  });

  const grocerySummary = await seedVendorOnlyTargets({
    vendorType: "grocery",
    vendors: targets.groceryStores,
    seedUsers,
    vendorCounts: existingCounts.vendorCounts.grocery,
    vendorReviewsPerVendor: options.vendorReviewsPerVendor,
    dryRun: options.dryRun,
  });

  const pharmacySummary = await seedVendorOnlyTargets({
    vendorType: "pharmacy",
    vendors: targets.pharmacyStores,
    seedUsers,
    vendorCounts: existingCounts.vendorCounts.pharmacy,
    vendorReviewsPerVendor: options.vendorReviewsPerVendor,
    dryRun: options.dryRun,
  });

  const grabmartSummary = await seedVendorOnlyTargets({
    vendorType: "grabmart",
    vendors: targets.grabMartStores,
    seedUsers,
    vendorCounts: existingCounts.vendorCounts.grabmart,
    vendorReviewsPerVendor: options.vendorReviewsPerVendor,
    dryRun: options.dryRun,
  });

  const totalOrders =
    restaurantSummary.ordersCreated +
    grocerySummary.ordersCreated +
    pharmacySummary.ordersCreated +
    grabmartSummary.ordersCreated;
  const totalVendorReviews =
    restaurantSummary.vendorReviewsCreated +
    grocerySummary.vendorReviewsCreated +
    pharmacySummary.vendorReviewsCreated +
    grabmartSummary.vendorReviewsCreated;

  console.log("[seed-dummy-reviews] Summary");
  console.log(
    `  - restaurants: ${restaurantSummary.vendorsProcessed} vendors, ${restaurantSummary.foodItemsProcessed} food items, ${restaurantSummary.vendorReviewsCreated} vendor reviews, ${restaurantSummary.itemReviewsCreated} item reviews`
  );
  console.log(
    `  - grocery stores: ${grocerySummary.vendorsProcessed} vendors, ${grocerySummary.vendorReviewsCreated} vendor reviews`
  );
  console.log(
    `  - pharmacy stores: ${pharmacySummary.vendorsProcessed} vendors, ${pharmacySummary.vendorReviewsCreated} vendor reviews`
  );
  console.log(
    `  - grabmart stores: ${grabmartSummary.vendorsProcessed} vendors, ${grabmartSummary.vendorReviewsCreated} vendor reviews`
  );
  console.log(`  - total synthetic orders created: ${totalOrders}`);
  console.log(`  - total vendor reviews created: ${totalVendorReviews}`);
  console.log(`  - total food item reviews created: ${restaurantSummary.itemReviewsCreated}`);
  console.log(
    `  - seed users reused: ${seedUsers.map((user) => user.username).join(", ")}`
  );
}

main()
  .catch((error) => {
    console.error("[seed-dummy-reviews] Failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
