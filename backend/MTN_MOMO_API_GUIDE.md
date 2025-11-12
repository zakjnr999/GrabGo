# MTN MOMO Payment Integration Guide

## Overview
This guide explains how to implement MTN MOMO payments in the GrabGo app for Ghana customers.

## Setup Requirements

### 1. MTN MOMO Developer Account
- Register at [MTN MOMO Developer Portal](https://momodeveloper.mtn.com/)
- Subscribe to the Collections API
- Get your API credentials

### 2. Environment Variables
Add these to your `.env` file:

```bash
# MTN MOMO Configuration
MTN_MOMO_BASE_URL=https://sandbox.momodeveloper.mtn.com
MTN_MOMO_SUBSCRIPTION_KEY=your_subscription_key_here
MTN_MOMO_API_KEY=your_api_key_here
MTN_MOMO_API_USER=your_api_user_here
MTN_MOMO_TARGET_ENVIRONMENT=sandbox

# For production
# MTN_MOMO_BASE_URL=https://momodeveloper.mtn.com
# MTN_MOMO_TARGET_ENVIRONMENT=mtncameroon
```

## API Endpoints

### 1. Initiate Payment
**POST** `/api/payments/mtn-momo/initiate`

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "orderId": "64f8a1b2c3d4e5f6789012ab",
  "phoneNumber": "+233501234567"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Payment request initiated successfully",
  "data": {
    "paymentId": "64f8a1b2c3d4e5f6789012cd",
    "referenceId": "PAY-1699123456789-1234",
    "externalReferenceId": "550e8400-e29b-41d4-a716-446655440000",
    "status": "processing",
    "amount": 25.50,
    "currency": "GHS",
    "phoneNumber": "233501234567"
  }
}
```

### 2. Check Payment Status
**GET** `/api/payments/mtn-momo/status/:paymentId`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Payment completed successfully",
  "data": {
    "paymentId": "64f8a1b2c3d4e5f6789012cd",
    "status": "successful",
    "amount": 25.50,
    "currency": "GHS",
    "financialTransactionId": "1234567890",
    "completedAt": "2024-01-15T10:30:00.000Z"
  }
}
```

### 3. Get User Payments
**GET** `/api/payments/my-payments`

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)

**Headers:**
```
Authorization: Bearer <jwt_token>
```

### 4. Cancel Payment
**PUT** `/api/payments/:paymentId/cancel`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

### 5. Webhook Endpoint
**POST** `/api/payments/mtn-momo/webhook`

This endpoint receives notifications from MTN MOMO about payment status changes.

## Phone Number Format
- Accepted formats: `+233501234567`, `233501234567`, `0501234567`
- The system automatically converts to MTN MOMO required format: `233501234567`

## Payment Flow

### Frontend Integration

1. **Order Creation:**
   ```javascript
   // Create order with mtn_momo payment method
   const orderData = {
     restaurant: "restaurant_id",
     items: [...],
     deliveryAddress: {...},
     paymentMethod: "mtn_momo",
     notes: "Special instructions"
   };
   
   const response = await fetch('/api/orders', {
     method: 'POST',
     headers: {
       'Authorization': `Bearer ${token}`,
       'Content-Type': 'application/json'
     },
     body: JSON.stringify(orderData)
   });
   ```

2. **Initiate Payment:**
   ```javascript
   const paymentData = {
     orderId: order.id,
     phoneNumber: "+233501234567"
   };
   
   const paymentResponse = await fetch('/api/payments/mtn-momo/initiate', {
     method: 'POST',
     headers: {
       'Authorization': `Bearer ${token}`,
       'Content-Type': 'application/json'
     },
     body: JSON.stringify(paymentData)
   });
   ```

3. **Poll Payment Status:**
   ```javascript
   const checkPaymentStatus = async (paymentId) => {
     const response = await fetch(`/api/payments/mtn-momo/status/${paymentId}`, {
       headers: {
         'Authorization': `Bearer ${token}`
       }
     });
     return response.json();
   };
   
   // Poll every 3 seconds for up to 5 minutes
   const pollPayment = (paymentId) => {
     const maxAttempts = 100; // 5 minutes / 3 seconds
     let attempts = 0;
   
     const poll = setInterval(async () => {
       attempts++;
       const result = await checkPaymentStatus(paymentId);
       
       if (result.data.status === 'successful') {
         clearInterval(poll);
         // Handle successful payment
         showSuccessMessage();
         redirectToOrderTracking();
       } else if (result.data.status === 'failed' || attempts >= maxAttempts) {
         clearInterval(poll);
         // Handle failed/expired payment
         showErrorMessage();
       }
     }, 3000);
   };
   ```

## Error Handling

### Common Error Codes
- `PAYMENT_REQUEST_FAILED`: Initial payment request failed
- `PAYMENT_EXPIRED`: Payment timed out (5 minutes)
- `MTN_MOMO_FAILED`: MTN MOMO returned failure
- `INVALID_PHONE_NUMBER`: Phone number format invalid
- `INSUFFICIENT_FUNDS`: Customer doesn't have enough balance
- `NETWORK_ERROR`: Temporary network issues

### Error Response Format
```json
{
  "success": false,
  "message": "Error description",
  "error": "Detailed error message",
  "code": "ERROR_CODE"
}
```

## Testing

### Sandbox Testing
Use MTN MOMO sandbox environment with test phone numbers:
- `233XXXXXXXXX` (Any 9-digit number after 233)

### Test Scenarios
1. **Successful Payment:** Use valid phone number
2. **Failed Payment:** Use invalid phone number
3. **Timeout:** Don't complete USSD prompt within 5 minutes

## Security Considerations

1. **Environment Variables:** Store all credentials securely
2. **Input Validation:** Validate phone numbers and amounts
3. **Rate Limiting:** Implement rate limiting on payment endpoints
4. **Webhook Security:** Verify webhook authenticity (implement signature verification)

## Monitoring and Logs

Monitor these metrics:
- Payment success/failure rates
- Average payment completion time
- Failed payment reasons
- Webhook delivery success

## Production Checklist

- [ ] Update environment variables for production
- [ ] Implement webhook signature verification
- [ ] Set up monitoring and alerting
- [ ] Test with real MTN MOMO accounts
- [ ] Implement proper error tracking
- [ ] Set up automated payment reconciliation

## Support

For MTN MOMO API issues:
- Documentation: [MTN MOMO Developer Docs](https://momodeveloper.mtn.com/docs)
- Support: Contact MTN MOMO Developer Support

For implementation issues:
- Check server logs for detailed error messages
- Verify API credentials and environment configuration
- Test with MTN MOMO sandbox first