const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, './.env') });
const Food = require('./models/Food');

async function testAggregation() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB\n');

        // Test the exact aggregation pipeline used in the API
        const popularItems = await Food.aggregate([
            { $match: { isAvailable: true } },
            { $sort: { orderCount: -1, rating: -1 } },
            {
                $group: {
                    _id: "$name",
                    doc: { $first: "$$ROOT" }
                }
            },
            { $replaceRoot: { newRoot: "$doc" } },
            { $sort: { orderCount: -1, rating: -1 } },
            { $limit: 3 },
            {
                $lookup: {
                    from: "categories",
                    localField: "category",
                    foreignField: "_id",
                    as: "category"
                }
            },
            { $unwind: { path: "$category", preserveNullAndEmptyArrays: true } },
            {
                $lookup: {
                    from: "restaurants",
                    localField: "restaurant",
                    foreignField: "_id",
                    as: "restaurant"
                }
            },
            { $unwind: { path: "$restaurant", preserveNullAndEmptyArrays: true } },
            {
                $addFields: {
                    food_image: "$foodImage",
                    image: "$foodImage",
                    "restaurant.restaurant_name": "$restaurant.restaurantName",
                    "restaurant.image": "$restaurant.logo"
                }
            },
            {
                $project: {
                    "restaurant.password": 0,
                    "category.isActive": 0
                }
            }
        ]);

        console.log('📊 Popular Items (First 3):');
        console.log('='.repeat(60));

        popularItems.forEach((item, index) => {
            console.log(`\n${index + 1}. ${item.name}`);
            console.log(`   foodImage field: ${item.foodImage || 'MISSING'}`);
            console.log(`   food_image field: ${item.food_image || 'MISSING'}`);
            console.log(`   image field: ${item.image || 'MISSING'}`);
            console.log(`   Restaurant: ${item.restaurant?.restaurantName || 'N/A'}`);
            console.log(`   restaurant.restaurant_name: ${item.restaurant?.restaurant_name || 'MISSING'}`);
            console.log(`   restaurant.logo: ${item.restaurant?.logo || 'MISSING'}`);
            console.log(`   restaurant.image: ${item.restaurant?.image || 'MISSING'}`);
        });

        console.log('\n' + '='.repeat(60));
        console.log('\n✅ Test complete');

        await mongoose.disconnect();
        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

testAggregation();
