# Setting Up Environment Variables on Render

Since your backend is hosted on Render, you need to add the Cloudinary environment variables in Render's dashboard.

## Steps to Add Environment Variables on Render

### 1. Go to Your Render Dashboard
1. Log in to [render.com](https://render.com)
2. Navigate to your **GrabGo backend service**

### 2. Add Environment Variables
1. Click on your service
2. Go to **Environment** tab (in the left sidebar)
3. Click **Add Environment Variable** button

### 3. Add These Three Variables

Add each variable one by one:

**Variable 1:**
- **Key:** `CLOUDINARY_CLOUD_NAME`
- **Value:** Your Cloudinary cloud name (e.g., `dxxuaiqib`)

**Variable 2:**
- **Key:** `CLOUDINARY_API_KEY`
- **Value:** Your Cloudinary API key

**Variable 3:**
- **Key:** `CLOUDINARY_API_SECRET`
- **Value:** Your Cloudinary API secret

### 4. Save and Deploy
- After adding all three variables, Render will automatically:
  - Save the changes
  - Restart your service
  - Apply the new environment variables

### 5. Verify It's Working
After the restart completes:
- Check your service logs in Render dashboard
- You should see: `✅ Connected to MongoDB`
- Test an image upload through your app
- Check Cloudinary dashboard to see if images are being uploaded

## Important Notes

⚠️ **Make sure these variables are also set:**
- `MONGODB_URI` - Your MongoDB connection string
- `JWT_SECRET` - Your JWT secret key
- `API_KEY` - Should be `pAuLInepisT_les` (to match your Flutter app)
- `PORT` - Usually set automatically by Render

## Quick Checklist

- [ ] Logged into Render dashboard
- [ ] Found your backend service
- [ ] Added `CLOUDINARY_CLOUD_NAME`
- [ ] Added `CLOUDINARY_API_KEY`
- [ ] Added `CLOUDINARY_API_SECRET`
- [ ] Service restarted automatically
- [ ] Tested image upload

## Troubleshooting

**Service won't start?**
- Check Render logs for errors
- Verify all environment variables are set correctly
- Make sure MongoDB URI is correct

**Images not uploading?**
- Check Cloudinary credentials are correct
- Verify service restarted after adding variables
- Check Render logs for Cloudinary errors

## Your Current API Base URL

Based on your Flutter config, your API is at:
```
https://grabgo.onrender.com/api
```

Make sure this matches your Render service URL!

