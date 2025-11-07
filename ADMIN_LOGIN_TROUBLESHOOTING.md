# 🔧 Admin Login Troubleshooting Guide

## Error: "Failed to fetch URI"

This error typically means the admin app cannot connect to the backend API.

---

## ✅ Quick Fixes

### 1. Check Backend Server is Running

**Make sure your backend is running:**
```bash
cd backend
npm run dev
```

**You should see:**
```
✅ Connected to MongoDB
🚀 Server running on port 5000
📡 API available at http://localhost:5000/api
```

### 2. Verify API URL Configuration

The admin app uses the API URL from `grab_go_shared/lib/shared/utils/config.dart`.

**Current default:** `http://localhost:5000/api`

**If your backend runs on a different port:**
- Update the `apiBaseUrl` in `packages/grab_go_shared/lib/shared/utils/config.dart`
- Or set environment variable when running:
  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
  ```

### 3. Check CORS Settings

The backend CORS is set to allow all origins (`*`) by default, which should work for local development.

**If you still get CORS errors, check `backend/server.js`:**
```javascript
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true
}));
```

**For local development, you can set in `.env`:**
```env
ALLOWED_ORIGINS=http://localhost:*,http://127.0.0.1:*
```

### 4. Test API Connection

**Test if backend is accessible:**
```bash
# In browser or Postman
GET http://localhost:5000/api/health
```

**Expected response:**
```json
{
  "status": "ok",
  "message": "GrabGo API is running"
}
```

### 5. Check Browser Console

Open browser DevTools (F12) and check:
- **Console tab** - Look for error messages
- **Network tab** - Check if the request is being sent and what response you get

---

## 🔍 Common Issues & Solutions

### Issue 1: Backend Not Running
**Symptom:** "Failed to fetch" or "Network error"

**Solution:**
1. Start backend: `cd backend && npm run dev`
2. Verify it's running on port 5000
3. Check `http://localhost:5000/api/health` in browser

### Issue 2: Wrong API URL
**Symptom:** "Failed to fetch" or connection timeout

**Solution:**
1. Check `packages/grab_go_shared/lib/shared/utils/config.dart`
2. Ensure `apiBaseUrl` is `http://localhost:5000/api` for local dev
3. If using remote server, ensure it's accessible

### Issue 3: CORS Error
**Symptom:** Browser console shows CORS error

**Solution:**
1. Check backend CORS settings in `server.js`
2. For local dev, `origin: '*'` should work
3. Or add your admin app URL to `ALLOWED_ORIGINS`

### Issue 4: Port Already in Use
**Symptom:** Backend fails to start

**Solution:**
1. Change port in `.env`: `PORT=5001`
2. Update API URL in config to match: `http://localhost:5001/api`
3. Or kill the process using port 5000

### Issue 5: MongoDB Not Connected
**Symptom:** Backend starts but API calls fail

**Solution:**
1. Ensure MongoDB is running
2. Check `MONGODB_URI` in `.env`
3. Verify connection in backend logs

---

## 🧪 Step-by-Step Debugging

### Step 1: Verify Backend
```bash
# Terminal 1: Start backend
cd backend
npm run dev

# Terminal 2: Test API
curl http://localhost:5000/api/health
# Should return: {"status":"ok","message":"GrabGo API is running"}
```

### Step 2: Test Login Endpoint
```bash
# Using curl or Postman
curl -X POST http://localhost:5000/api/users/login \
  -H "Content-Type: application/json" \
  -H "API_KEY: pAuLInepisT_les" \
  -d '{"email":"admin@grabgo.com","password":"admin123"}'
```

**Expected:** Should return user data and token

### Step 3: Check Admin App Network Request

1. Open admin app in browser
2. Open DevTools (F12)
3. Go to **Network** tab
4. Try to login
5. Check the request:
   - **URL**: Should be `http://localhost:5000/api/users/login`
   - **Method**: POST
   - **Status**: Should be 200 or 401 (not failed)
   - **Response**: Check the response body

### Step 4: Check Browser Console

Look for:
- CORS errors
- Network errors
- API URL issues
- Authentication errors

---

## 🔧 Configuration Options

### Option 1: Use Local Backend (Default)
```dart
// packages/grab_go_shared/lib/shared/utils/config.dart
static const String apiBaseUrl = 'http://localhost:5000/api';
```

### Option 2: Use Remote Backend
```dart
static const String apiBaseUrl = 'https://your-backend-url.com/api';
```

### Option 3: Use Environment Variable
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
```

---

## 📋 Checklist

Before trying to login, ensure:

- [ ] Backend server is running (`npm run dev`)
- [ ] Backend is accessible at `http://localhost:5000/api/health`
- [ ] MongoDB is connected
- [ ] Admin user exists (run `npm run init-db`)
- [ ] API URL in config matches backend URL
- [ ] No CORS errors in browser console
- [ ] Network tab shows the request is being sent

---

## 🐛 Still Not Working?

### Check These:

1. **Backend Logs:**
   - Look for errors in the terminal where backend is running
   - Check for connection errors, validation errors, etc.

2. **Browser Console:**
   - Open DevTools (F12)
   - Check Console and Network tabs
   - Look for specific error messages

3. **API Key:**
   - Verify `API_KEY` in config matches backend `.env`
   - Default: `pAuLInepisT_les`

4. **Firewall/Antivirus:**
   - May be blocking localhost connections
   - Try disabling temporarily to test

5. **Port Conflicts:**
   - Another app might be using port 5000
   - Change backend port if needed

---

## 💡 Quick Test

**Test the login endpoint directly:**

```bash
# Using curl
curl -X POST http://localhost:5000/api/users/login \
  -H "Content-Type: application/json" \
  -H "API_KEY: pAuLInepisT_les" \
  -d '{"email":"admin@grabgo.com","password":"admin123"}'
```

**Or use Postman:**
- Method: POST
- URL: `http://localhost:5000/api/users/login`
- Headers:
  - `Content-Type: application/json`
  - `API_KEY: pAuLInepisT_les`
- Body:
  ```json
  {
    "email": "admin@grabgo.com",
    "password": "admin123"
  }
  ```

If this works but the admin app doesn't, the issue is in the app configuration, not the backend.

---

**Most common issue:** Backend not running or wrong API URL! 🎯

