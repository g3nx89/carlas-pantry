# CI Pipeline Configuration Reference

CI/CD pipeline strategy, test tiers, emulator configuration, Gradle Managed Devices CI settings, test determinism, device hardening, flaky test quarantine and detection, Firebase Test Lab, KVM acceleration, AVD snapshot caching, self-hosted device farms, and resource management.

> For physical device setup and OEM quirks, see `device-setup-oem.md`. For end-to-end CI templates (GitHub Actions, GitLab CI), see `workflow-recipes.md`.

> **TL;DR**: Three test tiers (PR/nightly/pre-release), use ATD images for fast CI boot, enable KVM on Linux runners, quarantine flaky tests with `@FlakyTest` + nightly job, cache AVD snapshots, use Firebase Test Lab for cloud devices, enforce coverage gates via JaCoCo XML parsing.

## Contents

| Line | Section | Focus |
|-----:|---------|-------|
| 22 | CI/CD Pipeline Strategy | Test tiers, GMD, KVM, determinism, flaky quarantine |
| 486 | Firebase Test Lab | Cloud device testing, sharding, CI integration |
| 549 | Self-Hosted Runner Farm | STF setup, GitHub Actions integration |
| 601 | Resource Management | Emulator cleanup, disk management |
| 634 | Build Cache Optimization | Cacheable tasks, remote build cache |
| 652 | Anti-Patterns | Emulator instability, scripting mistakes |
| 674 | Pre-Flight Validation | SDK, emulator, ADB, build checks |
| 761 | Coverage Threshold Enforcement | JaCoCo XML parsing, threshold gates |

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

> **Note:** For emulator image boot time and disk size comparison table, see `emulator-cli.md` > System Image Variants.

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

### GMD additionalTestOutputDir

Capture files written by tests to device storage and pull them to the host automatically:

```kotlin
android {
    testOptions {
        additionalTestOutputDir = "/sdcard/test-outputs"
    }
}
```

Tests write to `/sdcard/test-outputs/`; Gradle pulls contents to `build/outputs/connected_android_test_additional_output/` after execution. Useful for custom screenshot capture, coverage `.ec` files with Orchestrator + `clearPackageData`, or any test-generated artifacts.

### GMD testDistribution

Distribute tests across multiple managed device instances for parallel execution (AGP 8.2+):

```kotlin
android {
    testOptions {
        managedDevices {
            groups {
                create("ciDevices") {
                    targetDevices.addAll(listOf(devices["pixel6api34"]))
                    testDistribution { maxParallelDevices = 4 }
                }
            }
        }
    }
}
```

Run with `./gradlew ciDevicesGroupDebugAndroidTest`. GMD provisions up to `maxParallelDevices` instances and distributes test classes across them.

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

### gradle.properties Runner Arguments

Set persistent instrumentation runner arguments in `gradle.properties` to avoid repeating CLI `-P` flags:

```properties
# gradle.properties — applied to all connectedAndroidTest runs
android.testInstrumentationRunnerArguments.clearPackageData=true
android.testInstrumentationRunnerArguments.disableAnalytics=true
```

Override per-invocation with CLI flags: `./gradlew connectedAndroidTest -Pandroid.testInstrumentationRunnerArguments.clearPackageData=false`. CLI `-P` flags take precedence over `gradle.properties` values.

### Device Hardening for CI

Run this script **post-boot, pre-test** to eliminate common CI-specific flakiness sources beyond animation disabling. Combines screen-wake, input, and hidden API settings into a single idempotent block:

```bash
#!/bin/bash
# ci-device-harden.sh — Run after emulator boot, before test execution

# Prevent screen sleep (max int32 timeout = ~24 days)
adb shell settings put system screen_off_timeout 2147483647

# Keep screen awake while USB-connected (bit flag: 1=AC, 2=USB, 4=wireless)
adb shell svc power stayon usb

# Unlock screen (dismiss swipe/keyguard)
adb shell input keyevent 82

# Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Disable spell checker (prevents flaky EditText input tests)
adb shell settings put secure spell_checker_enabled 0

# Show soft keyboard even with hardware keyboard attached (emulator has hw keyboard)
adb shell settings put secure show_ime_with_hard_keyboard 1

# Suppress hidden API access warnings/errors (API 28+)
# Value 1 = allow all hidden API access without logging
adb shell settings put global hidden_api_policy 1
adb shell settings put global hidden_api_policy_pre_p_apps 1
adb shell settings put global hidden_api_policy_p_apps 1
```

