# Physical Device Setup and OEM Reference

Physical device configuration, multi-device management, self-hosted runner setup, OEM-specific considerations (Samsung, Xiaomi, Huawei), device selection strategy, and power user tricks.

> For CI pipeline configuration and emulator setup, see `ci-pipeline-config.md`. For ADB connection management, see `adb-connection-apps.md`.

## Self-Hosted Runner: Physical Device Keep-Awake

For CI runners with physical devices attached, prevent screen lock from breaking tests:

```bash
# Keep screen on while USB connected (persists across reboots)
adb shell svc power stayon usb

# Extend screen timeout to max
adb shell settings put system screen_off_timeout 2147483647

# Dismiss keyguard before test run
adb shell input keyevent 82
```

## Multi-Device Management

### Parallel Install on All Devices

```bash
for device in $(adb devices | grep -w "device" | awk '{print $1}'); do
    adb -s "$device" install -r app.apk &
done
wait
```

### Device Health Monitoring

```bash
for device in $(adb devices | grep -w "device" | awk '{print $1}'); do
    battery=$(adb -s "$device" shell dumpsys battery | grep level | awk '{print $2}')
    temp=$(adb -s "$device" shell dumpsys battery | grep temperature | awk '{print $2}')
    echo "$device | Battery: ${battery}% | Temp: $((temp/10))°C"
done
```

### Sharded Test Execution

```bash
adb -s DEVICE_1 shell am instrument -w \
  -e numShards 2 -e shardIndex 0 \
  com.example.test/androidx.test.runner.AndroidJUnitRunner > results_0.txt &
adb -s DEVICE_2 shell am instrument -w \
  -e numShards 2 -e shardIndex 1 \
  com.example.test/androidx.test.runner.AndroidJUnitRunner > results_1.txt &
wait
```

### Bash Helper Functions

```bash
# Run command on all devices
adb_all() {
  adb devices | tail -n +2 | cut -sf 1 | while read device; do
    echo "=== $device ==="
    adb -s "$device" "$@"
  done
}

# Named device switching
adbm() { adb -s $CURRENT_ADB_DEVICE "$@"; }
Pixel() { export CURRENT_ADB_DEVICE="<pixel_serial>"; }
Samsung() { export CURRENT_ADB_DEVICE="<samsung_serial>"; }

# Disable animations on all devices
adb_all shell settings put global animator_duration_scale 0
adb_all shell settings put global window_animation_scale 0
adb_all shell settings put global transition_animation_scale 0
```

## Physical Device Setup

### USB Debugging

Enable Developer Options: **Settings > About Phone > tap "Build number" 7 times**. Then enable USB debugging in Developer Options.

RSA keys stored at `~/.android/adbkey` (private) and `~/.android/adbkey.pub` (public). Device stores authorized keys at `/data/misc/adb/adb_keys`. On first connect, accept RSA dialog on device ("Always allow from this computer").

**7-day authorization timeout**: Even with "Always allow," authorization expires after 7 days. Fix: enable **"Disable ADB Authorization Timeout"** in Developer Options.

### Linux udev Rules (Required for USB Without Root)

```bash
# Find vendor ID:
lsusb    # e.g., "ID 18d1:d002 Google Inc." -> vendor 18d1

# Create rules file:
sudo nano /etc/udev/rules.d/51-android.rules
# Add: SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"

# Apply:
sudo chmod a+r /etc/udev/rules.d/51-android.rules
sudo udevadm control --reload-rules && sudo udevadm trigger --action=change
adb kill-server && adb start-server
```

**Common vendor IDs**: Google/Pixel `18d1`, Samsung `04e8`, OnePlus `2a70`, Xiaomi `2717`, Huawei `12d1`, LG `1004`, Sony `0fce`, HTC `0bb4`, Motorola `22b8`, ASUS `0b05`, Oppo `22d9`.

### Wireless Debugging (Android 11+)

No initial USB required, TLS encrypted, new pairing flow with 6-digit code, dynamic ports, mDNS discovery, remembers paired devices.

```bash
# 1. On device: Developer Options > Wireless debugging > enable
# 2. Tap "Pair device with pairing code" -- note IP:port and code
# 3. PAIR (one-time):
adb pair 192.168.1.100:37885     # Enter 6-digit code
# 4. CONNECT (using CONNECTION port, DIFFERENT from pairing port):
adb connect 192.168.1.100:41913
```

