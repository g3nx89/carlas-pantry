# Workflow Recipes Reference

End-to-end CLI scripts for common Android testing and debugging workflows. Also includes CI/CD pipeline templates for GitHub Actions and GitLab CI.

## Recipe 1 — Local Test Loop

Launch emulator, deploy, run specific test, iterate.

```bash
#!/usr/bin/env bash
set -euo pipefail

PKG="com.example.app"
TEST_CLASS="com.example.app.ui.LoginTest#validLogin_showsHome"
AVD_NAME="Pixel_4_API_30"

# 1. Start emulator (if not already running)
nohup emulator -avd "$AVD_NAME" -no-snapshot -no-audio -no-boot-anim >/dev/null 2>&1 &

# 2. Wait for boot (use scripts/wait-for-boot.sh for production)
adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed | tr -d "\r") ]]; do sleep 1; done'

# 3. Install app + test APKs
./gradlew :app:installDebug :app:installDebugAndroidTest

# 4. Clear app data (optional)
adb shell pm clear "$PKG"

# 5. Run single test
adb shell am instrument -w -r \
  -e class "$TEST_CLASS" \
  "${PKG}.test/androidx.test.runner.AndroidJUnitRunner"

# 6. Quick debug output
adb logcat -d | grep -E "AndroidJUnitRunner|TestRunner|System.err"
```

Alternative: use Gradle filtering instead of `am instrument`:

```bash
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class="$TEST_CLASS"
```

## Recipe 2 — Full Regression with Coverage and Screenshots

Assumes `testCoverageEnabled = true` in debug, Roborazzi and Paparazzi configured.

```bash
#!/usr/bin/env bash
set -euo pipefail

AVD_NAME="Pixel_5_API_31"
PKG="com.example.app"

# 1. Start emulator
nohup emulator -avd "$AVD_NAME" -no-snapshot -no-audio -no-boot-anim >/dev/null 2>&1 &
EMU_PID=$!
trap 'kill $EMU_PID 2>/dev/null' ERR EXIT

adb wait-for-device
adb shell 'while [[ -z $(getprop sys.boot_completed | tr -d "\r") ]]; do sleep 1; done'

# 2. Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# 3. Build and install
./gradlew :app:assembleDebug :app:assembleAndroidTest
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk

# 4. Run full regression (Espresso + Compose)
./gradlew :app:connectedDebugAndroidTest

# 5. Generate coverage (unit + instrumented)
./gradlew :app:testDebugUnitTest :app:jacocoTestReport

# 6. Screenshot verification
./gradlew :ui:verifyPaparazziDebug :app:verifyRoborazziDebug

# 7. Collect artifacts
mkdir -p artifacts
cp -R app/build/reports/androidTests/* artifacts/ 2>/dev/null || true
cp -R app/build/reports/coverage/* artifacts/ 2>/dev/null || true
```

## Recipe 3 — Physical Device Diagnostics

Connect, install, exercise, collect diagnostics.

```bash
#!/usr/bin/env bash
set -euo pipefail

PKG="com.example.app"
APK_PATH="app/build/outputs/apk/debug/app-debug.apk"

# 1. Verify device
adb devices -l

# 2. Install app
adb install -r "$APK_PATH"

# 3. Enable StrictMode visual indicator
adb shell setprop persist.sys.strictmode.visual 1

# 4. Clear logs and start app
adb logcat -c
adb shell am start -n "${PKG}/.MainActivity"

echo ">>> Reproduce issue now; press ENTER when done."
read -r _

# 5. Collect diagnostics
OUT="diag-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

adb logcat -d > "$OUT/logcat.txt"
adb shell dumpsys meminfo "$PKG" > "$OUT/meminfo.txt"
adb shell dumpsys gfxinfo "$PKG" > "$OUT/gfxinfo.txt"
adb shell dumpsys activity threads > "$OUT/threads.txt"

# ANR traces (if available)
adb shell "cp /data/anr/traces.txt /sdcard/anr_traces.txt" 2>/dev/null || true
adb pull /sdcard/anr_traces.txt "$OUT/" 2>/dev/null || true

echo "Diagnostics collected under $OUT/"
```

