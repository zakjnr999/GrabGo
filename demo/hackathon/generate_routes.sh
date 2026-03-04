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

# Route density/speed tuning (override with env vars if needed)
RIDER_POINTS="${ROUTE_POINTS_RIDER:-90}"
DELIVERY_POINTS="${ROUTE_POINTS_DELIVERY:-110}"
RIDER_STEP_SECONDS="${ROUTE_STEP_SECONDS_RIDER:-5}"
DELIVERY_STEP_SECONDS="${ROUTE_STEP_SECONDS_DELIVERY:-5}"

# Branching amount to avoid dead-straight lines (in coordinate units)
RIDER_WIGGLE="${ROUTE_WIGGLE_RIDER:-0.00022}"
DELIVERY_WIGGLE="${ROUTE_WIGGLE_DELIVERY:-0.00018}"
RIDER_WAVES="${ROUTE_WAVES_RIDER:-5}"
DELIVERY_WAVES="${ROUTE_WAVES_DELIVERY:-6}"

NOW_EPOCH="$(date -u +%s)"
RIDER_START_EPOCH="$NOW_EPOCH"
RIDER_DURATION_SECONDS=$(( (RIDER_POINTS - 1) * RIDER_STEP_SECONDS ))
DELIVERY_START_EPOCH=$(( RIDER_START_EPOCH + RIDER_DURATION_SECONDS + 60 ))

iso_utc() {
  date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ'
}

generate_trkpts() {
  local from_lat="$1"
  local from_lon="$2"
  local to_lat="$3"
  local to_lon="$4"
  local points="$5"
  local start_epoch="$6"
  local step_seconds="$7"
  local wiggle="$8"
  local waves="$9"

  awk \
    -v slat="$from_lat" \
    -v slon="$from_lon" \
    -v elat="$to_lat" \
    -v elon="$to_lon" \
    -v points="$points" \
    -v start_epoch="$start_epoch" \
    -v step_seconds="$step_seconds" \
    -v wiggle="$wiggle" \
    -v waves="$waves" \
    'BEGIN {
      ENVIRON["TZ"] = "UTC";
      pi = atan2(0, -1);
      if (points < 2) points = 2;
      dx = elon - slon;
      dy = elat - slat;
      len = sqrt(dx * dx + dy * dy);
      if (len == 0) {
        len = 1;
      }

      for (i = 0; i < points; i++) {
        t = i / (points - 1);

        # Base interpolation
        base_lon = slon + (dx * t);
        base_lat = slat + (dy * t);

        # Perpendicular unit vector for subtle route bends
        per_lon = -dy / len;
        per_lat = dx / len;

        # Keep endpoints anchored; bend strongest mid-route
        envelope = sin(pi * t);
        offset = wiggle * sin((waves * pi) * t) * envelope;

        lon = base_lon + (per_lon * offset);
        lat = base_lat + (per_lat * offset);

        timestamp = start_epoch + (i * step_seconds);
        iso = strftime("%Y-%m-%dT%H:%M:%SZ", timestamp);

        printf "      <trkpt lat=\"%.7f\" lon=\"%.7f\"><time>%s</time></trkpt>\n", lat, lon, iso;
      }
    }'
}

{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="GrabGo Hackathon Demo Generator" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>GrabGo Rider to Vendor (Custom)</name>
    <desc>Auto-generated route from rider start to pickup.</desc>
    <time>$(iso_utc "$RIDER_START_EPOCH")</time>
  </metadata>
  <wpt lat="$START_LAT" lon="$START_LON"><name>Rider Start</name></wpt>
  <wpt lat="$PICKUP_LAT" lon="$PICKUP_LON"><name>Vendor Pickup</name></wpt>
  <trk>
    <name>Rider to Vendor (Custom)</name>
    <trkseg>
EOF
  generate_trkpts \
    "$START_LAT" \
    "$START_LON" \
    "$PICKUP_LAT" \
    "$PICKUP_LON" \
    "$RIDER_POINTS" \
    "$RIDER_START_EPOCH" \
    "$RIDER_STEP_SECONDS" \
    "$RIDER_WIGGLE" \
    "$RIDER_WAVES"
  cat <<EOF
    </trkseg>
  </trk>
</gpx>
EOF
} > "$RIDER_OUT"

{
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="GrabGo Hackathon Demo Generator" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>GrabGo Vendor to Customer (Custom)</name>
    <desc>Auto-generated route from pickup to dropoff.</desc>
    <time>$(iso_utc "$DELIVERY_START_EPOCH")</time>
  </metadata>
  <wpt lat="$PICKUP_LAT" lon="$PICKUP_LON"><name>Vendor Pickup</name></wpt>
  <wpt lat="$DROP_LAT" lon="$DROP_LON"><name>Customer Dropoff</name></wpt>
  <trk>
    <name>Vendor to Customer (Custom)</name>
    <trkseg>
EOF
  generate_trkpts \
    "$PICKUP_LAT" \
    "$PICKUP_LON" \
    "$DROP_LAT" \
    "$DROP_LON" \
    "$DELIVERY_POINTS" \
    "$DELIVERY_START_EPOCH" \
    "$DELIVERY_STEP_SECONDS" \
    "$DELIVERY_WIGGLE" \
    "$DELIVERY_WAVES"
  cat <<EOF
    </trkseg>
  </trk>
</gpx>
EOF
} > "$DELIVERY_OUT"

echo "Generated:"
echo "  $RIDER_OUT"
echo "  $DELIVERY_OUT"
echo "Route settings:"
echo "  Rider leg: points=$RIDER_POINTS, step=${RIDER_STEP_SECONDS}s, duration=$(( (RIDER_POINTS - 1) * RIDER_STEP_SECONDS ))s"
echo "  Delivery leg: points=$DELIVERY_POINTS, step=${DELIVERY_STEP_SECONDS}s, duration=$(( (DELIVERY_POINTS - 1) * DELIVERY_STEP_SECONDS ))s"
