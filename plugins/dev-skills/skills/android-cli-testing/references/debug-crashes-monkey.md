# Crash Analysis and Monkey Testing Reference

CLI-only techniques for ANR trace collection, tombstone analysis, thread dump deadlock detection, native crash symbolication, crash simulation, and monkey/stress testing.

> For memory leak detection, see debug-ui-memory.md. For system simulation (Doze, battery), see debug-system-simulation.md.

## ANR Traces and Tombstones

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

## Crash Analysis

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

## Monkey Testing

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
