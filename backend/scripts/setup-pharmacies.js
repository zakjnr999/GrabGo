const path = require('path');
const dotenv = require('dotenv');

// Load env vars
const result = dotenv.config({ path: path.resolve(__dirname, '../.env') });
if (result.error) {
    console.error('❌ Error loading .env file:', result.error);
}

const mongoose = require('mongoose');
const PharmacyStore = require('../models/PharmacyStore');

// Helper function to create dates in the past
const daysAgo = (days) => {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return date;
};

const pharmacyStores = [
    {
        storeName: "HealthPlus Pharmacy",
        logo: "https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800",
        description: "Your trusted neighborhood pharmacy with 24/7 emergency services and prescription delivery.",
        location: {
            type: 'Point',
            coordinates: [-0.1769, 5.5557],
            address: "123 Oxford Street, Osu",
            city: "Accra",
            area: "Osu"
        },
        phone: "+233 24 123 4567",
        email: "info@healthplus.com.gh",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 10,
        rating: 4.8,
        totalReviews: 245,
        categories: ["Prescription Drugs", "OTC Medications", "Health Supplements", "Medical Devices"],
        licenseNumber: "PH-ACC-2024-001",
        pharmacistName: "Dr. Kwame Mensah",
        pharmacistLicense: "PHARM-GH-12345",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Star Assurance"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(45)
    },
    {
        storeName: "MediCare Pharmacy",
        logo: "https://images.unsplash.com/photo-1586015555751-63bb77f4322a?w=800",
        description: "Quality healthcare products and professional pharmaceutical services.",
        location: {
            type: 'Point',
            coordinates: [-0.1870, 5.6037],
            address: "45 Ring Road Central, Accra",
            city: "Accra",
            area: "Central Business District"
        },
        phone: "+233 30 276 5432",
        email: "contact@medicare.com.gh",
        isOpen: true,
        deliveryFee: 8,
        minOrder: 15,
        rating: 4.6,
        totalReviews: 189,
        categories: ["Prescription Drugs", "Baby Care", "Personal Care", "First Aid"],
        licenseNumber: "PH-ACC-2024-002",
        pharmacistName: "Dr. Ama Asante",
        pharmacistLicense: "PHARM-GH-23456",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Metropolitan Insurance"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(30)
    },
    {
        storeName: "Wellness Pharmacy",
        logo: "https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=800",
        description: "Comprehensive pharmacy services with focus on wellness and preventive care.",
        location: {
            type: 'Point',
            coordinates: [-0.0892, 5.6389],
            address: "78 Spintex Road, Accra",
            city: "Accra",
            area: "Spintex"
        },
        phone: "+233 20 987 6543",
        email: "info@wellnesspharmacy.gh",
        isOpen: true,
        deliveryFee: 6,
        minOrder: 12,
        rating: 4.7,
        totalReviews: 312,
        categories: ["Prescription Drugs", "Vitamins", "Herbal Medicine", "Beauty Products"],
        licenseNumber: "PH-ACC-2024-003",
        pharmacistName: "Dr. Yaw Boateng",
        pharmacistLicense: "PHARM-GH-34567",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Hollard Insurance"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(60)
    }
];

async function setupPharmacies() {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');

        await PharmacyStore.deleteMany({});
        console.log('🗑️  Cleared existing pharmacy stores');

        const createdStores = [];
        for (const storeData of pharmacyStores) {
            const store = new PharmacyStore(storeData);
            store.createdAt = storeData.createdAt;
            store.updatedAt = storeData.createdAt;
            await store.save({ timestamps: false });
            createdStores.push(store);
        }

        console.log(`✅ Created ${createdStores.length} pharmacy stores`);

        console.log('\n📋 Created Pharmacy Stores:');
        createdStores.forEach((store, index) => {
            console.log(`${index + 1}. ${store.storeName} (${store.location.address})`);
            console.log(`   Rating: ${store.rating} ⭐ | Reviews: ${store.totalReviews}`);
            console.log(`   Emergency: ${store.emergencyService ? 'Yes ✅' : 'No ❌'}`);
            console.log(`   License: ${store.licenseNumber}`);
            console.log('');
        });

        console.log('✅ Pharmacy stores setup completed successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error setting up pharmacy stores:', error);
        process.exit(1);
    }
}

setupPharmacies();
