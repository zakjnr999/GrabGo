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
        store_name: "HealthPlus Pharmacy",
        logo: "https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800",
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
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Star Assurance"],
        createdAt: daysAgo(45)
    },
    {
        store_name: "MediCare Pharmacy",
        logo: "https://images.unsplash.com/photo-1586015555751-63bb77f4322a?w=800",
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
        insuranceAccepted: ["NHIS", "Metropolitan Insurance"],
        createdAt: daysAgo(30)
    },
    {
        store_name: "Wellness Pharmacy",
        logo: "https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=800",
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
        insuranceAccepted: ["NHIS", "Glico", "Hollard Insurance"],
        createdAt: daysAgo(60)
    },
    {
        store_name: "City Pharmacy",
        logo: "https://images.unsplash.com/photo-1587854692152-cbe660dbbb88?w=800",
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
        insuranceAccepted: ["NHIS", "Star Assurance"],
        createdAt: daysAgo(15)
    },
    {
        store_name: "Express Pharmacy",
        logo: "https://images.unsplash.com/photo-1607619056574-7b8d3ee536b2?w=800",
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
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Metropolitan Insurance", "Hollard Insurance"],
        createdAt: daysAgo(5)
    },
    {
        store_name: "Family Care Pharmacy",
        logo: "https://images.unsplash.com/photo-1559000357-f7cb73087364?w=800",
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
        insuranceAccepted: ["NHIS"],
        createdAt: daysAgo(75)
    },
    {
        store_name: "LifeCare Pharmacy",
        logo: "https://images.unsplash.com/photo-1585435557343-3b092031a831?w=800",
        description: "Advanced pharmaceutical care with modern diagnostic services.",
        address: "89 Labone Crescent, Accra",
        phone: "+233 24 777 8899",
        email: "info@lifecare.gh",
        isOpen: true,
        deliveryFee: 9,
        minOrder: 18,
        rating: 4.7,
        totalReviews: 267,
        categories: ["Prescription Drugs", "Diagnostic Services", "Medical Imaging", "Lab Tests"],
        latitude: 5.5789,
        longitude: -0.1678,
        licenseNumber: "PH-ACC-2024-007",
        pharmacistName: "Dr. Samuel Nkrumah",
        pharmacistLicense: "PHARM-GH-78901",
        operatingHours: "Mon-Sat: 7AM-9PM, Sun: 9AM-5PM",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Glico", "Star Assurance"],
        createdAt: daysAgo(20)
    },
    {
        store_name: "Prime Health Pharmacy",
        logo: "https://images.unsplash.com/photo-1576671081837-49000212a370?w=800",
        description: "Premium pharmacy with exclusive health and wellness products.",
        address: "23 Airport Residential Area, Accra",
        phone: "+233 20 111 2233",
        email: "contact@primehealth.gh",
        isOpen: true,
        deliveryFee: 12,
        minOrder: 25,
        rating: 4.9,
        totalReviews: 534,
        categories: ["Prescription Drugs", "Premium Supplements", "Organic Products", "Wellness"],
        latitude: 5.6012,
        longitude: -0.1734,
        licenseNumber: "PH-ACC-2024-008",
        pharmacistName: "Dr. Grace Amoah",
        pharmacistLicense: "PHARM-GH-89012",
        operatingHours: "24/7",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Metropolitan Insurance", "Star Assurance", "Hollard Insurance"],
        createdAt: daysAgo(10)
    },
    {
        store_name: "Community Pharmacy",
        logo: "https://images.unsplash.com/photo-1471864190281-a93a3070b6de?w=800",
        description: "Affordable healthcare for everyone in the community.",
        address: "67 Dansoman High Street, Accra",
        phone: "+233 24 333 4455",
        email: "info@communitypharm.gh",
        isOpen: true,
        deliveryFee: 3,
        minOrder: 5,
        rating: 4.3,
        totalReviews: 178,
        categories: ["Prescription Drugs", "OTC Medications", "Generic Drugs", "Basic Care"],
        latitude: 5.5456,
        longitude: -0.2890,
        licenseNumber: "PH-ACC-2024-009",
        pharmacistName: "Dr. Joseph Mensah",
        pharmacistLicense: "PHARM-GH-90123",
        operatingHours: "Mon-Fri: 8AM-8PM, Sat: 9AM-6PM, Sun: Closed",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS"],
        createdAt: daysAgo(50)
    },
    {
        store_name: "MedExpress Pharmacy",
        logo: "https://images.unsplash.com/photo-1550572017-4a6e8c4f8f7f?w=800",
        description: "Fast prescription delivery and convenient online ordering.",
        address: "45 Teshie Nungua Estates, Accra",
        phone: "+233 27 555 6677",
        email: "support@medexpress.gh",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 10,
        rating: 4.6,
        totalReviews: 298,
        categories: ["Prescription Drugs", "Online Ordering", "Home Delivery", "Chronic Care"],
        latitude: 5.5893,
        longitude: -0.0956,
        licenseNumber: "PH-ACC-2024-010",
        pharmacistName: "Dr. Akosua Darko",
        pharmacistLicense: "PHARM-GH-01234",
        operatingHours: "24/7",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Metropolitan Insurance"],
        createdAt: daysAgo(8)
    },
    {
        store_name: "Guardian Pharmacy",
        logo: "https://images.unsplash.com/photo-1563213126-a4273aed2016?w=800",
        description: "Your guardian for health with specialized pediatric and geriatric care.",
        address: "12 Madina Market Road, Accra",
        phone: "+233 30 777 8899",
        email: "info@guardianpharm.gh",
        isOpen: true,
        deliveryFee: 7,
        minOrder: 15,
        rating: 4.5,
        totalReviews: 223,
        categories: ["Prescription Drugs", "Pediatric Care", "Geriatric Care", "Immunizations"],
        latitude: 5.6812,
        longitude: -0.1677,
        licenseNumber: "PH-ACC-2024-011",
        pharmacistName: "Dr. Emmanuel Osei",
        pharmacistLicense: "PHARM-GH-11223",
        operatingHours: "Mon-Sat: 7AM-10PM, Sun: 8AM-6PM",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Star Assurance", "Hollard Insurance"],
        createdAt: daysAgo(35)
    },
    {
        store_name: "Remedy Pharmacy",
        logo: "https://images.unsplash.com/photo-1628348068343-c6a848d2b6dd?w=800",
        description: "Natural remedies and traditional medicine alongside modern pharmaceuticals.",
        address: "34 Kaneshie Market Circle, Accra",
        phone: "+233 24 888 9900",
        email: "contact@remedypharm.gh",
        isOpen: true,
        deliveryFee: 6,
        minOrder: 12,
        rating: 4.4,
        totalReviews: 187,
        categories: ["Prescription Drugs", "Herbal Medicine", "Traditional Remedies", "Natural Products"],
        latitude: 5.5634,
        longitude: -0.2345,
        licenseNumber: "PH-ACC-2024-012",
        pharmacistName: "Dr. Comfort Adjei",
        pharmacistLicense: "PHARM-GH-22334",
        operatingHours: "Mon-Sat: 8AM-9PM, Sun: 10AM-4PM",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Glico"],
        createdAt: daysAgo(65)
    },
    {
        store_name: "Apex Pharmacy",
        logo: "https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=800",
        description: "State-of-the-art pharmacy with compounding services and specialty medications.",
        address: "78 East Legon Extension, Accra",
        phone: "+233 20 999 0011",
        email: "info@apexpharm.gh",
        isOpen: true,
        deliveryFee: 11,
        minOrder: 22,
        rating: 4.8,
        totalReviews: 412,
        categories: ["Prescription Drugs", "Compounding", "Specialty Medications", "Clinical Services"],
        latitude: 5.6234,
        longitude: -0.1523,
        licenseNumber: "PH-ACC-2024-013",
        pharmacistName: "Dr. Frederick Ansah",
        pharmacistLicense: "PHARM-GH-33445",
        operatingHours: "Mon-Fri: 7AM-11PM, Sat-Sun: 8AM-10PM",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Metropolitan Insurance"],
        createdAt: daysAgo(12)
    },
    {
        store_name: "Sunrise Pharmacy",
        logo: "https://images.unsplash.com/photo-1512069511692-2f0a8d0c2f1f?w=800",
        description: "Early morning service for your health needs before work.",
        address: "56 Tema Community 1, Tema",
        phone: "+233 27 222 3344",
        email: "hello@sunrisepharm.gh",
        isOpen: true,
        deliveryFee: 8,
        minOrder: 14,
        rating: 4.6,
        totalReviews: 256,
        categories: ["Prescription Drugs", "OTC Medications", "Health Screening", "Vaccinations"],
        latitude: 5.6698,
        longitude: -0.0166,
        licenseNumber: "PH-ACC-2024-014",
        pharmacistName: "Dr. Beatrice Mensah",
        pharmacistLicense: "PHARM-GH-44556",
        operatingHours: "Mon-Sat: 5AM-11PM, Sun: 6AM-9PM",
        prescriptionRequired: true,
        emergencyService: false,
        insuranceAccepted: ["NHIS", "Star Assurance"],
        createdAt: daysAgo(25)
    },
    {
        store_name: "TrustMed Pharmacy",
        logo: "https://images.unsplash.com/photo-1585435557343-3b092031a831?w=800",
        description: "Trusted pharmaceutical care with free health consultations.",
        address: "23 Kasoa Toll Booth, Kasoa",
        phone: "+233 24 444 5566",
        email: "info@trustmed.gh",
        isOpen: true,
        deliveryFee: 5,
        minOrder: 10,
        rating: 4.7,
        totalReviews: 334,
        categories: ["Prescription Drugs", "Health Consultations", "Chronic Disease Management", "Wellness Programs"],
        latitude: 5.5312,
        longitude: -0.4123,
        licenseNumber: "PH-ACC-2024-015",
        pharmacistName: "Dr. Patrick Owusu",
        pharmacistLicense: "PHARM-GH-55667",
        operatingHours: "24/7",
        prescriptionRequired: true,
        emergencyService: true,
        insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Hollard Insurance"],
        createdAt: daysAgo(3)
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

        // Insert new pharmacy stores with custom createdAt dates
        const createdStores = [];
        for (const storeData of pharmacyStores) {
            const store = new PharmacyStore(storeData);
            // Manually set createdAt and updatedAt to match
            store.createdAt = storeData.createdAt;
            store.updatedAt = storeData.createdAt;
            await store.save({ timestamps: false });
            createdStores.push(store);
        }

        console.log(`✅ Created ${createdStores.length} pharmacy stores`);

        // Display created stores
        console.log('\n📋 Created Pharmacy Stores:');
        createdStores.forEach((store, index) => {
            console.log(`${index + 1}. ${store.store_name} (${store.address})`);
            console.log(`   Rating: ${store.rating} ⭐ | Reviews: ${store.totalReviews}`);
            console.log(`   Emergency: ${store.emergencyService ? 'Yes ✅' : 'No ❌'} | 24/7: ${store.operatingHours === '24/7' ? 'Yes ✅' : 'No ❌'}`);
            console.log(`   License: ${store.licenseNumber}`);
            console.log(`   Created: ${store.createdAt.toLocaleDateString()}`);
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
