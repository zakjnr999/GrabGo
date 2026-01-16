const path = require('path');
const dotenv = require('dotenv');

// Load env vars
const result = dotenv.config({ path: path.resolve(__dirname, '.env') });
if (result.error) {
    console.error('❌ Error loading .env file:', result.error);
}

const mongoose = require('mongoose');
const GroceryStore = require('../models/GroceryStore');
const GroceryCategory = require('../models/GroceryCategory');
const GroceryItem = require('../models/GroceryItem');

// Sample grocery categories
const categories = [
    { name: 'Fresh Produce', emoji: '🥬', description: 'Fresh fruits and vegetables', sortOrder: 1 },
    { name: 'Dairy & Eggs', emoji: '🥛', description: 'Milk, cheese, eggs, and dairy products', sortOrder: 2 },
    { name: 'Bakery', emoji: '🍞', description: 'Fresh bread, pastries, and baked goods', sortOrder: 3 },
    { name: 'Meat & Seafood', emoji: '🥩', description: 'Fresh meat, poultry, and seafood', sortOrder: 4 },
    { name: 'Pantry Staples', emoji: '🥫', description: 'Canned goods, pasta, rice, and grains', sortOrder: 5 },
    { name: 'Snacks & Sweets', emoji: '🍫', description: 'Chips, candy, cookies, and treats', sortOrder: 6 },
    { name: 'Beverages', emoji: '🥤', description: 'Drinks, juices, and soft drinks', sortOrder: 7 },
    { name: 'Personal Care', emoji: '🧴', description: 'Toiletries and personal care items', sortOrder: 8 },
];

// Sample grocery stores
const stores = [
    {
        storeName: 'Fresh Market',
        logo: 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=400',
        description: 'Your neighborhood grocery store with fresh produce and quality products',
        location: {
            type: 'Point',
            coordinates: [-0.1870, 5.6037],
            address: 'Accra Mall, Accra',
            city: 'Accra',
            area: 'Airport Residential Area'
        },
        phone: '+233 24 123 4567',
        email: 'info@freshmarket.com',
        deliveryFee: 5.00,
        minOrder: 20.00,
        rating: 4.5,
        categories: ['Fresh Produce', 'Dairy & Eggs', 'Bakery'],
        vendorType: 'grocery',
        status: 'approved'
    },
    {
        storeName: 'SuperMart',
        logo: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=400',
        description: 'One-stop shop for all your grocery needs',
        location: {
            type: 'Point',
            coordinates: [-0.1969, 5.5560],
            address: 'Osu, Accra',
            city: 'Accra',
            area: 'Osu'
        },
        phone: '+233 24 234 5678',
        email: 'contact@supermart.com',
        deliveryFee: 7.00,
        minOrder: 25.00,
        rating: 4.3,
        categories: ['Pantry Staples', 'Snacks & Sweets', 'Beverages'],
        vendorType: 'grocery',
        status: 'approved'
    },
    {
        storeName: 'Organic Haven',
        logo: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
        description: 'Premium organic and natural products',
        location: {
            type: 'Point',
            coordinates: [-0.1500, 5.6500],
            address: 'East Legon, Accra',
            city: 'Accra',
            area: 'East Legon'
        },
        phone: '+233 24 345 6789',
        email: 'hello@organichaven.com',
        deliveryFee: 10.00,
        minOrder: 30.00,
        rating: 4.8,
        categories: ['Fresh Produce', 'Dairy & Eggs', 'Personal Care'],
        vendorType: 'grocery',
        status: 'approved'
    },
    {
        storeName: 'Quick Stop',
        logo: 'https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=400',
        description: 'Fast delivery of everyday essentials',
        location: {
            type: 'Point',
            coordinates: [-0.0166, 5.6698],
            address: 'Tema, Accra',
            city: 'Accra',
            area: 'Tema Community 1'
        },
        phone: '+233 24 456 7890',
        email: 'support@quickstop.com',
        deliveryFee: 3.00,
        minOrder: 15.00,
        rating: 4.2,
        categories: ['Snacks & Sweets', 'Beverages', 'Personal Care'],
        vendorType: 'grocery',
        status: 'approved'
    },
    {
        storeName: 'Family Grocers',
        logo: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400',
        description: 'Quality groceries for the whole family',
        location: {
            type: 'Point',
            coordinates: [-0.1677, 5.6812],
            address: 'Madina, Accra',
            city: 'Accra',
            area: 'Madina'
        },
        phone: '+233 24 567 8901',
        email: 'info@familygrocers.com',
        deliveryFee: 6.00,
        minOrder: 20.00,
        rating: 4.6,
        categories: ['Meat & Seafood', 'Bakery', 'Pantry Staples'],
        vendorType: 'grocery',
        status: 'approved'
    },
];

