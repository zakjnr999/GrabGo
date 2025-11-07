# Quick Start Guide - Running the Backend Server

## Prerequisites
- Node.js 18+ installed
- MongoDB running (local or MongoDB Atlas)
- npm installed

## Step-by-Step Instructions

### 1. Navigate to Backend Directory
```bash
cd backend
```

### 2. Install Dependencies (if not already installed)
```bash
npm install
```

### 3. Set Up Environment Variables

Create a `.env` file in the `backend` directory with the following:

```env
PORT=5000
NODE_ENV=development
MONGODB_URI=mongodb://localhost:27017/grabgo
JWT_SECRET=your_super_secret_jwt_key_change_this_in_production
JWT_EXPIRE=7d
API_KEY=pAuLInepisT_les

# Optional: Cloudinary (for image uploads)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Optional: CORS
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
```

**For MongoDB Atlas (Cloud):**
```env
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/grabgo?retryWrites=true&w=majority
```

### 4. Initialize Database (First Time Only)
```bash
npm run init-db
```
This creates:
- Default admin user (email: `admin@grabgo.com`, password: `admin123`)
- Default categories with emojis

### 5. Run the Server

**Development Mode (with auto-reload):**
```bash
npm run dev
```

**Production Mode:**
```bash
npm start
```

### 6. Verify Server is Running

The server should start on `http://localhost:5000`

Test the health endpoint:
```bash
# Using curl (if available)
curl http://localhost:5000/api/health

# Or open in browser
http://localhost:5000/api/health
```

You should see:
```json
{
  "status": "ok",
  "message": "GrabGo API is running"
}
```

## Common Issues

### Port Already in Use
If port 5000 is already in use, change the PORT in `.env`:
```env
PORT=5001
```

### MongoDB Connection Error
- **Local MongoDB**: Make sure MongoDB is running
  ```bash
  # Windows: Check if MongoDB service is running
  # Or start MongoDB manually
  ```

- **MongoDB Atlas**: 
  - Check your connection string
  - Ensure your IP is whitelisted in Atlas
  - Verify username and password are correct

### Missing Dependencies
```bash
npm install
```

### Missing .env File
Create a `.env` file in the `backend` directory with the required variables (see Step 3).

## Testing the API

### Using Postman
1. Import the API collection (if available)
2. Set base URL: `http://localhost:5000/api`
3. Test endpoints

### Using curl
```bash
# Health check
curl http://localhost:5000/api/health

# Get restaurants
curl http://localhost:5000/api/restaurants

# Get categories
curl http://localhost:5000/api/categories
```

## Next Steps

1. **Add Sample Food Items** (optional):
   ```bash
   npm run add-foods
   ```

2. **Test Admin Login**:
   - Email: `admin@grabgo.com`
   - Password: `admin123`

3. **API Documentation**: See `README.md` for full API documentation

## Server Commands Summary

```bash
# Install dependencies
npm install

# Run in development mode (auto-reload)
npm run dev

# Run in production mode
npm start

# Initialize database (first time)
npm run init-db

# Add sample food items
npm run add-foods
```

## Server Status

When running successfully, you should see:
```
✅ Connected to MongoDB
🚀 Server running on port 5000
📡 API available at http://localhost:5000/api
```

