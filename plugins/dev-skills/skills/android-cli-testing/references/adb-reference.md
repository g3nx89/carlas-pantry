# ADB Comprehensive Reference

Complete ADB command reference for Android testing and debugging from the CLI.

## Architecture: Server-Client-Daemon Model

ADB operates as a tripartite system — understanding this prevents mysterious connection failures.

- **Client**: The `adb` binary invoked on the host. Transient — sends request to server, prints response, exits.
- **Server**: Long-running process on host bound to TCP port 5037. Manages all device connections and serializes commands.
- **Daemon (adbd)**: Background process on the Android device/emulator. In `userdebug`/`eng` builds (emulators), runs as root.

**Concurrency bottleneck**: The ADB server is a single point of contention. Multiple parallel agent threads invoking ADB commands are serialized through this one process. Heavy loads (e.g., pushing large files to 10 devices) can saturate I/O. For high-throughput testing, implement queueing or rate-limiting.

**Server health recovery**: If the server becomes unresponsive during long test suites, restart the sequence:

```bash
adb kill-server && adb start-server
```

## Connection Management

### Device List Parsing

```bash
adb devices          # Basic listing: serial + state
adb devices -l       # Extended: product, model, device, transport_id
```

Parse `adb devices -l` output to map serials to device characteristics:
- `emulator-5554 device product:sdk_gphone64_x86_64` → x86_64 emulator
- `192.168.1.5:43215 device product:bramble model:Pixel_4a_5G` → physical Pixel 4a 5G

Agents can use this to route ARM-native tests to physical devices and UI tests to emulators.

### USB Debugging

**Device states**: `device` (connected, operational but may still be booting), `unauthorized` (RSA prompt not accepted), `offline` (not responding), `no permissions` (Linux udev rules missing).

### WiFi/TCP Connection

```bash
# Legacy (Android 10 and below, also works on 11+):
adb tcpip 5555                       # Switch device to TCP/IP mode
adb connect <device_ip>:5555         # Connect wirelessly
adb disconnect <device_ip>:5555      # Disconnect

# Legacy TCP/IP disconnect hazard:
# Switching to TCP/IP terminates the USB connection. Handle this sequence:
#   1. Verify USB: adb devices
#   2. Switch:     adb tcpip 5555        (restarts adbd, drops USB)
#   3. Wait for USB drop or command return
#   4. Connect:    adb connect <ip>:5555
#   5. Verify:     adb devices

# Android 11+ wireless debugging (no initial USB needed, TLS-encrypted):
adb pair <ip>:<pairing_port>         # Enter 6-digit code when prompted
adb connect <ip>:<connection_port>   # Connect (DIFFERENT port than pairing)

# mDNS discovery:
adb mdns check                       # Verify mDNS working
adb mdns services                    # List discovered services
```

### Multi-Device Targeting

```bash
adb -s <serial> <command>            # By serial number
adb -s emulator-5554 install app.apk
adb -d <command>                     # USB device only
adb -e <command>                     # Emulator only
adb -t <transport_id> <command>      # By transport ID
export ANDROID_SERIAL=emulator-5554  # Environment variable (overridden by -s)
```

### Server Management

```bash
adb start-server    # Starts on port 5037
adb kill-server
adb version
```

Environment variables: `ADB_SERVER_SOCKET` (override socket), `ADB_MDNS_OPENSCREEN=1` (enable mDNS without external service).

## App Management

### Install with All Flags

```bash
adb install app.apk                    # Basic (streamed by default)
adb install -r app.apk                 # Replace/reinstall, keep data
adb install -t app.apk                 # Allow test-only APKs
adb install -g app.apk                 # Grant ALL runtime permissions
adb install -d app.apk                 # Allow version downgrade (debug only)
adb install --abi <abi> app.apk        # Override ABI
adb install --instant app.apk          # Install as instant app
adb install --fastdeploy app.apk       # Fast deploy
adb install --no-streaming app.apk     # Legacy push-then-install

# Split APKs (one package, simplified):
adb install-multiple base.apk split_config.en.apk split_config.xxhdpi.apk

# Multiple different packages atomically:
adb install-multi-package app1.apk app2.apk

# Split APKs (session-based, full control for App Bundles):
# 1. Create session — capture session ID from output "Success: created install session [1234]"
adb shell pm install-create -S <total_size_bytes>
# 2. Write each split into the session
adb shell pm install-write -S <base_size> 1234 0_base /data/local/tmp/base.apk
adb shell pm install-write -S <split_size> 1234 1_config /data/local/tmp/split_config.apk
# 3. Commit — atomic install of all parts
adb shell pm install-commit 1234
```

