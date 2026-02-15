# Advanced Debugging Reference

CLI-only debugging techniques: StrictMode, database/SharedPreferences inspection, memory leak detection, ANR/tombstone analysis, crash testing, monkey testing, and system simulation.

## 1. StrictMode from CLI

StrictMode detects accidental disk/network access on the main thread.

### Enabling in Code (Reference)

```kotlin
if (BuildConfig.DEBUG) {
  StrictMode.setThreadPolicy(
    StrictMode.ThreadPolicy.Builder()
      .detectAll()
      .penaltyLog()
      .build()
  )
  StrictMode.setVmPolicy(
    StrictMode.VmPolicy.Builder()
      .detectAll()
      .penaltyLog()
      .build()
  )
}
```

### CLI Controls

```bash
# Toggle visual indicator (device/build-specific)
adb shell setprop persist.sys.strictmode.visual 1   # Enable
adb shell setprop persist.sys.strictmode.visual 0   # Disable

# Monitor violations in logcat
adb logcat | grep -i strictmode
```

### Device-Wide StrictMode via ADB (No Code Changes)

Enable StrictMode for any app without modifying source code:

```bash
# Method 1: Global settings (screen flash on violations)
adb shell settings put global development_settings_enabled 1
adb shell settings put global strict_mode_enabled 1

# Method 2: System properties (force-enable for ALL apps)
adb shell setprop persist.sys.strictmode.disable false
adb shell setprop debug.strictmode 1

# Filtered logcat for StrictMode only
adb logcat -v long StrictMode:* *:S

# Extra detail level
adb shell setprop log.tag.StrictMode DEBUG
```

**Note**: On Android 9+, some global settings are limited to debuggable apps. Method 2 with system properties is more broadly effective on emulators and rooted devices.

Violations appear in logcat under StrictMode tags. Enable during development to catch disk/network main-thread issues that only surface in production.

## 2. Database Debugging (SQLite / Room)

> **Note:** For basic SQLite/database CLI commands (`run-as`, `sqlite3`, pull-to-host), see `adb-reference.md` File Operations section. This section covers debugging-specific patterns.

### Debugging Patterns

```bash
# Quick table check without entering interactive shell
adb shell run-as com.example.app sqlite3 databases/mydb.db ".tables"

# Check Room metadata (migration version, identity hash)
adb shell run-as com.example.app sqlite3 databases/mydb.db \
  "SELECT * FROM room_master_table;"

# Dump specific table for comparison
adb shell run-as com.example.app sqlite3 databases/mydb.db \
  -header -csv "SELECT * FROM users;" > users_dump.csv

# Verify schema after Room migration
adb shell run-as com.example.app sqlite3 databases/mydb.db ".schema users"
```

### Copy and Inspect Offline

When you need full database exploration, copy to host:

```bash
adb shell "run-as com.example.app cp databases/mydb.db /sdcard/mydb.db"
adb pull /sdcard/mydb.db .
sqlite3 mydb.db    # On host machine
```

### SQL Performance Tracing (No Code Changes)

Enable verbose SQL statement logging and slow query detection purely via ADB:

```bash
# Log ALL SQL statements to logcat
adb shell setprop log.tag.SQLiteStatements VERBOSE
# Output: D/SQLiteStatements: UPDATE User SET name='...' WHERE id=...

# Log SQL execution times
adb shell setprop log.tag.SQLiteTime VERBOSE
# Output: D/SQLiteTime: Query took 35ms

# Flag any query exceeding a threshold (ms)
adb shell setprop db.log.slow_query_threshold 200
# Any query >200ms appears in logcat

# Monitor SQL activity
adb logcat -v time SQLiteStatements:V SQLiteTime:V *:S
```

Zero-code database debugging: set properties, reproduce the flow, and inspect logcat for slow or unexpected queries. Requires app restart after setting properties.

### Content Providers via CLI

Query system or app Content Providers without code:

```bash
# Query system settings
adb shell content query --uri content://settings/system

# Query SMS (if permissions allow)
adb shell content query --uri content://sms --projection address,body --sort "date DESC"

# Query contacts
adb shell content query --uri content://contacts/phones
```

Useful for reading system state and verifying data. App Room databases typically do not expose ContentProviders unless explicitly configured.

## 3. SharedPreferences from CLI

SharedPreferences are XML files under `/data/data/<package>/shared_prefs/`.

```bash
# Read preferences
adb shell "run-as com.example.app cat shared_prefs/settings.xml"

# Pull for editing
adb shell "run-as com.example.app cat shared_prefs/settings.xml" > settings.xml

# Edit locally, then push back
adb shell "run-as com.example.app sh -c 'cat > shared_prefs/settings.xml'" < settings.xml
```

