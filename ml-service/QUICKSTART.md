# 🚀 Quick Start - Next Steps

## ✅ Installation Complete!

Great! All dependencies are installed. Here's what to do next:

---

## 📋 Step 1: Configure Environment

```bash
# Make sure you're in the ml-service directory
cd /home/zakjnr/Documents/Project/GrabGo/ml-service

# Copy the example environment file
cp .env.example .env

# Edit the .env file with your credentials
nano .env
```

### Required Environment Variables:

Update these in your `.env` file:

```bash
# Generate a secret key
SECRET_KEY=your-secret-key-here  # Run: openssl rand -hex 32

# Generate an API key for backend integration
API_KEY=your-api-key-here  # Run: openssl rand -hex 32

# Database credentials (if different from defaults)
POSTGRES_PASSWORD=your-postgres-password
POSTGRES_USER=postgres
POSTGRES_DB=grabgo

# MongoDB (if using authentication)
MONGODB_URL=mongodb://localhost:27017

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
```

---

## 📋 Step 2: Verify Database Connections

Before starting the service, make sure your databases are running:

### PostgreSQL
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Test connection
psql -h localhost -U postgres -d grabgo -c "SELECT 1;"
```

### MongoDB
```bash
# Check if MongoDB is running
sudo systemctl status mongod

# Test connection
mongosh --eval "db.adminCommand('ping')"
```

### Redis
```bash
# Check if Redis is running
sudo systemctl status redis

# Test connection
redis-cli ping
```

**If any database is not running, start it:**
```bash
sudo systemctl start postgresql
sudo systemctl start mongod
sudo systemctl start redis
```

---

## 📋 Step 3: Start the ML Service

```bash
# Activate virtual environment
source venv/bin/activate

# Start the development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You should see output like:
```
INFO:     Will watch for changes in these directories: ['/home/zakjnr/Documents/Project/GrabGo/ml-service']
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

---

## 📋 Step 4: Test the Service

Open a new terminal and test the endpoints:

### Health Check
```bash
curl http://localhost:8000/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2026-02-05T02:40:00.000000",
  "components": {
    "postgres": "healthy",
    "mongodb": "healthy",
    "redis": "healthy"
  }
}
```

### API Documentation
Open in your browser:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### Test a Recommendation Endpoint
```bash
curl -X POST http://localhost:8000/api/v1/recommendations/food \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-123",
    "limit": 10
  }'
```

---

## 🐛 Troubleshooting

### Issue: Database connection errors

**Solution:**
1. Check if databases are running
2. Verify credentials in `.env`
3. Check firewall rules
4. Review logs in the terminal

### Issue: Import errors

**Solution:**
```bash
# Reinstall dependencies
source venv/bin/activate
pip install -r requirements.txt
```

### Issue: Port 8000 already in use

**Solution:**
```bash
# Use a different port
uvicorn app.main:app --reload --host 0.0.0.0 --port 8001

# Or kill the process using port 8000
lsof -ti:8000 | xargs kill -9
```

---

## 🔗 Next: Backend Integration

Once the ML service is running, integrate it with your Node.js backend:

1. **Add to backend `.env`:**
```bash
ML_SERVICE_URL=http://localhost:8000
ML_API_KEY=your-api-key-here
```

2. **Install axios in backend:**
```bash
cd ../backend
npm install axios
```

3. **Use the integration examples:**
See `INTEGRATION.js` for complete code examples.

---

## 📚 Documentation

- **API Docs**: http://localhost:8000/docs
- **Architecture**: See `ARCHITECTURE.md`
- **Deployment**: See `DEPLOYMENT.md`
- **Integration**: See `INTEGRATION.js`

---

## ✨ You're Ready!

Your ML service is now:
- ✅ Installed and configured
- ✅ Ready to start
- ✅ Ready to integrate with backend
- ✅ Production-ready

**Start the service and begin testing!** 🚀

```bash
source venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
