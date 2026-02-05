# 🚀 Render Deployment - Quick Checklist

## ✅ Pre-Deployment Checklist

### 1. Generate Security Keys
```bash
# Generate SECRET_KEY
openssl rand -hex 32

# Generate API_KEY  
openssl rand -hex 32

# Save these - you'll need them for Render environment variables
```

### 2. Set Up MongoDB Atlas (Free)
- [ ] Go to https://cloud.mongodb.com
- [ ] Create free cluster
- [ ] Create database user
- [ ] Whitelist IP: `0.0.0.0/0`
- [ ] Get connection string: `mongodb+srv://user:pass@cluster.mongodb.net/grabgo`

### 3. Push to GitHub
```bash
cd /home/zakjnr/Documents/Project/GrabGo

# Add all ml-service files
git add ml-service/

# Commit
git commit -m "Add ML service with Render deployment config"

# Push
git push origin main
```

---

## 🎯 Render Deployment Steps

### Step 1: Create PostgreSQL Database

1. Go to https://dashboard.render.com
2. Click **New +** → **PostgreSQL**
3. Settings:
   - Name: `grabgo-ml-postgres`
   - Database: `grabgo_ml`
   - User: `grabgo_ml_user`
   - Region: **Oregon** (or same as your backend)
   - Plan: **Free** (or Starter for production)
4. Click **Create Database**
5. **Copy the Internal Database URL** (starts with `postgresql://`)

### Step 2: Create Redis Instance

1. Click **New +** → **Redis**
2. Settings:
   - Name: `grabgo-ml-redis`
   - Region: **Oregon** (same as database)
   - Plan: **Free** (or Starter for production)
3. Click **Create Redis**
4. **Copy the Internal Redis URL** (starts with `redis://`)

### Step 3: Create Web Service

1. Click **New +** → **Web Service**
2. Connect your GitHub repository
3. Settings:
   - **Name**: `grabgo-ml-service`
   - **Region**: **Oregon** (same as databases)
   - **Branch**: `main`
   - **Root Directory**: `ml-service`
   - **Runtime**: **Python 3**
   - **Build Command**: `./build.sh`
   - **Start Command**: `./start.sh`
   - **Plan**: **Free** (or Starter for production)

### Step 4: Add Environment Variables

Click **Advanced** → **Add Environment Variable**

Add these one by one:

```bash
# Required - Add these manually
SECRET_KEY=<paste-your-generated-secret-key>
API_KEY=<paste-your-generated-api-key>
DATABASE_URL=<paste-postgres-internal-url>
REDIS_URL=<paste-redis-internal-url>
MONGODB_URL=<paste-mongodb-atlas-connection-string>

# Backend Integration
BACKEND_URL=<your-render-backend-url>
BACKEND_API_KEY=<same-as-backend-if-needed>

# Auto-filled (keep defaults)
ENV=production
DEBUG=False
PYTHON_VERSION=3.11.0
WORKERS=2
LOG_LEVEL=INFO
LOG_FORMAT=json
ENABLE_METRICS=True
RATE_LIMIT_ENABLED=True
RATE_LIMIT_PER_MINUTE=60

# Optional - CORS (add your frontend URLs)
CORS_ORIGINS=https://your-frontend.com
```

### Step 5: Deploy

1. Click **Create Web Service**
2. Wait for deployment (5-10 minutes)
3. Monitor logs for any errors
4. Once deployed, you'll get a URL like:
   ```
   https://grabgo-ml-service.onrender.com
   ```

### Step 6: Test Deployment

```bash
# Test health endpoint
curl https://grabgo-ml-service.onrender.com/health

# Should return:
# {
#   "status": "healthy",
#   "components": {
#     "postgres": "healthy",
#     "mongodb": "healthy",
#     "redis": "healthy"
#   }
# }
```

### Step 7: Update Backend

In your backend's Render environment variables:

```bash
ML_SERVICE_URL=https://grabgo-ml-service.onrender.com
ML_API_KEY=<same-api-key-as-ml-service>
```

Then redeploy your backend or it will auto-deploy.

---

## 🎉 You're Done!

Your ML service is now:
- ✅ Deployed to Render
- ✅ Connected to databases
- ✅ Accessible via HTTPS
- ✅ Ready to integrate with backend

---

## 📊 Post-Deployment

### Monitor Your Service

- **Logs**: https://dashboard.render.com → Your Service → Logs
- **Metrics**: https://dashboard.render.com → Your Service → Metrics
- **Health**: https://grabgo-ml-service.onrender.com/health
- **API Docs**: https://grabgo-ml-service.onrender.com/docs

### Test API Endpoints

```bash
# Get recommendations
curl -X POST https://grabgo-ml-service.onrender.com/api/v1/recommendations/food \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user", "limit": 10}'

# Predict delivery time
curl -X POST https://grabgo-ml-service.onrender.com/api/v1/predictions/delivery-time \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "restaurant_location": {"latitude": 5.6037, "longitude": -0.187},
    "delivery_location": {"latitude": 5.6100, "longitude": -0.190}
  }'
```

---

## ⚠️ Important Notes

### Free Tier Limitations:
- Services spin down after 15 min of inactivity
- First request after spin-down takes 30-60 seconds
- 750 hours/month free

### For Production:
- Upgrade to **Starter** plan ($7/month) for:
  - No spin-down
  - Better performance
  - More resources

### Database Backups:
- Free tier: No automatic backups
- Paid tier: Daily automatic backups
- Export data regularly for safety

---

## 🐛 Troubleshooting

### Build Failed
- Check Python version in `runtime.txt`
- Check `requirements.txt` for incompatible packages
- View build logs in Render dashboard

### Service Won't Start
- Check environment variables are set correctly
- Check database URLs are correct (use Internal URLs)
- View service logs in Render dashboard

### Database Connection Errors
- Ensure using **Internal Database URL** (not External)
- Check database is in same region
- Verify credentials

### High Latency
- Upgrade from free tier
- Ensure all services in same region
- Check database performance

---

## 💰 Cost Estimate

### Free Tier (Development):
- Web Service: Free (750 hours/month)
- PostgreSQL: Free (90 days, then $7/month)
- Redis: Free (90 days, then $7/month)
- MongoDB Atlas: Free (512MB)
- **Total: $0 for 90 days, then ~$14/month**

### Starter Tier (Production):
- Web Service: $7/month
- PostgreSQL: $7/month
- Redis: $7/month
- MongoDB Atlas: Free or $9/month
- **Total: ~$21-30/month**

---

## 🎯 Next Steps

1. ✅ Deploy to Render
2. ✅ Test all endpoints
3. ✅ Integrate with backend
4. ✅ Monitor performance
5. ✅ Scale as needed

**Your ML service is production-ready!** 🚀