// Sample grocery items
const getGroceryItems = (categoryMap, storeMap) => [
    // Fresh Produce
    { name: 'Organic Bananas', description: 'Fresh organic bananas', image: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=400', price: 3.50, unit: 'kg', category: categoryMap['Fresh Produce'], store: storeMap['Fresh Market'], brand: 'Organic Haven', stock: 100, tags: ['organic', 'fresh'], rating: 4.7, reviewCount: 45, createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000) }, // 2 days ago
    { name: 'Red Apples', description: 'Crisp and sweet red apples', image: 'https://images.unsplash.com/photo-1568702846914-96b305d2aaeb?w=400', price: 4.00, unit: 'kg', category: categoryMap['Fresh Produce'], store: storeMap['Fresh Market'], brand: '', stock: 80, tags: ['fresh'], rating: 4.5, reviewCount: 32, createdAt: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000) }, // 15 days ago
    { name: 'Fresh Tomatoes', description: 'Ripe and juicy tomatoes', image: 'https://images.unsplash.com/photo-1546094096-0df4bcaaa337?w=400', price: 2.50, unit: 'kg', category: categoryMap['Fresh Produce'], store: storeMap['Organic Haven'], brand: '', stock: 120, tags: ['fresh', 'organic'], rating: 4.6, reviewCount: 28, discountPercentage: 15, discountEndDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000) }, // 4 days ago
    { name: 'Carrots', description: 'Fresh crunchy carrots', image: 'https://images.unsplash.com/photo-1598170845058-32b9d6a5da37?w=400', price: 2.00, unit: 'kg', category: categoryMap['Fresh Produce'], store: storeMap['Fresh Market'], brand: '', stock: 90, tags: ['fresh'], rating: 4.4, reviewCount: 22, createdAt: new Date(Date.now() - 20 * 24 * 60 * 60 * 1000) }, // 20 days ago
    { name: 'Lettuce', description: 'Crisp green lettuce', image: 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=400', price: 1.50, unit: 'piece', category: categoryMap['Fresh Produce'], store: storeMap['Organic Haven'], brand: '', stock: 60, tags: ['fresh', 'organic'], rating: 4.3, reviewCount: 18, createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) }, // 1 day ago

    // Dairy & Eggs
    { name: 'Fresh Milk', description: 'Whole fresh milk', image: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400', price: 5.00, unit: 'liter', category: categoryMap['Dairy & Eggs'], store: storeMap['Fresh Market'], brand: 'Dairy Best', stock: 50, tags: ['fresh'], rating: 4.8, reviewCount: 67, createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000) }, // 3 days ago
    { name: 'Cheddar Cheese', description: 'Premium cheddar cheese', image: 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400', price: 8.00, unit: 'pack', category: categoryMap['Dairy & Eggs'], store: storeMap['SuperMart'], brand: 'Cheese Co', stock: 40, tags: [], rating: 4.6, reviewCount: 41, discountPercentage: 20, discountEndDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000), createdAt: new Date(Date.now() - 10 * 24 * 60 * 60 * 1000) }, // 10 days ago
    { name: 'Free Range Eggs', description: 'Fresh free-range eggs', image: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=400', price: 6.00, unit: 'dozen', category: categoryMap['Dairy & Eggs'], store: storeMap['Organic Haven'], brand: 'Happy Hens', stock: 70, tags: ['organic', 'free-range'], rating: 4.9, reviewCount: 89, createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000) }, // 5 days ago
    { name: 'Greek Yogurt', description: 'Creamy Greek yogurt', image: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400', price: 4.50, unit: 'pack', category: categoryMap['Dairy & Eggs'], store: storeMap['Fresh Market'], brand: 'Yogurt Plus', stock: 55, tags: [], rating: 4.7, reviewCount: 52, createdAt: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000) }, // 6 days ago

    // Bakery
    { name: 'Whole Wheat Bread', description: 'Fresh whole wheat bread', image: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400', price: 3.00, unit: 'piece', category: categoryMap['Bakery'], store: storeMap['Family Grocers'], brand: 'Bakery Fresh', stock: 45, tags: ['fresh'], rating: 4.5, reviewCount: 38, createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) }, // 1 day ago
    { name: 'Croissants', description: 'Buttery French croissants', image: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=400', price: 5.00, unit: 'pack', category: categoryMap['Bakery'], store: storeMap['Fresh Market'], brand: 'French Bakery', stock: 30, tags: ['fresh'], rating: 4.8, reviewCount: 61, createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000) }, // 2 days ago
    { name: 'Bagels', description: 'Fresh bagels variety pack', image: 'https://images.unsplash.com/photo-1612182062631-e5c8c1c3c0b7?w=400', price: 4.00, unit: 'pack', category: categoryMap['Bakery'], store: storeMap['Family Grocers'], brand: '', stock: 35, tags: [], rating: 4.4, reviewCount: 29, createdAt: new Date(Date.now() - 12 * 24 * 60 * 60 * 1000) }, // 12 days ago

    // Meat & Seafood
    { name: 'Chicken Breast', description: 'Fresh boneless chicken breast', image: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400', price: 12.00, unit: 'kg', category: categoryMap['Meat & Seafood'], store: storeMap['Family Grocers'], brand: '', stock: 25, tags: ['fresh'], rating: 4.7, reviewCount: 44, createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000) }, // 4 days ago
    { name: 'Salmon Fillet', description: 'Fresh Atlantic salmon', image: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400', price: 18.00, unit: 'kg', category: categoryMap['Meat & Seafood'], store: storeMap['Fresh Market'], brand: '', stock: 15, tags: ['fresh'], rating: 4.9, reviewCount: 56, discountPercentage: 10, discountEndDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000), createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000) }, // 3 days ago
    { name: 'Ground Beef', description: 'Lean ground beef', image: 'https://images.unsplash.com/photo-1603048297172-c92544798d5a?w=400', price: 10.00, unit: 'kg', category: categoryMap['Meat & Seafood'], store: storeMap['Family Grocers'], brand: '', stock: 30, tags: [], rating: 4.6, reviewCount: 37, createdAt: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000) }, // 8 days ago

    // Pantry Staples
    { name: 'Basmati Rice', description: 'Premium basmati rice', image: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400', price: 15.00, unit: 'kg', category: categoryMap['Pantry Staples'], store: storeMap['SuperMart'], brand: 'Royal Rice', stock: 100, tags: [], rating: 4.8, reviewCount: 78, createdAt: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }, // 30 days ago
    { name: 'Pasta', description: 'Italian pasta variety pack', image: 'https://images.unsplash.com/photo-1551462147-ff29053bfc14?w=400', price: 4.00, unit: 'pack', category: categoryMap['Pantry Staples'], store: storeMap['SuperMart'], brand: 'Pasta Italia', stock: 80, tags: [], rating: 4.5, reviewCount: 42, createdAt: new Date(Date.now() - 25 * 24 * 60 * 60 * 1000) }, // 25 days ago
    { name: 'Olive Oil', description: 'Extra virgin olive oil', image: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400', price: 12.00, unit: 'liter', category: categoryMap['Pantry Staples'], store: storeMap['Organic Haven'], brand: 'Mediterranean', stock: 45, tags: ['organic'], rating: 4.9, reviewCount: 91, createdAt: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000) }, // 5 days ago
    { name: 'Canned Tomatoes', description: 'Diced tomatoes in juice', image: 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=400', price: 2.50, unit: 'pack', category: categoryMap['Pantry Staples'], store: storeMap['SuperMart'], brand: 'Tomato Co', stock: 120, tags: [], rating: 4.3, reviewCount: 34, createdAt: new Date(Date.now() - 18 * 24 * 60 * 60 * 1000) }, // 18 days ago

    // Snacks & Sweets
    { name: 'Potato Chips', description: 'Crispy potato chips', image: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400', price: 3.00, unit: 'pack', category: categoryMap['Snacks & Sweets'], store: storeMap['Quick Stop'], brand: 'Crispy Chips', stock: 90, tags: [], rating: 4.4, reviewCount: 56, createdAt: new Date(Date.now() - 6 * 24 * 60 * 60 * 1000) }, // 6 days ago
    { name: 'Chocolate Bar', description: 'Premium dark chocolate', image: 'https://images.unsplash.com/photo-1511381939415-e44015466834?w=400', price: 2.00, unit: 'piece', category: categoryMap['Snacks & Sweets'], store: storeMap['SuperMart'], brand: 'Choco Delight', stock: 150, tags: [], rating: 4.7, reviewCount: 89, discountPercentage: 25, discountEndDate: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000), createdAt: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000) }, // 14 days ago
    { name: 'Cookies', description: 'Assorted cookies pack', image: 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400', price: 4.50, unit: 'pack', category: categoryMap['Snacks & Sweets'], store: storeMap['Quick Stop'], brand: 'Cookie Jar', stock: 70, tags: [], rating: 4.6, reviewCount: 67, createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000) }, // 2 days ago

    // Beverages
    { name: 'Orange Juice', description: 'Fresh squeezed orange juice', image: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=400', price: 5.00, unit: 'liter', category: categoryMap['Beverages'], store: storeMap['Fresh Market'], brand: 'Fresh Squeeze', stock: 60, tags: ['fresh'], rating: 4.8, reviewCount: 73, createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000) }, // 1 day ago
    { name: 'Mineral Water', description: 'Natural mineral water', image: 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400', price: 1.50, unit: 'liter', category: categoryMap['Beverages'], store: storeMap['Quick Stop'], brand: 'Pure Water', stock: 200, tags: [], rating: 4.5, reviewCount: 45, createdAt: new Date(Date.now() - 22 * 24 * 60 * 60 * 1000) }, // 22 days ago
    { name: 'Coffee Beans', description: 'Premium Arabica coffee beans', image: 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400', price: 15.00, unit: 'kg', category: categoryMap['Beverages'], store: storeMap['Organic Haven'], brand: 'Coffee Masters', stock: 40, tags: ['organic'], rating: 4.9, reviewCount: 102, createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000) }, // 3 days ago

    // Personal Care
    { name: 'Shampoo', description: 'Moisturizing shampoo', image: 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=400', price: 8.00, unit: 'piece', category: categoryMap['Personal Care'], store: storeMap['Quick Stop'], brand: 'Hair Care Pro', stock: 55, tags: [], rating: 4.6, reviewCount: 48, createdAt: new Date(Date.now() - 16 * 24 * 60 * 60 * 1000) }, // 16 days ago
    { name: 'Toothpaste', description: 'Whitening toothpaste', image: 'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400', price: 4.00, unit: 'piece', category: categoryMap['Personal Care'], store: storeMap['Quick Stop'], brand: 'Smile Bright', stock: 80, tags: [], rating: 4.7, reviewCount: 61, createdAt: new Date(Date.now() - 11 * 24 * 60 * 60 * 1000) }, // 11 days ago
    { name: 'Hand Soap', description: 'Antibacterial hand soap', image: 'https://images.unsplash.com/photo-1585909695284-32d2985ac9c0?w=400', price: 3.50, unit: 'piece', category: categoryMap['Personal Care'], store: storeMap['Organic Haven'], brand: 'Clean Hands', stock: 70, tags: ['organic'], rating: 4.5, reviewCount: 39, createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000) }, // 4 days ago
];

async function seedGroceries() {
    try {
        // Connect to MongoDB
        // Connect to MongoDB
        const mongoUri = process.env.MONGODB_URI || "mongodb://localhost:27017/grabgo";
        await mongoose.connect(mongoUri);
        console.log('✅ Connected to MongoDB');

        // Clear existing data
        await GroceryCategory.deleteMany({});
        await GroceryStore.deleteMany({});
        await GroceryItem.deleteMany({});
        console.log('🗑️  Cleared existing grocery data');

        // Insert categories
        const insertedCategories = await GroceryCategory.insertMany(categories);
        console.log(`✅ Inserted ${insertedCategories.length} categories`);

        // Create category map
        const categoryMap = {};
        insertedCategories.forEach(cat => {
            categoryMap[cat.name] = cat._id;
        });

        // Insert stores
        const insertedStores = await GroceryStore.insertMany(stores);
        console.log(`✅ Inserted ${insertedStores.length} stores`);

        // Create store map
        const storeMap = {};
        insertedStores.forEach(store => {
            storeMap[store.storeName] = store._id;
        });

        // Insert items
        const items = getGroceryItems(categoryMap, storeMap);
        const insertedItems = await GroceryItem.insertMany(items);
        console.log(`✅ Inserted ${insertedItems.length} items`);

        console.log('\n🎉 Grocery data seeded successfully!');
        console.log(`\n📊 Summary:`);
        console.log(`   Categories: ${insertedCategories.length}`);
        console.log(`   Stores: ${insertedStores.length}`);
        console.log(`   Items: ${insertedItems.length}`);
        console.log(`   Deals: ${items.filter(i => i.discountPercentage > 0).length}`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error seeding grocery data:', error);
        process.exit(1);
    }
}

seedGroceries();
