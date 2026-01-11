---
description: Deploy Web Admin Panel to Render
---

# Deploy GrabGo Web Admin Panel to Render

This workflow guides you through deploying your Next.js admin panel to Render.

## Prerequisites

1. A Render account (sign up at https://render.com)
2. Your GitHub repository connected to Render
3. Environment variables ready (from your `.env.local` file)

## Deployment Steps

### Step 1: Prepare Your Project

First, ensure your admin panel builds successfully locally:

```bash
cd /home/zakjnr/Documents/Project/GrabGo/web/apps/admin
pnpm install
pnpm build
```

### Step 2: Create a `render.yaml` Configuration (Recommended)

Create a `render.yaml` file in your project root (`/home/zakjnr/Documents/Project/GrabGo/`) for Infrastructure as Code:

```yaml
services:
  - type: web
    name: grabgo-admin
    runtime: node
    region: oregon # or your preferred region
    plan: free # or starter/standard
    buildCommand: cd web/apps/admin && pnpm install && pnpm build
    startCommand: cd web/apps/admin && pnpm start
    envVars:
      - key: NODE_ENV
        value: production
      - key: NEXT_PUBLIC_API_URL
        sync: false # You'll add this manually in Render dashboard
      # Add other environment variables as needed
```

### Step 3: Alternative - Manual Render Setup

If you prefer manual setup instead of `render.yaml`:

1. **Go to Render Dashboard**
   - Visit https://dashboard.render.com
   - Click "New +" → "Web Service"

2. **Connect Your Repository**
   - Select your GrabGo repository
   - Grant necessary permissions

3. **Configure the Service**
   - **Name**: `grabgo-admin` (or your preferred name)
   - **Region**: Choose closest to your users
   - **Branch**: `main` (or your production branch)
   - **Root Directory**: Leave empty (we'll specify in commands)
   - **Runtime**: `Node`
   - **Build Command**: 
     ```bash
     cd web/apps/admin && pnpm install && pnpm build
     ```
   - **Start Command**: 
     ```bash
     cd web/apps/admin && pnpm start
     ```
   - **Plan**: Free (or paid plan for better performance)

4. **Add Environment Variables**
   - Click "Advanced" → "Add Environment Variable"
   - Add all variables from your `.env.local` file
   - Common variables:
     - `NODE_ENV=production`
     - `NEXT_PUBLIC_API_URL` (your backend API URL)
     - Any Firebase or authentication keys
     - Database connection strings

### Step 4: Configure for Monorepo (Important!)

Since you're using a monorepo with pnpm workspaces, you need to ensure Render can access workspace dependencies:

**Option A: Build from Root (Recommended)**

Update your build command to:
```bash
pnpm install && cd web/apps/admin && pnpm build
```

**Option B: Create a Standalone Build**

Modify `web/apps/admin/next.config.ts`:
```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'standalone', // This creates a standalone build
};

export default nextConfig;
```

Then update your start command to:
```bash
cd web/apps/admin && node .next/standalone/web/apps/admin/server.js
```

### Step 5: Handle Static Assets (if using standalone)

If you chose the standalone option, you'll need to copy static files:

Create a `web/apps/admin/render-build.sh`:
```bash
#!/bin/bash
set -e

# Install dependencies
pnpm install

# Build the app
cd web/apps/admin
pnpm build

# Copy static files for standalone mode
cp -r public .next/standalone/web/apps/admin/
cp -r .next/static .next/standalone/web/apps/admin/.next/
```

Make it executable and update Render build command:
```bash
chmod +x web/apps/admin/render-build.sh
```

Build Command: `./web/apps/admin/render-build.sh`

### Step 6: Deploy

1. Click "Create Web Service" (if manual setup)
2. Render will automatically build and deploy
3. Monitor the logs for any errors
4. Once deployed, you'll get a URL like: `https://grabgo-admin.onrender.com`

### Step 7: Set Up Custom Domain (Optional)

1. In Render dashboard, go to your service
2. Click "Settings" → "Custom Domain"
3. Add your domain (e.g., `admin.grabgo.com`)
4. Update your DNS records as instructed by Render

### Step 8: Enable Auto-Deploy

1. In service settings, enable "Auto-Deploy"
2. Choose your branch (e.g., `main`)
3. Every push to this branch will trigger a new deployment

## Troubleshooting

### Build Fails - Workspace Dependencies Not Found

**Solution**: Ensure you're running `pnpm install` from the root before building:
```bash
cd /home/zakjnr/Documents/Project/GrabGo && pnpm install && cd web/apps/admin && pnpm build
```

### Environment Variables Not Working

**Solution**: 
- Ensure all `NEXT_PUBLIC_*` variables are set in Render
- Restart the service after adding new variables
- Check that variable names match exactly (case-sensitive)

### Build Succeeds but App Crashes on Start

**Solution**:
- Check Render logs for errors
- Verify your start command is correct
- Ensure all runtime dependencies are in `dependencies`, not `devDependencies`

### Slow Build Times

**Solution**:
- Upgrade to a paid Render plan for faster builds
- Use build caching by ensuring `node_modules` is cached
- Consider using standalone mode to reduce deployment size

## Performance Optimization

1. **Enable Caching**: Render automatically caches `node_modules`
2. **Use CDN**: Render provides CDN for static assets
3. **Optimize Images**: Use Next.js Image optimization
4. **Monitor Performance**: Use Render's metrics dashboard

## Cost Considerations

- **Free Tier**: 
  - 750 hours/month (enough for one always-on service)
  - Spins down after 15 minutes of inactivity
  - Cold starts take 30-60 seconds
  
- **Starter Plan** ($7/month):
  - Always on (no cold starts)
  - Better performance
  - Recommended for production

## Security Best Practices

1. Never commit `.env.local` to git
2. Use Render's environment variable encryption
3. Enable HTTPS (automatic with Render)
4. Set up proper CORS in your Next.js app
5. Use Render's built-in DDoS protection

## Next Steps

After deployment:
1. Test all admin panel features
2. Set up monitoring and alerts
3. Configure backups if needed
4. Document your deployment process
5. Set up staging environment (optional)

## Useful Commands

**View Logs**:
```bash
# In Render dashboard, go to "Logs" tab
```

**Manual Deploy**:
```bash
# In Render dashboard, click "Manual Deploy" → "Deploy latest commit"
```

**Rollback**:
```bash
# In Render dashboard, go to "Events" → Select previous deploy → "Rollback"
```

## Additional Resources

- [Render Next.js Documentation](https://render.com/docs/deploy-nextjs)
- [Render Environment Variables](https://render.com/docs/environment-variables)
- [Next.js Deployment Documentation](https://nextjs.org/docs/deployment)
