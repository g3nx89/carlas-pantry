# Emulated Features Reference

Comprehensive guide to all emulated sensors and features in Genymotion Desktop. Covers configuration, Genymotion Shell commands, testing patterns, and feature availability.

> **Note:** For the complete Genymotion Shell and GMTool command syntax, see `cli-reference.md`. For CI/CD recipes using these features, see `ci-and-recipes.md`.

## Feature Availability Matrix

Not all features are available on all versions or license tiers. Use this matrix to verify availability before relying on a feature.

| Feature | Min Version | License Required | Android Req | Shell Commands |
|---------|------------|-----------------|-------------|----------------|
| GPS | All | Free | All | Yes |
| Battery | All | Free | All | Yes |
| Rotation | All | Free | All | Yes |
| Device Identity | All | Free | All | Yes |
| Network (WiFi/Mobile) | 3.3.0+ | Paid | 8.0+ (full) | Yes |
| Baseband (SIM/operator) | 3.5.0+ | Paid | All | No (GUI only) |
| Camera/Media Injection | 3.3.0+ | Paid | All | No (GUI only) |
| Disk I/O Throttling | 3.3.0+ | Paid | All | Yes |
| Phone/SMS | All | Free | All | Yes |
| Advanced Developer Tools | 3.4.0+ | Paid | All | No (GUI only) |
| Biometrics (Fingerprint) | 3.6.0+ | Paid | 13+ | No (GUI only) |
| Gamepad | 3.8.0+ | Paid | 12+ | No (GUI only) |
| Motion Sensors | 3.8.0+ | Paid | All | No (GUI only) |
| Device Link | 3.8.0+ | Paid | All | No (GUI only) |
| Capture (Screenshot/Video) | All | Free | All | No (use ADB) |

**Key**: "Shell Commands" = automatable via `genyshell`. Features marked "GUI only" require the Genymotion Desktop UI widgets and cannot be scripted through Genymotion Shell. For automation of GUI-only features, use ADB alternatives where available (noted per feature below).

---

## GPS and Location

The GPS widget simulates the device's location provider, replacing real satellite positioning data.

### Parameters

| Parameter | Range | Unit | Shell Command |
|-----------|-------|------|---------------|
| Latitude | -90 to 90 | degrees | `gps setlatitude` |
| Longitude | -180 to 180 | degrees | `gps setlongitude` |
| Altitude | -10000 to 10000 | meters | `gps setaltitude` |
| Speed | 0 to 99999.99 | m/s | GUI only |
| Accuracy | 0 to 200 | meters | `gps setaccuracy` |
| Bearing | 0 to 359.99 | degrees | `gps setbearing` |

### Route Simulation (v3.3.0+, Paid)

The GUI supports GPX and KML file import for route playback with play/pause and adjustable speed.

**GPX file requirements:**
- Minimum: latitude and longitude per trackpoint (`<trkpt lat="..." lon="...">`)
- Elevation: defaults to 0m if missing from file
- Timestamps: auto-incremented by 1 second if absent
- Ordering: Genymotion sorts points chronologically regardless of file order

**CLI route simulation**: GPX route playback is GUI-only. Simulate via scripted sequential commands — see `ci-and-recipes.md` Recipe 5 for a complete GPX parser script.

### Testing Patterns

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

**Limitation**: Many apps use accelerometer/gyroscope for bearing rather than GPS bearing. If the app's compass does not respond to `gps setbearing`, it requires motion sensor data instead — see Motion Sensors section below or use Device Link to forward real phone sensors.

---

## Battery

The Battery widget controls the power state reported to the Android system.

### Modes

| Mode | Behavior |
|------|----------|
| `host` | Battery level and state mirror the host computer |
| `manual` | Full developer control over level and state |

### States

| State | Description | Testing Use Case |
|-------|-------------|-----------------|
| `discharging` | Battery draining, no power source | Background task throttling, JobScheduler behavior |
| `charging` | Connected to charger, actively charging | Data sync triggers, battery-optimized features re-enabling |
| `notcharging` | Power connected but not charging | Thermal management testing |
| `full` | Battery at 100%, power connected | Charge completion notifications |

