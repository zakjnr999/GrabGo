# GrabGo Deployment Guide

## Quick Deployment Steps

### 1. Commit and Push to GitHub

```bash
# Stage all changes
git add .

# Commit with a descriptive message
git commit -m "feat: Update categories to use emojis instead of images, improve admin login flow"

# Push to GitHub
git push origin main
```

### 2. Deploy to Render

#### Option A: Automatic Deployment (Recommended)
If you have Render connected to your GitHub repository:

1. **Render will automatically detect the push** and start deploying
2. **Monitor the deployment** in your Render dashboard
3. **Wait for deployment to complete** (usually 2-5 minutes)

#### Option B: Manual Deployment
If automatic deployment is not set up:

1. Go to your Render dashboard
2. Find your backend service
3. Click "Manual Deploy" → "Deploy latest commit"

### 3. Run Database Initialization on Render

After deployment, you need to run the init-db script on Render:

#### Method 1: Using Render Shell (Recommended)
1. Go to your Render dashboard
2. Click on your backend service
3. Click "Shell" tab
4. Run:
   ```bash
   npm run init-db
   ```

#### Method 2: Using Render's Environment Variables
Add a build command that runs init-db:
1. Go to your service settings
2. Under "Build Command", add:
   ```bash
   npm install && npm run init-db
   ```
   (Note: This runs on every deploy, so only use if you want to reinitialize)

#### Method 3: SSH into Render Instance
If you have SSH access:
```bash
ssh <your-render-instance>
cd /opt/render/project/src
npm run init-db
```

### 4. Verify Deployment

1. **Check API Health:**
   ```bash
   curl https://your-backend.onrender.com/api/categories
   ```

2. **Test Categories Endpoint:**
   - Should return categories with `emoji` field instead of `image`
   - Example response:
     ```json
     {
       "success": true,
       "data": [
         {
           "_id": "...",
           "name": "Fast Food",
           "emoji": "🍔",
           "description": "..."
         }
       ]
     }
     ```

3. **Test Admin Login:**
   - Use admin credentials: `admin@grabgo.com` / `admin123`
   - Should successfully login and navigate to dashboard

## Environment Variables on Render

Make sure these are set in your Render dashboard:

1. Go to your service → **Environment** tab
2. Verify these variables are set:
   ```
   NODE_ENV=production
   PORT=5000
   MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/grabgo
   JWT_SECRET=your_strong_secret_here
   API_KEY=pAuLInepisT_les
   ALLOWED_ORIGINS=https://yourdomain.com,http://localhost:5000
   ```

## Important Notes

### Database Migration
- **Existing categories** in your production database will still have the old `image` field
- **New categories** will use the `emoji` field
- To update existing categories, you can:
  1. Manually update them via MongoDB Atlas
  2. Or delete and recreate them via the API

### API Base URL
- Make sure your Flutter apps are pointing to the correct API URL
- Update `packages/grab_go_shared/lib/shared/utils/config.dart` if needed:
  ```dart
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://your-backend.onrender.com/api',
  );
  ```

### Build Commands for Render
In your Render service settings:
- **Build Command:** `npm install`
- **Start Command:** `npm start`

## Troubleshooting

### Deployment Fails
1. Check Render logs for errors
2. Verify all environment variables are set
3. Check MongoDB connection string
4. Ensure Node.js version is compatible (18+)

### Categories Not Showing Emojis
1. Run `npm run init-db` on Render
2. Check database directly in MongoDB Atlas
3. Verify API response includes `emoji` field

### Admin Login Not Working
1. Verify admin user exists in database
2. Run `npm run init-db` to create admin if missing
3. Check API base URL in Flutter config
4. Verify API key is correct

## Post-Deployment Checklist

- [ ] Code pushed to GitHub
- [ ] Render deployment successful
- [ ] Database initialization script run
- [ ] Environment variables verified
- [ ] API endpoints tested
- [ ] Admin login tested
- [ ] Categories displaying with emojis
- [ ] Flutter apps updated with correct API URL

