# Benchmark CLI Reference

End-to-end CLI workflows for Android benchmarking: Microbenchmark, Macrobenchmark, startup measurement, Baseline Profiles, APK size tracking, and benchmark regression detection.

> For Perfetto trace analysis and frame timing, see `performance-profiling.md`. For CI pipeline integration, see `ci-pipeline-config.md`. For test execution patterns, see `test-espresso-compose.md`.

## Microbenchmark Setup and Execution

Microbenchmarks measure tight code loops (serialization, algorithms, data transformations) on-device with nanobenchmark precision.

### Module Setup

```kotlin
// benchmark/build.gradle.kts
plugins {
    id("com.android.library")
    id("androidx.benchmark")
}

android {
    namespace = "com.example.benchmark"
    defaultConfig {
        testInstrumentationRunner = "androidx.benchmark.junit4.AndroidBenchmarkRunner"
    }
    testBuildType = "release"
    buildTypes {
        release {
            isDefault = true
        }
    }
}

dependencies {
    androidTestImplementation("androidx.benchmark:benchmark-junit4:1.2.4")
}
```

### Execution

```bash
# Run all microbenchmarks
./gradlew :benchmark:connectedBenchmarkAndroidTest

# Run specific benchmark class
./gradlew :benchmark:connectedBenchmarkAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.benchmark.JsonParsingBenchmark

# Output location
# build/outputs/connected_android_test_additional_output/benchmarkRelease/connected/<device>/
# Files: *.json (machine-readable), *.txt (human-readable)
```

### JSON Output Format

```json
{
  "context": {
    "build": { "model": "Pixel 6", "device": "oriole" },
    "cpuCoreCount": 8,
    "cpuLocked": true
  },
  "benchmarks": [
    {
      "name": "jsonParsing",
      "className": "com.example.benchmark.JsonParsingBenchmark",
      "metrics": {
        "timeNs": {
          "minimum": 12500,
          "maximum": 15200,
          "median": 13100,
          "runs": [13100, 12500, 13400, 14200, 15200]
        },
        "allocationCount": {
          "minimum": 42,
          "maximum": 42,
          "median": 42,
          "runs": [42, 42, 42, 42, 42]
        }
      }
    }
  ]
}
```

### Parse Benchmark Results

```bash
# Extract median times for all benchmarks
cat build/outputs/connected_android_test_additional_output/benchmarkRelease/connected/*/*.json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for b in data['benchmarks']:
    ns = b['metrics']['timeNs']['median']
    print(f\"{b['className']}.{b['name']}: {ns/1e6:.3f} ms ({ns} ns)\")
"
```

## Macrobenchmark Deep Dive

Macrobenchmarks measure user-visible performance: app startup, scroll jank, animations.

### Module Setup

```kotlin
// macrobenchmark/build.gradle.kts
plugins {
    id("com.android.test")
    id("androidx.baselineprofile") // optional, for profile generation
}

android {
    namespace = "com.example.macrobenchmark"
    targetProjectPath = ":app"
    experimentalProperties["android.experimental.self-instrumenting"] = true

    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
}

dependencies {
    implementation("androidx.benchmark:benchmark-macro-junit4:1.2.4")
}
```

### Execution

```bash
# Run all macrobenchmarks
./gradlew :macrobenchmark:connectedBenchmarkAndroidTest

# Run specific test
./gradlew :macrobenchmark:connectedBenchmarkAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.macrobenchmark.StartupBenchmark
```

### CompilationMode Options

| Mode | Effect | When to Use |
|------|--------|-------------|
| `CompilationMode.None()` | No AOT — fully interpreted/JIT | Worst-case startup |
| `CompilationMode.Partial()` | Baseline Profile only | Realistic first-launch after install |
| `CompilationMode.Full()` | Full AOT (`speed` profile) | Best-case after background dex optimization |
| `CompilationMode.Ignore()` | Skip compilation reset | Measure current device state |

### Metric Types

| Metric | Measures | Key Output |
|--------|----------|------------|
| `StartupTimingMetric()` | Time to initial/full display | `timeToInitialDisplayMs`, `timeToFullDisplayMs` |
| `FrameTimingMetric()` | Per-frame render times | `frameDurationCpuMs` (P50, P90, P95, P99) |
| `TraceSectionMetric("name")` | Custom trace section duration | Duration of `Trace.beginSection("name")` blocks |
| `PowerMetric(type)` | Battery consumption (API 29+) | `powerCategoryMw` by component |

### Output

Results written to `build/outputs/connected_android_test_additional_output/` as JSON. Same format as Microbenchmark with metric-specific keys.

