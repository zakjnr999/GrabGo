const axios = require('axios');

class MTNMomoService {
  constructor() {
    // Back to sandbox mode with mock testing support
    this.baseURL = process.env.MTN_MOMO_BASE_URL || 'https://sandbox.momodeveloper.mtn.com';
    this.subscriptionKey = process.env.MTN_MOMO_SUBSCRIPTION_KEY;
    this.apiKey = process.env.MTN_MOMO_API_KEY;
    this.apiUser = process.env.MTN_MOMO_API_USER;
    this.environment = process.env.NODE_ENV === 'production' ? 'mtncameroon' : 'sandbox';
    this.targetEnvironment = process.env.MTN_MOMO_TARGET_ENVIRONMENT || 'sandbox';
  }

  /**
   * Get access token from MTN MOMO API
   */
  async getAccessToken() {
    try {
      const response = await axios.post(
        `${this.baseURL}/collection/token/`,
        {},
        {
          headers: {
            'Ocp-Apim-Subscription-Key': this.subscriptionKey,
            'Authorization': `Basic ${Buffer.from(`${this.apiUser}:${this.apiKey}`).toString('base64')}`,
            'X-Target-Environment': this.targetEnvironment,
            'Content-Type': 'application/json'
          }
        }
      );

      return response.data.access_token;
    } catch (error) {
      console.error('MTN MOMO Get Token Error:', error.response?.data || error.message);
      throw new Error('Failed to get MTN MOMO access token');
    }
  }

  /**
   * Generate a unique reference ID for the transaction
   */
  generateReferenceId() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**
   * Request payment from customer's mobile money account
   * @param {Object} paymentData - Payment details
   * @param {string} paymentData.amount - Amount to charge
   * @param {string} paymentData.currency - Currency (GHS for Ghana)
   * @param {string} paymentData.phoneNumber - Customer's phone number
   * @param {string} paymentData.payerMessage - Message for the payer
   * @param {string} paymentData.payeeNote - Note for the payee
   * @param {string} paymentData.externalId - External reference ID
   */
  async requestToPay(paymentData) {
    try {
      // Mock payment for development testing
      if (process.env.NODE_ENV === 'development' || this.targetEnvironment === 'sandbox') {
        // Check if it's a Ghana number (for UI testing)
        const phoneNumber = paymentData.phoneNumber.replace(/[^\d]/g, '');
        if (phoneNumber.startsWith('233') && phoneNumber.length === 12) {
          console.log('🧪 MOCK PAYMENT MODE: Simulating successful payment for Ghana number');
          console.log('Payment Data:', JSON.stringify(paymentData, null, 2));
          
          // Return exact same structure as real MTN MOMO service
          return {
            success: true,
            referenceId: paymentData.externalId,
            status: 'PENDING'
          };
        }
      }
      const accessToken = await this.getAccessToken();
      const referenceId = this.generateReferenceId();

      // MTN MOMO sandbox typically uses EUR for testing, even for Ghana
      const currency = this.targetEnvironment === 'sandbox' ? 'EUR' : (paymentData.currency || 'GHS');
      
      const payload = {
        amount: paymentData.amount.toString(),
        currency: currency,
        externalId: paymentData.externalId,
        payer: {
          partyIdType: 'MSISDN',
          partyId: paymentData.phoneNumber.replace(/^\+?233/, '233') // Ensure Ghana format
        },
        payerMessage: paymentData.payerMessage || 'Payment for GrabGo order',
        payeeNote: paymentData.payeeNote || 'GrabGo food delivery payment'
      };

      const response = await axios.post(
        `${this.baseURL}/collection/v1_0/requesttopay`,
        payload,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'X-Reference-Id': referenceId,
            'X-Target-Environment': this.targetEnvironment,
            'Ocp-Apim-Subscription-Key': this.subscriptionKey,
            'Content-Type': 'application/json'
          }
        }
      );

      console.log('MTN MOMO Request Response:', response.status, response.statusText);
      console.log('MTN MOMO Payload sent:', JSON.stringify(payload, null, 2));
      
