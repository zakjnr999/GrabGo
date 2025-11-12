# MTN MOMO Deployment Guide

## 🚀 Deployment Steps Required

### 1. **Backend Deployment (Render)**

#### **A. Add Environment Variables to Render:**
Go to your Render dashboard → Your backend service → Environment tab and add:

```bash
# MTN MOMO Configuration
MTN_MOMO_BASE_URL=https://sandbox.momodeveloper.mtn.com
MTN_MOMO_SUBSCRIPTION_KEY=your_mtn_momo_subscription_key
MTN_MOMO_API_KEY=your_mtn_momo_api_key
MTN_MOMO_API_USER=your_mtn_momo_api_user
MTN_MOMO_TARGET_ENVIRONMENT=sandbox

# For production, change to:
# MTN_MOMO_BASE_URL=https://momodeveloper.mtn.com
# MTN_MOMO_TARGET_ENVIRONMENT=mtncameroon
```

#### **B. Push Backend Code to GitHub:**
```bash
# In your project root
git add .
git commit -m "Add MTN MOMO payment integration"
git push origin main
```

#### **C. Render Auto-Deploy:**
- Render will automatically detect the changes
- It will redeploy with the new MTN MOMO endpoints
- Check deployment logs for any errors

### 2. **Frontend Configuration**

#### **A. Update API Base URL (if needed):**
Make sure your `.env.local` has the correct API URL:
```bash
# In your .env.local
API_BASE_URL=https://your-backend-url.onrender.com/api
```

#### **B. No Frontend Deployment Needed:**
- Flutter app runs locally
- It will call your updated backend on Render
- No need to deploy the Flutter app separately

### 3. **Testing Checklist**

#### **After Backend Deployment:**
- [ ] Check Render deployment logs - no errors
- [ ] Verify new endpoints are accessible:
  - `GET https://your-backend.onrender.com/api/payments` (should return 404 but not crash)
  - Backend logs show MTN MOMO service loaded

#### **Frontend Testing:**
- [ ] `flutter run` - app compiles successfully
- [ ] Navigate to payment flow
- [ ] MTN MOMO popup appears
- [ ] Console shows API calls to your Render backend

## 🔧 **Required Steps Summary:**

### **Backend (Render):**
1. ✅ **Add MTN MOMO environment variables** to Render
2. ✅ **Push code to GitHub** (includes MTN MOMO endpoints)
3. ✅ **Wait for auto-deployment** to complete

### **Frontend (Local):**
1. ✅ **Ensure .env.local** has correct API_BASE_URL
2. ✅ **Run `flutter run`** to test locally

## 🌐 **Environment Variables Needed:**

### **For Render Dashboard:**
```
MTN_MOMO_SUBSCRIPTION_KEY = your_subscription_key_here
MTN_MOMO_API_KEY = your_api_key_here  
MTN_MOMO_API_USER = your_api_user_here
MTN_MOMO_BASE_URL = https://sandbox.momodeveloper.mtn.com
MTN_MOMO_TARGET_ENVIRONMENT = sandbox
```

### **For Local .env.local:**
```
API_BASE_URL = https://your-backend-name.onrender.com/api
```

## 🚨 **Important Notes:**

### **MTN MOMO Credentials:**
- Get these from [MTN MOMO Developer Portal](https://momodeveloper.mtn.com/)
- Start with sandbox credentials for testing
- Switch to production credentials when ready

### **Backend Endpoints Added:**
- `POST /api/payments/mtn-momo/initiate`
- `GET /api/payments/mtn-momo/status/:paymentId`
- `PUT /api/payments/:paymentId/cancel`
- `POST /api/payments/mtn-momo/webhook`
- `POST /api/orders` (updated to support MTN MOMO)

### **Testing Flow:**
1. Deploy backend with MTN MOMO endpoints ✅
2. Add environment variables to Render ✅  
3. Test frontend locally ✅
4. Verify API calls reach your backend ✅

## 🎯 **Next Steps:**

1. **Add env vars to Render** 
2. **Push code to GitHub**
3. **Wait for deployment** 
4. **Test MTN MOMO popup** locally

The frontend will automatically use your deployed backend with the new MTN MOMO endpoints! 🚀