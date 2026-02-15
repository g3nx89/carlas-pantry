# System Simulation and Configuration Testing Reference

CLI-only techniques for simulating system conditions: Doze mode, battery states, display density, process lifecycle, background execution limits, App Standby Buckets, configuration changes (orientation, dark mode, locale, RTL), and multi-window testing.

> For StrictMode and data debugging, see debug-data-storage.md. For crash/ANR analysis, see debug-crashes-monkey.md.

## System Simulation from CLI

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
| Guess at DB performance from logs alone | Use `setprop log.tag.SQLiteStatements VERBOSE` for exact SQL + timing |
