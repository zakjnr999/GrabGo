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
        store_name: "QuickStop GrabMart",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
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
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household"],
        createdAt: daysAgo(40)
    },
    {
        store_name: "Express Mart",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
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
        productTypes: ["Snacks", "Beverages", "Stationery", "Personal Care"],
        createdAt: daysAgo(28)
    },
    {
        store_name: "Metro GrabMart",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
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
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household", "Electronics", "Stationery"],
        createdAt: daysAgo(55)
    },
    {
        store_name: "Corner Shop",
        logo: "https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=800",
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
        productTypes: ["Snacks", "Beverages", "Household"],
        createdAt: daysAgo(18)
    },
    {
        store_name: "Night Owl Mart",
        logo: "https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=800",
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
        productTypes: ["Snacks", "Beverages", "Personal Care", "Tobacco"],
        createdAt: daysAgo(7)
    },
    {
        store_name: "Campus Mart",
        logo: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800",
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
        productTypes: ["Snacks", "Beverages", "Stationery", "Personal Care"],
        createdAt: daysAgo(70)
    },
    {
        store_name: "Prime Stop",
        logo: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800",
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
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household", "Electronics"],
        createdAt: daysAgo(14)
    },
    {
        store_name: "FreshGo Mart",
        logo: "https://images.unsplash.com/photo-1556740749-887f6717d7e4?w=800",
        description: "Fresh food and groceries available round the clock.",
        address: "34 Spintex Road, Accra",
        phone: "+233 24 666 7788",
        email: "info@freshgo.gh",
        isOpen: true,
        deliveryFee: 4,
        minOrder: 8,
        rating: 4.7,
        totalReviews: 389,
        categories: ["Fresh Food", "Groceries", "Quick Shopping"],
        latitude: 5.6389,
        longitude: -0.0892,
        operatingHours: "24/7",
        is24Hours: true,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up", "Bill Payment", "Fresh Food Delivery"],
        productTypes: ["Fresh Produce", "Snacks", "Beverages", "Dairy", "Bakery"],
        createdAt: daysAgo(6)
    },
    {
        store_name: "TechStop Mart",
        logo: "https://images.unsplash.com/photo-1601524909162-ae8725290836?w=800",
        description: "Your one-stop shop for tech accessories and gadgets.",
        address: "12 Achimota Mall, Accra",
        phone: "+233 30 888 9999",
        email: "contact@techstop.gh",
        isOpen: true,
        deliveryFee: 6,
        minOrder: 15,
        rating: 4.6,
        totalReviews: 512,
        categories: ["Electronics", "Tech Accessories", "Gadgets"],
        latitude: 5.6789,
        longitude: -0.2234,
        operatingHours: "8AM-10PM",
        is24Hours: false,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up", "Phone Repairs", "Tech Support"],
        productTypes: ["Electronics", "Accessories", "Chargers", "Cables", "Earphones"],
        createdAt: daysAgo(22)
    },
    {
        store_name: "SnackHub",
        logo: "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=800",
        description: "The ultimate destination for snacks and treats.",
        address: "45 Madina Market, Accra",
        phone: "+233 27 777 8888",
        email: "hello@snackhub.gh",
        isOpen: true,
        deliveryFee: 3,
        minOrder: 5,
        rating: 4.5,
        totalReviews: 623,
        categories: ["Snacks", "Treats", "Beverages"],
        latitude: 5.6812,
        longitude: -0.1677,
        operatingHours: "7AM-11PM",
        is24Hours: false,
        hasParking: false,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up", "Home Delivery"],
        productTypes: ["Snacks", "Chips", "Candy", "Chocolate", "Beverages", "Ice Cream"],
        createdAt: daysAgo(48)
    },
    {
        store_name: "EcoMart",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "Eco-friendly products and sustainable living essentials.",
        address: "78 Cantonments Circle, Accra",
        phone: "+233 24 999 0000",
        email: "info@ecomart.gh",
        isOpen: true,
        deliveryFee: 8,
        minOrder: 20,
        rating: 4.8,
        totalReviews: 298,
        categories: ["Eco-Friendly", "Sustainable", "Organic"],
        latitude: 5.5693,
        longitude: -0.1821,
        operatingHours: "8AM-8PM",
        is24Hours: false,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Recycling", "Eco Consultations"],
        productTypes: ["Organic Products", "Reusable Items", "Natural Care", "Eco Snacks"],
        createdAt: daysAgo(85)
    },
    {
        store_name: "DrinkZone",
        logo: "https://images.unsplash.com/photo-1554866585-cd94860890b7?w=800",
        description: "Wide selection of beverages from soft drinks to energy drinks.",
        address: "23 Tema Community 4, Tema",
        phone: "+233 20 111 2222",
        email: "contact@drinkzone.gh",
        isOpen: true,
        deliveryFee: 4,
        minOrder: 10,
        rating: 4.4,
        totalReviews: 445,
        categories: ["Beverages", "Drinks", "Refreshments"],
        latitude: 5.6698,
        longitude: -0.0166,
        operatingHours: "6AM-12AM",
        is24Hours: false,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up", "Bulk Orders"],
        productTypes: ["Soft Drinks", "Energy Drinks", "Juices", "Water", "Sports Drinks"],
        createdAt: daysAgo(33)
    },
    {
        store_name: "OfficeHub Mart",
        logo: "https://images.unsplash.com/photo-1586075010923-2dd4570fb338?w=800",
        description: "Complete office supplies and stationery for professionals and students.",
        address: "56 Ring Road, Accra",
        phone: "+233 30 333 4444",
        email: "info@officehub.gh",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 12,
        rating: 4.7,
        totalReviews: 367,
        categories: ["Office Supplies", "Stationery", "Business"],
        latitude: 5.6037,
        longitude: -0.1870,
        operatingHours: "Mon-Sat: 7AM-9PM, Sun: 9AM-5PM",
        is24Hours: false,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Photocopying", "Printing", "Binding", "Lamination"],
        productTypes: ["Stationery", "Office Supplies", "Paper Products", "Writing Tools"],
        createdAt: daysAgo(11)
    },
    {
        store_name: "HealthyBite Mart",
        logo: "https://images.unsplash.com/photo-1546793665-c74683f339c1?w=800",
        description: "Healthy snacks and organic food options for wellness-conscious customers.",
        address: "89 East Legon Extension, Accra",
        phone: "+233 24 555 6666",
        email: "hello@healthybite.gh",
        isOpen: true,
        deliveryFee: 7,
        minOrder: 18,
        rating: 4.9,
        totalReviews: 289,
        categories: ["Healthy", "Organic", "Wellness"],
        latitude: 5.6234,
        longitude: -0.1523,
        operatingHours: "7AM-10PM",
        is24Hours: false,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["Nutrition Advice", "Meal Plans"],
        productTypes: ["Healthy Snacks", "Organic Food", "Protein Bars", "Smoothies", "Salads"],
        createdAt: daysAgo(4)
    },
    {
        store_name: "MidnightMart",
        logo: "https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=800",
        description: "Late-night essentials when you need them most.",
        address: "34 Osu Oxford Street, Accra",
        phone: "+233 27 777 8888",
        email: "support@midnightmart.gh",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 8,
        rating: 4.6,
        totalReviews: 734,
        categories: ["24/7", "Late Night", "Emergency"],
        latitude: 5.5589,
        longitude: -0.1756,
        operatingHours: "24/7",
        is24Hours: true,
        hasParking: false,
        acceptsCash: true,
        acceptsCard: true,
        acceptsMobileMoney: true,
        services: ["ATM", "Emergency Delivery"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Medicine", "Household"],
        createdAt: daysAgo(9)
    },
    {
        store_name: "ValueMart Express",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Best value for money with everyday low prices.",
        address: "67 Kasoa Main Road, Kasoa",
        phone: "+233 24 888 9999",
        email: "info@valuemart.gh",
        isOpen: true,
        deliveryFee: 3,
        minOrder: 5,
        rating: 4.3,
        totalReviews: 567,
        categories: ["Budget", "Value", "Essentials"],
        latitude: 5.5312,
        longitude: -0.4123,
        operatingHours: "6AM-11PM",
        is24Hours: false,
        hasParking: true,
        acceptsCash: true,
        acceptsCard: false,
        acceptsMobileMoney: true,
        services: ["Mobile Top-up", "Bill Payment"],
        productTypes: ["Snacks", "Beverages", "Household", "Personal Care", "Basic Groceries"],
        createdAt: daysAgo(62)
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

        // Insert new GrabMart stores with custom createdAt dates
        const createdStores = [];
        for (const storeData of grabMartStores) {
            const store = new GrabMartStore(storeData);
            // Manually set createdAt and updatedAt to match
            store.createdAt = storeData.createdAt;
            store.updatedAt = storeData.createdAt;
            await store.save({ timestamps: false });
            createdStores.push(store);
        }

        console.log(`✅ Created ${createdStores.length} GrabMart stores`);

        // Display created stores
        console.log('\n📋 Created GrabMart Stores:');
        createdStores.forEach((store, index) => {
            console.log(`${index + 1}. ${store.store_name} (${store.address})`);
            console.log(`   Rating: ${store.rating} ⭐ | Reviews: ${store.totalReviews}`);
            console.log(`   24/7: ${store.is24Hours ? 'Yes ✅' : 'No ❌'} | Parking: ${store.hasParking ? 'Yes ✅' : 'No ❌'}`);
            console.log(`   Services: ${store.services.join(', ')}`);
            console.log(`   Products: ${store.productTypes.join(', ')}`);
            console.log(`   Created: ${store.createdAt.toLocaleDateString()}`);
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
