const verboseSql = process.argv.includes("--verbose-sql");

if (!verboseSql) {
  process.env.NODE_ENV = "production";
}

require("dotenv").config();

const prisma = require("../config/prisma");

const dayFromNow = (days) => {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date;
};

const DUMMYJSON_IMAGE_BASE_URL = "https://cdn.dummyjson.com/product-images";
const CURATED_BAKERY_PACKSHOT_URL =
  "https://images.openfoodfacts.org/images/products/841/008/701/2018/front_fr.25.400.jpg";

const CATEGORY_DEFINITIONS = [
  {
    name: "Fresh Produce",
    emoji: "🥬",
    description: "Fruit, vegetables, and everyday market fresh picks.",
    image: `${DUMMYJSON_IMAGE_BASE_URL}/groceries/green-bell-pepper/thumbnail.webp`,
    sortOrder: 1,
  },
  {
    name: "Dairy & Eggs",
    emoji: "🥛",
    description: "Milk, yogurt, cheese, and chilled breakfast staples.",
    image: `${DUMMYJSON_IMAGE_BASE_URL}/groceries/milk/thumbnail.webp`,
    sortOrder: 2,
  },
  {
    name: "Bakery",
    emoji: "🥐",
    description: "Fresh bread, pastries, and breakfast baked goods.",
    image: CURATED_BAKERY_PACKSHOT_URL,
    sortOrder: 3,
  },
  {
    name: "Meat & Seafood",
    emoji: "🥩",
    description: "Proteins for quick meals and family cooking.",
    image: `${DUMMYJSON_IMAGE_BASE_URL}/groceries/fish-steak/thumbnail.webp`,
    sortOrder: 4,
  },
  {
    name: "Pantry Staples",
    emoji: "🥫",
    description: "Rice, pasta, oils, and shelf-ready cooking essentials.",
    image: `${DUMMYJSON_IMAGE_BASE_URL}/groceries/rice/thumbnail.webp`,
    sortOrder: 5,
  },
  {
    name: "Snacks & Treats",
    emoji: "🍪",
    description: "Sweet bites, crunchy snacks, and impulse favorites.",
    image: `${DUMMYJSON_IMAGE_BASE_URL}/groceries/honey-jar/thumbnail.webp`,
    sortOrder: 6,
  },
  {
    name: "Drinks & Coffee",
    emoji: "🥤",
    description: "Juices, water, sparkling drinks, and coffee essentials.",
    image: `${DUMMYJSON_IMAGE_BASE_URL}/groceries/juice/thumbnail.webp`,
    sortOrder: 7,
  },
  {
    name: "Home Care",
    emoji: "🧴",
    description: "Bathroom, hygiene, and personal care staples.",
    image: `${DUMMYJSON_IMAGE_BASE_URL}/skin-care/attitude-super-leaves-hand-soap/thumbnail.webp`,
    sortOrder: 8,
  },
];

