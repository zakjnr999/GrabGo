/**
 * Script to create admin users in MongoDB
 * Run this script from the backend directory: node scripts/createAdmin.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('../models/User');

// Admin user details - CHANGE THESE VALUES
const ADMIN_EMAIL = 'admin@grabgo.com';
const ADMIN_PASSWORD = 'Admin@123456'; // Change this to your desired password
const ADMIN_USERNAME = 'admin';

async function createAdminUser() {
    try {
        // Connect to MongoDB
        console.log('🔌 Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');

        // Check if admin already exists
        const existingAdmin = await User.findOne({ email: ADMIN_EMAIL });

        if (existingAdmin) {
            console.log('⚠️  Admin user already exists with email:', ADMIN_EMAIL);
            console.log('📧 Email:', existingAdmin.email);
            console.log('👤 Username:', existingAdmin.username);
            console.log('🔑 Role:', existingAdmin.role);
            console.log('🛡️  isAdmin:', existingAdmin.isAdmin);

            // Ask if you want to update the password
            console.log('\n💡 To update the password, delete the existing user from MongoDB and run this script again.');
            process.exit(0);
        }

        // Hash the password
        console.log('🔐 Hashing password...');
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(ADMIN_PASSWORD, salt);

        // Create admin user
        console.log('👤 Creating admin user...');
        const adminUser = await User.create({
            username: ADMIN_USERNAME,
            email: ADMIN_EMAIL,
            password: hashedPassword,
            role: 'admin',
            isAdmin: true,
            isActive: true,
            isEmailVerified: true,
            isPhoneVerified: false,
        });

        console.log('\n✅ Admin user created successfully!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📧 Email:', adminUser.email);
        console.log('👤 Username:', adminUser.username);
        console.log('🔑 Password:', ADMIN_PASSWORD);
        console.log('🛡️  Role:', adminUser.role);
        console.log('✅ isAdmin:', adminUser.isAdmin);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('\n⚠️  IMPORTANT: Save these credentials securely!');
        console.log('💡 You can now login to the admin panel with these credentials.');

    } catch (error) {
        console.error('❌ Error creating admin user:', error.message);
        console.error(error);
    } finally {
        // Disconnect from MongoDB
        await mongoose.disconnect();
        console.log('\n🔌 Disconnected from MongoDB');
        process.exit(0);
    }
}

// Run the script
createAdminUser();
