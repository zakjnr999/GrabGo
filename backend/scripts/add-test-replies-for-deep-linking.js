const mongoose = require('mongoose');
const User = require('../models/User');
const Status = require('../models/Status');
const Comment = require('../models/Comment');
const Notification = require('../models/Notification');
require('dotenv').config();

async function addTestRepliesForDeepLinking() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Find your user (replace with your actual email or phone)
        const yourEmail = 'zakjnr5@gmail.com'; // Change this to your email
        const yourUser = await User.findOne({ email: yourEmail });

        if (!yourUser) {
            console.log('❌ User not found. Please update the email in the script.');
            return;
        }

        console.log(`✅ Found your account: ${yourUser.name} (${yourUser.email})`);

        // Find other users to reply from
        const otherUsers = await User.find({
            _id: { $ne: yourUser._id }
        }).limit(5);

        if (otherUsers.length === 0) {
            console.log('❌ No other users found. Please create some test users first.');
            return;
        }

        console.log(`✅ Found ${otherUsers.length} other users to reply from`);

        // Find comments made by you
        const yourComments = await Comment.find({
            user: yourUser._id,
            parentComment: null // Only top-level comments
        }).limit(10);

        if (yourComments.length === 0) {
            console.log('❌ You have no comments yet. Please make some comments first.');
            return;
        }

        console.log(`✅ Found ${yourComments.length} of your comments`);

        const replyTexts = [
            "Great point! I totally agree with you 👍",
            "Thanks for sharing this!",
            "I had the same experience!",
            "This is so helpful, appreciate it!",
            "Couldn't have said it better myself",
            "Love this comment! 😊",
            "Exactly what I was thinking",
            "This made my day! Thanks!",
            "So true! 💯",
            "Really interesting perspective"
        ];

        let repliesCreated = 0;
        let notificationsCreated = 0;

        // Add 2-3 replies to each of your comments
        for (const comment of yourComments) {
            const numReplies = Math.floor(Math.random() * 2) + 2; // 2-3 replies

            for (let i = 0; i < numReplies; i++) {
                const randomUser = otherUsers[Math.floor(Math.random() * otherUsers.length)];
                const randomText = replyTexts[Math.floor(Math.random() * replyTexts.length)];

                // Create reply
                const reply = await Comment.create({
                    status: comment.status,
                    user: randomUser._id,
                    text: randomText,
                    parentComment: comment._id
                });

                await reply.populate('user', 'name email profileImage');

                // Update parent comment reply count
                await Comment.findByIdAndUpdate(comment._id, {
                    $inc: { replyCount: 1 }
                });

                repliesCreated++;

                // Get status and restaurant info for notification
                const status = await Status.findById(comment.status).select('restaurant');
                if (status) {
                    const Restaurant = require('../models/Restaurant');
                    const restaurant = await Restaurant.findById(status.restaurant).select('name');

                    // Create in-app notification
                    const notificationData = {
                        statusId: comment.status.toString(),
                        commentId: reply._id.toString(),  // Use reply ID, not parent comment ID
                        parentCommentId: comment._id.toString(),  // Add parent comment ID
                        isReply: true,  // Add isReply flag
                        restaurantId: status.restaurant.toString(),
                        restaurantName: restaurant?.name || 'Restaurant',
                        actorId: randomUser._id,
                        actorName: randomUser.name,
                        actorAvatar: randomUser.profileImage
                    };

                    console.log('📝 Creating notification with data:', JSON.stringify(notificationData, null, 2));

                    await Notification.create({
                        user: yourUser._id,
                        type: 'comment_reply',
                        title: `${randomUser.name} replied to your comment`,
                        message: `💬 ${randomText.length > 100 ? randomText.substring(0, 100) + '...' : randomText}`,
                        data: notificationData
                    });

                    notificationsCreated++;
                }

                console.log(`✅ Added reply from ${randomUser.name}: "${randomText}"`);
            }
        }

        // Also add some reactions to your comments
        const Reaction = require('../models/Reaction');
        const reactionTypes = ['like', 'love', 'haha', 'wow'];
        let reactionsCreated = 0;

        for (const comment of yourComments.slice(0, 5)) {
            const randomUser = otherUsers[Math.floor(Math.random() * otherUsers.length)];
            const randomType = reactionTypes[Math.floor(Math.random() * reactionTypes.length)];

            await Reaction.toggle(comment._id, randomUser._id, randomType);
            reactionsCreated++;

            // Create notification for reaction
            const status = await Status.findById(comment.status).select('restaurant');
            if (status) {
                const Restaurant = require('../models/Restaurant');
                const restaurant = await Restaurant.findById(status.restaurant).select('name');

                const reactionEmojis = { like: '👍', love: '❤️', haha: '😂', wow: '😮' };

                await Notification.create({
                    user: yourUser._id,
                    type: 'comment_reaction',
                    title: `${randomUser.name} reacted to your comment`,
                    message: `${reactionEmojis[randomType]} "${comment.text.length > 50 ? comment.text.substring(0, 50) + '...' : comment.text}"`,
                    data: {
                        statusId: comment.status.toString(),
                        commentId: comment._id.toString(),
                        restaurantId: status.restaurant.toString(),
                        restaurantName: restaurant?.name || 'Restaurant',
                        actorId: randomUser._id,
                        actorName: randomUser.name,
                        actorAvatar: randomUser.profileImage,
                        reactionType: randomType
                    }
                });

                notificationsCreated++;
                console.log(`✅ Added ${randomType} reaction from ${randomUser.name}`);
            }
        }

        console.log('\n🎉 Test data created successfully!');
        console.log(`📊 Summary:`);
        console.log(`   - Replies created: ${repliesCreated}`);
        console.log(`   - Reactions added: ${reactionsCreated}`);
        console.log(`   - Notifications created: ${notificationsCreated}`);
        console.log('\n💡 Now you can:');
        console.log('   1. Open the app and go to notifications');
        console.log('   2. Tap on a reply or reaction notification');
        console.log('   3. Watch it scroll directly to that comment!');

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await mongoose.connection.close();
        console.log('\n✅ Database connection closed');
    }
}

// Run the script
addTestRepliesForDeepLinking();
