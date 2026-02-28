#!/usr/bin/env node

/**
 * Test/update food customization config for any food item.
 *
 * Examples:
 *   npm run test:food-customization -- \
 *     --base-url https://grabgo-backend.onrender.com \
 *     --food-id cmktlc9dw005usat21w8aw2y4 \
 *     --token YOUR_JWT \
 *     --file scripts/food_customization_payload.sample.json
 *
 *   npm run test:food-customization -- \
 *     --food-id cmktlc9dw005usat21w8aw2y4 \
 *     --email zakjnr5@gmail.com \
 *     --password 'your-password' \
 *     --payload '{"portionOptions":[{"id":"small","label":"Small","price":22,"isDefault":true,"isActive":true}],"preferenceGroups":[{"id":"protein","label":"Choose Protein","required":true,"minSelections":1,"maxSelections":1,"options":[{"id":"fish","label":"Fish","priceDelta":6,"isActive":true}]}]}'
 */

require("dotenv").config();
const fs = require("fs");
const path = require("path");
const axios = require("axios");

const parseArgs = (argv) => {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;

    const clean = token.slice(2);
    if (!clean) continue;

    if (clean.includes("=")) {
      const [rawKey, ...rest] = clean.split("=");
      args[rawKey] = rest.join("=");
      continue;
    }

    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      args[clean] = true;
      continue;
    }

    args[clean] = next;
    i += 1;
  }
  return args;
};

const usage = () => {
  console.log(`
Usage:
  node scripts/test_food_customization.js --food-id <id> [options]

Options:
  --base-url <url>      API origin (default: GRABGO_API_BASE_URL or http://localhost:5000)
  --food-id <id>        Target food ID (required)
  --token <jwt>         Bearer token (preferred in CI/testing)
  --email <email>       Login email (if token not provided)
  --password <pass>     Login password (if token not provided)
  --file <path>         JSON file containing update body
  --payload <json>      Inline JSON update body
  --print-only          Print request and payload only (no API call)
  --skip-before         Skip fetching current food before update
  --skip-after          Skip fetching updated food after update
  --help                Show this help

Payload format:
  {
    "portionOptions": [...],      // optional (null to clear)
    "preferenceGroups": [...]     // optional (null to clear)
  }
`);
};

const normalizeApiBase = (rawBase) => {
  const base = String(rawBase || "").trim().replace(/\/+$/, "");
  if (!base) return "http://localhost:5000/api";
  if (base.endsWith("/api")) return base;
  return `${base}/api`;
};

const readJsonFile = (filePath) => {
  const absolutePath = path.isAbsolute(filePath)
    ? filePath
    : path.resolve(process.cwd(), filePath);

  const content = fs.readFileSync(absolutePath, "utf8");
  try {
    return JSON.parse(content);
  } catch (error) {
    throw new Error(`Failed to parse JSON file '${absolutePath}': ${error.message}`);
  }
};

const parseJsonString = (value, flagName) => {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`Invalid JSON for ${flagName}: ${error.message}`);
  }
};

const resolveUpdateBody = (args) => {
  if (args.file && args.payload) {
    throw new Error("Use either --file or --payload, not both");
  }

  let body;
  if (args.file) {
    body = readJsonFile(args.file);
  } else if (args.payload) {
    body = parseJsonString(args.payload, "--payload");
  } else {
    body = {
      portionOptions: [
        {
          id: "small",
          label: "Small",
          price: 22,
          isDefault: true,
          isActive: true,
        },
        {
          id: "medium",
          label: "Medium",
          price: 30,
          isActive: true,
        },
      ],
      preferenceGroups: [
        {
          id: "protein",
          label: "Choose Protein",
          required: false,
          minSelections: 0,
          maxSelections: 3,
          options: [
            {
              id: "fish",
              label: "Fish",
              priceDelta: 0,
              isActive: true,
              sizeOptions: [
                { id: "small", label: "Small", priceDelta: 4, isActive: true },
                { id: "medium", label: "Medium", priceDelta: 6, isActive: true, isDefault: true },
                { id: "large", label: "Large", priceDelta: 9, isActive: true },
              ],
            },
            { id: "chicken", label: "Chicken", priceDelta: 4, isActive: true },
          ],
        },
      ],
    };
  }

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("Update body must be a JSON object");
  }

  return body;
};

