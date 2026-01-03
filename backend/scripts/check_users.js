/**
 * Check Users Script
 * 
 * This script checks how many users are in the database
 * and shows their roles and active status.
 * 
 * Usage:
 *   node scripts/check_users.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

// Connect to MongoDB
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

// Main function
const main = async () => {
    console.log('👥 Checking Users in Database\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // Get all users
        const allUsers = await User.find({}).select('username email role isActive');
        console.log(`\n📊 Total Users: ${allUsers.length}`);

        // Get active customers (target for 'all' notifications)
        const activeCustomers = await User.find({
            role: 'customer',
            isActive: true
        }).select('username email');

        console.log(`\n✅ Active Customers: ${activeCustomers.length}`);

        if (activeCustomers.length > 0) {
            console.log('\nActive Customers:');
            activeCustomers.forEach((user, index) => {
                console.log(`   ${index + 1}. ${user.username} (${user.email})`);
            });
        } else {
            console.log('\n⚠️  No active customers found!');
            console.log('   This is why notifications targeting "all" won\'t be sent.');
        }

        // Show breakdown by role
        const breakdown = await User.aggregate([
            {
                $group: {
                    _id: { role: '$role', isActive: '$isActive' },
                    count: { $sum: 1 }
                }
            },
            {
                $sort: { '_id.role': 1 }
            }
        ]);

        console.log('\n📊 User Breakdown:');
        breakdown.forEach(item => {
            const status = item._id.isActive ? 'Active' : 'Inactive';
            const role = item._id.role || 'No Role';
            console.log(`   ${role} (${status}): ${item.count}`);
        });

        console.log('\n' + '='.repeat(60));
        console.log('\n💡 Tips:');
        console.log('   - Notifications targeting "all" only go to active customers');
        console.log('   - Create test users if needed for testing');
        console.log('   - Or use targetType: "user" with specific user IDs\n');

    } catch (error) {
        console.error('\n❌ Error checking users:', error.message);
    }

    process.exit(0);
};

// Run
main().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
