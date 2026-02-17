# ADB Logcat and Dumpsys Reference

Logcat filtering, buffers, and output formatting. Dumpsys service inspection for debugging window focus, fragment state, memory, battery, and graphics.

> For ADB connection and app management, see `adb-connection-apps.md`. For file operations, input, and screen capture, see `adb-io-system.md`.

## Logcat

### Filter Syntax

```bash
# Tag:Priority (V=Verbose, D=Debug, I=Info, W=Warning, E=Error, F=Fatal, S=Silent)
adb logcat ActivityManager:I MyApp:D *:S
adb logcat *:W                          # Warnings and above from all tags

# Filter by PID (app-specific)
adb logcat --pid=$(adb shell pidof -s com.example.app)

# Filter by UID
adb logcat --uid=<uid>

# Regex filter (Android 7+)
adb logcat -e "Exception|Error"
adb logcat --regex="pattern"

# Host-side grep (always works)
adb logcat | grep -E "(crash|exception|fatal)"
```

### Output Formats

`-v brief` (compact), `-v process`, `-v tag`, `-v thread`, `-v raw` (no metadata), `-v time`, **`-v threadtime`** (default, recommended), `-v long`. Modifiers: `epoch`, `uid`, `usec`, `UTC`, `printable`, `monotonic`, `color`.

### Buffers

`-b main` (app logs, default), `-b system` (OS messages), `-b crash` (crash logs), `-b events` (binary system events), `-b radio` (telephony), `-b all` (everything). Size: `-g` (print buffer sizes), `-G 16M` (set buffer to 16MB).

### Control Flags

`-c` (clear buffers), `-d` (dump and exit), `-t 100` (last 100 lines, exit), `-t '01-01 12:00:00.000'` (since timestamp), `-T 100` (last 100 then stream), `-f /path/log.txt` (file output), `-r 1024` (rotate KB), `-n 8` (rotated file count).

### Practical Patterns

```bash
# App-specific logs
adb logcat --pid=$(adb shell pidof -s com.example.myapp)

# Crash capture
adb logcat -b crash --pid=$(adb shell pidof -s com.example.myapp)
adb logcat -b crash -d > crash_log.txt

# ANR monitoring
adb logcat | grep -i "ANR in"

# Clear and capture fresh session
adb logcat -c && adb logcat -v threadtime > session.log

# Background log capture during tests
adb logcat -v threadtime > test_logs.txt &
LOG_PID=$!
# ... run tests ...
kill $LOG_PID
```

### Advanced Logcat

```bash
# Crash buffer only (isolate stack traces from noise):
adb logcat --buffer=crash
# Multiple buffers in one stream:
adb logcat --buffer=main,system,crash

# Stream from a specific timestamp (skip old logs, keep streaming):
adb logcat -T "2025-01-15 10:30:00.000"

# Combined filtering: app PID + regex + crash buffer
adb logcat -b crash -e "FATAL\|NullPointer" --pid=$(adb shell pidof -s com.example.myapp)

# Priority + tag + regex (on-device, no grep overhead):
adb logcat ActivityManager:I *:S -e "proc_start\|proc_died"

# UID + epoch timestamps for machine parsing:
adb logcat -v epoch,uid -b events

# Events buffer with specific event tags (system lifecycle events):
adb logcat -b events -e "am_proc_start\|am_proc_died\|am_activity_launch_time"
```

**Caveat:** `--buffer=` is the long form of `-b`. `--pid` requires API 24+. `-e` regex is API 23+. The `-b security` buffer requires root.

## dumpsys Service Reference

```bash
adb shell dumpsys -l                    # List ALL available services
```

### Window Focus Verification

Verify which Activity/Window is currently receiving input — more reliable than vision-based checks:

```bash
adb shell dumpsys window windows | grep mCurrentFocus
# Output: mCurrentFocus=Window{... u0 com.example.app/com.example.app.MainActivity}
# If focus is "StatusBar" or "Keyguard", the test has been interrupted
```

### Fragment State Verification (CLI-only method)

```bash
adb shell dumpsys activity top
# Look for "Active Fragments:" section:
#   #0: ReportFragment{...}  — fragment is attached
#   mHidden=false            — fragment is visible to the user
# This is the ONLY CLI method to verify Fragment visibility without instrumented code
```

### Activity Stack and Tasks

```bash
adb shell dumpsys activity activities            # Current activity stack/tasks
adb shell dumpsys activity services              # Running services
adb shell dumpsys activity services <package>    # Services for specific app
adb shell dumpsys activity broadcasts            # Broadcast state
adb shell dumpsys activity recents               # Recent tasks
adb shell dumpsys activity processes             # Running processes
adb shell dumpsys activity -p <package>          # Filter by package
```

### Memory Info

```bash
adb shell dumpsys meminfo                        # All processes summary
adb shell dumpsys meminfo <package_or_pid>       # Specific app
adb shell dumpsys meminfo -a <package>           # Detailed all sections
adb shell dumpsys meminfo --oom                  # Sorted by OOM adjustment
```

Shows PSS, USS, RSS, Java Heap, Native Heap, Code, Stack, Graphics.

### Battery Simulation

