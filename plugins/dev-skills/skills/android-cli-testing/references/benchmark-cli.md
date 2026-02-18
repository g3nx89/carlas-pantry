# Benchmark CLI Reference

End-to-end CLI workflows for Android benchmarking: Microbenchmark, Macrobenchmark, startup measurement, Baseline Profiles, and benchmark regression detection.

> For APK/AAB size analysis, see `apk-size-analysis.md`. For Perfetto trace analysis and frame timing, see `performance-profiling.md`. For CI pipeline integration, see `ci-pipeline-config.md`. For test execution patterns, see `test-espresso-compose.md`.

> **TL;DR**: Run Microbenchmarks (`./gradlew :benchmark:connectedBenchmarkAndroidTest`), Macrobenchmarks for startup/scroll jank, measure cold start with `am start-activity -W`, generate Baseline Profiles (`generateBaselineProfile`), compare JSON output for regression detection, always verify `cpuLocked: true` in results.

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
        // Suppress errors for CI on non-ideal devices (emulator, debuggable builds)
        testInstrumentationRunnerArguments["androidx.benchmark.suppressErrors"] = "EMULATOR,DEBUGGABLE"
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

The `suppressErrors` argument accepts a comma-separated list of error IDs (`EMULATOR`, `DEBUGGABLE`, `LOW-BATTERY`, `ACTIVITY-MISSING`, `UNLOCKED`). Use it to unblock CI pipelines running on non-ideal hardware — the errors still appear in output but do not abort the run.

### Execution

```bash
# Run all microbenchmarks
./gradlew :benchmark:connectedBenchmarkAndroidTest

# Run specific benchmark class
./gradlew :benchmark:connectedBenchmarkAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.benchmark.JsonParsingBenchmark

# Dry run — single iteration, no measurement (CI smoke test to verify benchmarks compile and launch)
./gradlew :benchmark:connectedBenchmarkAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.dryRunMode=true

# Output location
# build/outputs/connected_android_test_additional_output/benchmarkRelease/connected/<device>/
# Files: *.json (machine-readable), *.txt (human-readable)
```

`dryRunMode=true` runs each benchmark loop exactly once with no timing. Use it in CI pull-request checks to verify benchmarks do not crash, without burning device time on actual measurement.

### Allocation Tracking and Measurement Exclusion

Allocation tracking is enabled by default — output includes `allocationCount` metric alongside timing. Use `runWithMeasurementDisabled {}` to exclude setup/teardown code from both timing and allocation counts:

```kotlin
@Test
fun jsonParsing() {
    val data: String
    benchmarkRule.measureRepeated {
        runWithMeasurementDisabled {
            data = loadTestFixture()  // excluded from timing and allocations
        }
        parser.parse(data)  // measured
    }
}
```

> **Note:** `runWithMeasurementDisabled` replaced the older `runWithTimingDisabled` API. If upgrading from benchmark library < 1.2, rename all call sites.

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

**Verify `cpuLocked`**: Always check `"cpuLocked": true` in the `context` block before trusting results. If `false`, CPU frequency scaling was active during the run and results are unreliable — rerun with proper clock locking (see Device Preparation).

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

### StartupMode Behavior

| StartupMode | Process State | Activity State | What It Tests |
|-------------|--------------|----------------|---------------|
| `COLD` | Killed | Destroyed | Full process init + activity creation |
| `WARM` | Running | Destroyed | Activity re-creation (process already warm) |
| `HOT` | Running | Stopped/Background | Activity resume from background |

**CompilationMode interaction**: pair `COLD` with `None()` for worst-case and `Partial()` for realistic first-launch to quantify Baseline Profile impact.

### CompilationMode Options

| Mode | Effect | When to Use |
|------|--------|-------------|
| `CompilationMode.None()` | No AOT — JIT enabled at runtime | Worst-case startup (not interpreted-only; JIT still runs) |
| `CompilationMode.Partial()` | Baseline Profile only | Realistic first-launch after install |
| `CompilationMode.Partial(warmupIterations=3)` | JIT warmup for N iterations, then snapshot compiled methods | Steady-state performance without full AOT; captures hot paths from real execution |
| `CompilationMode.Full()` | Full AOT (`speed` profile) | Best-case after background dex optimization |
| `CompilationMode.Ignore()` | Skip compilation reset entirely | Manual compilation control; avoids APK reinstall on API < 34 |

