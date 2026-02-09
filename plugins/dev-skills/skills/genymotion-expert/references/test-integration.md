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

## Genymotion Gradle Plugin (Legacy)

The official plugin (`com.genymotion:plugin:1.4`) wraps gmtool for automated device lifecycle during `connectedAndroidTest`:

```groovy
buildscript {
    dependencies { classpath 'com.genymotion:plugin:1.4' }
}
apply plugin: 'genymotion'

genymotion {
    config {
        genymotionPath = "/opt/genymotion/"
        taskLaunch = "connectedAndroidTest"
    }
    devices {
        testPhone {
            template "Google Pixel 3 - 10.0 - API 29 - 1080x2160"
            deleteWhenFinish false   // Preserve device between runs
        }
    }
}
```

**Important**: This plugin (v1.4, last published 2017) may have compatibility issues with modern AGP versions. For current projects, scripting with gmtool directly is more reliable. Gradle Managed Devices (first-party, modern) has largely absorbed this niche.

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

Genymotion Shell sensor values (GPS, battery, network) persist for the lifetime of the running VM. They survive app restarts but are reset on device reboot. Factory reset also clears them. Between test suites, explicitly reset sensor state:

```bash
GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
"$GENYSHELL" -q -c "gps setstatus disabled"
"$GENYSHELL" -q -c "battery setmode host"
"$GENYSHELL" -q -c "network setstatus wifi enabled"
"$GENYSHELL" -q -c "network setsignalstrength wifi great"
"$GENYSHELL" -q -c "rotation setangle 0"
```

## Unsimulatable Features

Test these on physical devices only: Bluetooth, NFC, real camera hardware, fingerprint sensors (biometric widget is UI-only), thermal behavior, cellular radio, SafetyNet/Play Integrity attestation (detects emulator — apps may refuse to run on uncertified devices), Widevine L1 DRM.
