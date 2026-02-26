require("dotenv").config();
const prisma = require("../config/prisma");

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function hashString(input) {
  let hash = 0;
  for (let i = 0; i < input.length; i += 1) {
    hash = (hash * 31 + input.charCodeAt(i)) >>> 0;
  }
  return hash;
}

function seededInt(seed, min, max) {
  if (max <= min) return min;
  const range = max - min + 1;
  return min + (hashString(seed) % range);
}

function inferReviewCount({ id, orderCount, min = 8, max = 500 }) {
  const safeOrders = Math.max(0, Number(orderCount) || 0);
  const base = Math.round(safeOrders * 0.35);
  const jitter = seededInt(`${id}:jitter`, 0, 18);
  if (base > 0) return clamp(base + jitter, min, max);
  return seededInt(`${id}:fallback`, min, Math.min(max, 120));
}

function normalizeCount(...values) {
  for (const value of values) {
    const parsed = Number(value);
    if (Number.isFinite(parsed) && parsed > 0) {
      return Math.floor(parsed);
    }
  }
  return 0;
}

function round2(value) {
  return Math.round(value * 100) / 100;
}

async function seedRestaurants(dryRun = false) {
  const rows = await prisma.restaurant.findMany({
    select: {
      id: true,
      rating: true,
      ratingCount: true,
      totalReviews: true,
      ratingSum: true,
      totalOrders: true,
      monthlyOrders: true,
    },
  });

  let updated = 0;
  for (const row of rows) {
    const currentCount = normalizeCount(row.totalReviews, row.ratingCount);
    const seededCount =
      currentCount > 0
        ? currentCount
        : row.rating > 0
        ? inferReviewCount({
            id: row.id,
            orderCount: Math.max(row.totalOrders || 0, row.monthlyOrders || 0),
            min: 10,
            max: 1200,
          })
        : 0;

    const ratingSum =
      seededCount > 0 && row.rating > 0
        ? row.ratingSum > 0
          ? round2(row.ratingSum)
          : round2(row.rating * seededCount)
        : 0;

    const needsUpdate =
      row.ratingCount !== seededCount ||
      row.totalReviews !== seededCount ||
      round2(row.ratingSum || 0) !== ratingSum;

    if (!needsUpdate) continue;
    updated += 1;

    if (!dryRun) {
      await prisma.restaurant.update({
        where: { id: row.id },
        data: {
          ratingCount: seededCount,
          totalReviews: seededCount,
          ratingSum,
        },
      });
    }
  }

  return { total: rows.length, updated };
}

async function seedStores(model, options = {}, dryRun = false) {
  const rows = await prisma[model].findMany({
    select: {
      id: true,
      rating: true,
      ratingCount: true,
      totalReviews: true,
      ratingSum: true,
      totalOrders: true,
      monthlyOrders: true,
    },
  });

  let updated = 0;
  for (const row of rows) {
    const currentCount = normalizeCount(row.totalReviews, row.ratingCount);
    const seededCount =
      currentCount > 0
        ? currentCount
        : row.rating > 0
        ? inferReviewCount({
            id: row.id,
            orderCount: Math.max(row.totalOrders || 0, row.monthlyOrders || 0),
            min: options.minCount || 10,
            max: options.maxCount || 900,
          })
        : 0;

    const ratingSum =
      seededCount > 0 && row.rating > 0
        ? row.ratingSum > 0
          ? round2(row.ratingSum)
          : round2(row.rating * seededCount)
        : 0;

    const needsUpdate =
      row.ratingCount !== seededCount ||
      row.totalReviews !== seededCount ||
      round2(row.ratingSum || 0) !== ratingSum;

    if (!needsUpdate) continue;
    updated += 1;

    if (!dryRun) {
      await prisma[model].update({
        where: { id: row.id },
        data: {
          ratingCount: seededCount,
          totalReviews: seededCount,
          ratingSum,
        },
      });
    }
  }

  return { total: rows.length, updated };
}

async function seedItems(model, countField, dryRun = false) {
  const rows = await prisma[model].findMany({
    select: {
      id: true,
      rating: true,
      orderCount: true,
      [countField]: true,
    },
  });

  let updated = 0;
  for (const row of rows) {
    const currentCount = normalizeCount(row[countField]);
    const seededCount =
      currentCount > 0
        ? currentCount
        : row.rating > 0
        ? inferReviewCount({
            id: row.id,
            orderCount: row.orderCount || 0,
            min: 6,
            max: 600,
          })
        : 0;

    if (seededCount === currentCount) continue;
    updated += 1;

    if (!dryRun) {
      await prisma[model].update({
        where: { id: row.id },
        data: { [countField]: seededCount },
      });
    }
  }

  return { total: rows.length, updated };
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  console.log(
    `[rating-metrics] Starting ${dryRun ? "dry-run" : "write"} backfill...`
  );

  const restaurant = await seedRestaurants(dryRun);
  const groceryStore = await seedStores("groceryStore", {}, dryRun);
  const pharmacyStore = await seedStores("pharmacyStore", {}, dryRun);
  const grabMartStore = await seedStores("grabMartStore", {}, dryRun);

  const food = await seedItems("food", "totalReviews", dryRun);
  const groceryItem = await seedItems("groceryItem", "reviewCount", dryRun);
  const pharmacyItem = await seedItems("pharmacyItem", "reviewCount", dryRun);
  const grabMartItem = await seedItems("grabMartItem", "reviewCount", dryRun);

  const summary = {
    restaurant,
    groceryStore,
    pharmacyStore,
    grabMartStore,
    food,
    groceryItem,
    pharmacyItem,
    grabMartItem,
  };

  console.log("[rating-metrics] Summary:");
  for (const [name, stat] of Object.entries(summary)) {
    console.log(`  - ${name}: ${stat.updated}/${stat.total} updated`);
  }
}

main()
  .catch((error) => {
    console.error("[rating-metrics] Failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
