package com.grabgo.customer.location

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent

/**
 * BroadcastReceiver for handling geofence transition events
 * 
 * This receiver is triggered when the user enters, exits, or dwells in a geofence.
 * Events are forwarded to Flutter via the NativeLocationPlugin.
 */
class GeofenceBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GeofenceBroadcastRcvr"
        private const val ACTION_GEOFENCE_EVENT = "com.grabgo.customer.ACTION_GEOFENCE_EVENT"
        
        /**
         * Get PendingIntent for geofence events
         */
        fun getPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, GeofenceBroadcastReceiver::class.java)
            intent.action = ACTION_GEOFENCE_EVENT
            
            return PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_GEOFENCE_EVENT) {
            Log.w(TAG, "Received unexpected action: ${intent.action}")
            return
        }
        
        val geofencingEvent = GeofencingEvent.fromIntent(intent)
        
        if (geofencingEvent == null) {
            Log.e(TAG, "GeofencingEvent is null")
            return
        }
        
        if (geofencingEvent.hasError()) {
            val errorMessage = GeofenceStatusCodes.getStatusCodeString(geofencingEvent.errorCode)
            Log.e(TAG, "Geofence error: $errorMessage")
            return
        }
        
        val transition = geofencingEvent.geofenceTransition
        val triggeringGeofences = geofencingEvent.triggeringGeofences
        val triggeringLocation = geofencingEvent.triggeringLocation
        
        if (triggeringGeofences == null || triggeringGeofences.isEmpty()) {
            Log.w(TAG, "No triggering geofences")
            return
        }
        
        val transitionName = when (transition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            Geofence.GEOFENCE_TRANSITION_DWELL -> "dwell"
            else -> "unknown"
        }
        
        Log.d(TAG, "Geofence transition: $transitionName for ${triggeringGeofences.size} geofences")
        
        // Process each triggered geofence
        for (geofence in triggeringGeofences) {
            val eventData = mutableMapOf<String, Any?>(
                "geofenceId" to geofence.requestId,
                "transition" to transitionName,
                "timestamp" to System.currentTimeMillis()
            )
            
            // Add location data if available
            triggeringLocation?.let { location ->
                eventData["location"] = mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy.toDouble(),
                    "altitude" to location.altitude,
                    "speed" to location.speed.toDouble(),
                    "bearing" to location.bearing.toDouble(),
                    "timestamp" to location.time
                )
            }
            
            // Send event to Flutter
            // Note: In production, you might want to use a more robust method
            // such as WorkManager or a foreground service for background events
            sendGeofenceEventToFlutter(context, eventData)
            
            // Show notification for important transitions
            if (transition == Geofence.GEOFENCE_TRANSITION_ENTER || 
                transition == Geofence.GEOFENCE_TRANSITION_EXIT) {
                showGeofenceNotification(context, geofence.requestId, transitionName)
            }
        }
    }
    
    private fun sendGeofenceEventToFlutter(context: Context, eventData: Map<String, Any?>) {
        // Store event for later retrieval if app is in background
        // The NativeLocationPlugin will pick this up when the app resumes
        GeofenceEventStore.addEvent(context, eventData)
        
        Log.d(TAG, "Geofence event stored: ${eventData["geofenceId"]} - ${eventData["transition"]}")
    }
    
    private fun showGeofenceNotification(context: Context, geofenceId: String, transition: String) {
        // For delivery tracking, we can show a notification
        // This is useful when the rider enters the delivery zone
        
        val title = when (transition) {
            "enter" -> "Delivery Update"
            "exit" -> "Delivery Update"
            else -> "Location Update"
        }
        
        val message = when {
            geofenceId.startsWith("delivery_") && transition == "enter" -> 
                "Your rider is approaching your location!"
            geofenceId.startsWith("restaurant_") && transition == "enter" -> 
                "Your rider has arrived at the restaurant!"
            geofenceId.startsWith("delivery_") && transition == "exit" -> 
                "Your rider has left your delivery area"
            else -> "Geofence: $geofenceId - $transition"
        }
        
        // Note: Notification logic would go here
        // Using existing Firebase/Local notification infrastructure
        Log.d(TAG, "Geofence notification: $title - $message")
    }
}

/**
 * Simple event store for geofence events
 * Used to buffer events when the app is in background
 */
object GeofenceEventStore {
    private val events = mutableListOf<Map<String, Any?>>()
    private const val MAX_EVENTS = 100
    
    @Synchronized
    fun addEvent(context: Context, event: Map<String, Any?>) {
        if (events.size >= MAX_EVENTS) {
            events.removeAt(0)
        }
        events.add(event)
    }
    
    @Synchronized
    fun getAndClearEvents(): List<Map<String, Any?>> {
        val copy = events.toList()
        events.clear()
        return copy
    }
    
    @Synchronized
    fun hasEvents(): Boolean = events.isNotEmpty()
}
