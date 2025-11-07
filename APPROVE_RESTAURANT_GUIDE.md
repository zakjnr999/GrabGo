# 🏪 How to Approve a Restaurant

Your restaurant has `status: "pending"` but the app only shows restaurants with `status: "approved"`.

---

## ✅ Solution: Approve the Restaurant

### Method 1: Using Postman/API Client

**Endpoint:**
```
PUT http://localhost:5000/api/restaurants/:restaurantId
```

**Headers:**
```
Authorization: Bearer <your_admin_jwt_token>
API_KEY: pAuLInepisT_les
Content-Type: application/json
```

**Body:**
```json
{
  "status": "approved"
}
```

**Example:**
```
PUT http://localhost:5000/api/restaurants/690de37b36aa959e581c5582
```

**Full Request in Postman:**
1. Method: **PUT**
2. URL: `http://localhost:5000/api/restaurants/690de37b36aa959e581c5582`
3. Headers:
   - `Authorization`: `Bearer <your_admin_token>`
   - `API_KEY`: `pAuLInepisT_les`
   - `Content-Type`: `application/json`
4. Body (raw JSON):
   ```json
   {
     "status": "approved"
   }
   ```

**Expected Response (200):**
```json
{
  "success": true,
  "message": "Restaurant status updated successfully",
  "data": {
    "_id": "690de37b36aa959e581c5582",
    "restaurant_name": "Adepa Resraurant",
    "status": "approved",
    ...
  }
}
```

---

### Method 2: Using MongoDB Directly

If you have MongoDB access:

```javascript
// In MongoDB shell or Compass
db.restaurants.updateOne(
  { _id: ObjectId("690de37b36aa959e581c5582") },
  { $set: { status: "approved" } }
)
```

---

### Method 3: Create Admin User First

If you don't have an admin user yet:

1. **Create Admin User via MongoDB:**
   ```javascript
   db.users.insertOne({
     username: "admin",
     email: "admin@grabgo.com",
     password: "$2a$10$...", // Hash of your password
     role: "admin",
     isAdmin: true,
     isActive: true
   })
   ```

2. **Or modify existing user:**
   ```javascript
   db.users.updateOne(
     { email: "your-email@example.com" },
     { $set: { isAdmin: true, role: "admin" } }
   )
   ```

3. **Login with admin credentials** to get admin JWT token

4. **Then use Method 1** to approve the restaurant

---

## 🔍 Verify Restaurant Status

**Check if restaurant is approved:**
```
GET http://localhost:5000/api/restaurants/690de37b36aa959e581c5582
```

**Check all restaurants:**
```
GET http://localhost:5000/api/restaurants
```

Only restaurants with `status: "approved"` will appear in the app!

---

## 📋 Restaurant Status Values

- `pending` - Waiting for admin approval (default after registration)
- `approved` - ✅ Visible in app
- `rejected` - Application rejected
- `suspended` - Temporarily suspended

---

## 🚀 After Approval

Once approved:
1. Restaurant will appear in the app
2. Users can view and order from it
3. Restaurant can login and manage their menu

---

## ⚠️ Quick Test (Development Only)

If you want to test immediately without approval, you can temporarily modify the backend:

**File:** `backend/routes/restaurants.js`  
**Line 14:** Change from:
```javascript
const restaurants = await Restaurant.find({ status: 'approved' })
```

To (for testing only):
```javascript
const restaurants = await Restaurant.find({ status: { $in: ['approved', 'pending'] } })
```

**⚠️ Remember to revert this change before production!**

