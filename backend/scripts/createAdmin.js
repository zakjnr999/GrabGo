const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const prisma = require('../config/prisma');

// Admin user details - CHANGE THESE VALUES
const ADMIN_EMAIL = 'admin@grabgo.com';
const ADMIN_PASSWORD = 'Admin@123456'; // Change this to your desired password
const ADMIN_USERNAME = 'admin';

async function createAdminUser() {
    try {
        console.log('🚀 Connecting to Database with Prisma...');

        // Check if admin already exists
        const existingAdmin = await prisma.user.findUnique({
            where: { email: ADMIN_EMAIL }
        });

        if (existingAdmin) {
            console.log('⚠️  Admin user already exists with email:', ADMIN_EMAIL);
            console.log('📧 Email:', existingAdmin.email);
            console.log('👤 Username:', existingAdmin.username);
            console.log('🔑 Role:', existingAdmin.role);
            console.log('🛡️  isAdmin:', existingAdmin.isAdmin);

            console.log('\n💡 To update the password, use scripts/resetAdminPassword.js.');
            process.exit(0);
        }

        // Hash the password
        console.log('🔐 Hashing password...');
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(ADMIN_PASSWORD, salt);

        // Create admin user
        console.log('👤 Creating admin user...');
        const adminUser = await prisma.user.create({
            data: {
                username: ADMIN_USERNAME,
                email: ADMIN_EMAIL,
                password: hashedPassword,
                role: 'admin',
                isAdmin: true,
                isActive: true,
                isEmailVerified: true,
                isPhoneVerified: false,
            }
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
        await prisma.$disconnect();
        console.log('\n🔌 Disconnected from Database');
        process.exit(0);
    }
}

// Run the script
createAdminUser();