**`Ignore` detail**: On API < 34, the benchmark library reinstalls the APK to reset compilation state before each test. `Ignore` skips this reset entirely. Use it when you pre-compile once (e.g., `cmd package compile -m speed-profile`) and run multiple benchmarks against that fixed compilation state. Do not use it for general regression testing — leaked JIT data between tests invalidates comparisons.

### Metric Types

| Metric | Measures | Key Output |
|--------|----------|------------|
| `StartupTimingMetric()` | Time to initial/full display | `timeToInitialDisplayMs`, `timeToFullDisplayMs` |
| `FrameTimingMetric()` | Per-frame render times | `frameDurationCpuMs` (P50, P90, P95, P99) |
| `TraceSectionMetric("name")` | Custom trace section duration | Duration of `Trace.beginSection("name")` blocks |
| `PowerMetric(type)` | Battery consumption (API 29+) | `powerCategoryMw` by component |

### Perfetto SDK Tracing

Enable the Perfetto SDK tracing flag for deeper per-function traces inside the target app:

```bash
./gradlew :macrobenchmark:connectedBenchmarkAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.perfettoSdkTracing.enable=true
```

**Gotcha**: Perfetto SDK tracing loads a native library at runtime. This adds measurable latency to `COLD` startup measurements — do not enable it for startup regression tracking. Use it only when you need detailed per-function trace spans (e.g., diagnosing which specific method causes a regression already detected by standard metrics).

### Custom Trace Sections in Macrobenchmarks

**App side** -- instrument target code with `trace("LoadDashboard") { ... }` (AndroidX tracing). **Benchmark side** -- measure it with `TraceSectionMetric`:

```kotlin
// Benchmark module
benchmarkRule.measureRepeated(
    packageName = "com.example.app",
    metrics = listOf(TraceSectionMetric("LoadDashboard")),
    iterations = 10, startupMode = StartupMode.WARM
) { startActivityAndWait() }
```

Verify sections appear in captured traces:

```bash
./trace_processor build/outputs/**/*.perfetto-trace \
  --query "SELECT name, dur/1e6 AS ms FROM slice WHERE name = 'LoadDashboard'"
```

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

### reportFullyDrawn Gotchas

| Gotcha | Detail | Fix |
|--------|--------|-----|
| Not available on API 29 and below | TTFD silently missing from output — no error, just absent metric | Gate on `Build.VERSION.SDK_INT >= 29` or accept TTID-only on older APIs |
| Called before first frame renders | System collapses TTID and TTFD to the same value (data loss) | Delay the call until after the first meaningful frame is drawn |
| Called before async data loads | TTFD measures framework latency, not user-visible content readiness | Call only after RecyclerView/LazyColumn populates with real data |
| Compose placement | Calling from `onCreate` measures activity creation, not composition | Call from `LaunchedEffect` after initial composition + data load completes |

### fullyDrawnReported Implementation Pattern

```kotlin
// Compose: report after data loads and renders
val uiState by viewModel.uiState.collectAsStateWithLifecycle()
val activity = LocalContext.current as Activity
LaunchedEffect(uiState.isLoaded) {
    if (uiState.isLoaded) activity.reportFullyDrawn()
}

// View: report in data observer after layout pass
viewModel.data.observe(this) { data ->
    recyclerView.adapter = MyAdapter(data)
    recyclerView.post { reportFullyDrawn() }
}
```

**Gotcha**: calling in `onCreate` or before real data renders collapses TTID and TTFD to the same value. Calling after the measurement window (>30s) silently drops the metric from benchmarks.

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

### Cloud Profiles vs Local Profiles

| Aspect | Cloud Profile | Local Profile |
|--------|--------------|---------------|
| Source | Play Store aggregates from real users | `generateBaselineProfile` Gradle task |
| Distribution | Automatic via Play Store updates | Bundled in APK at build time |
| Coverage | Broad (real-world usage patterns) | Targeted (generator test journeys) |
| Availability | After sufficient install base | Immediately on first install |

Check active profile: `adb shell dumpsys package com.example.app | grep -i "profile\|dexopt\|compiler"`. Before benchmarking local profile impact, reset compilation state first:

```bash
adb shell cmd package compile --reset com.example.app
# Then install APK with local profile and measure startup
```

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

### R8/Obfuscation Gotcha for Profile Generation

