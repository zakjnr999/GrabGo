# Phase 8: Connect Provider to Map Tracking UI

## Step 8.1: Add Required Imports

Add these imports at the top of `map_tracking.dart`:

```dart
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/tracking_provider.dart';
import '../config/tracking_service_locator.dart';
```

---

## Step 8.2: Update MapTracking Widget

Change from StatefulWidget to use ChangeNotifierProvider:

### Current Structure:
```dart
class MapTracking extends StatefulWidget {
  const MapTracking({super.key});
  
  @override
  State<MapTracking> createState() => _MapTrackingState();
}
```

### New Structure:
```dart
class MapTracking extends StatefulWidget {
  final String orderId; // Add this parameter
  
  const MapTracking({
    super.key,
    required this.orderId,
  });
  
  @override
  State<MapTracking> createState() => _MapTrackingState();
}
```

---

## Step 8.3: Initialize Tracking in initState

Add this to `_MapTrackingState`:

```dart
class _MapTrackingState extends State<MapTracking> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    // Get auth token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken') ?? '';
    
    // Setup services
    setupTrackingServices(
      baseUrl: 'https://grabgo-backend.onrender.com',
      token: token,
    );
    
    // Initialize tracking
    if (mounted) {
      final provider = context.read<TrackingProvider>();
      await provider.initializeTracking(widget.orderId);
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    context.read<TrackingProvider>().stopTracking();
    super.dispose();
  }
  
  // ... rest of widget
}
```

---

## Step 8.4: Wrap with ChangeNotifierProvider

Wrap the entire Scaffold with Provider:

```dart
@override
Widget build(BuildContext context) {
  final colors = context.appColors;
  final Size size = MediaQuery.sizeOf(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return ChangeNotifierProvider(
    create: (_) => trackingLocator<TrackingProvider>(),
    child: Consumer<TrackingProvider>(
      builder: (context, provider, child) {
        // Show loading state
        if (provider.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: colors.accentOrange,
              ),
            ),
          );
        }

        // Show error state
        if (provider.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colors.error),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load tracking',
                    style: TextStyle(color: colors.textPrimary, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    provider.error!,
                    style: TextStyle(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => provider.refreshTracking(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        // Main tracking UI
        return _buildTrackingUI(context, provider, colors, size, isDark);
      },
    ),
  );
}
```

---

## Step 8.5: Update Google Map to Use Provider Data

Replace the GoogleMap widget with:

```dart
GoogleMap(
  initialCameraPosition: CameraPosition(
    target: provider.trackingData?.currentLocation?.toLatLng() ?? 
            const LatLng(5.6037, -0.1870),
    zoom: 14,
  ),
  markers: provider.markers,  // ← Use provider markers
  polylines: provider.polylines,  // ← Use provider polylines
  myLocationEnabled: false,
  myLocationButtonEnabled: false,
  zoomControlsEnabled: false,
  mapToolbarEnabled: false,
  compassEnabled: false,
  onMapCreated: (GoogleMapController controller) {
    provider.setMapController(controller);  // ← Set controller in provider
  },
  style: isDark ? _darkMapStyle : null,
),
```

---

## Step 8.6: Update UI with Real Data

Replace hardcoded values with provider data:

### Rider Name & Rating:
```dart
// Before:
Text("Kwame Atta", ...)

// After:
Text(
  provider.trackingData?.rider?.name ?? "Rider",
  ...
)

// Rating:
Text(
  provider.trackingData?.rider?.formattedRating ?? "N/A",
  ...
)
```

### Status:
```dart
// Before:
Text("On The Way", ...)

// After:
Text(
  provider.trackingData?.statusText ?? "Preparing",
  ...
)
```

### ETA:
```dart
// Before:
Text("28 min", ...)

// After:
Text(
  provider.trackingData?.formattedEta ?? "Calculating...",
  ...
)
```

### Distance:
```dart
// Before:
Text("1.2 km", ...)

// After:
Text(
  "${provider.trackingData?.distanceInKm ?? '0.0'} km",
  ...
)
```

### Active Step:
```dart
// Before:
int activeStep = 2;

// After:
final activeStep = provider.trackingData?.activeStep ?? 0;
```

---

## Step 8.7: Add Real-Time Update Indicator

Add a connection status indicator:

```dart
// In AppBar or somewhere visible
if (!provider.isSocketConnected)
  Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.orange,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 8),
        Text(
          'Reconnecting...',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  ),
```

---

## 🎯 Summary of Changes

1. ✅ Add imports (Provider, SharedPreferences, services)
2. ✅ Add `orderId` parameter to MapTracking
3. ✅ Add initState to initialize tracking
4. ✅ Wrap with ChangeNotifierProvider
5. ✅ Add loading & error states
6. ✅ Connect GoogleMap to provider (markers, polylines)
7. ✅ Replace all hardcoded data with provider data
8. ✅ Add real-time connection indicator

---

## 🧪 Testing

After making these changes:

1. Navigate to tracking screen with a real order ID
2. You should see:
   - Real rider location on map
   - Live ETA updates
   - Distance decreasing
   - Route polyline
   - Status changes

---

**Ready to implement these changes?** I can help you make them one by one! 🚀