### Critical Thresholds to Test

| Level | Android Behavior | What to Verify |
|-------|-----------------|----------------|
| 100% | Full charge | Charge complete notification |
| 15% | Low battery warning | App's power-saving mode activation |
| 5% | Critical battery | Feature degradation, data persistence |
| 1% | Imminent shutdown | Graceful state saving |
| 0% | Device may shut down | N/A (device behavior varies) |

### Shell Script Pattern

```bash
# Test progressive battery drain
for level in 100 75 50 25 15 10 5 1; do
    genyshell -q -c "battery setmode manual"
    genyshell -q -c "battery setlevel $level"
    genyshell -q -c "battery setstatus discharging"
    sleep 3
    # Capture app state at this level
    adb shell screencap "/sdcard/battery_${level}.png"
done

# Test charging transition
genyshell -q -c "battery setlevel 10"
genyshell -q -c "battery setstatus discharging"
sleep 3
genyshell -q -c "battery setstatus charging"
sleep 3
# Verify app re-enables features disabled at low battery
```

### ADB Verification

Confirm Genymotion Shell battery simulation is active:
```bash
adb shell dumpsys battery
# Look for: level, status, AC powered, USB powered
```

---

## Network

The Network widget (v3.3.0+, paid) simulates WiFi and mobile data interfaces with configurable profiles.

### Interface Control

```bash
# Toggle interfaces
network setstatus wifi enabled|disabled
network setstatus mobile enabled|disabled

# Signal strength per interface
network setsignalstrength wifi|mobile none|poor|moderate|good|great
```

### Mobile Network Profiles

| Profile | Download | Upload | Latency | Packet Loss | Use Case |
|---------|----------|--------|---------|-------------|----------|
| `gsm` (2G) | 14 Kb/s | 14 Kb/s | 500ms | 0% | Extreme degradation testing |
| `gprs` (2G) | 57 Kb/s | 28 Kb/s | 300ms | 0% | Minimal data connectivity |
| `edge` (2G) | 236 Kb/s | 236 Kb/s | 75ms | 0% | Slow mobile testing |
| `umts` (3G) | 384 Kb/s | 384 Kb/s | 75ms | 0% | Standard 3G experience |
| `hsdpa` (3G+) | 13.98 Mb/s | 5.76 Mb/s | 0ms | 10% | Fast 3G with packet loss |
| `lte` (4G) | 173 Mb/s | 58 Mb/s | 5ms | 0% | Modern mobile baseline |
| `5g` | 1174 Mb/s | 211 Mb/s | 5ms | 0% | High-speed mobile |

```bash
network setmobileprofile none|gsm|gprs|edge|umts|hsdpa|lte|5g
```

### Legacy API (Android 7.1 and below)

```bash
network setprofile no-data|gprs|edge|3g|4g|4g-high-losses|4g-bad-dns|wifi
```

### Signal Strength Levels

| Level | Meaning | UI Effect |
|-------|---------|-----------|
| `great` | Excellent signal | Full bars |
| `good` | Normal signal | 3-4 bars |
| `moderate` | Degraded | 2 bars |
| `poor` | Weak | 1 bar |
| `none` | No signal | 0 bars, may show "No Service" |

### Testing Patterns

**Offline mode:**
```bash
genyshell -q -c "network setstatus wifi disabled"
genyshell -q -c "network setstatus mobile disabled"
# Verify: offline banner, cached data, retry mechanisms
```

**WiFi to mobile handoff:**
```bash
genyshell -q -c "network setstatus wifi enabled"
genyshell -q -c "network setsignalstrength wifi great"
sleep 5
genyshell -q -c "network setstatus wifi disabled"
genyshell -q -c "network setstatus mobile enabled"
genyshell -q -c "network setmobileprofile lte"
# Verify: seamless transition, no data loss, UI update
```

**Limitation**: Mobile data is simulated at the interface level — no real baseband or SIM data connection. The network profile controls bandwidth shaping but not actual radio behavior. Sufficient for testing UI states and basic connectivity logic, but not radio-level behavior.

---

## Baseband (v3.5.0+, Paid)

The Baseband widget simulates SIM card and network operator data. GUI-only — not available via Genymotion Shell.

