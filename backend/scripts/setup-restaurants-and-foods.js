const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");
require("dotenv").config();

const Restaurant = require("../models/Restaurant");
const Food = require("../models/Food");
const Category = require("../models/Category");

const connectDB = async () => {
  try {
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/grabgo",
      {
        useNewUrlParser: true,
        useUnifiedTopology: true,
      }
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
    let approvedRestaurants = await Restaurant.find({ status: "approved" });
    console.log(`   Found ${approvedRestaurants.length} approved restaurant(s)`);

    const restaurantTemplates = [
      {
        restaurant_name: "Adepa Restaurant",
        email: "adepa@gmail.com",
        phone: "0552501805",
        address: "Adenta Madina",
        city: "Adenta",
        owner_full_name: "Adepa Res",
        owner_contact_number: "0536997662",
        business_id_number: "AHHSJJ66634",
        password: "password123",
        food_type: "Local & International",
        description: "Adepa Restaurant is a cozy and vibrant dining spot that blends traditional and modern flavors to create an unforgettable experience. Known for its warm hospitality and authentic dishes, Adepa Restaurant serves a variety of delicious meals made from the freshest local ingredients. Whether you're craving a hearty local delicacy or an international favorite, Adepa's diverse menu and relaxing atmosphere make it the perfect place to enjoy good food and great company.",
        latitude: 5.6969,
        longitude: -0.1674,
        average_delivery_time: "25-30 mins",
        delivery_fee: 5.00,
        min_order: 20.00,
        opening_hours: "9:00 AM - 10:00 PM",
        payment_methods: ["Cash", "Mobile Money", "Card"],
        banner_images: [
          "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800",
          "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
          "https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800"
        ],
        logo: "https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800",
        rating: 4.0,
        is_open: true,
        status: "approved"
      },
      {
        restaurant_name: "Tasty Bites",
        email: "tastybites@gmail.com",
        phone: "0241234567",
        address: "Accra Central",
        city: "Accra",
        owner_full_name: "John Doe",
        owner_contact_number: "0241234567",
        business_id_number: "TB123456789",
        password: "password123",
        food_type: "Fast Food & Quick Bites",
        description: "Tasty Bites offers delicious fast food options with a focus on quality and speed. From juicy burgers to crispy fries, we serve up your favorite comfort foods with a smile.",
        latitude: 5.6037,
        longitude: -0.1870,
        average_delivery_time: "20-25 mins",
        delivery_fee: 4.50,
        min_order: 15.00,
        opening_hours: "8:00 AM - 11:00 PM",
        payment_methods: ["Cash", "Mobile Money", "Card"],
        banner_images: [
          "https://images.unsplash.com/photo-1551782450-17144efb9c50?w=800",
          "https://images.unsplash.com/photo-1550547660-d9450f859349?w=800"
        ],
        logo: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
        rating: 4.5,
        is_open: true,
        status: "approved"
      },
      {
        restaurant_name: "Pizza Palace",
        email: "pizzapalace@gmail.com",
        phone: "0247654321",
        address: "East Legon",
        city: "Accra",
        owner_full_name: "Jane Smith",
        owner_contact_number: "0247654321",
        business_id_number: "PP987654321",
        password: "password123",
        food_type: "Pizza & Italian",
        description: "Pizza Palace brings authentic Italian flavors to Accra. Our wood-fired pizzas are made with fresh ingredients and traditional recipes, delivering a taste of Italy right to your door.",
        latitude: 5.6500,
        longitude: -0.1500,
        average_delivery_time: "30-35 mins",
        delivery_fee: 6.00,
        min_order: 25.00,
        opening_hours: "10:00 AM - 10:00 PM",
        payment_methods: ["Cash", "Mobile Money", "Card"],
        banner_images: [
          "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800",
          "https://images.unsplash.com/photo-1628840042765-356cda07504e?w=800"
        ],
        logo: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500",
        rating: 4.3,
        is_open: true,
        status: "approved"
      }
    ];

    for (const template of restaurantTemplates) {
      let restaurant = await Restaurant.findOne({
        $or: [
          { restaurant_name: template.restaurant_name },
          { email: template.email },
          { business_id_number: template.business_id_number }
        ]
      });

      if (restaurant) {
        restaurant.status = "approved";
        restaurant.food_type = restaurant.food_type || template.food_type;
        restaurant.description = restaurant.description || template.description;
        restaurant.latitude = restaurant.latitude || template.latitude;
        restaurant.longitude = restaurant.longitude || template.longitude;
        restaurant.average_delivery_time = restaurant.average_delivery_time || template.average_delivery_time;
        restaurant.delivery_fee = restaurant.delivery_fee || template.delivery_fee;
        restaurant.min_order = restaurant.min_order || template.min_order;
        restaurant.opening_hours = restaurant.opening_hours || template.opening_hours;
        restaurant.payment_methods = restaurant.payment_methods && restaurant.payment_methods.length > 0
          ? restaurant.payment_methods
          : template.payment_methods;
        restaurant.banner_images = restaurant.banner_images && restaurant.banner_images.length > 0
          ? restaurant.banner_images
          : template.banner_images;
        restaurant.is_open = true;
        restaurant.rating = restaurant.rating || template.rating;
        await restaurant.save();
        console.log(`   ✅ Updated: ${restaurant.restaurant_name}`);
      } else {
        const hashedPassword = await bcrypt.hash(template.password, 10);
        restaurant = await Restaurant.create({
          ...template,
          password: hashedPassword
        });
        console.log(`   ✅ Created: ${restaurant.restaurant_name}`);
      }
    }

    approvedRestaurants = await Restaurant.find({ status: "approved" });
    console.log(`\n✅ Total approved restaurants: ${approvedRestaurants.length}`);

    if (approvedRestaurants.length < 3) {
      console.log("⚠️  Warning: Less than 3 approved restaurants. Some restaurants may need manual approval.");
    }

    console.log("\n📋 Step 2: Cleaning up existing food items...");
    const deletedCount = await Food.deleteMany({});
    console.log(`   ✅ Deleted ${deletedCount.deletedCount} existing food item(s)`);

    console.log("\n📋 Step 3: Creating and distributing food items...");
    const categories = await Category.find({ isActive: true });
    if (categories.length === 0) {
      console.log("   ⚠️  No categories found. Please run 'npm run init-db' first.");
      process.exit(0);
    }

    const allFoodItems = [
      {
        name: 'Classic Burger',
        description: 'Juicy beef patty with fresh lettuce, tomato, and special sauce',
        price: 25.99,
        category: categories.find(c => c.name === 'Fast Food') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500',
        ingredients: ['Beef patty', 'Lettuce', 'Tomato', 'Onion', 'Pickles', 'Burger bun'],
        rating: 4.5,
        totalReviews: 120
      },
      {
        name: 'Chicken Wings',
        description: 'Crispy fried chicken wings with your choice of sauce',
        price: 18.99,
        category: categories.find(c => c.name === 'Fast Food') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=500',
        ingredients: ['Chicken wings', 'Flour', 'Spices', 'Hot sauce'],
        rating: 4.7,
        totalReviews: 89
      },
      {
        name: 'French Fries',
        description: 'Golden crispy fries served with ketchup',
        price: 8.99,
        category: categories.find(c => c.name === 'Fast Food') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500',
        ingredients: ['Potatoes', 'Salt', 'Oil'],
        rating: 4.3,
        totalReviews: 200
      },
      {
        name: 'Margherita Pizza',
        description: 'Classic pizza with tomato sauce, mozzarella, and fresh basil',
        price: 32.99,
        category: categories.find(c => c.name === 'Pizza') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500',
        ingredients: ['Pizza dough', 'Tomato sauce', 'Mozzarella cheese', 'Fresh basil'],
        rating: 4.6,
        totalReviews: 150
      },
      {
        name: 'Pepperoni Pizza',
        description: 'Classic pepperoni pizza with extra cheese',
        price: 35.99,
        category: categories.find(c => c.name === 'Pizza') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500',
        ingredients: ['Pizza dough', 'Tomato sauce', 'Mozzarella cheese', 'Pepperoni'],
        rating: 4.8,
        totalReviews: 180
      },
      {
        name: 'Club Sandwich',
        description: 'Triple-decker sandwich with chicken, bacon, lettuce, and mayo',
        price: 22.99,
        category: categories.find(c => c.name === 'Quick Bite') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586?w=500',
        ingredients: ['Bread', 'Chicken', 'Bacon', 'Lettuce', 'Tomato', 'Mayo'],
        rating: 4.4,
        totalReviews: 95
      },
      {
        name: 'Chicken Wrap',
        description: 'Grilled chicken wrap with vegetables and ranch dressing',
        price: 19.99,
        category: categories.find(c => c.name === 'Quick Bite') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=500',
        ingredients: ['Tortilla', 'Grilled chicken', 'Lettuce', 'Tomato', 'Onion', 'Ranch dressing'],
        rating: 4.5,
        totalReviews: 110
      },
      {
        name: 'Chocolate Cake',
        description: 'Rich and moist chocolate cake with chocolate frosting',
        price: 15.99,
        category: categories.find(c => c.name === 'Desserts') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500',
        ingredients: ['Flour', 'Sugar', 'Cocoa powder', 'Eggs', 'Butter', 'Chocolate'],
        rating: 4.9,
        totalReviews: 75
      },
      {
        name: 'Ice Cream Sundae',
        description: 'Vanilla ice cream with chocolate sauce, whipped cream, and cherry',
        price: 12.99,
        category: categories.find(c => c.name === 'Desserts') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1563805042-7684c019e1b3?w=500',
        ingredients: ['Vanilla ice cream', 'Chocolate sauce', 'Whipped cream', 'Cherry'],
        rating: 4.7,
        totalReviews: 130
      },
      {
        name: 'Fresh Orange Juice',
        description: 'Freshly squeezed orange juice',
        price: 6.99,
        category: categories.find(c => c.name === 'Beverages') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=500',
        ingredients: ['Oranges'],
        rating: 4.6,
        totalReviews: 160
      },
      {
        name: 'Iced Coffee',
        description: 'Cold brewed coffee with ice and milk',
        price: 8.99,
        category: categories.find(c => c.name === 'Beverages') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1517487881594-2787fef5ebf7?w=500',
        ingredients: ['Coffee', 'Milk', 'Ice', 'Sugar'],
        rating: 4.5,
        totalReviews: 140
      },
      {
        name: 'Caesar Salad',
        description: 'Fresh romaine lettuce with Caesar dressing, croutons, and parmesan',
        price: 16.99,
        category: categories.find(c => c.name === 'Healthy') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=500',
        ingredients: ['Romaine lettuce', 'Caesar dressing', 'Croutons', 'Parmesan cheese'],
        rating: 4.4,
        totalReviews: 100
      },
      {
        name: 'Grilled Chicken Salad',
        description: 'Mixed greens with grilled chicken, vegetables, and vinaigrette',
        price: 19.99,
        category: categories.find(c => c.name === 'Healthy') || categories[0],
        food_image: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
        ingredients: ['Mixed greens', 'Grilled chicken', 'Tomato', 'Cucumber', 'Carrots', 'Vinaigrette'],
        rating: 4.6,
        totalReviews: 85
      }
    ];

    let totalCreated = 0;
    const itemsPerRestaurant = Math.ceil(allFoodItems.length / approvedRestaurants.length);

    for (let i = 0; i < approvedRestaurants.length; i++) {
      const restaurant = approvedRestaurants[i];
      const startIndex = i * itemsPerRestaurant;
      const endIndex = Math.min(startIndex + itemsPerRestaurant, allFoodItems.length);
      const restaurantFoods = allFoodItems.slice(startIndex, endIndex);

      console.log(`\n   📍 ${restaurant.restaurant_name}: ${restaurantFoods.length} food item(s)`);

      for (const foodItem of restaurantFoods) {
        await Food.create({
          name: foodItem.name,
          description: foodItem.description,
          price: foodItem.price,
          food_image: foodItem.food_image,
          category: foodItem.category._id,
          restaurant: restaurant._id,
          isAvailable: true,
          ingredients: foodItem.ingredients,
          rating: foodItem.rating,
          totalReviews: foodItem.totalReviews
        });
        console.log(`      ✅ ${foodItem.name}`);
        totalCreated++;
      }
    }

    console.log("\n✅ Setup completed!");
    console.log(`   📊 Statistics:`);
    console.log(`      - Approved restaurants: ${approvedRestaurants.length}`);
    console.log(`      - Total food items created: ${totalCreated}`);
    console.log(`      - Food items per restaurant: ~${itemsPerRestaurant}`);

    process.exit(0);
  } catch (error) {
    console.error("❌ Error setting up restaurants and foods:", error);
    process.exit(1);
  }
};

setupRestaurantsAndFoods();

