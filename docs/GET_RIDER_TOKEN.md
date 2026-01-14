# 🔑 How to Get a Rider JWT Token for Testing

## Quick Solutions (Choose One)

---

## ✅ **Option 1: Temporary Bypass (EASIEST)**

Temporarily disable auth in backend for testing:

### Edit `backend/server.js` (lines 61-63):

**Before:**
```javascript
if (!token) {
  return next(new Error("Not authorized, no token provided"));
}
```

**After (for testing only):**
```javascript
if (!token) {
  // TESTING ONLY: Allow connection without token
  socket.data.userId = "test-rider-123";
  socket.data.userRole = "rider";
  return next();
}
```

**Remember to revert this after testing!**

---

## ✅ **Option 2: Use Postman/cURL to Login**

### 1. Login as Rider via API

```bash
curl -X POST https://grabgo-backend.onrender.com/api/auth/rider/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "rider@test.com",
    "password": "your-password"
  }'
```

### 2. Copy the Token

Response will look like:
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {...}
}
```

### 3. Paste Token in Test Client

Copy the `token` value and paste it in the "Rider JWT Token" field.

---

## ✅ **Option 3: Get Token from Rider App**

If you have a rider app running:

### In Browser DevTools:
```javascript
// Open DevTools (F12)
// Go to Console
localStorage.getItem('authToken')
// or
localStorage.getItem('riderToken')
```

### In Flutter App:
```dart
// Add this temporarily to print token
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('authToken');
print('TOKEN: $token');
```

---

## ✅ **Option 4: Create Test Rider Account**

### 1. Register a Test Rider

```bash
curl -X POST https://grabgo-backend.onrender.com/api/auth/rider/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Rider",
    "email": "test-rider@example.com",
    "password": "Test123!",
    "phone": "+1234567890"
  }'
```

### 2. Login with Test Account

```bash
curl -X POST https://grabgo-backend.onrender.com/api/auth/rider/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test-rider@example.com",
    "password": "Test123!"
  }'
```

### 3. Use the Token

Copy the token from the response.

---

## 🚀 **Quick Test Script**

I've created a script to get a token automatically:

```bash
#!/bin/bash
# Save as: get-rider-token.sh

BACKEND_URL="https://grabgo-backend.onrender.com"
EMAIL="test-rider@example.com"
PASSWORD="Test123!"

echo "🔐 Getting rider token..."

# Login
RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/auth/rider/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

# Extract token
TOKEN=$(echo $RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get token"
  echo "Response: $RESPONSE"
else
  echo "✅ Token retrieved!"
  echo ""
  echo "📋 Copy this token:"
  echo "$TOKEN"
  echo ""
  echo "Paste it in the test client's 'Rider JWT Token' field"
fi
```

**Usage:**
```bash
chmod +x get-rider-token.sh
./get-rider-token.sh
```

---

## 💡 **Recommended for Testing**

**Use Option 1 (Temporary Bypass)** - It's the fastest and easiest for testing!

Just remember to:
1. ✅ Make the change in `server.js`
2. ✅ Restart your backend
3. ✅ Test your WebRTC feature
4. ✅ **Revert the change** before deploying to production

---

## 🔒 **Security Note**

**NEVER** deploy the temporary bypass to production! It's only for local testing.

For production, always use proper authentication with real JWT tokens.

---

## 📞 **Still Having Issues?**

If you're still getting auth errors:

1. **Check backend logs** - See what error is being thrown
2. **Verify token format** - Should start with `eyJ`
3. **Check token expiry** - Tokens might expire after 24h
4. **Try without token** - See if backend allows it
5. **Check CORS** - Make sure backend allows your origin

---

**Happy Testing!** 🎉
