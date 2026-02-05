const prisma = require('../config/prisma');

/**
 * Migration Script: Fix Order Items Missing foodId
 * 
 * This script backfills the foodId field for OrderItems that have:
 * - itemType = 'Food'
 * - foodId = null
 * 
 * It matches order items to food items based on the name field.
 */

async function fixOrderItemsFoodId() {
    console.log('🔧 Starting Order Items foodId Migration...\n');

    try {
        // Find all order items with missing foodId
        const brokenItems = await prisma.orderItem.findMany({
            where: {
                itemType: 'Food',
                foodId: null
            },
            include: {
                order: {
                    select: {
                        id: true,
                        orderNumber: true,
                        customerId: true
                    }
                }
            }
        });

        console.log(`📦 Found ${brokenItems.length} order items with missing foodId\n`);

        if (brokenItems.length === 0) {
            console.log('✅ No items to fix. All order items have valid foodId!');
            return;
        }

        let fixed = 0;
        let notFound = 0;
        let errors = 0;

        for (const item of brokenItems) {
            try {
                // Try to find matching food by exact name
                const matchingFood = await prisma.food.findFirst({
                    where: {
                        name: item.name
                    },
                    select: {
                        id: true,
                        name: true,
                        price: true
                    }
                });

                if (matchingFood) {
                    // Update the order item with the correct foodId
                    await prisma.orderItem.update({
                        where: { id: item.id },
                        data: { foodId: matchingFood.id }
                    });

                    console.log(`✅ Fixed: "${item.name}" → foodId: ${matchingFood.id}`);
                    fixed++;
                } else {
                    console.log(`⚠️  Not Found: "${item.name}" - No matching food item in database`);
                    notFound++;
                }
            } catch (error) {
                console.error(`❌ Error fixing item "${item.name}":`, error.message);
                errors++;
            }
        }

        console.log('\n📊 Migration Summary:');
        console.log(`   ✅ Fixed: ${fixed}`);
        console.log(`   ⚠️  Not Found: ${notFound}`);
        console.log(`   ❌ Errors: ${errors}`);
        console.log(`   📦 Total Processed: ${brokenItems.length}`);

        if (fixed > 0) {
            console.log('\n🎉 Migration completed successfully!');
            console.log('💡 The "Order Again" section should now work correctly.');
        }

    } catch (error) {
        console.error('❌ Migration failed:', error);
        throw error;
    } finally {
        await prisma.$disconnect();
    }
}

// Run the migration
fixOrderItemsFoodId()
    .then(() => {
        console.log('\n✅ Script finished');
        process.exit(0);
    })
    .catch((error) => {
        console.error('\n❌ Script failed:', error);
        process.exit(1);
    });
