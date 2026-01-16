const mongoose = require('mongoose');
const GrabMartStore = require('../models/GrabMartStore');
require('dotenv').config();

const grabMartStores = [
    {
        store_name: "QuickStop GrabMart",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/grabmart/quickstop-logo.jpg",
        description: "Your 24/7 convenience store for all your daily needs. ATM and bill payment available.",
        address: "89 Cantonments Road, Accra",
        phone: "+233 24 789 0123",
        email: "info@quickstop.gh",
        isOpen: true,
        deliveryFee: 3,
        minOrder: 5,
        rating: 4.7,
        totalReviews: 567,
        categories: ["Convenience", "Quick Shopping", "24/7 Service"],
        latitude: 5.5693,
        longitude: -0.1821,
        operatingHours: "24/7",
        is24Hours: true,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["ATM", "Bill Payment", "Mobile Top-up", "Money Transfer"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household"]
    },
    {
        store_name: "Express Mart",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/grabmart/expressmart-logo.jpg",
        description: "Fast service, great prices. Your neighborhood convenience store.",
        address: "45 Labone Junction, Accra",
        phone: "+233 30 276 8901",
        email: "contact@expressmart.gh",
        isOpen: true,
        deliveryFee: 4,
        minOrder: 10,
        rating: 4.5,
        totalReviews: 234,
        categories: ["Convenience", "Groceries", "Snacks"],
        latitude: 5.5789,
        longitude: -0.1678,
        operatingHours: "6AM-12AM",
        is24Hours: false,
        hasParking: false,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up", "Photocopying", "Printing"],
        productTypes: ["Snacks", "Beverages", "Stationery", "Personal Care"]
    },
    {
        store_name: "Metro GrabMart",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/grabmart/metro-logo.jpg",
        description: "Premium convenience store with a wide range of products and services.",
        address: "12 Airport Residential Area, Accra",
        phone: "+233 20 345 6789",
        email: "hello@metrograbmart.gh",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 15,
        rating: 4.8,
        totalReviews: 892,
        categories: ["Premium", "Convenience", "Electronics"],
        latitude: 5.6012,
        longitude: -0.1734,
        operatingHours: "24/7",
        is24Hours: true,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["ATM", "Bill Payment", "Mobile Top-up", "Money Transfer", "Photocopying", "Printing"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household", "Electronics", "Stationery"]
    },
    {
        store_name: "Corner Shop",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/grabmart/cornershop-logo.jpg",
        description: "Your friendly neighborhood store for everyday essentials.",
        address: "78 Dansoman Roundabout, Accra",
        phone: "+233 27 654 3210",
        email: "info@cornershop.gh",
        isOpen: true,
        deliveryFee: 2,
        minOrder: 5,
        rating: 4.3,
        totalReviews: 145,
        categories: ["Neighborhood", "Essentials"],
        latitude: 5.5456,
        longitude: -0.2890,
        operatingHours: "7AM-10PM",
        is24Hours: false,
        hasParking: false,
        acceptsCash: true,
        acceptsCard: false,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up"],
        productTypes: ["Snacks", "Beverages", "Household"]
    },
    {
        store_name: "Night Owl Mart",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/grabmart/nightowl-logo.jpg",
        description: "Open all night for your convenience. Late-night snacks and essentials.",
        address: "23 Osu Oxford Street, Accra",
        phone: "+233 24 111 2222",
        email: "support@nightowl.gh",
        isOpen: true,
        deliveryFee: 6,
        minOrder: 8,
        rating: 4.9,
        totalReviews: 1023,
        categories: ["24/7", "Late Night", "Snacks"],
        latitude: 5.5589,
        longitude: -0.1756,
        operatingHours: "24/7",
        is24Hours: true,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["ATM", "Bill Payment", "Mobile Top-up"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Tobacco"]
    },
    {
        store_name: "Campus Mart",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/grabmart/campus-logo.jpg",
        description: "Student-friendly prices and services. Printing, photocopying, and more!",
        address: "University of Ghana, Legon",
        phone: "+233 30 987 6543",
        email: "info@campusmart.gh",
        isOpen: true,
        deliveryFee: 3,
        minOrder: 5,
        rating: 4.6,
        totalReviews: 678,
        categories: ["Student", "Campus", "Stationery"],
        latitude: 5.6512,
        longitude: -0.1867,
        operatingHours: "7AM-11PM",
        is24Hours: false,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up", "Photocopying", "Printing"],
        productTypes: ["Snacks", "Beverages", "Stationery", "Personal Care"]
    },
    {
        store_name: "Prime Stop",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/grabmart/primestop-logo.jpg",
        description: "Premium convenience with exceptional service. All payment methods accepted.",
        address: "67 East Legon, Accra",
        phone: "+233 20 555 4444",
        email: "contact@primestop.gh",
        isOpen: true,
        deliveryFee: 7,
        minOrder: 20,
        rating: 4.8,
        totalReviews: 445,
        categories: ["Premium", "Upscale"],
        latitude: 5.6234,
        longitude: -0.1523,
        operatingHours: "24/7",
        is24Hours: true,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["ATM", "Bill Payment", "Mobile Top-up", "Money Transfer"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household", "Electronics"]
    }
];

async function setupGrabMarts() {
    try {
        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');

        // Clear existing GrabMart stores
        await GrabMartStore.deleteMany({});
        console.log('🗑️  Cleared existing GrabMart stores');

        // Insert new GrabMart stores
        const createdStores = await GrabMartStore.insertMany(grabMartStores);
        console.log(`✅ Created ${createdStores.length} GrabMart stores`);

        // Display created stores
        console.log('\n📋 Created GrabMart Stores:');
        createdStores.forEach((store, index) => {
            console.log(`${index + 1}. ${store.store_name} (${store.address})`);
            console.log(`   Rating: ${store.rating} ⭐ | Reviews: ${store.totalReviews}`);
            console.log(`   24/7: ${store.is24Hours ? 'Yes ✅' : 'No ❌'} | Parking: ${store.hasParking ? 'Yes ✅' : 'No ❌'}`);
            console.log(`   Services: ${store.services.join(', ')}`);
            console.log(`   Products: ${store.productTypes.join(', ')}`);
            console.log('');
        });

        console.log('✅ GrabMart stores setup completed successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error setting up GrabMart stores:', error);
        process.exit(1);
    }
}

// Run the setup
setupGrabMarts();
