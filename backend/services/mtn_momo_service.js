const axios = require('axios');

class MTNMomoService {
  constructor() {
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
      const accessToken = await this.getAccessToken();
      const referenceId = this.generateReferenceId();

      const payload = {
        amount: paymentData.amount.toString(),
        currency: paymentData.currency || 'GHS',
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
   * Format phone number to MTN MOMO required format
   * @param {string} phoneNumber - Phone number to format
   */
  formatPhoneNumber(phoneNumber) {
    // Remove any non-digits except +
    let cleaned = phoneNumber.replace(/[^\d\+]/g, '');
    
    // Handle different formats
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