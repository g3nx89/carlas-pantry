# Performance Profiling Reference

CLI tools for profiling Android app performance: Perfetto traces, frame timing, method tracing, heap analysis, and physical device-specific measurements.

> **TL;DR**: Capture traces with `adb shell perfetto -t 20s sched freq gfx`, query with `trace_processor --query "SQL"`, measure jank via `dumpsys gfxinfo`, profile methods with `am profile start/stop`, dump heap with `am dumpheap`, detect slow frames via Choreographer slice analysis.

## Contents

| Line | Section | Focus |
|-----:|---------|-------|
| 21 | Perfetto Traces (Android 9+) | Config, capture, trace_processor SQL, automation |
| 559 | Frame Timing Analysis | gfxinfo, framestats, automated jank measurement |
| 604 | Method Tracing | `am profile`, dmtracedump |
| 626 | Heap Analysis | `am dumpheap`, hprof-conv |
| 641 | Process and Memory Monitoring | top, meminfo, vmstat |
| 656 | Physical Device Profiling | CPU governor, thermal, battery, GPU |
| 705 | Compose-Specific CLI Debugging | Layout bounds, overdraw, recomposition |
| 736 | Macrobenchmark and Baseline Profiles | Quick commands |
| 754 | Sensor and Hardware Capabilities | Sensor listing, connectivity |

## Perfetto Traces (Android 9+)

Perfetto is the primary system-wide tracing tool, default-enabled on Android 11+.

### Tool Setup

```bash
# trace_processor (SQL analysis engine)
curl -LO https://get.perfetto.dev/trace_processor && chmod +x trace_processor

# record_android_trace (capture helper -- handles adb pull automatically)
curl -LO https://raw.githubusercontent.com/google/perfetto/main/tools/record_android_trace
chmod +x record_android_trace

# Python API (for scripted analysis)
pip install perfetto
```

### Trace Capture

```bash
# Direct capture
adb shell perfetto \
  -o /data/misc/perfetto-traces/trace.perfetto-trace \
  -t 20s \
  sched freq idle am wm gfx view binder_driver hal dalvik camera input res memory
adb pull /data/misc/perfetto-traces/trace.perfetto-trace ./

# Helper script (recommended):
./record_android_trace -o trace.perfetto-trace -t 30s -b 64mb \
  sched freq idle am wm gfx view binder_driver hal dalvik

# Scheduling-only capture (lightweight)
adb shell perfetto -o /data/misc/perfetto-traces/trace.perfetto-trace \
  -t 5s sched/sched_switch sched/sched_wakeup
```

**Compose-relevant trace categories**: `gfx`, `view`, `am`, `wm`, `dalvik`, `input`, `res`.

Open traces at `ui.perfetto.dev` for web-based analysis.

### Perfetto Config via Text Protobuf

For fine-grained control, pass a text protobuf config specifying exact data sources:

```bash
cat config.pbtx | adb shell perfetto -c - --txt -o /data/misc/perfetto-traces/trace.perfetto-trace
```

This avoids pushing the config file to the device (`-c -` reads from stdin).

#### Full Config Example (UI Performance)

Save as `perf_config.pbtx`:

```protobuf
duration_ms: 15000
buffers { size_kb: 65536  fill_policy: RING_BUFFER }
buffers { size_kb: 8192   fill_policy: RING_BUFFER }

data_sources {
  config {
    name: "linux.ftrace"
    target_buffer: 0
    ftrace_config {
      buffer_size_kb: 16384
      ftrace_events: "sched/sched_switch"
      ftrace_events: "sched/sched_wakeup"
      ftrace_events: "sched/sched_waking"
      ftrace_events: "power/cpu_frequency"
      ftrace_events: "power/cpu_idle"
      ftrace_events: "power/suspend_resume"
      ftrace_events: "binder/binder_transaction"
      ftrace_events: "binder/binder_transaction_received"
      ftrace_events: "binder/binder_transaction_alloc_buf"
      atrace_categories: "gfx"
      atrace_categories: "view"
      atrace_categories: "input"
      atrace_categories: "wm"
      atrace_categories: "am"
      atrace_categories: "dalvik"
      atrace_categories: "res"
      atrace_categories: "memory"
      atrace_apps: "com.example.myapp"
    }
  }
}
data_sources {
  config {
    name: "linux.process_stats"
    target_buffer: 1
    process_stats_config { scan_all_processes_on_start: true }
  }
}
data_sources {
  config {
    name: "android.surfaceflinger.frametimeline"
  }
}
```

