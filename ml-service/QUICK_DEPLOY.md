# ⚡ Quick Deploy - ML Service to Render

## 🎯 Your Situation
- ✅ PostgreSQL: Supabase (already have)
- ✅ MongoDB: Already configured
- ✅ Redis: Already configured
- ⏳ ML Service: Need to deploy to Render

---

## 🚀 5-Step Deployment

### 1️⃣ Generate Keys (30 seconds)
```bash
openssl rand -hex 32  # SECRET_KEY
openssl rand -hex 32  # API_KEY
```

### 2️⃣ Push to GitHub (1 minute)
```bash
cd /home/zakjnr/Documents/Project/GrabGo
git add ml-service/
git commit -m "Add ML service"
git push origin main
```

### 3️⃣ Create Render Web Service (2 minutes)
- Go to: https://dashboard.render.com
- New + → Web Service
- Connect GitHub repo
- Root Directory: `ml-service`
- Build: `pip install -r requirements.txt`
- Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 2`

### 4️⃣ Add Environment Variables (3 minutes)
```bash
# Security
SECRET_KEY=<from-step-1>
API_KEY=<from-step-1>

# Supabase PostgreSQL
DATABASE_URL=<your-supabase-connection-string>

# MongoDB
MONGODB_URL=<your-mongodb-connection-string>

# Redis
REDIS_URL=<your-redis-connection-string>

# Optional
ENV=production
DEBUG=False
WORKERS=2
```

### 5️⃣ Deploy (5-10 minutes)
- Click "Create Web Service"
- Wait for deployment
- Get URL: `https://grabgo-ml-service.onrender.com`

---

## ✅ Test
```bash
curl https://grabgo-ml-service.onrender.com/health
```

---

## 🔗 Update Backend
Add to backend environment variables:
```bash
ML_SERVICE_URL=https://grabgo-ml-service.onrender.com
ML_API_KEY=<same-as-ml-service>
```

---

## 📚 Full Guide
See: `RENDER_SIMPLE_DEPLOY.md`

---

## 💰 Cost
- Free: $0 (with cold starts)
- Starter: $7/month (no cold starts)

**Total Time: ~15 minutes** ⚡
