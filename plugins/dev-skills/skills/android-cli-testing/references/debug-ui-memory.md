# UI Inspection and Memory Leak Detection Reference

CLI-only techniques for view hierarchy inspection, accessibility verification, Compose semantics debugging, memory leak detection, and heap dump analysis.

> For data/storage debugging (StrictMode, databases, SharedPrefs), see `debug-data-storage.md`. For crash analysis and monkey testing, see `debug-crashes-monkey.md`. For system simulation, see `debug-system-simulation.md`.

> **TL;DR**: Dump view hierarchy with `uiautomator dump`, detect Activity leaks via `dumpsys meminfo` object counts, analyze heap dumps with SharkCli (`shark-cli -h dump.hprof analyze`), monitor PSS trends for leak confirmation, automate CI leak detection with before/after heap comparison.

## Layout/UI Debugging Without GUI

### View Hierarchy via UIAutomator

```bash
adb shell uiautomator dump /sdcard/uidump.xml
adb pull /sdcard/uidump.xml .
```

XML contains class names, resource IDs, text, content descriptions, and bounds.

### Window and Activity State

```bash
# Current focused window and visible surfaces
adb shell dumpsys window | head -n 100

# Top activity with intent, task, process info
adb shell dumpsys activity top

# All activities, tasks, processes
adb shell dumpsys activity
```

Essential for verifying which Activity is foreground and detecting overlays blocking UI.

### Accessibility Inspection via CLI

```bash
# Dump the accessibility node tree (richer than uiautomator for semantics)
adb shell dumpsys accessibility

# Check which accessibility services are enabled
adb shell settings get secure enabled_accessibility_services

# Enable an accessibility service (e.g., TalkBack)
adb shell settings put secure enabled_accessibility_services \
  com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
```

Use `dumpsys accessibility` to verify that Compose semantics, content descriptions, and roles are correctly exposed to assistive technologies. Particularly useful for debugging why TalkBack announces elements incorrectly.

### Compose Semantics

Compose semantics are exposed to accessibility. Cross-tool strategy:
- Use `uiautomator dump --compressed` to see accessible nodes
- Use `dumpsys accessibility` for a more detailed accessibility node tree
- `testTag` is surfaced via semantics extras and optionally as resource ID when `testTagsAsResourceId` is enabled
- Use Compose tests for internal semantics verification
- Use UIAutomator dumps to verify accessibility labels/content descriptions are set correctly

## Memory Leak Detection

### Shark CLI: Standalone Heap Analysis

Shark CLI is LeakCanary's heap analysis engine as a standalone command-line tool. It works with any debuggable app -- LeakCanary dependency not required in the target app.

**Install:** Download `shark-cli.sh` from the LeakCanary repo or build from source.

```bash
# Dump heap from connected device and analyze in one step
shark-cli -d emulator-5554 -p com.example.app dump-process

# Analyze an existing hprof file (no hprof-conv needed for Shark)
shark-cli -h /path/to/dump.hprof analyze

# Analyze with ProGuard/R8 mapping for obfuscated release builds
shark-cli -h dump.hprof -m mapping.txt analyze

# Interactive exploration of heap contents
shark-cli -h dump.hprof interactive

# Strip PII before sharing (zeroes all primitive arrays)
shark-cli -h dump.hprof strip-hprof
# Produces dump-stripped.hprof
```

**Interpreting Shark output:** Shark outputs leak traces with GC root chains. Each trace shows the reference path from a GC root to the retained object. Focus on:
1. The "Leaking: YES" annotations identify confirmed leaking objects
2. The narrowing point where "Leaking: UNKNOWN" transitions to "Leaking: YES" -- that transition is your leak cause
3. The reference chain between these two points reveals what is holding the leak

**Programmatic analysis for CI:** Shark's Kotlin API (`shark` and `shark-android` libraries) allows writing custom heap analysis scripts that run headlessly in CI pipelines without MAT or any GUI dependency.

### PSS / RSS / USS Deep Dive

Understanding the memory metrics reported by `dumpsys meminfo`:

| Metric | Full Name | What It Measures | When to Use |
|--------|-----------|-----------------|-------------|
| PSS | Proportional Set Size | Private pages + proportional share of shared pages | Cross-process comparison (avoids double-counting shared libs) |
| RSS | Resident Set Size | All physical pages mapped to process (private + shared) | Overestimates per-process cost; useful for total system pressure |
| USS | Unique Set Size | Only private pages (not shared with any other process) | Truest measure of memory freed on process death |

