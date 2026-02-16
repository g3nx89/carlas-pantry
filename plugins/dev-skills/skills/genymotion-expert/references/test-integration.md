# Test Framework Integration with Genymotion

Patterns for running automated tests on Genymotion Desktop with Kotlin and Jetpack Compose.

## Espresso and Compose UI Tests

Both are instrumented tests running via Gradle. Required dependencies in `build.gradle.kts`:

```kotlin
dependencies {
    // Espresso
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.test:runner:1.6.1")
    androidTestImplementation("androidx.test:rules:1.6.1")

    // Compose Testing
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:$compose_version")
    debugImplementation("androidx.compose.ui:ui-test-manifest:$compose_version")
}

android {
    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
}
```

### Running Tests

```bash
# All tests
./gradlew connectedDebugAndroidTest

# Specific test class
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.ui.ComposeLoginTest

# Test sharding across multiple instances
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.numShards=3 \
  -Pandroid.testInstrumentationRunnerArguments.shardIndex=0
```

### Compose-Specific Notes

Compose rendering uses Skia (architecture-independent). The semantics tree used for testing (`testTag`, `onNodeWithText`, `onNodeWithContentDescription`) is independent of the rendering backend. Tests using `createComposeRule()` or `createAndroidComposeRule<Activity>()` behave identically on Genymotion x86, ARM physical devices, and AVDs. No known Compose-specific differences on Genymotion.

### Test Results Location

- HTML: `app/build/reports/androidTests/connected/index.html`
- JUnit XML: `app/build/outputs/androidTest-results/connected/`

### App Lifecycle Commands for Test Setup

```bash
# Clear app data between test suites (resets to fresh-install state)
adb shell pm clear com.example.app

# Force-stop app (simulate crash or reset state)
adb shell am force-stop com.example.app

# Pre-grant permissions to avoid UI dialogs during tests
adb shell pm grant com.example.app android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.app android.permission.CAMERA

# Launch a specific activity with extras
adb shell am start -n com.example.app/.DetailActivity --es "item_id" "123"

# Broadcast a custom intent
adb shell am broadcast -a com.example.CUSTOM_ACTION
```

### Screen Capture and Recording

```bash
# Screenshot
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png ./screenshots/

# Screen recording (hard limit: 180s per recording)
adb shell screenrecord --time-limit 60 --size 720x1280 /sdcard/recording.mp4
# Stop with Ctrl+C, then pull:
adb pull /sdcard/recording.mp4

# GMTool shortcut for logcat capture:
gmtool device -n "DeviceName" logcatdump ~/logcat.txt
```

### Keep Device Awake During Tests

```bash
# Prevent screen timeout during long Appium/Maestro sessions
adb shell svc power stayon true

# Or set a long timeout (30 minutes)
adb shell settings put system screen_off_timeout 1800000
```

### Split APK / App Bundle Installation

For apps distributed as App Bundles (.aab), use `bundletool` to generate device-specific APKs:

```bash
# Generate APK set from bundle
bundletool build-apks --bundle=app.aab --output=app.apks --local-testing

# Install on connected Genymotion device
bundletool install-apks --apks=app.apks

# Or install multiple split APKs directly
adb install-multiple base.apk config.xxhdpi.apk config.en.apk
```

### Verify Test Runner Availability

Before running instrumentation tests, confirm the runner is installed:

```bash
adb shell pm list instrumentation
# Expected: instrumentation:com.example.test/androidx.test.runner.AndroidJUnitRunner (target=com.example.app)
```

If the test runner is missing, the test APK was not installed correctly.

## ADB Instrumentation (Direct)

```bash
# All tests
adb shell am instrument -w \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# Specific class
adb shell am instrument -w \
  -e class com.example.test.LoginTest \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# Specific method
adb shell am instrument -w \
  -e class com.example.test.LoginTest#testValidLogin \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# Sharding
adb -s 192.168.56.101:5555 shell am instrument -w \
  -e numShards 3 -e shardIndex 0 \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# By annotation size
adb shell am instrument -w -e size large \
  com.example.test/androidx.test.runner.AndroidJUnitRunner
```

## Android Test Orchestrator

