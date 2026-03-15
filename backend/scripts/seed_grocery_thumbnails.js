const verboseSql = process.argv.includes("--verbose-sql");
const useLegacyTwemoji = process.argv.includes("--twemoji");
const useEmojiCatalog = process.argv.includes("--emoji") || useLegacyTwemoji;
const useOpenFoodFacts = process.argv.includes("--open-food-facts");

if (!verboseSql) {
  process.env.NODE_ENV = "production";
}

require("dotenv").config();
const prisma = require("../config/prisma");

const THUMBNAIL_BASE_URL = useLegacyTwemoji
  ? "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72"
  : "https://uwx.github.io/fluentui-twemoji-3d/export/3D_png/72x72";
const OPEN_FOOD_FACTS_SEARCH_URL = "https://world.openfoodfacts.org/cgi/search.pl";
const DUMMYJSON_IMAGE_BASE_URL = "https://cdn.dummyjson.com/product-images";
const OPEN_FOOD_FACTS_TIMEOUT_MS = 8000;
const CURATED_BAKERY_PACKSHOT_URL =
  "https://images.openfoodfacts.org/images/products/841/008/701/2018/front_fr.25.400.jpg";

const emojiAsset = (codePoint) => `${THUMBNAIL_BASE_URL}/${codePoint}.png`;
const dummyThumbnail = (category, slug) =>
  `${DUMMYJSON_IMAGE_BASE_URL}/${category}/${slug}/thumbnail.webp`;

const OPEN_FOOD_FACTS_QUERY_OVERRIDES = {
  "dark chocolate slab": "dark chocolate",
  "mature cheddar block": "cheddar cheese",
  "penne rigate pasta": "penne pasta",
  "premium basmati rice": "basmati rice",
  "chopped tomatoes tin": "canned tomatoes",
  "butter croissants": "croissant",
  "honeycrisp apples": "apple",
  "atlantic salmon portions": "salmon fillet",
  "market bananas": "banana",
  "greek yogurt cup": "greek yogurt",
  "cold-pressed orange juice": "orange juice",
  "full cream milk": "whole milk",
  "sweet carrots": "carrot",
  "soft white bread": "white bread",
  "baby spinach": "spinach",
  "free-range eggs": "eggs",
  "heirloom tomatoes": "tomatoes",
  "medium roast coffee beans": "coffee",
  "botanical hand soap": "hand soap",
  "extra virgin olive oil": "olive oil",
  "boneless chicken breast": "chicken breast",
  "lean ground beef": "ground beef",
  "stoneground wheat loaf": "whole wheat bread",
  "blueberry bagels": "bagels",
  "sparkling mineral water": "sparkling water",
  "sea salt potato chips": "potato chips",
  "repair & shine shampoo": "shampoo",
  "butter cookies pack": "butter cookies",
  "fresh mint toothpaste": "toothpaste",
  "apple sparkling juice": "apple juice",
  "coconut water bottle": "coconut water",
  "hass avocados": "avocado",
  "organic whole milk": "whole milk",
};

const CURATED_PACKSHOT_THUMBNAILS = {
  "butter croissants": CURATED_BAKERY_PACKSHOT_URL,
  "blueberry bagels": CURATED_BAKERY_PACKSHOT_URL,
  "stoneground wheat loaf": CURATED_BAKERY_PACKSHOT_URL,
  "mature cheddar block": dummyThumbnail("groceries", "milk"),
  "free-range eggs": dummyThumbnail("groceries", "eggs"),
  "sweet carrots": dummyThumbnail("groceries", "green-bell-pepper"),
};

