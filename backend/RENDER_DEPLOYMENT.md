# Complete Render Deployment Guide for GrabGo Backend

This is a detailed, step-by-step guide to deploy your GrabGo backend API to Render.

## Prerequisites

Before you start, make sure you have:
- ✅ A GitHub account
- ✅ Your code pushed to a GitHub repository
- ✅ A MongoDB database (MongoDB Atlas recommended)
- ✅ A Render account (free tier available)

---

## Step 1: Prepare Your Code for Deployment

### 1.1 Ensure All Files Are Committed

```bash
cd backend
git add .
git commit -m "Prepare for Render deployment"
git push origin main
```

### 1.2 Verify Your Repository Structure

Make sure your `backend` folder is in your GitHub repository. The structure should be:
```
your-repo/
  └── backend/
      ├── server.js
      ├── package.json
      ├── models/
      ├── routes/
      ├── middleware/
      └── ... (all other files)
```

**Important**: If your `backend` folder is in a subdirectory, Render needs to know the root directory.

---

## Step 2: Set Up MongoDB Atlas (Recommended)

### 2.1 Create MongoDB Atlas Account

1. Go to https://www.mongodb.com/cloud/atlas
2. Click **"Try Free"** or **"Sign Up"**
3. Create your account

### 2.2 Create a Cluster

1. After logging in, click **"Build a Database"**
2. Choose **"M0 FREE"** (Free tier)
3. Select your preferred cloud provider and region (choose closest to your Render region)
4. Click **"Create"**
5. Wait 3-5 minutes for cluster creation

### 2.3 Create Database User

1. In the **"Database Access"** section (left sidebar)
2. Click **"Add New Database User"**
3. Choose **"Password"** authentication
4. Enter:
   - **Username**: `grabgo-admin` (or your choice)
   - **Password**: Generate a strong password (save it!)
5. Set privileges to **"Atlas admin"** or **"Read and write to any database"**
6. Click **"Add User"**

### 2.4 Whitelist IP Address

1. Go to **"Network Access"** (left sidebar)
2. Click **"Add IP Address"**
3. Click **"Allow Access from Anywhere"** (for Render deployment)
   - Or add Render's IP ranges if you want more security
4. Click **"Confirm"**

### 2.5 Get Connection String

1. Go to **"Database"** (left sidebar)
2. Click **"Connect"** on your cluster
3. Choose **"Connect your application"**
4. Copy the connection string
   - It looks like: `mongodb+srv://username:password@cluster.mongodb.net/`
5. Replace `<password>` with your database user password
6. Add database name at the end: `mongodb+srv://username:password@cluster.mongodb.net/grabgo`
7. **Save this connection string** - you'll need it!

---

## Step 3: Create Render Account

### 3.1 Sign Up for Render

1. Go to https://render.com
2. Click **"Get Started for Free"**
3. Sign up with GitHub (recommended) or email
4. Verify your email if required

---

## Step 4: Deploy Backend Service

### 4.1 Create New Web Service

1. In Render dashboard, click **"New +"** button (top right)
2. Select **"Web Service"**

### 4.2 Connect Repository

1. If using GitHub, click **"Connect account"** (if not already connected)
2. Authorize Render to access your repositories
3. Select your repository from the list
4. Click **"Connect"**

### 4.3 Configure Service Settings

Fill in the following:

**Basic Settings:**
- **Name**: `grabgo-backend` (or your preferred name)
- **Region**: Choose closest to your users (e.g., `Oregon (US West)`)
- **Branch**: `main` (or your default branch)
- **Root Directory**: 
  - If backend is in root: leave empty
  - If backend is in subfolder: `backend`

**Build & Deploy:**
- **Runtime**: `Node`
- **Build Command**: `npm install`
- **Start Command**: `npm start`

**Environment:**
- **Environment**: `Node` (should auto-detect)

### 4.4 Add Environment Variables

Click **"Advanced"** → **"Add Environment Variable"** and add these one by one:

```
NODE_ENV = production
```

