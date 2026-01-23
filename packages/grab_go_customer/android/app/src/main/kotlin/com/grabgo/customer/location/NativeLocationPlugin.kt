package com.grabgo.customer.location

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.*
import kotlin.math.*

/**
 * Native Location Plugin for GrabGo Customer App
 * 
 * Provides battery-optimized location tracking using Google's FusedLocationProviderClient
 * and geofencing capabilities for delivery zone monitoring.
 */
class NativeLocationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, 
    ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "NativeLocationPlugin"
        private const val CHANNEL_NAME = "com.grabgo.customer/location"
        private const val EVENT_CHANNEL_NAME = "com.grabgo.customer/location_events"
        private const val GEOFENCE_EVENT_CHANNEL_NAME = "com.grabgo.customer/geofence_events"
        
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val BACKGROUND_PERMISSION_REQUEST_CODE = 1002
    }

    private var context: Context? = null
    private var activity: Activity? = null
    private var methodChannel: MethodChannel? = null
    private var locationEventChannel: EventChannel? = null
    private var geofenceEventChannel: EventChannel? = null
    
    private var fusedLocationClient: FusedLocationProviderClient? = null
    private var geofencingClient: GeofencingClient? = null
    
    private var locationCallback: LocationCallback? = null
    private var locationEventSink: EventChannel.EventSink? = null
    private var geofenceEventSink: EventChannel.EventSink? = null
    
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var isTracking = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        
        // Initialize FusedLocationProviderClient
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(binding.applicationContext)
        geofencingClient = LocationServices.getGeofencingClient(binding.applicationContext)
        
        // Setup Method Channel
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)
        
        // Setup Event Channels
        locationEventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        locationEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                locationEventSink = events
                Log.d(TAG, "Location event channel listening")
            }
            override fun onCancel(arguments: Any?) {
                locationEventSink = null
                Log.d(TAG, "Location event channel cancelled")
            }
        })
        
        geofenceEventChannel = EventChannel(binding.binaryMessenger, GEOFENCE_EVENT_CHANNEL_NAME)
        geofenceEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                geofenceEventSink = events
                Log.d(TAG, "Geofence event channel listening")
            }
            override fun onCancel(arguments: Any?) {
                geofenceEventSink = null
                Log.d(TAG, "Geofence event channel cancelled")
            }
        })
        
        Log.d(TAG, "NativeLocationPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopLocationUpdates()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        locationEventChannel?.setStreamHandler(null)
        locationEventChannel = null
        geofenceEventChannel?.setStreamHandler(null)
        geofenceEventChannel = null
        context = null
        Log.d(TAG, "NativeLocationPlugin detached from engine")
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        Log.d(TAG, "NativeLocationPlugin attached to activity")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> handleInitialize(result)
            "isLocationServiceEnabled" -> handleIsLocationServiceEnabled(result)
            "checkPermission" -> handleCheckPermission(result)
            "requestPermission" -> handleRequestPermission(result)
            "requestBackgroundPermission" -> handleRequestBackgroundPermission(result)
            "getCurrentLocation" -> handleGetCurrentLocation(call, result)
            "startLocationTracking" -> handleStartLocationTracking(call, result)
            "stopLocationTracking" -> handleStopLocationTracking(result)
            "addGeofence" -> handleAddGeofence(call, result)
            "addGeofences" -> handleAddGeofences(call, result)
            "removeGeofence" -> handleRemoveGeofence(call, result)
            "removeAllGeofences" -> handleRemoveAllGeofences(result)
            "getDistance" -> handleGetDistance(call, result)
            "reverseGeocode" -> handleReverseGeocode(call, result)
            "openLocationSettings" -> handleOpenLocationSettings(result)
            "openAppSettings" -> handleOpenAppSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(result: MethodChannel.Result) {
        try {
            // Verify Google Play Services availability
            val ctx = context ?: run {
                result.success(false)
                return
            }
            
            fusedLocationClient = LocationServices.getFusedLocationProviderClient(ctx)
            geofencingClient = LocationServices.getGeofencingClient(ctx)
            
            // Deliver any buffered geofence events from when app was in background
            deliverBufferedGeofenceEvents()
            
            Log.d(TAG, "Location services initialized")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize: ${e.message}")
            result.success(false)
        }
    }
    
    /**
     * Deliver any geofence events that were buffered while app was in background
     */
    private fun deliverBufferedGeofenceEvents() {
        if (GeofenceEventStore.hasEvents()) {
            val events = GeofenceEventStore.getAndClearEvents()
            Log.d(TAG, "Delivering ${events.size} buffered geofence events")
            
            for (event in events) {
                // Use Handler to post to main thread safely even if activity is null
                android.os.Handler(Looper.getMainLooper()).post {
                    geofenceEventSink?.success(event)
                }
            }
        }
    }

    private fun handleIsLocationServiceEnabled(result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(false)
            return
        }
        
        val locationManager = ctx.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val gpsEnabled = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) ?: false
        val networkEnabled = locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ?: false
        
        result.success(gpsEnabled || networkEnabled)
    }

    private fun handleCheckPermission(result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success("unknown")
            return
        }
        
        val fineLocation = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarseLocation = ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION)
        
        val permissionStatus = when {
            fineLocation == PackageManager.PERMISSION_GRANTED -> "granted"
            coarseLocation == PackageManager.PERMISSION_GRANTED -> "granted"
            activity?.let { 
                ActivityCompat.shouldShowRequestPermissionRationale(it, Manifest.permission.ACCESS_FINE_LOCATION)
            } == true -> "denied"
            else -> "deniedForever"
        }
        
        result.success(permissionStatus)
    }

    private fun handleRequestPermission(result: MethodChannel.Result) {
        val act = activity ?: run {
            result.success("denied")
            return
        }
        
        pendingPermissionResult = result
        
        ActivityCompat.requestPermissions(
            act,
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            PERMISSION_REQUEST_CODE
        )
    }

    private fun handleRequestBackgroundPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Background permission not needed before Android Q
            result.success("granted")
            return
        }
        
        val act = activity ?: run {
            result.success("denied")
            return
        }
        
        val ctx = context ?: run {
            result.success("denied")
            return
        }
        
        // Check if foreground permission is granted first
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.success("denied")
            return
        }
        
        // Check if background permission is already granted
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION) 
            == PackageManager.PERMISSION_GRANTED) {
            result.success("granted")
            return
        }
        
        pendingPermissionResult = result
        
        ActivityCompat.requestPermissions(
            act,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            BACKGROUND_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        when (requestCode) {
            PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && 
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                
                val status = if (granted) "granted" else {
                    activity?.let {
                        if (ActivityCompat.shouldShowRequestPermissionRationale(
                                it, Manifest.permission.ACCESS_FINE_LOCATION)) {
                            "denied"
                        } else {
                            "deniedForever"
                        }
                    } ?: "denied"
                }
                
                pendingPermissionResult?.success(status)
                pendingPermissionResult = null
                return true
            }
            BACKGROUND_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() && 
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                
                pendingPermissionResult?.success(if (granted) "granted" else "denied")
                pendingPermissionResult = null
                return true
            }
        }
        return false
    }

    private fun handleGetCurrentLocation(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }
        
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        
        val mode = call.argument<String>("mode") ?: "highAccuracy"
        val timeoutMs = call.argument<Int>("timeoutMs") ?: 15000
        
        val priority = when (mode) {
            "highAccuracy" -> Priority.PRIORITY_HIGH_ACCURACY
            "balanced" -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
            "lowPower" -> Priority.PRIORITY_LOW_POWER
            "passive" -> Priority.PRIORITY_PASSIVE
            else -> Priority.PRIORITY_HIGH_ACCURACY
        }
        
        val request = CurrentLocationRequest.Builder()
            .setPriority(priority)
            .setDurationMillis(timeoutMs.toLong())
            .setMaxUpdateAgeMillis(5000)
            .build()
        
        fusedLocationClient?.getCurrentLocation(request, null)
            ?.addOnSuccessListener { location: Location? ->
                if (location != null) {
                    result.success(locationToMap(location))
                } else {
                    // Try to get last known location as fallback
                    getLastKnownLocation(result)
                }
            }
            ?.addOnFailureListener { e ->
                Log.e(TAG, "Failed to get current location: ${e.message}")
                result.error("LOCATION_ERROR", e.message, null)
            }
    }

    private fun getLastKnownLocation(result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(null)
            return
        }
        
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.success(null)
            return
        }
        
        fusedLocationClient?.lastLocation
            ?.addOnSuccessListener { location: Location? ->
                if (location != null) {
                    result.success(locationToMap(location))
                } else {
                    result.success(null)
                }
            }
            ?.addOnFailureListener {
                result.success(null)
            }
    }

    private fun handleStartLocationTracking(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(false)
            return
        }
        
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        
        if (isTracking) {
            result.success(true)
            return
        }
        
        val mode = call.argument<String>("mode") ?: "balanced"
        val intervalMs = call.argument<Int>("intervalMs") ?: 10000
        val fastestIntervalMs = call.argument<Int>("fastestIntervalMs") ?: 5000
        val smallestDisplacement = call.argument<Double>("smallestDisplacementMeters") ?: 10.0
        
        val priority = when (mode) {
            "highAccuracy" -> Priority.PRIORITY_HIGH_ACCURACY
            "balanced" -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
            "lowPower" -> Priority.PRIORITY_LOW_POWER
            "passive" -> Priority.PRIORITY_PASSIVE
            else -> Priority.PRIORITY_BALANCED_POWER_ACCURACY
        }
        
        val locationRequest = LocationRequest.Builder(priority, intervalMs.toLong())
            .setMinUpdateIntervalMillis(fastestIntervalMs.toLong())
            .setMinUpdateDistanceMeters(smallestDisplacement.toFloat())
            .setWaitForAccurateLocation(mode == "highAccuracy")
            .build()
        
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    val locationMap = locationToMap(location)
                    // Use Handler for thread-safe UI updates even if activity is null
                    android.os.Handler(Looper.getMainLooper()).post {
                        locationEventSink?.success(locationMap)
                    }
                    Log.d(TAG, "Location update: ${location.latitude}, ${location.longitude}")
                }
            }
            
            override fun onLocationAvailability(availability: LocationAvailability) {
                Log.d(TAG, "Location availability: ${availability.isLocationAvailable}")
            }
        }
        
        try {
            fusedLocationClient?.requestLocationUpdates(
                locationRequest,
                locationCallback!!,
                Looper.getMainLooper()
            )
            isTracking = true
            Log.d(TAG, "Location tracking started with mode: $mode")
            result.success(true)
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception starting location updates: ${e.message}")
            result.success(false)
        }
    }

    private fun handleStopLocationTracking(result: MethodChannel.Result) {
        stopLocationUpdates()
        result.success(true)
    }

    private fun stopLocationUpdates() {
        locationCallback?.let { callback ->
            fusedLocationClient?.removeLocationUpdates(callback)
            Log.d(TAG, "Location tracking stopped")
        }
        locationCallback = null
        isTracking = false
    }

    private fun handleAddGeofence(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(false)
            return
        }
        
        // Check fine location permission
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        
        // Check background location permission for Android Q+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.error("BACKGROUND_PERMISSION_DENIED", "Background location permission required for geofencing", null)
            return
        }
        
        val id = call.argument<String>("id") ?: run {
            result.error("INVALID_ARGS", "Geofence ID is required", null)
            return
        }
        val latitude = call.argument<Double>("latitude") ?: 0.0
        val longitude = call.argument<Double>("longitude") ?: 0.0
        val radius = call.argument<Double>("radiusMeters") ?: 100.0
        val loiteringDelay = call.argument<Int>("loiteringDelayMs") ?: 30000
        val expiration = call.argument<Int>("expirationDurationMs") ?: -1
        val notifyOnEnter = call.argument<Boolean>("notifyOnEnter") ?: true
        val notifyOnExit = call.argument<Boolean>("notifyOnExit") ?: true
        val notifyOnDwell = call.argument<Boolean>("notifyOnDwell") ?: false
        
        var transitionTypes = 0
        if (notifyOnEnter) transitionTypes = transitionTypes or Geofence.GEOFENCE_TRANSITION_ENTER
        if (notifyOnExit) transitionTypes = transitionTypes or Geofence.GEOFENCE_TRANSITION_EXIT
        if (notifyOnDwell) transitionTypes = transitionTypes or Geofence.GEOFENCE_TRANSITION_DWELL
        
        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radius.toFloat())
            .setExpirationDuration(if (expiration < 0) Geofence.NEVER_EXPIRE else expiration.toLong())
            .setTransitionTypes(transitionTypes)
            .setLoiteringDelay(loiteringDelay)
            .build()
        
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()
        
        val pendingIntent = GeofenceBroadcastReceiver.getPendingIntent(ctx)
        
        try {
            geofencingClient?.addGeofences(request, pendingIntent)
                ?.addOnSuccessListener {
                    Log.d(TAG, "Geofence added: $id")
                    result.success(true)
                }
                ?.addOnFailureListener { e ->
                    Log.e(TAG, "Failed to add geofence: ${e.message}")
                    result.success(false)
                }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception adding geofence: ${e.message}")
            result.success(false)
        }
    }

    private fun handleAddGeofences(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(0)
            return
        }
        
        // Check fine location permission
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        
        // Check background location permission for Android Q+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            result.error("BACKGROUND_PERMISSION_DENIED", "Background location permission required for geofencing", null)
            return
        }
        
        @Suppress("UNCHECKED_CAST")
        val geofencesList = call.argument<List<Map<String, Any>>>("geofences") ?: run {
            result.success(0)
            return
        }
        
        val geofences = geofencesList.mapNotNull { config ->
            try {
                val id = config["id"] as? String ?: return@mapNotNull null
                val latitude = (config["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
                val longitude = (config["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
                val radius = (config["radiusMeters"] as? Number)?.toFloat() ?: 100f
                val loiteringDelay = (config["loiteringDelayMs"] as? Number)?.toInt() ?: 30000
                val expiration = (config["expirationDurationMs"] as? Number)?.toLong() ?: -1L
                val notifyOnEnter = config["notifyOnEnter"] as? Boolean ?: true
                val notifyOnExit = config["notifyOnExit"] as? Boolean ?: true
                val notifyOnDwell = config["notifyOnDwell"] as? Boolean ?: false
                
                var transitionTypes = 0
                if (notifyOnEnter) transitionTypes = transitionTypes or Geofence.GEOFENCE_TRANSITION_ENTER
                if (notifyOnExit) transitionTypes = transitionTypes or Geofence.GEOFENCE_TRANSITION_EXIT
                if (notifyOnDwell) transitionTypes = transitionTypes or Geofence.GEOFENCE_TRANSITION_DWELL
                
                Geofence.Builder()
                    .setRequestId(id)
                    .setCircularRegion(latitude, longitude, radius)
                    .setExpirationDuration(if (expiration < 0) Geofence.NEVER_EXPIRE else expiration)
                    .setTransitionTypes(transitionTypes)
                    .setLoiteringDelay(loiteringDelay)
                    .build()
            } catch (e: Exception) {
                Log.e(TAG, "Error creating geofence: ${e.message}")
                null
            }
        }
        
        if (geofences.isEmpty()) {
            result.success(0)
            return
        }
        
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()
        
        val pendingIntent = GeofenceBroadcastReceiver.getPendingIntent(ctx)
        
        try {
            geofencingClient?.addGeofences(request, pendingIntent)
                ?.addOnSuccessListener {
                    Log.d(TAG, "Added ${geofences.size} geofences")
                    result.success(geofences.size)
                }
                ?.addOnFailureListener { e ->
                    Log.e(TAG, "Failed to add geofences: ${e.message}")
                    result.success(0)
                }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception adding geofences: ${e.message}")
            result.success(0)
        }
    }

    private fun handleRemoveGeofence(call: MethodCall, result: MethodChannel.Result) {
        val geofenceId = call.argument<String>("geofenceId") ?: run {
            result.success(false)
            return
        }
        
        geofencingClient?.removeGeofences(listOf(geofenceId))
            ?.addOnSuccessListener {
                Log.d(TAG, "Geofence removed: $geofenceId")
                result.success(true)
            }
            ?.addOnFailureListener { e ->
                Log.e(TAG, "Failed to remove geofence: ${e.message}")
                result.success(false)
            }
    }

    private fun handleRemoveAllGeofences(result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(false)
            return
        }
        
        val pendingIntent = GeofenceBroadcastReceiver.getPendingIntent(ctx)
        
        geofencingClient?.removeGeofences(pendingIntent)
            ?.addOnSuccessListener {
                Log.d(TAG, "All geofences removed")
                result.success(true)
            }
            ?.addOnFailureListener { e ->
                Log.e(TAG, "Failed to remove all geofences: ${e.message}")
                result.success(false)
            }
    }

    private fun handleGetDistance(call: MethodCall, result: MethodChannel.Result) {
        val startLat = call.argument<Double>("startLat") ?: 0.0
        val startLng = call.argument<Double>("startLng") ?: 0.0
        val endLat = call.argument<Double>("endLat") ?: 0.0
        val endLng = call.argument<Double>("endLng") ?: 0.0
        
        val results = FloatArray(1)
        Location.distanceBetween(startLat, startLng, endLat, endLng, results)
        
        result.success(results[0].toDouble())
    }

    private fun handleReverseGeocode(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(null)
            return
        }
        
        val latitude = call.argument<Double>("latitude") ?: 0.0
        val longitude = call.argument<Double>("longitude") ?: 0.0
        
        try {
            val geocoder = Geocoder(ctx, Locale.getDefault())
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                geocoder.getFromLocation(latitude, longitude, 1) { addresses ->
                    val address = addresses.firstOrNull()
                    val formattedAddress = address?.let {
                        buildString {
                            it.locality?.let { append(it) }
                            it.adminArea?.let { 
                                if (isNotEmpty()) append(", ")
                                append(it) 
                            }
                        }.ifEmpty { it.getAddressLine(0) }
                    }
                    // Use Handler for thread-safe result delivery
                    android.os.Handler(Looper.getMainLooper()).post {
                        result.success(formattedAddress)
                    }
                }
            } else {
                @Suppress("DEPRECATION")
                val addresses = geocoder.getFromLocation(latitude, longitude, 1)
                val address = addresses?.firstOrNull()
                val formattedAddress = address?.let {
                    buildString {
                        it.locality?.let { append(it) }
                        it.adminArea?.let { 
                            if (isNotEmpty()) append(", ")
                            append(it) 
                        }
                    }.ifEmpty { it.getAddressLine(0) }
                }
                result.success(formattedAddress)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Reverse geocode error: ${e.message}")
            result.success(null)
        }
    }

    private fun handleOpenLocationSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context?.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening location settings: ${e.message}")
            result.success(false)
        }
    }

    private fun handleOpenAppSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.data = android.net.Uri.fromParts("package", context?.packageName, null)
            context?.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app settings: ${e.message}")
            result.success(false)
        }
    }

    private fun locationToMap(location: Location): Map<String, Any?> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "altitude" to location.altitude,
            "speed" to location.speed.toDouble(),
            "bearing" to location.bearing.toDouble(),
            "timestamp" to location.time
        )
    }
    
    /**
     * Send geofence event to Flutter
     * Called by GeofenceBroadcastReceiver
     */
    fun sendGeofenceEvent(event: Map<String, Any?>) {
        // Use Handler for thread-safe event delivery
        android.os.Handler(Looper.getMainLooper()).post {
            geofenceEventSink?.success(event)
        }
    }
}