```bash
adb shell dumpsys battery                        # Current state
adb shell dumpsys battery set level 15           # Fake level (0-100)
adb shell dumpsys battery set status 2           # 1=unknown,2=charging,3=discharging,4=not charging,5=full
adb shell dumpsys battery set ac 0               # Simulate AC disconnected
adb shell dumpsys battery set usb 0              # Simulate USB disconnected
adb shell dumpsys battery unplug                 # Simulate fully unplugged
adb shell dumpsys battery reset                  # Restore real values
```

### Frame Rendering (gfxinfo)

```bash
adb shell dumpsys gfxinfo <package>              # Performance data
adb shell dumpsys gfxinfo <package> framestats   # Nanosecond frame timing (API 23+)
adb shell dumpsys gfxinfo <package> reset        # Reset counters
```

> **Note:** For frame timing interpretation, jank thresholds, and automated measurement scripts, see `performance-profiling.md`.

### Other Key Services

| Service | Command | Purpose |
|---------|---------|---------|
| Package info | `dumpsys package <pkg>` | Permissions, components, versions |
| Window info | `dumpsys window` | Display info, focused window, rotation |
| Network stats | `dumpsys netstats detail` | Per-UID network usage |
| Process stats | `dumpsys procstats --hours 24` | Process runtime/memory over time |
| Alarms | `dumpsys alarm \| grep <pkg>` | Pending alarms |
| Jobs | `dumpsys jobscheduler \| grep <pkg>` | Scheduled jobs |
| Usage stats | `dumpsys usagestats` | App standby bucket, usage patterns |
| Battery stats | `dumpsys batterystats --charged <pkg>` | Battery usage history |
| CPU info | `dumpsys cpuinfo` | CPU load per process |
| Wake locks | `dumpsys power` | Active wake locks |
| Doze state | `dumpsys deviceidle` | Doze mode status |

### Detailed Service Inspection

Deep-dive grep patterns for services listed above. Use these when the summary table gives you the right service but you need to extract specific data.

#### jobscheduler

```bash
# All jobs for a specific app (context around match):
adb shell dumpsys jobscheduler | grep -A 10 "com.example.myapp"
# Count of registered jobs:
adb shell dumpsys jobscheduler | grep "Registered.*Jobs"
# Force-run a specific job (bypass constraints):
adb shell cmd jobscheduler run -f com.example.myapp 1234
# Simulate job timeout:
adb shell cmd jobscheduler timeout com.example.myapp 1234
```

Reveals: all scheduled jobs, constraints (network/charging/idle), next run time, last execution result. `cmd jobscheduler run` requires API 24+. The `-f` flag bypasses all constraints.

#### alarm

```bash
adb shell dumpsys alarm | grep -A 5 "com.example.myapp"
# Batch windows and alarm counts:
adb shell dumpsys alarm | grep "Batch\|num alarms\|when="
```

Reveals: pending alarms, batch windows, wakeup vs non-wakeup counts, alarm stats per UID.

#### netstats

```bash
# Find app UID first:
adb shell dumpsys package com.example.myapp | grep userId
# Then filter by UID:
adb shell dumpsys netstats detail | grep -A 8 "uid=10234"
```

Reveals: per-UID network bytes (rx/tx), bucketed into 2-hour windows. `set=DEFAULT` = foreground, `set=BACKGROUND` = background.

#### usagestats

```bash
adb shell dumpsys usagestats | grep -B 2 -A 5 "package=com.example.myapp"
```

Reveals: package usage times (ms), activity resume counts, last-time-used timestamps, standby bucket assignment.

#### procstats

```bash
# Last 3 hours of process statistics:
adb shell dumpsys procstats --hours 3
# Memory format: minPss-avgPss-maxPss / minUss-avgUss-maxUss
adb shell dumpsys procstats --hours 3 | grep "com.example.myapp"
# Full options:
adb shell dumpsys procstats -h
```

Reveals: per-process runtime %, PSS/USS/RSS memory over time, foreground vs cached states. API 19+. `--hours` caps at 24.

## Settings Database Hidden Keys

Three namespaces: `global`, `secure`, `system`. List all keys in a namespace with `adb shell settings list global`.

### Animation Control (Essential for UI Testing)

```bash
# Disable all animations:
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
# Re-enable (default 1):
adb shell settings put global animator_duration_scale 1
```

### Display and UI Testing

```bash
# Show layout bounds (same as Developer Options toggle):
adb shell setprop debug.layout true

# Disable immersive mode confirmation bubble:
adb shell settings put secure immersive_mode_confirmations confirmed

# Font scale testing (accessibility):
adb shell settings put system font_scale 1.3
# Reset:
adb shell settings put system font_scale 1.0

# Dark mode toggle (API 29+):
adb shell cmd uimode night yes
adb shell cmd uimode night no

# Show taps (useful for screen recording demos):
adb shell settings put system show_touches 1
```

### Screenshot and Demo Mode

```bash
# Enable Demo Mode for clean status bar in screenshots:
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
```

### Developer Convenience

