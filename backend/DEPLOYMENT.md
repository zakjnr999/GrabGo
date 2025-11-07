# Deployment Guide

This guide covers deploying the GrabGo backend API to various platforms.

## Quick Deploy Options

### 1. Render (Recommended for Beginners)

📖 **For detailed step-by-step instructions, see [RENDER_DEPLOYMENT.md](RENDER_DEPLOYMENT.md)**

**Quick Steps:**
1. **Create a Render account** at https://render.com
2. **Create a new Web Service**
3. **Connect your GitHub repository**
4. **Configure settings:**
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Root Directory**: `backend` (if backend is in a subfolder)
   - **Environment**: Node
5. **Add Environment Variables:**
   ```
   NODE_ENV=production
   PORT=5000
   MONGODB_URI=your_mongodb_connection_string
   JWT_SECRET=your_strong_secret_key
   API_KEY=your_api_key
   ```
6. **Deploy!**

**⚠️ Important Notes:**
- Free tier services spin down after 15 minutes of inactivity
- First request after spin-down takes ~30 seconds (cold start)
- For production, consider paid plan ($7/month) for always-on service

### 2. Heroku

1. **Install Heroku CLI** and login
2. **Create a new app:**
   ```bash
   heroku create grabgo-backend
   ```
3. **Add MongoDB Atlas addon:**
   ```bash
   heroku addons:create mongolab:sandbox
   ```
4. **Set environment variables:**
   ```bash
   heroku config:set NODE_ENV=production
   heroku config:set JWT_SECRET=your_secret
   heroku config:set API_KEY=your_api_key
   ```
5. **Deploy:**
   ```bash
   git push heroku main
   ```

### 3. DigitalOcean App Platform

1. **Create a new App** in DigitalOcean
2. **Connect your repository**
3. **Configure:**
   - **Build Command**: `npm install`
   - **Run Command**: `npm start`
4. **Add environment variables** in the App Settings
5. **Add MongoDB database** (or use MongoDB Atlas)
6. **Deploy**

### 4. AWS EC2

1. **Launch an EC2 instance** (Ubuntu recommended)
2. **SSH into the instance**
3. **Install Node.js and MongoDB:**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```
4. **Clone your repository:**
   ```bash
   git clone <your-repo-url>
   cd backend
   ```
5. **Install dependencies:**
   ```bash
   npm install --production
   ```
6. **Set up environment variables** in `.env`
7. **Use PM2 to run the app:**
   ```bash
   npm install -g pm2
   pm2 start ecosystem.config.js --env production
   pm2 save
   pm2 startup
   ```

### 5. Docker Deployment

#### Using Docker Compose (Recommended)

```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

#### Using Docker only

```bash
# Build image
docker build -t grabgo-backend .

# Run container
docker run -d \
  -p 5000:5000 \
  -e MONGODB_URI=mongodb://host.docker.internal:27017/grabgo \
  -e JWT_SECRET=your_secret \
  -e API_KEY=your_api_key \
  -v $(pwd)/uploads:/app/uploads \
  --name grabgo-backend \
  grabgo-backend
```

## MongoDB Setup

### Option 1: MongoDB Atlas (Recommended for Production)

1. **Create account** at https://www.mongodb.com/cloud/atlas
2. **Create a new cluster** (Free tier available)
3. **Create database user**
4. **Whitelist your IP** (or use 0.0.0.0/0 for all IPs)
5. **Get connection string:**
   ```
   mongodb+srv://username:password@cluster.mongodb.net/grabgo
   ```
6. **Use this in MONGODB_URI**

### Option 2: Self-Hosted MongoDB

1. **Install MongoDB** on your server
2. **Start MongoDB service**
3. **Use connection string:**
   ```
   mongodb://localhost:27017/grabgo
   ```

## Environment Variables

Create a `.env` file or set these in your hosting platform:

```env
# Server
NODE_ENV=production
PORT=5000

# Database
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/grabgo

# Security
JWT_SECRET=your_very_strong_secret_key_minimum_32_characters
JWT_EXPIRE=7d
API_KEY=your_api_key_here

# File Upload
MAX_FILE_SIZE=5242880
UPLOAD_PATH=./uploads

# CORS (comma-separated)
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# Admin (optional, for init script)
ADMIN_EMAIL=admin@grabgo.com
ADMIN_PASSWORD=change_this_password
```

## Post-Deployment Steps

1. **Initialize database:**
   ```bash
   npm run init-db
   ```
   This creates default categories and an admin user.

2. **Test the API:**
   ```bash
   curl https://your-api-url.com/api/health
   ```

3. **Update Flutter app** with your API URL:
   ```dart
   static const String apiBaseUrl = 'https://your-api-url.com/api';
   ```

## Security Checklist

- [ ] Change default JWT_SECRET to a strong random string
- [ ] Change default API_KEY
- [ ] Use HTTPS (SSL certificate)
- [ ] Set proper CORS origins
- [ ] Enable MongoDB authentication
- [ ] Use environment variables (never commit .env)
- [ ] Set up rate limiting (consider adding express-rate-limit)
- [ ] Regular backups of MongoDB
- [ ] Monitor logs for suspicious activity

## Monitoring

### Health Check Endpoint

```bash
GET /api/health
```

Returns:
```json
{
  "status": "ok",
  "message": "GrabGo API is running"
}
```

### Logs

- **Development**: Console output
- **Production**: Use platform logging or PM2 logs
  ```bash
  pm2 logs grabgo-backend
  ```

## Troubleshooting

### Connection Issues

- Check MongoDB connection string
- Verify network access (firewall, IP whitelist)
- Check MongoDB service is running

### Port Issues

- Ensure port is not in use
- Check firewall rules
- Verify PORT environment variable

### File Upload Issues

- Check uploads directory permissions
- Verify MAX_FILE_SIZE setting
- Check disk space

## Scaling

For high traffic:

1. **Use a load balancer** (nginx, AWS ALB)
2. **Run multiple instances** with PM2 cluster mode
3. **Use MongoDB replica sets**
4. **Implement caching** (Redis)
5. **CDN for static files**

## Support

For issues:
1. Check server logs
2. Verify environment variables
3. Test MongoDB connection
4. Review API documentation

