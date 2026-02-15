# CI Pipeline Configuration Reference

CI/CD pipeline strategy, test tiers, emulator configuration, Gradle Managed Devices CI settings, test determinism, flaky test quarantine, Firebase Test Lab, and resource management.

> For physical device setup and OEM quirks, see `device-setup-oem.md`. For end-to-end CI templates (GitHub Actions, GitLab CI), see `workflow-recipes.md`.

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

See `test-espresso-compose.md` for `@FlakyTest` annotation usage.

## Firebase Test Lab (CLI Integration)

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

## Anti-Patterns and Pitfalls

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
