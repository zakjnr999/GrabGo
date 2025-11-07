# Troubleshooting Profile Picture Upload

If profile pictures aren't uploading, follow these steps:

## 1. Check Render Logs

Go to your Render dashboard → Your service → **Logs** tab

Look for:
- ✅ `📤 Profile upload request:` - Confirms request received
- ✅ `✅ Profile picture uploaded successfully:` - Confirms upload worked
- ❌ `❌ Cloudinary upload middleware error:` - Indicates Cloudinary issue
- ❌ `Cloudinary upload failed` - Indicates file processing issue

## 2. Verify Cloudinary Environment Variables

In Render dashboard → Environment tab, ensure these are set:
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

**Test:** Check Render logs for Cloudinary connection errors

## 3. Check Common Issues

### Issue: "No file uploaded"
**Cause:** File not being sent from client
**Solution:** 
- Check client is sending file with field name `profilePicture`
- Verify image is selected before upload
- Check file size (max 5MB)

### Issue: "Cloudinary URL not found"
**Cause:** Cloudinary upload failed
**Possible reasons:**
- Invalid Cloudinary credentials
- Network issue
- File too large
- Invalid file format

**Solution:**
- Verify Cloudinary credentials in Render
- Check Cloudinary dashboard for uploads
- Verify file is image format (jpg, png, etc.)

### Issue: "Failed to upload image to Cloudinary"
**Cause:** Cloudinary API error
**Check:**
- Render logs for specific error message
- Cloudinary dashboard → Activity → Uploads
- Verify Cloudinary account is active

## 4. Test the Endpoint

You can test using curl:

```bash
curl -X PUT https://grabgo-backend.onrender.com/api/users/YOUR_USER_ID/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "profilePicture=@/path/to/image.jpg"
```

## 5. Check Response Format

The API should return:
```json
{
  "success": true,
  "message": "Profile picture uploaded successfully",
  "user": {
    ...
    "profilePicture": "https://res.cloudinary.com/..."
  }
}
```

## 6. Verify in Database

Check if the profile picture URL was saved:
- Look for `profilePicture` field in user document
- Should be a Cloudinary URL (starts with `https://res.cloudinary.com/`)

## 7. Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "No file uploaded" | File not sent | Check client code |
| "Cloudinary URL not found" | Upload failed | Check Cloudinary credentials |
| "Failed to upload to Cloudinary" | API error | Check Render logs |
| "Not authorized" | Wrong user ID | Verify token and user ID match |
| "User not found" | Invalid user ID | Check user exists |

## 8. Debug Steps

1. **Check Render logs** - Look for error messages
2. **Verify Cloudinary credentials** - Test in Cloudinary dashboard
3. **Check file format** - Must be image (jpg, png, gif, webp)
4. **Check file size** - Max 5MB (configurable via MAX_FILE_SIZE)
5. **Verify endpoint** - Should be `PUT /api/users/:userId/upload`
6. **Check authentication** - Token must be valid
7. **Test with curl** - Bypass client to isolate issue

## 9. Still Not Working?

If still having issues:
1. Share the error message from Render logs
2. Check Cloudinary dashboard for any upload attempts
3. Verify the file is actually being sent from the client
4. Check if other endpoints work (to rule out general server issues)

