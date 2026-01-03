require('dotenv').config();
const mongoose = require('mongoose');

async function cleanup() {
    await mongoose.connect(process.env.MONGODB_URI);

    await mongoose.connection.db.collection('users').updateOne(
        { email: 'zakjnr5@gmail.com' },
        { $unset: { 'notificationSettings.promotions': '' } }
    );

    console.log('✅ Removed old promotions field');
    process.exit(0);
}

cleanup();
