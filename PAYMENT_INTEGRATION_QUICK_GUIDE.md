# GrabGo Payment Integration - Quick Developer Guide

## 🚀 Quick Setup

### Environment Variables (.env)
```env
# MTN MOMO (Required)
MTN_MOMO_BASE_URL=https://sandbox.momodeveloper.mtn.com
MTN_MOMO_SUBSCRIPTION_KEY=your_subscription_key
MTN_MOMO_API_KEY=your_api_key
MTN_MOMO_API_USER=your_api_user_id
MTN_MOMO_TARGET_ENVIRONMENT=sandbox

# Database
MONGODB_URI=mongodb://localhost:27017/grabgo

# JWT
JWT_SECRET=your_jwt_secret
```

### Quick Test Commands
```bash
# 1. Start backend
cd backend && npm start

# 2. Test order creation
curl -X POST http://localhost:5000/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"orderNumber":"ORD-$(date +%s)-1234","restaurant":"RESTAURANT_ID","items":[{"food":"FOOD_ID","quantity":2,"price":15.99}],"deliveryAddress":{"street":"Test St","city":"Accra"},"paymentMethod":"mtn_momo"}'

# 3. Test MTN MOMO payment
curl -X POST http://localhost:5000/api/payments/mtn-momo/initiate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"orderId":"ORDER_ID","phoneNumber":"46733123453"}'
```

## 📱 Frontend Integration

### 1. Order Creation
```dart
// Use this service for all order operations
final orderService = OrderServiceWrapper();

final orderId = await orderService.createOrder(
  cartItems: cart.cartItems,
  deliveryAddress: selectedAddress,
  paymentMethod: "MTN MOMO", // Will be converted to "mtn_momo"
  subtotal: subtotal,
  deliveryFee: deliveryFee,
  total: total,
);
```

### 2. MTN MOMO Payment
```dart
// Show payment dialog
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => MtnMomoPaymentDialog(
    orderId: orderId,
    totalAmount: total,
    phoneNumber: userPhoneNumber,
    onPaymentSuccess: () => handleSuccess(),
    onPaymentFailed: () => handleFailure(),
  ),
);
```

## 🔧 Backend Integration

### 1. Order Model Usage
```javascript
// ✅ CORRECT: Include orderNumber
const order = await Order.create({
  orderNumber,  // CRITICAL: Must be included
  customer: req.user._id,
  restaurant: restaurantId,
  items: orderItems,
  // ... other fields
});

// ❌ WRONG: Missing orderNumber (will cause validation error)
const order = await Order.create({
  customer: req.user._id,
  restaurant: restaurantId,
  // ... missing orderNumber
});
```

### 2. MTN MOMO Service Usage
```javascript
const mtnMomoService = require('../services/mtn_momo_service');

// Initiate payment
const paymentRequest = await mtnMomoService.requestToPay({
  amount: order.totalAmount,
  currency: 'GHS',
  phoneNumber: formattedPhoneNumber,
  externalId: payment.referenceId,
  payerMessage: `Payment for GrabGo order ${order.orderNumber}`,
  payeeNote: 'GrabGo food delivery payment'
});

// Check status
const status = await mtnMomoService.getPaymentStatus(referenceId);
```

## 🧪 Testing Scenarios

### MTN MOMO Sandbox Test Numbers
| Phone Number | Expected Result |
|--------------|-----------------|
| 46733123453 | ✅ Successful payment |
| 46733123454 | ❌ Failed payment |
| 46733123455 | ⏱️ Timeout |

### Test Flow
1. **Create Order** → Should return orderId without errors
2. **Initiate Payment** → Should return paymentId and referenceId
3. **Check Status** → Should show payment progression
4. **Complete Payment** → Should update order status

## 🔍 Common Issues & Quick Fixes

### Issue: "orderNumber Path required"
```bash
✅ FIXED: The orderNumber is now properly included in backend order creation
```

### Issue: Phone Number Format Error
```javascript
// ✅ Use the built-in formatter
const formatted = mtnMomoService.formatPhoneNumber(phoneNumber);
// Converts: "0536997662" → "233536997662"
// Converts: "+233536997662" → "233536997662"
```

### Issue: Payment Stuck in Processing
```dart
// ✅ Implement timeout in frontend
Timer(Duration(minutes: 5), () {
  if (_status == PaymentStatus.processing) {
    setState(() => _status = PaymentStatus.timeout);
  }
});
```

## 📊 Payment Status Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   pending   │───▶│ processing  │───▶│ successful  │
└─────────────┘    └─────────────┘    └─────────────┘
                          │                   │
                          ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐
                   │   failed    │    │ Order Ready │
                   └─────────────┘    └─────────────┘
```

## 🛡️ Security Checklist

- ✅ All payment endpoints require authentication
- ✅ Phone numbers are validated and formatted
- ✅ Order ownership is verified before payment
- ✅ Payment reference IDs are unique and secure
- ✅ Sensitive MTN MOMO credentials in environment variables
- ✅ Input validation on all endpoints
- ✅ Rate limiting on payment attempts

## 🚨 Monitoring & Alerts

### Key Metrics to Monitor
- Order creation success rate
- Payment success rate
- MTN MOMO API response times
- Payment timeout frequency
- Error rates by type

### Log Examples
```javascript
// Success
console.log('Payment completed:', { 
  orderId, 
  paymentId, 
  amount, 
  duration: Date.now() - startTime 
});

// Failure
console.error('Payment failed:', { 
  orderId, 
  error: errorMessage, 
  phoneNumber: masked(phoneNumber) 
});
```

## 📞 Support Contacts

- **MTN MOMO Developer Support**: [MTN Developer Portal](https://momodeveloper.mtn.com/)
- **Technical Issues**: Check logs in `/backend/logs/`
- **Payment Disputes**: Refer to MTN MOMO transaction IDs

---

## 🎯 Next Steps

1. **Production Setup**:
   - Update MTN MOMO URLs to production
   - Set up monitoring and alerting
   - Configure rate limiting
   - Set up log aggregation

2. **Additional Features**:
   - Implement Vodafone Cash
   - Add payment history
   - Implement refunds
   - Add payment analytics

3. **Performance Optimization**:
   - Cache MTN MOMO access tokens
   - Optimize payment status polling
   - Implement webhook handlers
   - Add payment retry logic

---

*Last updated: November 2024*