```
PORT = 5000
```

```
MONGODB_URI = mongodb+srv://username:password@cluster.mongodb.net/grabgo
```
*(Replace with your actual MongoDB Atlas connection string)*

```
JWT_SECRET = your_very_strong_random_secret_key_minimum_32_characters
```
*(Generate a strong random string - you can use: `openssl rand -base64 32`)*

```
JWT_EXPIRE = 7d
```

```
API_KEY = pAuLInepisT_les
```
*(Or generate a new one for production)*

```
ALLOWED_ORIGINS = https://yourdomain.com,https://www.yourdomain.com
```
*(For now, you can use `*` for testing, but restrict in production)*

**Optional Variables:**
```
MAX_FILE_SIZE = 5242880
UPLOAD_PATH = ./uploads
```

### 4.5 Create Service

1. Review all settings
2. Click **"Create Web Service"**
3. Render will start building and deploying your service

---

## Step 5: Monitor Deployment

### 5.1 Watch Build Logs

1. You'll see the build process in real-time
2. Wait for build to complete (usually 2-5 minutes)
3. Look for: `✅ Build successful`

### 5.2 Check Deployment Status

1. After build, deployment starts automatically
2. Look for: `✅ Your service is live at https://your-service.onrender.com`
3. Note your service URL (e.g., `https://grabgo-backend.onrender.com`)

### 5.3 Common Build Issues

**Issue: "Module not found"**
- **Solution**: Make sure `package.json` is in the root directory (or root directory is set correctly)

**Issue: "Build command failed"**
- **Solution**: Check that all dependencies are in `package.json`

**Issue: "Start command failed"**
- **Solution**: Verify `npm start` works locally, check `server.js` exists

---

## Step 6: Test Your Deployment

### 6.1 Health Check

Open your browser and visit:
```
https://your-service.onrender.com/api/health
```

You should see:
```json
{
  "status": "ok",
  "message": "GrabGo API is running"
}
```

### 6.2 Test API Endpoints

**Test Registration:**
```bash
curl -X POST https://your-service.onrender.com/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "test123"
  }'
```

**Test Login:**
```bash
curl -X POST https://your-service.onrender.com/api/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "test123"
  }'
```

### 6.3 Check Logs

1. In Render dashboard, go to **"Logs"** tab
2. Check for any errors
3. Look for: `✅ Connected to MongoDB`
4. Look for: `🚀 Server running on port 5000`

---

## Step 7: Initialize Database (Optional)

### 7.1 Run Database Initialization

You can initialize your database by:

**Option 1: SSH into Render (if available)**
```bash
# Not available on free tier
```

**Option 2: Create a temporary endpoint**

Add this to your `server.js` temporarily:
```javascript
// Temporary endpoint for database initialization
app.post('/api/init-db', async (req, res) => {
  // Run init-db script logic here
  // Remove after first run!
});
```

**Option 3: Use MongoDB Compass**
- Connect to your MongoDB Atlas cluster
- Manually create collections and default data

**Option 4: Use a script locally**
- Connect to your MongoDB Atlas from your local machine
- Run: `npm run init-db` (after setting MONGODB_URI)

---

## Step 8: Configure Custom Domain (Optional)

### 8.1 Add Custom Domain

1. In Render dashboard, go to your service
2. Click **"Settings"** → **"Custom Domains"**
3. Click **"Add Custom Domain"**
4. Enter your domain (e.g., `api.yourdomain.com`)
5. Follow DNS configuration instructions
6. Wait for DNS propagation (can take up to 48 hours)

### 8.2 Update CORS

After adding custom domain, update `ALLOWED_ORIGINS`:
```
ALLOWED_ORIGINS = https://yourdomain.com,https://www.yourdomain.com
```

---

## Step 9: Update Flutter App

### 9.1 Update API Base URL

In your Flutter app, update the API URL:

**File**: `packages/grab_go_shared/lib/shared/utils/config.dart`