const STORE_CATALOG = {
  SuperMart: [
    {
      name: "Dark Chocolate Slab",
      categoryName: "Snacks & Treats",
      description: "Rich 70% cocoa dark chocolate for gifting or snacking.",
      image: "https://images.unsplash.com/photo-1511381939415-e44015466834?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1511381939415-e44015466834?w=800",
      price: 6.5,
      unit: "piece",
      brand: "Cocoa Reserve",
      stock: 140,
      tags: ["chocolate", "snack", "premium"],
      discountPercentage: 20,
      discountEndDate: dayFromNow(8),
    },
    {
      name: "Mature Cheddar Block",
      categoryName: "Dairy & Eggs",
      description: "Aged cheddar with a firm bite and creamy finish.",
      image: "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=800",
      price: 18.9,
      unit: "pack",
      brand: "Highland Dairy",
      stock: 65,
      tags: ["cheese", "dairy", "fridge"],
      discountPercentage: 10,
      discountEndDate: dayFromNow(6),
    },
    {
      name: "Penne Rigate Pasta",
      categoryName: "Pantry Staples",
      description: "Bronze-cut penne for weeknight pasta dishes.",
      image: "https://images.unsplash.com/photo-1551462147-ff29053bfc14?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1551462147-ff29053bfc14?w=800",
      price: 9.5,
      unit: "pack",
      brand: "Pasta Italia",
      stock: 120,
      tags: ["pasta", "pantry", "dinner"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Premium Basmati Rice",
      categoryName: "Pantry Staples",
      description: "Long-grain aromatic basmati rice for family meals.",
      image: "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=800",
      price: 24,
      unit: "kg",
      brand: "Royal Fields",
      stock: 150,
      tags: ["rice", "pantry", "bulk"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Chopped Tomatoes Tin",
      categoryName: "Pantry Staples",
      description: "Bright chopped tomatoes ready for sauces and stews.",
      image: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800",
      price: 6,
      unit: "pack",
      brand: "Tomato Pantry",
      stock: 180,
      tags: ["tomatoes", "cooking", "tin"],
      discountPercentage: 12,
      discountEndDate: dayFromNow(9),
    },
  ],
  "Fresh Market": [
    {
      name: "Butter Croissants",
      categoryName: "Bakery",
      description: "Flaky all-butter croissants baked fresh each morning.",
      image: "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800",
      price: 12,
      unit: "pack",
      brand: "Maison Bake",
      stock: 40,
      tags: ["bakery", "breakfast", "pastry"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Honeycrisp Apples",
      categoryName: "Fresh Produce",
      description: "Sweet-crisp apples with a clean juicy bite.",
      image: "https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=800",
      price: 14,
      unit: "kg",
      brand: "Fresh Market Select",
      stock: 90,
      tags: ["fruit", "fresh", "snack"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Atlantic Salmon Portions",
      categoryName: "Meat & Seafood",
      description: "Skin-on salmon portions ready for oven or pan.",
      image: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800",
      price: 48,
      unit: "kg",
      brand: "Ocean Table",
      stock: 28,
      tags: ["seafood", "salmon", "fresh"],
      discountPercentage: 15,
      discountEndDate: dayFromNow(4),
    },
    {
      name: "Market Bananas",
      categoryName: "Fresh Produce",
      description: "Everyday sweet bananas for breakfast bowls and smoothies.",
      image: "https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=800",
      price: 8.5,
      unit: "kg",
      brand: "Farm Basket",
      stock: 110,
      tags: ["fruit", "fresh", "breakfast"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Greek Yogurt Cup",
      categoryName: "Dairy & Eggs",
      description: "Thick strained yogurt with a creamy tang.",
      image: "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800",
      price: 11.5,
      unit: "pack",
      brand: "Yogurt House",
      stock: 70,
      tags: ["yogurt", "breakfast", "fridge"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Cold-Pressed Orange Juice",
      categoryName: "Drinks & Coffee",
      description: "Bright citrus juice with no artificial sweeteners.",
      image: "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=800",
      price: 18,
      unit: "liter",
      brand: "Fresh Squeeze",
      stock: 55,
      tags: ["juice", "breakfast", "drink"],
      discountPercentage: 10,
      discountEndDate: dayFromNow(5),
    },
    {
      name: "Full Cream Milk",
      categoryName: "Dairy & Eggs",
      description: "Fresh chilled whole milk for cereal and coffee.",
      image: "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=800",
      price: 16,
      unit: "liter",
      brand: "Dairy Best",
      stock: 65,
      tags: ["milk", "fridge", "breakfast"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Sweet Carrots",
      categoryName: "Fresh Produce",
      description: "Crunchy carrots for salads, soups, and roasting.",
      image: "https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=800",
      price: 7.5,
      unit: "kg",
      brand: "Market Roots",
      stock: 95,
      tags: ["vegetable", "fresh", "cooking"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Soft White Bread",
      categoryName: "Bakery",
      description: "Pillow-soft sandwich loaf baked for everyday breakfasts.",
      image: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800",
      price: 9.5,
      unit: "piece",
      brand: "Morning Bake",
      stock: 50,
      tags: ["bread", "bakery", "sandwich"],
      discountPercentage: 0,
      discountEndDate: null,
    },
  ],
  "Organic Haven": [
    {
      name: "Baby Spinach",
      categoryName: "Fresh Produce",
      description: "Tender leafy greens for wraps, bowls, and salads.",
      image: "https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=800",
      price: 10,
      unit: "pack",
      brand: "Organic Haven",
      stock: 45,
      tags: ["greens", "salad", "organic"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Free-Range Eggs",
      categoryName: "Dairy & Eggs",
      description: "Golden-yolk eggs sourced from free-range hens.",
      image: "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=800",
      price: 24,
      unit: "dozen",
      brand: "Happy Hens",
      stock: 75,
      tags: ["eggs", "breakfast", "organic"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Heirloom Tomatoes",
      categoryName: "Fresh Produce",
      description: "Juicy colorful tomatoes for salads and quick sauces.",
      image: "https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=800",
      price: 12,
      unit: "kg",
      brand: "Organic Haven",
      stock: 85,
      tags: ["tomatoes", "fresh", "organic"],
      discountPercentage: 14,
      discountEndDate: dayFromNow(5),
    },
    {
      name: "Medium Roast Coffee Beans",
      categoryName: "Drinks & Coffee",
      description: "Balanced medium roast with chocolate and caramel notes.",
      image: "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=800",
      price: 32,
      unit: "kg",
      brand: "Coffee Masters",
      stock: 35,
      tags: ["coffee", "beans", "drink"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Botanical Hand Soap",
      categoryName: "Home Care",
      description: "Gentle hand wash with a clean herbal scent.",
      image: "https://images.unsplash.com/photo-1585909695284-32d2985ac9c0?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1585909695284-32d2985ac9c0?w=800",
      price: 9,
      unit: "piece",
      brand: "Clean Hands",
      stock: 90,
      tags: ["soap", "bathroom", "care"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Extra Virgin Olive Oil",
      categoryName: "Pantry Staples",
      description: "Cold-pressed olive oil for dressings and finishing.",
      image: "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=800",
      price: 28,
      unit: "liter",
      brand: "Mediterranean",
      stock: 40,
      tags: ["oil", "pantry", "cooking"],
      discountPercentage: 8,
      discountEndDate: dayFromNow(10),
    },
  ],
  "Family Grocers": [
    {
      name: "Boneless Chicken Breast",
      categoryName: "Meat & Seafood",
      description: "Trimmed chicken breast for grills, bowls, and stir fry.",
      image: "https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=800",
      price: 34,
      unit: "kg",
      brand: "Family Grocers",
      stock: 42,
      tags: ["chicken", "protein", "fresh"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Lean Ground Beef",
      categoryName: "Meat & Seafood",
      description: "Fresh lean mince for burgers, pasta, and stews.",
      image: "https://images.unsplash.com/photo-1603048297172-c92544798d5a?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1603048297172-c92544798d5a?w=800",
      price: 30,
      unit: "kg",
      brand: "Family Grocers",
      stock: 38,
      tags: ["beef", "protein", "fresh"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Stoneground Wheat Loaf",
      categoryName: "Bakery",
      description: "Nutty whole wheat loaf sliced for toast and sandwiches.",
      image: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800",
      price: 11,
      unit: "piece",
      brand: "Bakery Fresh",
      stock: 36,
      tags: ["bread", "bakery", "breakfast"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Blueberry Bagels",
      categoryName: "Bakery",
      description: "Chewy bagels with a lightly sweet blueberry finish.",
      image: "https://images.unsplash.com/photo-1612182062631-e5c8c1c3c0b7?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1612182062631-e5c8c1c3c0b7?w=800",
      price: 14,
      unit: "pack",
      brand: "Family Grocers",
      stock: 30,
      tags: ["bagel", "bakery", "breakfast"],
      discountPercentage: 0,
      discountEndDate: null,
    },
  ],
  "Quick Stop": [
    {
      name: "Sparkling Mineral Water",
      categoryName: "Drinks & Coffee",
      description: "Refreshing carbonated mineral water chilled for delivery.",
      image: "https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=800",
      price: 4.5,
      unit: "liter",
      brand: "Pure Water",
      stock: 180,
      tags: ["water", "drink", "sparkling"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Sea Salt Potato Chips",
      categoryName: "Snacks & Treats",
      description: "Crisp kettle chips with a simple sea salt finish.",
      image: "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=800",
      price: 8,
      unit: "pack",
      brand: "Crispy Chips",
      stock: 140,
      tags: ["chips", "snack", "salty"],
      discountPercentage: 12,
      discountEndDate: dayFromNow(7),
    },
    {
      name: "Repair & Shine Shampoo",
      categoryName: "Home Care",
      description: "Hydrating shampoo for soft, glossy daily care.",
      image: "https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=800",
      price: 18,
      unit: "piece",
      brand: "Hair Care Pro",
      stock: 52,
      tags: ["shampoo", "bathroom", "care"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Butter Cookies Pack",
      categoryName: "Snacks & Treats",
      description: "Golden butter cookies packed for easy sharing.",
      image: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=800",
      price: 12,
      unit: "pack",
      brand: "Cookie Jar",
      stock: 96,
      tags: ["cookies", "sweet", "snack"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Fresh Mint Toothpaste",
      categoryName: "Home Care",
      description: "Cooling mint toothpaste for a bright everyday clean.",
      image: "https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=800",
      price: 10.5,
      unit: "piece",
      brand: "Smile Bright",
      stock: 84,
      tags: ["toothpaste", "care", "bathroom"],
      discountPercentage: 0,
      discountEndDate: null,
    },
  ],
  "Beverage Barn": [
    {
      name: "Apple Sparkling Juice",
      categoryName: "Drinks & Coffee",
      description: "Crisp sparkling apple drink with a clean fruit finish.",
      image: "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=800",
      price: 16,
      unit: "liter",
      brand: "Beverage Barn",
      stock: 48,
      tags: ["juice", "drink", "sparkling"],
      discountPercentage: 0,
      discountEndDate: null,
    },
    {
      name: "Coconut Water Bottle",
      categoryName: "Drinks & Coffee",
      description: "Light naturally sweet hydration for on-the-go refreshment.",
      image: "https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=800",
      price: 9.5,
      unit: "liter",
      brand: "Beverage Barn",
      stock: 52,
      tags: ["water", "drink", "refresh"],
      discountPercentage: 0,
      discountEndDate: null,
    },
  ],
  "City Mart": [
    {
      name: "Hass Avocados",
      categoryName: "Fresh Produce",
      description: "Creamy avocados ready for toast, salads, and bowls.",
      image: "https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=800",
      price: 18,
      unit: "kg",
      brand: "City Mart Select",
      stock: 40,
      tags: ["avocado", "fresh", "produce"],
      discountPercentage: 0,
      discountEndDate: null,
    },
  ],
  "Daily Fresh": [
    {
      name: "Organic Whole Milk",
      categoryName: "Dairy & Eggs",
      description: "Creamy chilled milk sourced for daily breakfast staples.",
      image: "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=800",
      thumbnailImage: "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=800",
      price: 15,
      unit: "liter",
      brand: "Daily Fresh",
      stock: 42,
      tags: ["milk", "breakfast", "fridge"],
      discountPercentage: 0,
      discountEndDate: null,
    },
  ],
};

function createCategoryMap(categories) {
  const map = new Map();
  for (const category of categories) {
    map.set(category.name, category);
  }
  return map;
}

async function syncCategories(dryRun) {
  const canonicalNames = CATEGORY_DEFINITIONS.map((category) => category.name);

  if (!dryRun) {
    await prisma.groceryCategory.updateMany({
      where: {
        name: {
          notIn: canonicalNames,
        },
      },
      data: {
        isActive: false,
      },
    });
  }

  const categories = [];

  for (const definition of CATEGORY_DEFINITIONS) {
    if (dryRun) {
      categories.push({
        id: `dry-run:${definition.name}`,
        ...definition,
        isActive: true,
      });
      continue;
    }

    const category = await prisma.groceryCategory.upsert({
      where: { name: definition.name },
      update: {
        emoji: definition.emoji,
        description: definition.description,
        image: definition.image,
        sortOrder: definition.sortOrder,
        isActive: true,
        storeId: null,
      },
      create: {
        name: definition.name,
        emoji: definition.emoji,
        description: definition.description,
        image: definition.image,
        sortOrder: definition.sortOrder,
        isActive: true,
        storeId: null,
      },
    });

    categories.push(category);
  }

  return createCategoryMap(categories);
}

function getCanonicalCatalogCount() {
  return Object.values(STORE_CATALOG).reduce((sum, items) => sum + items.length, 0);
}

async function fetchCurrentItemsByStore() {
  const items = await prisma.groceryItem.findMany({
    include: {
      store: {
        select: {
          storeName: true,
        },
      },
    },
    orderBy: [{ orderCount: "desc" }, { name: "asc" }],
  });

  const grouped = new Map();

  for (const item of items) {
    const storeName = item.store?.storeName;
    if (!storeName) continue;
    if (!grouped.has(storeName)) {
      grouped.set(storeName, []);
    }
    grouped.get(storeName).push(item);
  }

  return grouped;
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const categoriesOnly = process.argv.includes("--categories-only");
  const currentItemsByStore = categoriesOnly
    ? new Map()
    : await fetchCurrentItemsByStore();
  const categoryMap = await syncCategories(dryRun);
  if (categoriesOnly) {
    console.log("[grocery-catalog] Summary:");
    console.log(`  - categories active: ${CATEGORY_DEFINITIONS.length}`);
    console.log(
      "  - category images updated: grocery categories now use packshot-style assets"
    );
    return;
  }
  const canonicalCount = getCanonicalCatalogCount();
  const currentCount = Array.from(currentItemsByStore.values()).reduce(
    (sum, items) => sum + items.length,
    0
  );

  console.log(
    `[grocery-catalog] Starting ${
      dryRun ? "dry-run" : "write"
    } refresh for ${canonicalCount} catalog slots`
  );

  if (currentCount !== canonicalCount) {
    throw new Error(
      `Current grocery item count (${currentCount}) does not match catalog definitions (${canonicalCount}).`
    );
  }

  for (const [storeName, definitions] of Object.entries(STORE_CATALOG)) {
    const currentItems = currentItemsByStore.get(storeName) || [];

    if (currentItems.length !== definitions.length) {
      throw new Error(
        `Store "${storeName}" has ${currentItems.length} items, but catalog expects ${definitions.length}.`
      );
    }
  }

  let updated = 0;

  for (const [storeName, definitions] of Object.entries(STORE_CATALOG)) {
    const currentItems = currentItemsByStore.get(storeName) || [];

    for (let index = 0; index < definitions.length; index += 1) {
      const currentItem = currentItems[index];
      const definition = definitions[index];
      const category = categoryMap.get(definition.categoryName);

      if (!category) {
        throw new Error(
          `Missing category "${definition.categoryName}" for item "${definition.name}".`
        );
      }

      updated += 1;

      if (dryRun) continue;

      await prisma.groceryItem.update({
        where: { id: currentItem.id },
        data: {
          name: definition.name,
          description: definition.description,
          thumbnailImage: definition.thumbnailImage,
          price: definition.price,
          unit: definition.unit,
          categoryId: category.id,
          brand: definition.brand,
          stock: definition.stock,
          isAvailable: true,
          discountPercentage: definition.discountPercentage,
          discountEndDate: definition.discountEndDate,
          tags: definition.tags,
        },
      });
    }
  }

  console.log("[grocery-catalog] Summary:");
  console.log(`  - categories active: ${CATEGORY_DEFINITIONS.length}`);
  console.log(`  - items refreshed: ${updated}`);
  console.log("  - thumbnails updated: grocery items now use thumbnailImage only");
}

main()
  .catch((error) => {
    console.error("[grocery-catalog] Failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
