/**
 * Database initialization script
 * Creates default categories and admin user
 */

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const User = require('../models/User');
const Category = require('../models/Category');

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

const initDatabase = async () => {
  try {
    await connectDB();

    // Create default admin user if it doesn't exist
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@grabgo.com';
    const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';
    
    const existingAdmin = await User.findOne({ email: adminEmail });
    if (!existingAdmin) {
      const hashedPassword = await bcrypt.hash(adminPassword, 10);
      const admin = await User.create({
        username: 'admin',
        email: adminEmail,
        password: hashedPassword,
        isAdmin: true,
        role: 'admin',
        isEmailVerified: true,
        isActive: true,
        permissions: {
          canManageUsers: true,
          canManageProducts: true,
          canManageOrders: true,
          canManageContent: true
        }
      });
      console.log('✅ Admin user created:', adminEmail);
      console.log('   Default password:', adminPassword);
      console.log('   ⚠️  Please change the password after first login!');
    } else {
      console.log('ℹ️  Admin user already exists');
    }

    // Create default categories
    const defaultCategories = [
      { name: 'Fast Food', description: 'Quick and delicious fast food options', emoji: '🍔' },
      { name: 'Pizza', description: 'Freshly baked pizzas', emoji: '🍕' },
      { name: 'Quick Bite', description: 'Quick bite options', emoji: '🥪' },
      { name: 'Desserts', description: 'Sweet treats and desserts', emoji: '🍰' },
      { name: 'Beverages', description: 'Drinks and beverages', emoji: '🥤' },
      { name: 'Healthy', description: 'Healthy food options', emoji: '🥗' }
    ];

    for (const category of defaultCategories) {
      const existing = await Category.findOne({ name: category.name });
      if (!existing) {
        await Category.create(category);
        console.log(`✅ Category created: ${category.name}`);
      }
    }

    console.log('✅ Database initialization completed!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error initializing database:', error);
    process.exit(1);
  }
};

initDatabase();

