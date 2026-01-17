const path = require('path');
const dotenv = require('dotenv');

// Load env vars
const result = dotenv.config({ path: path.resolve(__dirname, '../.env') });
if (result.error) {
    console.error('❌ Error loading .env file:', result.error);
}

const mongoose = require('mongoose');
const GrabMartStore = require('../models/GrabMartStore');

// Helper function to create dates in the past
const daysAgo = (days) => {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return date;
};

const grabMartStores = [
    {
        storeName: "QuickStop GrabMart",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        description: "Your 24/7 convenience store for all your daily needs. ATM and bill payment available.",
        location: {
            type: 'Point',
            coordinates: [-0.1821, 5.5693],
            address: "89 Cantonments Road, Accra",
            city: "Accra",
            area: "Cantonments"
        },
        phone: "+233 24 789 0123",
        email: "info@quickstop.gh",
        businessIdNumber: "BID-GM-001",
        isOpen: true,
        deliveryFee: 3,
        minOrder: 5,
        rating: 4.7,
        totalReviews: 567,
        categories: ["Convenience", "Quick Shopping", "24/7 Service"],
        is24Hours: true,
        hasParking: true,
        paymentMethods: ["cash", "card", "mobile_money"],
        services: ["ATM", "Bill Payment", "Mobile Top-up", "Money Transfer"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household"],
        vendorType: "grabmart",
        status: "approved",
        createdAt: daysAgo(40),
        ratingSum: 2665,
        priorityScore: 10,
        orderAcceptanceRate: 99,
        orderCancellationRate: 1,
        features: ['parking', 'takeaway', 'wheelchair_accessible', 'air_conditioned'],
        tags: ['convenience', '24/7', 'essentials'],
        featured: true,
        isVerified: true,
        deliveryRadius: 5,
        averagePreparationTime: 5,
        averageDeliveryTime: 15,
        openingHours: {
            monday: { open: '00:00', close: '23:59', isClosed: false },
            tuesday: { open: '00:00', close: '23:59', isClosed: false },
            wednesday: { open: '00:00', close: '23:59', isClosed: false },
            thursday: { open: '00:00', close: '23:59', isClosed: false },
            friday: { open: '00:00', close: '23:59', isClosed: false },
            saturday: { open: '00:00', close: '23:59', isClosed: false },
            sunday: { open: '00:00', close: '23:59', isClosed: false }
        },
        socials: {
            facebook: 'https://facebook.com/quickstop',
            instagram: 'https://instagram.com/quickstop'
        }
    },
    {
        storeName: "Express Mart",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Fast service, great prices. Your neighborhood convenience store.",
        location: {
            type: 'Point',
            coordinates: [-0.1678, 5.5789],
            address: "45 Labone Junction, Accra",
            city: "Accra",
            area: "Labone"
        },
        phone: "+233 30 276 8901",
        email: "contact@expressmart.gh",
        businessIdNumber: "BID-GM-002",
        isOpen: true,
        deliveryFee: 4,
        minOrder: 10,
        rating: 4.5,
        totalReviews: 234,
        categories: ["Convenience", "Groceries", "Snacks"],
        is24Hours: false,
        hasParking: false,
        paymentMethods: ["cash", "card", "mobile_money"],
        services: ["Mobile Top-up", "Photocopying", "Printing"],
        productTypes: ["Snacks", "Beverages", "Stationery", "Personal Care"],
        vendorType: "grabmart",
        status: "approved",
        createdAt: daysAgo(28),
        ratingSum: 1053,
        priorityScore: 8,
        orderAcceptanceRate: 96,
        orderCancellationRate: 4,
        features: ['takeaway'],
        tags: ['express', ' snacks', 'drinks'],
        featured: false,
        isVerified: true,
        deliveryRadius: 4,
        averagePreparationTime: 5,
        averageDeliveryTime: 20,
        openingHours: {
            monday: { open: '07:00', close: '23:00', isClosed: false },
            tuesday: { open: '07:00', close: '23:00', isClosed: false },
            wednesday: { open: '07:00', close: '23:00', isClosed: false },
            thursday: { open: '07:00', close: '23:00', isClosed: false },
            friday: { open: '07:00', close: '23:00', isClosed: false },
            saturday: { open: '08:00', close: '23:00', isClosed: false },
            sunday: { open: '08:00', close: '22:00', isClosed: false }
        },
        socials: {
            instagram: 'https://instagram.com/expressmart'
        }
    },
    {
        storeName: "Metro GrabMart",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "Premium convenience store with a wide range of products and services.",
        location: {
            type: 'Point',
            coordinates: [-0.1734, 5.6012],
            address: "12 Airport Residential Area, Accra",
            city: "Accra",
            area: "Airport Residential"
        },
        phone: "+233 20 345 6789",
        email: "hello@metrograbmart.gh",
        businessIdNumber: "BID-GM-003",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 15,
        rating: 4.8,
        totalReviews: 892,
        categories: ["Premium", "Convenience", "Electronics"],
        is24Hours: true,
        hasParking: true,
        paymentMethods: ["cash", "card", "mobile_money"],
        services: ["ATM", "Bill Payment", "Mobile Top-up", "Money Transfer", "Photocopying", "Printing"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household", "Electronics", "Stationery"],
        vendorType: "grabmart",
        status: "approved",
        createdAt: daysAgo(55),
        ratingSum: 4281,
        priorityScore: 11,
        orderAcceptanceRate: 98,
        orderCancellationRate: 2,
        features: ['parking', 'takeaway', 'wheelchair_accessible', 'air_conditioned'],
        tags: ['premium', 'metro', 'electronics'],
        featured: true,
        isVerified: true,
        deliveryRadius: 8,
        averagePreparationTime: 10,
        averageDeliveryTime: 25,
        openingHours: {
            monday: { open: '00:00', close: '23:59', isClosed: false },
            tuesday: { open: '00:00', close: '23:59', isClosed: false },
            wednesday: { open: '00:00', close: '23:59', isClosed: false },
            thursday: { open: '00:00', close: '23:59', isClosed: false },
            friday: { open: '00:00', close: '23:59', isClosed: false },
            saturday: { open: '00:00', close: '23:59', isClosed: false },
            sunday: { open: '00:00', close: '23:59', isClosed: false }
        },
        socials: {
            facebook: 'https://facebook.com/metrograbmart',
            twitter: 'https://twitter.com/metrograbmart'
        }
    }
];

async function setupGrabMarts() {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');

        await GrabMartStore.deleteMany({});
        console.log('🗑️  Cleared existing GrabMart stores');

        const createdStores = [];
        for (const storeData of grabMartStores) {
            const store = new GrabMartStore(storeData);
            store.createdAt = storeData.createdAt;
            store.updatedAt = storeData.createdAt;
            await store.save({ timestamps: false });
            createdStores.push(store);
        }

        console.log(`✅ Created ${createdStores.length} GrabMart stores`);

        console.log('\n📋 Created GrabMart Stores:');
        createdStores.forEach((store, index) => {
            console.log(`${index + 1}. ${store.storeName} (${store.location.address})`);
            console.log(`   Rating: ${store.rating} ⭐ | Reviews: ${store.totalReviews}`);
            console.log(`   24/7: ${store.is24Hours ? 'Yes ✅' : 'No ❌'}`);
            console.log('');
        });

        console.log('✅ GrabMart stores setup completed successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error setting up GrabMart stores:', error);
        process.exit(1);
    }
}

setupGrabMarts();
