# GrabGo Admin Panel - Render Deployment Quick Start

## 🚀 Quick Deploy Steps

### Option 1: Using render.yaml (Recommended)

1. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Add Render deployment config"
   git push
   ```

2. **Create Service on Render**
   - Go to https://dashboard.render.com
   - Click "New +" → "Blueprint"
   - Connect your GrabGo repository
   - Render will automatically detect `render.yaml`
   - Click "Apply"

3. **Add Environment Variables**
   - In Render dashboard, go to your service
   - Click "Environment" tab
   - Add all variables from `web/apps/admin/.env.local`
   - Click "Save Changes"

4. **Deploy**
   - Render will automatically deploy
   - Your app will be live at: `https://grabgo-admin.onrender.com`

### Option 2: Manual Setup

1. **Go to Render Dashboard**
   - Visit https://dashboard.render.com
   - Click "New +" → "Web Service"

2. **Configure**
   - **Repository**: Select GrabGo
   - **Name**: `grabgo-admin`
   - **Build Command**: `./web/apps/admin/render-build.sh`
   - **Start Command**: `cd web/apps/admin && node .next/standalone/web/apps/admin/server.js`

3. **Add Environment Variables** (same as Option 1, step 3)

4. **Deploy** (same as Option 1, step 4)

## 📋 Required Environment Variables

Copy these from your `web/apps/admin/.env.local`:

- `NODE_ENV=production` (already set in render.yaml)
- `NEXT_PUBLIC_API_URL` (your backend API URL)
- Add any other `NEXT_PUBLIC_*` variables
- Add any Firebase/Auth keys
- Add any database connection strings

## 🔍 Verify Deployment

1. Check build logs in Render dashboard
2. Visit your deployed URL
3. Test admin panel functionality
4. Monitor for any errors

## 🛠️ Troubleshooting

**Build fails?**
- Check Render logs for specific errors
- Verify all dependencies are in `package.json`
- Ensure `render-build.sh` is executable

**App crashes on start?**
- Check environment variables are set correctly
- Verify backend API is accessible
- Check Render logs for runtime errors

**Slow cold starts?**
- Upgrade to Starter plan ($7/month) for always-on service

## 📚 Full Documentation

See `.agent/workflows/deploy-admin-to-render.md` for complete guide.

## 🎯 Next Steps

1. ✅ Deploy to Render
2. 🔒 Set up custom domain (optional)
3. 📊 Monitor performance
4. 🔄 Enable auto-deploy on push
5. 🧪 Set up staging environment (optional)
