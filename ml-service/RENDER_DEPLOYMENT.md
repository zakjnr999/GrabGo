# 🚀 Deploy GrabGo ML Service to Render

## Overview

This guide will help you deploy the ML service to Render, where your backend is already running.

---

## 📋 Prerequisites

- [ ] Render account (same one as your backend)
- [ ] GitHub repository with the ml-service code
- [ ] PostgreSQL database (can use Render's free tier)
- [ ] Redis instance (can use Render's free tier)

---

## 🎯 Deployment Options

### **Option 1: Deploy with Render's Managed Databases (Recommended)**
- Use Render PostgreSQL (free tier available)
- Use Render Redis (free tier available)
- Use external MongoDB (MongoDB Atlas free tier)

### **Option 2: Deploy Locally for Development**
- Run ML service on your local machine
- Connect to production databases
- Use ngrok for public URL (testing only)

---

## 🚀 Option 1: Full Render Deployment (Recommended)

### Step 1: Push Code to GitHub

```bash
cd /home/zakjnr/Documents/Project/GrabGo

# Initialize git if not already done
git add ml-service/
git commit -m "Add ML service for GrabGo"
git push origin main
```

### Step 2: Create PostgreSQL Database on Render

1. Go to https://dashboard.render.com
2. Click **"New +"** → **"PostgreSQL"**
3. Configure:
   - **Name**: `grabgo-ml-postgres`
   - **Database**: `grabgo_ml`
   - **User**: `grabgo_ml_user`
   - **Region**: Same as your backend (for lower latency)
   - **Plan**: Free (or paid for production)
4. Click **"Create Database"**
5. **Save the connection details** (Internal Database URL)

### Step 3: Create Redis Instance on Render

1. Click **"New +"** → **"Redis"**
2. Configure:
   - **Name**: `grabgo-ml-redis`
   - **Region**: Same as your backend
   - **Plan**: Free (or paid for production)
3. Click **"Create Redis"**
4. **Save the connection details** (Internal Redis URL)

### Step 4: Set Up MongoDB Atlas (Free)

1. Go to https://www.mongodb.com/cloud/atlas
2. Create a free cluster
3. Create a database user
4. Whitelist all IPs: `0.0.0.0/0` (for Render access)
5. Get connection string: `mongodb+srv://username:password@cluster.mongodb.net/grabgo`

### Step 5: Create Web Service on Render

1. Click **"New +"** → **"Web Service"**
2. Connect your GitHub repository
3. Configure:

   **Basic Settings:**
   - **Name**: `grabgo-ml-service`
   - **Region**: Same as backend
   - **Branch**: `main`
   - **Root Directory**: `ml-service`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

   **Instance Type:**
   - Free tier (for testing)
   - Starter or higher (for production)

4. Click **"Advanced"** and add environment variables:

### Step 6: Configure Environment Variables

Add these in Render's Environment Variables section:

```bash
# Environment
ENV=production
DEBUG=False

# API Configuration
API_V1_PREFIX=/api/v1
API_TITLE=GrabGo ML Service
API_VERSION=1.0.0

# Server
HOST=0.0.0.0
PORT=10000
WORKERS=2
RELOAD=False

# Security (IMPORTANT: Generate new keys!)
SECRET_KEY=<generate-with-openssl-rand-hex-32>
API_KEY=<generate-with-openssl-rand-hex-32>

# PostgreSQL (Use Render's Internal Database URL)
DATABASE_URL=<paste-render-postgres-internal-url>
POSTGRES_HOST=<from-render-postgres>
POSTGRES_PORT=5432
POSTGRES_DB=grabgo_ml
POSTGRES_USER=grabgo_ml_user
POSTGRES_PASSWORD=<from-render-postgres>

# MongoDB (Use MongoDB Atlas connection string)
MONGODB_URL=<paste-mongodb-atlas-connection-string>
MONGODB_DB=grabgo

# Redis (Use Render's Internal Redis URL)
REDIS_URL=<paste-render-redis-internal-url>
REDIS_HOST=<from-render-redis>
REDIS_PORT=6379

# ML Model Settings
MODEL_DIR=./ml_models
MODEL_UPDATE_INTERVAL=3600
RECOMMENDATION_CACHE_TTL=300
PREDICTION_CACHE_TTL=60

# Feature Flags
ENABLE_RECOMMENDATIONS=True
ENABLE_PREDICTIONS=True
ENABLE_FRAUD_DETECTION=True
ENABLE_SENTIMENT_ANALYSIS=True

# Logging
LOG_LEVEL=INFO
LOG_FORMAT=json

# Monitoring
ENABLE_METRICS=True

# Rate Limiting
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60

# CORS (Add your frontend domains)
CORS_ORIGINS=https://your-frontend.com,https://admin.grabgo.com

# Backend Integration
BACKEND_URL=<your-render-backend-url>
BACKEND_API_KEY=<same-as-backend>
```

### Step 7: Deploy

1. Click **"Create Web Service"**
2. Render will automatically:
   - Clone your repository
   - Install dependencies
   - Start the service
3. Monitor the deployment logs
4. Once deployed, you'll get a URL like: `https://grabgo-ml-service.onrender.com`

### Step 8: Verify Deployment

Test the health endpoint:
```bash
curl https://grabgo-ml-service.onrender.com/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2026-02-05T02:49:00.000000",
  "components": {
    "postgres": "healthy",
    "mongodb": "healthy",
    "redis": "healthy"
  }
}
```

### Step 9: Update Backend to Use ML Service

In your backend's Render environment variables, add:

```bash
ML_SERVICE_URL=https://grabgo-ml-service.onrender.com
ML_API_KEY=<same-api-key-as-ml-service>
```

---

## 🏠 Option 2: Run Locally (Development/Testing)

### Advantages:
- ✅ No deployment costs
- ✅ Faster development iteration
- ✅ Full control and debugging

### Disadvantages:
- ❌ Must keep computer running
- ❌ Not accessible when offline
- ❌ Requires port forwarding or ngrok for external access

### Setup:

1. **Configure .env for local development:**
```bash
cd /home/zakjnr/Documents/Project/GrabGo/ml-service

# Edit .env
nano .env
```

2. **Update .env with local settings:**
```bash
ENV=development
DEBUG=True
HOST=0.0.0.0
PORT=8000

# Use local databases
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=grabgo
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your-local-password

MONGODB_URL=mongodb://localhost:27017
MONGODB_DB=grabgo

REDIS_HOST=localhost
REDIS_PORT=6379

# Generate keys
SECRET_KEY=<generate-with-openssl-rand-hex-32>
API_KEY=<generate-with-openssl-rand-hex-32>
```

3. **Start the service:**
```bash
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

4. **Expose to internet (for testing with deployed backend):**

Using ngrok:
```bash
# Install ngrok
# Download from https://ngrok.com/download

# Start ngrok
ngrok http 8000
```

You'll get a URL like: `https://abc123.ngrok.io`

5. **Update backend environment:**
```bash
ML_SERVICE_URL=https://abc123.ngrok.io
ML_API_KEY=your-api-key
```

**Note:** ngrok URLs change on restart. For permanent local deployment, consider:
- Setting up a VPS
- Using Cloudflare Tunnel
- Port forwarding (if you have static IP)

---

## 📊 Comparison: Render vs Local

| Feature | Render Deployment | Local Development |
|---------|------------------|-------------------|
| **Cost** | Free tier available | Free |
| **Uptime** | 24/7 | Only when PC is on |
| **Performance** | Good (cloud servers) | Depends on your PC |
| **Scalability** | Easy (click to scale) | Limited |
| **Maintenance** | Managed by Render | You manage |
| **SSL/HTTPS** | Automatic | Requires setup |
| **Best For** | Production | Development/Testing |

---

## 🎯 Recommendation

### **For Production: Deploy to Render**
- More reliable
- Better performance
- Easier to scale
- Professional setup

### **For Development: Run Locally**
- Faster iteration
- Full debugging
- No deployment delays

### **Hybrid Approach (Best):**
1. **Development**: Run locally while building features
2. **Staging**: Deploy to Render free tier for testing
3. **Production**: Deploy to Render paid tier with auto-scaling

---

## 🔧 Render-Specific Configuration Files

I'll create these files for you:
- `render.yaml` - Infrastructure as Code
- `build.sh` - Custom build script
- `start.sh` - Custom start script

---

## 🚨 Important Notes

### Free Tier Limitations:
- Services spin down after 15 minutes of inactivity
- First request after spin-down takes 30-60 seconds
- 750 hours/month free (enough for 1 service)

### Recommendations:
1. **Use Render for production** (paid tier for better performance)
2. **Use local for development** (faster iteration)
3. **Keep services in same region** (lower latency)
4. **Use internal URLs** when services communicate (faster, free)

---

## 📝 Next Steps

Choose your deployment strategy:

### **If deploying to Render:**
1. Push code to GitHub
2. Create databases on Render
3. Create web service
4. Configure environment variables
5. Deploy and test

### **If running locally:**
1. Configure .env
2. Start databases locally
3. Start ML service
4. (Optional) Use ngrok for external access
5. Update backend URL

---

## 🆘 Need Help?

- **Render Docs**: https://render.com/docs
- **MongoDB Atlas**: https://www.mongodb.com/docs/atlas/
- **ngrok**: https://ngrok.com/docs

**Which option would you like to proceed with?**