```bash
# Push and record (Android 12+)
adb push perf_config.pbtx /data/misc/perfetto-configs/
adb shell perfetto --txt -c /data/misc/perfetto-configs/perf_config.pbtx \
  -o /data/misc/perfetto-traces/trace.perfetto-trace

# Pre-Android 12: pipe config via stdin
cat perf_config.pbtx | adb shell perfetto --txt -c - \
  -o /data/misc/perfetto-traces/trace.perfetto-trace

# Convenience wrapper (auto-pulls and opens UI)
./record_android_trace -o trace.perfetto-trace -t 10s -b 64mb -a 'com.example.myapp' \
  sched freq idle gfx view input binder_driver dalvik
```

#### Key Config Parameters

| Parameter | Purpose | Typical Value |
|-----------|---------|---------------|
| `duration_ms` | Trace length | 10000-30000 |
| `buffers.size_kb` | Ring buffer | 32768-131072 |
| `ftrace_config.buffer_size_kb` | Kernel buffer | 8192-16384 |
| `write_into_file: true` | Stream to disk for long traces | For >30s traces |
| `file_write_period_ms` | Flush interval when streaming | 2500 |
| `atrace_apps` | Enable app-level tracing for package | Package name |

#### Ring Buffer vs Long Trace Trade-offs

Default `RING_BUFFER` overwrites oldest data when full -- suitable for <30s captures. For longer sessions, add `write_into_file: true` and `file_write_period_ms: 2500` to stream to disk. Buffer sizing: 32MB handles ~10s; for 30s+ prefer streaming over larger buffers. Detect dropped events:

```bash
./trace_processor trace.perfetto-trace \
  --query "SELECT name, severity, value FROM stats WHERE severity != 'info'"
# Look for: ftrace_cpu_overrun, chunks_discarded, patches_discarded
```

### Machine Analysis with trace_processor

The Perfetto output is binary protobuf. Use `trace_processor` to query with SQL.

#### Interactive Mode

```bash
./trace_processor trace.perfetto-trace
# Enters SQL shell. Type queries, get tabular output.
```

#### Batch Mode

```bash
# Single query from command line:
./trace_processor trace.perfetto-trace --query "SELECT dur FROM slice WHERE name = 'inflate'"

# Run SQL file against trace
./trace_processor --query-file analysis.sql trace.perfetto-trace

# Run built-in metric
./trace_processor --run-metrics android_startup trace.perfetto-trace
```

#### Built-in Perfetto Metrics

| Metric | What It Measures |
|--------|-----------------|
| `android_startup` | App startup timing (TTID, TTFD, bind application) |
| `android_jank` | Frame jank classification and counts |
| `android_cpu` | CPU usage per process/thread |
| `android_mem` | Memory usage tracking (RSS, PSS) |
| `android_batt` | Battery drain estimation by subsystem |
| `android_binder` | Binder transaction latency and throughput |

List all available metrics with `./trace_processor --list-metrics`.

#### Python Scripted Analysis

```python
from perfetto.trace_processor import TraceProcessor

tp = TraceProcessor(trace='trace.perfetto-trace')
df = tp.query('SELECT ts, dur, name FROM slice LIMIT 100').as_pandas_dataframe()
print(df.describe())
```

### SQL Query Cookbook

#### Startup Time

```sql
-- Measure startup time
SELECT dur/1e6 as ms FROM slice WHERE name = 'bindApplication';
```

#### Slow Frames (Choreographer)

```sql
-- Find slow frames
SELECT ts, dur/1e6 as ms FROM slice
WHERE name = 'Choreographer#doFrame' AND dur > 16600000;
```

#### Jank Detection (Android 12+, frametimeline datasource)

```sql
-- All janky frames for an app
SELECT
  ts, dur / 1e6 AS dur_ms,
  jank_type, on_time_finish, present_type,
  layer_name, process.name
FROM actual_frame_timeline_slice
LEFT JOIN process USING(upid)
WHERE jank_type != 'None'
  AND process.name = 'com.example.myapp'
ORDER BY dur DESC;
```

**Complete `jank_type` values:**

