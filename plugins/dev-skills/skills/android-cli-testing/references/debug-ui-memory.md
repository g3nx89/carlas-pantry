# UI Inspection and Memory Leak Detection Reference

CLI-only techniques for view hierarchy inspection, accessibility verification, Compose semantics debugging, memory leak detection, and heap dump analysis.

> For data/storage debugging (StrictMode, databases, SharedPrefs), see `debug-data-storage.md`. For crash analysis and monkey testing, see `debug-crashes-monkey.md`. For system simulation, see `debug-system-simulation.md`.

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

### Memory Pressure Simulation

Force the app to handle low-memory callbacks without killing the process:

```bash
# Simulate low memory pressure (triggers onTrimMemory callback)
adb shell am send-trim-memory <package> RUNNING_LOW

# Available levels: RUNNING_MODERATE, RUNNING_LOW, RUNNING_CRITICAL,
# UI_HIDDEN, BACKGROUND, MODERATE, COMPLETE
adb shell am send-trim-memory com.example.app COMPLETE
```

Use to verify that the app releases caches, downsizes bitmaps, and handles lifecycle correctly under memory pressure. More targeted than killing the process — tests the app's voluntary cleanup path.

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