```bash
# Stay awake while charging (value 3 = AC + USB + wireless):
adb shell settings put global stay_on_while_plugged_in 3

# Bypass hidden API restrictions (API 28+, testing only):
adb shell settings put global hidden_api_policy 1
# 0=default, 1=allow all, 2=disallow, 3=warn only
# Reset:
adb shell settings delete global hidden_api_policy

# HTTP proxy (for Charles/mitmproxy):
adb shell settings put global http_proxy "192.168.1.100:8888"
# Clear proxy:
adb shell settings delete global http_proxy
```

## cmd package Commands

Package compilation, DEX optimization, and permission listing via `cmd package`.

### Compile and Optimize

```bash
# Profile-guided compilation (recommended for benchmarking):
adb shell cmd package compile -m speed-profile -f com.example.myapp
# Full AOT compilation (maximum speed, larger size):
adb shell cmd package compile -m speed -f com.example.myapp
# Compile everything on device (slow, 10-30 min):
adb shell cmd package compile -m speed -f -a
# Clear compiled code (reset to JIT):
adb shell cmd package compile --reset com.example.myapp
```

**Modes:** `verify` | `quicken` | `space-profile` | `space` | `speed-profile` | `speed` | `everything`

**Caveat:** API 24+ (ART JIT). `-f` forces recompile even if already compiled.

### Background DEX Optimization

```bash
# Force background dexopt (runs what idle maintenance would):
adb shell cmd package bg-dexopt-job
# Cancel running background dexopt:
adb shell cmd package cancel-bg-dexopt-job
# Reconcile secondary DEX files:
adb shell cmd package reconcile-secondary-dex-files com.example.myapp
# Delete dex optimization results:
adb shell cmd package delete-dexopt com.example.myapp
```

**Use case:** After OTA or app update, force dexopt to eliminate jank from JIT compilation.

### List Permissions and Features

```bash
# Dangerous permissions only (grouped):
adb shell cmd package list permissions -d -g
# All permissions with full detail:
adb shell cmd package list permissions -f
# List device features:
adb shell pm list features
# Trim app caches (free 500MB):
adb shell pm trim-caches 500000000
```

## Window Manager (wm) Commands

Display size, density, and overscan manipulation for testing responsive layouts.

```bash
# Get current values:
adb shell wm size           # e.g., Physical size: 1080x2400
adb shell wm density        # e.g., Physical density: 420

# Simulate tablet on phone:
adb shell wm size 2560x1600
adb shell wm density 320
# Reset:
adb shell wm size reset && adb shell wm density reset

# Overscan (shift display area; LEFT,TOP,RIGHT,BOTTOM):
adb shell wm overscan 0,0,0,100    # raise bottom by 100px
adb shell wm overscan reset
```

**Caveat:** `wm overscan` deprecated in API 30+; use display-cutout simulation in emulator instead. Setting invalid wm values may require reboot to recover.

## Device Properties (getprop/setprop)

System properties for debugging visuals, logging, and device identification.

### Debug Visualization

```bash
# Show layout bounds:
adb shell setprop debug.layout true      # toggle off: false
# GPU overdraw visualization:
adb shell setprop debug.hwui.overdraw show
# Color-blind mode:
adb shell setprop debug.hwui.overdraw show_deuteranomaly
adb shell setprop debug.hwui.overdraw false
# GPU profiling bars on screen:
adb shell setprop debug.hwui.profile visual_bars
```

### Log Tag Control

```bash
# Set minimum log level for a tag (V/D/I/W/E/S):
adb shell setprop log.tag.MyAppTag VERBOSE
# Suppress all logs for a noisy tag:
adb shell setprop log.tag.NoisyLib SUPPRESS
```

### System Configuration

```bash
# Change timezone without reboot:
adb shell setprop persist.sys.timezone "America/Los_Angeles"
```

### Read-Only Build Properties

```bash
adb shell getprop ro.build.version.sdk        # API level
adb shell getprop ro.build.type               # userdebug/eng/user
adb shell getprop ro.product.model            # device model
adb shell getprop ro.build.display.id         # build fingerprint
# Dump ALL properties:
adb shell getprop
```

**Caveat:** `setprop` changes are lost on reboot unless prefixed with `persist.`. Many `debug.*` props require a process restart to take effect (kill and relaunch the app).

## ADB Emulator Console Commands

Commands that only work with the Android emulator (not physical devices). Uses `adb emu` shorthand or `telnet localhost 5554`.

### GPS Simulation

```bash
# Fake GPS location (longitude latitude):
adb emu geo fix -122.084 37.422
```

### Telephony Simulation

```bash
# Simulate incoming call:
adb emu gsm call 5551234567
# Send SMS:
adb emu sms send 5551234567 "Test message body"
```

### Power Simulation

```bash
# Set battery level:
adb emu power capacity 15
adb emu power status not-charging
```

### Network Condition Simulation

```bash
# Slow network:
adb emu network speed gsm
# Fast network:
adb emu network speed lte
# High latency:
adb emu network delay gprs
```

### Biometric Simulation

```bash
# Simulate fingerprint touch (ID 1):
adb emu finger touch 1
```

**Caveat:** `adb emu` commands require the Android emulator console. Auth token at `~/.emulator_console_auth_token`.