### Common Install Errors

| Error | Fix |
|-------|-----|
| `INSTALL_FAILED_ALREADY_EXISTS` | Use `-r` flag |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Signature mismatch, uninstall first |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | Use `-d` flag |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | Free space on device |
| `INSTALL_FAILED_TEST_ONLY` | Use `-t` flag |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | Wrong architecture, rebuild with correct ABI |
| `INSTALL_FAILED_VERIFICATION_FAILURE` | Disable Play Protect: `settings put global verifier_verify_adb_installs 0` |

### Package Manager (pm)

```bash
adb shell pm list packages              # All packages
adb shell pm list packages -3           # Third-party only
adb shell pm list packages -s           # System only
adb shell pm list packages -f           # Show APK file paths
adb shell pm list packages -e           # Enabled only
adb shell pm list packages -d           # Disabled only
adb shell pm list packages <filter>     # Filter by name substring
adb shell pm dump <package>             # Full package info
adb shell pm path <package>             # APK file path(s)
adb shell pm clear <package>            # Clear all app data and cache
adb shell pm uninstall <package>        # Full uninstall
adb shell pm uninstall -k <package>     # Uninstall but keep data/cache

# Multi-user management (enterprise/shared device testing)
adb shell pm list users                 # List all user profiles
adb shell pm create-user "Work"         # Create secondary user profile
adb shell pm remove-user <user_id>      # Remove user profile
adb shell am switch-user <user_id>      # Switch active user
adb shell am start --user <user_id> -n com.example.app/.MainActivity  # Launch in specific user
```

### Permissions

```bash
adb shell pm grant <pkg> android.permission.<NAME>
adb shell pm revoke <pkg> android.permission.<NAME>
adb shell pm reset-permissions          # Reset ALL apps' permissions
adb shell pm list permissions -d        # List dangerous permissions
adb shell dumpsys package <pkg> | grep "granted="  # Check granted status
```

Common permission strings: `CAMERA`, `READ_CONTACTS`/`WRITE_CONTACTS`, `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`, `READ_EXTERNAL_STORAGE`/`WRITE_EXTERNAL_STORAGE`, `RECORD_AUDIO`, `READ_PHONE_STATE`/`CALL_PHONE`, `SEND_SMS`/`READ_SMS`, `POST_NOTIFICATIONS` (API 33+), `ACCESS_BACKGROUND_LOCATION` (API 29+).

**Critical behavior**: Revoking a runtime permission while the app is running triggers an **immediate process kill** by the OS. The agent must expect the process to die and plan to restart the activity in the next step. This is by design — the OS enforces the security change atomically.

## cmd package (Modern Alternative to pm)

`cmd package` communicates directly via Binder, bypassing the Java-based `pm` wrapper. Faster and more stable for automated workflows.

```bash
# List packages (faster than pm list packages)
adb shell cmd package list packages
adb shell cmd package list packages -3              # Third-party only

# Query permissions by group (dangerous only)
adb shell cmd package list permissions -g -d

# Compile app for speed (force AOT)
adb shell cmd package compile -m speed -f <package>

# Uninstall for current user (remove bloatware without root)
adb shell cmd package uninstall -k --user 0 <package>
```

As Android evolves (API 34+), `cmd` is expected to offer more structured output (potentially JSON), reducing parsing burden.

## Activity Manager

