const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
require('dotenv').config();

// Create PostgreSQL connection pool with SSL settings for Supabase
// We strip query params from the connection string to avoid conflicts with the manual ssl object
const connectionString = process.env.DATABASE_URL.split('?')[0];

const pool = new Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false,
  },
});

// Create Prisma adapter
const adapter = new PrismaPg(pool);

// Create a single instance of PrismaClient with the adapter
const prisma = new PrismaClient({
  adapter,
  log: process.env.NODE_ENV === 'development' ? ['query', 'info', 'warn', 'error'] : ['error'],
});

// Connection event handlers
prisma.$connect()
  .then(() => {
    console.log('✅ PostgreSQL Connected via Prisma (with Driver Adapter)');
  })
  .catch((error) => {
    console.error('❌ PostgreSQL Connection Error:', error);
  });

// Graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
  await pool.end();
});

module.exports = prisma;
