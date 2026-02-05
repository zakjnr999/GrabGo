# 🚀 Deploy ML Service to Render (Using Existing Databases)

## ✅ Your Setup

You already have:
- ✅ PostgreSQL (Supabase)
- ✅ MongoDB (already configured)
- ✅ Redis (already configured)

**You only need to deploy the ML Web Service to Render!**

---

## 📋 Super Simple Deployment (5 Steps)

### Step 1: Generate Security Keys (1 minute)

```bash
# Generate SECRET_KEY
openssl rand -hex 32

# Generate API_KEY
openssl rand -hex 32

# Save both keys - you'll need them in Step 4
```

---

### Step 2: Push Code to GitHub (2 minutes)

```bash
cd /home/zakjnr/Documents/Project/GrabGo

# Add ML service files
git add ml-service/

# Commit
git commit -m "Add ML service for Render deployment"

# Push to GitHub
git push origin main
```

---

### Step 3: Create Web Service on Render (3 minutes)

1. Go to https://dashboard.render.com
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repository
4. Configure:

**Basic Settings:**
- **Name**: `grabgo-ml-service`
- **Region**: **Oregon** (or same as your backend)
- **Branch**: `main`
- **Root Directory**: `ml-service`
- **Runtime**: **Python 3**
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 2`
- **Instance Type**: **Free** (or Starter for production)

---

### Step 4: Add Environment Variables (5 minutes)

Click **"Advanced"** → **"Add Environment Variable"**

Add these environment variables:

#### **Required - Security Keys:**
```bash
SECRET_KEY=<paste-your-generated-secret-key-from-step-1>
API_KEY=<paste-your-generated-api-key-from-step-1>
```

#### **Required - Database Connections:**
```bash
# Supabase PostgreSQL
DATABASE_URL=<your-supabase-postgres-connection-string>
POSTGRES_HOST=<your-supabase-host>
POSTGRES_PORT=5432
POSTGRES_DB=<your-database-name>
POSTGRES_USER=<your-supabase-user>
POSTGRES_PASSWORD=<your-supabase-password>

# MongoDB
MONGODB_URL=<your-mongodb-connection-string>
MONGODB_DB=grabgo

# Redis
REDIS_URL=<your-redis-connection-string>
REDIS_HOST=<your-redis-host>
REDIS_PORT=<your-redis-port>
```

**Where to find these:**
- **Supabase**: Project Settings → Database → Connection String
- **MongoDB**: Your MongoDB dashboard → Connect → Connection String
- **Redis**: Your Redis provider dashboard

#### **Optional - Configuration:**
```bash
ENV=production
DEBUG=False
WORKERS=2
LOG_LEVEL=INFO
LOG_FORMAT=json
ENABLE_METRICS=True
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60
```

#### **Optional - Backend Integration:**
```bash
BACKEND_URL=<your-render-backend-url>
BACKEND_API_KEY=<if-needed>
```

#### **Optional - CORS:**
```bash
CORS_ORIGINS=https://your-frontend.com,https://admin.grabgo.com
```

---

### Step 5: Deploy! (5-10 minutes)

1. Click **"Create Web Service"**
2. Render will:
   - Clone your repository
   - Install dependencies
   - Start the service
3. Monitor the deployment logs
4. Once complete, you'll get a URL like:
   ```
   https://grabgo-ml-service.onrender.com
   ```

---

## ✅ Verify Deployment

### Test Health Endpoint:
```bash
curl https://grabgo-ml-service.onrender.com/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-02-05T02:55:00.000000",
  "components": {
    "postgres": "healthy",
    "mongodb": "healthy",
    "redis": "healthy"
  }
}
```

### View API Documentation:
Open in browser: https://grabgo-ml-service.onrender.com/docs

---

## 🔗 Update Your Backend

In your backend's Render environment variables, add:

```bash
ML_SERVICE_URL=https://grabgo-ml-service.onrender.com
ML_API_KEY=<same-api-key-as-ml-service>
```

Then redeploy your backend (or it will auto-deploy).

---

## 🎯 Integration Example

In your Node.js backend:

```javascript
const axios = require('axios');