**Why `hidden_api_policy`:** AndroidX Test internals and some testing libraries (Espresso, UIAutomator) use hidden APIs via reflection. On API 28+ the platform logs warnings or throws exceptions for non-SDK interface access. Setting the policy to `1` suppresses both warnings and restrictions, preventing spurious test failures on strict API levels.

**Why `screen_off_timeout`:** CI emulators with default timeout (30s-2min) can turn off the screen mid-test, causing `NoActivityResumed` or touch injection failures. The max int32 value effectively disables the timeout.

> For OEM-specific device hardening (Samsung Knox, Xiaomi MIUI), see `device-setup-oem.md`.

### KVM Setup on GitHub Actions

KVM (Kernel-based Virtual Machine) is required for acceptable emulator performance on Linux CI runners. Without KVM, emulator boot takes ~143s vs ~15s with KVM, and API 31+ may fail to boot entirely.

**Standard Ubuntu runners** (`ubuntu-latest`): KVM device exists but requires permission fix via udev rules. Larger runners (`ubuntu-latest-4-cores` and above) have KVM enabled by default.

```yaml
# GitHub Actions step — add before emulator usage
- name: Enable KVM
  run: |
    echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --name-match=kvm
```

**What this does:** Creates a udev rule granting world-readable/writable access to `/dev/kvm`, reloads the udev daemon, and triggers the rule. The `static_node=kvm` option ensures the rule applies even before the device node is created by the kernel.

**Verification step (optional):**

```yaml
- name: Verify KVM
  run: |
    ls -la /dev/kvm
    emulator -accel-check 2>&1
    # Expected: "accel: 0" (KVM usable)
```

**macOS runners:** Use Hypervisor.framework automatically -- no setup required. Verify with `sysctl kern.hv_support` (returns `1` if available).

**Self-hosted Linux runners:** Install KVM packages if not present:

```bash
sudo apt-get install -y qemu-kvm libvirt-daemon-system
sudo usermod -aG kvm $(whoami)
# Re-login or: newgrp kvm
```

### GitLab CI Docker-in-Docker Emulator Setup

Running Android emulators in GitLab CI requires a dedicated runner with KVM access -- shared runners do not expose `/dev/kvm`.

```yaml
# .gitlab-ci.yml
android-emulator-tests:
  image: thyrlian/android-sdk:latest
  tags: [kvm]  # dedicated runner with KVM
  before_script:
    - yes | sdkmanager --licenses
    - sdkmanager "system-images;android-34;google_apis;x86_64"
    - echo "no" | avdmanager create avd -n ci -k "system-images;android-34;google_apis;x86_64"
  script:
    - emulator @ci -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect &
    - adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 2; done'
    - ./gradlew connectedDebugAndroidTest
```

Configure the GitLab Runner with KVM passthrough in `config.toml`:

```toml
[[runners]]
  [runners.docker]
    privileged = true
    devices = ["/dev/kvm"]
```

**Alternative Docker images:** `reactnativecommunity/react-native-android` (pre-installed SDKs, larger but ready-to-use), `thyrlian/android-sdk` (minimal, pull only what you need). **Limitation:** GitLab shared runners on gitlab.com do not provide KVM; use self-managed runners or group runners with nested virtualization enabled.

### AVD Snapshot Caching

Cache the AVD snapshot after initial creation to skip cold boot on subsequent CI runs. Two-step pattern: generate snapshot on cache miss, restore from cache on hit.

```yaml
# GitHub Actions — AVD snapshot caching pattern
- name: AVD cache
  uses: actions/cache@v4
  id: avd-cache
  with:
    path: |
      ~/.android/avd/*
      ~/.android/adb*
    key: avd-${{ matrix.api-level }}-${{ matrix.target }}

- name: Create AVD and generate snapshot
  if: steps.avd-cache.outputs.cache-hit != 'true'
  uses: reactivecircus/android-emulator-runner@v2
  with:
    api-level: ${{ matrix.api-level }}
    target: ${{ matrix.target }}
    arch: x86_64
    force-avd-creation: false
    emulator-options: -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
    disable-animations: false
    script: echo "Generated AVD snapshot for caching."

- name: Run tests (from cached snapshot)
  uses: reactivecircus/android-emulator-runner@v2
  with:
    api-level: ${{ matrix.api-level }}
    target: ${{ matrix.target }}
    arch: x86_64
    force-avd-creation: false
    emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
    disable-animations: true
    script: ./gradlew connectedCheck
```

