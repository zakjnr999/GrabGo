import Foundation
import Flutter
import CoreLocation
import UIKit

/// Native Location Plugin for GrabGo Customer App (iOS)
///
/// Provides battery-optimized location tracking using CLLocationManager
/// and geofencing capabilities for delivery zone monitoring.
public class NativeLocationPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Properties
    
    private var channel: FlutterMethodChannel?
    private var locationEventChannel: FlutterEventChannel?
    private var geofenceEventChannel: FlutterEventChannel?
    
    private var locationEventSink: FlutterEventSink?
    private var geofenceEventSink: FlutterEventSink?
    
    private var locationManager: CLLocationManager?
    private var isTracking = false
    private var currentTrackingMode: String = "balanced"
    
    // Pending permission request callback
    private var pendingPermissionResult: FlutterResult?
    
    // Timeout timer for location requests
    private var locationTimeoutTimer: Timer?
    
    // Track if we're waiting for a permission callback (to avoid duplicate calls)
    private var isWaitingForPermission = false
    
    // Buffered geofence events for when app is in background
    private var bufferedGeofenceEvents: [[String: Any]] = []
    private let maxBufferedEvents = 100
    
    // MARK: - Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativeLocationPlugin()
        instance.setupChannels(registrar: registrar)
    }
    
    private func setupChannels(registrar: FlutterPluginRegistrar) {
        // Method Channel
        channel = FlutterMethodChannel(
            name: "com.grabgo.customer/location",
            binaryMessenger: registrar.messenger()
        )
        channel?.setMethodCallHandler(handle)
        
        // Location Event Channel
        locationEventChannel = FlutterEventChannel(
            name: "com.grabgo.customer/location_events",
            binaryMessenger: registrar.messenger()
        )
        locationEventChannel?.setStreamHandler(LocationStreamHandler(plugin: self))
        
        // Geofence Event Channel
        geofenceEventChannel = FlutterEventChannel(
            name: "com.grabgo.customer/geofence_events",
            binaryMessenger: registrar.messenger()
        )
        geofenceEventChannel?.setStreamHandler(GeofenceStreamHandler(plugin: self))
        
        print("✅ NativeLocationPlugin registered")
    }
    
    // MARK: - Method Call Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(result: result)
        case "isLocationServiceEnabled":
            handleIsLocationServiceEnabled(result: result)
        case "checkPermission":
            handleCheckPermission(result: result)
        case "requestPermission":
            handleRequestPermission(result: result)
        case "requestBackgroundPermission":
            handleRequestBackgroundPermission(result: result)
        case "getCurrentLocation":
            handleGetCurrentLocation(call: call, result: result)
        case "startLocationTracking":
            handleStartLocationTracking(call: call, result: result)
        case "stopLocationTracking":
            handleStopLocationTracking(result: result)
        case "addGeofence":
            handleAddGeofence(call: call, result: result)
        case "addGeofences":
            handleAddGeofences(call: call, result: result)
        case "removeGeofence":
            handleRemoveGeofence(call: call, result: result)
        case "removeAllGeofences":
            handleRemoveAllGeofences(result: result)
        case "getDistance":
            handleGetDistance(call: call, result: result)
        case "reverseGeocode":
            handleReverseGeocode(call: call, result: result)
        case "openLocationSettings":
            handleOpenLocationSettings(result: result)
        case "openAppSettings":
            handleOpenAppSettings(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Initialize
    
    private func handleInitialize(result: @escaping FlutterResult) {
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            // Note: allowsBackgroundLocationUpdates is set when tracking starts
            // Setting it without authorization causes a crash
        }
        
        // Deliver any buffered geofence events
        deliverBufferedGeofenceEvents()
        
        print("✅ Location services initialized")
        result(true)
    }
    
    private func deliverBufferedGeofenceEvents() {
        guard !bufferedGeofenceEvents.isEmpty else { return }
        
        print("📤 Delivering \(bufferedGeofenceEvents.count) buffered geofence events")
        
        for event in bufferedGeofenceEvents {
            geofenceEventSink?(event)
        }
        
        bufferedGeofenceEvents.removeAll()
    }
    
    // MARK: - Location Service Status
    
    private func handleIsLocationServiceEnabled(result: @escaping FlutterResult) {
        result(CLLocationManager.locationServicesEnabled())
    }
    
    // MARK: - Permission Handling
    
    private func handleCheckPermission(result: @escaping FlutterResult) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        let permissionString = authorizationStatusToString(status)
        result(permissionString)
    }
    
    private func handleRequestPermission(result: @escaping FlutterResult) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        // If already determined, return immediately (delegate won't be called)
        if status != .notDetermined {
            result(authorizationStatusToString(status))
            return
        }
        
        pendingPermissionResult = result
        isWaitingForPermission = true
        locationManager?.requestWhenInUseAuthorization()
    }
    
    private func handleRequestBackgroundPermission(result: @escaping FlutterResult) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        // Check if we already have always authorization
        if status == .authorizedAlways {
            result("granted")
            return
        }
        
        // Check if we have when in use authorization (required before requesting always)
        if status != .authorizedWhenInUse {
            result("denied")
            return
        }
        
        pendingPermissionResult = result
        isWaitingForPermission = true
        locationManager?.requestAlwaysAuthorization()
    }
    
    private func authorizationStatusToString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return "granted"
        case .denied:
            return "deniedForever"
        case .restricted:
            return "restricted"
        case .notDetermined:
            return "denied"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - Get Current Location
    
    private var pendingLocationResult: FlutterResult?
    
    private func handleGetCurrentLocation(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        let mode = args["mode"] as? String ?? "highAccuracy"
        let timeoutMs = args["timeoutMs"] as? Int ?? 15000
        
        // Cancel any existing timeout
        locationTimeoutTimer?.invalidate()
        
        // Configure accuracy based on mode
        configureLocationManager(for: mode)
        
        // Store the result callback
        pendingLocationResult = result
        
        // Request single location update
        locationManager?.requestLocation()
        
        // Set timeout timer
        let timeoutSeconds = Double(timeoutMs) / 1000.0
        locationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutSeconds, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if let pendingResult = self.pendingLocationResult {
                pendingResult(FlutterError(
                    code: "LOCATION_TIMEOUT",
                    message: "Location request timed out after \(timeoutMs)ms",
                    details: nil
                ))
                self.pendingLocationResult = nil
            }
        }
    }
    
    private func configureLocationManager(for mode: String) {
        switch mode {
        case "highAccuracy":
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager?.distanceFilter = kCLDistanceFilterNone
        case "balanced":
            locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager?.distanceFilter = 50
        case "lowPower":
            locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer
            locationManager?.distanceFilter = 500
        case "passive":
            locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            locationManager?.distanceFilter = 1000
        default:
            locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager?.distanceFilter = 50
        }
    }
    
    // MARK: - Location Tracking
    
    private func handleStartLocationTracking(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
        }
        
        if isTracking {
            result(true)
            return
        }
        
        let mode = args["mode"] as? String ?? "balanced"
        let smallestDisplacement = args["smallestDisplacementMeters"] as? Double ?? 10.0
        
        currentTrackingMode = mode
        configureLocationManager(for: mode)
        locationManager?.distanceFilter = smallestDisplacement
        
        // Enable background location updates only if we have authorization
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager?.allowsBackgroundLocationUpdates = true
            locationManager?.pausesLocationUpdatesAutomatically = false
        }
        
        // Start updates based on mode
        if mode == "passive" {
            locationManager?.startMonitoringSignificantLocationChanges()
        } else {
            locationManager?.startUpdatingLocation()
        }
        
        isTracking = true
        print("✅ Location tracking started (mode: \(mode))")
        result(true)
    }
    
    private func handleStopLocationTracking(result: @escaping FlutterResult) {
        stopLocationUpdates()
        result(true)
    }
    
    private func stopLocationUpdates() {
        locationManager?.stopUpdatingLocation()
        locationManager?.stopMonitoringSignificantLocationChanges()
        isTracking = false
        print("✅ Location tracking stopped")
    }
    
    // MARK: - Geofencing
    
    private func handleAddGeofence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String,
              let latitude = args["latitude"] as? Double,
              let longitude = args["longitude"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Invalid geofence arguments", details: nil))
            return
        }
        
        // Check if geofencing is available
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            result(FlutterError(code: "GEOFENCING_UNAVAILABLE", message: "Geofencing not available", details: nil))
            return
        }
        
        // Geofencing requires "always" authorization on iOS
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status != .authorizedAlways {
            result(FlutterError(
                code: "BACKGROUND_PERMISSION_REQUIRED",
                message: "Geofencing requires 'Always' location permission on iOS",
                details: nil
            ))
            return
        }
        
        let radius = args["radiusMeters"] as? Double ?? 100.0
        let notifyOnEntry = args["notifyOnEnter"] as? Bool ?? true
        let notifyOnExit = args["notifyOnExit"] as? Bool ?? true
        
        // Ensure radius doesn't exceed maximum
        let clampedRadius = min(radius, locationManager?.maximumRegionMonitoringDistance ?? 100.0)
        
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: id)
        region.notifyOnEntry = notifyOnEntry
        region.notifyOnExit = notifyOnExit
        
        locationManager?.startMonitoring(for: region)
        
        print("✅ Geofence added: \(id)")
        result(true)
    }
    
    private func handleAddGeofences(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let geofences = args["geofences"] as? [[String: Any]] else {
            result(0)
            return
        }
        
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            result(FlutterError(code: "GEOFENCING_UNAVAILABLE", message: "Geofencing not available", details: nil))
            return
        }
        
        // Geofencing requires "always" authorization on iOS
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager?.authorizationStatus ?? .notDetermined
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status != .authorizedAlways {
            result(FlutterError(
                code: "BACKGROUND_PERMISSION_REQUIRED",
                message: "Geofencing requires 'Always' location permission on iOS",
                details: nil
            ))
            return
        }
        
        var addedCount = 0
        let maxRegions = 20 // iOS limit
        
        for (index, config) in geofences.enumerated() {
            if index >= maxRegions {
                print("⚠️ iOS geofence limit reached (max: \(maxRegions))")
                break
            }
            
            guard let id = config["id"] as? String,
                  let latitude = config["latitude"] as? Double,
                  let longitude = config["longitude"] as? Double else {
                continue
            }
            
            let radius = config["radiusMeters"] as? Double ?? 100.0
            let notifyOnEntry = config["notifyOnEnter"] as? Bool ?? true
            let notifyOnExit = config["notifyOnExit"] as? Bool ?? true
            
            let clampedRadius = min(radius, locationManager?.maximumRegionMonitoringDistance ?? 100.0)
            
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: id)
            region.notifyOnEntry = notifyOnEntry
            region.notifyOnExit = notifyOnExit
            
            locationManager?.startMonitoring(for: region)
            addedCount += 1
        }
        
        print("✅ Added \(addedCount) geofences")
        result(addedCount)
    }
    
    private func handleRemoveGeofence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let geofenceId = args["geofenceId"] as? String else {
            result(false)
            return
        }
        
        // Find and remove the region
        if let regions = locationManager?.monitoredRegions {
            for region in regions {
                if region.identifier == geofenceId {
                    locationManager?.stopMonitoring(for: region)
                    print("✅ Geofence removed: \(geofenceId)")
                    result(true)
                    return
                }
            }
        }
        
        result(false)
    }
    
    private func handleRemoveAllGeofences(result: @escaping FlutterResult) {
        if let regions = locationManager?.monitoredRegions {
            for region in regions {
                locationManager?.stopMonitoring(for: region)
            }
        }
        
        print("✅ All geofences removed")
        result(true)
    }
    
    // MARK: - Utilities
    
    private func handleGetDistance(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let startLat = args["startLat"] as? Double,
              let startLng = args["startLng"] as? Double,
              let endLat = args["endLat"] as? Double,
              let endLng = args["endLng"] as? Double else {
            result(0.0)
            return
        }
        
        let startLocation = CLLocation(latitude: startLat, longitude: startLng)
        let endLocation = CLLocation(latitude: endLat, longitude: endLng)
        
        let distance = startLocation.distance(from: endLocation)
        result(distance)
    }
    
    private func handleReverseGeocode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let latitude = args["latitude"] as? Double,
              let longitude = args["longitude"] as? Double else {
            result(nil)
            return
        }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("❌ Reverse geocode error: \(error.localizedDescription)")
                result(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                result(nil)
                return
            }
            
            var addressParts: [String] = []
            if let locality = placemark.locality {
                addressParts.append(locality)
            }
            if let administrativeArea = placemark.administrativeArea {
                addressParts.append(administrativeArea)
            }
            
            let formattedAddress = addressParts.isEmpty ? 
                placemark.name : addressParts.joined(separator: ", ")
            
            result(formattedAddress)
        }
    }
    
    private func handleOpenLocationSettings(result: @escaping FlutterResult) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    result(success)
                }
                return
            }
        }
        result(false)
    }
    
    private func handleOpenAppSettings(result: @escaping FlutterResult) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:]) { success in
                    result(success)
                }
                return
            }
        }
        result(false)
    }
    
    // MARK: - Helper Methods
    
    private func locationToMap(_ location: CLLocation) -> [String: Any] {
        return [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "speed": max(0, location.speed),
            "bearing": max(0, location.course),
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)
        ]
    }
    
    // MARK: - Event Sink Setters
    
    func setLocationEventSink(_ sink: FlutterEventSink?) {
        locationEventSink = sink
    }
    
    func setGeofenceEventSink(_ sink: FlutterEventSink?) {
        geofenceEventSink = sink
        // Deliver buffered events when sink becomes available
        if sink != nil {
            deliverBufferedGeofenceEvents()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension NativeLocationPlugin: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let locationData = locationToMap(location)
        
        // If we have a pending one-shot result, return it
        if let pendingResult = pendingLocationResult {
            // Cancel timeout timer
            locationTimeoutTimer?.invalidate()
            locationTimeoutTimer = nil
            
            pendingResult(locationData)
            pendingLocationResult = nil
        }
        
        // Send to stream if tracking (ensure main thread for Flutter)
        if isTracking {
            DispatchQueue.main.async { [weak self] in
                self?.locationEventSink?(locationData)
            }
            print("📍 Location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        
        // If we have a pending result, return error
        if let pendingResult = pendingLocationResult {
            // Cancel timeout timer
            locationTimeoutTimer?.invalidate()
            locationTimeoutTimer = nil
            
            pendingResult(FlutterError(
                code: "LOCATION_ERROR",
                message: error.localizedDescription,
                details: nil
            ))
            pendingLocationResult = nil
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // On iOS 14+, locationManagerDidChangeAuthorization is called instead
        // This method is only for iOS 13 and earlier
        if #available(iOS 14.0, *) {
            return // Handled by locationManagerDidChangeAuthorization
        }
        
        handleAuthorizationChange(status: status)
    }
    
    @available(iOS 14.0, *)
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange(status: manager.authorizationStatus)
    }
    
    private func handleAuthorizationChange(status: CLAuthorizationStatus) {
        let permissionString = authorizationStatusToString(status)
        
        // Only notify if we're actually waiting for a permission response
        if isWaitingForPermission, let pendingResult = pendingPermissionResult {
            pendingResult(permissionString)
            pendingPermissionResult = nil
            isWaitingForPermission = false
        }
        
        print("📍 Authorization changed: \(permissionString)")
    }
    
    // MARK: - Geofence Delegate Methods
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        let eventData: [String: Any] = [
            "geofenceId": circularRegion.identifier,
            "transition": "enter",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        sendGeofenceEvent(eventData)
        print("🎯 Geofence entered: \(circularRegion.identifier)")
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        let eventData: [String: Any] = [
            "geofenceId": circularRegion.identifier,
            "transition": "exit",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        
        sendGeofenceEvent(eventData)
        print("🎯 Geofence exited: \(circularRegion.identifier)")
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("❌ Geofence monitoring failed: \(error.localizedDescription)")
    }
    
    private func sendGeofenceEvent(_ eventData: [String: Any]) {
        // Ensure we're on the main thread for Flutter event sinks
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let sink = self.geofenceEventSink {
                sink(eventData)
            } else {
                // Buffer event for later delivery
                if self.bufferedGeofenceEvents.count >= self.maxBufferedEvents {
                    self.bufferedGeofenceEvents.removeFirst()
                }
                self.bufferedGeofenceEvents.append(eventData)
                print("📦 Geofence event buffered (app in background)")
            }
        }
    }
}

// MARK: - Stream Handlers

class LocationStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: NativeLocationPlugin?
    
    init(plugin: NativeLocationPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setLocationEventSink(events)
        print("📍 Location stream listening")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setLocationEventSink(nil)
        print("📍 Location stream cancelled")
        return nil
    }
}

class GeofenceStreamHandler: NSObject, FlutterStreamHandler {
    private weak var plugin: NativeLocationPlugin?
    
    init(plugin: NativeLocationPlugin) {
        self.plugin = plugin
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        plugin?.setGeofenceEventSink(events)
        print("🎯 Geofence stream listening")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        plugin?.setGeofenceEventSink(nil)
        print("🎯 Geofence stream cancelled")
        return nil
    }
}