### Full Round-Trip Modification (cp-based)

When the `cat` redirect method fails (permission issues on some devices):

```bash
# Copy out via /sdcard intermediary
adb shell "run-as com.example.app cp shared_prefs/settings.xml /sdcard/settings.xml"
adb pull /sdcard/settings.xml .

# Edit locally with any editor
# ... edit settings.xml ...

# Push back via /sdcard intermediary
adb push settings.xml /sdcard/settings.xml
adb shell "run-as com.example.app cp /sdcard/settings.xml shared_prefs/settings.xml"

# Alternative: exec-out to avoid /sdcard entirely
adb exec-out run-as com.example.app cat shared_prefs/settings.xml > local.xml
```

**Critical**: Pushing back preferences while the app is running has no effect until the app is killed and restarted. The in-memory SharedPreferences cache takes precedence:

```bash
adb shell am force-stop com.example.app
# Now restart — app loads the modified XML
```

### Dump Loaded Preferences (Runtime Inspection)

```bash
adb shell dumpsys activity preferences com.example.app
```

Prints currently loaded preference files and their values without pulling XML files. Useful for quick runtime inspection.

Use these techniques to flip feature flags, simulate corrupted preferences, or reset state between test runs.

## 4. Layout/UI Debugging Without GUI

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

## 5. Memory Leak Detection

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

## 6. ANR Traces and Tombstones

### ANR Traces

ANR stack traces stored at `/data/anr/traces.txt`:

```bash
# On emulator or rooted device
adb shell "cp /data/anr/traces.txt /sdcard/anr_traces.txt"
adb pull /sdcard/anr_traces.txt .

# Or print directly
adb shell "cd /data/anr && cat traces.txt" > anr.txt
```

`traces.txt` shows all thread stacks at the time of ANR. Use with CPU stats to diagnose deadlocks and main-thread stalls.

### Tombstones (Native Crashes)

Native crashes generate tombstones at `/data/tombstones/`:

```bash
adb shell "cp /data/tombstones/tombstone_00 /sdcard/tombstone_00"
adb pull /sdcard/tombstone_00 .
```

Tombstones contain: all thread stacks, memory map, open file descriptors. Critical for diagnosing SIGSEGV and other native crashes.

### Thread Dumps

```bash
# Activity manager thread dump (managed threads)
adb shell dumpsys activity threads > threads.txt

# SIGQUIT thread dump — sends full thread dump to logcat (all threads, locks, wait states)
adb shell "kill -3 $(pidof -s com.example.app)"
adb logcat -d -s art | grep -A 50 "SIGQUIT"  # Capture from logcat
```

The `kill -3` (SIGQUIT) technique is more comprehensive than `dumpsys activity threads` — it shows all JVM threads with their full stack traces, lock states, and monitor ownership. Critical for diagnosing deadlocks where `dumpsys` output is insufficient.

**Deadlock detection pattern**: In the SIGQUIT output, look for threads in `BLOCKED` or `WAITING` state holding monitors that other blocked threads are waiting on:

```
"main" ... BLOCKED on 0x... (a com.example.Mutex) held by thread 15
"AsyncTask #3" ... BLOCKED on 0x... (a com.example.Lock) held by thread 1
```

A circular dependency between `held by` references confirms a deadlock.

### Symbolizing Native Tombstones

Use `ndk-stack` to convert raw tombstone addresses into human-readable function names:

```bash
adb pull /data/tombstones/tombstone_00 .
ndk-stack -sym app/build/intermediates/merged_native_libs/debug/out/lib/arm64-v8a \
  -dump tombstone_00
```

Requires NDK on PATH and unstripped `.so` files from your build. Without `ndk-stack`, tombstones show only hex addresses — unusable for debugging native crashes.

## 7. Crash Analysis

### Force Crash for Testing

```bash
adb shell am crash com.example.app
```

Triggers a deliberate crash to verify crash reporters, logcat scraping, and CI crash handling.

### Forced ANR and Tombstone Simulation

```bash
# Force an ANR by blocking the main thread
adb shell am hang

# Force a tombstone capture without killing the process (on-device command)
adb shell "debuggerd -b \$(pidof -s com.example.app)"
```

Use `am hang` to test ANR reporters and verify ANR trace collection workflows. The `debuggerd -b` command captures a native backtrace (tombstone) for a running process without terminating it — useful for diagnosing hangs without losing state.

### Bugreports

Full diagnostic dump for post-mortem analysis:

```bash
adb bugreport bugreport.zip
```

ZIP contains: `anr/` and `tombstones/` copies, logs, dumpsys output, device info.