```bash
# Start activity by component
adb shell am start -n com.example.app/.MainActivity
adb shell am start -W -n com.example.app/.MainActivity   # Wait for launch, outputs TotalTime/WaitTime
adb shell am start -S -W -n com.example.app/.MainActivity   # Force-stop first (cold start benchmark)
adb shell am start -D -n com.example.app/.MainActivity   # Enable debugging

# Start with action/data (deep links)
adb shell am start -a android.intent.action.VIEW -d "https://example.com"
adb shell am start -a android.intent.action.VIEW -d "geo:37.7749,-122.4194"
adb shell am start -a android.intent.action.VIEW -d "myapp://deeplink/path"

# Intent extras — data type mapping:
#   --es key string    --ez key boolean  --ei key int     --el key long
#   --ef key float     --eu key uri      --eia key 1,2,3  --ela key 1,2,3
#   --esa key a,b,c    --esn key (null)  --eial key 1,2,3 (ArrayList<Integer>)
# A type mismatch causes the app to receive null or malformed data

# Broadcast
adb shell am broadcast -a com.example.ACTION --es foo "bar" -p com.example.app
adb shell am broadcast -a android.intent.action.BOOT_COMPLETED

# Process management
adb shell am force-stop <package>       # Force-stop everything
adb shell am kill <package>             # Kill safe-to-kill processes
adb shell am kill-all                   # Kill all background processes

# Instrumented test execution
adb shell am instrument -w com.example.test/androidx.test.runner.AndroidJUnitRunner

# Run specific test class
adb shell am instrument -w \
  -e class com.example.test.LoginTest \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# Run specific method
adb shell am instrument -w \
  -e class com.example.test.LoginTest#testValidLogin \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# Instrument flags: -w (wait, REQUIRED), -r (raw output), -e name value (args)
# -e package com.example.test (filter by Java package)
# -e notAnnotation androidx.test.filters.LargeTest (exclude)
# --no-window-animation (disable animations during test)

# Profiling
adb shell am profile start com.example.app /sdcard/profile.trace
adb shell am profile stop com.example.app

# Other useful am commands
adb shell am monitor                    # Monitor for crashes/ANRs
adb shell am dumpheap <process> <file>  # Dump heap
adb shell am set-debug-app -w <package> # Wait for debugger on launch
adb shell am clear-debug-app
```

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

## File Operations

```bash
# Incremental sync (only copies changed files — faster than push for iterative workflows)
adb sync                                           # Sync all partitions
adb sync data                                      # Sync /data only

# Push/Pull
adb push local_file /sdcard/Download/
adb pull /sdcard/Download/file.txt ./
adb push ./assets/ /sdcard/Download/assets/  # Entire directory

# Common paths:
#   /sdcard/ or /storage/emulated/0/  - User-accessible
#   /data/local/tmp/                   - World-writable temp
#   /data/data/<package>/              - App private (needs run-as or root)

# Private app data (debuggable apps only)
adb shell run-as com.example.myapp ls -la
adb shell run-as com.example.myapp ls shared_prefs/
adb shell run-as com.example.myapp ls databases/
adb shell run-as com.example.myapp cat shared_prefs/com.example.myapp_preferences.xml

# Pull database directly
adb shell "run-as com.example.myapp cat databases/mydb.db" > mydb.db

# SQLite inspection (emulators have sqlite3 pre-installed)
adb shell sqlite3 /data/data/com.example.myapp/databases/mydb.db
# .tables  .schema table_name  .headers on  .mode column
# SELECT * FROM users LIMIT 10;
# SELECT * FROM room_master_table;    # Room metadata

# For physical devices without sqlite3, pull and inspect locally:
adb shell "run-as com.example.myapp cat databases/mydb.db" > mydb.db
sqlite3 mydb.db    # On host machine
```

## Network Debugging

