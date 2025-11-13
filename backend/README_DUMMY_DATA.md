# Dummy Data Setup Guide

## Overview
The `tmp_rovodev_create_dummy_food_data.js` script creates comprehensive dummy data for your GrabGo food delivery platform.

## What it creates:
- **8 Categories**: Fast Food, Pizza, Asian Cuisine, Local Dishes, Desserts, Beverages, Breakfast, Grilled
- **4 Restaurants**: Each with different specialties and locations in Accra
- **Food Items**: 8-12 items per restaurant (total ~40-48 items)

## How to run:
```bash
cd backend
npm run create-dummy-data
```

## What the script does:
1. **Preserves existing categories** and only adds missing ones
2. **Clears existing food and restaurant data** (but keeps categories)
2. **Creates 8 food categories** with emojis and descriptions
3. **Creates 4 restaurants** with complete details:
   - Adepa Restaurant (Local & International)
   - Tasty Bites (Fast Food)
   - Pizza Palace (Italian & Pizza)
   - Golden Spoon (Local & Continental)
4. **Assigns food items** to each restaurant with:
   - Varied pricing (±15% from base price)
   - Different ratings and review counts
   - High-quality food images from Unsplash
   - Realistic ingredients lists

## Key Features:
- **All restaurants are approved** and ready to show in customer app
- **Each restaurant gets 8-12 unique food items** from different categories
- **Price variations** make each restaurant unique
- **Realistic data** with proper descriptions and ingredients
- **Professional food images** for better visual appeal

## Database Collections After Running:
- Categories: 8 items
- Restaurants: 4 items (all approved)
- Foods: ~40-48 items distributed across restaurants

## Testing Your Endpoints:
After running this script, you can test:
- `/api/restaurants` - Should return 4 restaurants
- `/api/foods` - Should return 40+ food items
- `/api/categories` - Should return 8 categories
- Restaurant-specific food endpoints will have data for all restaurants

## Clean Up:
The script preserves existing categories but removes existing food and restaurant data before creating new dummy data to ensure consistency.