| jank_type | Attribution | Meaning |
|-----------|------------|---------|
| `AppDeadlineMissed` | App | App took too long to produce frame |
| `SurfaceFlingerCpuDeadlineMissed` | System | Compositor CPU work exceeded deadline |
| `SurfaceFlingerGpuDeadlineMissed` | System | Compositor GPU work exceeded deadline |
| `DisplayHAL` | System | Display HAL layer missed deadline |
| `BufferStuffing` | App | Frame queue backlog (app producing faster than display consumes) |
| `PredictionError` | System | Vsync timing prediction drift |

For CI scripts, filter to app-attributable jank only: `WHERE jank_type IN ('AppDeadlineMissed', 'BufferStuffing')`. System-attributable types (`SurfaceFlinger*`, `DisplayHAL`) are not actionable in app code.

#### Frame Duration Percentiles (P50/P90/P99)

```sql
SELECT
  process.name,
  COUNT(*) AS frame_count,
  AVG(dur) / 1e6 AS avg_ms,
  PERCENTILE(dur, 50) / 1e6 AS p50_ms,
  PERCENTILE(dur, 90) / 1e6 AS p90_ms,
  PERCENTILE(dur, 99) / 1e6 AS p99_ms,
  MAX(dur) / 1e6 AS max_ms
FROM actual_frame_timeline_slice
LEFT JOIN process USING(upid)
WHERE process.name = 'com.example.myapp'
GROUP BY process.name;
```

Interpretation: p90 > 16.6ms indicates regular jank on 60Hz. p99 > 33ms means severe hitches.

#### Long Main Thread Work

```sql
SELECT s.name, s.dur / 1e6 AS dur_ms, s.ts, t.name AS thread
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE p.name = 'com.example.myapp'
  AND t.is_main_thread
  AND s.dur > 16000000  -- >16ms
ORDER BY s.dur DESC
LIMIT 30;
```

Interpretation: any slice >16ms on the main thread risks dropping a frame. Common culprits: `inflate`, `measure/layout/draw`, `Choreographer#doFrame`, database operations.

#### Binder Transaction Latency

```sql
INCLUDE PERFETTO MODULE android.binder;

SELECT
  aidl_name, method_name,
  client_process, client_thread,
  client_dur / 1e6 AS client_ms,
  server_process, server_thread,
  server_dur / 1e6 AS server_ms,
  (server_ts - client_ts) / 1e6 AS dispatch_ms
FROM android_binder_txns
WHERE is_sync AND client_process = 'com.example.myapp'
ORDER BY client_dur DESC
LIMIT 20;
```

Interpretation: high `dispatch_ms` with low `server_ms` = scheduling/queuing delay. High `server_ms` = slow service-side work. Binder calls >5ms on main thread are red flags.

#### GC Pauses

```sql
SELECT s.name, s.dur / 1e6 AS dur_ms, s.ts,
  p.name AS process_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE s.name GLOB '*GC*' OR s.name GLOB '*collector*'
  OR s.name GLOB '*Concurrent*Copying*'
ORDER BY s.dur DESC
LIMIT 20;
```

Interpretation: ART GC slices appear as `concurrent copying GC` or similar. Pauses >5ms noted in logs; in traces look for any GC slice overlapping with `Choreographer#doFrame` to find GC-induced jank.

#### CPU Utilization Per Process

```sql
INCLUDE PERFETTO MODULE linux.cpu.utilization.process;

SELECT name AS process_name,
  SUM(megacycles) AS total_megacycles,
  time_to_ms(SUM(runtime)) AS runtime_ms,
  MIN(min_freq) AS min_freq_khz,
  MAX(max_freq) AS max_freq_khz
FROM cpu_cycles_per_process
JOIN process USING(upid)
WHERE name = 'com.example.myapp'
GROUP BY name;
```

#### Thread Blocking Analysis (Uninterruptible Sleep)

```sql
SELECT blocked_function, COUNT(*) AS count, SUM(dur) / 1e6 AS total_ms
FROM thread_state
JOIN thread USING(utid)
JOIN process USING(upid)
WHERE process.name = 'com.example.myapp'
  AND state = 'D'  -- uninterruptible sleep
GROUP BY blocked_function
ORDER BY SUM(dur) DESC
LIMIT 15;
```

Interpretation: top `blocked_function` values reveal I/O bottlenecks. Common: `binder_thread_read` (binder waits), `do_page_fault` (memory pressure), `SyS_fsync` (disk flush).

#### App Startup Latency

```sql
INCLUDE PERFETTO MODULE android.app_process_starts;
INCLUDE PERFETTO MODULE time.conversion;

SELECT process_name, intent, reason,
  time_to_ms(total_dur) AS startup_ms
FROM android_app_process_starts
WHERE process_name = 'com.example.myapp';
```

