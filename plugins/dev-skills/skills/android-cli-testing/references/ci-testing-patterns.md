# CI/CD Testing Patterns and Physical Device Reference

CI/CD pipeline strategies, emulator resource management, multi-device workflows, physical device setup, OEM considerations, and power user tricks.

## CI/CD Pipeline Strategy

### Recommended Test Tiers

**Every commit/PR** (fast feedback):
- JVM unit tests + Robolectric Compose tests (seconds)
- GMD instrumented tests on emulator (minutes)

**Nightly builds**:
- Full instrumented suite across API level matrix (API 28, 30, 33, 34+) on emulators
- Screenshot regression via Roborazzi

**Pre-release**:
- Performance benchmarks on physical devices
- Full suite on Firebase Test Lab physical devices
- OEM-specific device testing for top user devices

### CI Emulator Recommendations

- Use **ATD images** (`aosp_atd`/`google_atd`) -- stripped-down, boot faster, fewer ANRs
- Avoid `google_apis_playstore` in CI -- Pixel Launcher causes background ANRs
- Use `default` or `google_apis` images
- Lighter device profiles (`medium_phone`) outperform Pixel profiles on CI
- **API 29-30 images are most stable** for CI; latest APIs may have teething issues
- Enable KVM on Linux CI runners (GitHub Actions Ubuntu runners: 2-3x faster than macOS and cheaper). Larger runner sizes (`ubuntu-latest-4-cores` and above) have KVM enabled by default
- Set `-partition-size 4096` to prevent "no space left on device"

### Gradle Managed Devices (GMD)

GMD automates the entire emulator lifecycle -- define devices in `build.gradle.kts` and run tests with zero manual emulator management:

```bash
./gradlew pixel6api34DebugAndroidTest
```

Define device groups for multi-API testing:

```kotlin
android {
    testOptions {
        managedDevices {
            localDevices {
                create("pixel6api34") {
                    device = "Pixel 6"
                    apiLevel = 34
                    systemImageSource = "google"
                }
            }
        }
    }
}
```

### GMD CI-Specific Settings

```properties
# gradle.properties — headless rendering for CI servers
android.testoptions.manageddevices.emulator.gpu=swiftshader_indirect

# Limit concurrent emulators to avoid OOM on CI
# (Default: Gradle auto-detects based on cores, cap at 16)
# Set via: -PmaxConcurrentManagedDevices=2
```

Flaky test auto-retry (AGP 8.0+):

```kotlin
android {
    testOptions {
        managedDevices {
            devices["pixel6api34"].flakyTestAttempts = 1  // retry once
        }
    }
}
```

### CI Video Recording Pattern

Record emulator screen during test runs for debugging failures:

```bash
adb shell screenrecord /sdcard/run.mp4 &
./gradlew connectedDebugAndroidTest ; STATUS=$?
adb shell pkill -l2 screenrecord    # stop recording gracefully
adb pull /sdcard/run.mp4
exit $STATUS
```

Upload `run.mp4` as CI artifact for post-mortem debugging.

### CI Logcat Capture on Failure

Capture logcat only when tests fail to avoid huge artifact storage:

```bash
# Start logcat capture in background
adb logcat -G 16M                         # Increase buffer first
adb logcat > logcat_full.txt &
LOGCAT_PID=$!

./gradlew connectedDebugAndroidTest ; STATUS=$?

kill $LOGCAT_PID 2>/dev/null

if [ $STATUS -ne 0 ]; then
  # Extract crash-related lines for quick triage
  grep -E "FATAL|ANR|Exception|Error|crash" logcat_full.txt > logcat_errors.txt
  # Upload logcat_full.txt and logcat_errors.txt as CI artifacts
fi
exit $STATUS
```

### CI Test Determinism Best Practices

Prevent state leakage between test runs:

```bash
# 1. Cold boot: always use -no-snapshot or -wipe-data for CI emulators
emulator -avd ci_test -no-window -no-snapshot -wipe-data &

# 2. Uninstall between runs (removes all app data including databases, prefs)
adb shell pm uninstall com.example.app || true
adb shell pm uninstall com.example.app.test || true

# 3. Clear logcat before each run
adb logcat -c

# 4. Disable animations (idempotent, safe to re-run)
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# 5. Disable spell checker (causes flaky input tests)
adb shell settings put secure spell_checker_enabled 0
```

Alternatively, use `clearPackageData = "true"` in `testInstrumentationRunnerArguments` or Test Orchestrator for per-test isolation.

### Flaky Test Quarantine in CI

Separate flaky tests from the main CI gate to prevent false blocking:

```yaml
# GitHub Actions example — two jobs: main suite and quarantine
jobs:
  test-stable:
    runs-on: ubuntu-latest
    steps:
      - run: ./gradlew connectedDebugAndroidTest \
          -Pandroid.testInstrumentationRunnerArguments.notAnnotation=androidx.test.filters.FlakyTest

  test-quarantine:
    runs-on: ubuntu-latest
    continue-on-error: true    # Don't block the pipeline
    steps:
      - run: ./gradlew connectedDebugAndroidTest \
          -Pandroid.testInstrumentationRunnerArguments.annotation=androidx.test.filters.FlakyTest \
          -Pandroid.testInstrumentationRunnerArguments.numRetries=2
```

See `test-frameworks.md` for `@FlakyTest` annotation usage.

### Self-Hosted Runner: Physical Device Keep-Awake

For CI runners with physical devices attached, prevent screen lock from breaking tests:

```bash
# Keep screen on while USB connected (persists across reboots)
adb shell svc power stayon usb

# Extend screen timeout to max
adb shell settings put system screen_off_timeout 2147483647

# Dismiss keyguard before test run
adb shell input keyevent 82
```

### Firebase Test Lab (CLI Integration)

Run tests on Google's cloud device farm:

```bash
# Run instrumented tests on a physical Pixel 6
gcloud firebase test android run \
  --type instrumentation \
  --app app-debug.apk \
  --test app-debug-androidTest.apk \
  --device model=oriole,version=33,locale=en,orientation=portrait \
  --timeout 15m \
  --results-bucket=my-test-results \
  --results-dir=run-$(date +%s)

# Run on multiple devices
gcloud firebase test android run \
  --type instrumentation \
  --app app-debug.apk \
  --test app-debug-androidTest.apk \
  --device model=oriole,version=33 \
  --device model=a51,version=30 \
  --num-flaky-test-attempts=2
```

Results include JUnit XML, logcat, video, and screenshots. Use `gcloud firebase test android models list` to see available devices.

## Resource Management and Cleanup

### Emulator Cleanup with Trap

```bash
emulator -avd ci_test -no-window -no-audio &
EMU_PID=$!
trap 'kill $EMU_PID' ERR EXIT

# ... run tests ...
```

### Kill All Emulators

```bash
adb devices | grep emulator | cut -f1 | while read line; do adb -s $line emu kill; done
adb kill-server
pkill -f qemu-system || true
```

**Do not use `kill -9`** for emulators -- corrupts filesystem images and does not close ports. Use `adb emu kill` or telnet console `kill` command.

### Disk Management

Each AVD consumes 6-12GB. Snapshots compound this. Cleanup:

```bash
avdmanager delete avd -n <name>
sdkmanager --uninstall "system-images;android-XX;google_apis;x86_64"
```

For multi-instance CI, use `--read-only` for instances after the first.

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

### Device Selection Strategy

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

### Emulator Instability

**Boot failures**: `adb wait-for-device` is the #1 cause of CI flakiness -- it does NOT mean the device is ready. Always poll `sys.boot_completed`. Use `-delay-adb` flag to suppress ADB until boot complete. Cold boot with `-no-snapshot` is more reliable than snapshot loading in CI.

**Snapshot corruption**: Causes boot loops or black screens. Fix: `emulator -avd name -no-snapshot-load` or delete `~/.android/avd/<name>.avd/snapshots/`. Snapshots with Vulkan are not supported -- avoid on API 30+ where Chrome forces Vulkan.

**Resource leaks**: Emulator requests full guest memory at startup on Windows. QCOW2 files grow unbounded. Cleanup: delete snapshot directories, remove unused AVDs, use `--read-only` for secondary instances.

### Common Scripting Mistakes

**Race condition after install**: `adb install` returns before PackageManager fully registers the app. Running `am start` immediately may fail. Add `sleep 2` or verify with `pm list packages | grep <pkg>`.

**Logcat buffer overflow**: Default 256KB ring buffer loses early logs in long CI runs. Increase: `adb logcat -G 16M`. Clear before test: `adb logcat -c`.

**Wrong device targeting**: Without `-s <serial>`, ADB errors "more than one device/emulator." Always use `-s serial` or `$ANDROID_SERIAL` in CI scripts.

### Emulator vs Device Discrepancies

Tests passing on emulator but failing on device (and vice versa) is common. Key differences: touch responsiveness, GPU rendering fidelity, font smoothing, OEM skin behavior, network stack (emulator is simulated), timing (CI emulators are typically slower). **Always disable animations in CI.** **Mock network layer for stability** -- emulator networking does not reproduce real carrier/WiFi behavior reliably.

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
