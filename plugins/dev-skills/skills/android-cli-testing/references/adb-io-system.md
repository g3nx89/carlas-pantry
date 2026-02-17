# ADB File Operations, Input, and System Control Reference

File push/pull, database access, network debugging, input simulation, screen capture, and system property control.

> For ADB connection and app management, see `adb-connection-apps.md`. For logcat and dumpsys, see `adb-logcat-dumpsys.md`.

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

# Settings (for animation disable commands, see adb-logcat-dumpsys.md > Animation Control)
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
```

## Bug Reporting

```bash
# Bugreport (comprehensive diagnostic dump)
adb bugreport bugreport.zip           # Android 7+
```