## 8. Monkey Testing

Random event injection for stress testing and crash discovery.

### Basic Usage

```bash
# 1000 random events across whole system
adb shell monkey -v 1000

# Limit to one package
adb shell monkey -p com.example.app -v 1000

# Reproducible run with throttling
adb shell monkey -p com.example.app \
  --throttle 500 \
  -s 42 \
  -v -v -v \
  10000 > monkey.log
```

### Key Options

| Option | Purpose |
|--------|---------|
| `-p <package>` | Restrict to your app |
| `-v` (1-3 times) | Verbosity level |
| `-s <seed>` | Reproducible sequence |
| `--throttle <ms>` | Delay between events |
| `--ignore-crashes` | Continue after crash |
| `--ignore-timeouts` | Continue after ANR |

### Event Mix Control

```bash
adb shell monkey -p com.example.app \
  -v \
  --pct-touch 50 \
  --pct-motion 20 \
  --pct-nav 10 \
  --pct-majornav 5 \
  --pct-syskeys 5 \
  --pct-appswitch 5 \
  --pct-anyevent 5 \
  10000
```

### Scriptable Monkey (Deterministic Sequences)

For AI agents, the scriptable monkey is more valuable than random mode. Generate deterministic scripts that are faster than individual `input` commands:

```bash
# Create script file:
cat > /tmp/monkey_script.txt << 'EOF'
type= raw events
count= 5
speed= 1.0
start data >>
DispatchPointer(0, 0, 0, 500, 1200, 0, 0, 0, 0, 0, 0, 0)
DispatchPointer(0, 0, 1, 500, 1200, 0, 0, 0, 0, 0, 0, 0)
UserWait(1000)
DispatchPointer(0, 0, 0, 500, 800, 0, 0, 0, 0, 0, 0, 0)
DispatchPointer(0, 0, 1, 500, 800, 0, 0, 0, 0, 0, 0, 0)
EOF

# Push to device and execute:
adb push /tmp/monkey_script.txt /sdcard/monkey_script.txt
adb shell monkey -f /sdcard/monkey_script.txt 1
```

DispatchPointer action codes: 0=DOWN, 1=UP, 2=MOVE. Combine for taps, swipes, long-presses.

### Crash Detection

- Check monkey exit code (non-zero = error)
- Grep output for `CRASH:` or `ANR:`
- Correlate with `anr/`, `tombstones/`, and logcat

## 9. System Simulation from CLI

### Doze Mode and App Standby

```bash
# Enable device idle (Doze)
adb shell dumpsys deviceidle enable

# Force idle (enter Doze immediately)
adb shell dumpsys deviceidle force-idle

# Exit idle
adb shell dumpsys deviceidle unforce
adb shell dumpsys battery reset
```

Simulate unplugged battery:

```bash
adb shell dumpsys battery unplug
# ... test ...
adb shell dumpsys battery reset
```

Granular battery simulation (test low-battery UX, charging indicators):

```bash
# Set exact battery level (0-100)
adb shell dumpsys battery set level 5     # Critical low
adb shell dumpsys battery set level 100   # Full

# Set charging status (1=unknown, 2=charging, 3=discharging, 4=not charging, 5=full)
adb shell dumpsys battery set status 2    # Charging
adb shell dumpsys battery set status 5    # Full

# Reset all battery overrides
adb shell dumpsys battery reset
```

Combine with WiFi ADB (no USB cable) to observe "real" unplugged behavior.

### Display Density and Size Simulation

Test responsive layouts and density-dependent rendering:

```bash
# Override display density (default varies: Pixel 6 = 411 dpi)
adb shell wm density 180     # Low density (ldpi-range)
adb shell wm density 480     # High density (xxhdpi-range)

# Override display resolution
adb shell wm size 1080x1920  # Full HD
adb shell wm size 720x1280   # HD (smaller phone)

# Reset to hardware defaults
adb shell wm density reset
adb shell wm size reset
```

Useful for testing how layouts behave across density buckets and screen sizes without needing multiple physical devices.

### Process Lifecycle Commands

```bash
# am force-stop: Immediate, unconditional kill. Clears all pending intents,
# stops services, removes from recents. App must be manually relaunched.
adb shell am force-stop com.example.app

# am kill: Polite kill. Only kills if app is in the background and safe to kill.
# Preserves saved instance state — Activity recreates normally on relaunch.
adb shell am kill com.example.app
```

Use `am kill` to test process death restoration (onSaveInstanceState/onRestoreInstanceState). Use `am force-stop` for a clean slate (e.g., between test runs).

### Keep Device Awake (CI/Testing)

