const prisma = require('../config/prisma');

/**
 * Script to create test orders with proper foodId for testing Order History
 * This creates delivered orders so they appear in the "Order Again" section
 */

async function createTestOrders() {
    console.log('🍔 Creating test orders for Order History...\n');

    try {
        // Get the user (you)
        const user = await prisma.user.findFirst({
            where: {
                email: 'zakjnr5@gmail.com'
            }
        });

        if (!user) {
            console.error('❌ User not found. Please update the email in the script.');
            return;
        }

        console.log(`✅ Found user: ${user.name} (${user.email})`);

        // Get some available food items
        const foods = await prisma.food.findMany({
            where: { isAvailable: true },
            include: { restaurant: true },
            take: 10
        });

        if (foods.length === 0) {
            console.error('❌ No food items found in database');
            return;
        }

        console.log(`✅ Found ${foods.length} available food items\n`);

        // Create 3 test orders with different statuses
        const ordersToCreate = [
            {
                status: 'delivered',
                items: foods.slice(0, 3),
                daysAgo: 2
            },
            {
                status: 'delivered',
                items: foods.slice(3, 6),
                daysAgo: 5
            },
            {
                status: 'on_the_way',
                items: foods.slice(6, 8),
                daysAgo: 0
            }
        ];

        let created = 0;

        for (const orderData of ordersToCreate) {
            const restaurant = orderData.items[0].restaurant;

            // Calculate totals
            let subtotal = 0;
            const orderItems = orderData.items.map(food => {
                const itemTotal = food.price * 1; // quantity = 1
                subtotal += itemTotal;
                return {
                    itemType: 'Food',
                    foodId: food.id, // ✅ This is the key - proper foodId!
                    name: food.name,
                    quantity: 1,
                    price: food.price,
                    image: food.image || null
                };
            });

            const deliveryFee = 5.0;
            const tax = subtotal * 0.05;
            const totalAmount = subtotal + deliveryFee + tax;

            // Calculate order date
            const orderDate = new Date();
            orderDate.setDate(orderDate.getDate() - orderData.daysAgo);

            const deliveredDate = orderData.status === 'delivered'
                ? new Date(orderDate.getTime() + 30 * 60000) // 30 mins after order
                : null;

            // Create the order (matching the format in orders.js)
            const order = await prisma.order.create({
                data: {
                    orderNumber: `TEST-${Date.now()}-${created}`,
                    orderType: 'food',
                    customerId: user.id,
                    restaurantId: restaurant.id,
                    subtotal,
                    deliveryFee,
                    tax,
                    totalAmount,
                    deliveryStreet: '123 Test Street',
                    deliveryCity: 'Accra',
                    deliveryState: 'Greater Accra',
                    deliveryLatitude: 5.6446,
                    deliveryLongitude: -0.21492,
                    paymentMethod: 'mobile_money',
                    paymentProvider: 'mtn_momo',
                    paymentStatus: 'completed',
                    status: orderData.status,
                    orderDate,
                    deliveredDate,
                    items: {
                        create: orderItems
                    }
                },
                include: {
                    items: true
                }
            });

            console.log(`✅ Created ${orderData.status} order #${order.orderNumber}`);
            console.log(`   📦 Items: ${order.items.length}`);
            console.log(`   💰 Total: GHS ${totalAmount.toFixed(2)}`);
            console.log(`   📅 Date: ${orderDate.toLocaleDateString()}\n`);

            created++;
        }

        console.log(`\n🎉 Successfully created ${created} test orders!`);
        console.log('💡 Refresh your app to see them in "Order Again" section.');

    } catch (error) {
        console.error('❌ Error creating test orders:', error);
        throw error;
    } finally {
        await prisma.$disconnect();
    }
}

// Run the script
createTestOrders()
    .then(() => {
        console.log('\n✅ Script finished');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Script failed:', error);
        process.exit(1);
    });