### Configurable Parameters

**Network Operator:**
| Field | Description | Example |
|-------|-------------|---------|
| MCC | Mobile Country Code | 310 (US), 222 (Italy), 208 (France) |
| MNC | Mobile Network Code | 260 (T-Mobile US), 01 (TIM), 01 (Orange) |
| Operator Name | Display name | "T-Mobile", "Vodafone" |

**SIM Operator:**
| Field | Description | Example |
|-------|-------------|---------|
| MCC/MNC | SIM issuer codes | Same format as network operator |
| MSIN | Mobile Subscriber ID Number | Unique subscriber identifier |
| Operator Name | SIM provider name | "AT&T", "Three" |
| Phone Number | Simulated phone number | "+1234567890" |

### Testing Patterns

**Roaming detection**: Set network operator MCC/MNC to a different country than the SIM operator to simulate roaming. Verify the app:
- Shows roaming indicator
- Reduces data usage or warns user
- Switches to offline-first mode if configured

**Multi-carrier testing**: Change operator name and MCC/MNC to test carrier-specific features (Wi-Fi calling labels, operator-branded notifications).

**ADB alternative** for basic GSM state control (automatable):
```bash
# Voice registration state (home, roaming, searching, denied)
genyshell -q -c "phone baseband gsm voice roaming"
genyshell -q -c "phone baseband gsm voice home"

# Data registration state
genyshell -q -c "phone baseband gsm data home"
```

**Limitation**: Virtual devices do not have a real phone number. The simulated phone number in the Baseband widget is metadata only — it does not enable actual calls or SMS.

---

## Motion Sensors (v3.8.0+, Paid)

The Motion Sensors widget emulates the Android sensor stack: accelerometer, gyroscope, and magnetometer. This was previously listed as unsimulatable.

### Input Methods

**Manual control via sliders:**
| Axis | Range | Unit |
|------|-------|------|
| Yaw | -180 to 180 | degrees |
| Pitch | -180 to 180 | degrees |
| Roll | -180 to 180 | degrees |

**Device rotation field**: Select a specific rotation angle for the device orientation.

**3D model manipulation**: Drag the interactive 3D device model to set orientation visually. The model updates in real-time and reflects the yaw/pitch/roll values.

### Sensor Readouts

The widget displays computed values for all three sensor types:

| Sensor | What It Measures | Typical Use |
|--------|-----------------|-------------|
| Accelerometer | Linear acceleration including gravity (m/s^2) | Shake detection, step counting, tilt |
| Gyroscope | Angular velocity (rad/s) | Rotation detection, VR head tracking |
| Magnetometer | Magnetic field strength (uT) | Compass heading, indoor navigation |

Values update in real-time as you manipulate the yaw/pitch/roll sliders or 3D model.

### Emulator Window Rotation Sync

When **Enable emulator window rotation** is toggled on, the emulator display rotates to match the simulated device orientation. This mirrors real device behavior where screen content reorients based on accelerometer data.

**Testing tip**: Use this to verify that your app's orientation lock or responsive layout behaves correctly during physical rotation, not just discrete `rotation setangle` changes.

### Device Link (Physical Device Sensor Forwarding)

Device Link (v3.8.0+) forwards real sensor data from a physical Android device to the emulator:

**Forwarded sensors:**
- Accelerometer
- Gyroscope
- Magnetometer

**Setup:**
1. Connect a physical Android device to the host via USB
2. Enable USB debugging on the physical device
3. In the Motion Sensors widget, click **Setup device link**
4. The physical device appears in "Available devices" — click **LINK DEVICE**
5. Once linked, the 3D model syncs with the physical device's orientation in real-time

**Calibration**: After linking, the emulator calibrates its reference frame to the physical device's current orientation. Hold the physical device steady during initial calibration for best results.

**Disconnection**: Unlink by clicking the linked device entry. Sensor values freeze at the last received state.

### Automation Considerations

Motion Sensors are **GUI-only** — no Genymotion Shell commands exist. For automated testing:

