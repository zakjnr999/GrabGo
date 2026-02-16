#!/usr/bin/env node

require("dotenv").config();
const axios = require("axios");

const usage = `
Pickup Vendor Flow Helper

Usage:
  node scripts/pickup_vendor_flow.js --order-id <ORDER_ID> --action <accept|ready|verify|reject>

Auth options (pick one):
  --token <JWT>
  --email <EMAIL> --password <PASSWORD>

Optional:
  --base-url <URL>      Default: API_BASE_URL env or http://localhost:5000/api
  --code <OTP_CODE>     Required for --action verify
  --reason <TEXT>       Used for --action reject (default: "Rejected by vendor")
  --show-order          Fetch and print order snapshot after action

Shortcut flow:
  --accept --ready      Runs accept then ready in sequence

Examples:
  node scripts/pickup_vendor_flow.js --order-id 123 --action accept --email vendor@mail.com --password pass
  node scripts/pickup_vendor_flow.js --order-id 123 --accept --ready --token <JWT>
  node scripts/pickup_vendor_flow.js --order-id 123 --action verify --code 123456 --token <JWT>
`;

function parseArgs(argv) {
  const result = {
    action: null,
    orderId: null,
    token: null,
    email: null,
    password: null,
    baseUrl: process.env.API_BASE_URL || "http://localhost:5000/api",
    code: null,
    reason: "Rejected by vendor",
    showOrder: false,
    accept: false,
    ready: false,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];

    if (arg === "--help" || arg === "-h") {
      result.help = true;
      continue;
    }
    if (arg === "--show-order") {
      result.showOrder = true;
      continue;
    }
    if (arg === "--accept") {
      result.accept = true;
      continue;
    }
    if (arg === "--ready") {
      result.ready = true;
      continue;
    }

    if (arg === "--action" && next) {
      result.action = String(next).trim().toLowerCase();
      index += 1;
      continue;
    }
    if ((arg === "--order-id" || arg === "--orderId") && next) {
      result.orderId = next;
      index += 1;
      continue;
    }
    if (arg === "--token" && next) {
      result.token = next;
      index += 1;
      continue;
    }
    if (arg === "--email" && next) {
      result.email = next;
      index += 1;
      continue;
    }
    if (arg === "--password" && next) {
      result.password = next;
      index += 1;
      continue;
    }
    if (arg === "--base-url" && next) {
      result.baseUrl = next;
      index += 1;
      continue;
    }
    if (arg === "--code" && next) {
      result.code = next;
      index += 1;
      continue;
    }
    if (arg === "--reason" && next) {
      result.reason = next;
      index += 1;
      continue;
    }
  }

  if (result.accept && result.ready) {
    result.action = "flow";
  }

  if (result.baseUrl.endsWith("/")) {
    result.baseUrl = result.baseUrl.slice(0, -1);
  }

  return result;
}

async function login(baseUrl, email, password) {
  const response = await axios.post(
    `${baseUrl}/users/login`,
    { email, password },
    { headers: { "Content-Type": "application/json" } }
  );

  const token =
    response.data?.token ||
    response.data?.data?.token ||
    response.data?.accessToken ||
    null;

  if (!token) {
    throw new Error("Login succeeded but no token found in response");
  }

  return token;
}

async function runAction(client, action, orderId, options = {}) {
  if (action === "accept") {
    return client.post(`/orders/${orderId}/pickup/accept`);
  }

  if (action === "ready") {
    return client.put(`/orders/${orderId}/status`, { status: "ready" });
  }

  if (action === "verify") {
    if (!options.code) {
      throw new Error("Missing --code for verify action");
    }
    return client.post(`/orders/${orderId}/pickup/verify-code`, { code: options.code });
  }

  if (action === "reject") {
    return client.post(`/orders/${orderId}/pickup/reject`, {
      reason: options.reason || "Rejected by vendor",
    });
  }

  throw new Error(`Unsupported action: ${action}`);
}

async function printOrderSnapshot(client, orderId) {
  try {
    const response = await client.get(`/orders/${orderId}`);
    const order = response.data?.data;
    if (!order) {
      console.log("ℹ️ Order snapshot unavailable");
      return;
    }

    console.log("📦 Order Snapshot");
    console.log(`  ID: ${order.id}`);
    console.log(`  Number: ${order.orderNumber}`);
    console.log(`  Fulfillment: ${order.fulfillmentMode}`);
    console.log(`  Status: ${order.status}`);
    console.log(`  Payment: ${order.paymentStatus}`);
    if (order.acceptByAt) console.log(`  acceptByAt: ${order.acceptByAt}`);
    if (order.readyAt) console.log(`  readyAt: ${order.readyAt}`);
    if (order.pickupExpiresAt) console.log(`  pickupExpiresAt: ${order.pickupExpiresAt}`);
  } catch (error) {
    const status = error.response?.status;
    const message = error.response?.data?.message || error.message;
    console.log(`ℹ️ Failed to fetch order snapshot (${status || "n/a"}): ${message}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage.trim());
    process.exit(0);
  }

  if (!args.orderId) {
    console.error("❌ Missing --order-id");
    console.log(usage.trim());
    process.exit(1);
  }

  if (!args.action) {
    console.error("❌ Missing action. Use --action or --accept --ready");
    console.log(usage.trim());
    process.exit(1);
  }

  let token = args.token;
  if (!token) {
    if (!args.email || !args.password) {
      console.error("❌ Provide --token or --email + --password");
      process.exit(1);
    }
    token = await login(args.baseUrl, args.email, args.password);
    console.log("✅ Authenticated");
  }

  const client = axios.create({
    baseURL: args.baseUrl,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    timeout: 30000,
  });

  const actions = args.action === "flow" ? ["accept", "ready"] : [args.action];

  for (const action of actions) {
    try {
      const response = await runAction(client, action, args.orderId, {
        code: args.code,
        reason: args.reason,
      });
      const message = response.data?.message || "Success";
      const status = response.data?.data?.status;
      console.log(`✅ ${action.toUpperCase()}: ${message}${status ? ` (status=${status})` : ""}`);
    } catch (error) {
      const status = error.response?.status;
      const message = error.response?.data?.message || error.message;
      console.error(`❌ ${action.toUpperCase()} failed (${status || "n/a"}): ${message}`);
      process.exit(1);
    }
  }

  if (args.showOrder || args.action === "flow" || args.action === "ready") {
    await printOrderSnapshot(client, args.orderId);
  }

  if (args.action === "ready" || args.action === "flow") {
    console.log("ℹ️ OTP is sent via push + in-app notification to the customer when status becomes READY.");
  }
}

main().catch((error) => {
  console.error("❌ Script error:", error.message);
  process.exit(1);
});
