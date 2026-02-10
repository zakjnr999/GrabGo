const RiderStatus = require('../models/RiderStatus');
const OrderReservation = require('../models/OrderReservation');
const socketService = require('../services/socket_service');
const { sendToUser } = require('../services/fcm_service');

const CONFIG = {
  INACTIVITY_THRESHOLD_MS: 30 * 60 * 1000,
  CRITICAL_BATTERY_LEVEL: 5,                 
  MAX_CONSECUTIVE_TIMEOUTS: 3,               
  TIMEOUT_WINDOW_MS: 60 * 60 * 1000,         
};

async function autoOfflineInactiveRiders() {
  const cutoffTime = new Date(Date.now() - CONFIG.INACTIVITY_THRESHOLD_MS);
  
  try {
    const inactiveRiders = await RiderStatus.find({
      isOnline: true,
      isOnDelivery: false,
      lastActiveAt: { $lt: cutoffTime }
    });
    
    console.log(`🔍 [Auto-Offline] Found ${inactiveRiders.length} inactive riders`);
    
    for (const rider of inactiveRiders) {
      await setRiderOffline(rider.riderId, 'inactivity', 
        `No activity for ${Math.round(CONFIG.INACTIVITY_THRESHOLD_MS / 60000)} minutes`);
    }
    
    return inactiveRiders.length;
  } catch (error) {
    console.error('❌ [Auto-Offline] Error checking inactive riders:', error);
    return 0;
  }
}

async function autoOfflineLowBatteryRiders() {
  try {
    const lowBatteryRiders = await RiderStatus.find({
      isOnline: true,
      isOnDelivery: false,
      batteryLevel: { $lt: CONFIG.CRITICAL_BATTERY_LEVEL },
      isCharging: false
    });
    
    console.log(`🔋 [Auto-Offline] Found ${lowBatteryRiders.length} riders with critical battery`);
    
    for (const rider of lowBatteryRiders) {
      await setRiderOffline(rider.riderId, 'low_battery', 
        `Battery critically low (${rider.batteryLevel}%)`);
    }
    
    return lowBatteryRiders.length;
  } catch (error) {
    console.error('❌ [Auto-Offline] Error checking low battery riders:', error);
    return 0;
  }
}

async function autoOfflineUnresponsiveRiders() {
  const windowStart = new Date(Date.now() - CONFIG.TIMEOUT_WINDOW_MS);
  
  try {
    const unresponsiveRiders = await OrderReservation.aggregate([
      {
        $match: {
          status: 'timeout',
          createdAt: { $gte: windowStart }
        }
      },
      {
        $group: {
          _id: '$riderId',
          timeoutCount: { $sum: 1 },
          lastTimeout: { $max: '$expiresAt' }
        }
      },
      {
        $match: {
          timeoutCount: { $gte: CONFIG.MAX_CONSECUTIVE_TIMEOUTS }
        }
      }
    ]);
    
    console.log(`⏰ [Auto-Offline] Found ${unresponsiveRiders.length} unresponsive riders`);
    
    for (const result of unresponsiveRiders) {
      const status = await RiderStatus.findOne({ 
        riderId: result._id, 
        isOnline: true,
        isOnDelivery: false 
      });
      
      if (status) {
        await setRiderOffline(result._id, 'unresponsive', 
          `${result.timeoutCount} missed order reservations`);
      }
    }
    
    return unresponsiveRiders.length;
  } catch (error) {
    console.error('❌ [Auto-Offline] Error checking unresponsive riders:', error);
    return 0;
  }
}

async function setRiderOffline(riderId, reason, message) {
  try {
    await RiderStatus.findOneAndUpdate(
      { riderId },
      { 
        $set: { 
          isOnline: false, 
          lastActiveAt: new Date(),
          autoOfflineReason: reason,
          autoOfflineAt: new Date()
        } 
      }
    );
    
    console.log(`🔴 [Auto-Offline] Rider ${riderId} set offline: ${reason}`);
    
    try {
      socketService.emitToRider(riderId, 'rider:auto_offline', {
        reason,
        message,
        timestamp: new Date().toISOString()
      });
    } catch (e) {
      console.log(`⚠️ Could not send socket notification: ${e.message}`);
    }
    
    try {
      await sendToUser(riderId, {
        title: "You've been set offline",
        body: message,
        data: {
          type: 'auto_offline',
          reason,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
      });
    } catch (e) {
      console.error(`Failed to send FCM for auto-offline: ${e.message}`);
    }
    
  } catch (error) {
    console.error(`❌ [Auto-Offline] Error setting rider ${riderId} offline:`, error);
  }
}

async function runAutoOfflineJob() {
  console.log('🤖 [Auto-Offline Job] Starting...');
  
  const inactiveCount = await autoOfflineInactiveRiders();
  const lowBatteryCount = await autoOfflineLowBatteryRiders();
  const unresponsiveCount = await autoOfflineUnresponsiveRiders();
  
  const totalOfflined = inactiveCount + lowBatteryCount + unresponsiveCount;
  console.log(`✅ [Auto-Offline Job] Complete. Set ${totalOfflined} riders offline.`);
  
  return {
    inactive: inactiveCount,
    lowBattery: lowBatteryCount,
    unresponsive: unresponsiveCount,
    total: totalOfflined
  };
}

module.exports = {
  runAutoOfflineJob,
  autoOfflineInactiveRiders,
  autoOfflineLowBatteryRiders,
  autoOfflineUnresponsiveRiders,
  setRiderOffline,
  CONFIG
};
