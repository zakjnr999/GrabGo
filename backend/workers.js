const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });

const cache = require('./utils/cache');
const logger = require('./utils/logger');
const connectMongoDB = require('./config/mongodb');
const { bootstrapDependencies } = require('./bootstrap/dependencies');
const { startBackgroundJobs, stopBackgroundJobs } = require('./bootstrap/background_jobs');

const startWorkers = async () => {
  await bootstrapDependencies();
  startBackgroundJobs({ io: null });
  logger.info('workers_started');
};

const shutdown = async () => {
  logger.info('workers_shutdown_started');
  try {
    stopBackgroundJobs();
    if (typeof connectMongoDB.close === 'function') {
      await connectMongoDB.close();
    }
    if (cache && typeof cache.close === 'function') {
      await cache.close();
    }
  } catch (error) {
    logger.error('workers_shutdown_error', { error });
  }

  setTimeout(() => {
    process.exit(0);
  }, 0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

module.exports = { startWorkers };

if (require.main === module) {
  startWorkers().catch((error) => {
    logger.error('workers_startup_failed', { error });
    process.exit(1);
  });
}