R8 obfuscation **must** be disabled for the build variant used during profile generation. Generated profile rules reference original (unobfuscated) method signatures — if R8 renames them, the rules will not match at install time and the profile has no effect.

```kotlin
// build.gradle.kts
buildTypes {
    create("benchmark") {
        initWith(getByName("release"))
        isMinifyEnabled = false  // critical for profile generation
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Use this `benchmark` build type for profile generation. The production `release` type retains R8/minification — the generated rules are applied before obfuscation during the release build pipeline.

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
  PCT=$(python3 -c "import sys; b,c=float(sys.argv[1]),float(sys.argv[2]); print(f'{(c-b)/b*100:.1f}')" "$BASE_VAL" "$CURR_VAL")
  echo "$NAME: ${BASE_VAL} → ${CURR_VAL} (${PCT}%)"
done
```

### Verify cpuLocked in JSON Output

Before comparing results, validate that clock locking was active during both runs:

```bash
# Check cpuLocked field in benchmark JSON
python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
locked = data.get('context', {}).get('cpuLocked', False)
if not locked:
    print(f'WARNING: cpuLocked=false in {sys.argv[1]} — results unreliable')
    sys.exit(1)
print(f'OK: cpuLocked=true in {sys.argv[1]}')
" baseline.json

python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
locked = data.get('context', {}).get('cpuLocked', False)
if not locked:
    print(f'WARNING: cpuLocked=false in {sys.argv[1]} — results unreliable')
    sys.exit(1)
print(f'OK: cpuLocked=true in {sys.argv[1]}')
" current.json
```

Discard any run where `cpuLocked` is `false` — frequency scaling during measurement invalidates comparisons.

### Threshold-Based Alerting

```bash
# Fail if any benchmark regresses more than 15%
THRESHOLD=15
REGRESSIONS=$(paste <(extract_medians baseline.json) <(extract_medians current.json) | \
while IFS=$'\t' read base curr; do
  NAME=$(echo "$base" | cut -d, -f1,2)
  BASE_VAL=$(echo "$base" | cut -d, -f3)
  CURR_VAL=$(echo "$curr" | cut -d, -f3)
  PCT=$(python3 -c "import sys; b,c=float(sys.argv[1]),float(sys.argv[2]); print(f'{(c-b)/b*100:.1f}')" "$BASE_VAL" "$CURR_VAL")
  echo "$NAME: ${BASE_VAL} -> ${CURR_VAL} (${PCT}%)"
done | awk -F'[(%)]' '{if ($2 > '"$THRESHOLD"') print}')

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

### Step-Fitting Algorithm and CoV Thresholds

Google's Jetpack CI uses a **step-fitting** algorithm (via Skia Perf) for regression detection: it searches for step functions in benchmark data sequences rather than comparing single-point values.

**Parameters**:
- `WIDTH`: number of results before and after a commit to compare (sliding window)
- `THRESHOLD`: minimum regression severity to flag (default 25% in Jetpack CI)
- **Statistical method**: two-sample t-test on before/after distributions within the window

**Coefficient of Variation (CoV)** thresholds:

| CoV Range | Interpretation | Action |
|-----------|---------------|--------|
| < 5% | Stable — reliable regression detection | Trust results, use standard threshold |
| 5% - 10% | Noisy — high false-positive risk | Increase iterations, investigate device stability |
| > 10% | Unreliable — benchmark is broken | Do not report regressions; fix device setup or benchmark code first |

**Practical rule**: If CoV > 5%, flag the benchmark as unreliable rather than reporting false regressions. Require minimum 10 iterations for statistical power.

## Firebase Test Lab Benchmarking

Run benchmarks on Firebase Test Lab (FTL) physical devices for consistent CI results without maintaining a local device farm.

```bash
# Build benchmark APKs
./gradlew :macrobenchmark:assembleBenchmarkRelease :app:assembleBenchmarkRelease

# Run on FTL physical device
gcloud firebase test android run \
  --type instrumentation \
  --app app/build/outputs/apk/benchmark/release/app-benchmark-release.apk \
  --test macrobenchmark/build/outputs/apk/benchmarkRelease/macrobenchmark-benchmarkRelease.apk \
  --device model=oriole,version=33,locale=en,orientation=portrait \
  --directories-to-pull /sdcard/Android/media/com.example.macrobenchmark \
  --results-bucket gs://my-benchmark-results \
  --no-auto-google-login \
  --environment-variables clearPackageData=true
