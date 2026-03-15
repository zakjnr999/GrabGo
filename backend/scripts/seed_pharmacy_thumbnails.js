const verboseSql = process.argv.includes("--verbose-sql");

if (!verboseSql) {
  process.env.NODE_ENV = "production";
}

require("dotenv").config();
const prisma = require("../config/prisma");

const DUMMYJSON_IMAGE_BASE_URL = "https://cdn.dummyjson.com/product-images";
const dummyThumbnail = (category, slug) =>
  `${DUMMYJSON_IMAGE_BASE_URL}/${category}/${slug}/thumbnail.webp`;

const PACKSHOT_LIBRARY = {
  supplementBottle: dummyThumbnail("groceries", "honey-jar"),
  milkBottle: dummyThumbnail("groceries", "milk"),
  waterBottle: dummyThumbnail("groceries", "water"),
  juiceBottle: dummyThumbnail("groceries", "juice"),
  handSoap: dummyThumbnail(
    "skin-care",
    "attitude-super-leaves-hand-soap",
  ),
  bodyWash: dummyThumbnail(
    "skin-care",
    "olay-ultra-moisture-shea-butter-body-wash",
  ),
  lotion: dummyThumbnail("skin-care", "vaseline-men-body-and-face-lotion"),
  medicines:
    "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800",
  antiInflammatory:
    "https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800",
  coughBottle:
    "https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=800",
  firstAid:
    "https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=800",
  babyCare:
    "https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=800",
  babyWipes:
    "https://images.unsplash.com/photo-1522771930-78848d9293e8?w=800",
  devices:
    "https://images.unsplash.com/photo-1550572017-4a6e8c4f8f7f?w=800",
  sunscreen:
    "https://images.unsplash.com/photo-1571875257727-256c39da42af?w=800",
  moisturizer:
    "https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=800",
};

const CATEGORY_IMAGE_RULES = [
  {
    pattern: /\bmedicines?\b/i,
    url: PACKSHOT_LIBRARY.medicines,
    source: "real_category",
  },
  {
    pattern: /\bwellness|supplements?|vitamins?\b/i,
    url: PACKSHOT_LIBRARY.coughBottle,
    source: "real_category",
  },
  {
    pattern: /\bpersonal care|skin care|hygiene\b/i,
    url: PACKSHOT_LIBRARY.lotion,
    source: "packshot_category",
  },
  {
    pattern: /\bfirst aid\b/i,
    url: PACKSHOT_LIBRARY.firstAid,
    source: "real_category",
  },
  {
    pattern: /\bbaby care|baby\b/i,
    url: PACKSHOT_LIBRARY.babyCare,
    source: "real_category",
  },
  {
    pattern: /\bhealth devices?|medical devices?\b/i,
    url: PACKSHOT_LIBRARY.devices,
    source: "real_category",
  },
];

const EXACT_ITEM_THUMBNAILS = {
  "paracetamol 500mg": PACKSHOT_LIBRARY.medicines,
  "ibuprofen 400mg": PACKSHOT_LIBRARY.antiInflammatory,
  "antibiotic amoxicillin": PACKSHOT_LIBRARY.devices,
  "cough syrup": PACKSHOT_LIBRARY.coughBottle,
  "vitamin c 1000mg": PACKSHOT_LIBRARY.medicines,
  "multivitamin complex": PACKSHOT_LIBRARY.devices,
  "omega-3 fish oil": PACKSHOT_LIBRARY.coughBottle,
  "hand sanitizer 500ml": PACKSHOT_LIBRARY.handSoap,
  "moisturizing lotion": PACKSHOT_LIBRARY.moisturizer,
  "sunscreen spf 50": PACKSHOT_LIBRARY.sunscreen,
  "adhesive bandages": PACKSHOT_LIBRARY.firstAid,
  "antiseptic solution": PACKSHOT_LIBRARY.handSoap,
  "first aid kit": PACKSHOT_LIBRARY.firstAid,
  "baby diapers size 3": PACKSHOT_LIBRARY.babyCare,
  "baby wipes": PACKSHOT_LIBRARY.babyWipes,
  "baby formula milk": PACKSHOT_LIBRARY.milkBottle,
  "digital thermometer": PACKSHOT_LIBRARY.medicines,
  "blood pressure monitor": PACKSHOT_LIBRARY.devices,
  "pulse oximeter": PACKSHOT_LIBRARY.coughBottle,
};