      return {
        success: true,
        referenceId: referenceId,
        status: 'PENDING'
      };
    } catch (error) {
      console.error('MTN MOMO Request Payment Error:', error.response?.data || error.message);
      
      return {
        success: false,
        error: error.response?.data?.message || error.message,
        code: error.response?.data?.code || 'PAYMENT_REQUEST_FAILED'
      };
    }
  }

  /**
   * Check the status of a payment request
   * @param {string} referenceId - The reference ID from requestToPay
   */
  async getPaymentStatus(referenceId) {
    try {
      // Mock payment status for development testing
      if (process.env.NODE_ENV === 'development' || this.targetEnvironment === 'sandbox') {
        // Handle both internal PAY- references and external references
        if (referenceId.startsWith('PAY-') || referenceId.length > 10) {
          console.log('\n🧪 MOCK PAYMENT STATUS CHECK:');
          console.log('  Reference ID:', referenceId);
          console.log('  Environment:', this.targetEnvironment);
          console.log('  NODE_ENV:', process.env.NODE_ENV);
          
          // Extract timestamp from PAY- format, or use creation time for other formats
          let paymentCreatedAt;
          if (referenceId.startsWith('PAY-')) {
            paymentCreatedAt = parseInt(referenceId.split('-')[1]);
          } else {
            // For external references, find the payment record to get creation time
            const Payment = require('../models/Payment');
            try {
              const payment = await Payment.findOne({ 
                $or: [
                  { referenceId: referenceId },
                  { externalReferenceId: referenceId }
                ]
              });
              if (payment) {
                paymentCreatedAt = payment.createdAt.getTime();
              } else {
                paymentCreatedAt = Date.now() - 15000; // Default to 15 seconds ago = successful
              }
            } catch (error) {
              paymentCreatedAt = Date.now() - 15000; // Default to successful
            }
          }
          
          const now = Date.now();
          const timeDiff = now - paymentCreatedAt;
          
          console.log('  Payment created at:', new Date(paymentCreatedAt).toLocaleString());
          console.log('  Current time:', new Date(now).toLocaleString());
          console.log('  Time difference:', timeDiff + 'ms (' + (timeDiff/1000).toFixed(1) + 's)');
          console.log('  Status will be:', timeDiff < 10000 ? 'PENDING' : 'SUCCESSFUL');
          
          if (timeDiff < 10000) { // First 10 seconds = pending
            return {
              success: true,
              status: 'PENDING', // Backend expects uppercase
              financialTransactionId: null,
              amount: 27.00,
              currency: 'EUR',
              reason: 'Payment is being processed...'
            };
          } else { // After 10 seconds = successful
            return {
              success: true,
              status: 'SUCCESSFUL', // Backend expects uppercase
              financialTransactionId: `TXN-${Date.now()}`,
              amount: 27.00,
              currency: 'EUR',
              reason: 'Payment completed successfully'
            };
          }
        }
      }
      const accessToken = await this.getAccessToken();

      const response = await axios.get(
        `${this.baseURL}/collection/v1_0/requesttopay/${referenceId}`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'X-Target-Environment': this.targetEnvironment,
            'Ocp-Apim-Subscription-Key': this.subscriptionKey
          }
        }
      );

      return {
        success: true,
        status: response.data.status,
        financialTransactionId: response.data.financialTransactionId,
        amount: response.data.amount,
        currency: response.data.currency,
        payer: response.data.payer,
        reason: response.data.reason
      };
    } catch (error) {
      console.error('MTN MOMO Get Status Error:', error.response?.data || error.message);
      
      return {
        success: false,
        error: error.response?.data?.message || error.message,
        status: 'UNKNOWN'
      };
    }
  }

  /**
   * Validate phone number format for Ghana
   * @param {string} phoneNumber - Phone number to validate
   */
  validateGhanaPhoneNumber(phoneNumber) {
    // Remove any spaces, dashes, or parentheses
    const cleaned = phoneNumber.replace(/[\s\-\(\)]/g, '');
    
    // Ghana phone number patterns
    const ghanaPatterns = [
      /^233[0-9]{9}$/,    // +233xxxxxxxxx format
      /^\+233[0-9]{9}$/,  // +233xxxxxxxxx format
      /^0[0-9]{9}$/       // 0xxxxxxxxx format (local)
    ];

    return ghanaPatterns.some(pattern => pattern.test(cleaned));
  }

  /**
   * Check if phone number is a valid sandbox test number
   * @param {string} phoneNumber - Phone number to check
   */
  isSandboxTestNumber(phoneNumber) {
    const testNumbers = ['46733123453', '46733123454', '46733123455'];
    const cleaned = phoneNumber.replace(/[^\d]/g, '');
    return testNumbers.includes(cleaned);
  }

  /**
   * Format phone number to MTN MOMO required format
   * @param {string} phoneNumber - Phone number to format
   */
  formatPhoneNumber(phoneNumber) {
    // Remove any non-digits except +
    let cleaned = phoneNumber.replace(/[^\d\+]/g, '');
    
    // For sandbox environment, keep test numbers as-is
    if (this.targetEnvironment === 'sandbox' && this.isSandboxTestNumber(cleaned)) {
      return cleaned;
    }
    
    // Handle Ghana phone number formats
    if (cleaned.startsWith('+233')) {
      return cleaned.substring(1); // Remove the + sign
    } else if (cleaned.startsWith('233')) {
      return cleaned;
    } else if (cleaned.startsWith('0')) {
      return '233' + cleaned.substring(1); // Replace leading 0 with 233
    } else {
      return '233' + cleaned; // Assume it's missing country code
    }
  }
}

module.exports = new MTNMomoService();