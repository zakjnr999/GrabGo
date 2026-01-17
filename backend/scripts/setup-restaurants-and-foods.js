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
        location: {
          type: "Point",
          coordinates: [-0.1674, 5.6969],
          address: "Adenta Madina",
          city: "Adenta",
          area: "Madina"
        },
        ownerFullName: "Adepa Res",
        ownerContactNumber: "0536997662",
        businessIdNumber: "AHHSJJ66634",
        password: "password123",
        foodType: "Local & International",
        description: "Adepa Restaurant is a cozy and vibrant dining spot that blends traditional and modern flavors to create an unforgettable experience. Known for its warm hospitality and authentic dishes, Adepa Restaurant serves a variety of delicious meals made from the freshest local ingredients.",
        averageDeliveryTime: 30,
        averagePreparationTime: 15,
        deliveryFee: 5.00,
        minOrder: 20.00,
        paymentMethods: ["cash", "card", "mobile_money"],
        bannerImages: [
          "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800",
          "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800"
        ],
        logo: "https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800",
        rating: 4.0,
        isOpen: true,
        status: "approved",
        vendorType: "restaurant",
        ratingSum: 400,
        totalReviews: 100,
        priorityScore: 10,
        orderAcceptanceRate: 98,
        orderCancellationRate: 2,
        features: ['takeaway', 'dine_in', 'outdoor_seating'],
        tags: ['local', 'international', 'cozy'],
        featured: true,
        isVerified: true,
        deliveryRadius: 10,
        openingHours: {
          monday: { open: '08:00', close: '22:00', isClosed: false },
          tuesday: { open: '08:00', close: '22:00', isClosed: false },
          wednesday: { open: '08:00', close: '22:00', isClosed: false },
          thursday: { open: '08:00', close: '22:00', isClosed: false },
          friday: { open: '08:00', close: '23:00', isClosed: false },
          saturday: { open: '09:00', close: '23:00', isClosed: false },
          sunday: { open: '10:00', close: '22:00', isClosed: false }
        },
        socials: {
          facebook: 'https://facebook.com/adepa',
          instagram: 'https://instagram.com/adepa'
        }
      },
      {
        restaurantName: "Tasty Bites",
        email: "tastybites@gmail.com",
        phone: "0241234567",
        location: {
          type: "Point",
          coordinates: [-0.1870, 5.6037],
          address: "Accra Central",
          city: "Accra",
          area: "Central Business District"
        },
        ownerFullName: "John Doe",
        ownerContactNumber: "0241234567",
        businessIdNumber: "TB123456789",
        password: "password123",
        foodType: "Fast Food & Quick Bites",
        description: "Tasty Bites offers delicious fast food options with a focus on quality and speed.",
        averageDeliveryTime: 25,
        averagePreparationTime: 10,
        deliveryFee: 4.50,
        minOrder: 15.00,
        paymentMethods: ["cash", "card", "mobile_money"],
        bannerImages: [
          "https://images.unsplash.com/photo-1551782450-17144efb9c50?w=800",
          "https://images.unsplash.com/photo-1550547660-d9450f859349?w=800"
        ],
        logo: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
        rating: 4.5,
        isOpen: true,
        status: "approved",
        vendorType: "restaurant",
        ratingSum: 450,
        totalReviews: 100,
        priorityScore: 8,
        orderAcceptanceRate: 95,
        orderCancellationRate: 5,
        features: ['takeaway', 'air_conditioned'],
        tags: ['fast food', 'burgers', 'pizza'],
        featured: false,
        isVerified: true,
        deliveryRadius: 8,
        openingHours: {
          monday: { open: '09:00', close: '21:00', isClosed: false },
          tuesday: { open: '09:00', close: '21:00', isClosed: false },
          wednesday: { open: '09:00', close: '21:00', isClosed: false },
          thursday: { open: '09:00', close: '21:00', isClosed: false },
          friday: { open: '09:00', close: '22:00', isClosed: false },
          saturday: { open: '10:00', close: '22:00', isClosed: false },
          sunday: { open: '10:00', close: '20:00', isClosed: false }
        },
        socials: {
          instagram: 'https://instagram.com/tastybites'
        }
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
        name: 'Classic Burger',
        description: 'Juicy beef patty with fresh lettuce, tomato, and special sauce',
        price: 25.99,
        category: categories.find(c => c.name === 'Fast Food')?._id || categories[0]?._id,
        foodImage: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500',
        ingredients: ['Beef patty', 'Lettuce', 'Tomato', 'Onion', 'Pickles', 'Burger bun'],
        rating: 4.5,
        totalReviews: 120,
        isAvailable: true
      },
      {
        name: 'Margherita Pizza',
        description: 'Classic tomato and mozzarella pizza with fresh basil',
        price: 45.00,
        category: categories.find(c => c.name === 'Pizza')?._id || categories[0]?._id,
        foodImage: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500',
        ingredients: ['Pizza dough', 'Tomato sauce', 'Mozzarella', 'Basil'],
        rating: 4.8,
        totalReviews: 156,
        isAvailable: true
      }
    ];

    // Distribute foods to restaurants
    for (const restaurant of approvedRestaurants) {
      for (const foodTemplate of allFoodItems) {
        await Food.create({
          ...foodTemplate,
          restaurant: restaurant._id
        });
      }
      console.log(`   ✅ Added foods to: ${restaurant.restaurantName}`);
    }

    console.log('✅ Setup completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error setting up restaurants and foods:', error);
    process.exit(1);
  }
};

setupRestaurantsAndFoods();