const mlClient = axios.create({
  baseURL: process.env.ML_SERVICE_URL,
  headers: {
    'X-API-Key': process.env.ML_API_KEY,
    'Content-Type': 'application/json'
  }
});

// Get food recommendations
async function getRecommendations(userId) {
  try {
    const response = await mlClient.post('/api/v1/recommendations/food', {
      user_id: userId,
      limit: 10
    });
    return response.data;
  } catch (error) {
    console.error('ML recommendation failed:', error.message);
    return { success: false, data: [] };
  }
}

// Predict delivery time
async function predictDeliveryTime(orderData) {
  try {
    const response = await mlClient.post('/api/v1/predictions/delivery-time', {
      restaurant_location: {
        latitude: orderData.restaurantLat,
        longitude: orderData.restaurantLon
      },
      delivery_location: {
        latitude: orderData.deliveryLat,
        longitude: orderData.deliveryLon
      },
      preparation_time: orderData.prepTime || 15
    });
    return response.data;
  } catch (error) {
    console.error('ML ETA prediction failed:', error.message);
    return { success: false, estimated_minutes: 30 };
  }
}
```

---

## 📊 What You're Deploying

Your ML service includes:
- 🎯 **Smart Recommendations** (food, restaurants, similar items)
- ⏱️ **Delivery Time Prediction** (ML-based ETA)
- 📈 **Demand Forecasting** (capacity planning)
- 🔄 **Churn Prediction** (customer retention)
- 🔒 **Fraud Detection** (order security)
- 💬 **Sentiment Analysis** (review analysis)

---

## 💰 Cost

Since you're using existing databases:
- **Free Tier**: $0 (750 hours/month)
- **Starter Tier**: $7/month (no cold starts, better performance)

**Recommendation for production: Upgrade to Starter ($7/month)**

---

## 🐛 Troubleshooting

### Build Failed
- Check logs in Render dashboard
- Verify `requirements.txt` is correct
- Check Python version in `runtime.txt`

### Service Won't Start
- Verify all environment variables are set
- Check database connection strings are correct
- View service logs in Render dashboard

### Database Connection Errors
**Common Issues:**
1. **Supabase**: Make sure connection pooling is enabled
   - Use connection string with `?pgbouncer=true`
2. **MongoDB**: Whitelist Render's IP addresses
   - Or use `0.0.0.0/0` to allow all
3. **Redis**: Check if authentication is required
   - Include password in connection string if needed

### Health Check Fails
- Check database URLs are accessible from Render
- Verify credentials are correct
- Check firewall/security group settings

---

## ⚡ Performance Tips

1. **Use Connection Pooling** (already configured in the code)
2. **Enable Redis Caching** (already configured)
3. **Same Region**: Deploy Render service in same region as databases
4. **Upgrade Plan**: Use Starter tier for production (no cold starts)

---

## 🎉 You're Done!

Your deployment is complete when:
- ✅ Service is running on Render
- ✅ Health check returns "healthy"
- ✅ All database connections work
- ✅ Backend can call ML service
- ✅ API endpoints respond correctly

**Total Time: ~15-20 minutes**

---

## 📞 Need Help?

- **Render Logs**: https://dashboard.render.com → Your Service → Logs
- **API Docs**: https://grabgo-ml-service.onrender.com/docs
- **Health Check**: https://grabgo-ml-service.onrender.com/health

---

## 🚀 Next Steps After Deployment

1. Test all API endpoints via `/docs`
2. Integrate with your backend (see `INTEGRATION.js`)
3. Monitor performance in Render dashboard
4. Set up alerts for errors
5. Scale as needed

**Your ML service is production-ready!** 🎉
