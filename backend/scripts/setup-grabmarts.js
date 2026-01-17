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
        location: { type: 'Point', coordinates: [-0.1821, 5.5693], address: "89 Cantonments Road, Accra", city: "Accra", area: "Cantonments" },
        phone: "+233 24 789 0123", email: "info@quickstop.gh", businessIdNumber: "BID-GM-001",
        isOpen: true, deliveryFee: 3, minOrder: 5, rating: 4.7, totalReviews: 567,
        categories: ["Convenience", "Quick Shopping", "24/7 Service"],
        is24Hours: true, hasParking: true, paymentMethods: ["cash", "card", "mobile_money"],
        services: ["ATM", "Bill Payment", "Mobile Top-up", "Money Transfer"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(40), ratingSum: 2665,
        priorityScore: 10, orderAcceptanceRate: 99, orderCancellationRate: 1,
        features: ['parking', 'takeaway', 'wheelchair_accessible', 'air_conditioned'],
        tags: ['convenience', '24/7', 'essentials'], featured: true, isVerified: true,
        deliveryRadius: 5, averagePreparationTime: 5, averageDeliveryTime: 15,
        openingHours: {
            monday: { open: '00:00', close: '23:59', isClosed: false },
            tuesday: { open: '00:00', close: '23:59', isClosed: false },
            wednesday: { open: '00:00', close: '23:59', isClosed: false },
            thursday: { open: '00:00', close: '23:59', isClosed: false },
            friday: { open: '00:00', close: '23:59', isClosed: false },
            saturday: { open: '00:00', close: '23:59', isClosed: false },
            sunday: { open: '00:00', close: '23:59', isClosed: false }
        },
        socials: { facebook: 'https://facebook.com/quickstop', instagram: 'https://instagram.com/quickstop' },
        isGrabGoExclusive: true
    },
    {
        storeName: "Express Mart",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Fast service, great prices. Your neighborhood convenience store.",
        location: { type: 'Point', coordinates: [-0.1678, 5.5789], address: "45 Labone Junction, Accra", city: "Accra", area: "Labone" },
        phone: "+233 30 276 8901", email: "contact@expressmart.gh", businessIdNumber: "BID-GM-002",
        isOpen: true, deliveryFee: 4, minOrder: 10, rating: 4.5, totalReviews: 234,
        categories: ["Convenience", "Groceries", "Snacks"],
        is24Hours: false, hasParking: false, paymentMethods: ["cash", "card", "mobile_money"],
        services: ["Mobile Top-up", "Photocopying", "Printing"],
        productTypes: ["Snacks", "Beverages", "Stationery", "Personal Care"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(28), ratingSum: 1053,
        priorityScore: 8, orderAcceptanceRate: 96, orderCancellationRate: 4,
        features: ['takeaway'], tags: ['express', ' snacks', 'drinks'], featured: false, isVerified: true,
        deliveryRadius: 4, averagePreparationTime: 5, averageDeliveryTime: 20,
        openingHours: {
            monday: { open: '07:00', close: '23:00', isClosed: false },
            tuesday: { open: '07:00', close: '23:00', isClosed: false },
            wednesday: { open: '07:00', close: '23:00', isClosed: false },
            thursday: { open: '07:00', close: '23:00', isClosed: false },
            friday: { open: '07:00', close: '23:00', isClosed: false },
            saturday: { open: '08:00', close: '23:00', isClosed: false },
            sunday: { open: '08:00', close: '22:00', isClosed: false }
        },
        socials: { instagram: 'https://instagram.com/expressmart' },
        isGrabGoExclusive: true
    },
    {
        storeName: "Metro GrabMart",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "Premium convenience store with a wide range of products and services.",
        location: { type: 'Point', coordinates: [-0.1734, 5.6012], address: "12 Airport Residential Area, Accra", city: "Accra", area: "Airport Residential" },
        phone: "+233 20 345 6789", email: "hello@metrograbmart.gh", businessIdNumber: "BID-GM-003",
        isOpen: true, deliveryFee: 5, minOrder: 15, rating: 4.8, totalReviews: 892,
        categories: ["Premium", "Convenience", "Electronics"],
        is24Hours: true, hasParking: true, paymentMethods: ["cash", "card", "mobile_money"],
        services: ["ATM", "Bill Payment", "Mobile Top-up", "Money Transfer", "Photocopying", "Printing"],
        productTypes: ["Snacks", "Beverages", "Personal Care", "Household", "Electronics", "Stationery"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(55), ratingSum: 4281,
        priorityScore: 11, orderAcceptanceRate: 98, orderCancellationRate: 2,
        features: ['parking', 'takeaway', 'wheelchair_accessible', 'air_conditioned'],
        tags: ['premium', 'metro', 'electronics'], featured: true, isVerified: true,
        deliveryRadius: 8, averagePreparationTime: 10, averageDeliveryTime: 25,
        openingHours: {
            monday: { open: '00:00', close: '23:59', isClosed: false },
            tuesday: { open: '00:00', close: '23:59', isClosed: false },
            wednesday: { open: '00:00', close: '23:59', isClosed: false },
            thursday: { open: '00:00', close: '23:59', isClosed: false },
            friday: { open: '00:00', close: '23:59', isClosed: false },
            saturday: { open: '00:00', close: '23:59', isClosed: false },
            sunday: { open: '00:00', close: '23:59', isClosed: false }
        },
        socials: { facebook: 'https://facebook.com/metrograbmart', twitter: 'https://twitter.com/metrograbmart' },
        isGrabGoExclusive: true
    },
    {
        storeName: "City Corner Mart",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        description: "Your daily corner store.",
        location: { type: 'Point', coordinates: [-0.1900, 5.5600], address: "10 Ring Road, Accra", city: "Accra", area: "Ring Road" },
        phone: "+233 24 000 0000", email: "citycorner@example.com", businessIdNumber: "BID-GM-004",
        isOpen: true, deliveryFee: 3, minOrder: 5, rating: 4.4, totalReviews: 120,
        categories: ["Convenience"], is24Hours: false, hasParking: false, paymentMethods: ["cash", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Snacks", "Beverages"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(10), ratingSum: 528,
        priorityScore: 6, orderAcceptanceRate: 94, orderCancellationRate: 6,
        features: ['takeaway'], tags: ['corner', 'store'], featured: false, isVerified: true,
        deliveryRadius: 4, averagePreparationTime: 5, averageDeliveryTime: 15,
        openingHours: {
            monday: { open: '08:00', close: '22:00', isClosed: false },
            tuesday: { open: '08:00', close: '22:00', isClosed: false },
            wednesday: { open: '08:00', close: '22:00', isClosed: false },
            thursday: { open: '08:00', close: '22:00', isClosed: false },
            friday: { open: '08:00', close: '23:00', isClosed: false },
            saturday: { open: '09:00', close: '23:00', isClosed: false },
            sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: { instagram: 'https://instagram.com/citycorner' }
    },
    {
        storeName: "Night Owl Mart",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Open late for you.",
        location: { type: 'Point', coordinates: [-0.1600, 5.5900], address: "55 Osu Oxford Street, Accra", city: "Accra", area: "Osu" },
        phone: "+233 50 111 2222", email: "nightowl@example.com", businessIdNumber: "BID-GM-005",
        isOpen: true, deliveryFee: 6, minOrder: 15, rating: 4.6, totalReviews: 200,
        categories: ["Convenience", "Late Night"], is24Hours: true, hasParking: true, paymentMethods: ["cash", "card"],
        services: ["ATM"], productTypes: ["Snacks", "Beverages"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(20), ratingSum: 920,
        priorityScore: 9, orderAcceptanceRate: 98, orderCancellationRate: 2,
        features: ['takeaway', 'parking'], tags: ['night', 'owl', 'late'], featured: false, isVerified: true,
        deliveryRadius: 6, averagePreparationTime: 5, averageDeliveryTime: 20,
        openingHours: {
            monday: { open: '18:00', close: '06:00', isClosed: false },
            tuesday: { open: '18:00', close: '06:00', isClosed: false },
            wednesday: { open: '18:00', close: '06:00', isClosed: false },
            thursday: { open: '18:00', close: '06:00', isClosed: false },
            friday: { open: '18:00', close: '06:00', isClosed: false },
            saturday: { open: '18:00', close: '06:00', isClosed: false },
            sunday: { open: '18:00', close: '06:00', isClosed: false }
        }
    },
    {
        storeName: "Family Mart",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "For all your family needs.",
        location: { type: 'Point', coordinates: [-0.1400, 5.6500], address: "10 East Legon, Accra", city: "Accra", area: "East Legon" },
        phone: "+233 26 333 4444", email: "familymart@example.com", businessIdNumber: "BID-GM-006",
        isOpen: true, deliveryFee: 5, minOrder: 20, rating: 4.7, totalReviews: 180,
        categories: ["Groceries", "Household"], is24Hours: false, hasParking: true, paymentMethods: ["cash", "mobile_money"],
        services: ["Bill Payment"], productTypes: ["Household"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(30), ratingSum: 846,
        priorityScore: 8, orderAcceptanceRate: 97, orderCancellationRate: 3,
        features: ['parking', 'takeaway'], tags: ['family', 'mart'], featured: true, isVerified: true,
        deliveryRadius: 8, averagePreparationTime: 10, averageDeliveryTime: 30,
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '21:00', isClosed: false },
            saturday: { open: '09:00', close: '21:00', isClosed: false },
            sunday: { open: '10:00', close: '18:00', isClosed: false }
        },
        socials: { facebook: 'https://facebook.com/familymart' }
    },
    {
        storeName: "Eco Mart",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        description: "Eco-friendly products.",
        location: { type: 'Point', coordinates: [-0.1800, 5.6100], address: "8 Ridge, Accra", city: "Accra", area: "Ridge" },
        phone: "+233 27 555 6666", email: "ecomart@example.com", businessIdNumber: "BID-GM-007",
        isOpen: true, deliveryFee: 4, minOrder: 10, rating: 4.8, totalReviews: 150,
        categories: ["Eco-friendly"], is24Hours: false, hasParking: true, paymentMethods: ["card", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Household", "Personal Care"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(15), ratingSum: 720,
        priorityScore: 9, orderAcceptanceRate: 99, orderCancellationRate: 1,
        features: ['parking'], tags: ['eco', 'green'], featured: false, isVerified: true,
        deliveryRadius: 7, averagePreparationTime: 5, averageDeliveryTime: 20,
        openingHours: {
            monday: { open: '09:00', close: '19:00', isClosed: false },
            tuesday: { open: '09:00', close: '19:00', isClosed: false },
            wednesday: { open: '09:00', close: '19:00', isClosed: false },
            thursday: { open: '09:00', close: '19:00', isClosed: false },
            friday: { open: '09:00', close: '19:00', isClosed: false },
            saturday: { open: '10:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Tech Stop",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Electronics and gadgets.",
        location: { type: 'Point', coordinates: [-0.1700, 5.5800], address: "15 Kanda, Accra", city: "Accra", area: "Kanda" },
        phone: "+233 23 777 8888", email: "techstop@example.com", businessIdNumber: "BID-GM-008",
        isOpen: true, deliveryFee: 7, minOrder: 30, rating: 4.5, totalReviews: 100,
        categories: ["Electronics"], is24Hours: false, hasParking: true, paymentMethods: ["card", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Electronics"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(45), ratingSum: 450,
        priorityScore: 8, orderAcceptanceRate: 96, orderCancellationRate: 4,
        features: ['air_conditioned', 'parking'], tags: ['tech', 'gadgets'], featured: true, isVerified: true,
        deliveryRadius: 10, averagePreparationTime: 10, averageDeliveryTime: 30,
        openingHours: {
            monday: { open: '09:00', close: '20:00', isClosed: false },
            tuesday: { open: '09:00', close: '20:00', isClosed: false },
            wednesday: { open: '09:00', close: '20:00', isClosed: false },
            thursday: { open: '09:00', close: '20:00', isClosed: false },
            friday: { open: '09:00', close: '20:00', isClosed: false },
            saturday: { open: '10:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Pet Parade",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "Pet supplies and food.",
        location: { type: 'Point', coordinates: [-0.1950, 5.5700], address: "20 Adabraka, Accra", city: "Accra", area: "Adabraka" },
        phone: "+233 24 999 0000", email: "petparade@example.com", businessIdNumber: "BID-GM-009",
        isOpen: true, deliveryFee: 5, minOrder: 15, rating: 4.6, totalReviews: 130,
        categories: ["Pet Supplies"], is24Hours: false, hasParking: false, paymentMethods: ["cash", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Household"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(35), ratingSum: 598,
        priorityScore: 7, orderAcceptanceRate: 95, orderCancellationRate: 5,
        features: ['takeaway'], tags: ['pet', 'supplies'], featured: false, isVerified: true,
        deliveryRadius: 8, averagePreparationTime: 5, averageDeliveryTime: 25,
        openingHours: {
            monday: { open: '08:00', close: '19:00', isClosed: false },
            tuesday: { open: '08:00', close: '19:00', isClosed: false },
            wednesday: { open: '08:00', close: '19:00', isClosed: false },
            thursday: { open: '08:00', close: '19:00', isClosed: false },
            friday: { open: '08:00', close: '19:00', isClosed: false },
            saturday: { open: '09:00', close: '17:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Stationery Plus",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        description: "Office and school supplies.",
        location: { type: 'Point', coordinates: [-0.1550, 5.6200], address: "12 Dzorwulu, Accra", city: "Accra", area: "Dzorwulu" },
        phone: "+233 20 111 2222", email: "stationery@example.com", businessIdNumber: "BID-GM-010",
        isOpen: true, deliveryFee: 4, minOrder: 10, rating: 4.4, totalReviews: 90,
        categories: ["Stationery"], is24Hours: false, hasParking: true, paymentMethods: ["cash", "card"],
        services: ["Printing", "Photocopying"], productTypes: ["Stationery"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(25), ratingSum: 396,
        priorityScore: 6, orderAcceptanceRate: 93, orderCancellationRate: 7,
        features: ['takeaway', 'parking'], tags: ['stationery', 'office'], featured: false, isVerified: true,
        deliveryRadius: 6, averagePreparationTime: 10, averageDeliveryTime: 25,
        openingHours: {
            monday: { open: '08:00', close: '18:00', isClosed: false },
            tuesday: { open: '08:00', close: '18:00', isClosed: false },
            wednesday: { open: '08:00', close: '18:00', isClosed: false },
            thursday: { open: '08:00', close: '18:00', isClosed: false },
            friday: { open: '08:00', close: '18:00', isClosed: false },
            saturday: { open: '09:00', close: '14:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Beauty Box",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Cosmetics and personal care.",
        location: { type: 'Point', coordinates: [-0.1750, 5.6050], address: "5 Cantonments, Accra", city: "Accra", area: "Cantonments" },
        phone: "+233 26 555 6666", email: "beautybox@example.com", businessIdNumber: "BID-GM-011",
        isOpen: true, deliveryFee: 5, minOrder: 20, rating: 4.7, totalReviews: 160,
        categories: ["Beauty"], is24Hours: false, hasParking: true, paymentMethods: ["card", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Personal Care"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(50), ratingSum: 752,
        priorityScore: 8, orderAcceptanceRate: 97, orderCancellationRate: 3,
        features: ['air_conditioned', 'parking'], tags: ['beauty', 'cosmetics'], featured: true, isVerified: true,
        deliveryRadius: 9, averagePreparationTime: 5, averageDeliveryTime: 20,
        openingHours: {
            monday: { open: '09:00', close: '20:00', isClosed: false },
            tuesday: { open: '09:00', close: '20:00', isClosed: false },
            wednesday: { open: '09:00', close: '20:00', isClosed: false },
            thursday: { open: '09:00', close: '20:00', isClosed: false },
            friday: { open: '09:00', close: '20:00', isClosed: false },
            saturday: { open: '10:00', close: '19:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Gift Galore",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "Gifts for all occasions.",
        location: { type: 'Point', coordinates: [-0.1650, 5.5950], address: "20 Osu, Accra", city: "Accra", area: "Osu" },
        phone: "+233 24 777 8888", email: "giftgalore@example.com", businessIdNumber: "BID-GM-012",
        isOpen: true, deliveryFee: 6, minOrder: 15, rating: 4.5, totalReviews: 110,
        categories: ["Gifts"], is24Hours: false, hasParking: false, paymentMethods: ["cash", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Stationery"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(18), ratingSum: 495,
        priorityScore: 7, orderAcceptanceRate: 95, orderCancellationRate: 5,
        features: ['takeaway'], tags: ['gifts', 'presents'], featured: false, isVerified: true,
        deliveryRadius: 7, averagePreparationTime: 15, averageDeliveryTime: 30,
        openingHours: {
            monday: { open: '09:00', close: '19:00', isClosed: false },
            tuesday: { open: '09:00', close: '19:00', isClosed: false },
            wednesday: { open: '09:00', close: '19:00', isClosed: false },
            thursday: { open: '09:00', close: '19:00', isClosed: false },
            friday: { open: '09:00', close: '19:00', isClosed: false },
            saturday: { open: '10:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Baby Bliss",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        description: "Everything for your baby.",
        location: { type: 'Point', coordinates: [-0.1850, 5.6250], address: "15 Roman Ridge, Accra", city: "Accra", area: "Roman Ridge" },
        phone: "+233 23 444 3333", email: "babybliss@example.com", businessIdNumber: "BID-GM-013",
        isOpen: true, deliveryFee: 5, minOrder: 25, rating: 4.8, totalReviews: 140,
        categories: ["Baby"], is24Hours: false, hasParking: true, paymentMethods: ["card", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Personal Care", "Household"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(42), ratingSum: 672,
        priorityScore: 9, orderAcceptanceRate: 98, orderCancellationRate: 2,
        features: ['parking'], tags: ['baby', 'infant'], featured: true, isVerified: true,
        deliveryRadius: 9, averagePreparationTime: 5, averageDeliveryTime: 25,
        openingHours: {
            monday: { open: '09:00', close: '20:00', isClosed: false },
            tuesday: { open: '09:00', close: '20:00', isClosed: false },
            wednesday: { open: '09:00', close: '20:00', isClosed: false },
            thursday: { open: '09:00', close: '20:00', isClosed: false },
            friday: { open: '09:00', close: '20:00', isClosed: false },
            saturday: { open: '10:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Party Central",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Party supplies and decorations.",
        location: { type: 'Point', coordinates: [-0.1500, 5.6300], address: "8 Airport West, Accra", city: "Accra", area: "Airport West" },
        phone: "+233 27 111 2222", email: "partycentral@example.com", businessIdNumber: "BID-GM-014",
        isOpen: true, deliveryFee: 6, minOrder: 30, rating: 4.4, totalReviews: 95,
        categories: ["Party"], is24Hours: false, hasParking: true, paymentMethods: ["cash", "card"],
        services: ["Mobile Top-up"], productTypes: ["Stationery", "Household"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(12), ratingSum: 418,
        priorityScore: 7, orderAcceptanceRate: 94, orderCancellationRate: 6,
        features: ['takeaway', 'parking'], tags: ['party', 'fun'], featured: false, isVerified: true,
        deliveryRadius: 8, averagePreparationTime: 20, averageDeliveryTime: 35,
        openingHours: {
            monday: { open: '09:00', close: '19:00', isClosed: false },
            tuesday: { open: '09:00', close: '19:00', isClosed: false },
            wednesday: { open: '09:00', close: '19:00', isClosed: false },
            thursday: { open: '09:00', close: '19:00', isClosed: false },
            friday: { open: '09:00', close: '20:00', isClosed: false },
            saturday: { open: '09:00', close: '20:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Home Essentials",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "Basic home needs.",
        location: { type: 'Point', coordinates: [-0.2000, 5.5800], address: "12 Tesano, Accra", city: "Accra", area: "Tesano" },
        phone: "+233 26 888 7777", email: "homeessentials@example.com", businessIdNumber: "BID-GM-015",
        isOpen: true, deliveryFee: 5, minOrder: 15, rating: 4.5, totalReviews: 105,
        categories: ["Household"], is24Hours: false, hasParking: true, paymentMethods: ["cash", "mobile_money"],
        services: ["Bill Payment"], productTypes: ["Household", "Personal Care"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(36), ratingSum: 472,
        priorityScore: 7, orderAcceptanceRate: 96, orderCancellationRate: 4,
        features: ['parking'], tags: ['home', 'essentials'], featured: false, isVerified: true,
        deliveryRadius: 8, averagePreparationTime: 5, averageDeliveryTime: 25,
        openingHours: {
            monday: { open: '08:00', close: '20:00', isClosed: false },
            tuesday: { open: '08:00', close: '20:00', isClosed: false },
            wednesday: { open: '08:00', close: '20:00', isClosed: false },
            thursday: { open: '08:00', close: '20:00', isClosed: false },
            friday: { open: '08:00', close: '20:00', isClosed: false },
            saturday: { open: '09:00', close: '18:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Flower Power",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        description: "Fresh flowers daily.",
        location: { type: 'Point', coordinates: [-0.1700, 5.6100], address: "5 Cantonments, Accra", city: "Accra", area: "Cantonments" },
        phone: "+233 50 222 1111", email: "flowerpower@example.com", businessIdNumber: "BID-GM-016",
        isOpen: true, deliveryFee: 7, minOrder: 20, rating: 4.9, totalReviews: 160,
        categories: ["Florist"], is24Hours: false, hasParking: true, paymentMethods: ["card", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Personal Care"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(5), ratingSum: 784,
        priorityScore: 10, orderAcceptanceRate: 99, orderCancellationRate: 1,
        features: ['takeaway', 'parking'], tags: ['flowers', 'fresh'], featured: true, isVerified: true,
        deliveryRadius: 10, averagePreparationTime: 20, averageDeliveryTime: 35,
        openingHours: {
            monday: { open: '08:00', close: '18:00', isClosed: false },
            tuesday: { open: '08:00', close: '18:00', isClosed: false },
            wednesday: { open: '08:00', close: '18:00', isClosed: false },
            thursday: { open: '08:00', close: '18:00', isClosed: false },
            friday: { open: '08:00', close: '18:00', isClosed: false },
            saturday: { open: '09:00', close: '16:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Snack Shack",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "All your favorite snacks.",
        location: { type: 'Point', coordinates: [-0.1880, 5.5650], address: "20 Adabraka, Accra", city: "Accra", area: "Adabraka" },
        phone: "+233 24 555 4444", email: "snackshack@example.com", businessIdNumber: "BID-GM-017",
        isOpen: true, deliveryFee: 4, minOrder: 5, rating: 4.3, totalReviews: 85,
        categories: ["Snacks"], is24Hours: false, hasParking: false, paymentMethods: ["cash", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Snacks", "Beverages"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(8), ratingSum: 365,
        priorityScore: 6, orderAcceptanceRate: 93, orderCancellationRate: 7,
        features: ['takeaway'], tags: ['snacks', 'tasty'], featured: false, isVerified: true,
        deliveryRadius: 5, averagePreparationTime: 5, averageDeliveryTime: 15,
        openingHours: {
            monday: { open: '09:00', close: '21:00', isClosed: false },
            tuesday: { open: '09:00', close: '21:00', isClosed: false },
            wednesday: { open: '09:00', close: '21:00', isClosed: false },
            thursday: { open: '09:00', close: '21:00', isClosed: false },
            friday: { open: '09:00', close: '22:00', isClosed: false },
            saturday: { open: '10:00', close: '22:00', isClosed: false },
            sunday: { open: '12:00', close: '20:00', isClosed: false }
        }
    },
    {
        storeName: "Healthy Bites",
        logo: "https://images.unsplash.com/photo-1542838132-92c53300491e?w=800",
        description: "Healthy snacks and drinks.",
        location: { type: 'Point', coordinates: [-0.1580, 5.5750], address: "12 Labone, Accra", city: "Accra", area: "Labone" },
        phone: "+233 26 222 1111", email: "healthybites@example.com", businessIdNumber: "BID-GM-018",
        isOpen: true, deliveryFee: 6, minOrder: 15, rating: 4.7, totalReviews: 110,
        categories: ["Healthy"], is24Hours: false, hasParking: true, paymentMethods: ["card", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Snacks", "Beverages"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(29), ratingSum: 517,
        priorityScore: 8, orderAcceptanceRate: 97, orderCancellationRate: 3,
        features: ['parking'], tags: ['healthy', 'bites'], featured: false, isVerified: true,
        deliveryRadius: 8, averagePreparationTime: 10, averageDeliveryTime: 25,
        openingHours: {
            monday: { open: '08:00', close: '19:00', isClosed: false },
            tuesday: { open: '08:00', close: '19:00', isClosed: false },
            wednesday: { open: '08:00', close: '19:00', isClosed: false },
            thursday: { open: '08:00', close: '19:00', isClosed: false },
            friday: { open: '08:00', close: '19:00', isClosed: false },
            saturday: { open: '09:00', close: '17:00', isClosed: false },
            sunday: { open: '00:00', close: '00:00', isClosed: true }
        }
    },
    {
        storeName: "Wine & Spirits",
        logo: "https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800",
        description: "Fine wines and spirits.",
        location: { type: 'Point', coordinates: [-0.1780, 5.6150], address: "10 Airport City, Accra", city: "Accra", area: "Airport City" },
        phone: "+233 20 666 5555", email: "winespirits@example.com", businessIdNumber: "BID-GM-019",
        isOpen: true, deliveryFee: 8, minOrder: 40, rating: 4.8, totalReviews: 180,
        categories: ["Alcohol"], is24Hours: false, hasParking: true, paymentMethods: ["card", "mobile_money"],
        services: ["Mobile Top-up"], productTypes: ["Beverages"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(60), ratingSum: 864,
        priorityScore: 9, orderAcceptanceRate: 98, orderCancellationRate: 2,
        features: ['air_conditioned', 'parking'], tags: ['wine', 'spirits'], featured: true, isVerified: true,
        deliveryRadius: 12, averagePreparationTime: 10, averageDeliveryTime: 30,
        openingHours: {
            monday: { open: '10:00', close: '22:00', isClosed: false },
            tuesday: { open: '10:00', close: '22:00', isClosed: false },
            wednesday: { open: '10:00', close: '22:00', isClosed: false },
            thursday: { open: '10:00', close: '22:00', isClosed: false },
            friday: { open: '10:00', close: '23:00', isClosed: false },
            saturday: { open: '10:00', close: '23:00', isClosed: false },
            sunday: { open: '12:00', close: '20:00', isClosed: false }
        }
    },
    {
        storeName: "Daily News",
        logo: "https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800",
        description: "Magazines and newspapers.",
        location: { type: 'Point', coordinates: [-0.1920, 5.5680], address: "12 Ridge, Accra", city: "Accra", area: "Ridge" },
        phone: "+233 24 333 2222", email: "dailynews@example.com", businessIdNumber: "BID-GM-020",
        isOpen: true, deliveryFee: 3, minOrder: 5, rating: 4.2, totalReviews: 60,
        categories: ["Newsstand"], is24Hours: false, hasParking: false, paymentMethods: ["cash"],
        services: ["Mobile Top-up"], productTypes: ["Stationery"],
        vendorType: "grabmart", status: "approved", createdAt: daysAgo(4), ratingSum: 252,
        priorityScore: 5, orderAcceptanceRate: 90, orderCancellationRate: 10,
        features: ['takeaway'], tags: ['news', 'daily'], featured: false, isVerified: true,
        deliveryRadius: 5, averagePreparationTime: 5, averageDeliveryTime: 15,
        openingHours: {
            monday: { open: '06:00', close: '18:00', isClosed: false },
            tuesday: { open: '06:00', close: '18:00', isClosed: false },
            wednesday: { open: '06:00', close: '18:00', isClosed: false },
            thursday: { open: '06:00', close: '18:00', isClosed: false },
            friday: { open: '06:00', close: '18:00', isClosed: false },
            saturday: { open: '07:00', close: '17:00', isClosed: false },
            sunday: { open: '07:00', close: '13:00', isClosed: false }
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
