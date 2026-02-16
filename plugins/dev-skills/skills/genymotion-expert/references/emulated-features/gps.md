# GPS and Location

The GPS widget simulates the device's location provider, replacing real satellite positioning data.

> **Cross-references:** For sensor persistence rules and reset scripts, see `sensor-management.md`. For feature availability, see `index.md`. For CI route playback recipe, see `ci-and-recipes.md` Recipe 5.

## Parameters

| Parameter | Range | Unit | Shell Command |
|-----------|-------|------|---------------|
| Latitude | -90 to 90 | degrees | `gps setlatitude` |
| Longitude | -180 to 180 | degrees | `gps setlongitude` |
| Altitude | -10000 to 10000 | meters | `gps setaltitude` |
| Speed | 0 to 99999.99 | m/s | GUI only |
| Accuracy | 0 to 200 | meters | `gps setaccuracy` |
| Bearing | 0 to 359.99 | degrees | `gps setbearing` |

## Route Simulation (v3.3.0+, Paid)

The GUI supports GPX and KML file import for route playback with play/pause and adjustable speed.

**Supported file formats:**
- **GPX** (`<trkpt>` elements with `lat`/`lon` attributes)
- **KML** (Keyhole Markup Language, Google Earth format)

**GPX file requirements:**
- Minimum: latitude and longitude per trackpoint (`<trkpt lat="..." lon="...">`)
- Elevation: defaults to 0m if missing from file
- Timestamps: auto-incremented by 1 second if absent
- Ordering: Genymotion sorts points chronologically regardless of file order

**CLI route simulation**: GPX route playback is GUI-only. Simulate via scripted sequential commands — see `ci-and-recipes.md` Recipe 5 for a complete GPX parser script.

**Script-based GPS animation** (for CI/CD):
```bash
#!/usr/bin/env bash
# Read GPX waypoints and update GPS at realistic intervals
# Adjust INTERVAL for simulated speed (lower = faster movement)
INTERVAL=2  # seconds between updates

genyshell -q -c "gps setstatus enabled"
# Example: simulate walking a city block
coords=(
    "40.7128 -74.0060"   # Start
    "40.7130 -74.0058"   # Step 1
    "40.7132 -74.0055"   # Step 2
    "40.7135 -74.0052"   # Step 3
)
for coord in "${coords[@]}"; do
    read -r lat lon <<< "$coord"
    genyshell -q -c "gps setlatitude $lat"
    genyshell -q -c "gps setlongitude $lon"
    sleep "$INTERVAL"
done
```

**Tip**: For realistic movement, calculate the pause between updates based on the distance between waypoints and the desired speed. Abrupt coordinate jumps (no pause) cause "teleportation" that location-aware apps may reject or flag as GPS spoofing.

## Testing Patterns

**Geofencing validation:**
```bash
# Move device inside geofence boundary
genyshell -q -c "gps setlatitude 37.7749"
genyshell -q -c "gps setlongitude -122.4194"
sleep 3  # Allow geofence trigger
# Verify app received geofence entry event

# Move outside geofence
genyshell -q -c "gps setlatitude 37.8000"
genyshell -q -c "gps setlongitude -122.4500"
sleep 3  # Allow geofence exit event
```

**GPS accuracy degradation** (urban canyon scenario):
```bash
genyshell -q -c "gps setaccuracy 5"    # High accuracy (open sky)
sleep 5
genyshell -q -c "gps setaccuracy 50"   # Moderate (suburban)
sleep 5
genyshell -q -c "gps setaccuracy 200"  # Poor (downtown canyon)
```

**Bearing-based navigation:**
```bash
# Simulate heading north at known position
genyshell -q -c "gps setbearing 0"      # North
genyshell -q -c "gps setbearing 90"     # East
genyshell -q -c "gps setbearing 180"    # South
genyshell -q -c "gps setbearing 270"    # West
```

**Limitation**: Many apps use accelerometer/gyroscope for bearing rather than GPS bearing. If the app's compass does not respond to `gps setbearing`, it requires motion sensor data instead — see `gui-features.md` Motion Sensors section or use Device Link to forward real phone sensors.
