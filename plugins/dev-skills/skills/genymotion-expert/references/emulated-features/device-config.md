# Device Configuration

Device-level configuration features: Device Identity, Disk I/O Throttling, and Rotation.

> **Cross-references:** For sensor persistence rules and reset scripts, see `sensor-management.md`. For motion sensors and continuous rotation, see `gui-features.md`.

---

## Device Identity

The Identifiers widget controls the device's Android ID and Device ID (IMEI/MEID).

### Parameters

| Identifier | Description | Validation | Shell Command |
|------------|-------------|-----------|---------------|
| Android ID | Unique 64-bit hex | 16 hex characters `[0-9a-f]` | `android setandroidid` |
| Device ID | IMEI or MEID | GSM 02.16 compliant, chars: `[a-zA-Z0-9._-]` + checksum | `android setdeviceid` |

### Key Behaviors

- **Default Device ID**: `000000000000000` (all zeros)
- **Android ID caveat**: Genymotion reports the same Android ID across all apps. On real devices running Android 8.0+, each app gets a unique Android ID scoped to the signing key. Apps relying on per-app Android ID uniqueness will behave differently on Genymotion
- **No reboot required**: Identity changes take effect immediately

### Shell Commands

```bash
android version                                  # Android OS version
android getandroidid                             # Current Android ID
android setandroidid random                      # Generate random ID
android setandroidid custom 0123456789abcdef     # Set specific ID (16 hex digits)
android getdeviceid                              # Current IMEI/MEID
android setdeviceid random                       # Generate random ID
android setdeviceid none                         # Clear device ID
android setdeviceid custom 123456789012345       # Set specific IMEI
```

### Testing Patterns

**Parallel testing identity isolation:**
```bash
# After cloning a device, randomize identifiers to avoid backend conflicts
genyshell -r "$CLONE_IP" -c "android setandroidid random"
genyshell -r "$CLONE_IP" -c "android setdeviceid random"
```

**OEM-specific code path testing** (combine with `--sysprop`):
```bash
# Create a device that identifies as a specific model
gmtool admin create "Custom Phone" "Android 13.0" "FakePixel" \
  --sysprop MODEL:Pixel_7 --sysprop BRAND:google --sysprop MANUFACTURER:Google
# Then set a matching device ID pattern
genyshell -q -c "android setdeviceid custom 358240051111110"
```

---

## Disk I/O Throttling

The Disk I/O widget simulates storage performance of different device tiers.

### Preset Profiles

| Profile | Read Rate | Use Case |
|---------|-----------|----------|
| High-end device | 200 MiB/s | Flagship phone baseline |
| Mid-range device | 100 MiB/s | Average user experience |
| Low-end device | 50 MiB/s | Budget device testing |
| Custom | User-defined MiB/s | Specific scenarios |

### Shell Commands

```bash
diskio setreadratelimit <1-2097151>    # Set limit in KB/sec (0 = unlimited)
diskio getreadratelimit                 # Current limit
diskio clearcache                       # Clear disk cache (forces re-read from disk)
```

**Unit conversion**: The GUI shows MiB/s, but the shell uses **KB/sec**.
- High-end (200 MiB/s) = `diskio setreadratelimit 204800`
- Mid-range (100 MiB/s) = `diskio setreadratelimit 102400`
- Low-end (50 MiB/s) = `diskio setreadratelimit 51200`

**Cache behavior**: Switching profiles via the GUI automatically clears the disk cache. When using shell commands, call `diskio clearcache` manually after changing the rate limit to get accurate measurements.

### Testing Patterns

**App launch time on slow storage:**
```bash
# Simulate low-end device
genyshell -q -c "diskio setreadratelimit 51200"
genyshell -q -c "diskio clearcache"
# Launch app and measure cold start time
adb shell am start -W com.example.app/.MainActivity
# Output includes TotalTime (ms) for launch duration
```

**Database operation performance:**
```bash
# Test with constrained I/O
genyshell -q -c "diskio setreadratelimit 25600"   # 25 MiB/s (very slow)
genyshell -q -c "diskio clearcache"
# Run database-heavy test suite
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.annotation=com.example.test.DatabaseTest
```

**Restore unlimited I/O:**
```bash
genyshell -q -c "diskio setreadratelimit 0"
```

---

## Rotation

The Rotation feature provides discrete screen orientation changes.

### Available Angles

| Angle | Orientation | Display |
|-------|-------------|---------|
| 0 | Portrait | Default upright |
| 90 | Landscape left | Rotated 90 counterclockwise |
| 180 | Portrait inverted | Upside down |
| 270 | Landscape right | Rotated 90 clockwise |

```bash
rotation setangle 0|90|180|270
```

### Relationship with Motion Sensors

- `rotation setangle` provides **discrete** orientation changes (four positions only)
- The **Motion Sensors widget** (v3.8.0+) provides **continuous** orientation via yaw/pitch/roll
- When **Enable emulator window rotation** is toggled in the Motion Sensors widget, the display rotates based on accelerometer data rather than discrete angle commands
- For automated orientation testing in CI, use `rotation setangle` (scriptable). For realistic orientation behavior, use Motion Sensors widget or Device Link

### Testing Patterns

**Configuration change survival:**
```bash
# Verify activity/fragment survives rotation
genyshell -q -c "rotation setangle 0"
sleep 2
# Fill in a form, start a process
genyshell -q -c "rotation setangle 90"
sleep 2
# Verify form data is preserved, process continues
genyshell -q -c "rotation setangle 0"
sleep 2
# Verify return to original state
```

**Orientation-locked apps:**
```bash
# Set landscape
genyshell -q -c "rotation setangle 90"
# If app is portrait-locked, verify it does not rotate
# If app is landscape-only (game), verify correct behavior
```