```bash
# Full memory breakdown for a package
adb shell dumpsys meminfo com.example.app

# All processes sorted by PSS (find top consumers)
adb shell dumpsys meminfo --sort pss

# Native unreachable memory with backtraces (useful for native leaks)
adb shell dumpsys meminfo --unreachable $(adb shell pidof com.example.app)
```

**Key categories in dumpsys meminfo output:**

| Category | Meaning | Leak Signal |
|----------|---------|-------------|
| Java Heap (Private Dirty) | Objects on Dalvik/ART heap | Grows after GC = Java leak |
| Native Heap (Private Dirty) | malloc'd memory (Bitmap pixels, native libs) | Grows steadily = native leak |
| Graphics | GPU/EGL/GL memory (textures, framebuffers) | Grows = texture or bitmap leak |
| Views / ViewRootImpl | Live view hierarchy count | Count > expected windows = dialog/activity leak |
| Activities | Live Activity instances in process | Count > 1 of same type after navigation = leak |
| AppContexts | Application context references | Should stay stable |

**Interpretation:** PSS climbing across repeated GC cycles confirms a leak. Force GC with `adb shell am force-gc com.example.app` (API 30+) or trigger from debug menu. USS is the truest measure of memory that would be freed on process death -- use it when evaluating per-process impact.

### dumpsys meminfo Trends Monitoring

Track memory growth over time to distinguish leaks from normal allocation patterns:

```bash
#!/bin/bash
# Monitor PSS trend over time -- rising PSS across GC cycles confirms a leak
PKG="com.example.app"
echo "Timestamp,TOTAL_PSS_KB,Activities,Views,ViewRootImpl"
while true; do
  TS=$(date +%H:%M:%S)
  INFO=$(adb shell dumpsys meminfo "$PKG")
  PSS=$(echo "$INFO" | grep "TOTAL PSS" | awk '{print $3}')
  ACTS=$(echo "$INFO" | grep "Activities:" | awk '{print $2}')
  VIEWS=$(echo "$INFO" | grep "Views:" | awk '{print $2}')
  VRI=$(echo "$INFO" | grep "ViewRootImpl:" | awk '{print $2}')
  echo "$TS,$PSS,$ACTS,$VIEWS,$VRI"
  sleep 5
done
```

Pipe output to a CSV file (`> mem_trend.csv`) and review for monotonic growth. A steady upward trend in PSS with stable or increasing Activity/View counts confirms a leak.

### Activity Count Leak Detection (CLI-only)

Detect Activity/context leaks without MAT by monitoring the Objects section in `dumpsys meminfo`:

```bash
# 1. Navigate to a screen, record baseline Activity count
adb shell dumpsys meminfo com.example.app | grep -A5 "Objects"
# Look for "Activities:" count

# 2. Navigate away and back (or rotate)
adb shell input keyevent 4          # BACK
adb shell am start -n com.example.app/.MainActivity

# 3. Wait for GC, then re-check
# Repeat navigate-away-and-back 3-5 times to give the runtime GC opportunities.
# Each cycle should trigger natural garbage collection of unreferenced objects.
sleep 3
adb shell dumpsys meminfo com.example.app | grep -A5 "Objects"

# If Activity count increases monotonically across multiple cycles despite
# returning to the same screen, a context leak is confirmed.
# Also check "Views:" count for view hierarchy leaks.
```

### Activity Leak Detection via ViewRootImpl Count

Each ViewRootImpl represents a window (Activity, Dialog, PopupWindow). Monitoring the count is the fastest way to detect leaked windows:

```bash
# Check Activity and ViewRootImpl counts together
adb shell dumpsys meminfo com.example.app | grep -E "Activities|ViewRootImpl"
# Expected: Activities = number of visible activities
# ViewRootImpl = number of windows (activities + dialogs + popups)

# List activity stack with states
adb shell dumpsys activity activities | grep -A5 "com.example.app"

# Check for destroyed-but-retained activities
adb shell dumpsys activity com.example.app | grep -i "destroy"
```

**Manual leak test protocol:**
1. Note Activity count and ViewRootImpl count from `dumpsys meminfo`
2. Navigate forward to new Activity, then press Back
3. Force GC: `adb shell am force-gc com.example.app` (API 30+), or `adb shell kill -10 $(adb shell pidof com.example.app)` (SIGUSR1 triggers GC on debug builds)
4. Re-check counts -- if Activity count did not decrease, the previous Activity leaked
5. If ViewRootImpl stays elevated after closing a dialog or Activity, a window/dialog is leaked

