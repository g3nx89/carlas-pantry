# CI/CD Integration and Workflow Recipes

Patterns for integrating Genymotion Desktop into CI pipelines and complete automation scripts.

## The Fundamental Constraint

**Genymotion Desktop has no headless mode.** It requires full GPU acceleration and a GUI to render the device display. Cannot run on standard CI VMs, VPS, or cloud instances.

Three workarounds exist:

### 1. Self-Hosted CI Runner with GPU and Display (Supported)

Requires bare-metal machine with GPU, X server, and Genymotion Desktop installed. Set `DISPLAY=:0` environment variable.

On Linux without a physical display, use Xvfb (X Virtual Framebuffer) to provide a virtual display context:
```bash
# Start virtual display (add to CI setup)
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99

# Or use xvfb-run wrapper (auto-manages server lifecycle)
xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
  gmtool admin start "DeviceName"
```
This is unsupported by Genymotion but widely used in the community. Performance degrades with software rendering.

### 2. VBoxManage Headless (Community, Unsupported)

Bypass Genymotion's player and start VMs headlessly through VirtualBox:

```bash
VBoxManage startvm <VM-UUID> --type headless
IP=$(VBoxManage guestproperty get <VM-UUID> androvm_ip_management | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
adb connect ${IP}:5555
```

### 3. Genymotion SaaS via gmsaas (Recommended for CI)

Works on any runner:

```bash
pip install gmsaas
gmsaas auth token $API_TOKEN
UUID=$(gmsaas instances start <RECIPE_UUID> "test-device")
gmsaas instances adbconnect $UUID
# Run tests...
gmsaas instances stop $UUID
```

## License Management in CI

```bash
gmtool config --email "$GENY_EMAIL" --password "$GENY_PASSWORD"
gmtool license register "$GENY_LICENSE_KEY"
gmtool license validity   # Returns days remaining
```

Store credentials as CI secrets. License is per-machine — ephemeral CI environments consume activations.

**License lockout prevention**: CI jobs that crash without cleanup can leave licenses consumed. Always implement a trap:
```bash
cleanup() {
    gmtool admin stop "$DEVICE" 2>/dev/null || true
    gmtool admin delete "$DEVICE" 2>/dev/null || true
}
trap cleanup EXIT
```

**Single-user constraint**: "If you have different users on your machine, only use GMTool for one user." In multi-user CI environments, isolate to separate machines or containers per user.

## GitHub Actions

### Desktop (Self-Hosted Runner)

```yaml
name: Tests (Genymotion Desktop)
on: [push]
jobs:
  test:
    runs-on: [self-hosted, linux, genymotion]
    timeout-minutes: 30
    env:
      GMTOOL: /opt/genymotion/gmtool
      DEVICE: ci-${{ github.run_id }}
      DISPLAY: ":0"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '17', distribution: 'temurin' }
      - name: Setup
        run: |
          $GMTOOL config --email "${{ secrets.GENY_EMAIL }}" --password "${{ secrets.GENY_PASSWORD }}"
          $GMTOOL license register "${{ secrets.GENY_LICENSE }}" || true
          $GMTOOL admin create "Samsung Galaxy S10" "Android 11.0" "$DEVICE" --nbcpu 4 --ram 4096
          $GMTOOL --timeout 300 admin start "$DEVICE"
          $GMTOOL device -n "$DEVICE" adbconnect
          for i in $(seq 1 60); do
            bc=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
            ba=$(adb shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")
            if [ "$bc" = "1" ] && [ "$ba" = "stopped" ]; then
              adb shell pm list packages 2>/dev/null | head -1 | grep -q "package:" && break
            fi
            sleep 5
          done
          adb shell input keyevent 82
          adb shell settings put global window_animation_scale 0
          adb shell settings put global transition_animation_scale 0
          adb shell settings put global animator_duration_scale 0
      - run: ./gradlew connectedDebugAndroidTest
      - if: always()
        run: |
          $GMTOOL device -n "$DEVICE" logcatdump logcat.txt || true
          $GMTOOL admin stop "$DEVICE" || true
          $GMTOOL admin delete "$DEVICE" || true
```

### SaaS (Any Runner)

```yaml
- uses: genymobile/genymotion-saas-github-action@v1
  with:
    api_token: ${{ secrets.GMSAAS_APITOKEN }}
    recipe_uuid: ea5fda48-fa8b-48c1-8acc-07d910856141
```

