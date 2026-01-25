const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const prisma = require('../config/prisma');

const ADMIN_EMAIL = 'admin@grabgo.com';
const NEW_PASSWORD = 'Admin@123456';

async function resetAdminPassword() {
    try {
        console.log('🚀 Connecting to Database with Prisma...');

        // Find admin user
        const admin = await prisma.user.findUnique({
            where: { email: ADMIN_EMAIL }
        });

        if (!admin) {
            console.log('❌ Admin user not found with email:', ADMIN_EMAIL);
            console.log('💡 Run scripts/createAdmin.js first to create the admin user');
            process.exit(1);
        }

        console.log('👤 Found admin user:', admin.email);

        // Hash new password
        console.log('🔐 Hashing new password...');
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(NEW_PASSWORD, salt);

        // Update password directly
        await prisma.user.update({
            where: { email: ADMIN_EMAIL },
            data: { password: hashedPassword }
        });

        console.log('\n✅ Password reset successfully!');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📧 Email:', ADMIN_EMAIL);
        console.log('🔑 New Password:', NEW_PASSWORD);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('\n💡 Try logging in now!');

    } catch (error) {
        console.error('❌ Error:', error.message);
    } finally {
        await prisma.$disconnect();
        console.log('\n🔌 Disconnected from Database');
        process.exit(0);
    }
}

resetAdminPassword();
