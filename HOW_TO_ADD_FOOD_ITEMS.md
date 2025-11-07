# How to Add Food Items to the Database

## Method 1: Using the Sample Foods Script (Quickest for Testing)

### Steps:

1. **Make sure you have:**
   - ✅ At least one restaurant in the database (approved or pending)
   - ✅ Categories created (run `npm run init-db` if needed)

2. **Run the script:**
   ```bash
   cd backend
   npm run add-foods
   ```

3. **Verify in database:**
   ```bash
   # Check via API
   GET http://localhost:5000/api/foods
   ```

**Result:** 13 sample food items will be added to your database with images, ingredients, ratings, etc.

---

## Method 2: Using the API (Recommended for Production)

### Steps:

1. **Get Required IDs:**

   **a) Get Restaurant ID:**
   ```bash
   GET http://localhost:5000/api/restaurants
   ```
   Copy the `_id` of the restaurant you want to add food to.

   **b) Get Category ID:**
   ```bash
   GET http://localhost:5000/api/categories
   ```
   Copy the `_id` of the category (e.g., Fast Food, Pizza, etc.)

   **c) Get Auth Token:**
   ```bash
   POST http://localhost:5000/api/users/login
   Content-Type: application/json
   
   {
     "email": "restaurant@example.com",
     "password": "password"
   }
   ```
   Copy the `token` from the response.

2. **Create Food Item:**

   **Option A: With Image Upload (Multipart Form Data)**
   ```bash
   POST http://localhost:5000/api/foods
   Authorization: Bearer <your-token>
   Content-Type: multipart/form-data
   
   Fields:
   - name: "Burger Deluxe"
   - description: "Delicious burger with special sauce"
   - price: 25.99
   - category: <category-id>
   - restaurant: <restaurant-id>
   - ingredients: ["Beef patty", "Lettuce", "Tomato", "Bun"]
   - isAvailable: true
   - rating: 4.5
   - totalReviews: 0
   - food_image: <upload-image-file>
   ```

   **Option B: Without Image (JSON)**
   ```bash
   POST http://localhost:5000/api/foods
   Authorization: Bearer <your-token>
   Content-Type: application/json
   
   {
     "name": "Burger Deluxe",
     "description": "Delicious burger with special sauce",
     "price": 25.99,
     "category": "<category-id>",
     "restaurant": "<restaurant-id>",
     "ingredients": ["Beef patty", "Lettuce", "Tomato", "Bun"],
     "isAvailable": true,
     "rating": 4.5,
     "totalReviews": 0,
     "food_image": "https://example.com/image.jpg"
   }
   ```

3. **Verify:**
   ```bash
   GET http://localhost:5000/api/foods?restaurant=<restaurant-id>
   ```

---

## Method 3: Using Postman

### Steps:

1. **Setup:**
   - Create a new POST request
   - URL: `http://localhost:5000/api/foods`
   - Headers: Add `Authorization: Bearer <your-token>`

2. **For Image Upload:**
   - Select "Body" tab
   - Choose "form-data"
   - Add fields:
     - `name` (Text): "Burger Deluxe"
     - `description` (Text): "Description here"
     - `price` (Text): "25.99"
     - `category` (Text): "<category-id>"
     - `restaurant` (Text): "<restaurant-id>"
     - `ingredients` (Text): `["Beef", "Lettuce", "Tomato"]` (as JSON array string)
     - `isAvailable` (Text): "true"
     - `rating` (Text): "4.5"
     - `totalReviews` (Text): "0"
     - `food_image` (File): Select image file

3. **For JSON (without image):**
   - Select "Body" tab
   - Choose "raw"
   - Select "JSON" from dropdown
   - Paste JSON:
     ```json
     {
       "name": "Burger Deluxe",
       "description": "Delicious burger",
       "price": 25.99,
       "category": "<category-id>",
       "restaurant": "<restaurant-id>",
       "ingredients": ["Beef patty", "Lettuce", "Tomato"],
       "isAvailable": true,
       "rating": 4.5,
       "totalReviews": 0,
       "food_image": "https://example.com/image.jpg"
     }
     ```