const DUMMYJSON_FALLBACK_RULES = [
  { pattern: /\b(apple|apples)\b/i, url: dummyThumbnail("groceries", "apple") },
  { pattern: /\b(banana|bananas)\b/i, url: dummyThumbnail("groceries", "kiwi") },
  { pattern: /\b(avocado|avocados)\b/i, url: dummyThumbnail("groceries", "kiwi") },
  { pattern: /\b(strawberry|berry|berries)\b/i, url: dummyThumbnail("groceries", "strawberry") },
  { pattern: /\b(orange juice|apple juice|juice)\b/i, url: dummyThumbnail("groceries", "juice") },
  { pattern: /\b(water)\b/i, url: dummyThumbnail("groceries", "water") },
  { pattern: /\b(coffee)\b/i, url: dummyThumbnail("groceries", "nescafe-coffee") },
  { pattern: /\b(chicken)\b/i, url: dummyThumbnail("groceries", "chicken-meat") },
  { pattern: /\b(beef)\b/i, url: dummyThumbnail("groceries", "beef-steak") },
  { pattern: /\b(salmon|fish|seafood)\b/i, url: dummyThumbnail("groceries", "fish-steak") },
  { pattern: /\b(olive oil|cooking oil|oil)\b/i, url: dummyThumbnail("groceries", "cooking-oil") },
  { pattern: /\b(croissant|croissants|bagel|bagels)\b/i, url: dummyThumbnail("groceries", "ice-cream") },
  { pattern: /\b(bread|loaf|rice|pasta)\b/i, url: dummyThumbnail("groceries", "rice") },
  { pattern: /\b(egg|eggs)\b/i, url: dummyThumbnail("groceries", "eggs") },
  { pattern: /\b(milk|yogurt|cheese|cheddar)\b/i, url: dummyThumbnail("groceries", "milk") },
  { pattern: /\b(spinach|lettuce|cucumber|pepper|tomato|tomatoes|carrot|carrots|potato|potatoes)\b/i, url: dummyThumbnail("groceries", "green-bell-pepper") },
  { pattern: /\b(chips)\b/i, url: dummyThumbnail("groceries", "potatoes") },
  { pattern: /\b(cookie|cookies|chocolate)\b/i, url: dummyThumbnail("groceries", "honey-jar") },
  { pattern: /\b(soap)\b/i, url: dummyThumbnail("skin-care", "attitude-super-leaves-hand-soap") },
  { pattern: /\b(shampoo|body wash)\b/i, url: dummyThumbnail("skin-care", "olay-ultra-moisture-shea-butter-body-wash") },
  { pattern: /\b(toothpaste)\b/i, url: dummyThumbnail("skin-care", "vaseline-men-body-and-face-lotion") },
];

const CURATED_EMOJI_THUMBNAILS = {
  cookies: emojiAsset("1f36a"),
  "greek yogurt": emojiAsset("1f95b"),
  "olive oil": emojiAsset("1fad2"),
  "orange juice": emojiAsset("1f9c3"),
  "potato chips": emojiAsset("1f35f"),
};

