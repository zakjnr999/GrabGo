#!/usr/bin/env node

const path = require("path");
const bcrypt = require("bcryptjs");

require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

const prisma = require("../config/prisma");

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PASSWORD_LENGTH = 6;

const parseCliArgs = () => {
  const [, , emailArg, passwordArg] = process.argv;
  const email = (emailArg || "").trim().toLowerCase();
  const password = (passwordArg || "").trim();

  if (!email || !password) {
    throw new Error(
      "Usage: node scripts/create_rider_account.js <email> <password>\n" +
        "Example: node scripts/create_rider_account.js rider.demo@grabgo.com DemoPass123"
    );
  }

  if (!EMAIL_REGEX.test(email)) {
    throw new Error("Invalid email format.");
  }

  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new Error(`Password must be at least ${MIN_PASSWORD_LENGTH} characters.`);
  }

  return { email, password };
};

const normalizeBaseUsername = (email) => {
  const localPart = email.split("@")[0] || "rider";
  const normalized = localPart
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");

  return normalized || "rider";
};

const generateUniqueUsername = async (email) => {
  const base = normalizeBaseUsername(email);
  const baseCandidate = `${base}_rider`;

  const existingBase = await prisma.user.findUnique({
    where: { username: baseCandidate },
    select: { id: true },
  });
  if (!existingBase) return baseCandidate;

  for (let i = 0; i < 20; i += 1) {
    const suffix = Math.floor(Math.random() * 9000 + 1000);
    const candidate = `${base}_rider_${suffix}`;
    const taken = await prisma.user.findUnique({
      where: { username: candidate },
      select: { id: true },
    });
    if (!taken) return candidate;
  }

  return `${base}_rider_${Date.now().toString().slice(-6)}`;
};

const ensureRiderProfile = async (userId) => {
  const now = new Date();
  const dummyData = {
    vehicleType: "motorcycle",
    licensePlateNumber: "GRB-0000-26",
    vehicleBrand: "Yamaha",
    vehicleModel: "YBR125",
    nationalIdType: "national_id",
    nationalIdNumber: `GG-${Date.now().toString().slice(-8)}`,
    paymentMethod: "mobile_money",
    mobileMoneyProvider: "mtn",
    mobileMoneyNumber: "233200000000",
    verificationStatus: "approved",
    verifiedAt: now,
    agreedToTerms: true,
    agreedToLocationAccess: true,
    agreedToAccuracy: true,
    notes: "Auto-created dummy rider profile via script",
  };

  const existingRider = await prisma.rider.findUnique({
    where: { userId },
    select: { id: true },
  });

  if (!existingRider) {
    await prisma.rider.create({
      data: {
        userId,
        ...dummyData,
      },
    });
    return "created";
  }

  await prisma.rider.update({
    where: { userId },
    data: {
      verificationStatus: "approved",
      verifiedAt: now,
      agreedToTerms: true,
      agreedToLocationAccess: true,
      agreedToAccuracy: true,
      // Keep existing rider payload mostly intact; only enforce fields needed for demo readiness.
      vehicleType: dummyData.vehicleType,
      paymentMethod: dummyData.paymentMethod,
      mobileMoneyProvider: dummyData.mobileMoneyProvider,
      mobileMoneyNumber: dummyData.mobileMoneyNumber,
      notes: "Updated by create_rider_account script",
    },
  });
  return "updated";
};

const ensureRiderWallet = async (userId) => {
  const existingWallet = await prisma.riderWallet.findUnique({
    where: { userId },
    select: { id: true },
  });

  if (existingWallet) return "exists";

  await prisma.riderWallet.create({
    data: {
      userId,
      balance: 0,
      totalEarnings: 0,
      totalWithdrawals: 0,
      pendingWithdrawals: 0,
    },
  });
  return "created";
};

async function main() {
  const { email, password } = parseCliArgs();
  const hashedPassword = await bcrypt.hash(password, 10);

  const existingUser = await prisma.user.findUnique({
    where: { email },
    select: {
      id: true,
      email: true,
      username: true,
      role: true,
      isActive: true,
      isEmailVerified: true,
    },
  });

  let userId;
  let userAction;

  if (!existingUser) {
    const username = await generateUniqueUsername(email);
    const user = await prisma.user.create({
      data: {
        username,
        email,
        password: hashedPassword,
        role: "rider",
        isActive: true,
        isEmailVerified: true,
        isPhoneVerified: false,
      },
      select: { id: true, username: true, email: true, role: true },
    });
    userId = user.id;
    userAction = `Created new user (${user.username})`;
  } else {
    const updateData = {
      password: hashedPassword,
      role: "rider",
      isActive: true,
      isEmailVerified: true,
    };

    const user = await prisma.user.update({
      where: { id: existingUser.id },
      data: updateData,
      select: { id: true, username: true, email: true, role: true },
    });

    userId = user.id;
    userAction = `Updated existing user (${user.username})`;
  }

  const riderProfileAction = await ensureRiderProfile(userId);
  const riderWalletAction = await ensureRiderWallet(userId);

  console.log("Rider account is ready.");
  console.log("--------------------------------");
  console.log(`Email: ${email}`);
  console.log(`Password: ${password}`);
  console.log(`User action: ${userAction}`);
  console.log(`Rider profile: ${riderProfileAction}`);
  console.log(`Rider wallet: ${riderWalletAction}`);
  console.log("Verification: approved");
  console.log("--------------------------------");
  console.log("Next step: log into rider app and tap Go Online.");
}

main()
  .catch((error) => {
    console.error("Failed to create rider account:");
    console.error(error.message || error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
