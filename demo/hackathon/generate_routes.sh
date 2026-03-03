#!/usr/bin/env bash
set -euo pipefail

# Generates custom GPX route files for hackathon playback.
# Usage:
#   ./generate_routes.sh START_LAT START_LON PICKUP_LAT PICKUP_LON DROP_LAT DROP_LON
# Example:
#   ./generate_routes.sh 5.5646133 -0.1823567 5.6037 -0.1870 5.57457729677039 -0.215160772204399

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 START_LAT START_LON PICKUP_LAT PICKUP_LON DROP_LAT DROP_LON"
  exit 1
fi

START_LAT="$1"
START_LON="$2"
PICKUP_LAT="$3"
PICKUP_LON="$4"
DROP_LAT="$5"
DROP_LON="$6"

OUT_DIR="$(cd "$(dirname "$0")" && pwd)"

RIDER_OUT="$OUT_DIR/rider_to_vendor_custom.gpx"
DELIVERY_OUT="$OUT_DIR/vendor_to_customer_custom.gpx"

cat > "$RIDER_OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="GrabGo Hackathon Demo Generator" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>GrabGo Rider to Vendor (Custom)</name>
    <desc>Auto-generated route from rider start to pickup.</desc>
    <time>2026-03-03T10:00:00Z</time>
  </metadata>
  <wpt lat="$START_LAT" lon="$START_LON"><name>Rider Start</name></wpt>
  <wpt lat="$PICKUP_LAT" lon="$PICKUP_LON"><name>Vendor Pickup</name></wpt>
  <trk>
    <name>Rider to Vendor (Custom)</name>
    <trkseg>
      <trkpt lat="$START_LAT" lon="$START_LON"><time>2026-03-03T10:00:00Z</time></trkpt>
      <trkpt lat="$(awk -v a="$START_LAT" -v b="$PICKUP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.18}')" lon="$(awk -v a="$START_LON" -v b="$PICKUP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.18 - 0.00050}')"><time>2026-03-03T10:00:20Z</time></trkpt>
      <trkpt lat="$(awk -v a="$START_LAT" -v b="$PICKUP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.36}')" lon="$(awk -v a="$START_LON" -v b="$PICKUP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.36 + 0.00035}')"><time>2026-03-03T10:00:40Z</time></trkpt>
      <trkpt lat="$(awk -v a="$START_LAT" -v b="$PICKUP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.52}')" lon="$(awk -v a="$START_LON" -v b="$PICKUP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.52 - 0.00040}')"><time>2026-03-03T10:01:00Z</time></trkpt>
      <trkpt lat="$(awk -v a="$START_LAT" -v b="$PICKUP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.70}')" lon="$(awk -v a="$START_LON" -v b="$PICKUP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.70 + 0.00025}')"><time>2026-03-03T10:01:20Z</time></trkpt>
      <trkpt lat="$(awk -v a="$START_LAT" -v b="$PICKUP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.86}')" lon="$(awk -v a="$START_LON" -v b="$PICKUP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.86 - 0.00015}')"><time>2026-03-03T10:01:40Z</time></trkpt>
      <trkpt lat="$PICKUP_LAT" lon="$PICKUP_LON"><time>2026-03-03T10:02:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
EOF

cat > "$DELIVERY_OUT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="GrabGo Hackathon Demo Generator" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>GrabGo Vendor to Customer (Custom)</name>
    <desc>Auto-generated route from pickup to dropoff.</desc>
    <time>2026-03-03T10:10:00Z</time>
  </metadata>
  <wpt lat="$PICKUP_LAT" lon="$PICKUP_LON"><name>Vendor Pickup</name></wpt>
  <wpt lat="$DROP_LAT" lon="$DROP_LON"><name>Customer Dropoff</name></wpt>
  <trk>
    <name>Vendor to Customer (Custom)</name>
    <trkseg>
      <trkpt lat="$PICKUP_LAT" lon="$PICKUP_LON"><time>2026-03-03T10:10:00Z</time></trkpt>
      <trkpt lat="$(awk -v a="$PICKUP_LAT" -v b="$DROP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.15}')" lon="$(awk -v a="$PICKUP_LON" -v b="$DROP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.15 + 0.00040}')"><time>2026-03-03T10:10:20Z</time></trkpt>
      <trkpt lat="$(awk -v a="$PICKUP_LAT" -v b="$DROP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.32}')" lon="$(awk -v a="$PICKUP_LON" -v b="$DROP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.32 - 0.00030}')"><time>2026-03-03T10:10:40Z</time></trkpt>
      <trkpt lat="$(awk -v a="$PICKUP_LAT" -v b="$DROP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.49}')" lon="$(awk -v a="$PICKUP_LON" -v b="$DROP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.49 + 0.00025}')"><time>2026-03-03T10:11:00Z</time></trkpt>
      <trkpt lat="$(awk -v a="$PICKUP_LAT" -v b="$DROP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.66}')" lon="$(awk -v a="$PICKUP_LON" -v b="$DROP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.66 - 0.00020}')"><time>2026-03-03T10:11:20Z</time></trkpt>
      <trkpt lat="$(awk -v a="$PICKUP_LAT" -v b="$DROP_LAT" 'BEGIN{printf "%.7f", a + (b-a)*0.83}')" lon="$(awk -v a="$PICKUP_LON" -v b="$DROP_LON" 'BEGIN{printf "%.7f", a + (b-a)*0.83 + 0.00015}')"><time>2026-03-03T10:11:40Z</time></trkpt>
      <trkpt lat="$DROP_LAT" lon="$DROP_LON"><time>2026-03-03T10:12:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
EOF

echo "Generated:"
echo "  $RIDER_OUT"
echo "  $DELIVERY_OUT"
