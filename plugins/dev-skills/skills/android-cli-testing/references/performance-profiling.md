# Performance Profiling Reference

CLI tools for profiling Android app performance: Perfetto traces, frame timing, method tracing, heap analysis, and physical device-specific measurements.

## Perfetto Traces (Android 9+)

Perfetto is the primary system-wide tracing tool, default-enabled on Android 11+.

```bash
# Direct capture
adb shell perfetto \
  -o /data/misc/perfetto-traces/trace.perfetto-trace \
  -t 20s \
  sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory
adb pull /data/misc/perfetto-traces/trace.perfetto-trace ./

# Helper script (recommended):
curl -O https://raw.githubusercontent.com/google/perfetto/main/tools/record_android_trace
chmod u+x record_android_trace
./record_android_trace -o trace.perfetto-trace -t 30s -b 64mb \
  sched freq idle am wm gfx view binder_driver hal dalvik
```

**Compose-relevant trace categories**: `gfx`, `view`, `am`, `wm`, `dalvik`, `input`, `res`.

Open traces at `ui.perfetto.dev` for web-based analysis.

### Perfetto Config via Text Protobuf

For fine-grained control, pass a text protobuf config specifying exact data sources:

```bash
cat config.pbtx | adb shell perfetto -c - --txt -o /data/misc/perfetto-traces/trace.perfetto-trace
```

This avoids pushing the config file to the device (`-c -` reads from stdin).

### Machine Analysis with trace_processor_shell

The Perfetto output is binary protobuf. Use `trace_processor_shell` to query with SQL:

```bash
# Download trace_processor (part of Perfetto SDK)
# Query layout inflation time:
trace_processor_shell trace.perfetto-trace --query "SELECT dur FROM slice WHERE name = 'inflate'"

# Measure startup time:
trace_processor_shell trace.perfetto-trace --query \
  "SELECT dur/1e6 as ms FROM slice WHERE name = 'bindApplication'"

# Find slow frames:
trace_processor_shell trace.perfetto-trace --query \
  "SELECT ts, dur/1e6 as ms FROM slice WHERE name = 'Choreographer#doFrame' AND dur > 16600000"
```

This allows agents to mathematically verify performance improvements (e.g., "Layout inflation decreased by 15%").

## Frame Timing Analysis (gfxinfo)

```bash
adb shell dumpsys gfxinfo <package> reset   # Reset counters first
# ... run test scenario ...
adb shell dumpsys gfxinfo <package>          # Collect data
adb shell dumpsys gfxinfo <package> framestats   # Nanosecond per-frame timing (API 23+)
```

### Interpreting Results

- **Total frames rendered**: Baseline count
- **Janky frames**: Frames exceeding budget (>10% of total indicates a problem)
- **Frame budget**: 16.67ms for 60fps displays, 8.33ms for 120fps displays
- **Percentiles**: 50th/90th/95th/99th render times reveal tail latency

### framestats CSV Column Reference (API 23+)

The `framestats` output is a CSV block where each row is a frame. Timestamps are nanoseconds:

| Column | Stage | Parsing Value |
|--------|-------|---------------|
| 0 | Flags | 0=Normal, 1=Janky (missed deadline) |
| 1 | IntendedVsync | When frame *should* have started |
| 2 | Vsync | When frame *actually* started |
| 5 | HandleInputStart | Input event processing began |
| 7 | PerformTraversalsStart | Layout/measure pass began |
| 13 | FrameCompleted | GPU finished work |

**Agent analysis logic**:
- **Frame duration**: `FrameCompleted - IntendedVsync`. If >16.6ms (60Hz), frame was dropped
- **Input latency**: High delta `HandleInputStart - IntendedVsync` = main thread blocked, cannot process touch
- **Slow UI thread**: High duration in `PerformTraversals` = heavy logic in `onMeasure`/`onLayout`

### Automated Jank Measurement