### Memory Pressure Simulation

Force the app to handle low-memory callbacks without killing the process:

```bash
# Simulate low memory pressure (triggers onTrimMemory callback)
adb shell am send-trim-memory <package> RUNNING_LOW

# Available levels: RUNNING_MODERATE, RUNNING_LOW, RUNNING_CRITICAL,
# UI_HIDDEN, BACKGROUND, MODERATE, COMPLETE
adb shell am send-trim-memory com.example.app COMPLETE
```

Use to verify that the app releases caches, downsizes bitmaps, and handles lifecycle correctly under memory pressure. More targeted than killing the process -- tests the app's voluntary cleanup path.

### Force GC Methods by API Level

| Method | API Level | Command |
|--------|-----------|---------|
| `am force-gc` | 30+ | `adb shell am force-gc <package>` |
| SIGUSR1 | All | `adb shell kill -10 $(adb shell pidof <package>)` |
| Runtime.gc() via JDWP | All | Attach debugger, invoke `Runtime.gc()` (requires debuggable app) |

SIGUSR1 triggers a GC on the ART runtime for debug builds. Use `am force-gc` on API 30+ for a cleaner approach. Always wait 2-3 seconds after forcing GC before capturing memory snapshots.

### Heap Dumps via `am dumpheap`

```bash
PACKAGE=com.example.app
OUT=/data/local/tmp/${PACKAGE}-heap.hprof

# Trigger heap dump
adb shell am dumpheap $PACKAGE $OUT

# Wait, then pull
sleep 3
adb pull $OUT .

# Convert from Android hprof to standard Java hprof
hprof-conv ${PACKAGE}-heap.hprof ${PACKAGE}-heap-converted.hprof

# Analyze in MAT (Eclipse Memory Analyzer) or similar
```

Use `/data/local/tmp/` instead of `/sdcard/` if you hit permission errors.

**MAT headless batch mode** (no GUI required):

```bash
# Generate leak suspects report
./mat/ParseHeapDump.sh dump-converted.hprof org.eclipse.mat.api:suspects

# Run OQL query headless (e.g., find all Activity instances)
./mat/ParseHeapDump.sh dump-converted.hprof \
  "-command=oql \"SELECT * FROM instanceof android.app.Activity\"" \
  org.eclipse.mat.api:query
```

**MAT OQL queries for common leaks:**

```sql
-- All retained Activity instances (should be 0-1 after navigation)
SELECT * FROM instanceof android.app.Activity

-- Large byte arrays (likely bitmap backing buffers)
SELECT * FROM byte[] s WHERE s.@length > 1048576

-- All Bitmap objects with retained size
SELECT toString(b), b.@retainedHeapSize FROM android.graphics.Bitmap b
```

For large dumps, pass `-vmargs -Xmx4g` to MAT. Use `discard_ratio` to sample huge heaps.

**jhat deprecation:** `jhat` was removed in JDK 9+. Use MAT or SharkCli instead. If using JDK 8: `jhat -J-Xmx4g heap.hprof` opens a web server on port 7000 for OQL queries.

### Scripted Leak Investigation

```bash
dump_heap() {
  local label="$1"
  local remote="/data/local/tmp/${PACKAGE}-${label}.hprof"
  local local_conv="${label}-converted.hprof"

  adb shell am dumpheap "$PACKAGE" "$remote"
  sleep 3
  adb pull "$remote" "${label}.hprof"
  adb shell rm "$remote"
  hprof-conv "${label}.hprof" "$local_conv"
  rm "${label}.hprof"
}

# Take baseline, exercise suspected flow, take second dump, compare
dump_heap "baseline"
# ... exercise app ...
dump_heap "after_flow"
```

### LeakCanary from CLI

LeakCanary outputs leak traces to logcat:

```bash
adb logcat | grep -i leakcanary
```

Combine: trigger scenario via CLI or test, then dump heap around the time LeakCanary reports a leak for deeper MAT analysis.

### LeakCanary Broadcast Trigger

Force a heap dump on demand (requires LeakCanary 2.x, debuggable app):

```bash
adb shell am broadcast -a com.squareup.leakcanary.DUMP_HEAP
adb shell ls /data/data/<package>/files/leakcanary/
adb pull /data/data/<package>/files/leakcanary/<timestamp>.hprof .
```

Useful in CI to force analysis at a specific test checkpoint rather than relying on automatic threshold triggers.

### LeakCanary in Instrumented Tests

