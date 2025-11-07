# Render Deployment Checklist

Use this checklist to ensure you don't miss any steps during deployment.

## Pre-Deployment

- [ ] Code is committed and pushed to GitHub
- [ ] All dependencies are in `package.json`
- [ ] `package.json` has `start` script: `"start": "node server.js"`
- [ ] MongoDB Atlas account created
- [ ] MongoDB cluster created and running
- [ ] Database user created with password
- [ ] IP address whitelisted in MongoDB Atlas
- [ ] MongoDB connection string saved

## Render Setup

- [ ] Render account created
- [ ] GitHub account connected to Render
- [ ] Repository selected in Render
- [ ] Web Service created

## Configuration

- [ ] **Name**: Set service name (e.g., `grabgo-backend`)
- [ ] **Region**: Selected appropriate region
- [ ] **Branch**: Set to `main` (or your default branch)
- [ ] **Root Directory**: Set to `backend` (if backend is in subfolder)
- [ ] **Build Command**: `npm install`
- [ ] **Start Command**: `npm start`

## Environment Variables

Add all these in Render dashboard:

- [ ] `NODE_ENV` = `production`
- [ ] `PORT` = `5000`
- [ ] `MONGODB_URI` = `mongodb+srv://username:password@cluster.mongodb.net/grabgo`
- [ ] `JWT_SECRET` = `your_strong_random_secret` (32+ characters)
- [ ] `JWT_EXPIRE` = `7d`
- [ ] `API_KEY` = `your_api_key` (changed from default)
- [ ] `ALLOWED_ORIGINS` = `*` (or specific domains)

## Deployment

- [ ] Service created successfully
- [ ] Build completed without errors
- [ ] Deployment successful
- [ ] Service is live (green status)

## Testing

- [ ] Health check works: `https://your-service.onrender.com/api/health`
- [ ] Can register a user
- [ ] Can login
- [ ] MongoDB connection successful (check logs)
- [ ] No errors in logs

## Post-Deployment

- [ ] Update Flutter app with new API URL
- [ ] Test Flutter app connection
- [ ] Remove any test/debug code
- [ ] Update `ALLOWED_ORIGINS` to specific domains
- [ ] Document your service URL
- [ ] Set up monitoring (optional)

## Security Checklist

- [ ] `JWT_SECRET` is strong and random
- [ ] `API_KEY` changed from default
- [ ] MongoDB password is strong
- [ ] `ALLOWED_ORIGINS` restricted (not `*` in production)
- [ ] MongoDB IP whitelist configured
- [ ] No secrets in code (all in environment variables)

## Troubleshooting

If deployment fails:

- [ ] Check build logs for errors
- [ ] Verify `package.json` is correct
- [ ] Check all environment variables are set
- [ ] Verify MongoDB connection string format
- [ ] Check MongoDB Atlas IP whitelist
- [ ] Verify root directory is correct
- [ ] Check start command is correct

## Quick Reference

**Service URL:**
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

**MongoDB Connection String Format:**
```
mongodb+srv://username:password@cluster.mongodb.net/grabgo
```

---

**✅ Once all items are checked, your deployment is complete!**

