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
        businessIdNumber: "BID-HP-001",
        pharmacistName: "Dr. Kwame Mensah",
        pharmacistLicense: "PHARM-GH-12345",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Star Assurance"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(45),
        ratingSum: 1176,
        priorityScore: 10,
        orderAcceptanceRate: 98,
        orderCancellationRate: 2,
        features: ['takeaway', 'wheelchair_accessible', 'parking'],
        tags: ['pharmacy', 'health', '24/7'],
        featured: true,
        isVerified: true,
        deliveryRadius: 10,
        paymentMethods: ['cash', 'card', 'mobile_money'],
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
            facebook: 'https://facebook.com/healthplus',
            instagram: 'https://instagram.com/healthplus'
        }
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
        businessIdNumber: "BID-MC-002",
        pharmacistName: "Dr. Ama Asante",
        pharmacistLicense: "PHARM-GH-23456",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Metropolitan Insurance"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(30),
        ratingSum: 869,
        priorityScore: 8,
        orderAcceptanceRate: 95,
        orderCancellationRate: 5,
        features: ['parking'],
        tags: ['pharmacy', 'health'],
        featured: false,
        isVerified: true,
        deliveryRadius: 8,
        paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        },
        socials: {
            instagram: 'https://instagram.com/medicare'
        }
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
        businessIdNumber: "BID-WP-003",
        pharmacistName: "Dr. Yaw Boateng",
        pharmacistLicense: "PHARM-GH-34567",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Hollard Insurance"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(60),
        ratingSum: 1466,
        priorityScore: 9,
        orderAcceptanceRate: 97,
        orderCancellationRate: 3,
        features: ['wheelchair_accessible', 'parking'],
        tags: ['wellness', 'supplements', 'herbal'],
        featured: true,
        isVerified: true,
        deliveryRadius: 10,
        paymentMethods: ['cash', 'card', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '23:00', isClosed: false },
            saturday: { open: '09:00', close: '23:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: {
            facebook: 'https://facebook.com/wellness',
        }
    },
    {
        storeName: "City Care Pharmacy",
        logo: "https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=800",
        description: "Your partner in health, providing quality medicines and healthcare advice.",
        location: {
            type: 'Point',
            coordinates: [-0.1969, 5.5560],
            address: "22 Cantonments Road, Osu",
            city: "Accra",
            area: "Osu"
        },
        phone: "+233 24 555 1212",
        email: "citycare@example.com",
        isOpen: true,
        deliveryFee: 7,
        minOrder: 15,
        rating: 4.5,
        totalReviews: 120,
        categories: ["Prescription Drugs", "First Aid", "Vitamins"],
        licenseNumber: "PH-ACC-2024-004",
        businessIdNumber: "BID-CC-004",
        pharmacistName: "Dr. Kofi Annan",
        pharmacistLicense: "PHARM-GH-45678",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Allianz"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(20),
        ratingSum: 540,
        priorityScore: 7,
        orderAcceptanceRate: 96,
        orderCancellationRate: 4,
        features: ['takeaway'],
        tags: ['health', 'care'],
        featured: false,
        isVerified: true,
        deliveryRadius: 8,
        paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '20:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        },
        socials: {
            instagram: 'https://instagram.com/citycare'
        }
    },
    {
        storeName: "Royal Pharma",
        logo: "https://images.unsplash.com/photo-1628771065518-0d82f1938462?w=800",
        description: "Premium pharmacy services with a wide range of international brands.",
        location: {
            type: 'Point',
            coordinates: [-0.1500, 5.6500],
            address: "15 Lagos Avenue, East Legon",
            city: "Accra",
            area: "East Legon"
        },
        phone: "+233 50 123 9876",
        email: "royalpharma@example.com",
        isOpen: true,
        deliveryFee: 10,
        minOrder: 25,
        rating: 4.9,
        totalReviews: 350,
        categories: ["Prescription Drugs", "Cosmetics", "Supplements"],
        licenseNumber: "PH-ACC-2024-005",
        businessIdNumber: "BID-RP-005",
        pharmacistName: "Dr. Esi Mensah",
        pharmacistLicense: "PHARM-GH-56789",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Prudential", "Acacia"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(10),
        ratingSum: 1715,
        priorityScore: 11,
        orderAcceptanceRate: 99,
        orderCancellationRate: 1,
        features: ['air_conditioned', 'parking'],
        tags: ['premium', 'pharmacy'],
        featured: true,
        isVerified: true,
        deliveryRadius: 15,
        paymentMethods: ['cash', 'card', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '23:00', isClosed: false },
            saturday: { open: '09:00', close: '23:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: {
            facebook: 'https://facebook.com/royalpharma',
            instagram: 'https://instagram.com/royalpharma'
        }
    },
    {
        storeName: "Trust Chemist",
        logo: "https://images.unsplash.com/photo-1530497610245-94d3c16cda28?w=800",
        description: "Accessible and affordable medication for everyone.",
        location: {
            type: 'Point',
            coordinates: [-0.2195, 5.5900],
            address: "88 Achimota Road, Achimota",
            city: "Accra",
            area: "Achimota"
        },
        phone: "+233 27 765 4321",
        email: "trustchemist@example.com",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 10,
        rating: 4.3,
        totalReviews: 95,
        categories: ["Prescription Drugs", "OTC Medications", "Household"],
        licenseNumber: "PH-ACC-2024-006",
        businessIdNumber: "BID-TC-006",
        pharmacistName: "Dr. Kwesi Appiah",
        pharmacistLicense: "PHARM-GH-67890",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(50),
        ratingSum: 408,
        priorityScore: 6,
        orderAcceptanceRate: 94,
        orderCancellationRate: 6,
        features: ['takeaway'],
        tags: ['affordable', 'chemist'],
        featured: false,
        isVerified: true,
        deliveryRadius: 6,
        paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '20:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        },
        socials: {
            instagram: 'https://instagram.com/trustchemist'
        }
    },
    {
        storeName: "Family Care Pharmacy",
        logo: "https://images.unsplash.com/photo-1555633514-abcea88cd0a1?w=800",
        description: "Caring for your family's health with personalized service.",
        location: {
            type: 'Point',
            coordinates: [-0.1300, 5.6800],
            address: "5 Madina Market Road, Madina",
            city: "Accra",
            area: "Madina"
        },
        phone: "+233 26 111 2222",
        email: "familycare@example.com",
        isOpen: true,
        deliveryFee: 4,
        minOrder: 10,
        rating: 4.4,
        totalReviews: 150,
        categories: ["Prescription Drugs", "Baby Care", "Maternal Health"],
        licenseNumber: "PH-ACC-2024-007",
        businessIdNumber: "BID-FC-007",
        pharmacistName: "Dr. Akosua Darko",
        pharmacistLicense: "PHARM-GH-78901",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(40),
        ratingSum: 660,
        priorityScore: 7,
        orderAcceptanceRate: 95,
        orderCancellationRate: 5,
        features: ['takeaway', 'wheelchair_accessible'],
        tags: ['family', 'pharmacy'],
        featured: false,
        isVerified: true,
        deliveryRadius: 8,
        paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '21:00', isClosed: false },
            tuesday: { open: '08:00', close: '21:00', isClosed: false },
            wednesday: { open: '08:00', close: '21:00', isClosed: false },
            thursday: { open: '08:00', close: '21:00', isClosed: false },
            friday: { open: '08:00', close: '22:00', isClosed: false },
            saturday: { open: '09:00', close: '21:00', isClosed: false },
            sunday: { open: '12:00', close: '18:00', isClosed: false }
        },
        socials: {
            facebook: 'https://facebook.com/familycare'
        }
    },
    {
        storeName: "LifeWell Pharmacy",
        logo: "https://images.unsplash.com/photo-1585435557343-3b092031a831?w=800",
        description: "Your comprehensive source for wellness and vitality.",
        location: {
            type: 'Point',
            coordinates: [-0.0166, 5.6698],
            address: "10 Community 1, Tema",
            city: "Tema",
            area: "Community 1"
        },
        phone: "+233 24 999 8888",
        email: "lifewell@example.com",
        isOpen: true,
        deliveryFee: 6,
        minOrder: 15,
        rating: 4.7,
        totalReviews: 210,
        categories: ["Prescription Drugs", "Vitamins", "Sports Nutrition"],
        licenseNumber: "PH-ACC-2024-008",
        businessIdNumber: "BID-LW-008",
        pharmacistName: "Dr. Kojo Boakye",
        pharmacistLicense: "PHARM-GH-89012",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Phoenix"],
        vendorType: "pharmacy",
        status: "approved",
        createdAt: daysAgo(25),
        ratingSum: 987,
        priorityScore: 9,
        orderAcceptanceRate: 97,
        orderCancellationRate: 3,
        features: ['parking', 'takeaway'],
        tags: ['wellness', 'sports'],
        featured: true,
        isVerified: true,
        deliveryRadius: 10,
        paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '22:00', isClosed: false },
            saturday: { open: '09:00', close: '22:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: {
            instagram: 'https://instagram.com/lifewell'
        }
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
