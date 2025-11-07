# How to Add Food Items for Testing

## Quick Method: Use the Sample Foods Script

The easiest way to add food items is using the provided script:

### Step 1: Make sure you have:
- ✅ At least one **approved restaurant** in the database
- ✅ Categories created (run `npm run init-db` if needed)

### Step 2: Run the script

```bash
cd backend
npm run add-foods
```

This will add 12 sample food items across all categories:
- 🍔 **Fast Food**: Classic Burger, Chicken Wings, French Fries
- 🍕 **Pizza**: Margherita Pizza, Pepperoni Pizza
- 🥪 **Quick Bite**: Club Sandwich, Chicken Wrap
- 🍰 **Desserts**: Chocolate Cake, Ice Cream Sundae
- 🥤 **Beverages**: Fresh Orange Juice, Iced Coffee
- 🥗 **Healthy**: Caesar Salad, Grilled Chicken Salad

## Manual Method: Using Postman/API

### Step 1: Get Required IDs

1. **Get Restaurant ID:**
   ```bash
   GET http://localhost:5000/api/restaurants
   ```
   Copy the `_id` of an approved restaurant

2. **Get Category ID:**
   ```bash
   GET http://localhost:5000/api/categories
   ```
   Copy the `_id` of the category you want

3. **Get Auth Token:**
   ```bash
   POST http://localhost:5000/api/users/login
   Body: {
     "email": "restaurant@example.com",
     "password": "password"
   }
   ```
   Copy the `token` from response

### Step 2: Create Food Item

```bash
POST http://localhost:5000/api/foods
Headers:
  Authorization: Bearer <your-token>
  Content-Type: multipart/form-data

Body (form-data):
  name: "Burger Deluxe"
  description: "Delicious burger with special sauce"
  price: 25.99
  category: <category-id>
  restaurant: <restaurant-id>
  preparationTime: 15
  ingredients: ["Beef patty", "Lettuce", "Tomato", "Bun"]
  allergens: ["Gluten", "Dairy"]
  image: <upload-image-file>
```

### Step 3: Verify

```bash
GET http://localhost:5000/api/foods?restaurant=<restaurant-id>
```

## Using the Admin Panel

If you have the admin panel set up:
1. Login as admin
2. Navigate to restaurant management
3. Select a restaurant
4. Add food items through the UI

## Using MongoDB Directly

You can also add food items directly to MongoDB:

```javascript
// Connect to MongoDB
use grabgo

// Insert a food item
db.foods.insertOne({
  name: "Test Burger",
  description: "A test burger",
  price: 20.99,
  category: ObjectId("your-category-id"),
  restaurant: ObjectId("your-restaurant-id"),
  isAvailable: true,
  preparationTime: 15,
  ingredients: ["Beef", "Bun"],
  allergens: ["Gluten"],
  rating: 4.5,
  totalReviews: 0,
  createdAt: new Date(),
  updatedAt: new Date()
})
```

## Requirements for Food Items

- **Required fields:**
  - `name` (String)
  - `price` (Number, min: 0)
  - `category` (ObjectId - must exist in categories collection)
  - `restaurant` (ObjectId - must exist in restaurants collection)

- **Optional fields:**
  - `description` (String)
  - `image` (String - URL or file upload)
  - `preparationTime` (Number - in minutes)
  - `ingredients` (Array of Strings)
  - `allergens` (Array of Strings)
  - `isAvailable` (Boolean, default: true)
  - `rating` (Number, 0-5, default: 0)
  - `totalReviews` (Number, default: 0)

## Troubleshooting

### "No approved restaurant found"
- Approve at least one restaurant first
- Use admin panel or update restaurant status in MongoDB:
  ```javascript
  db.restaurants.updateOne(
    { email: "restaurant@example.com" },
    { $set: { status: "approved" } }
  )
  ```

### "Category not found"
- Run `npm run init-db` to create categories
- Or create categories via API:
  ```bash
  POST http://localhost:5000/api/categories
  Headers:
    Authorization: Bearer <admin-token>
    api_key: pAuLInepisT_les
  Body: {
    "name": "Category Name",
    "description": "Description",
    "emoji": "🍔"
  }
  ```

### "Restaurant not found"
- Make sure the restaurant exists and is approved
- Check the restaurant ID is correct

## Sample Food Items Included in Script

The script adds these items:

1. **Classic Burger** - $25.99 (Fast Food)
2. **Chicken Wings** - $18.99 (Fast Food)
3. **French Fries** - $8.99 (Fast Food)
4. **Margherita Pizza** - $32.99 (Pizza)
5. **Pepperoni Pizza** - $35.99 (Pizza)
6. **Club Sandwich** - $22.99 (Quick Bite)
7. **Chicken Wrap** - $19.99 (Quick Bite)
8. **Chocolate Cake** - $15.99 (Desserts)
9. **Ice Cream Sundae** - $12.99 (Desserts)
10. **Fresh Orange Juice** - $6.99 (Beverages)
11. **Iced Coffee** - $8.99 (Beverages)
12. **Caesar Salad** - $16.99 (Healthy)
13. **Grilled Chicken Salad** - $19.99 (Healthy)

All items include:
- Descriptions
- Preparation times
- Ingredients lists
- Allergen information
- Ratings and review counts

