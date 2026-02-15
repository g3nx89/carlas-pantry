# ADB Connection and App Management Reference

ADB architecture, connection management (USB/WiFi/TCP), app installation and management, permissions, and Activity Manager commands.

> For logcat and dumpsys, see `adb-logcat-dumpsys.md`. For file operations, input, and screen capture, see `adb-io-system.md`.

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
