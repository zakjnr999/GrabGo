/**
 * Schema Comparison Script
 * Compares MongoDB models with Prisma schema to find missing fields
 */

const fs = require('fs');
const path = require('path');

// MongoDB models to check
const modelsToCheck = [
    'User',
    'Restaurant',
    'Category',
    'Food',
    'GroceryStore',
    'GroceryCategory',
    'GroceryItem',
    'PharmacyStore',
    'PharmacyCategory',
    'PharmacyItem',
    'GrabMartStore',
    'GrabMartCategory',
    'GrabMartItem',
    'Order',
    'Cart',
    'Payment',
    'Rider',
    'RiderWallet',
    'Notification',
    'PromoCode',
    'PromotionalBanner'
];

console.log('📋 Checking MongoDB models for field completeness...\n');

const modelsDir = path.join(__dirname, '../models');
const schemaPath = path.join(__dirname, '../prisma/schema.prisma');

const prismaSchema = fs.readFileSync(schemaPath, 'utf-8');

modelsToCheck.forEach(modelName => {
    const modelPath = path.join(modelsDir, `${modelName}.js`);

    if (!fs.existsSync(modelPath)) {
        console.log(`⚠️  ${modelName}: Model file not found`);
        return;
    }

    const modelContent = fs.readFileSync(modelPath, 'utf-8');

    // Extract field names from Mongoose schema
    const fieldMatches = modelContent.matchAll(/(\w+):\s*{[\s\S]*?type:\s*(\w+)/g);
    const mongoFields = new Set();

    for (const match of fieldMatches) {
        mongoFields.add(match[1]);
    }

    // Check if model exists in Prisma schema
    const prismaModelRegex = new RegExp(`model ${modelName} {([\\s\\S]*?)}`, 'g');
    const prismaMatch = prismaModelRegex.exec(prismaSchema);

    if (!prismaMatch) {
        console.log(`❌ ${modelName}: Not found in Prisma schema`);
        return;
    }

    const prismaModelContent = prismaMatch[1];
    const prismaFieldMatches = prismaModelContent.matchAll(/^\s+(\w+)\s+/gm);
    const prismaFields = new Set();

    for (const match of prismaFieldMatches) {
        // Skip Prisma-specific fields
        if (!['createdAt', 'updatedAt', 'id'].includes(match[1])) {
            prismaFields.add(match[1]);
        }
    }

    // Find missing fields
    const missingFields = [];
    for (const field of mongoFields) {
        // Skip Mongoose-specific fields
        if (['_id', '__v', 'timestamps'].includes(field)) continue;

        // Check if field exists in Prisma (accounting for naming conventions)
        const camelCaseField = field;
        const snakeCaseField = field.replace(/([A-Z])/g, '_$1').toLowerCase();

        if (!prismaFields.has(camelCaseField) && !prismaFields.has(snakeCaseField)) {
            missingFields.push(field);
        }
    }

    if (missingFields.length > 0) {
        console.log(`⚠️  ${modelName}: Missing fields - ${missingFields.join(', ')}`);
    } else {
        console.log(`✅ ${modelName}: All fields present`);
    }
});

console.log('\n✨ Schema comparison complete!');