**Measured impact:** Snapshot restore boots in ~5-8s vs ~15s cold boot with KVM.

**Cache key must include** `api-level` AND `target` -- different system images produce incompatible snapshots.

**Caveats:**
- Use `-no-snapshot-save` on test runs to avoid overwriting the clean snapshot with dirty state
- Running cached emulator across multiple jobs in the same workflow can cause hangs (issue #362) -- use separate cache keys per job if needed
- GitHub Actions cache is immutable per key -- to refresh a stale snapshot, bump a version suffix in the key (e.g., `avd-30-aosp_atd-v2`)

### reactivecircus/android-emulator-runner vs Manual Setup

| Aspect | `android-emulator-runner` Action | Manual `emulator` + `adb` |
|--------|----------------------------------|---------------------------|
| Abstraction | High -- handles AVD creation, boot wait, KVM | Low -- full control over each step |
| Retry on boot failure | Built-in (configurable attempts) | Must implement manually |
| Snapshot caching | Integrates with `actions/cache` | Manual cache key management |
| Multi-emulator | Single emulator per step | Multiple concurrent instances via `-port` |
| Emulator console access | Not exposed | Full telnet console access |
| Custom snapshots | Not supported (uses default quick-boot) | Full `-snapshot` flag support |
| Best for | Standard single-device CI workflows | Complex multi-device, custom boot, or non-GitHub CI |

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

**Marathon-based quarantine with retry budgets:** See `test-espresso-compose.md` > Marathon Test Runner section for full Gradle plugin configuration (retryStrategy, flakinessStrategy, filteringConfiguration). Marathon implements push-to-free-device dynamic assignment rather than static sharding, reducing tail latency by ~30%.

See `test-espresso-compose.md` for `@FlakyTest` annotation usage. See `test-result-parsing.md` for flaky test detection via re-run comparison and root cause diagnosis.

### Flaky Test Detection via Repeated Runs

Identify flaky tests before they enter the quarantine pipeline. Run the full suite N times and diff pass/fail outcomes per test method:

```bash
#!/bin/bash
# flaky-detect.sh — Run test suite N times, report inconsistent results
RUNS=${1:-10}
RESULTS_DIR="flaky-detection-results"
mkdir -p "$RESULTS_DIR"

for i in $(seq 1 "$RUNS"); do
  echo "=== Run $i/$RUNS ==="
  ./gradlew connectedDebugAndroidTest || true
  mkdir -p "$RESULTS_DIR/run-$i"
  cp app/build/outputs/androidTest-results/connected/*.xml "$RESULTS_DIR/run-$i/" 2>/dev/null
done

# Extract pass/fail per test across all runs
echo "=== Flaky Test Report ==="
for xml in "$RESULTS_DIR/run-1/"*.xml; do
  BASENAME=$(basename "$xml")
  PASS=0; FAIL=0
  for run in $(seq 1 "$RUNS"); do
    if grep -q 'failures="0"' "$RESULTS_DIR/run-$run/$BASENAME" 2>/dev/null; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1))
    fi
  done
  if [ "$PASS" -gt 0 ] && [ "$FAIL" -gt 0 ]; then
    echo "FLAKY: $BASENAME — passed $PASS/$RUNS, failed $FAIL/$RUNS"
  fi
done
```

**Using `count` runner argument** (single invocation, repeated per-test):

```bash
# Repeat each test 5 times within a single instrumentation run
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.count=5
```

**Recommended cadence:** Run flaky detection as a weekly scheduled CI job (not on every PR). Feed results into `@FlakyTest` annotation decisions. See `test-result-parsing.md` for automated JUnit XML diffing across runs.

### CI-Level Test Orchestration Patterns

For large test suites, CI-level orchestration provides sharding and retry capabilities beyond what the AndroidJUnitRunner offers natively. See `test-automation-tools.md` for tool-specific setup.

**Native AndroidJUnitRunner sharding:**

```bash
# Shard 0 of 4 — run in parallel CI jobs with different shardIndex values
./gradlew connectedAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.numShards=4 \
  -Pandroid.testInstrumentationRunnerArguments.shardIndex=0
```

**GitHub Actions matrix sharding:**

```yaml
strategy:
  fail-fast: false
  matrix:
    shard: [0, 1, 2, 3]
steps:
  - run: ./gradlew connectedAndroidTest \
      -Pandroid.testInstrumentationRunnerArguments.numShards=4 \
      -Pandroid.testInstrumentationRunnerArguments.shardIndex=${{ matrix.shard }}
```

**Caveat:** Native sharding uses round-robin by test method hashCode -- shard times can be unbalanced (up to 3:1 ratio). For timing-based balanced sharding, use Flank or emulator.wtf (see `test-automation-tools.md`).

**Result merging after sharded runs:**

```bash
# Merge JUnit XML from all shards (requires: pip install junitparser)
junitparser merge results/shard-*.xml merged-results.xml
```

**Gotcha:** Duplicate test names across shards (from retries) cause CI parsers to double-count. Deduplicate by test class+method before merge. See `test-result-parsing.md` for parsing strategies.

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

# Run with test sharding (parallel execution across device instances)
gcloud firebase test android run \
  --type instrumentation \
  --app app-debug.apk \
  --test app-debug-androidTest.apk \
  --device model=MediumPhone.arm,version=34 \
  --num-uniform-shards=4 \
  --use-orchestrator \
  --timeout 10m
```

**Sharding flags:**

| Flag | Purpose |
|------|---------|
| `--num-uniform-shards=N` | Split tests into N equal shards across device instances |
| `--use-orchestrator` | Run with AndroidX Test Orchestrator for per-test isolation |
| `--num-flaky-test-attempts=N` | Retry failed tests up to N times |

**Shard limits:** Physical devices: 50, ARM virtual: 200, x86 virtual: 500.

**CI integration pattern:**

```yaml
- name: Run Firebase Test Lab
  run: |
    gcloud auth activate-service-account --key-file=${{ secrets.GCP_SA_KEY }}
    gcloud config set project ${{ secrets.FIREBASE_PROJECT_ID }}
    gcloud firebase test android run \
      --app app-debug.apk \
      --test app-debug-androidTest.apk \
      --device model=MediumPhone.arm,version=34 \
      --num-uniform-shards=4 \
      --use-orchestrator \
      --timeout 10m
```

Results include JUnit XML, logcat, video, and screenshots. Use `gcloud firebase test android models list` to see available devices.

## Self-Hosted Runner Physical Device Farm

For teams needing physical device coverage beyond Firebase Test Lab, DeviceFarmer/STF (Smartphone Test Farm) is the most mature open-source solution for managing USB-connected devices and exposing them to CI.

### STF Setup

```bash
# Install STF (requires Node.js, ADB, rethinkdb)
npm install -g @devicefarmer/stf

# Start STF server (auto-detects USB-connected devices)
stf local --public-ip <your-server-ip>
# Web UI available at http://<your-server-ip>:7100
```

**Architecture:** STF uses ADB tracking to auto-detect USB-connected devices, installs an agent APK on each device, and exposes them via WebSocket. Supports remote ADB connections so CI runners do not need physical USB access to the devices.

### GitHub Actions Self-Hosted Integration

```yaml
runs-on: self-hosted
steps:
  - name: List connected devices
    run: adb devices

  - name: Harden device for CI
    run: |
      SERIAL=$(adb devices | grep -w device | head -1 | awk '{print $1}')
      adb -s "$SERIAL" shell settings put global window_animation_scale 0
      adb -s "$SERIAL" shell settings put global transition_animation_scale 0
      adb -s "$SERIAL" shell settings put global animator_duration_scale 0
      adb -s "$SERIAL" shell settings put system screen_off_timeout 2147483647
      adb -s "$SERIAL" shell svc power stayon usb

  - name: Run tests on physical device
    run: |
      SERIAL=$(adb devices | grep -w device | head -1 | awk '{print $1}')
      ANDROID_SERIAL=$SERIAL ./gradlew connectedCheck
```

### Operational Considerations

| Concern | Mitigation |
|---------|------------|
| USB disconnects | Use powered USB hubs; implement health-check + auto-reconnect scripts |
| Battery degradation | Budget for device replacement (batteries degrade under constant charge) |
| Device lock/sleep | Apply device hardening script (see above) on every CI run |
| Multi-device targeting | Always use `-s <serial>` or `$ANDROID_SERIAL` -- never rely on single-device default |
| Scaling beyond USB | For Kubernetes environments, `android-farm-operator` manages emulators + physical devices + STF in k8s clusters |

> For OEM-specific device quirks when running physical device farms, see `device-setup-oem.md`.

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

## Build Cache Optimization for Tests

Gradle build cache can skip re-execution of unchanged tasks, but instrumented tests (`connectedAndroidTest`) are **not cacheable by default** because device state is an implicit input.

**Cacheable test tasks:** Unit tests (`test`), Lint, Robolectric tests -- these are deterministic and benefit from both local and remote caching.

**Making custom tasks cacheable:** Annotate with `@CacheableTask` and declare all inputs (`@InputFile`, `@Input`) and outputs (`@OutputDirectory`, `@OutputFile`) explicitly with `@PathSensitive` annotations.

**Remote build cache** for CI (share cache across runners):

```properties
# gradle.properties
org.gradle.caching=true
# settings.gradle.kts: buildCache { remote<HttpBuildCache> { url = uri("https://cache.example.com/") } }
```

Avoid caching tasks that depend on device state, timestamps, or network responses -- these produce false cache hits.

## Anti-Patterns

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

## Pre-Flight Validation Checklist

Run these checks before any CI test execution to catch environment issues early. An agent can execute this sequence autonomously to verify readiness.

### SDK and Build Tools

```bash
# Verify SDK components installed
sdkmanager --list --installed 2>/dev/null | grep -E "build-tools|platform-tools|platforms;android"

# Verify Gradle wrapper present and executable
[ -x "./gradlew" ] && echo "Gradle wrapper OK" || echo "FAIL: ./gradlew missing or not executable"

# Verify ANDROID_HOME / ANDROID_SDK_ROOT set
[ -n "$ANDROID_HOME" ] && echo "ANDROID_HOME=$ANDROID_HOME" || echo "WARN: ANDROID_HOME not set"
```

### Emulator Readiness

```bash
# Verify emulator binary available
command -v emulator >/dev/null && echo "Emulator OK" || echo "FAIL: emulator not on PATH"

# List available AVDs
avdmanager list avd -c

# Verify system image installed for target API
sdkmanager --list --installed 2>/dev/null | grep "system-images;android-34"

# Verify hardware acceleration (KVM on Linux, HVF on macOS)
emulator -accel-check 2>&1
# Expected: "accel: 0" (KVM usable) or "HAXM version ... is installed"
```

### ADB and Device Connectivity

```bash
# Verify ADB responsive
adb version >/dev/null 2>&1 && echo "ADB OK" || echo "FAIL: ADB not available"

# Check connected devices/emulators
DEVICES=$(adb devices | grep -c -E "device$|emulator")
echo "Connected devices: $DEVICES"

# If emulator running, verify boot complete
adb shell getprop sys.boot_completed 2>/dev/null | grep -q "1" && \
  echo "Device booted" || echo "WARN: Device not fully booted"

# Verify animations disabled
for scale in window_animation_scale transition_animation_scale animator_duration_scale; do
  VAL=$(adb shell settings get global $scale 2>/dev/null)
  [ "$VAL" = "0" ] || [ "$VAL" = "0.0" ] || echo "WARN: $scale = $VAL (should be 0)"
done
```

### Test APK Buildability

```bash
# Quick compile check (no test execution)
./gradlew assembleDebug assembleDebugAndroidTest --dry-run 2>&1 | tail -5
# If --dry-run succeeds, task graph is valid

# Verify test APK exists (after build)
TEST_APK=$(find . -path "*/outputs/apk/androidTest/debug/*.apk" | head -1)
[ -n "$TEST_APK" ] && echo "Test APK: $TEST_APK" || echo "WARN: No test APK found"
```

### Full Pre-Flight Script

```bash
#!/bin/bash
# pre-flight.sh — Run before CI test execution
ERRORS=0
check() { if ! eval "$1" >/dev/null 2>&1; then echo "FAIL: $2"; ERRORS=$((ERRORS+1)); else echo "OK: $2"; fi }

check "command -v adb"          "ADB on PATH"
check "command -v emulator"     "Emulator on PATH"
check "[ -x ./gradlew ]"       "Gradle wrapper executable"
check "[ -n \$ANDROID_HOME ]"  "ANDROID_HOME set"
check "emulator -accel-check 2>&1 | grep -q 'is installed\|accel: 0'" "HW acceleration"
check "adb devices | grep -qE 'device$|emulator'" "Device connected"
check "adb shell getprop sys.boot_completed | grep -q 1" "Device booted"
check "[ \$(df -h \$ANDROID_HOME 2>/dev/null | awk 'NR==2{print \$4}' | sed 's/G//') -gt 10 ] 2>/dev/null || true" "Disk space >10GB free"

[ $ERRORS -eq 0 ] && echo "Pre-flight PASSED" || { echo "Pre-flight FAILED ($ERRORS errors)"; exit 1; }
```

## Coverage Threshold Enforcement

Parse JaCoCo XML reports to enforce coverage gates in CI without external tools. For JaCoCo setup and merging, see `test-coverage-gmd.md`.

### Parse JaCoCo XML

```bash
# JaCoCo XML location (after running coverage task)
# ./gradlew createDebugCoverageReport
JACOCO_XML="app/build/reports/coverage/androidTest/debug/report.xml"

# Extract overall line coverage percentage
LINE_COV=$(xmllint --xpath \
  'string(//counter[@type="LINE"]/@covered)' "$JACOCO_XML")
LINE_MISS=$(xmllint --xpath \
  'string(//counter[@type="LINE"]/@missed)' "$JACOCO_XML")
LINE_PCT=$(python3 -c "print(f'{$LINE_COV / ($LINE_COV + $LINE_MISS) * 100:.1f}')")
echo "Line coverage: ${LINE_PCT}%"

# Extract branch coverage
BRANCH_COV=$(xmllint --xpath \
  'string(//counter[@type="BRANCH"]/@covered)' "$JACOCO_XML")
BRANCH_MISS=$(xmllint --xpath \
  'string(//counter[@type="BRANCH"]/@missed)' "$JACOCO_XML")
BRANCH_PCT=$(python3 -c "print(f'{$BRANCH_COV / ($BRANCH_COV + $BRANCH_MISS) * 100:.1f}')")
echo "Branch coverage: ${BRANCH_PCT}%"
```

### Threshold Gate Script

```bash
#!/bin/bash
# coverage-gate.sh — Fail CI if coverage below threshold
MIN_LINE=70
MIN_BRANCH=50
JACOCO_XML="${1:-app/build/reports/coverage/androidTest/debug/report.xml}"

extract() {
  COV=$(xmllint --xpath "string(//counter[@type=\"$1\"]/@covered)" "$JACOCO_XML")
  MISS=$(xmllint --xpath "string(//counter[@type=\"$1\"]/@missed)" "$JACOCO_XML")
  python3 -c "print(f'{$COV / ($COV + $MISS) * 100:.1f}')"
}

LINE_PCT=$(extract LINE)
BRANCH_PCT=$(extract BRANCH)

echo "Line coverage:   ${LINE_PCT}% (min: ${MIN_LINE}%)"
echo "Branch coverage: ${BRANCH_PCT}% (min: ${MIN_BRANCH}%)"

FAIL=0
python3 -c "exit(0 if $LINE_PCT >= $MIN_LINE else 1)" || { echo "FAIL: Line coverage below ${MIN_LINE}%"; FAIL=1; }
python3 -c "exit(0 if $BRANCH_PCT >= $MIN_BRANCH else 1)" || { echo "FAIL: Branch coverage below ${MIN_BRANCH}%"; FAIL=1; }

exit $FAIL
```

### Per-Package Coverage Breakdown

```bash
# List coverage by package (top-level report element children)
xmllint --xpath '//package' "$JACOCO_XML" 2>/dev/null | \
  grep -o 'name="[^"]*"' | sed 's/name="//;s/"//' | while read pkg; do
    COV=$(xmllint --xpath "string(//package[@name=\"$pkg\"]/counter[@type=\"LINE\"]/@covered)" "$JACOCO_XML")
    MISS=$(xmllint --xpath "string(//package[@name=\"$pkg\"]/counter[@type=\"LINE\"]/@missed)" "$JACOCO_XML")
    PCT=$(python3 -c "print(f'{$COV / ($COV + $MISS) * 100:.1f}')" 2>/dev/null || echo "N/A")
    echo "$pkg: ${PCT}%"
  done
```