## GitLab CI (Self-Hosted Runner)

```yaml
android-test:
  tags: [genymotion, gpu]
  variables:
    GMTOOL: /opt/genymotion/gmtool
    DISPLAY: ":0"
  before_script:
    - $GMTOOL config --email "$GENY_EMAIL" --password "$GENY_PASSWORD"
    - $GMTOOL license register "$GENY_LICENSE_KEY" || true
  script:
    - DEVICE="ci-${CI_JOB_ID}"
    - $GMTOOL admin create "Samsung Galaxy S10" "Android 11.0" "$DEVICE" --nbcpu 4 --ram 4096
    - $GMTOOL --timeout 300 admin start "$DEVICE"
    - $GMTOOL device -n "$DEVICE" adbconnect
    - |
      for i in $(seq 1 60); do
        bc=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
        ba=$(adb shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")
        if [ "$bc" = "1" ] && [ "$ba" = "stopped" ]; then
          adb shell pm list packages 2>/dev/null | head -1 | grep -q "package:" && break
        fi
        sleep 5
      done
      adb shell input keyevent 82
    - ./gradlew connectedDebugAndroidTest
  after_script:
    - $GMTOOL admin stop "ci-${CI_JOB_ID}" || true
    - $GMTOOL admin delete "ci-${CI_JOB_ID}" || true
  artifacts:
    when: always
    paths: [app/build/reports/]
```

---

## Workflow Recipes

> For the complete GMTool and Genymotion Shell command reference, see `cli-reference.md`.

### Recipe 1: Single Device Test Run

```bash
#!/usr/bin/env bash
set -euo pipefail

GMTOOL="${GENYMOTION_PATH:-/opt/genymotion}/gmtool"
GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
DEVICE="test-$$"
HW_PROFILE="${HW_PROFILE:-Samsung Galaxy S10}"
OS_IMAGE="${OS_IMAGE:-Android 11.0}"
BOOT_TIMEOUT=120

cleanup() {
    echo "==> Cleanup..."
    "$GMTOOL" device -n "$DEVICE" logcatdump "logcat-${DEVICE}.txt" 2>/dev/null || true
    "$GMTOOL" admin stop "$DEVICE" 2>/dev/null || true
    "$GMTOOL" admin delete "$DEVICE" 2>/dev/null || true
}
trap cleanup EXIT

"$GMTOOL" admin create "$HW_PROFILE" "$OS_IMAGE" "$DEVICE" --nbcpu 4 --ram 4096
"$GMTOOL" --timeout 300 admin start "$DEVICE"
"$GMTOOL" device -n "$DEVICE" adbconnect

adb wait-for-device
elapsed=0
while [ $elapsed -lt $BOOT_TIMEOUT ]; do
    bc=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
    ba=$(adb shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")
    if [ "$bc" = "1" ] && [ "$ba" = "stopped" ]; then
        # Verify package manager is ready (prevents INSTALL_FAILED race)
        adb shell pm list packages 2>/dev/null | head -1 | grep -q "package:" && break
    fi
    sleep 5; elapsed=$((elapsed + 5))
done
[ "$bc" != "1" ] && echo "ERROR: Boot timeout" && exit 1
adb shell input keyevent 82

adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

"$GMTOOL" device -n "$DEVICE" install app-debug.apk
adb install -t app-debug-androidTest.apk
./gradlew connectedDebugAndroidTest
TEST_RESULT=$?

if [ $TEST_RESULT -ne 0 ]; then
    adb shell screencap /sdcard/failure.png
    adb pull /sdcard/failure.png ./
fi
exit $TEST_RESULT
```

### Recipe 2: Multi-Device Parallel Testing with Sharding

> For sensor reset between suites, see `emulated-features/sensor-management.md`.

