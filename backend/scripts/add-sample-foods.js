const mongoose = require('mongoose');
require('dotenv').config();

const Food = require('../models/Food');
const Category = require('../models/Category');
const Restaurant = require('../models/Restaurant');

const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ Connected to MongoDB');
  } catch (error) {
    console.error('❌ MongoDB connection error:', error);
    process.exit(1);
  }
};

const addSampleFoods = async () => {
  try {
    await connectDB();

    let restaurant = await Restaurant.findOne({ status: 'approved' });
    if (!restaurant) {
      restaurant = await Restaurant.findOne();
      if (!restaurant) {
        process.exit(1);
      }
      console.log(`No approved restaurant found. Using: ${restaurant.restaurant_name} (status: ${restaurant.status})`);
      console.log(`Note: Approve this restaurant for it to show in customer app.`);
    } else {
      console.log(`Using restaurant: ${restaurant.restaurant_name}`);
    }

    const categories = await Category.find({ isActive: true });
    if (categories.length === 0) {
      console.error('No categories found. Please run npm run init-db first.');
      process.exit(1);
    }
    console.log(`✅ Found ${categories.length} categories`);

    const sampleFoods = [
      {
        name: 'Classic Burger',
        description: 'Juicy beef patty with fresh lettuce, tomato, and special sauce',
        price: 25.99,
        category: categories.find(c => c.name === 'Fast Food')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500',
        ingredients: ['Beef patty', 'Lettuce', 'Tomato', 'Onion', 'Pickles', 'Burger bun'],
        isAvailable: true,
        rating: 4.5,
        totalReviews: 120
      },
      {
        name: 'Chicken Wings',
        description: 'Crispy fried chicken wings with your choice of sauce',
        price: 18.99,
        category: categories.find(c => c.name === 'Fast Food')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1527477396000-e27163b481c2?w=500',
        ingredients: ['Chicken wings', 'Flour', 'Spices', 'Hot sauce'],
        isAvailable: true,
        rating: 4.7,
        totalReviews: 89
      },
      {
        name: 'French Fries',
        description: 'Golden crispy fries served with ketchup',
        price: 8.99,
        category: categories.find(c => c.name === 'Fast Food')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=500',
        ingredients: ['Potatoes', 'Salt', 'Oil'],
        isAvailable: true,
        rating: 4.3,
        totalReviews: 200
      },
      {
        name: 'Margherita Pizza',
        description: 'Classic pizza with tomato sauce, mozzarella, and fresh basil',
        price: 32.99,
        category: categories.find(c => c.name === 'Pizza')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=500',
        ingredients: ['Pizza dough', 'Tomato sauce', 'Mozzarella cheese', 'Fresh basil'],
        isAvailable: true,
        rating: 4.6,
        totalReviews: 150
      },
      {
        name: 'Pepperoni Pizza',
        description: 'Classic pepperoni pizza with extra cheese',
        price: 35.99,
        category: categories.find(c => c.name === 'Pizza')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=500',
        ingredients: ['Pizza dough', 'Tomato sauce', 'Mozzarella cheese', 'Pepperoni'],
        isAvailable: true,
        rating: 4.8,
        totalReviews: 180
      },
      {
        name: 'Club Sandwich',
        description: 'Triple-decker sandwich with chicken, bacon, lettuce, and mayo',
        price: 22.99,
        category: categories.find(c => c.name === 'Quick Bite')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586?w=500',
        ingredients: ['Bread', 'Chicken', 'Bacon', 'Lettuce', 'Tomato', 'Mayo'],
        isAvailable: true,
        rating: 4.4,
        totalReviews: 95
      },
      {
        name: 'Chicken Wrap',
        description: 'Grilled chicken wrap with vegetables and ranch dressing',
        price: 19.99,
        category: categories.find(c => c.name === 'Quick Bite')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=500',
        ingredients: ['Tortilla', 'Grilled chicken', 'Lettuce', 'Tomato', 'Onion', 'Ranch dressing'],
        isAvailable: true,
        rating: 4.5,
        totalReviews: 110
      },
      {
        name: 'Chocolate Cake',
        description: 'Rich and moist chocolate cake with chocolate frosting',
        price: 15.99,
        category: categories.find(c => c.name === 'Desserts')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500',
        ingredients: ['Flour', 'Sugar', 'Cocoa powder', 'Eggs', 'Butter', 'Chocolate'],
        isAvailable: true,
        rating: 4.9,
        totalReviews: 75
      },
      {
        name: 'Ice Cream Sundae',
        description: 'Vanilla ice cream with chocolate sauce, whipped cream, and cherry',
        price: 12.99,
        category: categories.find(c => c.name === 'Desserts')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1563805042-7684c019e1b3?w=500',
        ingredients: ['Vanilla ice cream', 'Chocolate sauce', 'Whipped cream', 'Cherry'],
        isAvailable: true,
        rating: 4.7,
        totalReviews: 130
      },
      {
        name: 'Fresh Orange Juice',
        description: 'Freshly squeezed orange juice',
        price: 6.99,
        category: categories.find(c => c.name === 'Beverages')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=500',
        ingredients: ['Oranges'],
        isAvailable: true,
        rating: 4.6,
        totalReviews: 160
      },
      {
        name: 'Iced Coffee',
        description: 'Cold brewed coffee with ice and milk',
        price: 8.99,
        category: categories.find(c => c.name === 'Beverages')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1517487881594-2787fef5ebf7?w=500',
        ingredients: ['Coffee', 'Milk', 'Ice', 'Sugar'],
        isAvailable: true,
        rating: 4.5,
        totalReviews: 140
      },
      {
        name: 'Caesar Salad',
        description: 'Fresh romaine lettuce with Caesar dressing, croutons, and parmesan',
        price: 16.99,
        category: categories.find(c => c.name === 'Healthy')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=500',
        ingredients: ['Romaine lettuce', 'Caesar dressing', 'Croutons', 'Parmesan cheese'],
        isAvailable: true,
        rating: 4.4,
        totalReviews: 100
      },
      {
        name: 'Grilled Chicken Salad',
        description: 'Mixed greens with grilled chicken, vegetables, and vinaigrette',
        price: 19.99,
        category: categories.find(c => c.name === 'Healthy')?._id || categories[0]._id,
        restaurant: restaurant._id,
        food_image: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
        ingredients: ['Mixed greens', 'Grilled chicken', 'Tomato', 'Cucumber', 'Carrots', 'Vinaigrette'],
        isAvailable: true,
        rating: 4.6,
        totalReviews: 85
      }
    ];

    let added = 0;
    let skipped = 0;

    for (const food of sampleFoods) {
      const existing = await Food.findOne({
        name: food.name,
        restaurant: food.restaurant
      });

      if (existing) {
        console.log(`⏭Skipped: ${food.name} (already exists)`);
        skipped++;
        continue;
      }

      await Food.create(food);
      console.log(`Added: ${food.name} - $${food.price}`);
      added++;
    }

    console.log('Sample foods added successfully!');
    console.log(`   Added: ${added} foods`);
    console.log(`   Skipped: ${skipped} foods (already exist)`);
    console.log(`   Restaurant: ${restaurant.restaurant_name}`);
    
    process.exit(0);
  } catch (error) {
    console.error('Error adding sample foods:', error);
    process.exit(1);
  }
};

addSampleFoods();

