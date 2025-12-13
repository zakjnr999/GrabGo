/**
 * Script to create dummy promotional banners for testing
 * 
 * Usage: node create_dummy_banners.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const PromotionalBanner = require('./models/PromotionalBanner');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
});

const db = mongoose.connection;
db.on('error', console.error.bind(console, 'MongoDB connection error:'));
db.once('open', async () => {
    console.log('✅ Connected to MongoDB');
    await createDummyBanners();
});

async function createDummyBanners() {
    try {
        console.log('\n📦 Creating dummy promotional banners...\n');

        // Clear existing banners (optional - comment out if you want to keep existing)
        // await PromotionalBanner.deleteMany({});
        // console.log('🗑️  Cleared existing banners\n');

        const now = new Date();
        const tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const nextWeek = new Date(now);
        nextWeek.setDate(nextWeek.getDate() + 7);
        const nextMonth = new Date(now);
        nextMonth.setMonth(nextMonth.getMonth() + 1);

        const banners = [
            {
                title: 'Slice & Save on\nPizza Hut',
                subtitle: 'Savour your favourite\npizza for just GHS43',
                imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400',
                discount: '-50%',
                backgroundColor: '#FFF4E6',
                targetUrl: '/restaurant/pizza-hut',
                startDate: now,
                endDate: nextMonth,
                isActive: true,
                priority: 3,
                targetAudience: 'all'
            },
            {
                title: 'Fresh Burgers\nat KFC',
                subtitle: 'Crispy chicken burgers\nstarting at GHS35',
                imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
                discount: '-40%',
                backgroundColor: '#FFEBEE',
                targetUrl: '/restaurant/kfc',
                startDate: now,
                endDate: nextMonth,
                isActive: true,
                priority: 2,
                targetAudience: 'all'
            },
            {
                title: 'Sushi Special\nat Zen Garden',
                subtitle: 'Premium sushi rolls\nfrom GHS55',
                imageUrl: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400',
                discount: '-30%',
                backgroundColor: '#E8F5E9',
                targetUrl: '/restaurant/zen-garden',
                startDate: now,
                endDate: nextWeek,
                isActive: true,
                priority: 1,
                targetAudience: 'all'
            },
            {
                title: 'Weekend Breakfast\nDeals',
                subtitle: 'Start your day right\nfrom GHS20',
                imageUrl: 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=400',
                discount: '-25%',
                backgroundColor: '#FFF9C4',
                targetUrl: '/category/breakfast',
                startDate: now,
                endDate: nextWeek,
                isActive: true,
                priority: 0,
                targetAudience: 'all'
            },
            {
                title: 'Inactive Banner\n(Future)',
                subtitle: 'This banner starts tomorrow',
                imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400',
                discount: '-20%',
                backgroundColor: '#E1F5FE',
                targetUrl: '/deals',
                startDate: tomorrow,
                endDate: nextMonth,
                isActive: true,
                priority: 5,
                targetAudience: 'all'
            }
        ];

        let created = 0;
        for (const bannerData of banners) {
            const banner = await PromotionalBanner.create(bannerData);
            created++;

            const isCurrentlyActive = banner.startDate <= now && banner.endDate >= now;
            console.log(`✅ Created banner: "${banner.title.replace('\n', ' ')}"`);
            console.log(`   - Discount: ${banner.discount}`);
            console.log(`   - Priority: ${banner.priority}`);
            console.log(`   - Active now: ${isCurrentlyActive ? 'Yes' : 'No (starts later)'}`);
            console.log(`   - Valid until: ${banner.endDate.toLocaleDateString()}\n`);
        }

        console.log(`\n🎉 Successfully created ${created} promotional banners!`);
        console.log(`\n📊 Summary:`);
        console.log(`   - Total banners: ${created}`);
        console.log(`   - Currently active: ${banners.filter(b => b.startDate <= now && b.endDate >= now).length}`);
        console.log(`   - Future banners: ${banners.filter(b => b.startDate > now).length}`);
        console.log(`\n✅ You can now test the promotional banners in the app!`);
        console.log(`\n🔗 Test API: GET http://localhost:5000/api/promotions/banners`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error creating dummy banners:', error);
        process.exit(1);
    }
}
