const mongoose = require('mongoose');
const PharmacyStore = require('../models/PharmacyStore');
require('dotenv').config();

const pharmacyStores = [
    {
        store_name: "HealthPlus Pharmacy",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/pharmacies/healthplus-logo.jpg",
        description: "Your trusted neighborhood pharmacy with 24/7 emergency services and prescription delivery.",
        address: "123 Oxford Street, Osu",
        phone: "+233 24 123 4567",
        email: "info@healthplus.com.gh",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 10,
        rating: 4.8,
        totalReviews: 245,
        categories: ["Prescription Drugs", "OTC Medications", "Health Supplements", "Medical Devices"],
        latitude: 5.5557,
        longitude: -0.1769,
        licenseNumber: "PH-ACC-2024-001",
        pharmacistName: "Dr. Kwame Mensah",
        pharmacistLicense: "PHARM-GH-12345",
        operatingHours: "24/7",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Star Assurance"]
    },
    {
        store_name: "MediCare Pharmacy",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/pharmacies/medicare-logo.jpg",
        description: "Quality healthcare products and professional pharmaceutical services.",
        address: "45 Ring Road Central, Accra",
        phone: "+233 30 276 5432",
        email: "contact@medicare.com.gh",
        isOpen: true,
        deliveryFee: 8,
        minOrder: 15,
        rating: 4.6,
        totalReviews: 189,
        categories: ["Prescription Drugs", "Baby Care", "Personal Care", "First Aid"],
        latitude: 5.6037,
        longitude: -0.1870,
        licenseNumber: "PH-ACC-2024-002",
        pharmacistName: "Dr. Ama Asante",
        pharmacistLicense: "PHARM-GH-23456",
        operatingHours: "Mon-Sat: 8AM-10PM, Sun: 9AM-6PM",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Metropolitan Insurance"]
    },
    {
        store_name: "Wellness Pharmacy",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/pharmacies/wellness-logo.jpg",
        description: "Comprehensive pharmacy services with focus on wellness and preventive care.",
        address: "78 Spintex Road, Accra",
        phone: "+233 20 987 6543",
        email: "info@wellnesspharmacy.gh",
        isOpen: true,
        deliveryFee: 6,
        minOrder: 12,
        rating: 4.7,
        totalReviews: 312,
        categories: ["Prescription Drugs", "Vitamins", "Herbal Medicine", "Beauty Products"],
        latitude: 5.6389,
        longitude: -0.0892,
        licenseNumber: "PH-ACC-2024-003",
        pharmacistName: "Dr. Yaw Boateng",
        pharmacistLicense: "PHARM-GH-34567",
        operatingHours: "24/7",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Hollard Insurance"]
    },
    {
        store_name: "City Pharmacy",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/pharmacies/city-logo.jpg",
        description: "Fast and reliable pharmacy services in the heart of the city.",
        address: "12 Independence Avenue, Accra",
        phone: "+233 24 555 7890",
        email: "hello@citypharmacy.gh",
        isOpen: true,
        deliveryFee: 7,
        minOrder: 10,
        rating: 4.5,
        totalReviews: 156,
        categories: ["Prescription Drugs", "OTC Medications", "Medical Equipment", "Diabetic Care"],
        latitude: 5.5600,
        longitude: -0.2057,
        licenseNumber: "PH-ACC-2024-004",
        pharmacistName: "Dr. Efua Owusu",
        pharmacistLicense: "PHARM-GH-45678",
        operatingHours: "Mon-Fri: 7AM-11PM, Sat-Sun: 8AM-9PM",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Star Assurance"]
    },
    {
        store_name: "Express Pharmacy",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/pharmacies/express-logo.jpg",
        description: "Quick prescription filling and emergency medication delivery.",
        address: "34 Tema Station Road, Accra",
        phone: "+233 27 444 3210",
        email: "support@expresspharmacy.gh",
        isOpen: true,
        deliveryFee: 4,
        minOrder: 8,
        rating: 4.9,
        totalReviews: 428,
        categories: ["Prescription Drugs", "Emergency Medications", "Pain Relief", "Antibiotics"],
        latitude: 5.6500,
        longitude: -0.0500,
        licenseNumber: "PH-ACC-2024-005",
        pharmacistName: "Dr. Kofi Adjei",
        pharmacistLicense: "PHARM-GH-56789",
        operatingHours: "24/7",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Metropolitan Insurance", "Hollard Insurance"]
    },
    {
        store_name: "Family Care Pharmacy",
        logo: "https://res.cloudinary.com/grabgo/image/upload/v1/pharmacies/familycare-logo.jpg",
        description: "Your family's health is our priority. Comprehensive pharmaceutical care.",
        address: "56 Achimota Mile 7, Accra",
        phone: "+233 30 298 7654",
        email: "info@familycare.gh",
        isOpen: true,
        deliveryFee: 10,
        minOrder: 20,
        rating: 4.4,
        totalReviews: 98,
        categories: ["Prescription Drugs", "Pediatric Care", "Maternal Health", "Elderly Care"],
        latitude: 5.6789,
        longitude: -0.2234,
        licenseNumber: "PH-ACC-2024-006",
        pharmacistName: "Dr. Abena Osei",
        pharmacistLicense: "PHARM-GH-67890",
        operatingHours: "Mon-Sat: 8AM-8PM, Sun: Closed",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS"]
    }
];

async function setupPharmacies() {
    try {
        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');

        // Clear existing pharmacy stores
        await PharmacyStore.deleteMany({});
        console.log('🗑️  Cleared existing pharmacy stores');

        // Insert new pharmacy stores
        const createdStores = await PharmacyStore.insertMany(pharmacyStores);
        console.log(`✅ Created ${createdStores.length} pharmacy stores`);

        // Display created stores
        console.log('\n📋 Created Pharmacy Stores:');
        createdStores.forEach((store, index) => {
            console.log(`${index + 1}. ${store.store_name} (${store.address})`);
            console.log(`   Rating: ${store.rating} ⭐ | Reviews: ${store.totalReviews}`);
            console.log(`   Emergency: ${store.emergencyService ? 'Yes ✅' : 'No ❌'} | 24/7: ${store.operatingHours === '24/7' ? 'Yes ✅' : 'No ❌'}`);
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

// Run the setup
setupPharmacies();
