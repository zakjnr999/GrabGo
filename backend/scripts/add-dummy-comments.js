const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../.env') });

const Status = require('../models/Status');
const Comment = require('../models/Comment');
const User = require('../models/User');

// Sample comment texts for variety
const commentTexts = [
    "This looks absolutely delicious! 😋",
    "Can't wait to try this!",
    "Is this available for delivery?",
    "What are the ingredients?",
    "Looks amazing! How much is it?",
    "I tried this yesterday, it was fantastic!",
    "Do you have vegetarian options?",
    "This is my favorite dish here!",
    "The presentation is beautiful 🤩",
    "How spicy is this?",
    "Is this gluten-free?",
    "Wow, that discount is great!",
    "I'm definitely ordering this tonight",
    "Does it come with sides?",
    "This is a must-try!",
    "Perfect for lunch!",
    "Yummy! 😍",
    "Great value for money",
    "Is this a new menu item?",
    "Looks fresh and healthy",
    "My mouth is watering!",
    "Best food in town!",
    "How long does delivery take?",
    "Can I customize this order?",
    "This is exactly what I've been craving",
    "Do you offer combo deals?",
    "Portion size looks generous!",
    "Is this available all day?",
    "Love the colors in this dish",
    "Can't resist this offer!",
    "Tried it last week, highly recommend!",
    "Is there a vegan version?",
    "This would be perfect for dinner",
    "Amazing presentation!",
    "How many calories is this?",
    "Do you deliver to my area?",
    "This is making me hungry!",
    "What's the preparation time?",
    "Looks restaurant-quality!",
    "I need this in my life right now",
];

const replyTexts = [
    'Thanks for asking!',
    'Yes, it is!',
    'No, sorry.',
    'Great question!',
    'Let me check and get back to you.',
    'Absolutely!',
    'Not at the moment.',
    'Coming soon!',
    'Yes, we have that option.',
    'Please contact us for more details.',
];

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ MongoDB Connected');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

(async () => {
    try {
        await connectDB();

        // Get all active statuses
        const statuses = await Status.find({
            isActive: true,
            expiresAt: { $gt: new Date() }
        }).limit(50);

        if (statuses.length === 0) {
            console.log('⚠️  No active statuses found. Please create some statuses first.');
            process.exit(0);
        }

        console.log(`📊 Found ${statuses.length} active statuses`);

        // Get all users (excluding admins)
        const users = await User.find({ role: { $ne: 'admin' } }).limit(20);

        if (users.length === 0) {
            console.log('⚠️  No users found. Please create some users first.');
            process.exit(0);
        }

        console.log(`👥 Found ${users.length} users`);

        // Delete existing comments
        await Comment.deleteMany({});
        console.log('🗑️  Cleared existing comments\n');

        let commentsCreated = 0;

        // Add comments to each status
        for (const status of statuses) {
            const numComments = Math.floor(Math.random() * 11) + 5;
            const comments = [];
            const usedTexts = new Set();

            for (let i = 0; i < numComments; i++) {
                const randomUser = users[Math.floor(Math.random() * users.length)];

                let commentText;
                do {
                    commentText = commentTexts[Math.floor(Math.random() * commentTexts.length)];
                } while (usedTexts.has(commentText) && usedTexts.size < commentTexts.length);
                usedTexts.add(commentText);

                const hoursAgo = Math.random() * 24;
                const createdAt = new Date(Date.now() - hoursAgo * 60 * 60 * 1000);

                comments.push({
                    status: status._id,
                    user: randomUser._id,
                    text: commentText,
                    createdAt,
                    updatedAt: createdAt
                });
            }

            await Comment.insertMany(comments);
            commentsCreated += comments.length;
            console.log(`  ✓ Added ${comments.length} comments to status: ${status.title || status.category}`);
        }

        console.log(`\n✅ Created ${commentsCreated} comments across ${statuses.length} statuses`);

        // Create replies for some comments
        console.log('\n📝 Creating replies...');

        let repliesCreated = 0;
        const allComments = await Comment.find({ parentComment: null }).limit(30);

        for (const comment of allComments) {
            // 60% chance to have replies
            if (Math.random() > 0.4) {
                const numReplies = Math.floor(Math.random() * 3) + 1; // 1-3 replies

                for (let i = 0; i < numReplies; i++) {
                    const randomUser = users[Math.floor(Math.random() * users.length)];
                    const randomText = replyTexts[Math.floor(Math.random() * replyTexts.length)];

                    await Comment.create({
                        status: comment.status,
                        user: randomUser._id,
                        text: randomText,
                        parentComment: comment._id,
                        createdAt: new Date(Date.now() - Math.random() * 12 * 60 * 60 * 1000),
                    });

                    repliesCreated++;
                }
            }
        }

        console.log(`✅ Created ${repliesCreated} replies`);
        console.log('\n🎉 Dummy data creation complete!');
        console.log(`Total: ${commentsCreated} comments + ${repliesCreated} replies`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
})();