const EMOJI_RULES = [
  { pattern: /\b(grape|grapes)\b/i, url: emojiAsset("1f347") },
  { pattern: /\b(banana|bananas)\b/i, url: emojiAsset("1f34c") },
  { pattern: /\b(apple|apples)\b/i, url: emojiAsset("1f34e") },
  { pattern: /\b(orange|oranges)\b/i, url: emojiAsset("1f34a") },
  { pattern: /\b(tomato|tomatoes)\b/i, url: emojiAsset("1f345") },
  { pattern: /\b(carrot|carrots)\b/i, url: emojiAsset("1f955") },
  { pattern: /\b(lettuce|cabbage|leafy|spinach)\b/i, url: emojiAsset("1f96c") },
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

const offSearchCache = new Map();

function normalizeName(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

async function searchOpenFoodFacts(searchTerm) {
  const normalizedSearchTerm = normalizeName(searchTerm);

  if (!normalizedSearchTerm) {
    return null;
  }

  if (offSearchCache.has(normalizedSearchTerm)) {
    return offSearchCache.get(normalizedSearchTerm);
  }

  const url = new URL(OPEN_FOOD_FACTS_SEARCH_URL);
  url.search = new URLSearchParams({
    search_terms: normalizedSearchTerm,
    search_simple: "1",
    action: "process",
    json: "1",
    page_size: "8",
    fields: "product_name,image_front_url,image_front_thumb_url,image_url,image_thumb_url",
  }).toString();

  const response = await fetch(url, {
    headers: {
      "User-Agent": "GrabGo Grocery Thumbnail Seeder/1.0",
    },
    signal: AbortSignal.timeout(OPEN_FOOD_FACTS_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw new Error(`Open Food Facts search failed with status ${response.status}`);
  }

  const payload = await response.json();
  const products = Array.isArray(payload.products) ? payload.products : [];
  const match = products.find(
    (product) =>
      product?.image_front_url || product?.image_url || product?.image_front_thumb_url || product?.image_thumb_url
  );

  const resolved = match
    ? {
        thumbnailImage:
          match.image_front_url || match.image_url || match.image_front_thumb_url || match.image_thumb_url,
        matchedRule: `off:${normalizedSearchTerm}`,
        source: "open_food_facts",
      }
    : null;

  offSearchCache.set(normalizedSearchTerm, resolved);
  return resolved;
}

function resolveEmojiThumbnail(item, fallbackToExistingImage) {
  const normalizedName = normalizeName(item.name);
  const curatedThumbnail = CURATED_EMOJI_THUMBNAILS[normalizedName];

  if (curatedThumbnail) {
    return {
      thumbnailImage: curatedThumbnail,
      matchedRule: `emoji:${normalizedName}`,
      source: "emoji_curated",
    };
  }

  const searchText = [item.name, item.brand].filter(Boolean).join(" ");

  for (const rule of EMOJI_RULES) {
    if (rule.pattern.test(searchText)) {
      return {
        thumbnailImage: rule.url,
        matchedRule: rule.pattern.toString(),
        source: "emoji_rule",
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

async function resolveRealPackshotThumbnail(item, fallbackToExistingImage) {
  const normalizedName = normalizeName(item.name);
  const curatedPackshot = CURATED_PACKSHOT_THUMBNAILS[normalizedName];

  if (curatedPackshot) {
    return {
      thumbnailImage: curatedPackshot,
      matchedRule: `packshot:${normalizedName}`,
      source: "curated_packshot",
    };
  }

  if (useOpenFoodFacts) {
    const searchTerm = OPEN_FOOD_FACTS_QUERY_OVERRIDES[normalizedName] || normalizedName;

    try {
      const openFoodFactsMatch = await searchOpenFoodFacts(searchTerm);
      if (openFoodFactsMatch?.thumbnailImage) {
        return openFoodFactsMatch;
      }
    } catch (error) {
      if (verboseSql) {
        console.warn(`[grocery-thumbnails] Open Food Facts lookup failed for "${item.name}": ${error.message}`);
      }
    }
  }

  const searchText = [item.name, item.brand].filter(Boolean).join(" ");
  for (const rule of DUMMYJSON_FALLBACK_RULES) {
    if (rule.pattern.test(searchText)) {
      return {
        thumbnailImage: rule.url,
        matchedRule: `dummyjson:${rule.pattern}`,
        source: "dummyjson_fallback",
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

async function resolveThumbnailImage(item, fallbackToExistingImage) {
  if (useEmojiCatalog) {
    return resolveEmojiThumbnail(item, fallbackToExistingImage);
  }

  return resolveRealPackshotThumbnail(item, fallbackToExistingImage);
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const overwrite = process.argv.includes("--overwrite");
  const fallbackToExistingImage = process.argv.includes("--fallback-to-image");
  const sourceLabel = useEmojiCatalog
    ? useLegacyTwemoji
      ? "twemoji"
      : "fluent3d"
    : useOpenFoodFacts
    ? "real-packshots+off"
    : "real-packshot-catalog";

  console.log(
    `[grocery-thumbnails] Starting ${
      dryRun ? "dry-run" : "write"
    } update (overwrite=${overwrite}, fallbackToImage=${fallbackToExistingImage}, source=${sourceLabel})`
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
  let openFoodFactsMatches = 0;
  let dummyjsonFallbacks = 0;
  let curatedPackshots = 0;
  let emojiMatches = 0;
  let existingImageFallbacks = 0;
  let alreadyPopulated = 0;
  let unmatched = 0;
  const unmatchedItems = [];

  for (let index = 0; index < items.length; index += 1) {
    const item = items[index];

    if (!overwrite && item.thumbnailImage) {
      alreadyPopulated += 1;
      continue;
    }

    const resolution = await resolveThumbnailImage(item, fallbackToExistingImage);

    if (!resolution.thumbnailImage) {
      unmatched += 1;
      unmatchedItems.push({
        name: item.name,
        brand: item.brand,
      });
      continue;
    }

    if (resolution.source === "open_food_facts") {
      openFoodFactsMatches += 1;
    } else if (resolution.source === "curated_packshot") {
      curatedPackshots += 1;
    } else if (resolution.source === "dummyjson_fallback") {
      dummyjsonFallbacks += 1;
    } else if (resolution.source === "emoji_curated" || resolution.source === "emoji_rule") {
      emojiMatches += 1;
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

    if (!useEmojiCatalog && ((index + 1) % 5 === 0 || index + 1 === items.length)) {
      console.log(`  - processed ${index + 1}/${items.length}`);
    }
  }

  console.log("[grocery-thumbnails] Summary:");
  console.log(`  - total items: ${items.length}`);
  console.log(`  - updated: ${updated}`);
  console.log(`  - curated packshots: ${curatedPackshots}`);
  console.log(`  - Open Food Facts packshots: ${openFoodFactsMatches}`);
  console.log(`  - DummyJSON fallbacks: ${dummyjsonFallbacks}`);
  console.log(`  - emoji matches: ${emojiMatches}`);
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

  if (!useEmojiCatalog) {
    console.log("  - note: use --open-food-facts if you want to attempt slower external front-image lookups");
    console.log("  - note: use --emoji or --twemoji to restore the old icon-based thumbnails");
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
