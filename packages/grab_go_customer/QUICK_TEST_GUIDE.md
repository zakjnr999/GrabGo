# MTN MOMO Payment - Quick Test Guide

## ✅ Setup Complete!

Your MTN MOMO payment integration is now configured to use your existing environment setup from `.env.local`.

## 🛠️ Configuration Used:
- **API Base URL**: `AppConfig.apiBaseUrl` (from your .env.local)
- **Payment Endpoints**: `${AppConfig.apiBaseUrl}/payments/mtn-momo/*`
- **Order Endpoints**: `${AppConfig.apiBaseUrl}/orders`

## 🚀 How to Test:

### 1. Ensure Backend is Running
Make sure your backend server is running with the MTN MOMO endpoints we created earlier.

### 2. Test Payment Flow:
1. **Add items to cart**
2. **Go to checkout** 
3. **Select "MTN MOMO"** (should show `0536997662`)
4. **Tap "Proceed to Order Summary"**
5. **Tap "Confirm & Pay GHS XX.XX"**
6. **MTN MOMO popup should appear** 📱

### 3. Expected Popup Behavior:
```
┌─────────────────────────────────────┐
│  MTN Mobile Money    [X]            │
│  0536997662                         │
│                                     │
│     📱 (pulsing phone animation)    │
│                                     │
│  Enter Your MOMO PIN                │
│  Check your phone for USSD prompt   │
│  and enter MTN MOMO PIN             │
│                                     │
│  ████████░░ (5-min progress bar)    │
│  Time remaining: 04:58              │
│                                     │
│  Amount to Pay: GHS XX.XX           │
└─────────────────────────────────────┘
```

## 🔧 API Calls Made:
1. `POST ${AppConfig.apiBaseUrl}/orders` - Creates order
2. `POST ${AppConfig.apiBaseUrl}/payments/mtn-momo/initiate` - Starts payment
3. `GET ${AppConfig.apiBaseUrl}/payments/mtn-momo/status/:paymentId` - Polls status (every 3s)

## 🎯 Testing Checklist:

- [ ] Backend running with MTN MOMO endpoints
- [ ] `.env.local` configured with API_BASE_URL
- [ ] App builds without errors
- [ ] Can navigate to checkout
- [ ] Can select MTN MOMO payment method
- [ ] Order summary shows MTN MOMO with phone number
- [ ] Payment button triggers popup
- [ ] Popup shows correct animations and countdown
- [ ] API calls are made to correct endpoints

## 🐛 Troubleshooting:

### If popup doesn't appear:
- Check console for API errors
- Verify backend endpoints are accessible
- Check if order creation succeeded

### If API calls fail:
- Verify `AppConfig.apiBaseUrl` in debug console
- Check network connectivity
- Ensure backend has CORS configured for your app

### If phone number not showing:
- Update `_momoNumber` in `order_summary.dart` line 27

## 🔄 Next Steps:
Once popup appears correctly, you can:
1. Test with real MTN MOMO sandbox credentials
2. Update user phone number to be dynamic
3. Add proper error handling and retries
4. Connect to production MTN MOMO when ready

## 📱 User Flow:
Cart → Checkout → MTN MOMO → Order Summary → **PAY** → 📱 **POPUP** → USSD → Success!

The integration is ready for testing! 🎉