```bash
#!/usr/bin/env bash
set -euo pipefail

GMTOOL="${GENYMOTION_PATH:-/opt/genymotion}/gmtool"
NBCPU="${NBCPU:-2}"
RAM="${RAM:-2048}"
DEVICES=()
PIDS=()

# Configure device matrix: "HW_PROFILE|OS_IMAGE" per shard
CONFIGS=(
    "${CONFIG_0:-Samsung Galaxy S10|Android 11.0}"
    "${CONFIG_1:-Custom Phone|Android 13.0}"
    "${CONFIG_2:-Google Pixel 4|Android 12.0}"
)
NUM_SHARDS=${#CONFIGS[@]}

cleanup() {
    for d in "${DEVICES[@]}"; do
        "$GMTOOL" admin stop "$d" 2>/dev/null || true
        "$GMTOOL" admin delete "$d" 2>/dev/null || true
    done
}
trap cleanup EXIT

for i in "${!CONFIGS[@]}"; do
    IFS='|' read -r hw os <<< "${CONFIGS[$i]}"
    name="shard-${i}-$$"
    DEVICES+=("$name")
    "$GMTOOL" admin create "$hw" "$os" "$name" --nbcpu "$NBCPU" --ram "$RAM"
    "$GMTOOL" --timeout 300 admin start "$name"
    "$GMTOOL" device -n "$name" adbconnect
done

# Collect serials in device order
SERIALS=()
for d in "${DEVICES[@]}"; do
    IP=$("$GMTOOL" admin details "$d" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    SERIALS+=("${IP}:5555")
done

# Wait for each device to boot (targeting by serial)
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

for d in "${DEVICES[@]}"; do
    "$GMTOOL" device -n "$d" install app-debug.apk
done

for i in "${!DEVICES[@]}"; do
    ANDROID_SERIAL="${SERIALS[$i]}" ./gradlew connectedDebugAndroidTest \
        -Pandroid.testInstrumentationRunnerArguments.numShards=$NUM_SHARDS \
        -Pandroid.testInstrumentationRunnerArguments.shardIndex=$i \
        2>&1 | tee "results-shard-${i}.log" &
    PIDS+=($!)
done

OVERALL=0
for pid in "${PIDS[@]}"; do
    wait "$pid" || OVERALL=1
done

# Aggregate results from all shards
echo "==> Shard results:"
for i in "${!DEVICES[@]}"; do
    if grep -q "BUILD SUCCESSFUL" "results-shard-${i}.log" 2>/dev/null; then
        echo "  Shard $i: PASS"
    else
        echo "  Shard $i: FAIL"
    fi
done

# Collect test reports from all devices
mkdir -p ./aggregated-reports
for d in "${DEVICES[@]}"; do
    "$GMTOOL" device -n "$d" pull /sdcard/Android/data/ "./aggregated-reports/${d}/" 2>/dev/null || true
    "$GMTOOL" device -n "$d" logcatdump "./aggregated-reports/logcat-${d}.txt" 2>/dev/null || true
done
exit $OVERALL
```

### Recipe 3: Sensor Simulation Testing

```bash
#!/usr/bin/env bash
set -euo pipefail

GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
mkdir -p ./screenshots

# GPS coordinate sequence
GPS_COORDS=(
    "48.8566|2.3522"     # Paris
    "40.7128|-74.0060"   # New York
    "35.6762|139.6503"   # Tokyo
)

for coord in "${GPS_COORDS[@]}"; do
    IFS='|' read -r lat lon <<< "$coord"
    "$GENYSHELL" -q -c "gps setstatus enabled"
    "$GENYSHELL" -q -c "gps setlatitude $lat"
    "$GENYSHELL" -q -c "gps setlongitude $lon"
    sleep 3
    adb shell screencap /sdcard/gps_${lat}_${lon}.png
    adb pull /sdcard/gps_${lat}_${lon}.png ./screenshots/
done

# Battery state testing
for level in 100 50 15 5 1; do
    "$GENYSHELL" -q -c "battery setmode manual"
    "$GENYSHELL" -q -c "battery setlevel $level"
    "$GENYSHELL" -q -c "battery setstatus discharging"
    sleep 2
    adb shell screencap /sdcard/battery_${level}.png
    adb pull /sdcard/battery_${level}.png ./screenshots/
done

# Orientation testing
for angle in 0 90 180 270; do
    "$GENYSHELL" -q -c "rotation setangle $angle"
    sleep 2
    adb shell screencap /sdcard/rotation_${angle}.png
    adb pull /sdcard/rotation_${angle}.png ./screenshots/
done
```

### Recipe 4: Network Condition Testing