Automatically fail tests on memory leaks:

```kotlin
// build.gradle.kts
dependencies {
  androidTestImplementation("com.squareup.leakcanary:leakcanary-android-instrumentation:2.14")
}

// In AndroidManifest.xml (androidTest sourceset) or test runner config:
android {
  defaultConfig {
    testInstrumentationRunner = "com.squareup.leakcanary.InstrumentationTestRunner"
    // Or use FailTestOnLeakRunnerListener with custom runner
  }
}
```

```bash
./gradlew connectedDebugAndroidTest
# Tests that leak Activities/Fragments/Views automatically FAIL with leak trace in output
```

This catches leaks during regular test runs rather than requiring manual heap dump inspection. Pairs well with Orchestrator (isolated process per test prevents cross-test leak contamination).

**Per-test leak detection with rules:**

```kotlin
// Detect leaks after each passing test using JUnit rule
class FeatureTest {
  @get:Rule
  val leakRule = DetectLeaksAfterTestSuccess()

  @Test
  fun navigateAndBack() {
    // ... UI test code ...
    // Leak detection triggers automatically after test passes
  }
}

// Manual assertion at specific checkpoint
@Test
fun criticalFlow() {
  launchActivity()
  pressBack()
  LeakAssertions.assertNoLeaks() // Dumps heap, fails if leaks found
}
```

### Custom ObjectInspector Rules

ObjectInspectors teach LeakCanary about app-specific types (DI scopes, custom lifecycle objects), reducing false positives in leak reports:

```kotlin
LeakCanary.config = LeakCanary.config.copy(
  objectInspectors = LeakCanary.config.objectInspectors +
    ObjectInspector { reporter ->
      reporter.whenInstanceOf("com.example.AppSingleton") { instance ->
        reportNotLeaking("App singleton, held for process lifetime")
      }
    }
)
```

Mark singletons, DI-scoped objects, or process-lifetime holders as "not leaking" to focus leak reports on real issues.

## Bitmap Memory Analysis

On API 26+, bitmap pixel data lives in native heap, not Java heap. A growing "Graphics" or "Native Heap" category in `dumpsys meminfo` with stable Java heap points to bitmap/texture leaks.

```bash
# Check native heap and graphics memory (where bitmap pixels live on API 26+)
adb shell dumpsys meminfo com.example.app | grep -E "Native|Graphics"
```

**Extract bitmaps from heap dumps as PNGs** (useful for identifying which images are leaking):

```bash
# github.com/dtrounine/hprof_bitmap_dump
java -jar hprof_bitmap_dump.jar dump-converted.hprof output_dir/
```

**MAT OQL for bitmap investigation:**

```sql
-- Find large bitmaps (width * height * 4 bytes for ARGB_8888)
SELECT b, b.mWidth, b.mHeight, b.@retainedHeapSize
FROM android.graphics.Bitmap b
WHERE b.mWidth * b.mHeight > 500000

-- Find all byte arrays > 1MB (likely bitmap backing buffers)
SELECT s.@length, s.@retainedHeapSize FROM byte[] s WHERE s.@length > 1048576
```

**Glide cache monitoring:**

```bash
# Glide logs cache hits/misses at verbose level
adb shell setprop log.tag.Engine VERBOSE
adb logcat -s Engine
# Watch for "Loaded resource from..." entries
# SIZE_ORIGINAL with large source images = memory bomb
```

**Coil/Glide cache sizing:** Both default to ~25% of available heap for memory cache. Override with `MemoryCache.Builder` if too generous for your app's memory budget. When investigating, check if the image loader's cache is holding onto decoded bitmaps that are no longer displayed -- this often manifests as high native heap with many large byte arrays in the heap dump.

## procstats and memtrack: Long-Running Leak Detection

For leaks that manifest over hours (slow leaks, background service leaks), `procstats` provides historical memory data without continuous monitoring:

```bash
# Memory stats over last 3 hours
adb shell dumpsys procstats --hours 3

# Stats for specific package over 24 hours
adb shell dumpsys procstats --hours 24 com.example.app

# Compact CSV-like format for scripting/graphing
adb shell dumpsys procstats --csv

# GPU/graphics memory tracking (per-process GPU allocation)
adb shell dumpsys memtrack
```

**procstats output interpretation:**
- `maxPss` / `maxUss` / `maxRss` -- peak memory footprints over the time window
- `minPss` vs `maxPss` -- large delta indicates memory growth (possible leak)
- `avgPss` -- average memory over the window; upward trend across successive windows is definitive
- `runtime` -- time spent in each process state (foreground, background, cached)