**Tradeoffs**: USB is significantly faster for APK installs (~480 Mbps vs ~50-100 Mbps WiFi) and more stable. Wireless is convenient for UI testing and untethered debugging. Can use both simultaneously.

## OEM Considerations

### Samsung

- Knox restrictions can block ADB installs
- Aggressive "Sleeping apps" and "Deep sleeping apps" kill background processes -- add test app to "Never sleeping apps"
- Samsung-specific logcat tags: `SamsungAlarmManager`, `SDHMS`

### Xiaomi (MIUI/HyperOS)

- Requires **extra "Install via USB" toggle** beyond standard USB debugging (may need Mi Account)
- Also enable "USB debugging (Security settings)"
- Every `adb install` may show confirmation popup
- Disable "MIUI Optimization" in Developer Options for standard behavior

### Huawei

- Newer devices lack Google Play Services (HMS only)
- Aggressive power management -- set app to "Manage manually" in Settings > Battery > App launch

### Google Pixel

- Closest to AOSP, most predictable, fastest updates
- **Recommended as primary development device**
- No extra toggles or restrictions

### Background Kill Severity (Most to Least Aggressive)

Samsung > OnePlus > Huawei > Xiaomi > Nokia > Pixel

Reference: dontkillmyapp.com

## Device Selection Strategy

- **Minimum** (2 devices): Pixel + budget Samsung/Xiaomi (~$500)
- **Moderate** (4 devices): Pixel + Samsung flagship + Xiaomi mid-range + budget device (~$1,500)
- Cover at least 3 density buckets, include notch/cutout and punch-hole devices, mix 60Hz and 120Hz displays, include one low-RAM device (3-4GB)

## Anti-Patterns and Pitfalls

### ADB Reliability Traps

**Connection drops**: USB3 ports cause frequent disconnects (especially Samsung); USB2 is more stable. Screen lock timeout causes ADB to lose authorization -- extend or disable timeout. Recovery: `adb kill-server && adb start-server`.

**Zombie servers**: Multiple tools (Android Studio, CLI, Genymotion) spawn separate ADB servers fighting for port 5037. `adb kill-server` may fail silently. Manual fix: `lsof -i :5037` to find occupying process, `kill -9 <PID>`, then restart.

**"Unauthorized" state**: Check device screen for RSA dialog (screen must be unlocked), toggle USB debugging off/on, revoke all USB authorizations and reconnect, or delete `~/.android/adbkey*` and restart server.

**Version mismatch**: Cryptic failures when client and server versions differ. Common when multiple ADB binaries exist on PATH. Fix: `which -a adb` to find all binaries, ensure single canonical `$ANDROID_HOME/platform-tools/adb`.

**Shell exit codes are unreliable**: `adb shell` returns 0 even when the inner command fails. Must parse output or use `adb shell "command; echo \$?"`.

## Local Device Farm Tools

For scaling beyond single-device CI, third-party orchestrators distribute tests across multiple connected devices or emulators:

- **Flank** (open-source, Firebase Test Lab compatible): `flank android run` — parallelizes test shards across devices, supports YAML config, produces JUnit XML. Also works with local devices via `--local-result-dir`.
- **Spoon** (Square, legacy): `java -jar spoon-runner.jar --apk app.apk --test-apk test.apk` — runs tests on all connected devices, generates HTML report with per-device screenshots. Less actively maintained; prefer Flank or GMD for new projects.

Both tools complement GMD (which manages emulator lifecycle) by adding cross-device orchestration and reporting.

## Power User Tricks

```bash
# Get current foreground app
adb shell "dumpsys activity activities | grep mResumedActivity"

# Prevent screen timeout during dev
adb shell settings put system screen_off_timeout 2147483647

# Suppress immersive mode confirmation
adb shell settings put secure immersive_mode_confirmations confirmed

# Unlock swipe-lock screen remotely
adb shell input keyevent 82

# Remove bloatware without root
adb shell cmd package uninstall -k --user 0 <package>

# Force AOT compilation for faster app startup
adb shell cmd package compile -m speed -f <package>

# Set hidden API policy (testing internal APIs)
adb shell settings put global hidden_api_policy 1

# Disable spell checker (reduces test flakiness)
adb shell settings put secure spell_checker_enabled 0

# Factory reset preserving ADB keys (API 29+, CI use)
adb shell cmd testharness enable
```