```bash
# Reset, run test, collect
adb shell dumpsys gfxinfo com.example.app reset
# ... automated test scenario ...
RESULT=$(adb shell dumpsys gfxinfo com.example.app)
JANKY=$(echo "$RESULT" | grep "Janky frames" | awk '{print $NF}')
echo "Janky frames: $JANKY"
```

## Method Tracing

```bash
# Start profiling
adb shell am profile start com.example.app /sdcard/profile.trace
# ... interact with app or run test ...
adb shell am profile stop com.example.app
adb pull /sdcard/profile.trace
```

Analyze `.trace` files with Android Studio Profiler or `dmtracedump` CLI tool:

```bash
# Generate HTML call graph from trace
dmtracedump -h profile.trace > profile.html

# Text output (default)
dmtracedump profile.trace
```

The `-h` flag produces an HTML call graph navigable in a browser — useful for CI artifacts or sharing without Android Studio.

## Heap Analysis

> **Note:** For extended heap dump workflows (scripted leak investigation, baseline comparison, LeakCanary CLI), see `debug-ui-memory.md`.

```bash
# Dump heap for a running process
adb shell am dumpheap <PID> /data/local/tmp/heap.hprof
adb pull /data/local/tmp/heap.hprof

# Find PID
adb shell pidof -s com.example.app
```

Convert HPROF format if needed: `hprof-conv heap.hprof converted.hprof` (required for MAT/Eclipse analysis).

## Process and Memory Monitoring

```bash
# Process monitoring
adb shell top -n 1 -m 10               # Top 10 processes, one iteration
adb shell ps -A | grep com.example     # Find process
adb shell cat /proc/meminfo            # System memory
adb shell vmstat 1                     # VM stats every 1s
adb shell dumpsys cpuinfo              # CPU load per process

# Memory breakdown for specific app
adb shell dumpsys meminfo com.example.app
adb shell dumpsys meminfo -a com.example.app   # Detailed
```

## Physical Device Profiling

Physical device profiling captures real hardware behavior invisible on emulators: CPU governor policies, thermal throttling, actual GPU rendering, and battery consumption.

### CPU Frequency and Governor

```bash
# CPU frequency per core (kHz):
adb shell "for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do echo \$i: \$(cat \$i); done"

# CPU governor:
adb shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### Thermal Throttling Detection

```bash
adb shell "for i in /sys/class/thermal/thermal_zone*/; do echo \$(cat \${i}type): \$(cat \${i}temp); done"
# Output: cpu-0-0-usr: 42000 (millidegrees Celsius = 42°C)
```

Thermal throttling causes frame drops invisible in emulators. Monitor during sustained test sessions.

### Battery Profiling

```bash
adb shell dumpsys batterystats --reset           # Reset before test
adb shell dumpsys batterystats --enable full-wake-history
# ... test period ...
adb bugreport bugreport.zip                       # Generate bugreport
# Analyze with Battery Historian:
# docker run -p 9999:9999 gcr.io/android-battery-historian/stable:3.1 --port 9999
```

### GPU and Surface Profiling

```bash
adb shell dumpsys gfxinfo <package> framestats   # Per-frame timing
adb shell dumpsys SurfaceFlinger                  # Composition info, layers
adb shell dumpsys SurfaceFlinger --list            # List active surface layers (quick check)
```

### Storage I/O Benchmarking

```bash
adb shell dd if=/dev/zero of=/data/local/tmp/testfile bs=1M count=100  # Write test
adb shell dd if=/data/local/tmp/testfile of=/dev/null bs=1M            # Read test
```

## Compose-Specific CLI Debugging

### Layout Bounds

```bash
adb shell setprop debug.layout true    # Show layout bounds (affects Compose too)
```

### GPU Rendering Visualization

```bash
adb shell setprop debug.hwui.profile visual_bars  # GPU render bars overlay
adb shell setprop debug.hwui.overdraw show         # GPU overdraw visualization
```

### Composition Tracing

Capture Perfetto traces with `gfx view am wm dalvik` categories to profile the Compose rendering pipeline. Focus on:
- Recomposition frequency and scope
- Frame rendering time per composition
- Layout and measure pass duration

### Recomposition Detection

Use the Rebugger library (`io.github.nicosm:rebugger`) in debug builds to log exact recomposition reasons. For production analysis, use Perfetto traces.

### Animation Testing

The standard `animator_duration_scale 0` setting affects Compose animations. Disable during functional tests:

```bash
adb shell settings put global animator_duration_scale 0
```

### Performance Optimization Verification

Converting state params to lambda params (`() -> State`) eliminates unnecessary recompositions. Profile impact via `dumpsys gfxinfo` frame timing before and after the change.

## Macrobenchmark and Baseline Profiles

### Jetpack Macrobenchmark

Macrobenchmark measures high-level app performance metrics (cold startup, scrolling jank, animations) using real instrumentation:

```bash
# Run macrobenchmark tests (requires separate :macrobenchmark module)
./gradlew :macrobenchmark:connectedBenchmarkAndroidTest

