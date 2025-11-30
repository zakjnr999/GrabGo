/**
 * Script to add sample status data for testing
 * Run with: npm run add-statuses
 */

require('dotenv').config();
const mongoose = require('mongoose');
const axios = require('axios');
const sharp = require('sharp');
const { encode } = require('blurhash');
const Status = require('../models/Status');
const Restaurant = require('../models/Restaurant');
const Food = require('../models/Food');

/**
 * Generate blur hash from image URL
 */
async function generateBlurHash(imageUrl) {
    try {
        // Fetch image (30 second timeout for slow connections)
        const response = await axios.get(imageUrl, { responseType: 'arraybuffer', timeout: 30000 });
        const buffer = Buffer.from(response.data);

        // Process with sharp
        const { data, info } = await sharp(buffer)
            .raw()
            .ensureAlpha()
            .resize(32, 32, { fit: 'inside' })
            .toBuffer({ resolveWithObject: true });

        // Encode blur hash
        const blurHash = encode(
            new Uint8ClampedArray(data),
            info.width,
            info.height,
            4, // componentX
            3  // componentY
        );

        return blurHash;
    } catch (error) {
        console.log(`  ⚠️  Could not generate blur hash: ${error.message}`);
        return null;
    }
}

// Sample media URLs (using placeholder images)
const sampleImages = [
    'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80', // Pizza
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80', // Burger
    'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800&q=80', // BBQ
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800&q=80', // Salad
    'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&q=80', // Food platter
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80', // Healthy bowl
    'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=800&q=80', // Pasta
    'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=800&q=80', // Breakfast
    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=800&q=80', // Colorful food
    'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=800&q=80', // Pancakes
    'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=800&q=80', // Cake
    'https://images.unsplash.com/photo-1482049016gy-2d1ec7ab7445?w=800&q=80', // Dessert
];

// Sample video thumbnails
const sampleVideoThumbnails = [
    'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800&q=80', // Cooking
    'https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=800&q=80', // Chef
    'https://images.unsplash.com/photo-1507048331197-7d4ac70811cf?w=800&q=80', // Kitchen
];

// Sample status data templates
const statusTemplates = {
    daily_special: [
        {
            title: "Chef's Special Ramen 🍜",
            description: "Our signature tonkotsu ramen with 12-hour slow-cooked broth, chashu pork, and soft-boiled egg. Available today only!",
        },
        {
            title: "Grilled Salmon Delight 🐟",
            description: "Fresh Atlantic salmon with herb butter, seasonal vegetables, and garlic mashed potatoes.",
        },
        {
            title: "BBQ Ribs Feast 🍖",
            description: "Fall-off-the-bone tender ribs glazed with our secret BBQ sauce. Served with coleslaw and fries.",
        },
        {
            title: "Mediterranean Platter 🥗",
            description: "A healthy mix of hummus, falafel, tabbouleh, and warm pita bread. Perfect for sharing!",
        },
    ],
    discount: [
        {
            title: "50% OFF All Pizzas! 🍕",
            description: "Use code PIZZA50 at checkout. Valid for dine-in and delivery. Limited time offer!",
            discountPercentage: 50,
            promoCode: "PIZZA50",
        },
        {
            title: "Buy 1 Get 1 Free Burgers 🍔",
            description: "Order any burger and get another one absolutely free! No code needed.",
            discountPercentage: 50,
            promoCode: "BOGO",
        },
        {
            title: "20% OFF Your First Order 🎉",
            description: "New customers get 20% off! Use code WELCOME20 on your first order.",
            discountPercentage: 20,
            promoCode: "WELCOME20",
        },
        {
            title: "Free Delivery Weekend 🚗",
            description: "Enjoy free delivery on all orders above GHS 50 this weekend!",
            discountPercentage: 100,
            promoCode: "FREEDEL",
        },
    ],
    new_item: [
        {
            title: "NEW: Truffle Mushroom Pasta 🍝",
            description: "Introducing our newest creation - creamy pasta with black truffle and wild mushrooms.",
        },
        {
            title: "Just Launched: Acai Bowl 🫐",
            description: "Start your day right with our refreshing acai bowl topped with fresh fruits and granola.",
        },
        {
            title: "NEW: Spicy Korean Fried Chicken 🍗",
            description: "Crispy fried chicken coated in our signature gochujang glaze. Available in mild, medium, or hot!",
        },
        {
            title: "Introducing: Matcha Lava Cake 🍰",
            description: "A decadent matcha chocolate cake with a molten center. Perfect for dessert lovers!",
        },
    ],
    video: [
        {
            title: "Behind the Scenes 🎬",
            description: "Watch our chefs prepare your favorite dishes with love and care.",
        },
        {
            title: "How We Make Our Pizza 🍕",
            description: "From dough to oven - see the magic happen in our kitchen!",
        },
        {
            title: "Meet Our Head Chef 👨‍🍳",
            description: "Get to know the culinary genius behind our amazing menu.",
        },
    ],
};

