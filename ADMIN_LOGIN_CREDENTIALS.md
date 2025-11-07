# 🔐 Admin Login Credentials

## Default Admin Credentials

The backend has a database initialization script that creates a default admin user.

### Default Credentials:
- **Email**: `admin@grabgo.com`
- **Password**: `admin123`

---

## 🚀 Setup Admin User

### Option 1: Run Database Initialization Script (Recommended)

This will create the admin user and default categories:

```bash
cd backend
npm run init-db
```

**Output:**
```
✅ Connected to MongoDB
✅ Admin user created: admin@grabgo.com
   Default password: admin123
   ⚠️  Please change the password after first login!
✅ Category created: Fast Food
✅ Category created: Pizza
...
✅ Database initialization completed!
```

### Option 2: Custom Admin Credentials

You can set custom admin credentials using environment variables:

1. **Add to `.env` file:**
   ```env
   ADMIN_EMAIL=your-admin@email.com
   ADMIN_PASSWORD=your-secure-password
   ```

2. **Run initialization:**
   ```bash
   npm run init-db
   ```

### Option 3: Create Admin User Manually (MongoDB)

If you prefer to create the admin user manually:

```javascript
// In MongoDB shell or Compass
db.users.insertOne({
  username: "admin",
  email: "admin@grabgo.com",
  password: "$2a$10$...", // Hash of your password using bcrypt
  isAdmin: true,
  role: "admin",
  isEmailVerified: true,
  isActive: true,
  permissions: {
    canManageUsers: true,
    canManageProducts: true,
    canManageOrders: true,
    canManageContent: true
  }
})
```

**To hash password:**
```javascript
const bcrypt = require('bcryptjs');
const hashedPassword = await bcrypt.hash('your-password', 10);
console.log(hashedPassword);
```

---

## 📝 Login Steps

1. **Start the backend server:**
   ```bash
   cd backend
   npm run dev
   ```

2. **Open the admin panel** (web browser)

3. **Enter credentials:**
   - Email: `admin@grabgo.com`
   - Password: `admin123`

4. **Click "LOGIN"**

5. **You should be redirected to the admin dashboard**

---

## ✅ Verify Admin User Exists

### Check via MongoDB:
```javascript
db.users.findOne({ email: "admin@grabgo.com" })
```

### Check via API (Postman):
```
GET http://localhost:5000/api/users/login
POST http://localhost:5000/api/users/login
Body: {
  "email": "admin@grabgo.com",
  "password": "admin123"
}
```

---

## 🔒 Security Notes

⚠️ **Important Security Recommendations:**

1. **Change Default Password**: After first login, change the default password
2. **Use Strong Password**: Use a strong, unique password
3. **Environment Variables**: For production, always use environment variables
4. **Don't Commit Credentials**: Never commit `.env` file with real credentials

---

## 🛠️ Troubleshooting

### Admin user doesn't exist?
- Run `npm run init-db` to create it
- Check MongoDB connection
- Verify `.env` file has correct `MONGODB_URI`

### Login fails?
- Verify email and password are correct
- Check if user exists in database
- Check if `isAdmin: true` and `isActive: true`
- Check backend server logs for errors

### "Access denied. Admin privileges required"?
- Verify user has `isAdmin: true` in database
- Check user `role` is set to `'admin'`
- Verify user `isActive: true`

---

## 📋 Admin User Requirements

For a user to be able to login as admin, they must have:

- ✅ `isAdmin: true`
- ✅ `role: 'admin'`
- ✅ `isActive: true`
- ✅ Valid email and password

---

## 🔄 Create Additional Admin Users

To create more admin users, you can:

1. **Via MongoDB:**
   ```javascript
   db.users.updateOne(
     { email: "user@example.com" },
     { $set: { isAdmin: true, role: "admin" } }
   )
   ```

2. **Via API (if you're already admin):**
   - First, you'd need to add an admin endpoint to create users
   - Or manually update via database

---

**Default credentials are for development only. Always change them in production!**

