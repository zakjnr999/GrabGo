# 🧪 Quick MTN MOMO Test Steps

## Step 1: Start the App
```bash
cd packages/grab_go_customer
flutter run
```

**Choose your device:**
- `1` for Android
- `2` for Chrome (web)
- `3` for Windows

## Step 2: Test Basic Flow

### ✅ **Navigation Test:**
1. App should launch successfully
2. Navigate to home/restaurants
3. Add some food items to cart
4. Go to cart page

### ✅ **Checkout Test:**
1. In cart, tap "Checkout" or "Proceed to Checkout"
2. **Verify:** MTN MOMO option appears in payment methods
3. **Select:** MTN MOMO payment method
4. **Verify:** Shows phone number `0536997662`
5. Tap "Proceed to Order Summary"

### ✅ **Order Summary Test:**
1. **Verify:** Order summary page shows:
   - Order items and prices
   - Delivery address
   - Payment method: "MTN MOMO 0536997662"
   - "Confirm & Pay GHS XX.XX" button

## Step 3: 🎯 **Main Test - MTN MOMO Popup**

1. **Tap:** "Confirm & Pay GHS XX.XX" button
2. **Expected:** Loading spinner appears, button shows "Processing Payment..."

### 🚨 **Critical Test Points:**

#### **A. Order Creation:**
- Should see loading for 1-2 seconds
- If backend is running: Order creation succeeds
- If backend is down: Should show error "Failed to create order"

#### **B. MTN MOMO Popup:**
If order creation succeeds, popup should appear with:
```
┌─────────────────────────────────────┐
│  MTN Mobile Money    [X]            │
│  0536997662                         │
│                                     │
│     📱 (pulsing animation)          │
│                                     │
│  Enter Your MOMO PIN                │
│  Check your phone for USSD prompt   │
│                                     │
│  ████████░░ (progress bar)          │
│  Time remaining: 04:59              │
│                                     │
│  Amount to Pay: GHS XX.XX           │
└─────────────────────────────────────┘
```

## Step 4: 🔍 **Verify Integration Works**

### ✅ **Success Indicators:**
- [ ] No compilation errors
- [ ] MTN MOMO popup appears
- [ ] Animations work (pulsing phone icon)
- [ ] Countdown timer works (5:00 → 4:59 → 4:58...)
- [ ] Progress bar animates
- [ ] Amount displays correctly
- [ ] Cancel button works

### ⚠️ **Expected in Sandbox:**
- Payment will likely timeout after 5 minutes
- This is **NORMAL** - means integration is working!
- Real MTN MOMO needs production credentials

## Step 5: 📱 **Check Console Logs**

In terminal, look for:
```
✅ Chopper: POST /orders
✅ Chopper: POST /payments/mtn-momo/initiate  
✅ Chopper: GET /payments/mtn-momo/status/:id
✅ Status polling every 3 seconds
```

## 🎯 **Test Results:**

### ✅ **PASS - Integration Working:**
- MTN MOMO popup appears
- Animations work correctly
- API calls made to backend
- No crash or errors

### ❌ **FAIL - Need to Fix:**
- Compilation errors
- Popup doesn't appear
- App crashes when tapping pay button
- Network errors in console

---

## 🚀 **Quick Test Commands:**

```bash
# Test the app
cd packages/grab_go_customer
flutter run

# Watch for errors
flutter logs
```

**Start with Step 1 and let me know what happens at each step!** 📱

The main goal is to see the beautiful MTN MOMO popup appear when you tap "Confirm & Pay" - that confirms the integration is working! 🎉