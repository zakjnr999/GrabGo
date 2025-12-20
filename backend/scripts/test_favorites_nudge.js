/**
 * Test Favorites-Based Notifications
 * 
 * This script verifies the logic for identifying users who haven't 
 * ordered from their favorites in a while and sending them a nudge.
 * 
 * Usage:
 *   node scripts/test_favorites_nudge.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Restaurant = require('../models/Restaurant');
const Notification = require('../models/Notification');
const { processFavoritesNudges } = require('../services/favorites_nudge_service');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const testFavoritesNudge = async () => {
    console.log('🧪 Testing Favorites-Based Notifications\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // 1. Prepare test user
        console.log('\n👤 1. Preparing test user...');
        const user = await User.findOne({ email: 'zakjnr5@gmail.com' });
        if (!user) {
            console.log('❌ Test user zakjnr5@gmail.com not found');
            process.exit(1);
        }

        // Ensure they have a favorite restaurant
        let favRestaurantId;
        if (!user.favorites?.restaurants || user.favorites.restaurants.length === 0) {
            console.log('   Adding a favorite restaurant for testing...');
            const restaurant = await Restaurant.findOne();
            if (!restaurant) {
                console.log('❌ No restaurants found in DB to add to favorites');
                process.exit(1);
            }
            favRestaurantId = restaurant._id;
            await User.findByIdAndUpdate(user._id, {
                $push: {
                    'favorites.restaurants': {
                        restaurantId: favRestaurantId,
                        addedAt: new Date()
                    }
                }
            });
        } else {
            favRestaurantId = user.favorites.restaurants[0].restaurantId;
        }

        // Set eligibility criteria
        const eightDaysAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000);
        const fourDaysAgo = new Date(Date.now() - 4 * 24 * 60 * 60 * 1000);

        await User.findByIdAndUpdate(user._id, {
            lastOrderDate: eightDaysAgo,
            lastFavoritesNudgeAt: fourDaysAgo,
            favoritesNudgesThisWeek: 0,
            'notificationSettings.promoNotifications': true
        });

        console.log(`✅ User ${user.email} is now eligible for a nudge`);
        console.log(`   Last Order: ${eightDaysAgo.toDateString()}`);
        console.log(`   Last Nudge: ${fourDaysAgo.toDateString()}`);

        // 2. Trigger nudges
        console.log('\n🚀 2. Triggering favorites nudges...');
        await processFavoritesNudges();

        // 3. Verify results
        console.log('\n📊 3. Verifying results...');
        const updatedUser = await User.findById(user._id);
        const notification = await Notification.findOne({
            user: user._id,
            type: 'favorites_reminder'
        }).sort({ createdAt: -1 });

        if (notification) {
            console.log('✅ Success! Notification created');
            console.log(`   Title: ${notification.title}`);
            console.log(`   Message: ${notification.message}`);
            console.log(`   Restaurant ID: ${notification.data.restaurantId}`);
        } else {
            console.log('❌ Failed: No notification found');
        }

        if (updatedUser.favoritesNudgesThisWeek === 1) {
            console.log('✅ Success! User tracking updated (nudgesCount = 1)');
        } else {
            console.log(`❌ Failed: User tracking not updated correctly (${updatedUser.favoritesNudgesThisWeek})`);
        }

        console.log('\n✅ TEST COMPLETE');

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    } finally {
        await mongoose.connection.close();
        process.exit(0);
    }
};

testFavoritesNudge();