```bash
# Port forwarding: host -> device
adb forward tcp:6100 tcp:7100           # localhost:6100 on host hits device:7100
adb forward --list                      # List all forwards
adb forward --remove tcp:6100           # Remove specific
adb forward --remove-all                # Remove all

# Reverse forwarding: device -> host
adb reverse tcp:8080 tcp:8080           # Device app hitting localhost:8080 reaches host:8080
adb reverse --list / --remove / --remove-all

# HTTP proxy
adb shell settings put global http_proxy 192.168.1.100:8888
adb shell settings put global http_proxy :0       # Clear (must use ":0", not empty)

# Traffic capture
adb shell tcpdump -i any -s 0 -w /sdcard/capture.pcap
adb pull /sdcard/capture.pcap

# Network state
adb shell dumpsys connectivity
adb shell ping -c 4 google.com
```

## Input Simulation

```bash
adb shell input tap 500 1200                     # Tap at coordinates
adb shell input swipe 500 1500 500 300           # Fast swipe up
adb shell input swipe 500 1500 500 300 1500      # Slow swipe (1.5s duration)
adb shell input text "hello"                     # Type text
adb shell input keyevent 3                       # HOME
adb shell input keyevent KEYCODE_BACK            # BACK (by name)
adb shell input keyevent --longpress 26          # Long-press POWER
adb shell input draganddrop 100 200 400 600 1000 # Drag and drop (API 24+)

# Long-press simulation (hold tap):
adb shell input swipe 500 800 500 800 1000       # Same start/end + duration

# Unicode/emoji injection (hex-encoded)
adb shell input text $'\u263A'                   # Smiley face
adb shell input text $'\u00e9'                   # é (accented e)
```

Unicode injection is useful for i18n testing — verify text fields handle multi-byte characters and emoji correctly.

**Essential key codes**: HOME (3), BACK (4), DPAD_UP/DOWN/LEFT/RIGHT (19-22), DPAD_CENTER (23), VOLUME_UP/DOWN (24/25), POWER (26), ENTER (66), DEL (67), MENU (82), SEARCH (84), APP_SWITCH (187), TAB (61).

## Screen Capture

```bash
# Screenshot (direct pipe - fastest)
adb exec-out screencap -p > screen.png

# Screenshot (via device storage)
adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png

# Screen recording
adb shell screenrecord /sdcard/video.mp4
adb shell screenrecord --size 1280x720 --bit-rate 8000000 --time-limit 60 /sdcard/video.mp4
# Stop with Ctrl+C, then: adb pull /sdcard/video.mp4
# Max 3 minutes per recording, no audio, API 19+
```

**Critical note**: `adb shell` allocates a PTY that mangles binary data (`\n` to `\r\n`). Always use `adb exec-out` for screenshots, tarballs, and database dumps.

## System Control

```bash
# Properties
adb shell getprop                                  # List all
adb shell getprop ro.build.version.sdk             # API level
adb shell getprop ro.build.version.release         # Android version
adb shell getprop ro.product.model                 # Device model
adb shell setprop debug.layout true                # Show layout bounds
adb shell setprop debug.hwui.profile visual_bars   # GPU render bars
adb shell setprop debug.hwui.overdraw show         # GPU overdraw

# Settings
adb shell settings put global animator_duration_scale 0      # Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global stay_on_while_plugged_in 3     # Stay on AC+USB

# Display
adb shell wm size                     # Get display size
adb shell wm size 1080x2340           # Override
adb shell wm size reset
adb shell wm density                  # Get density
adb shell wm density 420              # Override
adb shell wm density reset

# Service control
adb shell svc power stayon usb        # Keep screen on USB
adb shell svc power stayon true       # Keep on always
adb shell svc wifi enable/disable
adb shell svc data enable/disable
adb shell svc bluetooth enable/disable

# Dark mode
adb shell cmd uimode night yes        # Enable
adb shell cmd uimode night no         # Disable

# Notification verification
adb shell cmd notification list                    # List all active status bar notifications
adb shell dumpsys notification | grep -A5 "NotificationRecord"  # Detailed notification state

# App ops
adb shell cmd appops set com.example.app POST_NOTIFICATION ignore
adb shell cmd appops set com.example.app POST_NOTIFICATION allow

# Force AOT compilation
adb shell cmd package compile -m speed -f <package>

# Bugreport (comprehensive diagnostic dump)
adb bugreport bugreport.zip           # Android 7+
```
