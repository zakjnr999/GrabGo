const path = require('path');
const dotenv = require('dotenv');

// Load env vars
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const mongoose = require('mongoose');
const PharmacyStore = require('../models/PharmacyStore');
const PharmacyCategory = require('../models/PharmacyCategory');
const PharmacyItem = require('../models/PharmacyItem');
const GrabMartStore = require('../models/GrabMartStore');
const GrabMartCategory = require('../models/GrabMartCategory');
const GrabMartItem = require('../models/GrabMartItem');

// Function to get pharmacy items
const getPharmacyItems = (categoryMap, stores) => [
    // Medicines
    { name: 'Paracetamol 500mg', description: 'Pain relief and fever reducer', image: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400', price: 5.00, unit: 'strip', category: categoryMap['Medicines'], store: stores[0]._id, brand: 'MediCare', stock: 200, requiresPrescription: false, tags: ['pain-relief', 'fever'], rating: 4.7, reviewCount: 89, orderCount: 450 },
    { name: 'Ibuprofen 400mg', description: 'Anti-inflammatory pain reliever', image: 'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=400', price: 8.00, unit: 'strip', category: categoryMap['Medicines'], store: stores[0]._id, brand: 'PharmaCare', stock: 150, requiresPrescription: false, tags: ['pain-relief', 'anti-inflammatory'], rating: 4.6, reviewCount: 67, orderCount: 320 },
    { name: 'Cough Syrup', description: 'Relief from cough and cold symptoms', image: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400', price: 12.00, unit: 'bottle', category: categoryMap['Medicines'], store: stores[1]._id, brand: 'CoughAway', stock: 80, requiresPrescription: false, tags: ['cough', 'cold'], rating: 4.5, reviewCount: 54, orderCount: 280, discountPercentage: 10, discountEndDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) },
    { name: 'Antibiotic Amoxicillin', description: 'Treats bacterial infections', image: 'https://images.unsplash.com/photo-1550572017-4a6e8c4f8f7f?w=400', price: 25.00, unit: 'pack', category: categoryMap['Medicines'], store: stores[0]._id, brand: 'MediStrong', stock: 60, requiresPrescription: true, tags: ['antibiotic', 'prescription'], rating: 4.8, reviewCount: 42, orderCount: 180 },

    // Wellness
    { name: 'Vitamin C 1000mg', description: 'Immune system support', image: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400', price: 15.00, unit: 'bottle', category: categoryMap['Wellness'], store: stores[1]._id, brand: 'VitaBoost', stock: 120, requiresPrescription: false, tags: ['vitamin', 'immunity'], rating: 4.7, reviewCount: 98, orderCount: 520 },
    { name: 'Multivitamin Complex', description: 'Complete daily nutrition', image: 'https://images.unsplash.com/photo-1550572017-4a6e8c4f8f7f?w=400', price: 20.00, unit: 'bottle', category: categoryMap['Wellness'], store: stores[0]._id, brand: 'HealthPlus', stock: 90, requiresPrescription: false, tags: ['multivitamin', 'wellness'], rating: 4.8, reviewCount: 112, orderCount: 480 },
    { name: 'Omega-3 Fish Oil', description: 'Heart and brain health support', image: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400', price: 30.00, unit: 'bottle', category: categoryMap['Wellness'], store: stores[1]._id, brand: 'OmegaCare', stock: 70, requiresPrescription: false, tags: ['omega-3', 'heart-health'], rating: 4.9, reviewCount: 87, orderCount: 390, discountPercentage: 15, discountEndDate: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000) },

    // Personal Care
    { name: 'Hand Sanitizer 500ml', description: 'Kills 99.9% of germs', image: 'https://images.unsplash.com/photo-1585909695284-32d2985ac9c0?w=400', price: 8.00, unit: 'bottle', category: categoryMap['Personal Care'], store: stores[0]._id, brand: 'CleanHands', stock: 200, requiresPrescription: false, tags: ['sanitizer', 'hygiene'], rating: 4.6, reviewCount: 145, orderCount: 680 },
    { name: 'Moisturizing Lotion', description: 'Hydrates and softens skin', image: 'https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=400', price: 12.00, unit: 'bottle', category: categoryMap['Personal Care'], store: stores[1]._id, brand: 'SkinCare Pro', stock: 110, requiresPrescription: false, tags: ['skincare', 'moisturizer'], rating: 4.7, reviewCount: 76, orderCount: 340 },
    { name: 'Sunscreen SPF 50', description: 'Broad spectrum UV protection', image: 'https://images.unsplash.com/photo-1571875257727-256c39da42af?w=400', price: 18.00, unit: 'tube', category: categoryMap['Personal Care'], store: stores[0]._id, brand: 'SunShield', stock: 85, requiresPrescription: false, tags: ['sunscreen', 'skincare'], rating: 4.8, reviewCount: 92, orderCount: 420 },

    // First Aid
    { name: 'Adhesive Bandages', description: 'Assorted sizes for cuts and scrapes', image: 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=400', price: 4.00, unit: 'box', category: categoryMap['First Aid'], store: stores[1]._id, brand: 'FirstCare', stock: 180, requiresPrescription: false, tags: ['bandage', 'first-aid'], rating: 4.5, reviewCount: 63, orderCount: 290 },
    { name: 'Antiseptic Solution', description: 'Prevents infection in wounds', image: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400', price: 6.00, unit: 'bottle', category: categoryMap['First Aid'], store: stores[0]._id, brand: 'MediClean', stock: 140, requiresPrescription: false, tags: ['antiseptic', 'wound-care'], rating: 4.6, reviewCount: 48, orderCount: 220 },
    { name: 'First Aid Kit', description: 'Complete emergency kit', image: 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?w=400', price: 35.00, unit: 'box', category: categoryMap['First Aid'], store: stores[1]._id, brand: 'EmergencyCare', stock: 50, requiresPrescription: false, tags: ['first-aid', 'emergency'], rating: 4.9, reviewCount: 71, orderCount: 310, discountPercentage: 20, discountEndDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000) },

    // Baby Care
    { name: 'Baby Diapers Size 3', description: 'Soft and absorbent diapers', image: 'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=400', price: 25.00, unit: 'pack', category: categoryMap['Baby Care'], store: stores[0]._id, brand: 'BabySoft', stock: 100, requiresPrescription: false, tags: ['diapers', 'baby'], rating: 4.7, reviewCount: 134, orderCount: 560 },
    { name: 'Baby Wipes', description: 'Gentle and hypoallergenic', image: 'https://images.unsplash.com/photo-1522771930-78848d9293e8?w=400', price: 8.00, unit: 'pack', category: categoryMap['Baby Care'], store: stores[1]._id, brand: 'BabyClean', stock: 150, requiresPrescription: false, tags: ['wipes', 'baby'], rating: 4.6, reviewCount: 98, orderCount: 480 },
    { name: 'Baby Formula Milk', description: 'Nutritious infant formula', image: 'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?w=400', price: 40.00, unit: 'can', category: categoryMap['Baby Care'], store: stores[0]._id, brand: 'BabyNutri', stock: 70, requiresPrescription: false, tags: ['formula', 'baby'], rating: 4.8, reviewCount: 87, orderCount: 390 },

    // Health Devices
    { name: 'Digital Thermometer', description: 'Fast and accurate temperature reading', image: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400', price: 15.00, unit: 'piece', category: categoryMap['Health Devices'], store: stores[1]._id, brand: 'TempCheck', stock: 90, requiresPrescription: false, tags: ['thermometer', 'health-device'], rating: 4.7, reviewCount: 76, orderCount: 340 },
    { name: 'Blood Pressure Monitor', description: 'Automatic BP measurement', image: 'https://images.unsplash.com/photo-1550572017-4a6e8c4f8f7f?w=400', price: 50.00, unit: 'piece', category: categoryMap['Health Devices'], store: stores[0]._id, brand: 'HealthMonitor', stock: 45, requiresPrescription: false, tags: ['bp-monitor', 'health-device'], rating: 4.8, reviewCount: 62, orderCount: 280 },
    { name: 'Pulse Oximeter', description: 'Measures oxygen saturation', image: 'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=400', price: 35.00, unit: 'piece', category: categoryMap['Health Devices'], store: stores[1]._id, brand: 'OxyCheck', stock: 60, requiresPrescription: false, tags: ['oximeter', 'health-device'], rating: 4.6, reviewCount: 54, orderCount: 240, discountPercentage: 12, discountEndDate: new Date(Date.now() + 8 * 24 * 60 * 60 * 1000) },
];

// Function to get GrabMart items
const getGrabMartItems = (categoryMap, stores) => [
    // Snacks
    { name: 'Potato Chips Classic', description: 'Crispy salted potato chips', image: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400', price: 3.50, unit: 'pack', category: categoryMap['Snacks'], store: stores[0]._id, brand: 'CrunchTime', stock: 200, tags: ['chips', 'snack'], rating: 4.5, reviewCount: 145, orderCount: 680 },
    { name: 'Chocolate Bar', description: 'Smooth milk chocolate', image: 'https://images.unsplash.com/photo-1511381939415-e44015466834?w=400', price: 2.50, unit: 'piece', category: categoryMap['Snacks'], store: stores[1]._id, brand: 'ChocoDelight', stock: 250, tags: ['chocolate', 'sweet'], rating: 4.7, reviewCount: 198, orderCount: 820, discountPercentage: 15, discountEndDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000) },
    { name: 'Salted Peanuts', description: 'Roasted and salted peanuts', image: 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?w=400', price: 4.00, unit: 'pack', category: categoryMap['Snacks'], store: stores[0]._id, brand: 'NuttySnack', stock: 180, tags: ['nuts', 'snack'], rating: 4.6, reviewCount: 112, orderCount: 540 },
    { name: 'Cookies Assorted', description: 'Mix of chocolate and vanilla cookies', image: 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400', price: 5.00, unit: 'pack', category: categoryMap['Snacks'], store: stores[1]._id, brand: 'CookieJar', stock: 160, tags: ['cookies', 'sweet'], rating: 4.8, reviewCount: 134, orderCount: 620 },

    // Beverages
    { name: 'Cola Soft Drink', description: 'Refreshing carbonated cola', image: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=400', price: 2.00, unit: 'can', category: categoryMap['Beverages'], store: stores[0]._id, brand: 'FizzCola', stock: 300, tags: ['soda', 'drink'], rating: 4.4, reviewCount: 167, orderCount: 750 },
    { name: 'Energy Drink', description: 'Boosts energy and focus', image: 'https://images.unsplash.com/photo-1622543925917-763c34f4dbd0?w=400', price: 4.50, unit: 'can', category: categoryMap['Beverages'], store: stores[1]._id, brand: 'PowerBoost', stock: 220, tags: ['energy', 'drink'], rating: 4.6, reviewCount: 189, orderCount: 820 },
    { name: 'Bottled Water', description: 'Pure mineral water', image: 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400', price: 1.50, unit: 'bottle', category: categoryMap['Beverages'], store: stores[0]._id, brand: 'PureWater', stock: 400, tags: ['water', 'drink'], rating: 4.5, reviewCount: 201, orderCount: 920 },
    { name: 'Orange Juice', description: 'Fresh squeezed orange juice', image: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=400', price: 5.00, unit: 'bottle', category: categoryMap['Beverages'], store: stores[1]._id, brand: 'FreshSqueeze', stock: 150, tags: ['juice', 'drink'], rating: 4.7, reviewCount: 123, orderCount: 580, discountPercentage: 10, discountEndDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) },

    // Electronics
    { name: 'USB-C Cable', description: 'Fast charging cable 1m', image: 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=400', price: 8.00, unit: 'piece', category: categoryMap['Electronics'], store: stores[0]._id, brand: 'TechConnect', stock: 120, tags: ['cable', 'charging'], rating: 4.5, reviewCount: 87, orderCount: 420 },
    { name: 'Phone Charger', description: 'Universal USB wall charger', image: 'https://images.unsplash.com/photo-1591290619762-c588f7e4e86f?w=400', price: 12.00, unit: 'piece', category: categoryMap['Electronics'], store: stores[1]._id, brand: 'PowerPlug', stock: 100, tags: ['charger', 'electronics'], rating: 4.6, reviewCount: 94, orderCount: 460 },
    { name: 'Earphones', description: 'In-ear wired earphones', image: 'https://images.unsplash.com/photo-1484704849700-f032a568e944?w=400', price: 15.00, unit: 'piece', category: categoryMap['Electronics'], store: stores[0]._id, brand: 'SoundBuds', stock: 80, tags: ['audio', 'electronics'], rating: 4.4, reviewCount: 76, orderCount: 380 },

    // Personal Care
    { name: 'Toothpaste', description: 'Whitening toothpaste with fluoride', image: 'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=400', price: 4.00, unit: 'tube', category: categoryMap['Personal Care'], store: stores[1]._id, brand: 'SmileBright', stock: 180, tags: ['dental', 'hygiene'], rating: 4.6, reviewCount: 134, orderCount: 620 },
    { name: 'Shampoo', description: 'Moisturizing hair shampoo', image: 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=400', price: 8.00, unit: 'bottle', category: categoryMap['Personal Care'], store: stores[0]._id, brand: 'HairCare', stock: 140, tags: ['haircare', 'hygiene'], rating: 4.7, reviewCount: 112, orderCount: 540 },
    { name: 'Bar Soap', description: 'Antibacterial soap bar', image: 'https://images.unsplash.com/photo-1585909695284-32d2985ac9c0?w=400', price: 2.50, unit: 'piece', category: categoryMap['Personal Care'], store: stores[1]._id, brand: 'CleanSoap', stock: 200, tags: ['soap', 'hygiene'], rating: 4.5, reviewCount: 98, orderCount: 480 },

    // Household
    { name: 'Toilet Paper 4-Pack', description: 'Soft and strong toilet tissue', image: 'https://images.unsplash.com/photo-1584556326561-c8746083993b?w=400', price: 6.00, unit: 'pack', category: categoryMap['Household'], store: stores[0]._id, brand: 'SoftTouch', stock: 150, tags: ['tissue', 'household'], rating: 4.6, reviewCount: 145, orderCount: 680 },
    { name: 'Dish Soap', description: 'Grease-cutting dish liquid', image: 'https://images.unsplash.com/photo-1585909695284-32d2985ac9c0?w=400', price: 4.50, unit: 'bottle', category: categoryMap['Household'], store: stores[1]._id, brand: 'CleanDish', stock: 120, tags: ['cleaning', 'household'], rating: 4.5, reviewCount: 87, orderCount: 420 },
    { name: 'Trash Bags', description: 'Heavy-duty garbage bags', image: 'https://images.unsplash.com/photo-1610557892470-55d9e80c0bce?w=400', price: 5.00, unit: 'pack', category: categoryMap['Household'], store: stores[0]._id, brand: 'StrongBag', stock: 130, tags: ['bags', 'household'], rating: 4.4, reviewCount: 76, orderCount: 380, discountPercentage: 8, discountEndDate: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000) },

    // Stationery
    { name: 'Ballpoint Pens 10-Pack', description: 'Blue ink ballpoint pens', image: 'https://images.unsplash.com/photo-1586075010923-2dd4570fb338?w=400', price: 3.00, unit: 'pack', category: categoryMap['Stationery'], store: stores[1]._id, brand: 'WritePro', stock: 160, tags: ['pens', 'stationery'], rating: 4.5, reviewCount: 92, orderCount: 450 },
    { name: 'Notebook A5', description: 'Ruled notebook 100 pages', image: 'https://images.unsplash.com/photo-1517842645767-c639042777db?w=400', price: 4.00, unit: 'piece', category: categoryMap['Stationery'], store: stores[0]._id, brand: 'NoteBook Pro', stock: 140, tags: ['notebook', 'stationery'], rating: 4.6, reviewCount: 78, orderCount: 390 },
    { name: 'Sticky Notes', description: 'Colorful adhesive notes', image: 'https://images.unsplash.com/photo-1586075010923-2dd4570fb338?w=400', price: 2.50, unit: 'pack', category: categoryMap['Stationery'], store: stores[1]._id, brand: 'StickyPad', stock: 180, tags: ['notes', 'stationery'], rating: 4.4, reviewCount: 65, orderCount: 320 },

    // Ice Cream & Desserts
    { name: 'Vanilla Ice Cream', description: 'Creamy vanilla ice cream', image: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400', price: 8.00, unit: 'pack', category: categoryMap['Ice Cream & Desserts'], store: stores[0]._id, brand: 'FrozenDelight', stock: 100, tags: ['ice-cream', 'dessert'], rating: 4.8, reviewCount: 156, orderCount: 720 },
    { name: 'Chocolate Ice Cream', description: 'Rich chocolate ice cream', image: 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=400', price: 8.00, unit: 'pack', category: categoryMap['Ice Cream & Desserts'], store: stores[1]._id, brand: 'FrozenDelight', stock: 90, tags: ['ice-cream', 'dessert'], rating: 4.9, reviewCount: 178, orderCount: 820 },
    { name: 'Ice Cream Sandwich', description: 'Vanilla ice cream between cookies', image: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=400', price: 3.50, unit: 'piece', category: categoryMap['Ice Cream & Desserts'], store: stores[0]._id, brand: 'SweetTreat', stock: 120, tags: ['ice-cream', 'dessert'], rating: 4.7, reviewCount: 134, orderCount: 620, discountPercentage: 20, discountEndDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000) },
];

async function seedItems() {
    try {
        const mongoUri = process.env.MONGODB_URI || "mongodb://localhost:27017/grabgo";
        await mongoose.connect(mongoUri);
        console.log('✅ Connected to MongoDB');

        // ========== PHARMACY ITEMS ==========
        console.log('\n📦 Seeding Pharmacy Items...');

        // Get pharmacy stores
        const pharmacyStores = await PharmacyStore.find().limit(2);
        if (pharmacyStores.length === 0) {
            console.log('⚠️  No pharmacy stores found. Please run setup-pharmacies.js first.');
        } else {
            // Get pharmacy categories
            const pharmacyCategories = await PharmacyCategory.find();
            const pharmacyCategoryMap = {};
            pharmacyCategories.forEach(cat => {
                pharmacyCategoryMap[cat.name] = cat._id;
            });

            // Clear existing pharmacy items
            await PharmacyItem.deleteMany({});

            // Insert pharmacy items
            const pharmacyItems = getPharmacyItems(pharmacyCategoryMap, pharmacyStores);
            const insertedPharmacyItems = await PharmacyItem.insertMany(pharmacyItems);
            console.log(`✅ Seeded ${insertedPharmacyItems.length} Pharmacy items`);
        }

        // ========== GRABMART ITEMS ==========
        console.log('\n📦 Seeding GrabMart Items...');

        // Get GrabMart stores
        const grabMartStores = await GrabMartStore.find().limit(2);
        if (grabMartStores.length === 0) {
            console.log('⚠️  No GrabMart stores found. Please run setup-grabmarts.js first.');
        } else {
            // Get GrabMart categories
            const grabMartCategories = await GrabMartCategory.find();
            const grabMartCategoryMap = {};
            grabMartCategories.forEach(cat => {
                grabMartCategoryMap[cat.name] = cat._id;
            });

            // Clear existing GrabMart items
            await GrabMartItem.deleteMany({});

            // Insert GrabMart items
            const grabMartItems = getGrabMartItems(grabMartCategoryMap, grabMartStores);
            const insertedGrabMartItems = await GrabMartItem.insertMany(grabMartItems);
            console.log(`✅ Seeded ${insertedGrabMartItems.length} GrabMart items`);
        }

        console.log('\n🎉 All items seeded successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error seeding items:', error);
        process.exit(1);
    }
}

seedItems();