```bash
# Keep screen on while USB is connected (survives reboots)
adb shell svc power stayon true

# Alternatives: usb = stay on when USB, ac = when AC, wireless = when wireless charging
adb shell svc power stayon usb

# Disable
adb shell svc power stayon false
```

Essential for self-hosted CI runners with physical devices — prevents screen lock from breaking test runs.

### Background Execution Limits

```bash
# Simulate app inactive state
adb shell am set-inactive <package> true

# Force UID into idle state (more aggressive than set-inactive)
adb shell am make-uid-idle <package>

# Use appops for restrictions
adb shell cmd appops set <package> RUN_IN_BACKGROUND deny
adb shell cmd appops set <package> RUN_IN_BACKGROUND allow
```

### App Standby Buckets (Android 9+)

Control how aggressively the system restricts background work:

```bash
# Set standby bucket (active, working_set, frequent, rare, restricted)
adb shell am set-standby-bucket <package> rare

# Check current bucket
adb shell am get-standby-bucket <package>
```

| Bucket | Effect |
|--------|--------|
| `active` | No restrictions (app in foreground) |
| `working_set` | Mild restrictions on jobs/alarms |
| `frequent` | Deferred jobs, limited network |
| `rare` | Heavily restricted background work |
| `restricted` | Almost no background execution (Android 12+) |

Test that WorkManager tasks, alarms, and FCM still function correctly under restrictive buckets.

API-level dependent; rely on official Doze/App Standby docs for exact flows.

### Configuration Changes

```bash
# Orientation
adb shell settings put system accelerometer_rotation 0  # Disable auto-rotate
adb shell settings put system user_rotation 1            # Force landscape (0=portrait, 1=landscape)

# Dark mode
adb shell cmd uimode night yes
adb shell cmd uimode night no

# Font scale
adb shell settings put system font_scale 1.3

# Locale (requires restart; root or emulator)
adb shell "setprop persist.sys.locale es-ES; stop; sleep 5; start"

# Do Not Disturb (Zen Mode)
adb shell settings put global zen_mode 1    # Enable DND
adb shell settings put global zen_mode 0    # Disable DND

# RTL layout testing
adb shell settings put global debug_force_rtl 1   # Force RTL layout
adb shell settings put global debug_force_rtl 0   # Restore LTR

# Time and timezone simulation
adb shell settings put global auto_time 0                    # Disable auto-time
adb shell date "MMDDhhmm[[CC]YY][.ss]"                      # Set date (root/emulator)
adb shell setprop persist.sys.timezone "America/New_York"    # Set timezone
adb shell am broadcast -a android.intent.action.TIMEZONE_CHANGED  # Notify apps
```

Orientation values for `user_rotation`: 0=portrait, 1=landscape, 2=reverse portrait, 3=reverse landscape.

RTL testing is essential for Arabic/Hebrew locale support — `debug_force_rtl` flips all layouts without changing locale. Time simulation is useful for testing time-sensitive logic (expiration, scheduling) without waiting.

Drive configuration changes before starting Activity, then assert behavior via Espresso/Compose tests.

### Multi-Window and Form Factor Testing

Test non-phone form factors and multi-window scenarios from CLI:

```bash
# Enable freeform multi-window (requires reboot on some devices)
adb shell settings put global enable_freeform_support 1

# Launch app in split-screen/multi-window mode
adb shell am start -n com.example.app/.MainActivity --windowingMode 5  # split-screen

# Launch in freeform window (desktop mode)
adb shell am start -n com.example.app/.MainActivity --windowingMode 5

# Simulate TV/Automotive DPAD navigation
adb shell input keyevent KEYCODE_DPAD_DOWN
adb shell input keyevent KEYCODE_DPAD_RIGHT
adb shell input keyevent KEYCODE_DPAD_CENTER   # Select
```

Important for foldables, tablets, ChromeOS, Android Automotive, and Samsung DeX. Test that layouts adapt correctly and Activity lifecycle handles configuration changes during window mode transitions.

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Over-rely on logcat for debugging | Use systrace/Perfetto, StrictMode, heap dumps |
| Skip StrictMode during development | Enable early to catch disk/network main-thread issues |
| Debug only on debug builds | Release builds behave differently (R8/ProGuard, inlining, background limits) |
| Ignore ANR traces | Pull `/data/anr/traces.txt` for deadlock/stall analysis |
| Run monkey with no seed | Always use `-s <seed>` for reproducibility |
| Test only happy paths | Exercise offline, error, edge cases via CLI simulation |
| Push SharedPreferences while app is running | Kill app first: in-memory cache overrides file on disk |
| Guess at DB performance from logs alone | Use `setprop log.tag.SQLiteStatements VERBOSE` for exact SQL + timing |