const ITEM_RULES = [
  {
    pattern:
      /\b(paracetamol|ibuprofen|amoxicillin|antibiotic|tablet|tablets|capsule|capsules|pill|pills|medicine|medication)\b/i,
    url: PACKSHOT_LIBRARY.medicines,
    source: "real_medicine",
  },
  {
    pattern: /\b(cough|syrup|tonic|mouthwash)\b/i,
    url: PACKSHOT_LIBRARY.coughBottle,
    source: "real_liquid",
  },
  {
    pattern: /\b(vitamin|multivitamin|supplement|omega|fish oil|zinc)\b/i,
    url: PACKSHOT_LIBRARY.supplementBottle,
    source: "packshot_supplement",
  },
  {
    pattern: /\b(sanitizer|antiseptic|disinfect|soap|wash)\b/i,
    url: PACKSHOT_LIBRARY.handSoap,
    source: "packshot_handsoap",
  },
  {
    pattern: /\b(lotion|cream|moisturizer|sunscreen|ointment|vaseline)\b/i,
    url: PACKSHOT_LIBRARY.lotion,
    source: "packshot_lotion",
  },
  {
    pattern: /\b(shampoo|conditioner|body wash)\b/i,
    url: PACKSHOT_LIBRARY.bodyWash,
    source: "packshot_bodywash",
  },
  {
    pattern: /\b(toothpaste|toothbrush|oral)\b/i,
    url: PACKSHOT_LIBRARY.lotion,
    source: "packshot_oralcare",
  },
  {
    pattern: /\b(bandage|bandages|band aid|band-aid|gauze|plaster|first aid)\b/i,
    url: PACKSHOT_LIBRARY.firstAid,
    source: "real_firstaid",
  },
  {
    pattern: /\b(diaper|diapers|wipes|formula|baby)\b/i,
    url: PACKSHOT_LIBRARY.babyCare,
    source: "real_baby",
  },
  {
    pattern: /\b(thermometer|oximeter|monitor|blood pressure|bp monitor|device)\b/i,
    url: PACKSHOT_LIBRARY.devices,
    source: "real_device",
  },
];

