const axios = require("axios");

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

module.exports = {
  initializeTransaction,
  PAYSTACK_CALLBACK_URL,
};