The Android Test Orchestrator runs each test in its own `Instrumentation` instance, providing stronger test isolation (crashes in one test don't affect others). On Genymotion, it requires installing the Test Services APK alongside the test APK:

```bash
# Install orchestrator and test services
adb install -r orchestrator.apk
adb install -r test-services.apk

# Or use Gradle (recommended):
android {
    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
}
# Then: ./gradlew connectedDebugAndroidTest
```

Orchestrator is useful on Genymotion when running large test suites where flaky tests might crash the process, since each test gets a fresh instance.

## Genymotion Java API (In-Test Sensor Control)

Manipulate sensors directly from instrumented tests:

```kotlin
// build.gradle.kts
repositories {
    maven { url = uri("http://api.genymotion.com/repositories/releases/") }
}
dependencies {
    androidTestImplementation("com.genymotion:genymotion-api:1.0.0")
}
```

```kotlin
import com.genymotion.api.GenymotionManager

@Test
fun testLowBatteryWarning() {
    GenymotionManager.getDevice().battery.setLevel(5)
    GenymotionManager.getDevice().battery.setStatus(BatteryStatus.DISCHARGING)
    // Assert app shows warning
}

@Test
fun testLocationFeature() {
    GenymotionManager.getDevice().gps.setLatitude(48.8566)
    GenymotionManager.getDevice().gps.setLongitude(2.3522)
    // Assert app shows Paris location
}
```

## UI Automator

Works identically to real devices (standard ADB interface). API 21+ required (API 26+ for UiAutomator2 driver v6.0+).

```bash
# Hierarchy dump for inspection:
adb shell uiautomator dump /sdcard/ui_dump.xml && adb pull /sdcard/ui_dump.xml
```

## Appium

```json
{
  "platformName": "Android",
  "appium:automationName": "UiAutomator2",
  "appium:deviceName": "Genymotion",
  "appium:platformVersion": "13",
  "appium:udid": "192.168.56.101:5555",
  "appium:systemPort": 8200,
  "appium:app": "/path/to/app.apk",
  "appium:autoGrantPermissions": true
}
```

For parallel testing, use different `udid` AND `systemPort` per session. Each concurrent Appium session needs a unique `systemPort` (range 8200-8299) to forward UiAutomator2 commands without conflict. The `--avd` flag does NOT work with Genymotion — always start devices via gmtool first, then connect via `udid`.

## Maestro

Uses ADB under the hood. Natively supports Jetpack Compose elements via accessibility/semantics.

```bash
curl -Ls https://get.maestro.mobile.dev | bash
adb install app.apk
maestro test flow.yaml
maestro test --format junit flows/ --output report.xml

# Target a specific Genymotion device when multiple are running:
maestro test flow.yaml -d 192.168.56.101:5555
```

## System Inspection Commands

Useful for debugging test state, verifying sensor simulation, and diagnosing failures:

```bash
# Verify boot and system state
adb shell getprop sys.boot_completed              # "1" when fully booted
adb shell getprop init.svc.bootanim               # "stopped" when animation done
adb shell getprop ro.product.cpu.abilist          # Supported ABIs
adb shell getprop ro.build.version.sdk            # API level

# Battery state (verify Genymotion Shell simulation worked)
adb shell dumpsys battery

# Memory usage per app (detect leaks during long test runs)
adb shell dumpsys meminfo com.example.app

# Current foreground activity (verify correct screen is shown)
adb shell dumpsys activity | grep mCurrentFocus

# Network connectivity state
adb shell dumpsys connectivity | grep "NetworkAgentInfo"

# UI interaction for debugging
adb shell input tap 500 1000                      # Tap at coordinates
adb shell input text "hello"                      # Type text
adb shell input keyevent KEYCODE_HOME             # Press Home
adb shell input keyevent 82                       # Menu / unlock
adb shell input swipe 500 1500 500 300 300        # Swipe up
```

## Logcat Strategies

```bash
adb logcat -c                                      # Clear buffer before test
adb logcat -d > logcat.txt                         # Dump and exit
adb logcat -v threadtime > logcat.txt &            # Background continuous capture
adb logcat -s "MyApp:D" "AndroidRuntime:E"         # Filter by tags
adb logcat *:E                                      # Errors only
adb logcat --pid=$(adb shell pidof com.example.app) # Filter by app PID
```

## Test Distribution Tools

For distributing tests across multiple Genymotion instances beyond basic Gradle sharding:

- **Flank** (recommended): Google's open-source test runner that distributes tests across multiple devices in parallel. Works with Genymotion since it uses ADB. Supports automatic sharding, retry on failure, and JUnit XML aggregation.
- **Spoon** (legacy): Square's test runner for multi-device distribution with HTML reports and screenshots per device. Works with Genymotion via standard ADB serials.
- **Marathon**: Gradle plugin for parallel test execution with dynamic device allocation, test batching, and flakiness strategies.

All these tools treat Genymotion instances as standard ADB devices — configure them with the Genymotion device serials (e.g., `192.168.56.101:5555`).

## Multi-Device Parallel Testing

> **Note:** For a complete CI-ready parallel testing recipe with cleanup, result aggregation, and report collection, see `ci-and-recipes.md` Recipe 2.

Each Genymotion device gets a unique IP on the host-only network (all on port 5555):

```bash
adb devices
# 192.168.56.101:5555    device
# 192.168.56.102:5555    device
```

Target specific devices with `adb -s 192.168.56.101:5555` or `ANDROID_SERIAL` env var.

### Sharded Test Script Pattern

```bash
# Start multiple devices
for i in 0 1 2; do
    gmtool admin create "Custom Phone" "Android 11.0" "shard-${i}" --nbcpu 2 --ram 2048
    gmtool --timeout 300 admin start "shard-${i}"
    gmtool device -n "shard-${i}" adbconnect
done

# Collect device serials and wait for each to boot
SERIALS=()
while IFS= read -r line; do
    SERIALS+=("$line")
done < <(adb devices | grep "device$" | awk '{print $1}')

for serial in "${SERIALS[@]}"; do
    for j in $(seq 1 60); do
        bc=$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
        ba=$(adb -s "$serial" shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")
        if [ "$bc" = "1" ] && [ "$ba" = "stopped" ]; then
            adb -s "$serial" shell pm list packages 2>/dev/null | head -1 | grep -q "package:" && break
        fi
        sleep 5
    done
    adb -s "$serial" shell input keyevent 82
done

# Run shards in parallel
for i in "${!SERIALS[@]}"; do
    ANDROID_SERIAL="${SERIALS[$i]}" ./gradlew connectedDebugAndroidTest \
        -Pandroid.testInstrumentationRunnerArguments.numShards=${#SERIALS[@]} \
        -Pandroid.testInstrumentationRunnerArguments.shardIndex=$i &
done
wait
```

## Reliability and Flakiness Patterns

Common sources of test instability on Genymotion and their resolutions.

### ADB Connection Drops

**Symptom**: `error: device not found` or `error: closed` mid-test run.
**Causes**: Host network adapter reconfiguration, VPN toggling, ADB server restart from version mismatch, host sleep/wake.
**Fix**: Implement the ADB recovery pattern (see `ci-and-recipes.md`). In CI, wrap test execution with connection health checks. Align ADB versions to prevent server restarts.

### VM Startup Failures

**Symptom**: `gmtool admin start` returns error code 4 (virtualization engine does not respond) or error code 13.
**Causes**: VirtualBox version mismatch (see `cli-reference.md` VirtualBox Compatibility section), hypervisor conflict (Hyper-V vs VirtualBox on Windows), insufficient host resources, corrupted Quick Boot state.
**Fix**: Verify hypervisor compatibility. Try `--coldboot` to bypass corrupt state. Check host RAM/CPU availability. Ensure only one hypervisor type is active.

### ARM Translation Crashes

**Symptom**: App crashes on launch or during specific operations with SIGILL or SIGSEGV in logcat referencing libhoudini.
**Causes**: libhoudini ARM translation cannot handle certain ARM instructions or advanced JIT code.
**Fix**: Build x86/x86_64 APKs (the fundamental fix). If ARM-only third-party SDKs are involved, isolate testing of those SDK paths to physical devices. Never run ARM-translated code in performance-sensitive tests — crypto operations can be 10x slower under translation.

### Memory Overuse and OOM

**Symptom**: Host becomes unresponsive, tests timeout, device reboots mid-test.
**Causes**: Running too many concurrent instances, host physical memory exhausted, Android process OOM inside the VM.
**Fix**: Respect the concurrent instance limits in SKILL.md. Monitor host memory with `free -h` or Activity Monitor. For long-running suites, implement periodic device recycling (see `ci-and-recipes.md`).

### Clock and Timezone Inconsistencies

**Symptom**: Tests depending on time (token expiry, scheduled events, date formatting) fail intermittently.
**Causes**: VM clock can drift from host, especially after suspend/resume or long-running sessions. Timezone may not match expectations.
**Fix**: Sync time explicitly: `adb shell settings put global auto_time 1`. Set timezone: `adb shell setprop persist.sys.timezone "America/New_York"`. For time-travel testing (e.g., future dates), use `adb shell date` on rooted Genymotion images.

### UI Rendering Differences

**Symptom**: Screenshot comparison tests fail; layout looks different than on physical devices.
**Causes**: Genymotion runs AOSP Android, not OEM skins. Samsung, Pixel, and other manufacturers apply different default fonts, spacing, status bar heights, and system UI. The VM GPU adapter may render gradients or shadows differently.
**Fix**: Use semantic assertions (`onNodeWithText`, `onNodeWithContentDescription`) over pixel-based comparisons. Accept that Genymotion validates logic, not pixel-perfect OEM rendering. Use `--sysprop` to set device identity but understand this does not change the rendering engine.

### Licensing Disruptions

**Symptom**: Commands fail with error code 9 (license not activated) or 14 (requires Indie/Business) mid-pipeline.
**Causes**: License server unreachable, maximum workstation activations consumed, ephemeral CI environments consuming activations without cleanup.
**Fix**: Always implement cleanup traps (see `ci-and-recipes.md`). Monitor license validity: `gmtool license validity`. Since Desktop 3.2.0, `list`/`start`/`stop` work without license — design CI to tolerate license outages for basic operations.

## Test Stability Checklist

Before running tests on Genymotion:

1. **Disable animations** (all three scales set to 0)
2. **Align ADB versions** (`gmtool config --use_custom_sdk on --sdk_path "$ANDROID_HOME"`)
3. **Wait for boot completion** (check `sys.boot_completed`, `init.svc.bootanim`, AND `pm list packages` readiness)
4. **Build x86/x86_64 APKs** (avoid ARM translation)
5. **Use `--coldboot`** in CI for reproducibility
6. **Reset sensor state** between test suites via Genymotion Shell
7. **Disable Google Play auto-updates** in CI: `adb shell pm disable-user com.android.vending`
8. **Keep screen awake** for Appium/Maestro: `adb shell svc power stayon true`
9. **Clear logcat before test** to isolate relevant logs: `adb logcat -c`
10. **Dismiss keyguard** after boot: `adb shell input keyevent 82`

## Sensor State Persistence

Genymotion Shell sensor values (GPS, battery, network) persist for the lifetime of the running VM. They survive app restarts but are reset on device reboot. Factory reset also clears them. Between test suites, explicitly reset sensor state using the canonical reset script in `emulated-features/sensor-management.md` (Reset Script for Test Suites) — it covers GPS, battery, network (WiFi + mobile), mobile profile, rotation, and disk I/O.

## Emulated Features Overview

> **Comprehensive reference**: See `emulated-features/index.md` for the Feature Availability Matrix and Testing Strategy decision matrix. Per-feature details are in individual files under `emulated-features/`.

Genymotion Desktop supports emulation of GPS, battery, network, rotation, phone/SMS, disk I/O, device identity (all via Genymotion Shell), plus motion sensors, biometrics, camera/media injection, gamepad, and advanced developer tools (GUI-only widgets). Features vary by version and license tier.

## Unsimulatable Features

Features that Genymotion **cannot** simulate. Plan physical device testing or alternative strategies.

| Feature | Why Not Simulatable | Testing Alternative |
|---------|-------------------|---------------------|
| Bluetooth | No virtual Bluetooth adapter in VM | Mock Bluetooth layer in app code; physical device for integration |
| NFC | No virtual NFC controller | Mock NFC intents in instrumented tests; physical device for tap flows |
| Thermal behavior | No thermal sensor simulation | Mock `PowerManager` and `ThermalStatus` callbacks |
| Cellular radio (real) | Genymotion Shell simulates signal UI, not actual radio behavior | Sufficient for UI testing of degraded states; physical device for network stack |
| SafetyNet / Play Integrity | Emulator is detected; attestation always fails | Physical device required; use `isTestDevice` flag during development |
| Widevine L1 DRM | Emulator provides L3 at best | Physical device required for DRM-protected content playback |
| Barometer / proximity | Not exposed via Genymotion Shell or widgets | Mock at the Android API level in instrumented tests |

## Partially Simulatable Features

Features that Genymotion supports with limitations. Understand the boundaries for each.

| Feature | What Works | Limitation | Alternative for Full Coverage |
|---------|-----------|-----------|-------------------------------|
| Motion sensors (v3.8.0+) | Yaw/pitch/roll sliders, 3D model, Device Link forwarding | GUI-only (not scriptable via Shell); no continuous motion injection for CI | Mock `SensorManager` in test code; Device Link for manual QA |
| Biometrics (v3.6.0+, Android 13+) | 6 fingerprint scenarios (recognized, unrecognized, dirty, partial, insufficient, too fast) | GUI-only; does not exercise real TEE or cryptographic biometric stack | `BiometricPrompt` test APIs for CI; physical device for full TEE validation |
| Camera (v3.3.0+) | Static image, video, or host webcam injection to front/back cameras | No depth data (LiDAR/ToF); no continuous autofocus simulation; GUI-only | Mock `CameraX`/`Camera2` providers in tests; physical device for camera quality |
| Gamepad (v3.8.0+, Android 12+) | Xbox 360, PS5 (mac/linux), generic USB forwarding | GUI-only; PS5 not recognized on Windows without third-party tools | ADB `input keyevent KEYCODE_BUTTON_*` for automated input |

**General rule**: If the feature requires hardware silicon not present in the VM (TEE, radio baseband, sensor fusion), it cannot be accurately simulated. Mock at the API boundary for unit/integration tests, and reserve physical devices for hardware-dependent acceptance tests.