**Option 1 — Discrete rotation** (limited but automatable):
```bash
genyshell -q -c "rotation setangle 0"    # Portrait
genyshell -q -c "rotation setangle 90"   # Landscape left
genyshell -q -c "rotation setangle 180"  # Portrait inverted
genyshell -q -c "rotation setangle 270"  # Landscape right
```

**Option 2 — Mock SensorManager in test code**:
```kotlin
// For continuous motion testing, mock at the Android API level
// in instrumented tests when Genymotion Shell is insufficient
@Test
fun testShakeDetection() {
    // Use SensorManager test APIs or custom test doubles
    // to inject accelerometer events programmatically
}
```

**Option 3 — Device Link**: Connect a physical device and physically manipulate it. Best for manual QA validation of motion-heavy features (AR, compass, games).

### Testing Patterns

**Compass app testing**: Use yaw slider (0=North, 90=East, 180=South, 270=West) and verify compass needle or heading display.

**Tilt-based UI**: Adjust pitch and roll to test features that respond to device tilt (e.g., panoramic photo viewers, level tools).

**Shake detection**: Rapidly toggle accelerometer values via the 3D model to simulate device shake. Verify the app triggers shake-to-undo or shake-to-refresh.

---

## Biometrics (v3.6.0+, Android 13+, Paid)

The Biometrics widget simulates fingerprint recognition scenarios for testing `BiometricPrompt` and fingerprint-gated features.

### Setup (Required Before Use)

1. Open **Settings > Security & Privacy** in the emulator
2. Set up a screen lock (PIN or pattern) if not already configured
3. Navigate to **Fingerprint** and tap **Add fingerprint**
4. Use the Biometrics widget in the Genymotion toolbar to simulate a finger touch during enrollment
5. Complete enrollment (typically requires multiple simulated touches)

**Auto-validation shortcut**: Toggle **Automatically validate biometric authentication** in the widget to auto-respond with "Recognized" during fingerprint enrollment, speeding up the setup process.

### Fingerprint Scenarios

| Scenario | Behavior | Testing Use Case |
|----------|----------|-----------------|
| **Recognized** | Fingerprint matches enrolled print | Happy path authentication |
| **Unrecognized** | Fingerprint does not match | Error handling, retry prompts, lockout after N failures |
| **Dirty** | Sensor reports dirty finger | Sensor cleaning prompt, UX guidance |
| **Partial** | Only partial fingerprint captured | Repositioning guidance, partial match handling |
| **Insufficient** | Quality too low for recognition | Quality feedback to user |
| **Too Fast** | Finger removed before capture completes | "Hold finger longer" messaging |

### Testing Patterns

**Authentication flow:**
1. Launch the app feature requiring biometric auth
2. Wait for the `BiometricPrompt` dialog to appear
3. Click the desired scenario in the Biometrics widget
4. Verify the app handles the result correctly

**Lockout testing:**
1. Trigger multiple "Unrecognized" fingerprint events in sequence
2. Verify the app shows the lockout message after the system-defined threshold
3. Verify fallback to PIN/password is offered

**Graceful degradation:**
1. Test on Android 12 image (biometrics widget unavailable)
2. Verify the app falls back to PIN/password authentication
3. Test on Android 13+ with biometrics widget for full flow

### Automation Considerations

Biometrics are **GUI-only** — no Genymotion Shell commands exist. For automated testing:

**Option 1 — BiometricPrompt test APIs** (recommended for CI):
```kotlin
// Use AndroidX Biometric testing library
androidTestImplementation("androidx.biometric:biometric:1.2.0-alpha05")

// In test code, use the CryptoObject mock or
// BiometricPrompt.AuthenticationCallback test doubles
```

**Option 2 — ADB keyevent injection** (fragile, position-dependent):
```bash
# Not recommended — depends on widget position and resolution
```

**Option 3 — Manual QA via GUI**: Click widget scenarios during exploratory testing sessions.

---

## Camera and Media Injection (v3.3.0+, Paid)

The Camera and Media Injection widget replaces the virtual device's camera and microphone inputs with host resources or media files.

### Video Input Sources

| Source | Front Camera | Back Camera | Notes |
|--------|-------------|-------------|-------|
| Host webcam | Yes | Yes | Any connected webcam device |
| Image file | Yes | Yes | Static image displayed as camera feed |
| Video file | Yes | Yes | Plays as camera feed |

