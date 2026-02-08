const axios = require('axios');

const buildArkeselRequest = async ({ url, apiKey, sender, to, message, mode }) => {
  if (!url || !apiKey || !sender) {
    return {
      success: false,
      error: 'Arkesel not configured. Set ARKESEL_*_URL, ARKESEL_*_API_KEY, and ARKESEL_*_SENDER.',
    };
  }

  try {
    if ((mode || '').toLowerCase() === 'query') {
      const params = {
        action: 'send-sms',
        api_key: apiKey,
        to,
        from: sender,
        sms: message,
      };
      const response = await axios.get(url, { params, timeout: 15000 });
      return { success: true, provider: 'arkesel', data: response.data };
    }

    const response = await axios.post(
      url,
      { sender, message, recipients: [to] },
      {
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        timeout: 15000,
      }
    );

    return { success: true, provider: 'arkesel', data: response.data };
  } catch (error) {
    return {
      success: false,
      provider: 'arkesel',
      error: error.response?.data || error.message,
      status: error.response?.status,
    };
  }
};

const sendArkeselSms = async ({ to, message }) => {
  return buildArkeselRequest({
    url: process.env.ARKESEL_SMS_URL,
    apiKey: process.env.ARKESEL_SMS_API_KEY || process.env.ARKESEL_API_KEY,
    sender: process.env.ARKESEL_SMS_SENDER || process.env.ARKESEL_SENDER,
    to,
    message,
    mode: process.env.ARKESEL_SMS_MODE || 'json',
  });
};

const sendArkeselWhatsapp = async ({ to, message }) => {
  return buildArkeselRequest({
    url: process.env.ARKESEL_WHATSAPP_URL,
    apiKey: process.env.ARKESEL_WHATSAPP_API_KEY || process.env.ARKESEL_API_KEY,
    sender: process.env.ARKESEL_WHATSAPP_SENDER || process.env.ARKESEL_SENDER,
    to,
    message,
    mode: process.env.ARKESEL_WHATSAPP_MODE || 'json',
  });
};

module.exports = {
  sendArkeselSms,
  sendArkeselWhatsapp,
};
