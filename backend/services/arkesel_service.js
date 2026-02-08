const axios = require('axios');

const normalizePayload = (data) => {
  if (data === null || data === undefined) return { payload: null, raw: data };
  if (typeof data === 'string') {
    try {
      return { payload: JSON.parse(data), raw: data };
    } catch (_) {
      return { payload: { message: data }, raw: data };
    }
  }
  return { payload: data, raw: data };
};

const interpretArkeselResponse = (data) => {
  const { payload } = normalizePayload(data);
  if (!payload || typeof payload !== 'object') {
    return { success: true, message: undefined, payload };
  }

  const message = payload.message || payload.msg;
  const code = payload.code ?? payload.statusCode;
  const status = payload.status ?? payload.success;

  if (typeof status === 'boolean') {
    return { success: status, message, payload };
  }

  if (typeof status === 'string') {
    const normalized = status.toLowerCase();
    if (['success', 'ok', 'sent'].includes(normalized)) {
      return { success: true, message, payload };
    }
    if (['error', 'failed', 'fail'].includes(normalized)) {
      return { success: false, message: message || status, payload };
    }
  }

  if (code !== undefined && code !== null) {
    const codeValue = String(code).toLowerCase();
    if (codeValue === '1000' || codeValue === '200' || codeValue === 'ok') {
      return { success: true, message, payload };
    }
    return { success: false, message: message || `Provider error code ${code}`, payload };
  }

  return { success: true, message, payload };
};

const buildArkeselRequest = async ({ url, apiKey, sender, to, message, mode }) => {
  if (!url || !apiKey || !sender) {
    const message =
      'Arkesel not configured. Set ARKESEL_*_URL, ARKESEL_*_API_KEY, and ARKESEL_*_SENDER.';
    return {
      success: false,
      error: message,
      message,
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
      const interpreted = interpretArkeselResponse(response.data);
      return {
        success: interpreted.success,
        provider: 'arkesel',
        data: response.data,
        message: interpreted.message,
      };
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

    const interpreted = interpretArkeselResponse(response.data);
    return {
      success: interpreted.success,
      provider: 'arkesel',
      data: response.data,
      message: interpreted.message,
    };
  } catch (error) {
    const responseMessage =
      error.response?.data?.message ||
      error.response?.data?.msg ||
      error.response?.data?.error ||
      error.message;
    return {
      success: false,
      provider: 'arkesel',
      error: error.response?.data || error.message,
      message: responseMessage,
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