```bash
#!/usr/bin/env bash
set -euo pipefail

GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
RESULTS_DIR="./network-results"
mkdir -p "$RESULTS_DIR"

declare -A PROFILES=(
    ["wifi_good"]="wifi|enabled|good"
    ["mobile_4g"]="mobile|enabled|great"
    ["mobile_edge"]="mobile|enabled|poor"
    ["offline"]="wifi|disabled|none"
)

for profile_name in "${!PROFILES[@]}"; do
    IFS='|' read -r iface status strength <<< "${PROFILES[$profile_name]}"
    echo "==> Testing profile: $profile_name"

    "$GENYSHELL" -q -c "network setstatus $iface $status"
    [ "$status" = "enabled" ] && "$GENYSHELL" -q -c "network setsignalstrength $iface $strength"

    if [ "$iface" = "mobile" ] && [ "$status" = "enabled" ]; then
        "$GENYSHELL" -q -c "network setmobileprofile edge"
    fi

    sleep 3

    ./gradlew connectedDebugAndroidTest \
        -Pandroid.testInstrumentationRunnerArguments.annotation=com.example.test.NetworkTest \
        2>&1 | tee "$RESULTS_DIR/${profile_name}.log"

    adb shell screencap /sdcard/net_${profile_name}.png
    adb pull /sdcard/net_${profile_name}.png "$RESULTS_DIR/"
done

# Restore normal connectivity
"$GENYSHELL" -q -c "network setstatus wifi enabled"
"$GENYSHELL" -q -c "network setsignalstrength wifi great"
```

### Recipe 5: GPX Route Playback

> For GPS parameters and testing patterns, see `emulated-features/gps.md`.

GPX route playback is GUI-only. Simulate via scripted sequential GPS commands:

```bash
#!/usr/bin/env bash
# Usage: ./drive_sim.sh <Device_IP> <Route.gpx>
set -euo pipefail

DEVICE_IP=${1:?"Usage: $0 <Device_IP> <Route.gpx>"}
GPX_FILE=${2:?"Usage: $0 <Device_IP> <Route.gpx>"}
[ ! -f "$GPX_FILE" ] && echo "ERROR: GPX file not found: $GPX_FILE" && exit 1
GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"

echo "Initializing GPS..."
"$GENYSHELL" -r "$DEVICE_IP" -c "gps setstatus enabled"

# Parse standard GPX trkpt format: <trkpt lat="X" lon="Y">
grep "<trkpt" "$GPX_FILE" | while IFS= read -r line; do
    LAT=$(echo "$line" | sed -n 's/.*lat="\([^"]*\)".*/\1/p')
    LON=$(echo "$line" | sed -n 's/.*lon="\([^"]*\)".*/\1/p')

    if [ -n "$LAT" ] && [ -n "$LON" ]; then
        echo "Moving to: $LAT, $LON"
        "$GENYSHELL" -r "$DEVICE_IP" -c "gps setlatitude $LAT"
        "$GENYSHELL" -r "$DEVICE_IP" -c "gps setlongitude $LON"
        sleep 1  # Adjust based on GPX granularity
    fi
done

echo "Route complete."
```

### Recipe 6: Network Flakiness Simulation (Progressive Degradation)

> For network profiles and signal levels, see `emulated-features/network.md`.

Simulates a user entering a zone of poor connectivity and then recovering:

```bash
#!/usr/bin/env bash
set -euo pipefail

DEVICE_IP=${1:?"Usage: $0 <Device_IP>"}
GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
gsh() { "$GENYSHELL" -r "$DEVICE_IP" -c "$1"; }

restore_network() {
    echo "Restoring network to default state..."
    gsh "network setstatus mobile enabled" 2>/dev/null || true
    gsh "network setstatus wifi enabled" 2>/dev/null || true
    gsh "network setsignalstrength wifi great" 2>/dev/null || true
}
trap restore_network EXIT

# 1. Start with good WiFi
gsh "network setstatus wifi enabled"
gsh "network setsignalstrength wifi great"
sleep 5

# 2. Degrade to 3G
echo "Degrading to 3G..."
gsh "network setstatus wifi disabled"
gsh "network setstatus mobile enabled"
gsh "network setmobileprofile umts"
gsh "network setsignalstrength mobile moderate"
sleep 5

# 3. Simulate high packet loss (tunnel/elevator)
echo "Simulating packet loss..."
gsh "network setsignalstrength mobile poor"
sleep 5

# 4. Complete connection drop
echo "Dropping connection..."
gsh "network setstatus mobile disabled"
sleep 5

# 5. Recovery
echo "Restoring connection..."
gsh "network setstatus mobile enabled"
gsh "network setmobileprofile lte"
gsh "network setsignalstrength mobile good"
sleep 2
gsh "network setstatus wifi enabled"
gsh "network setsignalstrength wifi great"
```