## Startup Measurement

### Quick Measurement with am start

```bash
# Cold start (force-stop first)
adb shell am force-stop com.example.app
adb shell am start-activity -W -n com.example.app/.MainActivity

# Output:
# Status: ok
# LaunchState: COLD
# Activity: com.example.app/.MainActivity
# TotalTime: 850
# WaitTime: 870

# Warm start (back out, don't force-stop)
adb shell am start-activity -W -n com.example.app/.MainActivity
```

| Field | Meaning |
|-------|---------|
| `TotalTime` | Time from launch intent to activity `onResume()` completion |
| `WaitTime` | TotalTime + system overhead (process creation, zygote fork) |
| `LaunchState` | COLD (new process), WARM (process exists, new activity), HOT (existing activity) |

### Detect reportFullyDrawn

For apps that call `reportFullyDrawn()` after data loads:

```bash
# Start app and watch for fully drawn
adb shell am start-activity -W -n com.example.app/.MainActivity
adb logcat -d | grep -i "fullyDrawnReported\|Fully drawn"
# Output: ActivityTaskManager: Fully drawn com.example.app/.MainActivity: +1s200ms
```

### Automated Startup Timing Script

```bash
#!/bin/bash
# Measure cold startup 5 times, report average
PACKAGE="com.example.app"
ACTIVITY="$PACKAGE/.MainActivity"
TOTAL=0
RUNS=5

for i in $(seq 1 $RUNS); do
  adb shell am force-stop "$PACKAGE"
  sleep 1
  TIME=$(adb shell am start-activity -W -n "$ACTIVITY" 2>/dev/null | \
    grep TotalTime | awk '{print $2}')
  echo "Run $i: ${TIME}ms"
  TOTAL=$((TOTAL + TIME))
done

AVG=$((TOTAL / RUNS))
echo "Average cold start: ${AVG}ms ($RUNS runs)"
```

### am start vs Macrobenchmark

| Aspect | `am start -W` | Macrobenchmark |
|--------|----------------|----------------|
| Setup effort | None | Separate module + dependencies |
| Metric accuracy | Coarse (ms resolution) | High (ns, Perfetto-backed) |
| CompilationMode control | Manual (`cmd package compile`) | Built-in per-test |
| Automated regression detection | Script it yourself | JSON output, CI-ready |
| Trace capture | No | Automatic Perfetto traces |

Use `am start -W` for quick checks. Use Macrobenchmark for CI-integrated regression tracking.

## Baseline Profiles from CLI

### Generate

```bash
# Generate Baseline Profile (requires macrobenchmark module with BaselineProfileGenerator)
./gradlew :app:generateBaselineProfile

# Or generate for specific build variant
./gradlew :app:generateReleaseBaselineProfile
```

Output: `app/src/main/generated/baselineProfiles/baseline-prof.txt`

### Profile Rules Syntax

```
# baseline-prof.txt — human-readable rules
HSPLcom/example/app/MainActivity;->onCreate(Landroid/os/Bundle;)V
HSPLcom/example/app/data/Repository;->fetch()Ljava/lang/Object;
PLcom/example/app/ui/HomeScreen;->**(**)**
```

| Flag | Meaning |
|------|---------|
| `H` | Hot method (frequently called) — AOT compiled |
| `S` | Startup method — compiled before app launch |
| `P` | Post-startup method — compiled after launch |
| `L` | Following is a class (not method) |

### Verify Profile Installation

```bash
# Check compilation status
adb shell dumpsys package com.example.app | grep -A5 "dexopt"
# Look for: [status=speed-profile] indicating profile-guided compilation

# Force compile with profile
adb shell cmd package compile -m speed-profile -f com.example.app

# Verify profile exists on device
adb shell cmd package dump-profiles com.example.app
```

### A/B Comparison

```bash
# 1. Measure WITHOUT profile
adb shell cmd package compile -m verify -f com.example.app  # Reset to no compilation
# Run startup benchmark or am start -W

# 2. Measure WITH profile
adb shell cmd package compile -m speed-profile -f com.example.app
# Run same benchmark

# 3. Compare results
```

## APK Size Tracking

### Size Breakdown with apkanalyzer

```bash
# Overall size
apkanalyzer apk file-size app-release.apk
apkanalyzer apk download-size app-release.apk  # Compressed download size

# Size by component
apkanalyzer files list app-release.apk | head -20
apkanalyzer dex packages --defined-only app-release.apk | head -20

# Resources breakdown
apkanalyzer resources configs --type drawable app-release.apk

# DEX method/reference count (64K limit monitoring)
apkanalyzer dex references app-release.apk

# Compare two APKs
apkanalyzer apk compare old-release.apk new-release.apk
```

