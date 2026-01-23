package com.grabgo.customer.location

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot receiver to handle device restarts
 * 
 * Geofences are cleared when the device reboots, so this receiver
 * allows us to re-register them when the device starts up.
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Device boot completed - geofences need to be re-registered")
            
            // The app will need to re-register geofences when it next starts
            // This is typically handled by the Flutter app when it initializes
            // We can store a flag to indicate that geofences need re-registration
            
            val prefs = context.getSharedPreferences("grabgo_location_prefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("geofences_need_reregistration", true).apply()
            
            Log.d(TAG, "Set flag for geofence re-registration")
        }
    }
}