```

| Flag | Purpose |
|------|---------|
| `--directories-to-pull` | Pulls benchmark JSON and Perfetto traces from device after run |
| `--results-bucket` | GCS bucket for result storage and historical comparison |
| `--no-auto-google-login` | Prevents Play Services sign-in dialogs from interfering with benchmarks |
| `--environment-variables clearPackageData=true` | Resets app state between test methods |

After the run completes, download results from the GCS bucket and feed the JSON into the regression detection pipeline above.

## Physical Device Requirements

Emulator benchmarks are **unreliable** — CPU emulation, no real GPU, no thermal throttling. Always benchmark on physical devices.

### Device Preparation Checklist

```bash
# 1. Enable fixed performance mode (non-root, API 31+)
adb shell cmd power set-fixed-performance-mode-enabled true
# Note: does NOT prevent thermal throttling under sustained load

# 2. Lock clocks with lockClocks script (root required — most stable option)
adb push lockClocks.sh /data/local/tmp/lockClocks.sh
adb shell chmod +x /data/local/tmp/lockClocks.sh
adb shell /data/local/tmp/lockClocks.sh
# Or via Gradle: ./gradlew :benchmark:lockClocks
# lockClocks pins CPU to a low sustainable frequency — more stable than fixed-performance mode

# 3. Manual CPU governor lock (root required — alternative to lockClocks)
# Uses 'userspace' governor with min freq pinning for maximum stability
adb shell "echo userspace > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
adb shell "cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
adb shell "cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
# If no root: Macrobenchmark's lockClocks() handles this automatically

# 4. Airplane mode (eliminates network interference)
adb shell cmd connectivity airplane-mode enable

# 5. Do Not Disturb (prevents notification rendering overhead)
adb shell cmd notification set_dnd on

# 6. Screen brightness fixed (prevents adaptive brightness CPU usage)
adb shell settings put system screen_brightness_mode 0
adb shell settings put system screen_brightness 128

# 7. Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# 8. Check thermal state (don't benchmark when hot)
adb shell dumpsys thermalservice | grep -i "current"
# Must show NONE or LIGHT — abort if MODERATE or higher

# Fallback: read thermal zones directly
adb shell "for z in /sys/class/thermal/thermal_zone*/; do echo \$(cat \${z}type): \$(cat \${z}temp); done"
# If any zone > 45000 (45C), wait before benchmarking

# 9. Kill background apps
adb shell am kill-all
```

**Clock locking hierarchy** (most stable first):
1. `lockClocks.sh` / `./gradlew :benchmark:lockClocks` — pins to low sustainable frequency, best stability
2. `userspace` governor with min freq pinning — manual equivalent of lockClocks
3. `set-fixed-performance-mode-enabled true` — non-root convenience, but device can still thermal-throttle
4. No locking — `cpuLocked` will be `false` in JSON output, results unreliable

Always add 30-60s cooldown pauses between benchmark suites regardless of locking method.

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

## Anti-Patterns

| Mistake | Why It Fails | Fix |
|---------|-------------|-----|
| Running benchmarks on emulator | Measures host CPU, not device silicon | Use physical device; suppress with `EMULATOR` arg only for CI smoke tests |
| `debuggable = true` in benchmark build | Disables ART optimizations, 10-50x slower | Use release or dedicated benchmark build type |
| No compilation reset between tests | Previous JIT data leaks between test methods | Use default CompilationMode behavior; do not use `Ignore` unless intentional |
| Too few iterations (< 5) | High variance, false regressions | Minimum 5, prefer 10+ iterations |
| No cooldown between suites | Thermal throttling skews later test results | Add 30-60s sleep between benchmark classes |
| Database/cache not cleared | Cached results hide real performance | Clear in `setUp()` or use `measureRepeated { setupBlock {} }` |
| Calling `reportFullyDrawn()` too early | TTID == TTFD, losing time-to-full-display data | Call only after async data is rendered |
| Profile generation with R8 enabled | Generated rules reference obfuscated names, won't match | Disable minification for profile generation variant |
| Using `createComposeRule` for perf tests | It is a functional test rule, not a benchmark rule | Use `BenchmarkRule` for micro, `MacrobenchmarkRule` for macro |
| Not checking `cpuLocked` in JSON output | Results unreliable if CPU frequency scaled during run | Verify `"cpuLocked": true` in output JSON context block |
