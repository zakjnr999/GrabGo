const axios = require("axios");
const crypto = require("crypto");

const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;
const PAYSTACK_BASE_URL = process.env.PAYSTACK_BASE_URL || "https://api.paystack.co";
const PAYSTACK_CALLBACK_URL = process.env.PAYSTACK_CALLBACK_URL || "https://standard.paystack.co/close";
const PAYSTACK_CURRENCY = process.env.PAYSTACK_CURRENCY || "GHS";

const paystackClient = axios.create({
  baseURL: PAYSTACK_BASE_URL,
  headers: {
    Authorization: `Bearer ${PAYSTACK_SECRET_KEY || ""}`,
    "Content-Type": "application/json",
  },
});

const ensureConfigured = () => {
  if (!PAYSTACK_SECRET_KEY) {
    throw new Error("Paystack secret key not configured");
  }
};

const initializeTransaction = async ({ email, amount, reference, metadata }) => {
  ensureConfigured();

  const payload = {
    email,
    amount,
    reference,
    currency: PAYSTACK_CURRENCY,
    callback_url: PAYSTACK_CALLBACK_URL,
    metadata,
  };

  const response = await paystackClient.post("/transaction/initialize", payload);
  const data = response?.data;

  if (!data?.status) {
    throw new Error(data?.message || "Paystack initialization failed");
  }

  return data.data;
};

const verifyTransaction = async (reference) => {
  ensureConfigured();

  const response = await paystackClient.get(`/transaction/verify/${reference}`);
  const data = response?.data;

  if (!data?.status) {
    throw new Error(data?.message || "Paystack verification failed");
  }

  return data.data;
};

const verifyWebhookSignature = (rawBody, signatureHeader) => {
  if (!PAYSTACK_SECRET_KEY) return false;
  if (!signatureHeader) return false;

  const payloadBuffer = Buffer.isBuffer(rawBody)
    ? rawBody
    : Buffer.from(typeof rawBody === 'string' ? rawBody : JSON.stringify(rawBody || {}));

  const expected = crypto
    .createHmac('sha512', PAYSTACK_SECRET_KEY)
    .update(payloadBuffer)
    .digest('hex');

  const provided = String(signatureHeader || '').trim();
  if (!provided) return false;

  const expectedBuffer = Buffer.from(expected, 'utf8');
  const providedBuffer = Buffer.from(provided, 'utf8');
  if (expectedBuffer.length !== providedBuffer.length) return false;
  return crypto.timingSafeEqual(expectedBuffer, providedBuffer);
};

const extractWebhookReference = (payload) =>
  payload?.data?.reference ||
  payload?.data?.tx_ref ||
  payload?.reference ||
  null;

const extractWebhookEventId = (payload) =>
  payload?.event_id ||
  payload?.data?.id?.toString?.() ||
  `${payload?.event || 'paystack_event'}:${extractWebhookReference(payload) || 'unknown'}`;

module.exports = {
  initializeTransaction,
  verifyTransaction,
  verifyWebhookSignature,
  extractWebhookReference,
  extractWebhookEventId,
  PAYSTACK_CALLBACK_URL,
};