const pickToken = (loginResponseData) => {
  if (!loginResponseData || typeof loginResponseData !== "object") return null;
  if (typeof loginResponseData.token === "string" && loginResponseData.token.trim()) {
    return loginResponseData.token.trim();
  }
  if (
    loginResponseData.data &&
    typeof loginResponseData.data.token === "string" &&
    loginResponseData.data.token.trim()
  ) {
    return loginResponseData.data.token.trim();
  }
  return null;
};

const maskToken = (token) => {
  if (!token || token.length < 16) return "***";
  return `${token.slice(0, 10)}...${token.slice(-6)}`;
};

const printFoodSnapshot = (food) => {
  if (!food || typeof food !== "object") {
    console.log("  (no food snapshot)");
    return;
  }

  const name = food.name || "-";
  const price = typeof food.price === "number" ? food.price : "-";
  const portions = Array.isArray(food.portionOptions) ? food.portionOptions.length : 0;
  const groups = Array.isArray(food.preferenceGroups) ? food.preferenceGroups.length : 0;

  console.log(`  name: ${name}`);
  console.log(`  price: ${price}`);
  console.log(`  portionOptions: ${portions}`);
  console.log(`  preferenceGroups: ${groups}`);
};

const run = async () => {
  const args = parseArgs(process.argv);
  if (args.help) {
    usage();
    process.exit(0);
  }

  const foodId = String(args["food-id"] || args.foodId || args.id || "").trim();
  if (!foodId) {
    usage();
    throw new Error("Missing required --food-id");
  }

  const apiBase = normalizeApiBase(
    args["base-url"] || args.baseUrl || process.env.GRABGO_API_BASE_URL || "http://localhost:5000"
  );
  const updateBody = resolveUpdateBody(args);
  const updateUrl = `${apiBase}/foods/${foodId}`;
  const beforeUrl = `${apiBase}/foods/${foodId}`;

  console.log("\n[food-customization-test] Request setup");
  console.log(`  apiBase: ${apiBase}`);
  console.log(`  foodId: ${foodId}`);
  console.log(`  endpoint: PUT ${updateUrl}`);
  console.log("  payload:");
  console.log(JSON.stringify(updateBody, null, 2));

  if (args["print-only"]) {
    console.log("\n[food-customization-test] print-only mode; no API request sent.");
    return;
  }

  let token = String(args.token || process.env.GRABGO_AUTH_TOKEN || "").trim();
  if (!token) {
    const email = String(args.email || process.env.GRABGO_EMAIL || "").trim();
    const password = String(args.password || process.env.GRABGO_PASSWORD || "").trim();
    if (!email || !password) {
      throw new Error("Provide --token, or provide --email and --password");
    }

    const loginUrl = `${apiBase}/users/login`;
    console.log(`\n[food-customization-test] Logging in via ${loginUrl} ...`);
    const loginResponse = await axios.post(
      loginUrl,
      { email, password },
      { headers: { "Content-Type": "application/json" }, timeout: 30000 }
    );

    token = pickToken(loginResponse.data);
    if (!token) {
      throw new Error("Login succeeded but token was not found in response payload");
    }
  }

  console.log(`[food-customization-test] Using token: ${maskToken(token)}`);

  const headers = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };

  if (!args["skip-before"]) {
    console.log(`\n[food-customization-test] Fetching current food: GET ${beforeUrl}`);
    const beforeResponse = await axios.get(beforeUrl, { headers, timeout: 30000 });
    printFoodSnapshot(beforeResponse.data?.data || beforeResponse.data?.food || beforeResponse.data);
  }

  console.log(`\n[food-customization-test] Updating food customization...`);
  const updateResponse = await axios.put(updateUrl, updateBody, { headers, timeout: 30000 });
  console.log("[food-customization-test] Update response:");
  console.log(`  success: ${updateResponse.data?.success}`);
  if (updateResponse.data?.message) {
    console.log(`  message: ${updateResponse.data.message}`);
  }

  if (!args["skip-after"]) {
    console.log(`\n[food-customization-test] Fetching updated food: GET ${beforeUrl}`);
    const afterResponse = await axios.get(beforeUrl, { headers, timeout: 30000 });
    printFoodSnapshot(afterResponse.data?.data || afterResponse.data?.food || afterResponse.data);
  }

  console.log("\n[food-customization-test] Completed successfully.");
};

run().catch((error) => {
  const status = error.response?.status;
  const payload = error.response?.data;
  console.error("\n[food-customization-test] Failed.");
  if (status) {
    console.error(`  status: ${status}`);
  }
  if (payload) {
    console.error("  response:");
    console.error(JSON.stringify(payload, null, 2));
  } else {
    console.error(`  error: ${error.message}`);
  }
  process.exit(1);
});
