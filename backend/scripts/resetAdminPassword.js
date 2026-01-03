/**
 * Quick script to reset admin password
 * This connects to your MongoDB and updates the admin user's password
 */

require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ADMIN_EMAIL = 'admin@grabgo.com';
const NEW_PASSWORD = 'Admin@123456';

async function resetAdminPassword() {
    try {
        console.log('🔌 Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Get the User model
        const User = mongoose.model('User', new mongoose.Schema({}, { strict: false }));

        // Find admin user
        const admin = await User.findOne({ email: ADMIN_EMAIL });

        if (!admin) {
            console.log('❌ Admin user not found with email:', ADMIN_EMAIL);
            console.log('💡 Run createAdmin.js first to create the admin user');
            process.exit(1);
        }

        console.log('👤 Found admin user:', admin.email);

        // Hash new password
        console.log('🔐 Hashing new password...');
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(NEW_PASSWORD, salt);

        // Update password directly
        await User.updateOne(
            { email: ADMIN_EMAIL },
            { $set: { password: hashedPassword } }
        );

        console.log('\n✅ Password reset successfully!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📧 Email:', ADMIN_EMAIL);
        console.log('🔑 New Password:', NEW_PASSWORD);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('\n💡 Try logging in now!');

    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await mongoose.disconnect();
        console.log('\n🔌 Disconnected from MongoDB');
        process.exit(0);
    }
}

resetAdminPassword();
