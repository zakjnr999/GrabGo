# 🔐 How to Use API Documentation with Authentication

## ✅ Your API is Working Correctly!

The error `"API key is required"` means the security is working as expected. You just need to authenticate in the Swagger UI.

---

## 🔑 Your API Key

```
b102a6829eef4aea7b8c8f46ef6f3d9b54524ee9649d27a87e0ea35df8c91951
```

---

## 📝 How to Authenticate in Swagger UI

### Step 1: Open the Docs
Go to: https://grabgo-ml-service.onrender.com/docs

### Step 2: Click "Authorize" Button
Look for the **"Authorize"** button at the top right of the page (it has a lock icon 🔒)

### Step 3: Enter Your API Key
In the popup window:
1. Find the **"X-API-Key"** field
2. Enter your API key:
   ```
   b102a6829eef4aea7b8c8f46ef6f3d9b54524ee9649d27a87e0ea35df8c91951
   ```
3. Click **"Authorize"**
4. Click **"Close"**

### Step 4: Test Endpoints
Now you can test any endpoint! The API key will be automatically included in all requests.

---

## 🧪 Quick Test - Food Recommendations

After authorizing, try this:

1. **Find the endpoint**: `POST /api/v1/recommendations/food`
2. **Click "Try it out"**
3. **Edit the request body**:
   ```json
   {
     "user_id": "test-user-123",
     "limit": 10
   }
   ```
4. **Click "Execute"**
5. **See the response!** ✅

---

## 📋 Alternative: Test with cURL

If you prefer command line:

```bash
# Food Recommendations
curl -X POST https://grabgo-ml-service.onrender.com/api/v1/recommendations/food \
  -H "X-API-Key: b102a6829eef4aea7b8c8f46ef6f3d9b54524ee9649d27a87e0ea35df8c91951" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-123",
    "limit": 10
  }'

# Delivery Time Prediction
curl -X POST https://grabgo-ml-service.onrender.com/api/v1/predictions/delivery-time \
  -H "X-API-Key: b102a6829eef4aea7b8c8f46ef6f3d9b54524ee9649d27a87e0ea35df8c91951" \
  -H "Content-Type: application/json" \
  -d '{
    "restaurant_location": {"latitude": 5.6037, "longitude": -0.187},
    "delivery_location": {"latitude": 5.6100, "longitude": -0.190}
  }'

# Sentiment Analysis
curl -X POST https://grabgo-ml-service.onrender.com/api/v1/analytics/sentiment \
  -H "X-API-Key: b102a6829eef4aea7b8c8f46ef6f3d9b54524ee9649d27a87e0ea35df8c91951" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "The food was amazing and delivery was super fast!"
  }'
```

---

## 🔒 Security Note

The API key is required for all endpoints (except `/health` and `/`). This is intentional to:
- ✅ Prevent unauthorized access
- ✅ Track API usage
- ✅ Protect your ML service

---

## 📊 Available Endpoints to Test

### Recommendations:
- `POST /api/v1/recommendations/food` - Get food recommendations
- `POST /api/v1/recommendations/restaurants` - Get restaurant recommendations
- `POST /api/v1/recommendations/similar-items` - Find similar items

### Predictions:
- `POST /api/v1/predictions/delivery-time` - Predict delivery ETA
- `POST /api/v1/predictions/demand` - Forecast demand
- `POST /api/v1/predictions/churn` - Predict customer churn

### Analytics:
- `POST /api/v1/analytics/sentiment` - Analyze sentiment
- `POST /api/v1/analytics/fraud-check` - Check for fraud
- `POST /api/v1/analytics/insights` - Get business insights

### Public (No Auth Required):
- `GET /health` - Health check
- `GET /` - Service info

---

## 🎯 Visual Guide

```
┌─────────────────────────────────────────┐
│  Swagger UI                             │
│  ┌───────────────────────────────────┐  │
│  │  🔒 Authorize  ← Click here!      │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Available authorizations         │  │
│  │                                   │  │
│  │  X-API-Key (apiKey)              │  │
│  │  ┌─────────────────────────────┐ │  │
│  │  │ Value:                      │ │  │
│  │  │ b102a6829eef4aea7b8c8f46... │ │  │
│  │  └─────────────────────────────┘ │  │
│  │                                   │  │
│  │  [Authorize] [Close]             │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## ✅ Summary

1. **Open**: https://grabgo-ml-service.onrender.com/docs
2. **Click**: "Authorize" button (top right)
3. **Enter**: Your API key
4. **Test**: Any endpoint you want!

**Your API is secure and working perfectly!** 🎉