### Audio Input Sources

| Source | Notes |
|--------|-------|
| Host microphone | Default system mic |
| Audio file | Plays as microphone input |

### Resize Modes

When injecting media files, the content may not match the virtual camera resolution. Resize modes control adaptation:

| Mode | Behavior | Best For |
|------|----------|----------|
| **Crop** | Fills frame, clips overflow | QR code scanning (image fills viewport) |
| **Keep Aspect** | Fits within frame, letterboxed | General testing (no distortion) |
| **Resize** | Stretches to fill frame | When exact resolution match matters |

### Media File Storage Paths

Media files placed in these directories are available in the injection widget:

| OS | Path |
|----|------|
| Windows | `%LOCALAPPDATA%\Genymobile\Genymotion\media` |
| Linux | `$HOME/.Genymobile/Genymotion/media` |
| macOS | `$HOME/Applications/Genymotion.app/Contents/MacOS/media` |

### Codec Requirements

- **Linux/macOS**: Most formats work out of the box
- **Windows**: Genymotion Desktop does not bundle codecs. Install [K-Lite Codec Pack Full](https://codecguide.com/download_kl.htm) or equivalent for video/audio playback

### Persistence

Since **v3.6.0**, camera input settings persist across virtual device restarts. Set once and the configuration survives reboots.

### Testing Patterns

**QR code / barcode scanning:**
1. Save the QR code as a PNG file
2. Place it in the media directory (see paths above)
3. In the Camera widget, assign the PNG to the back camera
4. Select **Crop** resize mode for full-frame display
5. Open the app's scanner — the QR code image appears as the camera feed

**Facial recognition:**
1. Prepare a face image that matches your test dataset
2. Assign to front camera with **Keep Aspect** mode
3. Test the app's face detection flow

**AR app testing:**
1. Assign a video file showing a real-world surface to the back camera
2. Test marker detection and overlay rendering
3. Limitation: no depth data — AR features requiring depth (LiDAR, ToF) cannot be tested

**Voice command testing:**
1. Record command audio files (WAV or MP3)
2. Assign as microphone input
3. Test the app's speech recognition pipeline

### Automation Considerations

Camera/Media Injection is **GUI-only** — no Genymotion Shell or GMTool commands exist. For automated testing:

**ADB push for camera images:**
```bash
# Push a QR code image to the device storage
adb push qr_code.png /sdcard/DCIM/Camera/

# The app can then open the image from storage
# (different from live camera feed, but useful for some test scenarios)
```

**Mocking CameraX/Camera2 in tests** (recommended for CI):
```kotlin
// Use CameraX test utilities or mock the camera provider
// to inject test images programmatically in instrumented tests
```

---

## Phone and SMS

The Phone widget simulates incoming calls and text messages. Messages appear as notifications and in the Messaging app.

### Basic Commands

```bash
# Incoming call (shows call screen with caller number)
phone call "+1234567890"

# Incoming SMS (appears in notification and Messaging app)
phone sms "+1234567890" "Your OTP is 123456"
```

### Baseband GSM Control (Advanced)

For fine-grained telephony simulation:

**Call management:**
```bash
phone baseband gsm call <number>      # Create incoming call
phone baseband gsm accept <number>    # Answer call
phone baseband gsm hold <number>      # Place on hold
phone baseband gsm busy <number>      # Mark as busy (caller hears busy tone)
phone baseband gsm cancel <number>    # Hang up
phone baseband gsm list               # List all active calls
phone baseband gsm status             # GSM registration status
```

**Voice and data registration:**
```bash
phone baseband gsm voice home         # Normal home network
phone baseband gsm voice roaming      # Roaming state
phone baseband gsm voice searching    # Searching for network
phone baseband gsm voice denied       # Registration denied
phone baseband gsm voice unregistered # Not registered
phone baseband gsm voice off          # Radio off

phone baseband gsm data home          # Data connected
```

**Signal quality:**
```bash
phone baseband gsm signal rssi <0-31>      # Signal strength (0=weak, 31=strong)
phone baseband gsm signal ber <0-7>        # Bit error rate (% — lower is better)
phone baseband gsm signal rs_snr <-200 to 300>  # Signal-to-noise ratio
```

**RSSI to signal bars mapping:**
| RSSI | Signal Quality | Approx. dBm | UI Bars |
|------|---------------|-------------|---------|
| 0-6 | Very poor | < -100 | 0-1 |
| 7-12 | Poor | -100 to -90 | 1-2 |
| 13-18 | Moderate | -90 to -80 | 2-3 |
| 19-24 | Good | -80 to -70 | 3-4 |
| 25-31 | Excellent | > -70 | 4-5 |

**CDMA (if applicable):**
```bash
phone baseband cdma ssource nv|ruim    # Subscription source
phone baseband cdma prl_version <val>  # PRL version
```

**SMS in PDU format:**
```bash
phone baseband sms send <number> "message"   # Standard SMS
phone baseband sms pdu <hex_string>           # Raw PDU format (for protocol testing)
```

### Testing Patterns

**OTP/SMS verification flow:**
```bash
# Start the app's login/verification flow, then:
genyshell -q -c 'phone sms "+15551234567" "Your verification code is 847291"'
# Verify: app auto-reads SMS, extracts code, proceeds with verification
```

**Call interruption handling:**
```bash
# While the app is performing a critical operation:
genyshell -q -c 'phone call "+15559876543"'
sleep 10  # Wait for call screen
genyshell -q -c 'phone baseband gsm cancel "+15559876543"'
# Verify: app resumes correctly after call ends, no data loss
```

**Signal degradation with call quality:**
```bash
genyshell -q -c "phone baseband gsm signal rssi 25"  # Good signal
sleep 5
genyshell -q -c "phone baseband gsm signal rssi 5"   # Very poor signal
# Verify: app shows connectivity warning if VoIP-based
```

**Limitation**: Genymotion cannot send or receive actual phone calls or SMS. All telephony is simulated — the notification and Messaging app receive the data, but no real network communication occurs.

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

---

## Gamepad (v3.8.0+, Android 12+, Paid)

The Gamepad feature forwards host-connected game controllers to the Android emulator.

### Controller Compatibility

| Controller | Windows | macOS | Linux |
|-----------|---------|-------|-------|
| Xbox 360 | Yes | Yes | Yes |
| PS5 DualSense | No* | Yes | Yes |
| Generic USB | Yes | Yes | Yes |

*PS5 DualSense on Windows: Not natively recognized. Workaround: use third-party Xbox emulation tools (e.g., DS4Windows, DualSenseX) to make the PS5 controller appear as Xbox 360.

### Features

- **Per-gamepad enable/disable**: Toggle individual controllers on/off
- **Multi-device preview**: See all connected gamepads and their status
- **Standard Android input mapping**: Controllers appear as standard Android gamepad input devices — apps using `InputDevice` and `KeyEvent.KEYCODE_BUTTON_*` work automatically

### Testing Patterns

**Game input verification:**
1. Connect a gamepad to the host machine
2. Enable it in the Gamepad widget
3. Open the game or app
4. Test all button mappings, analog stick response, and trigger sensitivity

**Accessibility testing**: Verify your app supports D-pad navigation (which uses the same input events as gamepad D-pad) for users who rely on external controllers.

### Automation Considerations

Gamepad input is **GUI-only** — no shell commands. For automated input testing, use ADB:
```bash
# Simulate gamepad button press via ADB input
adb shell input keyevent KEYCODE_BUTTON_A    # A button
adb shell input keyevent KEYCODE_BUTTON_B    # B button
adb shell input keyevent KEYCODE_BUTTON_X    # X button
adb shell input keyevent KEYCODE_BUTTON_Y    # Y button
adb shell input keyevent KEYCODE_DPAD_UP     # D-pad up
adb shell input keyevent KEYCODE_DPAD_DOWN   # D-pad down
adb shell input keyevent KEYCODE_DPAD_LEFT   # D-pad left
adb shell input keyevent KEYCODE_DPAD_RIGHT  # D-pad right
```

---

## Advanced Developer Tools (v3.4.0+, Paid)

The Advanced Developer Tools widget provides quick access to common Android developer settings.

### Available Toggles

| Toggle | Effect | Testing Use |
|--------|--------|-------------|
| **Root Access** | Enables/disables su access | Security testing, system-level inspection |
| **Show Taps** | Displays touch indicators on screen | Debugging touch targets, recording demos |
| **Show Pointer Location** | Shows pointer coordinates overlay | Verifying touch coordinates in automation scripts |
| **Show Layout Bounds** | Draws layout boundaries for all views | Debugging layout issues, padding/margin verification |
| **Enable/Disable Animations** | Controls system animation scale | Quick toggle vs. manual `settings put` commands |
| **Force Desktop Mode** | Multi-display desktop mode | Requires reboot; testing freeform/desktop UI |

### Root Access Details

When root is enabled, `adb shell` sessions run as root by default. This allows:
- Reading any file on the filesystem
- Modifying system settings directly
- Installing system apps
- Running security analysis tools (Frida, MobSF, etc.)
- Inspecting network traffic at the system level

```bash
# Verify root access
adb shell whoami
# Expected: root (when enabled), shell (when disabled)
```

### ADB Alternatives for Automation

All developer options can also be set via ADB (automatable in CI):

```bash
# Animations (most common — see Test Stability Checklist in test-integration.md)
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Show taps
adb shell settings put system show_touches 1    # Enable
adb shell settings put system show_touches 0    # Disable

# Pointer location
adb shell settings put system pointer_location 1  # Enable
adb shell settings put system pointer_location 0  # Disable

# Layout bounds
adb shell setprop debug.layout true    # Enable
adb shell setprop debug.layout false   # Disable
adb shell service call activity 1599295570  # Force refresh
```

---

## Capture

The Capture widget provides screenshot and screen recording from the emulator toolbar.

### Capabilities

| Feature | Description |
|---------|-------------|
| Screenshot | Single frame capture to file |
| Screencast | Toggle on/off video recording |
| File Browser | Open capture directory |

**Default directory**: Configurable via **Genymotion > Settings > Device**.

### ADB Alternatives (Automatable)

For CI/CD and scripted capture, use ADB directly:

```bash
# Screenshot
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png ./

# Screen recording (max 180 seconds per recording)
adb shell screenrecord --time-limit 60 --size 720x1280 /sdcard/recording.mp4
# Stop early with Ctrl+C, then:
adb pull /sdcard/recording.mp4 ./

# GMTool shortcut for logcat (related diagnostic):
gmtool device -n "DeviceName" logcatdump ~/logcat.txt
```

---

## Android Controls (v3.3.0+, Paid)

The Android Controls widget provides virtual buttons for hardware controls not present on the emulator window.

| Control | Function | ADB Alternative |
|---------|----------|-----------------|
| D-pad (Up/Down/Left/Right) | Directional navigation | `adb shell input keyevent KEYCODE_DPAD_*` |
| Volume Up/Down | Audio volume | `adb shell input keyevent KEYCODE_VOLUME_UP/DOWN` |
| Call button | Simulate call key | `adb shell input keyevent KEYCODE_CALL` |
| End Call | End call key | `adb shell input keyevent KEYCODE_ENDCALL` |
| Play/Pause | Media playback | `adb shell input keyevent KEYCODE_MEDIA_PLAY_PAUSE` |
| Stop | Stop media | `adb shell input keyevent KEYCODE_MEDIA_STOP` |
| Next/Previous | Media track navigation | `adb shell input keyevent KEYCODE_MEDIA_NEXT/PREVIOUS` |

---

## Other Controls

| Control | Description | Shortcut / ADB |
|---------|-------------|----------------|
| **Sound** | Volume adjustment | `adb shell media volume --set <0-15>` |
| **Rotate** (v3.3.0+) | 90 left/right rotation | `rotation setangle` via genyshell |
| **Pixel Perfect** | 1:1 pixel mapping (scrollbars if display > host screen) | GUI only |
| **Navigation** | Recent apps, Home, Back | `adb shell input keyevent KEYCODE_APP_SWITCH/HOME/BACK` |
| **Power** | Sleep mode; hold for power off | `adb shell input keyevent KEYCODE_POWER` |

---

## Open GApps

One-click minimal Google Play Services installation via the toolbar widget.

**Process**: Downloads compatible GApps package, flashes to device, requires reboot.

**CLI alternative** (for automation): See `cli-reference.md` Google Play Services section for `gmtool device flash` commands.

**Disclaimer**: GApps are provided by the Open GApps project. Genymotion states: "We assume no liability whatsoever resulting from the download, install and use of Open GApps."

---

## Sensor State Management

Understanding how sensor state persists and resets is critical for reliable testing.

### Persistence Rules

| Event | GPS | Battery | Network | Rotation | Identity | Disk I/O |
|-------|-----|---------|---------|----------|----------|----------|
| App restart | Persists | Persists | Persists | Persists | Persists | Persists |
| Device reboot | Resets | Resets | Resets | Resets | Persists | Resets |
| Factory reset | Resets | Resets | Resets | Resets | Resets | Resets |
| VM stop/start | Resets* | Resets* | Resets* | Resets* | Persists | Resets* |

*Quick Boot may preserve some state if the VM was not cleanly shut down.

### Default Values After Boot

| Sensor | Default |
|--------|---------|
| GPS | Disabled, 0/0 coordinates |
| Battery | Host mode (mirrors host) |
| Network | WiFi enabled, great signal |
| Rotation | 0 (portrait) |
| Android ID | Generated on first boot |
| Device ID | `000000000000000` |
| Disk I/O | Unlimited (0) |

### Reset Script for Test Suites

Run between test suites to ensure clean state:

```bash
#!/usr/bin/env bash
GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
"$GENYSHELL" -q -c "gps setstatus disabled"
"$GENYSHELL" -q -c "battery setmode host"
"$GENYSHELL" -q -c "network setstatus wifi enabled"
"$GENYSHELL" -q -c "network setstatus mobile disabled"
"$GENYSHELL" -q -c "network setsignalstrength wifi great"
"$GENYSHELL" -q -c "network setmobileprofile none"
"$GENYSHELL" -q -c "rotation setangle 0"
"$GENYSHELL" -q -c "diskio setreadratelimit 0"
```

### Potential Conflicts

| Conflict | Behavior |
|----------|----------|
| WiFi disabled + mobile disabled | Complete offline — no connectivity |
| WiFi enabled + mobile enabled | WiFi takes priority (standard Android behavior) |
| Battery mode host + setlevel | `setlevel` ignored in host mode — switch to manual first |
| GPS enabled + no coordinates set | Apps receive 0,0 (Null Island, Gulf of Guinea) |

---

## Testing Strategy by Feature

Decision matrix for choosing the right testing approach per feature.

| Feature | Genymotion Emulation | Mock in Test Code | Physical Device |
|---------|---------------------|-------------------|-----------------|
| GPS position | Best (full Shell control) | Overkill | Unnecessary |
| GPS route playback | Good (GUI or scripted) | N/A | Unnecessary |
| Battery states | Best (full Shell control) | Overkill | Impractical |
| Network profiles | Best (full Shell control) | Overkill | Impractical |
| Network offline | Best (Shell toggle) | Also good | Impractical |
| Discrete rotation | Best (Shell control) | N/A | Unnecessary |
| Continuous motion | Good (GUI only, v3.8.0+) | Better for CI | Best for accuracy |
| Fingerprint auth | Good (GUI only, v3.6.0+) | Better for CI | Best for full TEE |
| Camera (static image) | Good (GUI injection) | Also good | Unnecessary |
| Camera (live video) | Limited (host webcam) | Mock CameraX | Better |
| Phone calls/SMS | Good (Shell control) | Also good | Unnecessary |
| Disk I/O throttling | Best (Shell control) | N/A | Varies by device |
| Bluetooth | Not available | Required | Best |
| NFC | Not available | Required | Best |
| SafetyNet/Play Integrity | Not available | Mock for dev | Required for prod |
| Widevine DRM | Not available (L3 only) | N/A | Required (L1) |
| Thermal behavior | Not available | Mock PowerManager | Varies |
| Barometer/proximity | Not available | Mock SensorManager | Best |
