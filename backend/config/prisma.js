const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const logger = require('../utils/logger');

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is required');
}

const connectionString = process.env.DATABASE_URL.split('?')[0];

const pool = new Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false,
  },
});

const adapter = new PrismaPg(pool);

const prisma = new PrismaClient({
  adapter,
  log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
});

let prismaReady = false;
let prismaConnectPromise = null;

const ensurePrismaConnected = async () => {
  if (!prismaConnectPromise) {
    prismaConnectPromise = prisma.$connect()
      .then(() => {
        prismaReady = true;
        logger.info('postgres_connected');
      })
      .catch((error) => {
        prismaReady = false;
        prismaConnectPromise = null;
        throw error;
      });
  }

  return prismaConnectPromise;
};

const checkPrismaHealth = async () => {
  try {
    await ensurePrismaConnected();
    await prisma.$queryRaw`SELECT 1`;
    prismaReady = true;
    return true;
  } catch (error) {
    prismaReady = false;
    return false;
  }
};

const isPrismaReady = () => prismaReady;

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
  await pool.end();
});

prisma.ensurePrismaConnected = ensurePrismaConnected;
prisma.checkHealth = checkPrismaHealth;
prisma.isReady = isPrismaReady;

module.exports = prisma;