## ADB Recovery Pattern

Connections can drop during ADB server restarts, network adapter reconfiguration, or VPN changes:

```bash
ensure_adb_connection() {
    local device="$1"  # e.g., 192.168.56.101:5555
    if ! adb -s "$device" shell echo "ok" 2>/dev/null | grep -q "ok"; then
        adb connect "$device"
        sleep 3
        adb -s "$device" wait-for-device
    fi
}
```

## VPN Interference

Host VPN can block routing to the `192.168.56.x` host-only subnet. Configure VPN split-tunneling to exclude `192.168.56.0/24`, or disable VPN during test execution.

## Host System Stability

Abrupt host sleep, shutdown, or power loss while VMs are running can corrupt the virtual disk image (VDI or QCOW2). Recovery and prevention:

- **Quick Boot corruption**: Use `gmtool admin start "DeviceName" --coldboot` to bypass corrupt saved state
- **Full disk corruption**: Delete and recreate the device from scratch; restore from clone if using the golden master pattern (see Clone-Based Test Isolation below)
- **Prevention on macOS**: Use `caffeinate -i ./run-tests.sh` to prevent sleep during test execution
- **Prevention on Linux**: Use `systemd-inhibit --what=sleep ./run-tests.sh` or ensure CI runners disable sleep
- **Always stop VMs before host shutdown**: `gmtool admin stopall` in a shutdown hook or CI cleanup step

## Device Identity for Clones

When cloning devices for parallel testing, clones share the same Android ID and Device ID. If your backend tracks device identity, randomize after cloning:
```bash
genyshell -r "$CLONE_IP" -c "android setandroidid random"
genyshell -r "$CLONE_IP" -c "android setdeviceid random"
```

## Extended Run Device Recycling

> **Note:** For memory leak details and concurrent instance limits, see the main SKILL.md file.

For long-running test suites, restart devices periodically:

```bash
# After every N test suites, recycle the device
gmtool admin stop "$DEVICE"
sleep 5
gmtool --timeout 300 admin start "$DEVICE"
# Re-wait for boot...
```

## Snapshot Management (VirtualBox, Unofficial)

GMTool does not expose snapshot commands. Use VBoxManage directly:

```bash
VBoxManage snapshot "VM-Name" take "clean-state"
VBoxManage snapshot "VM-Name" restore "clean-state"
```

Each snapshot consumes 2-8GB. Budget ~50-100GB for a snapshot library. Refresh baselines weekly as OS and app versions change.

## Clone-Based Test Isolation

Cloning provides a supported alternative to snapshots for reproducible test environments:

```bash
# 1. Create and configure a "golden master" device (install apps, GApps, ARM translation, etc.)
gmtool admin create "Custom Phone" "Android 11.0" "golden-master" --nbcpu 2 --ram 2048
gmtool --timeout 300 admin start "golden-master"
# ... install apps, configure settings ...
gmtool admin stop "golden-master"

# 2. Before each test run, clone the golden master
gmtool admin clone "golden-master" "test-run-$$"
gmtool --timeout 300 admin start "test-run-$$"
gmtool device -n "test-run-$$" adbconnect

# 3. Randomize device identity if backend tracks devices
genyshell -q -c "android setandroidid random"
genyshell -q -c "android setdeviceid random"

# 4. Run tests on the clone
./gradlew connectedDebugAndroidTest

# 5. Discard clone after tests (golden master remains untouched)
gmtool admin stop "test-run-$$"
gmtool admin delete "test-run-$$"
```

This avoids repetitive setup (app install, GApps flash, settings configuration) on each run while keeping full test isolation. Cloning is faster than creating from scratch because it reuses the existing disk image via differencing disks.

## Device Matrix Strategy

For Kotlin + Jetpack Compose, target the latest 3-4 Android versions. Compose requires API 21+ minimum, works best on API 26+.

Recommended minimal matrix:

| Android | Resolution | Density | Profile |
|---------|-----------|---------|---------|
| 12 (API 31) | 1080x2400 | 420dpi | Mid-range phone |
| 13 (API 33) | 1440x3200 | 560dpi | Flagship phone |
| 14 (API 34) | 1080x1920 | 320dpi | Compact phone |
| 15 (API 35) | 2560x1600 | 320dpi | Tablet |

Run the full matrix nightly; top 2 configs on every PR.
