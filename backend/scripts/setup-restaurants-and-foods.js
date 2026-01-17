const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
const path = require('path');
require("dotenv").config({ path: path.resolve(__dirname, '../.env') });

const Restaurant = require("../models/Restaurant");
const Food = require("../models/Food");
const Category = require("../models/Category");

const connectDB = async () => {
  try {
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/grabgo"
    );
    console.log("✅ Connected to MongoDB");
  } catch (error) {
    console.error("❌ MongoDB connection error:", error);
    process.exit(1);
  }
};

const setupRestaurantsAndFoods = async () => {
  try {
    await connectDB();

    console.log("\n📋 Step 1: Checking restaurants...");

    // Drop existing indexes to remove legacy conflicts
    await Restaurant.collection.dropIndexes();
    console.log("   ✅ Dropped existing indexes");

    // TEMPLATE DATA
    const restaurantTemplates = [
      {
        restaurantName: "Adepa Restaurant",
        email: "adepa@gmail.com",
        phone: "0552501805",
        location: { type: "Point", coordinates: [-0.1674, 5.6969], address: "Adenta Madina", city: "Adenta", area: "Madina" },
        ownerFullName: "Adepa Res", ownerContactNumber: "0536997662", businessIdNumber: "AHHSJJ66634", password: "password123",
        foodType: "Local & International", description: "Adepa Restaurant is a cozy and vibrant dining spot.",
        averageDeliveryTime: 30, averagePreparationTime: 15, deliveryFee: 5.00, minOrder: 20.00,
        paymentMethods: ["cash", "card", "mobile_money"],
        bannerImages: ["https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800"],
        logo: "https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800",
        rating: 4.0, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 400, totalReviews: 100,
        features: ['takeaway', 'dine_in'], tags: ['local', 'cozy'],
        isGrabGoExclusive: true,
        openingHours: { monday: { open: '08:00', close: '22:00', isClosed: false } }
      },
      {
        restaurantName: "Tasty Bites",
        email: "tastybites@gmail.com",
        phone: "0241234567",
        location: { type: "Point", coordinates: [-0.1870, 5.6037], address: "Accra Central", city: "Accra", area: "Central Business District" },
        ownerFullName: "John Doe", ownerContactNumber: "0241234567", businessIdNumber: "TB123456789", password: "password123",
        foodType: "Fast Food", description: "Tasty Bites offers delicious fast food options.",
        averageDeliveryTime: 25, averagePreparationTime: 10, deliveryFee: 4.50, minOrder: 15.00,
        paymentMethods: ["cash", "mobile_money"],
        bannerImages: ["https://images.unsplash.com/photo-1551782450-17144efb9c50?w=800"],
        logo: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
        rating: 4.5, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 450, totalReviews: 100,
        features: ['takeaway'], tags: ['fast food', 'burgers'],
        isGrabGoExclusive: true,
        openingHours: { monday: { open: '09:00', close: '21:00', isClosed: false } }
      },
      {
        restaurantName: "Sushi Zen",
        email: "sushizen@gmail.com",
        phone: "0201112222",
        location: { type: "Point", coordinates: [-0.1900, 5.5900], address: "Osu Oxford St", city: "Accra", area: "Osu" },
        ownerFullName: "Kenji Sato", ownerContactNumber: "0201112222", businessIdNumber: "SZ001", password: "password123",
        foodType: "Japanese", description: "Authentic sushi and Japanese cuisine.",
        averageDeliveryTime: 40, averagePreparationTime: 20, deliveryFee: 8.00, minOrder: 50.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=800"],
        logo: "https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800",
        rating: 4.8, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 480, totalReviews: 100,
        features: ['dine_in', 'takeaway'], tags: ['sushi', 'japanese'],
        isGrabGoExclusive: true,
        openingHours: { monday: { open: '11:00', close: '23:00', isClosed: false } }
      },
      {
        restaurantName: "Pasta La Vista",
        email: "pasta@gmail.com",
        phone: "0243334444",
        location: { type: "Point", coordinates: [-0.1600, 5.6100], address: "Cantonments", city: "Accra", area: "Cantonments" },
        ownerFullName: "Mario Rossi", ownerContactNumber: "0243334444", businessIdNumber: "PLV002", password: "password123",
        foodType: "Italian", description: "Homemade pasta and authentic Italian sauces.",
        averageDeliveryTime: 35, averagePreparationTime: 20, deliveryFee: 7.00, minOrder: 40.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800"],
        logo: "https://images.unsplash.com/photo-1595295333158-4742f28fbd85?w=800",
        rating: 4.6, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 460, totalReviews: 100,
        features: ['dine_in'], tags: ['italian', 'pasta'],
        openingHours: { monday: { open: '12:00', close: '22:00', isClosed: false } }
      },
      {
        restaurantName: "Spice Route",
        email: "spiceroute@gmail.com",
        phone: "0505556666",
        location: { type: "Point", coordinates: [-0.1500, 5.6500], address: "East Legon", city: "Accra", area: "East Legon" },
        ownerFullName: "Raj Patel", ownerContactNumber: "0505556666", businessIdNumber: "SR003", password: "password123",
        foodType: "Indian", description: "Spicy and flavorful Indian curries and tandoori.",
        averageDeliveryTime: 45, averagePreparationTime: 25, deliveryFee: 6.00, minOrder: 35.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800"],
        logo: "https://images.unsplash.com/photo-1585937421612-70a008356f36?w=800",
        rating: 4.4, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 440, totalReviews: 100,
        features: ['dine_in', 'halal'], tags: ['indian', 'spicy'],
        openingHours: { monday: { open: '11:00', close: '23:00', isClosed: false } }
      },
      {
        restaurantName: "Burger Kingz",
        email: "burgerkingz@gmail.com",
        phone: "0277778888",
        location: { type: "Point", coordinates: [-0.2000, 5.5600], address: "Circle", city: "Accra", area: "Circle" },
        ownerFullName: "King Burger", ownerContactNumber: "0277778888", businessIdNumber: "BK004", password: "password123",
        foodType: "American", description: "The king of burgers in town.",
        averageDeliveryTime: 20, averagePreparationTime: 10, deliveryFee: 4.00, minOrder: 15.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1550547660-d9450f859349?w=800"],
        logo: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
        rating: 4.2, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 420, totalReviews: 100,
        features: ['takeaway'], tags: ['burgers', 'fast food'],
        openingHours: { monday: { open: '09:00', close: '23:00', isClosed: false } }
      },
      {
        restaurantName: "Salad Bar",
        email: "saladbar@gmail.com",
        phone: "0269990000",
        location: { type: "Point", coordinates: [-0.1800, 5.5800], address: "Labone", city: "Accra", area: "Labone" },
        ownerFullName: "Sarah Green", ownerContactNumber: "0269990000", businessIdNumber: "SB005", password: "password123",
        foodType: "Healthy", description: "Fresh and healthy salads and smoothies.",
        averageDeliveryTime: 25, averagePreparationTime: 10, deliveryFee: 5.00, minOrder: 25.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800"],
        logo: "https://images.unsplash.com/photo-1546793665-c74683f339c1?w=800",
        rating: 4.7, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 470, totalReviews: 100,
        features: ['vegan_options'], tags: ['salad', 'healthy'],
        openingHours: { monday: { open: '08:00', close: '20:00', isClosed: false } }
      },
      {
        restaurantName: "Golden Dragon",
        email: "goldendragon@gmail.com",
        phone: "0541212121",
        location: { type: "Point", coordinates: [-0.1700, 5.6200], address: "Airport City", city: "Accra", area: "Airport" },
        ownerFullName: "Li Chen", ownerContactNumber: "0541212121", businessIdNumber: "GD006", password: "password123",
        foodType: "Chinese", description: "Authentic Chinese cuisine and dim sum.",
        averageDeliveryTime: 40, averagePreparationTime: 20, deliveryFee: 7.00, minOrder: 40.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1525755662778-989d64d6b636?w=800"],
        logo: "https://images.unsplash.com/photo-1563245372-f2172732006e?w=800",
        rating: 4.5, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 450, totalReviews: 100,
        features: ['dine_in'], tags: ['chinese', 'dim sum'],
        openingHours: { monday: { open: '11:00', close: '22:00', isClosed: false } }
      },
      {
        restaurantName: "Taco Fiesta",
        email: "tacofiesta@gmail.com",
        phone: "0234567890",
        location: { type: "Point", coordinates: [-0.1650, 5.5950], address: "Osu RE", city: "Accra", area: "Osu" },
        ownerFullName: "Carlos Gomez", ownerContactNumber: "0234567890", businessIdNumber: "TF007", password: "password123",
        foodType: "Mexican", description: "Tacos, burritos, and nachos made fresh.",
        averageDeliveryTime: 30, averagePreparationTime: 15, deliveryFee: 5.50, minOrder: 20.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800"],
        logo: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800",
        rating: 4.3, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 430, totalReviews: 100,
        features: ['takeaway'], tags: ['mexican', 'tacos'],
        openingHours: { monday: { open: '10:00', close: '23:00', isClosed: false } }
      },
      {
        restaurantName: "Café Moka",
        email: "cafemoka@gmail.com",
        phone: "0559991111",
        location: { type: "Point", coordinates: [-0.1750, 5.6050], address: "Roman Ridge", city: "Accra", area: "Roman Ridge" },
        ownerFullName: "Ama Coffee", ownerContactNumber: "0559991111", businessIdNumber: "CM008", password: "password123",
        foodType: "Cafe", description: "Best coffee and pastries in the neighborhood.",
        averageDeliveryTime: 20, averagePreparationTime: 10, deliveryFee: 3.50, minOrder: 10.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800"],
        logo: "https://images.unsplash.com/photo-1497935586351-b67a49e012bf?w=800",
        rating: 4.9, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 490, totalReviews: 100,
        features: ['dine_in', 'wifi'], tags: ['coffee', 'pastry'],
        openingHours: { monday: { open: '07:00', close: '18:00', isClosed: false } }
      },
      {
        restaurantName: "BBQ Nation",
        email: "bbqnation@gmail.com",
        phone: "0288882222",
        location: { type: "Point", coordinates: [-0.2100, 5.6300], address: "Achimota Forest", city: "Accra", area: "Achimota" },
        ownerFullName: "Big Joe", ownerContactNumber: "0288882222", businessIdNumber: "BN009", password: "password123",
        foodType: "BBQ", description: "Smoked ribs, grilled chicken, and more.",
        averageDeliveryTime: 40, averagePreparationTime: 25, deliveryFee: 6.00, minOrder: 30.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800"],
        logo: "https://images.unsplash.com/photo-1544025162-d76694265947?w=800",
        rating: 4.7, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 470, totalReviews: 100,
        features: ['outdoor_seating'], tags: ['bbq', 'meat'],
        openingHours: { monday: { open: '12:00', close: '22:00', isClosed: false } }
      },
      {
        restaurantName: "Sweet Treats",
        email: "sweettreats@gmail.com",
        phone: "0240001111",
        location: { type: "Point", coordinates: [-0.1850, 5.5500], address: "Osu", city: "Accra", area: "Osu" },
        ownerFullName: "Lisa Bake", ownerContactNumber: "0240001111", businessIdNumber: "ST010", password: "password123",
        foodType: "Dessert", description: "Cakes, cookies, and ice cream.",
        averageDeliveryTime: 20, averagePreparationTime: 5, deliveryFee: 3.00, minOrder: 10.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1551024601-5637ade98e30?w=800"],
        logo: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800",
        rating: 4.8, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 480, totalReviews: 100,
        features: ['takeaway'], tags: ['dessert', 'sweet'],
        openingHours: { monday: { open: '10:00', close: '20:00', isClosed: false } }
      },
      {
        restaurantName: "Seafood Delight",
        email: "seafooddelight@gmail.com",
        phone: "0271113333",
        location: { type: "Point", coordinates: [-0.0500, 5.6000], address: "Tema Beach", city: "Tema", area: "Community 1" },
        ownerFullName: "Captain Jack", ownerContactNumber: "0271113333", businessIdNumber: "SD011", password: "password123",
        foodType: "Seafood", description: "Fresh catch of the day, grilled to perfection.",
        averageDeliveryTime: 45, averagePreparationTime: 30, deliveryFee: 8.00, minOrder: 40.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1565656890453-a64dc6372b16?w=800"],
        logo: "https://images.unsplash.com/photo-1615141982880-131f274d5224?w=800",
        rating: 4.6, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 460, totalReviews: 100,
        features: ['outdoor_seating'], tags: ['seafood', 'beach'],
        openingHours: { monday: { open: '11:00', close: '22:00', isClosed: false } }
      },
      {
        restaurantName: "Breakfast Club",
        email: "breakfastclub@gmail.com",
        phone: "0549998888",
        location: { type: "Point", coordinates: [-0.1950, 5.5750], address: "Dzorwulu", city: "Accra", area: "Dzorwulu" },
        ownerFullName: "Morning Glory", ownerContactNumber: "0549998888", businessIdNumber: "BC012", password: "password123",
        foodType: "Breakfast", description: "All-day breakfast options.",
        averageDeliveryTime: 25, averagePreparationTime: 15, deliveryFee: 4.50, minOrder: 15.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1533089862017-ec326aa0530b?w=800"],
        logo: "https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=800",
        rating: 4.5, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 450, totalReviews: 100,
        features: ['wifi'], tags: ['breakfast', 'brunch'],
        openingHours: { monday: { open: '06:00', close: '15:00', isClosed: false } }
      },
      {
        restaurantName: "Smoothie King",
        email: "smoothieking@gmail.com",
        phone: "0205554444",
        location: { type: "Point", coordinates: [-0.1550, 5.6600], address: "Adjiringanor", city: "Accra", area: "East Legon" },
        ownerFullName: "Juicy Joe", ownerContactNumber: "0205554444", businessIdNumber: "SK013", password: "password123",
        foodType: "Smoothie", description: "Healthy fruit smoothies and juices.",
        averageDeliveryTime: 15, averagePreparationTime: 5, deliveryFee: 3.00, minOrder: 10.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=800"],
        logo: "https://images.unsplash.com/photo-1610970881699-44a5587cabec?w=800",
        rating: 4.8, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 480, totalReviews: 100,
        features: ['takeaway'], tags: ['smoothie', 'healthy'],
        openingHours: { monday: { open: '08:00', close: '20:00', isClosed: false } }
      },
      {
        restaurantName: "Kebab House",
        email: "kebabhouse@gmail.com",
        phone: "0232223333",
        location: { type: "Point", coordinates: [-0.1780, 5.6250], address: "Legon", city: "Accra", area: "Legon" },
        ownerFullName: "Ali Baba", ownerContactNumber: "0232223333", businessIdNumber: "KH014", password: "password123",
        foodType: "Middle Eastern", description: "Kebabs, shawarma, and falafel.",
        averageDeliveryTime: 30, averagePreparationTime: 15, deliveryFee: 5.00, minOrder: 20.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800"],
        logo: "https://images.unsplash.com/photo-1561758033-d8f5872948ce?w=800",
        rating: 4.6, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 460, totalReviews: 100,
        features: ['takeaway', 'halal'], tags: ['kebab', 'shawarma'],
        openingHours: { monday: { open: '10:00', close: '22:00', isClosed: false } }
      },
      {
        restaurantName: "Chicken Republic",
        email: "chickenrepublic@gmail.com",
        phone: "0550009999",
        location: { type: "Point", coordinates: [-0.1920, 5.5650], address: "Ring Road", city: "Accra", area: "Ring Road" },
        ownerFullName: "Mr. Chicken", ownerContactNumber: "0550009999", businessIdNumber: "CR015", password: "password123",
        foodType: "Fast Food", description: "Fried chicken and chips.",
        averageDeliveryTime: 25, averagePreparationTime: 10, deliveryFee: 4.00, minOrder: 15.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1569058242252-623df46b5025?w=800"],
        logo: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=800",
        rating: 4.3, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 430, totalReviews: 100,
        features: ['takeaway', 'air_conditioned'], tags: ['chicken', 'fast food'],
        openingHours: { monday: { open: '10:00', close: '22:00', isClosed: false } }
      },
      {
        restaurantName: "Sandwich & Co",
        email: "sandwichco@gmail.com",
        phone: "0278887777",
        location: { type: "Point", coordinates: [-0.1620, 5.5850], address: "Osu", city: "Accra", area: "Osu" },
        ownerFullName: "Sam Witch", ownerContactNumber: "0278887777", businessIdNumber: "SC016", password: "password123",
        foodType: "Sandwich", description: "Freshly made subs and sandwiches.",
        averageDeliveryTime: 20, averagePreparationTime: 10, deliveryFee: 3.50, minOrder: 15.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1554433607-66b5efe9d304?w=800"],
        logo: "https://images.unsplash.com/photo-1553909489-cdb173a24322?w=800",
        rating: 4.5, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 450, totalReviews: 100,
        features: ['takeaway'], tags: ['sandwich', 'lunch'],
        openingHours: { monday: { open: '09:00', close: '18:00', isClosed: false } }
      },
      {
        restaurantName: "Noodle House",
        email: "noodlehouse@gmail.com",
        phone: "0543332222",
        location: { type: "Point", coordinates: [-0.1880, 5.5920], address: "Airport", city: "Accra", area: "Airport" },
        ownerFullName: "Wang Wei", ownerContactNumber: "0543332222", businessIdNumber: "NH017", password: "password123",
        foodType: "Asian", description: "Stir-fried noodles and soups.",
        averageDeliveryTime: 30, averagePreparationTime: 15, deliveryFee: 5.00, minOrder: 25.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1552611052-33e04de081de?w=800"],
        logo: "https://images.unsplash.com/photo-1540344168270-55465bc7c5b9?w=800",
        rating: 4.4, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 440, totalReviews: 100,
        features: ['takeaway'], tags: ['noodles', 'asian'],
        openingHours: { monday: { open: '11:00', close: '21:00', isClosed: false } }
      },
      {
        restaurantName: "Vegan Vibes",
        email: "veganvibes@gmail.com",
        phone: "0209995555",
        location: { type: "Point", coordinates: [-0.1580, 5.6150], address: "East Legon", city: "Accra", area: "East Legon" },
        ownerFullName: "Leaf Green", ownerContactNumber: "0209995555", businessIdNumber: "VV018", password: "password123",
        foodType: "Vegan", description: "100% plant-based deliciousness.",
        averageDeliveryTime: 35, averagePreparationTime: 20, deliveryFee: 6.00, minOrder: 30.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800"],
        logo: "https://images.unsplash.com/photo-1584878462837-1d5758066870?w=800",
        rating: 4.8, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 480, totalReviews: 100,
        features: ['vegan_options'], tags: ['vegan', 'healthy', 'organic'],
        openingHours: { monday: { open: '10:00', close: '20:00', isClosed: false } }
      },
      {
        restaurantName: "Chop Bar",
        email: "chopbar@gmail.com",
        phone: "0261110000",
        location: { type: "Point", coordinates: [-0.2050, 5.5850], address: "Abeka Lapaz", city: "Accra", area: "Lapaz" },
        ownerFullName: "Mama T", ownerContactNumber: "0261110000", businessIdNumber: "CB019", password: "password123",
        foodType: "Local", description: "Authentic Ghanaian dishes like fufu and banku.",
        averageDeliveryTime: 30, averagePreparationTime: 20, deliveryFee: 4.00, minOrder: 15.00,
        paymentMethods: ["cash", "mobile_money"], bannerImages: ["https://images.unsplash.com/photo-1504544750208-dc0358e63f7f?w=800"],
        logo: "https://images.unsplash.com/photo-1555126634-323283e090fa?w=800",
        rating: 4.7, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 470, totalReviews: 100,
        features: ['dine_in'], tags: ['local', 'fufu', 'banku'],
        openingHours: { monday: { open: '09:00', close: '21:00', isClosed: false } }
      },
      {
        restaurantName: "Donut Delights",
        email: "donutdelights@gmail.com",
        phone: "0558887777",
        location: { type: "Point", coordinates: [-0.1800, 5.6000], address: "Kanda", city: "Accra", area: "Kanda" },
        ownerFullName: "Homer S", ownerContactNumber: "0558887777", businessIdNumber: "DD020", password: "password123",
        foodType: "Bakery", description: "Freshly glazed donuts and coffee.",
        averageDeliveryTime: 20, averagePreparationTime: 5, deliveryFee: 3.50, minOrder: 10.00,
        paymentMethods: ["cash", "card"], bannerImages: ["https://images.unsplash.com/photo-1551024601-5637ade98e30?w=800"],
        logo: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=800",
        rating: 4.6, isOpen: true, status: "approved", vendorType: "restaurant", ratingSum: 460, totalReviews: 100,
        features: ['takeaway'], tags: ['donut', 'bakery', 'sweet'],
        openingHours: { monday: { open: '08:00', close: '18:00', isClosed: false } }
      }
    ];

    // Clear and re-create to ensure schema compliance
    await Restaurant.deleteMany({});
    console.log("🗑️  Cleared existing restaurants");

    for (const template of restaurantTemplates) {
      const hashedPassword = await bcrypt.hash(template.password, 10);
      const restaurant = await Restaurant.create({
        ...template,
        password: hashedPassword
      });
      console.log(`   ✅ Created: ${restaurant.restaurantName}`);
    }

    const approvedRestaurants = await Restaurant.find({ status: "approved" });

    console.log("\n📋 Step 2: Cleaning up existing food items...");
    await Food.deleteMany({});
    console.log(`   ✅ Deleted existing food item(s)`);

    console.log("\n📋 Step 3: Creating food items...");
    const categories = await Category.find({ isActive: true });
    if (categories.length === 0) {
      console.log("   ⚠️  No categories found. Please run init-db first.");
      process.exit(0);
    }

    const allFoodItems = [
      {
        name: 'Classic Burger', description: 'Juicy beef patty with fresh lettuce, tomato, and special sauce', price: 25.99,
        categoryName: 'Fast Food', foodImage: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500',
        ingredients: ['Beef patty', 'Lettuce', 'Tomato', 'Onion', 'Pickles', 'Burger bun'], rating: 4.5, totalReviews: 120, isAvailable: true,
        orderCount: 150, discountPercentage: 10, discountEndDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      },
      {
        name: 'Margherita Pizza', description: 'Classic tomato and mozzarella pizza with fresh basil', price: 45.00,
        categoryName: 'Pizza', foodImage: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500',
        ingredients: ['Pizza dough', 'Tomato sauce', 'Mozzarella', 'Basil'], rating: 4.8, totalReviews: 156, isAvailable: true,
        orderCount: 220, discountPercentage: 15, discountEndDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000)
      },
      {
        name: 'Jollof Rice with Chicken', description: 'Spicy Ghanaian Jollof rice served with grilled chicken', price: 35.00,
        categoryName: 'Healthy', foodImage: 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=500',
        ingredients: ['Rice', 'Tomatoes', 'Chicken', 'Spices'], rating: 4.9, totalReviews: 200, isAvailable: true,
        orderCount: 450, discountPercentage: 0
      },
      {
        name: 'Thai Green Curry', description: 'Fragrant and spicy coconut curry with chicken and basil', price: 42.00,
        categoryName: 'Healthy', foodImage: 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=500',
        ingredients: ['Chicken', 'Coconut milk', 'Green curry paste', 'Bamboo shoots'], rating: 4.7, totalReviews: 88, isAvailable: true,
        orderCount: 215, discountPercentage: 0
      },
      {
        name: 'Chicken Tacos', description: 'Three soft corn tortillas with grilled chicken and salsa', price: 28.00,
        categoryName: 'Quick Bite', foodImage: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=500',
        ingredients: ['Chicken', 'Corn tortillas', 'Cilantro', 'Onion', 'Salsa'], rating: 4.6, totalReviews: 142, isAvailable: true,
        orderCount: 380, discountPercentage: 10
      },
      {
        name: 'Salmon Poke Bowl', description: 'Fresh salmon with avocado, edamame, and pickled ginger over rice', price: 55.00,
        categoryName: 'Healthy', foodImage: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
        ingredients: ['Salmon', 'Avocado', 'Rice', 'Edamame', 'Seaweed'], rating: 4.8, totalReviews: 95, isAvailable: true,
        orderCount: 160, discountPercentage: 0
      },
      {
        name: 'Pancakes with Syrup', description: 'Fluffy pancakes served with butter and maple syrup', price: 22.00,
        categoryName: 'Desserts', foodImage: 'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=500',
        ingredients: ['Flour', 'Milk', 'Eggs', 'Maple syrup'], rating: 4.5, totalReviews: 110, isAvailable: true,
        orderCount: 290, discountPercentage: 5
      },
      {
        name: 'Lamb Gyro', description: 'Grilled lamb in pita with tzatziki sauce and fries', price: 32.00,
        categoryName: 'Fast Food', foodImage: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=500',
        ingredients: ['Lamb', 'Pita', 'Tzatziki', 'Tomato', 'Onion'], rating: 4.7, totalReviews: 165, isAvailable: true,
        orderCount: 410, discountPercentage: 0
      },
      {
        name: 'Beef Pho', description: 'Vietnamese rice noodle soup with thinly sliced beef and herbs', price: 38.00,
        categoryName: 'Healthy', foodImage: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=500',
        ingredients: ['Rice noodles', 'Beef broth', 'Beef slices', 'Basil', 'Bean sprouts'], rating: 4.9, totalReviews: 120, isAvailable: true,
        orderCount: 305, discountPercentage: 0
      },
      {
        name: 'Falafel Wrap', description: 'Crispy falafel balls with hummus and fresh veggies in a wrap', price: 18.00,
        categoryName: 'Quick Bite', foodImage: 'https://images.unsplash.com/photo-1547496502-affa22d38842?w=500',
        ingredients: ['Falafel', 'Hummus', 'Tahini', 'Wrap', 'Cucumber'], rating: 4.4, totalReviews: 78, isAvailable: true,
        orderCount: 225, discountPercentage: 15
      },
      {
        name: 'Beef Burger', description: 'Double beef patty with cheese and bacon', price: 30.00,
        categoryName: 'Fast Food', foodImage: 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?w=500',
        ingredients: ['Beef', 'Cheese', 'Bacon', 'Burger bun'], rating: 4.6, totalReviews: 130, isAvailable: true,
        orderCount: 140, discountPercentage: 0
      },
      {
        name: 'Chicken Shawarma', description: 'Tender chicken strips wrapped in pita bread with veggies and sauce', price: 20.00,
        categoryName: 'Quick Bite', foodImage: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=500',
        ingredients: ['Chicken', 'Pita bread', 'Cabbage', 'Sauce'], rating: 4.5, totalReviews: 110, isAvailable: true,
        orderCount: 520, discountPercentage: 5, discountEndDate: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000)
      },
      {
        name: 'Pepperoni Pizza', description: 'Loaded with spicy pepperoni slices and extra cheese', price: 55.00,
        categoryName: 'Pizza', foodImage: 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500',
        ingredients: ['Pizza dough', 'Pepperoni', 'Cheese'], rating: 4.7, totalReviews: 180, isAvailable: true,
        orderCount: 310, discountPercentage: 0
      },
      {
        name: 'Fried Rice & Beef Sauce', description: 'Stir-fried rice with vegetables and savory beef sauce', price: 40.00,
        categoryName: 'Healthy', foodImage: 'https://images.unsplash.com/photo-1603133872878-684f57143b34?w=500',
        ingredients: ['Rice', 'Beef', 'Vegetables', 'Soy sauce'], rating: 4.6, totalReviews: 140, isAvailable: true,
        orderCount: 180, discountPercentage: 20, discountEndDate: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000)
      }
    ];

    // Distribute foods to restaurants with variation
    for (const restaurant of approvedRestaurants) {
      // Pick a random number of items (between 5 and 10) for this restaurant
      const shuffled = [...allFoodItems].sort(() => 0.5 - Math.random());
      const selectedItems = shuffled.slice(0, Math.floor(Math.random() * 6) + 5);

      for (const foodTemplate of selectedItems) {
        // Find category by name or fallback to first category
        let category = categories.find(c => c.name === foodTemplate.categoryName);
        if (!category && categories.length > 0) category = categories[0];

        // Add some random variation to make data look real
        const priceVariation = (Math.random() * 8 - 4); // +/- 4 GHS
        const finalPrice = Math.max(5, (foodTemplate.price || 20) + priceVariation);

        // Vary order count significantly (0 to 500)
        const finalOrderCount = Math.floor(Math.random() * 501);

        // Randomly decide if THIS specific restaurant has a deal on this item
        // 40% chance of a discount
        let finalDiscount = 0;
        let finalDiscountEnd = null;
        if (Math.random() < 0.4) {
          finalDiscount = (Math.floor(Math.random() * 6) + 1) * 5; // 5, 10, 15, 20, 25, 30%
          finalDiscountEnd = new Date(Date.now() + (Math.floor(Math.random() * 7) + 1) * 24 * 60 * 60 * 1000);
        }

        await Food.create({
          ...foodTemplate,
          price: parseFloat(finalPrice.toFixed(2)),
          orderCount: finalOrderCount,
          discountPercentage: finalDiscount,
          discountEndDate: finalDiscountEnd,
          category: category ? category._id : null,
          restaurant: restaurant._id,
          rating: parseFloat((Math.random() * 1.5 + 3.5).toFixed(1))
        });
      }
      console.log(`   ✅ Added ${selectedItems.length} varied foods to: ${restaurant.restaurantName}`);
    }

    console.log('✅ Setup completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting up restaurants and foods:', error);
    process.exit(1);
  }
};

setupRestaurantsAndFoods();