# Run on a specific device
ANDROID_SERIAL=emulator-5554 ./gradlew :macrobenchmark:connectedBenchmarkAndroidTest
```

Macrobenchmark tests are instrumentation tests with a special test runner. They output JSON/CSV metrics (startup time, frame timing) to `build/outputs/`. Integrate into CI to catch regressions (e.g., fail build if startup exceeds threshold).

### Baseline Profiles

Baseline Profiles pre-compile hot code paths to optimize app startup and scrolling:

```bash
# Generate Baseline Profile (requires :macrobenchmark module with profile generation tests)
./gradlew :app:generateReleaseBaselineProfile

# The generated profile is embedded in the APK/AAB automatically
# Output: app/src/main/generated/baselineProfiles/baseline-prof.txt
```

CI workflow: run `generateReleaseBaselineProfile` on every release build to ensure the profile stays up-to-date. Community talks (Android Dev Summit) report 20-40% startup improvements from Baseline Profiles.

### APK Size Monitoring

```bash
# Analyze APK size and method count
apkanalyzer apk summary app-release.apk
apkanalyzer dex references app-release.apk

# Track size in CI: compare against previous build
apkanalyzer apk file-size app-release.apk
```

Combine with Dexcount Gradle plugin to fail builds when method count or APK size exceeds thresholds.

## Sensor and Hardware Capabilities

### Sensor Listing

```bash
adb shell dumpsys sensorservice | head -50   # List available sensors and status
```

Real device sensors cannot be stimulated from CLI -- physical device must be moved. For programmatic sensor simulation, use the emulator console (`sensor set`) or Genymotion Shell.

### Connectivity Status

```bash
adb shell dumpsys bluetooth_manager   # Full Bluetooth status and profiles
adb shell dumpsys nfc                 # NFC state and controller info
adb shell dumpsys connectivity        # Network connections
```

### GPS Control

```bash
adb shell settings put secure location_providers_allowed +gps   # Enable GPS
adb shell settings put secure location_providers_allowed -gps   # Disable GPS
```

## Benchmarking and Baseline Profiles

For comprehensive benchmark workflows (Microbenchmark module setup, Macrobenchmark deep dive with CompilationMode/StartupTimingMetric/FrameTimingMetric, startup measurement scripts, benchmark regression detection with JSON parsing, and APK size tracking), see `benchmark-cli.md`.

### Quick Baseline Profile Verification

After generating or installing a Baseline Profile, verify it is active:

```bash
# Check profile-guided compilation status
adb shell dumpsys package com.example.app | grep -A5 "dexopt"
# Look for: [status=speed-profile]

# Force recompile with profile
adb shell cmd package compile -m speed-profile -f com.example.app

# Verify profile rules are loaded
adb shell cmd package dump-profiles com.example.app
```

See `benchmark-cli.md` for full Baseline Profile generation, A/B comparison, and CI integration.