**Leak signal:** If `maxPss` grows across successive `--hours 1` snapshots while the app is idle in background, memory is leaking. Compare `avgPss` across hours -- a steady upward trend is definitive. Use `memtrack` output to determine whether the growth is in GPU/graphics memory (texture leak) versus CPU-side allocations.

## Perfetto: Advanced Memory Tracing

For deep native memory profiling and system-wide memory attribution:

```bash
# Native heap profiling (malloc attribution with call stacks)
# Requires perfetto tools from Android SDK or standalone download
perfetto_tools/heap_profile -n com.example.app -d 30000

# Java heap dump via Perfetto
perfetto_tools/java_heap_dump -n com.example.app

# RSS tracking over time via ftrace
adb shell perfetto -c - --txt -o /data/misc/perfetto-traces/mem.pftrace <<EOF
buffers: { size_kb: 8960 fill_policy: DISCARD }
data_sources: {
  config {
    name: "linux.process_stats"
    process_stats_config { scan_all_processes_on_start: true }
  }
}
data_sources: {
  config {
    name: "linux.ftrace"
    ftrace_config {
      ftrace_events: "kmem/rss_stat"
    }
  }
}
duration_ms: 60000
EOF

# Pull and view in ui.perfetto.dev
adb pull /data/misc/perfetto-traces/mem.pftrace .
```

**What to look for in Perfetto UI:** The "Unreleased malloc size" flamegraph shows cumulative allocations not yet freed, attributed to call stacks. Large nodes that grow over time are leak sites. This is especially useful for native leaks (JNI, NDK, bitmap pixel buffers) that do not appear in Java heap dumps.

## Compose-Specific Memory Patterns

No dedicated CLI tooling exists for Compose memory debugging. Detection uses standard heap analysis, but knowing what to look for in Compose's internal types is critical.

**Common Compose leak patterns:**

| Pattern | Cause | Detection in Heap Dump |
|---------|-------|----------------------|
| Captured Activity context in `remember {}` | Context outlives recomposition scope | Activity instances retained by `RememberObserver` chain |
| Unregistered callbacks in `LaunchedEffect` | Coroutine scope captures composable state | Growing `StandaloneCoroutine` count in heap |
| `DisposableEffect` without cleanup | Listeners/subscriptions never removed | Listener objects referencing destroyed composition |
| `mutableStateOf` in ViewModel with View refs | State holds View references across config changes | ViewModel retaining Activity/Fragment |
| `CompositionLocal` holding large objects | Local value retained across entire composition tree | Large retained size on `CompositionLocalMap` entries |
| Remembered state holding stale references | `remember { mutableStateOf(heavyObject) }` without key invalidation | Stale objects retained by `SnapshotMutableState` after navigation |

**CLI detection approach:**

```bash
# Dump heap, then query for composition-related leaks
shark-cli -h dump.hprof analyze
# Look for "Leaking: YES" traces involving:
#   - CompositionImpl
#   - RememberObserver
#   - DisposableEffectImpl
#   - RecomposeScopeImpl
#   - StandaloneCoroutine (LaunchedEffect scope leaks)
```

**MAT OQL for Compose leaks:**

```sql
-- All RememberObserver instances (composition-retained objects)
SELECT * FROM instanceof androidx.compose.runtime.RememberObserver

-- Find leaked coroutine scopes from LaunchedEffect
SELECT * FROM instanceof kotlinx.coroutines.StandaloneCoroutine

-- Find RecomposeScopeImpl instances referencing destroyed compositions
SELECT * FROM instanceof androidx.compose.runtime.RecomposeScopeImpl
```

## Automated Leak Detection in CI

### Heap Dump Delta Analysis Pipeline

Capture heap before and after a test suite, then compare to detect memory growth:

```bash
#!/bin/bash
# CI script: capture baseline, run tests, capture post, compare
PKG="com.example.app"
PID=$(adb shell pidof $PKG)

# Baseline heap dump
adb shell am dumpheap $PID /data/local/tmp/baseline.hprof
sleep 3
adb pull /data/local/tmp/baseline.hprof
hprof-conv baseline.hprof baseline-conv.hprof

# Run test suite
adb shell am instrument -w \
  com.example.app.test/androidx.test.runner.AndroidJUnitRunner

# Post-test heap dump (re-fetch PID in case process restarted)
PID=$(adb shell pidof $PKG)
adb shell am dumpheap $PID /data/local/tmp/posttest.hprof
sleep 3
adb pull /data/local/tmp/posttest.hprof
hprof-conv posttest.hprof posttest-conv.hprof

# Run MAT leak suspects on both dumps
./mat/ParseHeapDump.sh baseline-conv.hprof org.eclipse.mat.api:suspects
./mat/ParseHeapDump.sh posttest-conv.hprof org.eclipse.mat.api:suspects

# Or use Shark for comparison
shark-cli -h baseline-conv.hprof analyze > baseline-leaks.txt
shark-cli -h posttest-conv.hprof analyze > posttest-leaks.txt
diff baseline-leaks.txt posttest-leaks.txt
```

