# Cloudinary Setup Guide

This guide explains how to set up Cloudinary for image uploads in the GrabGo backend.

## Prerequisites

1. Create a free account at [Cloudinary](https://cloudinary.com/)
2. Get your Cloudinary credentials from the dashboard

## Installation

The required packages are already added to `package.json`:
- `cloudinary`: ^1.41.0
- `multer-storage-cloudinary`: ^4.0.0 (optional, not used in current implementation)

Install dependencies:
```bash
cd backend
npm install
```

## Environment Variables

Add the following environment variables to your `.env` file:

```env
# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

### How to Get Your Cloudinary Credentials

1. Sign up at [cloudinary.com](https://cloudinary.com/)
2. Go to your Dashboard
3. You'll see your credentials:
   - **Cloud Name**: Found in the dashboard URL or under "Account Details"
   - **API Key**: Found in "Account Details" section
   - **API Secret**: Found in "Account Details" section (click "Reveal" to see it)

## How It Works

### File Upload Flow

1. **Client uploads file** → Multer processes it (stores in memory)
2. **uploadToCloudinary middleware** → Uploads to Cloudinary
3. **Route handler** → Saves Cloudinary URL to database

### Folder Structure in Cloudinary

Images are organized in the following folders:
- `grabgo/profiles/` - User profile pictures
- `grabgo/restaurants/` - Restaurant logos
- `grabgo/foods/` - Food item images
- `grabgo/documents/` - Business documents (ID photos, owner photos)

### Automatic Image Optimization

All uploaded images are automatically:
- Resized to max 800x800px (maintaining aspect ratio)
- Optimized for web delivery
- Served via HTTPS (secure URLs)

## API Endpoints Using Cloudinary

### User Profile Picture
- **Endpoint**: `PUT /api/users/:userId/upload`
- **Field name**: `profilePicture`
- **Returns**: Cloudinary URL

### Restaurant Registration
- **Endpoint**: `POST /api/restaurants/register`
- **Fields**: `logo`, `business_id_photo`, `owner_photo`
- **Returns**: Cloudinary URLs

### Food Items
- **Create**: `POST /api/foods` (field: `image`)
- **Update**: `PUT /api/foods/:foodId` (field: `image`)
- **Returns**: Cloudinary URL

## Features

### Automatic Old Image Deletion
When updating profile pictures or food images, the old Cloudinary image is automatically deleted to save storage space.

### Backward Compatibility
The system still supports local file uploads (for development/testing). If Cloudinary credentials are not set, it will fall back to local storage.

## Troubleshooting

### Images Not Uploading

1. **Check Environment Variables**
   ```bash
   # Verify your .env file has all three Cloudinary variables
   echo $CLOUDINARY_CLOUD_NAME
   echo $CLOUDINARY_API_KEY
   echo $CLOUDINARY_API_SECRET
   ```

2. **Check Cloudinary Dashboard**
   - Verify your account is active
   - Check if you've exceeded free tier limits (25GB storage, 25GB bandwidth)

3. **Check Server Logs**
   - Look for "Cloudinary upload error" messages
   - Verify the file size is under 5MB (configurable via `MAX_FILE_SIZE`)

### Common Errors

**Error: "Invalid cloud_name"**
- Solution: Check your `CLOUDINARY_CLOUD_NAME` in `.env`

**Error: "Invalid API key"**
- Solution: Verify your `CLOUDINARY_API_KEY` in `.env`

**Error: "Invalid signature"**
- Solution: Check your `CLOUDINARY_API_SECRET` in `.env`

**Error: "File too large"**
- Solution: Increase `MAX_FILE_SIZE` in `.env` or compress images before upload

## Testing

After setting up, test the upload functionality:

```bash
# Test profile picture upload
curl -X PUT http://localhost:5000/api/users/:userId/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "profilePicture=@/path/to/image.jpg"
```

## Free Tier Limits

Cloudinary's free tier includes:
- 25GB storage
- 25GB bandwidth per month
- Unlimited transformations
- CDN delivery

For production apps with high traffic, consider upgrading to a paid plan.

## Security Notes

1. **Never commit `.env` file** - Keep your API secret secure
2. **Use environment variables** - Don't hardcode credentials
3. **Set up upload limits** - Configure `MAX_FILE_SIZE` to prevent abuse
4. **Validate file types** - Only allow image files (already configured)

## Additional Resources

- [Cloudinary Documentation](https://cloudinary.com/documentation)
- [Node.js SDK Guide](https://cloudinary.com/documentation/node_integration)
- [Image Transformations](https://cloudinary.com/documentation/image_transformations)