function normalizeName(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function resolveCategoryImage(category) {
  const normalizedName = normalizeName(category.name);

  for (const rule of CATEGORY_IMAGE_RULES) {
    if (rule.pattern.test(normalizedName)) {
      return {
        image: rule.url,
        source: rule.source,
      };
    }
  }

  return {
    image: null,
    source: "no_match",
  };
}

function resolveItemThumbnail(item) {
  const normalizedName = normalizeName(item.name);
  const exactMatch = EXACT_ITEM_THUMBNAILS[normalizedName];

  if (exactMatch) {
    return {
      thumbnailImage: exactMatch,
      source: "exact_match",
    };
  }

  const searchText = [item.name, item.brand, item.categoryName]
    .filter(Boolean)
    .join(" ");

  for (const rule of ITEM_RULES) {
    if (rule.pattern.test(searchText)) {
      return {
        thumbnailImage: rule.url,
        source: rule.source,
      };
    }
  }

  const existingImage = String(item.image || "").trim();
  if (existingImage.length > 0) {
    return {
      thumbnailImage: existingImage,
      source: "existing_image",
    };
  }

  return {
    thumbnailImage: null,
    source: "no_match",
  };
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const overwrite = process.argv.includes("--overwrite");
  const itemsOnly = process.argv.includes("--items-only");
  const categoriesOnly = process.argv.includes("--categories-only");

  console.log(
    `[pharmacy-thumbnails] Starting ${
      dryRun ? "dry-run" : "write"
    } update (overwrite=${overwrite}, itemsOnly=${itemsOnly}, categoriesOnly=${categoriesOnly})`,
  );

  let updatedItems = 0;
  let updatedCategories = 0;
  let exactMatches = 0;
  let packshotMatches = 0;
  let realPhotoMatches = 0;
  let existingImageFallbacks = 0;
  let alreadyPopulatedItems = 0;
  let alreadyStyledCategories = 0;
  let unmatchedItems = 0;
  let unmatchedCategories = 0;
  const unmatchedItemNames = [];
  const unmatchedCategoryNames = [];

  if (!categoriesOnly) {
    const items = await prisma.pharmacyItem.findMany({
      select: {
        id: true,
        name: true,
        brand: true,
        image: true,
        thumbnailImage: true,
        category: {
          select: {
            name: true,
          },
        },
      },
      orderBy: { name: "asc" },
    });

    for (const item of items) {
      const resolution = resolveItemThumbnail({
        name: item.name,
        brand: item.brand,
        categoryName: item.category?.name,
      });

      if (!resolution.thumbnailImage) {
        unmatchedItems += 1;
        unmatchedItemNames.push(item.name);
        continue;
      }

      if (
        !overwrite &&
        item.thumbnailImage &&
        item.thumbnailImage === resolution.thumbnailImage
      ) {
        alreadyPopulatedItems += 1;
        continue;
      }

      updatedItems += 1;
      if (resolution.source === "exact_match") {
        exactMatches += 1;
      } else if (resolution.source.startsWith("packshot")) {
        packshotMatches += 1;
      } else if (resolution.source === "existing_image") {
        existingImageFallbacks += 1;
      } else if (resolution.source.startsWith("real_")) {
        realPhotoMatches += 1;
      }

      if (!dryRun) {
        await prisma.pharmacyItem.update({
          where: { id: item.id },
          data: {
            thumbnailImage: resolution.thumbnailImage,
          },
        });
      }
    }
  }

  if (!itemsOnly) {
    const categories = await prisma.pharmacyCategory.findMany({
      select: {
        id: true,
        name: true,
        image: true,
      },
      orderBy: { sortOrder: "asc" },
    });

    for (const category of categories) {
      const resolution = resolveCategoryImage(category);

      if (!resolution.image) {
        unmatchedCategories += 1;
        unmatchedCategoryNames.push(category.name);
        continue;
      }

      if (!overwrite && category.image === resolution.image) {
        alreadyStyledCategories += 1;
        continue;
      }

      updatedCategories += 1;

      if (!dryRun) {
        await prisma.pharmacyCategory.update({
          where: { id: category.id },
          data: {
            image: resolution.image,
          },
        });
      }
    }
  }

  console.log("[pharmacy-thumbnails] Summary:");
  console.log(`  - items updated: ${updatedItems}`);
  console.log(`  - categories updated: ${updatedCategories}`);
  console.log(`  - exact item matches: ${exactMatches}`);
  console.log(`  - packshot item matches: ${packshotMatches}`);
  console.log(`  - real photo item matches: ${realPhotoMatches}`);
  console.log(`  - existing image fallbacks: ${existingImageFallbacks}`);
  console.log(`  - already populated items: ${alreadyPopulatedItems}`);
  console.log(`  - already styled categories: ${alreadyStyledCategories}`);
  console.log(`  - unmatched items: ${unmatchedItems}`);
  console.log(`  - unmatched categories: ${unmatchedCategories}`);

  if (unmatchedItemNames.length > 0) {
    console.log("  - unmatched item names:");
    for (const itemName of unmatchedItemNames) {
      console.log(`    * ${itemName}`);
    }
  }

  if (unmatchedCategoryNames.length > 0) {
    console.log("  - unmatched category names:");
    for (const categoryName of unmatchedCategoryNames) {
      console.log(`    * ${categoryName}`);
    }
  }
}

main()
  .catch((error) => {
    console.error("[pharmacy-thumbnails] Failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
