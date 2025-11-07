# Quick Start Guide

Get your GrabGo backend API running in 5 minutes!

## Prerequisites

- Node.js 18+ installed
- MongoDB running (local or Atlas)

## Step 1: Install Dependencies

```bash
cd backend
npm install
```

## Step 2: Configure Environment

Create a `.env` file in the backend directory:

```bash
# Copy the example (if .env.example exists)
cp .env.example .env
```

Or create `.env` manually with:

```env
PORT=5000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/grabgo
JWT_SECRET=your_super_secret_jwt_key_change_this
JWT_EXPIRE=7d
API_KEY=pAuLInepisT_les
```

## Step 3: Create Uploads Directory

```bash
mkdir uploads
```

## Step 4: Start MongoDB

**Local MongoDB:**
```bash
# Make sure MongoDB is running
mongod
```

**Or use MongoDB Atlas:**
- Sign up at https://www.mongodb.com/cloud/atlas
- Create a free cluster
- Get your connection string
- Update `MONGODB_URI` in `.env`

## Step 5: Initialize Database (Optional)

Create default categories and admin user:

```bash
npm run init-db
```

Default admin credentials:
- Email: `admin@grabgo.com`
- Password: `admin123`

**⚠️ Change the password after first login!**

## Step 6: Start the Server

**Development mode (with auto-reload):**
```bash
npm run dev
```

**Production mode:**
```bash
npm start
```

## Step 7: Test the API

Open your browser or use curl:

```bash
# Health check
curl http://localhost:5000/api/health

# Should return:
# {"status":"ok","message":"GrabGo API is running"}
```

## Test Registration

```bash
curl -X POST http://localhost:5000/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }'
```

## Test Login

```bash
curl -X POST http://localhost:5000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

## API Base URL

Your API is now available at:
```
http://localhost:5000/api
```

Update your Flutter app's `AppConfig.apiBaseUrl` to point to this URL.

## Common Issues

### Port Already in Use
```bash
# Change PORT in .env to a different port (e.g., 5001)
PORT=5001
```

### MongoDB Connection Failed
- Check if MongoDB is running
- Verify connection string in `.env`
- For Atlas: Check IP whitelist and credentials

### Module Not Found
```bash
# Reinstall dependencies
rm -rf node_modules
npm install
```

## Next Steps

1. ✅ API is running
2. 📱 Update Flutter app with API URL
3. 🔐 Change default passwords
4. 🚀 Deploy to production (see DEPLOYMENT.md)

## Need Help?

- Check the main [README.md](README.md)
- Review [DEPLOYMENT.md](DEPLOYMENT.md) for production setup
- Check server logs for error messages

Happy coding! 🎉