4. **Send Request**

---

## Method 4: Direct MongoDB (For Quick Testing)

### Steps:

1. **Connect to MongoDB:**
   ```bash
   mongosh
   use grabgo
   ```

2. **Get IDs:**
   ```javascript
   // Get restaurant ID
   db.restaurants.findOne({}, {_id: 1, restaurant_name: 1})
   
   // Get category ID
   db.categories.findOne({name: "Fast Food"}, {_id: 1, name: 1})
   ```

3. **Insert Food Item:**
   ```javascript
   db.foods.insertOne({
     name: "Test Burger",
     description: "A test burger",
     price: 20.99,
     category: ObjectId("your-category-id"),
     restaurant: ObjectId("your-restaurant-id"),
     food_image: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500",
     ingredients: ["Beef", "Bun", "Lettuce"],
     isAvailable: true,
     rating: 4.5,
     totalReviews: 0,
     createdAt: new Date(),
     updatedAt: new Date()
   })
   ```

---

## Required Fields

### Must Have:
- ✅ **name** (String) - Food name
- ✅ **price** (Number) - Price (must be >= 0)
- ✅ **category** (ObjectId) - Must exist in categories collection
- ✅ **restaurant** (ObjectId) - Must exist in restaurants collection

### Optional:
- **description** (String)
- **food_image** (String) - URL or will be set when uploading file
- **ingredients** (Array of Strings)
- **isAvailable** (Boolean, default: true)
- **rating** (Number, 0-5, default: 0)
- **totalReviews** (Number, default: 0)

---

## Troubleshooting

### "Category not found"
- **Solution:** Make sure category exists. Run `npm run init-db` to create default categories.

### "Restaurant not found"
- **Solution:** Make sure restaurant exists. Register a restaurant first via `/api/restaurants/register`

### "Unauthorized" or 401 Error
- **Solution:** Make sure you're logged in and include the `Authorization: Bearer <token>` header.

### Food not showing in customer app
- **Solution:** 
  1. Check if restaurant is approved (`status: "approved"`)
  2. Check if `isAvailable: true`
  3. Verify the food item exists: `GET /api/foods?restaurant=<restaurant-id>`

### Image not uploading
- **Solution:**
  1. Make sure you're using `multipart/form-data` for file uploads
  2. Field name must be `food_image` (not `image`)
  3. Check file size limits in upload middleware
  4. Supported formats: JPEG, JPG, PNG, GIF, WEBP

---

## Quick Checklist

Before adding food items:
- [ ] Restaurant exists in database
- [ ] Categories exist (run `npm run init-db` if needed)
- [ ] You have auth token (if using API)
- [ ] Backend server is running
- [ ] MongoDB is connected

After adding:
- [ ] Verify via `GET /api/foods`
- [ ] Check restaurant is approved (for customer app visibility)
- [ ] Test in customer app

---

## Example: Complete Flow

```bash
# 1. Start backend
cd backend
npm run dev

# 2. Create categories (if not done)
npm run init-db

# 3. Get restaurant ID
curl http://localhost:5000/api/restaurants

# 4. Login to get token
curl -X POST http://localhost:5000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"restaurant@example.com","password":"password"}'

# 5. Add food item
curl -X POST http://localhost:5000/api/foods \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Burger Deluxe",
    "description": "Delicious burger",
    "price": 25.99,
    "category": "<category-id>",
    "restaurant": "<restaurant-id>",
    "ingredients": ["Beef", "Lettuce", "Tomato"],
    "isAvailable": true,
    "rating": 4.5,
    "totalReviews": 0
  }'

# 6. Verify
curl http://localhost:5000/api/foods?restaurant=<restaurant-id>
```

---

## Summary

**Easiest for Testing:** Use `npm run add-foods` script

**Best for Production:** Use API with proper authentication

**Quick Testing:** Use MongoDB directly

**For Development:** Use Postman with form-data for image uploads