### Size Tracking with bundletool

```bash
# Build universal APK from AAB
bundletool build-apks --bundle=app-release.aab --output=app.apks --mode=universal

# Get size for specific device config
bundletool get-size total --apks=app.apks
bundletool get-size total --apks=app.apks --device-spec=device-spec.json

# Generate device spec from connected device
bundletool get-device-spec --output=device-spec.json
```

### CI Size Threshold Enforcement

```bash
#!/bin/bash
# Fail CI if APK exceeds size threshold
MAX_SIZE_BYTES=20971520  # 20 MB
APK="app/build/outputs/apk/release/app-release.apk"

ACTUAL=$(stat -f%z "$APK" 2>/dev/null || stat -c%s "$APK" 2>/dev/null)
if [ "$ACTUAL" -gt "$MAX_SIZE_BYTES" ]; then
  echo "APK size regression: ${ACTUAL} bytes exceeds limit of ${MAX_SIZE_BYTES} bytes"
  exit 1
fi
echo "APK size OK: ${ACTUAL} bytes (limit: ${MAX_SIZE_BYTES})"
```

## Benchmark Regression Detection

### Parse and Compare JSON Results

```bash
# Extract median values from two benchmark runs
extract_medians() {
  python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
for b in data['benchmarks']:
    for metric, values in b['metrics'].items():
        print(f\"{b['name']},{metric},{values['median']}\")
" "$1"
}

# Compare baseline vs current
paste <(extract_medians baseline.json) <(extract_medians current.json) | \
while IFS=$'\t' read baseline current; do
  NAME=$(echo "$baseline" | cut -d, -f1,2)
  BASE_VAL=$(echo "$baseline" | cut -d, -f3)
  CURR_VAL=$(echo "$current" | cut -d, -f3)
  PCT=$(python3 -c "print(f'{($CURR_VAL - $BASE_VAL) / $BASE_VAL * 100:.1f}')")
  echo "$NAME: ${BASE_VAL} → ${CURR_VAL} (${PCT}%)"
done
```

### Threshold-Based Alerting

```bash
# Fail if any benchmark regresses more than 15%
THRESHOLD=15
REGRESSIONS=$(compare_benchmarks baseline.json current.json | \
  awk -F'[(%)]' '{if ($2 > '"$THRESHOLD"') print}')

if [ -n "$REGRESSIONS" ]; then
  echo "Benchmark regressions detected (>${THRESHOLD}% slower):"
  echo "$REGRESSIONS"
  exit 1
fi
```

### Statistical Considerations

- **Minimum 10 iterations** per benchmark for meaningful medians
- **P90/P99** more useful than mean for user-facing metrics (startup, scroll)
- **Device temperature** affects results — cool down between runs
- **Coefficient of Variation (CV)**: If CV > 5%, results are noisy — increase iterations or stabilize device

## Physical Device Requirements

Emulator benchmarks are **unreliable** — CPU emulation, no real GPU, no thermal throttling. Always benchmark on physical devices.

### Device Preparation Checklist

```bash
# 1. Airplane mode (eliminates network interference)
adb shell cmd connectivity airplane-mode enable

# 2. Do Not Disturb (prevents notification rendering overhead)
adb shell cmd notification set_dnd on

# 3. Screen brightness fixed (prevents adaptive brightness CPU usage)
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 128

# 4. Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# 5. Check thermal state (don't benchmark when hot)
adb shell "for z in /sys/class/thermal/thermal_zone*/; do echo \$(cat \${z}type): \$(cat \${z}temp); done"
# If any zone > 45000 (45°C), wait before benchmarking

# 6. Lock CPU governor (root required — prevents frequency scaling)
adb shell "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" 2>/dev/null
# If no root: Macrobenchmark's lockClocks() handles this automatically

# 7. Kill background apps
adb shell am kill-all
```

### Why Emulator Benchmarks Fail

| Factor | Emulator | Physical Device |
|--------|----------|-----------------|
| CPU | Translated (QEMU) or host-shared | Actual ARM/ARM64 silicon |
| GPU | SwiftShader (software) | Hardware GPU with driver |
| Thermal | None | Real thermal throttling |
| Memory | Host-allocated, swap possible | Fixed LPDDR with real latency |
| Storage | Host filesystem proxy | UFS/eMMC with real I/O patterns |
| Scheduler | Host OS scheduler interference | Android-native scheduler |

Emulator numbers are directionally useful (relative comparison only) but absolute values are meaningless for production performance decisions.