## Recipe 4 — Multi-API Testing Loop (GMD)

Test across multiple API levels using Gradle Managed Devices.

```bash
#!/usr/bin/env bash
set -euo pipefail

# Assumes GMD devices defined in build.gradle.kts:
# create("pixelApi26") { apiLevel = 26; ... }
# create("pixelApi30") { apiLevel = 30; ... }
# create("pixelApi34") { apiLevel = 34; ... }

DEVICES=(pixelApi26 pixelApi30 pixelApi34)
VARIANT="Debug"

for DEVICE in "${DEVICES[@]}"; do
  TASK="${DEVICE}${VARIANT}AndroidTest"
  echo ">>> Running tests on $DEVICE ($TASK)"
  ./gradlew "$TASK" \
    -Pandroid.testInstrumentationRunnerArguments.annotation=com.example.test.SmokeTest \
    --stacktrace

  OUT="reports-${DEVICE}"
  mkdir -p "$OUT"
  cp -R app/build/outputs/androidTest-results/* "$OUT" 2>/dev/null || true
done
```

Per-API result folders can be diffed or post-processed into a comparison matrix.

## Recipe 5 — Network Debugging Session

Proxy setup, capture, offline and slow connection testing.

```bash
#!/usr/bin/env bash
set -euo pipefail

PKG="com.example.app"
PROXY_HOST="192.168.0.10"
PROXY_PORT="8888"

# 1. Configure global HTTP proxy
adb shell settings put global http_proxy "${PROXY_HOST}:${PROXY_PORT}"

# 2. Disable captive portal detection (reduce noise)
adb shell settings put global captive_portal_mode 0

# 3. Run app
adb shell am start -n "${PKG}/.MainActivity"

# 4. Capture traffic on proxy side (mitmproxy/Charles)
echo ">>> Traffic is being proxied. Press ENTER when done."
read -r _

# 5. Test offline mode
adb shell svc wifi disable
adb shell svc data disable
echo ">>> Device is offline. Test offline UI. Press ENTER when done."
read -r _
adb shell svc wifi enable

# 6. Reset proxy
adb shell settings put global http_proxy :0
adb shell settings put global captive_portal_mode 1
```

## Recipe 6 — Memory Leak Investigation

Baseline and comparative heap dump analysis.

```bash
#!/usr/bin/env bash
set -euo pipefail

PKG="com.example.app"
OUT_DIR="leaks-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

dump_heap() {
  local label="$1"
  local remote="/data/local/tmp/${PKG}-${label}.hprof"
  local local_conv="${OUT_DIR}/${label}-converted.hprof"

  echo ">>> Dumping heap: $label"
  adb shell am dumpheap "$PKG" "$remote"
  sleep 3
  adb pull "$remote" "${OUT_DIR}/${label}.hprof"
  adb shell rm "$remote"
  hprof-conv "${OUT_DIR}/${label}.hprof" "$local_conv"
  rm "${OUT_DIR}/${label}.hprof"
}

# 1. Install and start
./gradlew :app:installDebug
adb shell am start -n "${PKG}/.MainActivity"

echo ">>> Drive app to baseline state, then press ENTER."
read -r _
dump_heap "baseline"

echo ">>> Exercise suspected leaking flow now, then press ENTER."
read -r _
dump_heap "after_flow"

echo "Heap dumps saved under $OUT_DIR/. Compare baseline vs after_flow in MAT."
```

## Recipe 7 — GitHub Actions CI Pipeline

Complete workflow: emulator tests + coverage + screenshots + artifacts.

