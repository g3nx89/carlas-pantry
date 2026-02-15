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
