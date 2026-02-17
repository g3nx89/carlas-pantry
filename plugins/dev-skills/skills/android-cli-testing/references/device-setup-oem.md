# Physical Device Setup and OEM Reference

Physical device CLI configuration, multi-device management, self-hosted runner setup, OEM-specific CLI workarounds, and ADB reliability.

> For CI pipeline configuration and emulator setup, see `ci-pipeline-config.md`. For ADB connection management, see `adb-connection-apps.md`. For GUI-only device operations (Developer Options, USB debugging enable, OEM toggles), see `gui-walkthroughs.md`.

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

### RSA Key Locations

RSA keys stored at `~/.android/adbkey` (private) and `~/.android/adbkey.pub` (public). Device stores authorized keys at `/data/misc/adb/adb_keys`.

**GUI-only prerequisite**: Enabling Developer Options, USB debugging, and RSA key acceptance require device GUI interaction. **When these are needed**, load `gui-walkthroughs.md` and relay the step-by-step instructions to the user.

### Linux udev Rules (Required for USB Without Root)

```bash
# Find vendor ID:
lsusb    # e.g., "ID 18d1:d002 Google Inc." -> vendor 18d1

# Create rules file:
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/51-android.rules

# Apply:
sudo chmod a+r /etc/udev/rules.d/51-android.rules
sudo udevadm control --reload-rules && sudo udevadm trigger --action=change
adb kill-server && adb start-server
```

**Common vendor IDs**: Google/Pixel `18d1`, Samsung `04e8`, OnePlus `2a70`, Xiaomi `2717`, Huawei `12d1`, LG `1004`, Sony `0fce`, HTC `0bb4`, Motorola `22b8`, ASUS `0b05`, Oppo `22d9`.

### Wireless Debugging (Android 11+)

TLS encrypted, dynamic ports, mDNS discovery, remembers paired devices.

```bash
# PAIR (one-time, requires pairing code from device GUI):
adb pair 192.168.1.100:37885     # Enter 6-digit code

# CONNECT (using CONNECTION port, DIFFERENT from pairing port):
adb connect 192.168.1.100:41913
```

**GUI-only prerequisite**: Enabling Wireless debugging and obtaining the pairing code/port require device GUI interaction. **When needed**, load `gui-walkthroughs.md` and relay the instructions.

USB is significantly faster for APK installs (~480 Mbps vs ~50-100 Mbps WiFi). Wireless is convenient for UI testing. Can use both simultaneously.

## OEM Considerations

### Samsung

- Samsung-specific logcat tags for debugging: `SamsungAlarmManager`, `SDHMS`
- Knox restrictions can block ADB installs entirely (enterprise/carrier devices) — see `gui-walkthroughs.md` for Knox troubleshooting
- **GUI-only**: Aggressive "Sleeping apps" kills background processes — user must add test app to "Never sleeping apps" list. Load `gui-walkthroughs.md` for steps

### Xiaomi (MIUI/HyperOS)

- **GUI-only**: Requires extra toggles beyond standard USB debugging: "Install via USB" and "USB debugging (Security settings)". Without these, every `adb install` shows a confirmation popup. Load `gui-walkthroughs.md` for steps
- Newer devices lack Google Play Services (HMS only)

### Huawei

- Newer devices lack Google Play Services (HMS only)
- **GUI-only**: Aggressive power management kills background apps — user must set app to "Manage manually" in battery settings. Load `gui-walkthroughs.md` for steps

### Google Pixel

- Closest to AOSP, most predictable — recommended as primary development device
- No extra toggles or restrictions

### Background Kill Severity

Samsung > OnePlus > Huawei > Xiaomi > Nokia > Pixel (reference: dontkillmyapp.com)

## Anti-Patterns

### ADB Reliability Traps

**Connection drops**: USB3 ports cause frequent disconnects (especially Samsung); USB2 is more stable. Screen lock timeout causes ADB to lose authorization — extend or disable timeout. Recovery: `adb kill-server && adb start-server`.

**Zombie servers**: Multiple tools (Android Studio, CLI, Genymotion) spawn separate ADB servers fighting for port 5037. `adb kill-server` may fail silently. Fix:

```bash
lsof -i :5037              # Find occupying process
kill -9 <PID>              # Kill it
adb start-server           # Restart clean
```

**"Unauthorized" state**: Troubleshoot via CLI first, then escalate to GUI if needed:

```bash
# 1. Check if device is visible
adb devices -l

# 2. Restart ADB server
adb kill-server && adb start-server

# 3. If still unauthorized, delete host keys and reconnect
rm ~/.android/adbkey*
adb start-server
```

If CLI steps fail, load `gui-walkthroughs.md` for RSA key re-authorization steps on the device.

**Version mismatch**: Cryptic failures when client and server versions differ. Common when multiple ADB binaries exist on PATH. Fix: `which -a adb` to find all binaries, ensure single canonical `$ANDROID_HOME/platform-tools/adb`.

**Shell exit codes are unreliable**: `adb shell` returns 0 even when the inner command fails. Must parse output or use `adb shell "command; echo \$?"`.

## Local Device Farm Tools

For scaling beyond single-device CI:

- **Flank** (open-source, Firebase Test Lab compatible): `flank android run` — parallelizes test shards across devices, supports YAML config, produces JUnit XML. Also works with local devices via `--local-result-dir`.
- **Spoon** (Square, legacy): `java -jar spoon-runner.jar --apk app.apk --test-apk test.apk` — runs tests on all connected devices, generates HTML report with per-device screenshots. Less actively maintained; prefer Flank or GMD for new projects.

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
