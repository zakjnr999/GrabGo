# GrabGo Hackathon Route Playback

Use these GPX files to demo live tracking without physically moving:

- `rider_to_vendor.gpx`
- `vendor_to_customer.gpx`

Currently tuned with your latest demo coordinates:

- Rider start: `5.5646133, -0.1823567`
- Vendor pickup: `5.6037000, -0.1870000`
- Customer dropoff: `5.57457729677039, -0.215160772204399`

## Quick Setup

1. Keep backend tracking real:
   - Set `AppConfig.trackingDemoMode` to `false`.
2. Start both apps (customer + rider) and confirm rider is online.
3. Place an order from customer app and accept on rider alert sheet.
4. Open rider map tracking screen.

## Playback in Android Emulator

1. Open emulator `...` (Extended controls).
2. Go to `Location` -> `Routes`.
3. Import `demo/hackathon/rider_to_vendor.gpx`.
4. Press play while rider is on map.
5. At vendor marker, tap `I've Arrived`, then `Picked Up`.
6. Import and play `demo/hackathon/vendor_to_customer.gpx`.
7. Keep customer tracking screen open to show live map updates.

## Optional: Push GPX to Emulator Storage

From project root:

```bash
adb push demo/hackathon/rider_to_vendor.gpx /sdcard/Download/
adb push demo/hackathon/vendor_to_customer.gpx /sdcard/Download/
```

Then import from `/sdcard/Download` in emulator route playback.

## Regenerate for New Order Coordinates

If your next order uses different coordinates:

```bash
chmod +x demo/hackathon/generate_routes.sh
demo/hackathon/generate_routes.sh <start_lat> <start_lon> <pickup_lat> <pickup_lon> <drop_lat> <drop_lon>
```

This creates:

- `demo/hackathon/rider_to_vendor_custom.gpx`
- `demo/hackathon/vendor_to_customer_custom.gpx`

## Demo Tips

- Use playback speed `1x` or `2x` for clear movement.
- Keep rider app in foreground during the map segment.
- Ensure notification and location permissions are enabled on rider app.
- If dispatch misses riders because of range filtering, enable your demo radius flag.