### Threshold Alerting Script

Fail CI builds when memory growth exceeds a configurable threshold:

```bash
#!/bin/bash
# Memory growth threshold check for CI
PKG="com.example.app"
THRESHOLD_KB=20000  # 20MB threshold

# Capture baseline PSS
BASELINE_PSS=$(adb shell dumpsys meminfo "$PKG" | grep "TOTAL PSS" | awk '{print $3}')

# Run test scenario
adb shell am instrument -w \
  com.example.app.test/androidx.test.runner.AndroidJUnitRunner

# Capture post-test PSS
POST_PSS=$(adb shell dumpsys meminfo "$PKG" | grep "TOTAL PSS" | awk '{print $3}')

DELTA=$((POST_PSS - BASELINE_PSS))
echo "Memory delta: ${DELTA}KB (baseline: ${BASELINE_PSS}KB, post: ${POST_PSS}KB)"

if [ $DELTA -gt $THRESHOLD_KB ]; then
  echo "FAIL: Memory grew by ${DELTA}KB exceeding threshold of ${THRESHOLD_KB}KB"
  # Capture heap dump for investigation
  PID=$(adb shell pidof "$PKG")
  adb shell am dumpheap $PID /data/local/tmp/leak-investigation.hprof
  sleep 3
  adb pull /data/local/tmp/leak-investigation.hprof
  hprof-conv leak-investigation.hprof leak-investigation-conv.hprof
  shark-cli -h leak-investigation-conv.hprof analyze
  exit 1
fi
echo "PASS: Memory growth within threshold"
```

### Dropbox Production Approach

Dropbox uploads LeakCanary traces to Bugsnag (crash reporting), integrates with Jira for tracking, and runs leak detection in CI via instrumented tests. They use `@SkipLeakDetection` annotation to suppress known test-only leaks with documented justification. Leaks surface as standard build failures, making them visible in the same workflow as test failures and crashes.

## Quick Reference: Command Cheat Sheet

| Goal | Command |
|------|---------|
| Live memory snapshot | `adb shell dumpsys meminfo <pkg>` |
| All processes by PSS | `adb shell dumpsys meminfo --sort pss` |
| Activity/View count | `adb shell dumpsys meminfo <pkg> \| grep -E "Activities\|ViewRoot"` |
| Heap dump | `adb shell am dumpheap <pid> /data/local/tmp/dump.hprof` |
| Pull dump | `adb pull /data/local/tmp/dump.hprof .` |
| Convert hprof | `hprof-conv dump.hprof dump-conv.hprof` |
| Shark dump + analyze | `shark-cli -d <serial> -p <pkg> dump-process` |
| Shark analyze file | `shark-cli -h dump-conv.hprof analyze` |
| Shark with mapping | `shark-cli -h dump.hprof -m mapping.txt analyze` |
| Shark interactive | `shark-cli -h dump.hprof interactive` |
| MAT headless | `./ParseHeapDump.sh dump-conv.hprof org.eclipse.mat.api:suspects` |
| Native leaks | `adb shell dumpsys meminfo --unreachable <pid>` |
| 3-hour trend | `adb shell dumpsys procstats --hours 3 <pkg>` |
| procstats CSV | `adb shell dumpsys procstats --csv` |
| GPU memory tracking | `adb shell dumpsys memtrack` |
| Perfetto native heap | `heap_profile -n <pkg> -d 30000` |
| Perfetto java heap | `java_heap_dump -n <pkg>` |
| Strip PII from dump | `shark-cli -h dump.hprof strip-hprof` |
| Force GC (debug) | `adb shell am force-gc <pkg>` (API 30+) |
| Extract bitmaps | `java -jar hprof_bitmap_dump.jar dump.hprof out/` |
| Glide cache log | `adb shell setprop log.tag.Engine VERBOSE && adb logcat -s Engine` |
