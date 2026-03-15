const verboseSql = process.argv.includes("--verbose-sql");
const useLegacyTwemoji = process.argv.includes("--twemoji");

if (!verboseSql) {
  process.env.NODE_ENV = "production";
}

require("dotenv").config();
const prisma = require("../config/prisma");

const THUMBNAIL_BASE_URL = useLegacyTwemoji
  ? "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72"
  : "https://uwx.github.io/fluentui-twemoji-3d/export/3D_png/72x72";

const emojiAsset = (codePoint) => `${THUMBNAIL_BASE_URL}/${codePoint}.png`;

const CURATED_NAME_THUMBNAILS = {
  cookies: emojiAsset("1f36a"),
  "greek yogurt": emojiAsset("1f95b"),
  "olive oil": emojiAsset("1fad2"),
  "orange juice": emojiAsset("1f9c3"),
  "potato chips": emojiAsset("1f35f"),
};

const THUMBNAIL_RULES = [
  { pattern: /\b(grape|grapes)\b/i, url: emojiAsset("1f347") },
  { pattern: /\b(banana|bananas)\b/i, url: emojiAsset("1f34c") },
  { pattern: /\b(apple|apples)\b/i, url: emojiAsset("1f34e") },
  { pattern: /\b(orange|oranges)\b/i, url: emojiAsset("1f34a") },
  { pattern: /\b(tomato|tomatoes)\b/i, url: emojiAsset("1f345") },
  { pattern: /\b(carrot|carrots)\b/i, url: emojiAsset("1f955") },
  { pattern: /\b(lettuce|cabbage|leafy)\b/i, url: emojiAsset("1f96c") },
  { pattern: /\bmilk\b/i, url: emojiAsset("1f95b") },
  { pattern: /\b(cheese|cheddar)\b/i, url: emojiAsset("1f9c0") },
  { pattern: /\b(egg|eggs)\b/i, url: emojiAsset("1f95a") },
  { pattern: /\bbread\b/i, url: emojiAsset("1f35e") },
  { pattern: /\b(croissant|croissants)\b/i, url: emojiAsset("1f950") },
  { pattern: /\b(bagel|bagels)\b/i, url: emojiAsset("1f96f") },
  { pattern: /\bchicken\b/i, url: emojiAsset("1f357") },
  { pattern: /\b(salmon|fish|fillet|seafood)\b/i, url: emojiAsset("1f41f") },
  { pattern: /\b(beef|steak|meat)\b/i, url: emojiAsset("1f969") },
  { pattern: /\brice\b/i, url: emojiAsset("1f35a") },
  { pattern: /\b(pasta|spaghetti|noodle)\b/i, url: emojiAsset("1f35d") },
  { pattern: /\b(chocolate|cocoa)\b/i, url: emojiAsset("1f36b") },
  { pattern: /\bjuice\b/i, url: emojiAsset("1f9c3") },
  { pattern: /\bwater\b/i, url: emojiAsset("1f4a7") },
  { pattern: /\bcoffee\b/i, url: emojiAsset("2615") },
  { pattern: /\b(shampoo|lotion)\b/i, url: emojiAsset("1f9f4") },
  { pattern: /\bsoap\b/i, url: emojiAsset("1f9fc") },
  { pattern: /\b(toothpaste|toothbrush)\b/i, url: emojiAsset("1faa5") },
];

function normalizeName(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function resolveThumbnailImage(item, fallbackToExistingImage) {
  const normalizedName = normalizeName(item.name);
  const curatedThumbnail = CURATED_NAME_THUMBNAILS[normalizedName];

  if (curatedThumbnail) {
    return {
      thumbnailImage: curatedThumbnail,
      matchedRule: `exact:${normalizedName}`,
      source: "curated_name",
    };
  }

  const searchText = [item.name, item.brand].filter(Boolean).join(" ");

  for (const rule of THUMBNAIL_RULES) {
    if (rule.pattern.test(searchText)) {
      return {
        thumbnailImage: rule.url,
        matchedRule: rule.pattern.toString(),
        source: "starter_catalog",
      };
    }
  }

  if (fallbackToExistingImage && item.image) {
    return {
      thumbnailImage: item.image,
      matchedRule: "existing-image",
      source: "existing_image_fallback",
    };
  }

  return {
    thumbnailImage: null,
    matchedRule: null,
    source: "no_match",
  };
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const overwrite = process.argv.includes("--overwrite");
  const fallbackToExistingImage = process.argv.includes("--fallback-to-image");

  console.log(
    `[grocery-thumbnails] Starting ${
      dryRun ? "dry-run" : "write"
    } update (overwrite=${overwrite}, fallbackToImage=${fallbackToExistingImage}, source=${
      useLegacyTwemoji ? "twemoji" : "fluent3d"
    })`
  );

  const items = await prisma.groceryItem.findMany({
    select: {
      id: true,
      name: true,
      brand: true,
      image: true,
      thumbnailImage: true,
    },
    orderBy: { name: "asc" },
  });

  let updated = 0;
  let starterCatalogMatches = 0;
  let existingImageFallbacks = 0;
  let curatedNameMatches = 0;
  let alreadyPopulated = 0;
  let unmatched = 0;
  const unmatchedItems = [];

  for (const item of items) {
    if (!overwrite && item.thumbnailImage) {
      alreadyPopulated += 1;
      continue;
    }

    const resolution = resolveThumbnailImage(item, fallbackToExistingImage);

    if (!resolution.thumbnailImage) {
      unmatched += 1;
      unmatchedItems.push({
        name: item.name,
        brand: item.brand,
      });
      continue;
    }

    if (resolution.source === "curated_name") {
      curatedNameMatches += 1;
    } else if (resolution.source === "starter_catalog") {
      starterCatalogMatches += 1;
    } else if (resolution.source === "existing_image_fallback") {
      existingImageFallbacks += 1;
    }

    updated += 1;

    if (!dryRun) {
      await prisma.groceryItem.update({
        where: { id: item.id },
        data: {
          thumbnailImage: resolution.thumbnailImage,
        },
      });
    }
  }

  console.log("[grocery-thumbnails] Summary:");
  console.log(`  - total items: ${items.length}`);
  console.log(`  - updated: ${updated}`);
  console.log(`  - curated exact-name matches: ${curatedNameMatches}`);
  console.log(`  - starter catalog matches: ${starterCatalogMatches}`);
  console.log(`  - fallback to existing image: ${existingImageFallbacks}`);
  console.log(`  - already populated: ${alreadyPopulated}`);
  console.log(`  - unmatched: ${unmatched}`);

  if (unmatchedItems.length > 0) {
    console.log("  - unmatched item names:");
    for (const unmatchedItem of unmatchedItems) {
      const brandLabel = unmatchedItem.brand ? ` (${unmatchedItem.brand})` : "";
      console.log(`    * ${unmatchedItem.name}${brandLabel}`);
    }
  }

  if (!fallbackToExistingImage) {
    console.log(
      "  - note: use --fallback-to-image if you want every unmatched item to copy its current image into thumbnailImage"
    );
  }
}

main()
  .catch((error) => {
    console.error("[grocery-thumbnails] Failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