```yaml
name: Android CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
      - name: Unit tests
        run: ./gradlew testDebugUnitTest --stacktrace
      - name: Screenshot tests (Paparazzi + Roborazzi)
        run: ./gradlew verifyPaparazziDebug verifyRoborazziDebug
      - name: Upload reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: unit-test-reports
          path: '**/build/reports/**'

  instrumented-tests:
    runs-on: macos-latest
    strategy:
      matrix:
        api-level: [30, 34]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
      - name: Emulator tests
        uses: ReactiveCircus/android-emulator-runner@v2
        with:
          api-level: ${{ matrix.api-level }}
          target: google_apis
          arch: x86_64
          profile: Pixel 4
          cores: 2
          ram-size: 2048M
          disk-size: 8G
          script: ./gradlew connectedDebugAndroidTest createDebugCoverageReport --stacktrace
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: instrumented-reports-api${{ matrix.api-level }}
          path: |
            **/build/outputs/androidTest-results/**
            **/build/reports/androidTests/**
            **/build/reports/coverage/**
```

### Key `android-emulator-runner` Inputs

| Input | Description | Example |
|-------|-------------|---------|
| `api-level` | Android API level | `30`, `34` |
| `target` | System image target | `default`, `google_apis`, `google-atd` |
| `arch` | CPU architecture | `x86_64` (prefer on macOS/Linux) |
| `profile` | AVD device profile | `Pixel 4`, `Pixel 6` |
| `cores` | CPU cores | `2` |
| `ram-size` | RAM allocation | `2048M` |
| `disk-size` | Disk size | `8G` |
| `script` | Command to run after boot | Gradle test command |

Notes:
- GitHub macOS/Linux runners have hardware acceleration configured
- Ubuntu runners are 2-3x faster and cheaper than macOS for emulators (KVM)
- Carefully match `api-level`/`target`/`arch` to available system images

## Recipe 8 — GitLab CI Pipeline

### Build Stage

```yaml
image: inovex/gitlab-ci-android

stages:
  - build
  - test

variables:
  GRADLE_OPTS: "-Dorg.gradle.daemon=false"

before_script:
  - export GRADLE_USER_HOME=$(pwd)/.gradle
  - chmod +x ./gradlew

cache:
  key: ${CI_PROJECT_ID}
  paths:
    - .gradle/

build:
  stage: build
  script:
    - ./gradlew assembleDebug
  artifacts:
    paths:
      - app/build/outputs/apk/debug/*.apk
    expire_in: 1 week

unit_tests:
  stage: test
  script:
    - ./gradlew testDebugUnitTest --stacktrace
  artifacts:
    reports:
      junit: '**/build/test-results/**/TEST-*.xml'
```

### Emulator in Docker (KVM Required)

Start long-lived emulator container on CI host:

```bash
docker run -d --restart=always \
  --device /dev/kvm \
  -e ADBKEY="$(cat ~/.android/adbkey)" \
  -e EMULATOR_PARAMS="-wipe-data" \
  -p 8554:8554 -p 5555:5555 \
  --name android-emulator \
  us-docker.pkg.dev/android-emulator-268719/images/30-google-x64:30.1.2
```

GitLab job connecting to emulator:

```yaml
test_instrumented:
  stage: test
  image: inovex/gitlab-ci-android
  script:
    - adb connect host.docker.internal:5555
    - adb devices
    - ./gradlew connectedDebugAndroidTest
```

Requirements: KVM access on GitLab runner host, Docker executor with `--device /dev/kvm`.

## CI General Patterns

### Test Pyramid Strategy

| Level | Target | Speed | CI Frequency |
|-------|--------|-------|-------------|
| Unit tests (JVM) | `testDebugUnitTest` | Seconds | Every commit |
| Compose snapshots | `verifyPaparazziDebug` | Seconds | Every commit |
| Instrumented tests | `connectedDebugAndroidTest` | Minutes | Every PR |
| E2E flows | `maestro test` | Minutes | Nightly |
| Performance | Physical device benchmarks | Variable | Pre-release |

### Flaky Test Handling

- Tag flaky tests with `@FlakyTest` annotation
- Quarantine into separate CI job
- Use Orchestrator for test isolation
- Disable animations, prefer idling semantics to sleeps
- Parse JUnit XML to identify repeat offenders

### Artifact Collection

Always upload test reports (even on failure):

```yaml
- name: Archive test reports
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: android-test-results
    path: |
      **/build/outputs/androidTest-results/**
      **/build/reports/androidTests/**
```