```dart
static const String apiBaseUrl = 'https://your-service.onrender.com/api';
```

Or for production:
```dart
static const String apiBaseUrl = 'https://api.yourdomain.com/api';
```

### 9.2 Test Connection

1. Run your Flutter app
2. Test login/registration
3. Verify API calls work

---

## Step 10: Security Checklist

Before going to production:

- [ ] Changed `JWT_SECRET` to a strong random value
- [ ] Changed `API_KEY` from default
- [ ] Set `ALLOWED_ORIGINS` to specific domains (not `*`)
- [ ] MongoDB Atlas IP whitelist configured
- [ ] Database user has strong password
- [ ] Removed any test/debug endpoints
- [ ] Environment variables are set (not hardcoded)
- [ ] HTTPS is enabled (Render does this automatically)

---

## Troubleshooting

### Service Won't Start

**Check logs for:**
- MongoDB connection errors → Verify `MONGODB_URI`
- Port errors → Verify `PORT` is set
- Module errors → Check `package.json` dependencies

### Database Connection Failed

**Solutions:**
1. Verify MongoDB Atlas IP whitelist includes Render IPs
2. Check connection string format
3. Verify database user credentials
4. Test connection string locally

### 502 Bad Gateway

**Possible causes:**
- Service crashed → Check logs
- Build failed → Check build logs
- Environment variables missing → Verify all required vars are set

### Slow Response Times

**Free tier limitations:**
- Services spin down after 15 minutes of inactivity
- First request after spin-down takes ~30 seconds
- Consider upgrading to paid plan for always-on service

### File Uploads Not Working

**Issue**: Uploads directory not persistent on free tier

**Solution**: 
- Use cloud storage (AWS S3, Cloudinary) for production
- Or upgrade to paid plan with persistent disk

---

## Render Free Tier Limitations

⚠️ **Important Notes:**

1. **Service Spins Down**: After 15 minutes of inactivity, service sleeps
2. **Cold Start**: First request after sleep takes ~30 seconds
3. **No Persistent Disk**: File uploads in `uploads/` folder will be lost on restart
4. **Limited Resources**: 512MB RAM, shared CPU

**For Production**: Consider upgrading to paid plan ($7/month) for:
- Always-on service (no spin-down)
- Persistent disk storage
- Better performance
- More resources

---

## Useful Render Features

### Auto-Deploy

- Automatically deploys on every push to main branch
- Can disable in settings if needed

### Manual Deploy

- Go to **"Manual Deploy"** tab
- Deploy specific branch or commit

### Environment Variables

- Can be updated without redeploying
- Changes take effect on next deploy

### Logs

- Real-time logs available
- Can download logs
- Search and filter logs

### Metrics

- Monitor CPU, memory usage
- View request metrics
- Track performance

---

## Next Steps After Deployment

1. ✅ Test all API endpoints
2. ✅ Update Flutter app with new API URL
3. ✅ Monitor logs for errors
4. ✅ Set up error tracking (optional: Sentry)
5. ✅ Configure backups for MongoDB
6. ✅ Set up monitoring alerts
7. ✅ Document API endpoints for team

---

## Support

If you encounter issues:

1. **Check Render Logs**: Most issues show in logs
2. **Check MongoDB Atlas**: Verify connection
3. **Test Locally**: Ensure code works locally first
4. **Render Docs**: https://render.com/docs
5. **Render Community**: https://community.render.com

---

## Quick Reference

**Your Service URL:**
```
https://your-service.onrender.com
```

**API Base URL:**
```
https://your-service.onrender.com/api
```

**Health Check:**
```
https://your-service.onrender.com/api/health
```

**Environment Variables Needed:**
- `NODE_ENV=production`
- `PORT=5000`
- `MONGODB_URI=your_connection_string`
- `JWT_SECRET=your_secret`
- `JWT_EXPIRE=7d`
- `API_KEY=your_api_key`
- `ALLOWED_ORIGINS=your_domains`

---

**🎉 Congratulations! Your backend is now deployed on Render!**

