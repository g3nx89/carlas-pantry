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
  "appium:app": "/path/to/app.apk",
  "appium:autoGrantPermissions": true
}
```

For parallel testing, use different `udid` per session. The `--avd` flag does NOT work with Genymotion — always start devices via gmtool first, then connect via `udid`.

## Maestro

Uses ADB under the hood. Natively supports Jetpack Compose elements via accessibility/semantics.

```bash
curl -Ls https://get.maestro.mobile.dev | bash
adb install app.apk
maestro test flow.yaml
maestro test --format junit flows/ --output report.xml
```

## Multi-Device Parallel Testing

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
        [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
        sleep 5
    done
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
3. **Wait for boot completion** (check `sys.boot_completed` property)
4. **Build x86/x86_64 APKs** (avoid ARM translation)
5. **Use `--coldboot`** in CI for reproducibility
6. **Reset sensor state** between test suites via Genymotion Shell
7. **Disable Google Play auto-updates** in CI: `adb shell pm disable-user com.android.vending`

## Unsimulatable Features

Test these on physical devices only: Bluetooth, NFC, real camera hardware, fingerprint sensors (biometric widget is UI-only), thermal behavior, cellular radio, SafetyNet/Play Integrity attestation (detects emulator), Widevine L1 DRM.