#### Monitor Contention During Startup

```sql
INCLUDE PERFETTO MODULE android.monitor_contention;
INCLUDE PERFETTO MODULE android.startup.startups;

SELECT process_name,
  SUM(dur) / 1e6 AS contention_ms,
  COUNT(*) AS count
FROM android_monitor_contention
WHERE is_blocked_thread_main
GROUP BY process_name
ORDER BY SUM(dur) DESC;
```

#### Slice Statistics (Generic Pattern for Any Named Event)

```sql
SELECT name, COUNT(*) AS count,
  AVG(dur) / 1e6 AS avg_ms,
  PERCENTILE(dur, 90) / 1e6 AS p90_ms,
  PERCENTILE(dur, 99) / 1e6 AS p99_ms,
  MAX(dur) / 1e6 AS max_ms
FROM slice
WHERE name REGEXP '.*MyCustomTrace.*'
GROUP BY name
ORDER BY count DESC;
```

This allows agents to mathematically verify performance improvements (e.g., "Layout inflation decreased by 15%").

### Automated Perfetto Analysis

#### Regression Detection Script

Use the Python API to extract metrics from traces and compare against baseline thresholds in CI:

```python
from perfetto.trace_processor import TraceProcessor
import json, sys

def analyze(trace_path, package):
    tp = TraceProcessor(trace=trace_path)
    frames = tp.query(f'''
        SELECT COUNT(*) AS total,
          SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) AS janky,
          PERCENTILE(dur, 90)/1e6 AS p90_ms,
          PERCENTILE(dur, 99)/1e6 AS p99_ms
        FROM actual_frame_timeline_slice
        LEFT JOIN process USING(upid)
        WHERE process.name = '{package}'
    ''').as_pandas_dataframe()
    startup = tp.query(f'''
        INCLUDE PERFETTO MODULE android.app_process_starts;
        INCLUDE PERFETTO MODULE time.conversion;
        SELECT time_to_ms(total_dur) AS ms
        FROM android_app_process_starts
        WHERE process_name = '{package}'
    ''').as_pandas_dataframe()
    return {
        'jank_rate': float(frames['janky'].iloc[0]) / max(float(frames['total'].iloc[0]), 1),
        'p90_frame_ms': float(frames['p90_ms'].iloc[0]),
        'p99_frame_ms': float(frames['p99_ms'].iloc[0]),
        'startup_ms': float(startup['ms'].iloc[0]) if len(startup) else None
    }

result = analyze(sys.argv[1], 'com.example.myapp')
print(json.dumps(result, indent=2))
# Compare against baseline thresholds in CI
```

#### Macrobenchmark Trace Extraction

Macrobenchmark automatically captures Perfetto traces per iteration. Pull and query them for deep analysis beyond the summary metrics.

**Trace file location:**
```
<project>/app/build/outputs/connected_android_test_additional_output/
  debugAndroidTest/connected/<device_id>/
  TrivialStartupBenchmark_startup[mode=COLD]_iter002.perfetto-trace
```

**Automated analysis of benchmark traces:**

```python
import glob
from perfetto.trace_processor import TraceProcessor

for trace_file in glob.glob('build/outputs/**/*.perfetto-trace', recursive=True):
    tp = TraceProcessor(trace=trace_file)
    df = tp.query('''
        SELECT process.name, AVG(dur)/1e6 AS avg_frame_ms,
               PERCENTILE(dur, 95)/1e6 AS p95_ms
        FROM actual_frame_timeline_slice
        LEFT JOIN process USING(upid)
        GROUP BY process.name
    ''').as_pandas_dataframe()
    print(f"{trace_file}: p95={df['p95_ms'].values}")
```

### Trace Sharing in CI

Use `./record_android_trace --open` to capture and launch Perfetto UI. Share traces via `ui.perfetto.dev` (drag-and-drop). Store as CI artifacts:

```yaml
# GitHub Actions example
- uses: actions/upload-artifact@v4
  with:
    name: perfetto-traces
    path: build/outputs/**/*.perfetto-trace
    retention-days: 30
```

### Custom Trace Instrumentation (Perfetto SDK)

#### Kotlin/Java (Appears as atrace Slices)

```kotlin
// Requires: atrace_apps includes your package in config, or -a '*'
import android.os.Trace
Trace.beginSection("MyOperation")
// ... work ...
Trace.endSection()

// Or with AndroidX (preferred)
import androidx.tracing.trace
trace("MyOperation") {
    // ... work ...
}
```