async function addSampleStatuses() {
    try {
        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');

        // Get all approved restaurants
        const restaurants = await Restaurant.find({ status: 'approved' }).limit(10);

        if (restaurants.length === 0) {
            console.log('⚠️  No approved restaurants found. Creating sample statuses with first available restaurant...');
            const anyRestaurant = await Restaurant.findOne();
            if (!anyRestaurant) {
                console.log('❌ No restaurants found in database. Please add restaurants first.');
                process.exit(1);
            }
            restaurants.push(anyRestaurant);
        }

        console.log(`📍 Found ${restaurants.length} restaurant(s)`);

        // Get some food items for linking
        const foods = await Food.find().limit(20);
        console.log(`🍔 Found ${foods.length} food item(s)`);

        // Clear existing statuses (optional - comment out if you want to keep existing)
        const deleted = await Status.deleteMany({});
        console.log(`🗑️  Cleared ${deleted.deletedCount} existing statuses`);

        const createdStatuses = [];
        const categories = ['daily_special', 'discount', 'new_item', 'video'];

        for (const restaurant of restaurants) {
            console.log(`\n📍 Creating statuses for: ${restaurant.restaurant_name}`);

            // Create 2-4 statuses per restaurant
            const numStatuses = Math.floor(Math.random() * 3) + 2;

            for (let i = 0; i < numStatuses; i++) {
                // Pick a random category
                const category = categories[Math.floor(Math.random() * categories.length)];
                const templates = statusTemplates[category];
                const template = templates[Math.floor(Math.random() * templates.length)];

                // Pick a random image
                const imageIndex = Math.floor(Math.random() * sampleImages.length);
                const mediaUrl = category === 'video'
                    ? sampleVideoThumbnails[Math.floor(Math.random() * sampleVideoThumbnails.length)]
                    : sampleImages[imageIndex];

                // Random expiration between 6-24 hours from now
                const hoursUntilExpiry = Math.floor(Math.random() * 18) + 6;
                const expiresAt = new Date();
                expiresAt.setHours(expiresAt.getHours() + hoursUntilExpiry);

                // Link a random food item for daily_special and new_item
                let linkedFood = null;
                if ((category === 'daily_special' || category === 'new_item') && foods.length > 0) {
                    linkedFood = foods[Math.floor(Math.random() * foods.length)]._id;
                }

                // Generate blur hash for the image
                console.log(`  🔄 Generating blur hash for: ${template.title}...`);
                const blurHash = await generateBlurHash(mediaUrl);

                // Create the status
                const statusData = {
                    restaurant: restaurant._id,
                    category,
                    title: template.title,
                    description: template.description,
                    mediaType: category === 'video' ? 'video' : 'image',
                    mediaUrl,
                    thumbnailUrl: category === 'video' ? mediaUrl : null,
                    blurHash,
                    discountPercentage: template.discountPercentage || null,
                    promoCode: template.promoCode || null,
                    linkedFood,
                    isRecommended: Math.random() > 0.6, // 40% chance of being recommended
                    isActive: true,
                    expiresAt,
                    viewCount: Math.floor(Math.random() * 500),
                    likeCount: Math.floor(Math.random() * 100),
                };

                const status = await Status.create(statusData);
                createdStatuses.push(status);
                console.log(`  ✅ Created: ${template.title} (${category}) ${blurHash ? '+ blur hash' : ''}`);
            }
        }

        console.log(`\n🎉 Successfully created ${createdStatuses.length} sample statuses!`);

        // Summary
        const summary = await Status.aggregate([
            { $match: { isActive: true } },
            { $group: { _id: '$category', count: { $sum: 1 } } }
        ]);

        console.log('\n📊 Status Summary:');
        summary.forEach(s => {
            console.log(`  - ${s._id}: ${s.count}`);
        });

        // Show stories grouping
        const stories = await Status.aggregate([
            { $match: { isActive: true, expiresAt: { $gt: new Date() } } },
            { $group: { _id: '$restaurant', count: { $sum: 1 } } },
            { $lookup: { from: 'restaurants', localField: '_id', foreignField: '_id', as: 'restaurant' } },
            { $unwind: '$restaurant' },
            { $project: { name: '$restaurant.restaurant_name', statusCount: '$count' } }
        ]);

        console.log('\n🏪 Stories by Restaurant:');
        stories.forEach(s => {
            console.log(`  - ${s.name}: ${s.statusCount} status(es)`);
        });

    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await mongoose.disconnect();
        console.log('\n👋 Disconnected from MongoDB');
    }
}

// Run the script
addSampleStatuses();
