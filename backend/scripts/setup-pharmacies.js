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
        location: { type: 'Point', coordinates: [-0.1769, 5.5557], address: "123 Oxford Street, Osu", city: "Accra", area: "Osu" },
        phone: "+233 24 123 4567", email: "info@healthplus.com.gh", isOpen: true, deliveryFee: 5, minOrder: 10,
        rating: 4.8, totalReviews: 245, categories: ["Prescription Drugs", "OTC Medications", "Health Supplements", "Medical Devices"],
        licenseNumber: "PH-ACC-2024-001", businessIdNumber: "BID-HP-001", pharmacistName: "Dr. Kwame Mensah", pharmacistLicense: "PHARM-GH-12345",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Glico", "Enterprise Insurance", "Star Assurance"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(45), ratingSum: 1176, priorityScore: 10,
        orderAcceptanceRate: 98, orderCancellationRate: 2, features: ['takeaway', 'wheelchair_accessible', 'parking'],
        tags: ['pharmacy', 'health', '24/7'], featured: true, isVerified: true, deliveryRadius: 10,
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
        socials: { facebook: 'https://facebook.com/healthplus', instagram: 'https://instagram.com/healthplus' },
        isGrabGoExclusive: true
    },
    {
        storeName: "MediCare Pharmacy",
        logo: "https://images.unsplash.com/photo-1586015555751-63bb77f4322a?w=800",
        description: "Quality healthcare products and professional pharmaceutical services.",
        location: { type: 'Point', coordinates: [-0.1870, 5.6037], address: "45 Ring Road Central, Accra", city: "Accra", area: "Central Business District" },
        phone: "+233 30 276 5432", email: "contact@medicare.com.gh", isOpen: true, deliveryFee: 8, minOrder: 15,
        rating: 4.6, totalReviews: 189, categories: ["Prescription Drugs", "Baby Care", "Personal Care", "First Aid"],
        licenseNumber: "PH-ACC-2024-002", businessIdNumber: "BID-MC-002", pharmacistName: "Dr. Ama Asante", pharmacistLicense: "PHARM-GH-23456",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS", "Metropolitan Insurance"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(30), ratingSum: 869, priorityScore: 8,
        orderAcceptanceRate: 95, orderCancellationRate: 5, features: ['parking'], tags: ['pharmacy', 'health'],
        featured: false, isVerified: true, deliveryRadius: 8, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        },
        socials: { instagram: 'https://instagram.com/medicare' },
        isGrabGoExclusive: true
    },
    {
        storeName: "Wellness Pharmacy",
        logo: "https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=800",
        description: "Comprehensive pharmacy services with focus on wellness and preventive care.",
        location: { type: 'Point', coordinates: [-0.0892, 5.6389], address: "78 Spintex Road, Accra", city: "Accra", area: "Spintex" },
        phone: "+233 20 987 6543", email: "info@wellnesspharmacy.gh", isOpen: true, deliveryFee: 6, minOrder: 12,
        rating: 4.7, totalReviews: 312, categories: ["Prescription Drugs", "Vitamins", "Herbal Medicine", "Beauty Products"],
        licenseNumber: "PH-ACC-2024-003", businessIdNumber: "BID-WP-003", pharmacistName: "Dr. Yaw Boateng", pharmacistLicense: "PHARM-GH-34567",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Glico", "Hollard Insurance"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(60), ratingSum: 1466, priorityScore: 9,
        orderAcceptanceRate: 97, orderCancellationRate: 3, features: ['wheelchair_accessible', 'parking'], tags: ['wellness', 'supplements', 'herbal'],
        featured: true, isVerified: true, deliveryRadius: 10, paymentMethods: ['cash', 'card', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '23:00', isClosed: false },
            saturday: { open: '09:00', close: '23:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: { facebook: 'https://facebook.com/wellness' },
        isGrabGoExclusive: true
    },
    {
        storeName: "City Care Pharmacy",
        logo: "https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=800",
        description: "Your partner in health, providing quality medicines and healthcare advice.",
        location: { type: 'Point', coordinates: [-0.1969, 5.5560], address: "22 Cantonments Road, Osu", city: "Accra", area: "Osu" },
        phone: "+233 24 555 1212", email: "citycare@example.com", isOpen: true, deliveryFee: 7, minOrder: 15,
        rating: 4.5, totalReviews: 120, categories: ["Prescription Drugs", "First Aid", "Vitamins"],
        licenseNumber: "PH-ACC-2024-004", businessIdNumber: "BID-CC-004", pharmacistName: "Dr. Kofi Annan", pharmacistLicense: "PHARM-GH-45678",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS", "Allianz"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(20), ratingSum: 540, priorityScore: 7,
        orderAcceptanceRate: 96, orderCancellationRate: 4, features: ['takeaway'], tags: ['health', 'care'],
        featured: false, isVerified: true, deliveryRadius: 8, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '20:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        },
        socials: { instagram: 'https://instagram.com/citycare' }
    },
    {
        storeName: "Royal Pharma",
        logo: "https://images.unsplash.com/photo-1628771065518-0d82f1938462?w=800",
        description: "Premium pharmacy services with a wide range of international brands.",
        location: { type: 'Point', coordinates: [-0.1500, 5.6500], address: "15 Lagos Avenue, East Legon", city: "Accra", area: "East Legon" },
        phone: "+233 50 123 9876", email: "royalpharma@example.com", isOpen: true, deliveryFee: 10, minOrder: 25,
        rating: 4.9, totalReviews: 350, categories: ["Prescription Drugs", "Cosmetics", "Supplements"],
        licenseNumber: "PH-ACC-2024-005", businessIdNumber: "BID-RP-005", pharmacistName: "Dr. Esi Mensah", pharmacistLicense: "PHARM-GH-56789",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Prudential", "Acacia"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(10), ratingSum: 1715, priorityScore: 11,
        orderAcceptanceRate: 99, orderCancellationRate: 1, features: ['air_conditioned', 'parking'], tags: ['premium', 'pharmacy'],
        featured: true, isVerified: true, deliveryRadius: 15, paymentMethods: ['cash', 'card', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '23:00', isClosed: false },
            saturday: { open: '09:00', close: '23:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: { facebook: 'https://facebook.com/royalpharma', instagram: 'https://instagram.com/royalpharma' }
    },
    {
        storeName: "Trust Chemist",
        logo: "https://images.unsplash.com/photo-1530497610245-94d3c16cda28?w=800",
        description: "Accessible and affordable medication for everyone.",
        location: { type: 'Point', coordinates: [-0.2195, 5.5900], address: "88 Achimota Road, Achimota", city: "Accra", area: "Achimota" },
        phone: "+233 27 765 4321", email: "trustchemist@example.com", isOpen: true, deliveryFee: 5, minOrder: 10,
        rating: 4.3, totalReviews: 95, categories: ["Prescription Drugs", "OTC Medications", "Household"],
        licenseNumber: "PH-ACC-2024-006", businessIdNumber: "BID-TC-006", pharmacistName: "Dr. Kwesi Appiah", pharmacistLicense: "PHARM-GH-67890",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(50), ratingSum: 408, priorityScore: 6,
        orderAcceptanceRate: 94, orderCancellationRate: 6, features: ['takeaway'], tags: ['affordable', 'chemist'],
        featured: false, isVerified: true, deliveryRadius: 6, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '20:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        },
        socials: { instagram: 'https://instagram.com/trustchemist' }
    },
    {
        storeName: "Family Care Pharmacy",
        logo: "https://images.unsplash.com/photo-1555633514-abcea88cd0a1?w=800",
        description: "Caring for your family's health with personalized service.",
        location: { type: 'Point', coordinates: [-0.1300, 5.6800], address: "5 Madina Market Road, Madina", city: "Accra", area: "Madina" },
        phone: "+233 26 111 2222", email: "familycare@example.com", isOpen: true, deliveryFee: 4, minOrder: 10,
        rating: 4.4, totalReviews: 150, categories: ["Prescription Drugs", "Baby Care", "Maternal Health"],
        licenseNumber: "PH-ACC-2024-007", businessIdNumber: "BID-FC-007", pharmacistName: "Dr. Akosua Darko", pharmacistLicense: "PHARM-GH-78901",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Glico"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(40), ratingSum: 660, priorityScore: 7,
        orderAcceptanceRate: 95, orderCancellationRate: 5, features: ['takeaway', 'wheelchair_accessible'], tags: ['family', 'pharmacy'],
        featured: false, isVerified: true, deliveryRadius: 8, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '21:00', isClosed: false },
            tuesday: { open: '08:00', close: '21:00', isClosed: false },
            wednesday: { open: '08:00', close: '21:00', isClosed: false },
            thursday: { open: '08:00', close: '21:00', isClosed: false },
            friday: { open: '08:00', close: '22:00', isClosed: false },
            saturday: { open: '09:00', close: '21:00', isClosed: false },
            sunday: { open: '12:00', close: '18:00', isClosed: false }
        },
        socials: { facebook: 'https://facebook.com/familycare' }
    },
    {
        storeName: "LifeWell Pharmacy",
        logo: "https://images.unsplash.com/photo-1585435557343-3b092031a831?w=800",
        description: "Your comprehensive source for wellness and vitality.",
        location: { type: 'Point', coordinates: [-0.0166, 5.6698], address: "10 Community 1, Tema", city: "Tema", area: "Community 1" },
        phone: "+233 24 999 8888", email: "lifewell@example.com", isOpen: true, deliveryFee: 6, minOrder: 15,
        rating: 4.7, totalReviews: 210, categories: ["Prescription Drugs", "Vitamins", "Sports Nutrition"],
        licenseNumber: "PH-ACC-2024-008", businessIdNumber: "BID-LW-008", pharmacistName: "Dr. Kojo Boakye", pharmacistLicense: "PHARM-GH-89012",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Phoenix"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(25), ratingSum: 987, priorityScore: 9,
        orderAcceptanceRate: 97, orderCancellationRate: 3, features: ['parking', 'takeaway'], tags: ['wellness', 'sports'],
        featured: true, isVerified: true, deliveryRadius: 10, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '22:00', isClosed: false },
            saturday: { open: '09:00', close: '22:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: { instagram: 'https://instagram.com/lifewell' }
    },
    {
        storeName: "Community Pharmacy",
        logo: "https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=800",
        description: " Serving the community with care and compassion.",
        location: { type: 'Point', coordinates: [-0.1600, 5.6100], address: "12 Airport Road, Accra", city: "Accra", area: "Airport" },
        phone: "+233 20 888 7777", email: "community@example.com", isOpen: true, deliveryFee: 5, minOrder: 20,
        rating: 4.6, totalReviews: 180, categories: ["Prescription Drugs", "First Aid"],
        licenseNumber: "PH-ACC-2024-009", businessIdNumber: "BID-CP-009", pharmacistName: "Dr. Abena Osei", pharmacistLicense: "PHARM-GH-90123",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(15), ratingSum: 828, priorityScore: 8,
        orderAcceptanceRate: 98, orderCancellationRate: 2, features: ['takeaway'], tags: ['community', 'care'],
        featured: false, isVerified: true, deliveryRadius: 8, paymentMethods: ['cash', 'card'],
        openingHours: {
            monday: { open: '08:00', close: '21:00', isClosed: false },
            tuesday: { open: '08:00', close: '21:00', isClosed: false },
            wednesday: { open: '08:00', close: '21:00', isClosed: false },
            thursday: { open: '08:00', close: '21:00', isClosed: false },
            friday: { open: '08:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '20:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "QuickMeds",
        logo: "https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800",
        description: "Quick and easy medication delivery.",
        location: { type: 'Point', coordinates: [-0.1900, 5.5700], address: "5 Ring Road, Accra", city: "Accra", area: "Ring Road" },
        phone: "+233 30 222 3344", email: "quickmeds@example.com", isOpen: true, deliveryFee: 4, minOrder: 10,
        rating: 4.3, totalReviews: 90, categories: ["OTC Medications", "First Aid"],
        licenseNumber: "PH-ACC-2024-010", businessIdNumber: "BID-QM-010", pharmacistName: "Dr. James Doe", pharmacistLicense: "PHARM-GH-01234",
        prescriptionRequired: false, emergencyService: false, insuranceAccepted: [],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(5), ratingSum: 387, priorityScore: 6,
        orderAcceptanceRate: 92, orderCancellationRate: 8, features: ['takeaway'], tags: ['quick', 'easy'],
        featured: false, isVerified: true, deliveryRadius: 5, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '07:00', close: '22:00', isClosed: false },
            tuesday: { open: '07:00', close: '22:00', isClosed: false },
            wednesday: { open: '07:00', close: '22:00', isClosed: false },
            thursday: { open: '07:00', close: '22:00', isClosed: false },
            friday: { open: '07:00', close: '23:00', isClosed: false },
            saturday: { open: '08:00', close: '23:00', isClosed: false },
            sunday: { open: '08:00', close: '20:00', isClosed: false }
        }
    },
    {
        storeName: "Top Pharma",
        logo: "https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=800",
        description: "Top quality service and products.",
        location: { type: 'Point', coordinates: [-0.1400, 5.6600], address: "10 Legon Bypass, Accra", city: "Accra", area: "Legon" },
        phone: "+233 24 111 0000", email: "toppharma@example.com", isOpen: true, deliveryFee: 6, minOrder: 20,
        rating: 4.5, totalReviews: 130, categories: ["Prescription Drugs", "Vitamins"],
        licenseNumber: "PH-ACC-2024-011", businessIdNumber: "BID-TP-011", pharmacistName: "Dr. Sarah Smith", pharmacistLicense: "PHARM-GH-12340",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Glico"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(35), ratingSum: 585, priorityScore: 8,
        orderAcceptanceRate: 96, orderCancellationRate: 4, features: ['parking', 'wheelchair_accessible'], tags: ['top', 'service'],
        featured: false, isVerified: true, deliveryRadius: 10, paymentMethods: ['cash', 'card'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '19:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Health First",
        logo: "https://images.unsplash.com/photo-1628771065518-0d82f1938462?w=800",
        description: "Putting your health first.",
        location: { type: 'Point', coordinates: [-0.1700, 5.5800], address: "40 Kanda Highway, Accra", city: "Accra", area: "Kanda" },
        phone: "+233 27 222 3333", email: "healthfirst@example.com", isOpen: true, deliveryFee: 5, minOrder: 15,
        rating: 4.6, totalReviews: 160, categories: ["Prescription Drugs", "OTC Medications"],
        licenseNumber: "PH-ACC-2024-012", businessIdNumber: "BID-HF-012", pharmacistName: "Dr. John K", pharmacistLicense: "PHARM-GH-23450",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(28), ratingSum: 736, priorityScore: 8,
        orderAcceptanceRate: 95, orderCancellationRate: 5, features: ['takeaway'], tags: ['health', 'first'],
        featured: false, isVerified: true, deliveryRadius: 7, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '21:00', isClosed: false },
            tuesday: { open: '08:00', close: '21:00', isClosed: false },
            wednesday: { open: '08:00', close: '21:00', isClosed: false },
            thursday: { open: '08:00', close: '21:00', isClosed: false },
            friday: { open: '08:00', close: '22:00', isClosed: false },
            saturday: { open: '09:00', close: '20:00', isClosed: false },
            sunday: { open: '12:00', close: '18:00', isClosed: false }
        }
    },
    {
        storeName: "MediPlus",
        logo: "https://images.unsplash.com/photo-1585435557343-3b092031a831?w=800",
        description: "More than just medicine.",
        location: { type: 'Point', coordinates: [-0.2050, 5.5950], address: "20 Lapaz Road, Accra", city: "Accra", area: "Lapaz" },
        phone: "+233 26 444 5555", email: "mediplus@example.com", isOpen: true, deliveryFee: 4, minOrder: 12,
        rating: 4.4, totalReviews: 110, categories: ["Prescription Drugs", "Personal Care"],
        licenseNumber: "PH-ACC-2024-013", businessIdNumber: "BID-MP-013", pharmacistName: "Dr. Grace A", pharmacistLicense: "PHARM-GH-34560",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(18), ratingSum: 484, priorityScore: 7,
        orderAcceptanceRate: 94, orderCancellationRate: 6, features: ['takeaway'], tags: ['medi', 'plus'],
        featured: false, isVerified: true, deliveryRadius: 6, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '07:00', close: '22:00', isClosed: false },
            tuesday: { open: '07:00', close: '22:00', isClosed: false },
            wednesday: { open: '07:00', close: '22:00', isClosed: false },
            thursday: { open: '07:00', close: '22:00', isClosed: false },
            friday: { open: '07:00', close: '23:00', isClosed: false },
            saturday: { open: '08:00', close: '23:00', isClosed: false },
            sunday: { open: '09:00', close: '20:00', isClosed: false }
        }
    },
    {
        storeName: "PharmaCare",
        logo: "https://images.unsplash.com/photo-1555633514-abcea88cd0a1?w=800",
        description: "Care you can trust.",
        location: { type: 'Point', coordinates: [-0.1850, 5.6150], address: "15 Roman Ridge, Accra", city: "Accra", area: "Roman Ridge" },
        phone: "+233 23 555 6666", email: "pharmacare@example.com", isOpen: true, deliveryFee: 7, minOrder: 25,
        rating: 4.7, totalReviews: 140, categories: ["Prescription Drugs", "Baby Care"],
        licenseNumber: "PH-ACC-2024-014", businessIdNumber: "BID-PC-014", pharmacistName: "Dr. Peter P", pharmacistLicense: "PHARM-GH-45670",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Allianz"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(60), ratingSum: 658, priorityScore: 9,
        orderAcceptanceRate: 98, orderCancellationRate: 2, features: ['parking', 'wheelchair_accessible'], tags: ['care', 'trust'],
        featured: true, isVerified: true, deliveryRadius: 10, paymentMethods: ['cash', 'card'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '19:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Good Health",
        logo: "https://images.unsplash.com/photo-1631549916768-4119b2e5f926?w=800",
        description: "Your guide to good health.",
        location: { type: 'Point', coordinates: [-0.1750, 5.6000], address: "30 Nima Highway, Accra", city: "Accra", area: "Nima" },
        phone: "+233 24 666 7777", email: "goodhealth@example.com", isOpen: true, deliveryFee: 5, minOrder: 15,
        rating: 4.5, totalReviews: 100, categories: ["Prescription Drugs", "OTC Medications"],
        licenseNumber: "PH-ACC-2024-015", businessIdNumber: "BID-GH-015", pharmacistName: "Dr. Mary M", pharmacistLicense: "PHARM-GH-56780",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(45), ratingSum: 450, priorityScore: 8,
        orderAcceptanceRate: 96, orderCancellationRate: 4, features: ['takeaway'], tags: ['good', 'health'],
        featured: false, isVerified: true, deliveryRadius: 7, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '09:00', close: '21:00', isClosed: false },
            tuesday: { open: '09:00', close: '21:00', isClosed: false },
            wednesday: { open: '09:00', close: '21:00', isClosed: false },
            thursday: { open: '09:00', close: '21:00', isClosed: false },
            friday: { open: '09:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '21:00', isClosed: false },
            sunday: { open: '10:00', close: '18:00', isClosed: false }
        }
    },
    {
        storeName: "PharmaLink",
        logo: "https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800",
        description: "Your link to pharmaceutical care.",
        location: { type: 'Point', coordinates: [-0.1550, 5.5850], address: "18 Labadi Road, Accra", city: "Accra", area: "Labadi" },
        phone: "+233 50 888 7777", email: "pharmalink@example.com", isOpen: true, deliveryFee: 6, minOrder: 18,
        rating: 4.6, totalReviews: 190, categories: ["Prescription Drugs", "Medical Devices"],
        licenseNumber: "PH-ACC-2024-016", businessIdNumber: "BID-PL-016", pharmacistName: "Dr. Ben K", pharmacistLicense: "PHARM-GH-67891",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Prudential"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(38), ratingSum: 874, priorityScore: 9,
        orderAcceptanceRate: 97, orderCancellationRate: 3, features: ['parking'], tags: ['pharma', 'link'],
        featured: true, isVerified: true, deliveryRadius: 9, paymentMethods: ['cash', 'card', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '22:00', isClosed: false },
            saturday: { open: '09:00', close: '21:00', isClosed: false },
            sunday: { open: '12:00', close: '18:00', isClosed: false }
        }
    },
    {
        storeName: "CarePlus Pharmacy",
        logo: "https://images.unsplash.com/photo-1586015555751-63bb77f4322a?w=800",
        description: "Plus care for your health needs.",
        location: { type: 'Point', coordinates: [-0.1980, 5.5650], address: "25 Circle Road, Accra", city: "Accra", area: "Circle" },
        phone: "+233 24 000 1111", email: "careplus@example.com", isOpen: true, deliveryFee: 5, minOrder: 12,
        rating: 4.3, totalReviews: 115, categories: ["Prescription Drugs", "Vitamins"],
        licenseNumber: "PH-ACC-2024-017", businessIdNumber: "BID-CP-017", pharmacistName: "Dr. Frank F", pharmacistLicense: "PHARM-GH-78902",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(22), ratingSum: 494, priorityScore: 7,
        orderAcceptanceRate: 94, orderCancellationRate: 6, features: ['takeaway'], tags: ['care', 'plus'],
        featured: false, isVerified: true, deliveryRadius: 6, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '07:00', close: '21:00', isClosed: false },
            tuesday: { open: '07:00', close: '21:00', isClosed: false },
            wednesday: { open: '07:00', close: '21:00', isClosed: false },
            thursday: { open: '07:00', close: '21:00', isClosed: false },
            friday: { open: '07:00', close: '21:00', isClosed: false },
            saturday: { open: '08:00', close: '20:00', isClosed: false },
            sunday: { open: '10:00', close: '16:00', isClosed: false }
        }
    },
    {
        storeName: "MediMart",
        logo: "https://images.unsplash.com/photo-1628771065518-0d82f1938462?w=800",
        description: "Your medical market.",
        location: { type: 'Point', coordinates: [-0.1450, 5.6400], address: "8 Mempeasem Road, Accra", city: "Accra", area: "Mempeasem" },
        phone: "+233 27 555 4444", email: "medimart@example.com", isOpen: true, deliveryFee: 7, minOrder: 20,
        rating: 4.5, totalReviews: 125, categories: ["Prescription Drugs", "First Aid"],
        licenseNumber: "PH-ACC-2024-018", businessIdNumber: "BID-MM-018", pharmacistName: "Dr. Sam S", pharmacistLicense: "PHARM-GH-89013",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS", "Glico"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(33), ratingSum: 562, priorityScore: 8,
        orderAcceptanceRate: 96, orderCancellationRate: 4, features: ['parking'], tags: ['medical', 'mart'],
        featured: false, isVerified: true, deliveryRadius: 8, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '20:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '12:00', close: '18:00', isClosed: false }
        }
    },
    {
        storeName: "HealthHub Pharmacy",
        logo: "https://images.unsplash.com/photo-1576602976047-174e57a47881?w=800",
        description: "Connecting you to better health.",
        location: { type: 'Point', coordinates: [-0.1250, 5.6700], address: "22 Atomic Junction, Accra", city: "Accra", area: "Atomic" },
        phone: "+233 23 999 0000", email: "healthhub@example.com", isOpen: true, deliveryFee: 6, minOrder: 15,
        rating: 4.8, totalReviews: 220, categories: ["Prescription Drugs", "Supplements"],
        licenseNumber: "PH-ACC-2024-019", businessIdNumber: "BID-HH-019", pharmacistName: "Dr. Lisa L", pharmacistLicense: "PHARM-GH-90124",
        prescriptionRequired: true, emergencyService: true, insuranceAccepted: ["NHIS", "Hollard"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(52), ratingSum: 1056, priorityScore: 10,
        orderAcceptanceRate: 98, orderCancellationRate: 2, features: ['wheelchair_accessible', 'takeaway'], tags: ['hub', 'health'],
        featured: true, isVerified: true, deliveryRadius: 10, paymentMethods: ['cash', 'card'],
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '22:00', isClosed: false },
            saturday: { open: '09:00', close: '22:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        }
    },
    {
        storeName: "PharmaZone",
        logo: "https://images.unsplash.com/photo-1587854692152-cbe660dbde88?w=800",
        description: "Your zone for pharmaceutical excellence.",
        location: { type: 'Point', coordinates: [-0.1500, 5.6000], address: "10 37 Military Road, Accra", city: "Accra", area: "37" },
        phone: "+233 24 888 1111", email: "pharmazone@example.com", isOpen: true, deliveryFee: 5, minOrder: 15,
        rating: 4.6, totalReviews: 175, categories: ["Prescription Drugs", "Medical Devices"],
        licenseNumber: "PH-ACC-2024-020", businessIdNumber: "BID-PZ-020", pharmacistName: "Dr. Tina T", pharmacistLicense: "PHARM-GH-01235",
        prescriptionRequired: true, emergencyService: false, insuranceAccepted: ["NHIS", "Phoenix"],
        vendorType: "pharmacy", status: "approved", createdAt: daysAgo(29), ratingSum: 805, priorityScore: 8,
        orderAcceptanceRate: 97, orderCancellationRate: 3, features: ['takeaway'], tags: ['pharmacy', 'zone'],
        featured: false, isVerified: true, deliveryRadius: 8, paymentMethods: ['cash', 'mobile_money'],
        openingHours: {
            monday: { open: '08:00', close: '21:00', isClosed: false },
            tuesday: { open: '08:00', close: '21:00', isClosed: false },
            wednesday: { open: '08:00', close: '21:00', isClosed: false },
            thursday: { open: '08:00', close: '21:00', isClosed: false },
            friday: { open: '08:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '21:00', isClosed: false },
            sunday: { open: '12:00', close: '18:00', isClosed: false }
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