#### Coroutine Tracing

`Trace.beginSection`/`endSection` cannot span suspension points -- the section closes on suspend. Use `androidx.tracing:tracing-ktx` instead:

```kotlin
implementation("androidx.tracing:tracing-ktx:1.3.0-alpha02")

suspend fun loadData(): Data = trace("LoadData") {
    val raw = apiService.fetch()   // suspends, trace continues
    parseResponse(raw)
}
```

Coroutine traces appear as **async slices** in Perfetto spanning full suspension duration (wall-clock, not CPU time). Query with the standard `slice` table.

#### Compose Recomposition Tracing

```kotlin
// build.gradle.kts
implementation("androidx.compose.runtime:runtime-tracing:1.10.2")
```

No code changes needed -- once the dependency is added and tracing is enabled (API 30+), recomposition events appear as slices in Perfetto automatically. Capture with `gfx view am wm dalvik` categories and look for recomposition slice names in the trace to identify:

- Recomposition frequency and scope
- Frame rendering time per composition
- Layout and measure pass duration

#### Native (C/C++)

```c
#include <android/trace.h>  // API 23+
ATrace_beginSection("NativeWork");
// ... work ...
ATrace_endSection();
```

### Systrace to Perfetto Migration

| Systrace | Perfetto Equivalent |
|----------|-------------------|
| `systrace.py -t 5 gfx view sched` | `adb shell perfetto -t 5s -o trace sched gfx view` |
| `systrace.py -a com.app` | Add `atrace_apps: "com.app"` in config or `-a com.app` with record_android_trace |
| `systrace.py --from-file trace.html` | `./trace_processor trace.perfetto-trace` |
| HTML output | Binary protobuf (view at ui.perfetto.dev or via trace_processor SQL) |
| Limited duration | `write_into_file: true` enables arbitrarily long traces |
| No SQL analysis | Full SQL via trace_processor |

### ftrace Events Reference

| Category | Events | Use Case |
|----------|--------|----------|
| Scheduling | `sched/sched_switch`, `sched/sched_wakeup`, `sched/sched_waking` | Thread execution, preemption, wake chains |
| CPU Power | `power/cpu_frequency`, `power/cpu_idle` | Throttling, power state correlation |
| Suspend | `power/suspend_resume` | Device sleep/wake analysis |
| Binder | `binder/binder_transaction`, `binder/binder_transaction_received`, `binder/binder_transaction_alloc_buf` | IPC latency, transaction tracing |
| GPU | atrace `gfx` category | Render pipeline, GPU composition |
| Memory | atrace `memory`, `dalvik` categories | GC events, allocation tracking |
| Input | atrace `input` category | Touch-to-render latency |
| Window Manager | atrace `wm`, `am` categories | Activity lifecycle, transitions |

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

The `-h` flag produces an HTML call graph navigable in a browser -- useful for CI artifacts or sharing without Android Studio.

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
# Output: cpu-0-0-usr: 42000 (millidegrees Celsius = 42C)
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

### Recomposition Detection

Use the Rebugger library (`io.github.nicosm:rebugger`) in debug builds to log exact recomposition reasons. For production analysis, use Perfetto traces with `runtime-tracing` (see Custom Trace Instrumentation above).

### Animation Testing

The standard `animator_duration_scale 0` setting affects Compose animations. Disable during functional tests:

```bash
adb shell settings put global animator_duration_scale 0
```

### Performance Optimization Verification

Converting state params to lambda params (`() -> State`) eliminates unnecessary recompositions. Profile impact via `dumpsys gfxinfo` frame timing before and after the change.

## Macrobenchmark and Baseline Profiles

For comprehensive coverage of Macrobenchmark (module setup, CompilationMode, metrics), Microbenchmark, Baseline Profile generation/verification, and benchmark regression detection, see `benchmark-cli.md`. For APK/AAB size analysis with `apkanalyzer`/`bundletool`, see `apk-size-analysis.md`.

Quick commands for common tasks:

```bash
# Run macrobenchmark tests
./gradlew :macrobenchmark:connectedBenchmarkAndroidTest

# Generate Baseline Profile
./gradlew :app:generateReleaseBaselineProfile

# Verify Baseline Profile installation
adb shell dumpsys package com.example.app | grep -A5 "dexopt"
# Look for: [status=speed-profile]
```

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

