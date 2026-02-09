# Genymotion Desktop CLI: exhaustive technical reference for automated Android testing

**Genymotion Desktop provides three CLI tools — GMTool, Genymotion Shell, and ADB — that together enable complete terminal-driven Android test automation, though significant limitations around headless operation and parallel scaling make it better suited for local development than CI/CD pipelines.** The emulator runs Android x86 images on QEMU (Linux/macOS) or VirtualBox (Windows) with near-native CPU performance via hardware virtualization, supports Android 5.0 through 15.0, and offers rich sensor simulation. However, Genymotion's own support documentation warns that Desktop is "not optimal for automation tests" and lacks headless mode entirely — a critical constraint the community has partially worked around but never fully solved. This report documents every CLI capability, integration pattern, and hard-won field lesson needed to build automated testing workflows with Kotlin/Jetpack Compose applications.

---

## PART 1 — Technical architecture for CLI-driven automation

### Virtualization engine and hypervisor layer

Genymotion Desktop runs Android x86/x86_64 system images inside a hypervisor VM. The default hypervisor varies by platform:

| Platform | Default Hypervisor | Alternative | Notes |
|---|---|---|---|
| **Linux** | QEMU (uses KVM) | VirtualBox (legacy) | QEMU bundled since v3.3.0 |
| **macOS Intel** | QEMU (Hypervisor.framework) | VirtualBox (deprecated) | VirtualBox only on Intel |
| **macOS Apple Silicon** | QEMU | None | Native arm64 Android images |
| **Windows** | VirtualBox | QEMU (experimental, requires Hyper-V) | QEMU on Windows has known performance issues |

On x86/x86_64 hosts, CPU instructions execute at near-native speed via hardware virtualization extensions (**VT-x** for Intel, **AMD-V** for AMD). On Apple Silicon Macs, Genymotion provides native ARM64 Android images — apps run identically to real ARM devices with no translation overhead.

**Quick Boot** is available only with the QEMU hypervisor and is not supported on Windows yet. When enabled (default), the VM state is saved on shutdown and resumed on next start, reducing boot time to seconds. The `--coldboot` flag forces a complete boot cycle. Quick Boot can be disabled per-device via `gmtool admin edit "DeviceName" --quickboot off` or in the virtual device configuration. A critical reliability note from the release notes: "Force cold boot with QEMU when snapshot is not compatible anymore" — corrupted Quick Boot state can prevent device startup and requires either a cold boot or factory reset.

**VirtualBox and Hyper-V are mutually exclusive on Windows.** VirtualBox crashes or performs terribly with Hyper-V enabled. QEMU on Windows *requires* Hyper-V. This creates a difficult situation for Windows developers who also need WSL2 or Docker Desktop.

Switch hypervisors via CLI:
```bash
gmtool config --hypervisor qemu   # or: virtualbox
```

### ADB architecture and connection model

Genymotion auto-registers running devices with ADB when configured with the Android SDK path (`gmtool config --use_custom_sdk on --sdk_path /path/to/sdk`). Each device receives a **VirtualBox/QEMU host-only IP address** (typically `192.168.56.101`, `192.168.56.102`, etc.) on port **5555**.

```bash
# Devices appear in adb as IP:port pairs
adb devices
# Output:
# List of devices attached
# 192.168.56.101:5555    device
# 192.168.56.102:5555    device
```

**Critical pitfall**: Genymotion ships its own ADB binary. If the host's Android SDK ADB version differs, the ADB server restarts can disconnect all devices. **Always configure Genymotion to use the same SDK ADB** by setting `gmtool config --use_custom_sdk on --sdk_path "$ANDROID_HOME"`. Manual connection is available via `adb connect 192.168.56.101:5555` or through GMTool: `gmtool device -n "DeviceName" adbconnect`.

For multiple concurrent instances, each device gets a unique IP on the host-only network. Port management is automatic — unlike the Android Studio emulator which uses incrementing port pairs (5554/5555, 5556/5557), Genymotion devices all use port 5555 but on different IPs. Target specific devices with `adb -s 192.168.56.101:5555 shell ...` or set the `ANDROID_SERIAL` environment variable.

### Image and disk storage

Virtual device images are stored in the path configured via `gmtool config --virtual_device_path <path>` (default varies by OS). Each device consists of a QEMU disk image or VirtualBox VDI file containing the Android system and user data partitions. **Minimum disk space per device is 2GB**, but devices with installed apps and GApps can consume **8GB+**. Screen captures are stored at the path set by `gmtool config --screen_capture_path <path>`.

### Network stack

| Mode | Description | CLI Configuration |
|---|---|---|
| **NAT** (default) | VM accesses external network through host NAT | No config needed |
| **Bridge** | VM gets own IP on physical network via DHCP | `gmtool admin create ... --network-mode bridge --bridged-if eth0` |

Bridge mode is **only available with VirtualBox hypervisor**. NAT mode uses the special address **`10.0.3.2`** as an alias for the host machine — useful for proxy configuration and `adb reverse` scenarios.

Port forwarding from host to device:
```bash
adb reverse tcp:8080 tcp:8080   # Device can reach host's port 8080 via localhost:8080
adb forward tcp:9999 tcp:5000   # Host can reach device's port 5000 via localhost:9999
```

### ARM translation layer

Genymotion on x86 hosts runs x86 Android. ARM-only apps require **libhoudini** (Intel's ARM-to-x86 binary translator), which Genymotion does **not distribute** due to licensing. Key facts:

- ARM translation must be sideloaded from community sources (GitHub repos by m9rco, niizam)
- Only translates **armeabi-v7a and armeabi** — **arm64-v8a is NOT supported** on x86 images
- **Genymotion officially warns**: "ARM translation tools modify the Android image and may damage your virtual device permanently. USE AT YOUR OWN RISKS!"
- Must be installed *before* Open GApps
- Verification: `adb shell getprop ro.product.cpu.abilist` should show `x86,armeabi-v7a,armeabi`
- **Best practice for testing**: Build APKs with x86/x86_64 ABI included, or use Mac M-series with native arm64 images

ABI support matrix:

| ABI | Mac M-series (ARM host) | PC/Mac Intel (x86 host) |
|---|---|---|
| arm64-v8a | ✅ Native | ❌ Not supported |
| armeabi-v7a | ❌ | 🔶 Requires ARM translation |
| x86_64 | ❌ | ✅ Android 11+ |
| x86 | ❌ | ✅ Android 5–10 |

### Google Play Services via CLI

Genymotion 2.10+ includes a one-click Open GApps installer widget in the toolbar. For **CLI/automation**, no official command exists. The community approach:

```bash
# Download appropriate x86 Open GApps nano package from opengapps.org
# Flash it via gmtool:
gmtool device -n "DeviceName" flash open_gapps-x86-11.0-nano-*.zip
# Or via adb:
adb push open_gapps.zip /sdcard/Download/
adb shell "/system/bin/flash-archive.sh /sdcard/Download/open_gapps.zip"
adb reboot
```

OpenGApps website **does not have packages for Android 12+** — for newer Android versions, the built-in widget is required. GApps version must exactly match the Android version. For CI workflows, use `deleteWhenFinish false` in the Gradle plugin to preserve GApps between runs, or use snapshot/clone to preserve the installed state.

### Performance characteristics

**Genymotion was historically 2–5x faster than the old ARM-based Android emulator.** After Google's Project Marble improvements (2018+), the Android Studio emulator reached parity or surpassed Genymotion in many benchmarks. A detailed community benchmark (1,100 Espresso tests on a 2015 MacBook Pro) showed **the Android Emulator completing tests faster than Genymotion** when properly configured with x86 images and HAXM.

Practical concurrent instance limits (per official Genymotion guidance: **"Not recommended to run more than one device at the same time"**):

| Host RAM | Max Instances | Per-Instance Recommended Config |
|---|---|---|
| 8GB | 1 (possibly 2 lightweight) | 1–2GB RAM, 2 CPU cores |
| 16GB | 2–3 | 2GB RAM, 2 CPU cores each |
| 32GB | 3–4 | 2–3GB RAM, 2 CPU cores each |

**Memory leaks are a documented, officially acknowledged limitation.** Genymotion support states: "Using Genymotion Desktop for a long period of time causes memory leaks which renders Genymotion extremely slow and unstable. This is a known limitation and no fixes could be implemented so far." The emulator is **not suitable for running more than 1 device for more than 12 hours**.

---

## PART 2 — GMTool complete CLI reference

### Installation and PATH setup

GMTool is bundled with Genymotion Desktop — no separate installation required.

| OS | Binary Location | PATH Setup |
|---|---|---|
| **Windows** | `C:\Program Files\Genymobile\Genymotion\` | Add to System PATH |
| **macOS** | `/Applications/Genymotion.app/Contents/MacOS/` | `export PATH="/Applications/Genymotion.app/Contents/MacOS:$PATH"` |
| **Linux** | `$HOME/genymotion/` or `/opt/genymotion/` | `export PATH="$HOME/genymotion:$PATH"` |

Shell autocompletion is provided for Bash and Zsh. Install Bash completion by adding to `~/.bash_profile`:
```bash
. {COMPLETION_DIR}/bash/gmtool.bash
```
Zsh completion: add before `compinit` in `~/.zshrc`:
```bash
fpath=({COMPLETION_DIR}/zsh $fpath)
```

### Authentication and license management

```bash
# Configure credentials (required before any paid-license commands)
gmtool config --email "user@example.com" --password "secret"

# Register license key
gmtool license register YOUR_LICENSE_KEY

# Check license info
gmtool license info        # Returns license type, activated workstations, expiration
gmtool license count       # Number of activated workstations
gmtool license validity    # Days remaining
```

**Since Desktop 3.2.0**, `gmtool admin list`, `gmtool admin start`, and `gmtool admin stop` work **without a paid license** — a significant change for basic automation. All other admin/device commands (create, delete, clone, edit, details, device interactions) require Indie or Business license (error code 14 if attempted without).

### Global options

| Option | Short | Description |
|---|---|---|
| `--timeout <0-3600>` | `-t` | Timeout in seconds |
| `--verbose` | `-v` | Verbose output |
| `--help` | `-h` | Display help |

### Device lifecycle management

**List available hardware profiles and OS images:**
```bash
gmtool admin hwprofiles    # List all hardware profiles (Samsung Galaxy S10, Pixel 4, Custom Phone, etc.)
gmtool admin osimages      # List all available Android images (Android 5.0 through 15.0)
# Note: 'gmtool admin templates' is DEPRECATED — use hwprofiles + osimages instead
```

**Create a device:**
```bash
gmtool admin create "<hwprofile>" "<osimage>" "<device_name>" [options]

# Examples:
gmtool admin create "Samsung Galaxy S10" "Android 11.0" "MyPhone"
gmtool admin create "Custom Phone" "Android 11.0" "TestDevice" \
  --width 1440 --height 2560 --density 560 --nbcpu 4 --ram 4096

# All create options:
#   --density <value>        Screen density (120,160,213,240,260,280,300,320,340,360,400,420,440,450,480,560,640)
#   --width <value>          Screen width in pixels
#   --height <value>         Screen height in pixels
#   --virtualkeyboard <on|off>   Virtual keyboard
#   --navbar <on|off>        Android navigation bar
#   --nbcpu <value>          Number of CPU cores
#   --ram <value>            RAM in MB
#   --network-mode <nat|bridge>  Network mode (VirtualBox only)
#   --bridged-if <name>      Bridge interface (VirtualBox only)
#   --quickboot <on|off>     Quick Boot (QEMU only)
#   --root-access <on|off>   Root access (non-rooted images only)
#   --sysprop <property>:<value>  System property (MODEL, PRODUCT, MANUFACTURER, BOARD, BRAND, DEVICE, DISPLAY, SERIAL, TYPE, FINGERPRINT, TAGS)
```

**Start, stop, and manage devices:**
```bash
gmtool admin start "DeviceName"             # Start device (uses Quick Boot if available)
gmtool admin start "DeviceName" --coldboot   # Force complete boot cycle
gmtool admin stop "DeviceName"              # Stop device
gmtool admin stopall                        # Stop ALL running devices
gmtool admin list                           # List all devices
gmtool admin list --running                 # List only running devices
gmtool admin list --off                     # List only stopped devices
gmtool admin details "DeviceName"           # Show device properties (all settings, ADB serial, etc.)
```

**Clone, edit, reset, and delete:**
```bash
gmtool admin clone "SourceDevice" "NewDeviceName"    # Full clone
gmtool admin edit "DeviceName" --width 1080 --height 1920 --density 420  # Modify settings
gmtool admin edit "DeviceName" --nbcpu 2 --ram 2048  # Change resource allocation
gmtool admin factoryreset "DeviceName"               # Restore to factory state
gmtool admin delete "DeviceName"                     # Delete device permanently
```

**Log generation:**
```bash
gmtool admin logzip ~/Desktop/                    # Archive all Genymotion logs
gmtool admin logzip -n "DeviceName" ~/Desktop/    # Archive specific device logs
```

### Device interaction commands

All `gmtool device` commands accept `-n <device_name>` to target a specific device, or `--all` for all running devices. The `--start` flag auto-starts the device if not running.

```bash
gmtool device -n "DeviceName" adbconnect       # Connect device to ADB
gmtool device -n "DeviceName" adbdisconnect    # Disconnect from ADB
gmtool device -n "DeviceName" install app.apk  # Install APK
gmtool device -n "DeviceName" push local.txt /sdcard/  # Push file to device
gmtool device -n "DeviceName" pull /sdcard/file.txt ./  # Pull file from device
gmtool device -n "DeviceName" flash archive.zip         # Flash a ZIP archive
gmtool device -n "DeviceName" logcatdump ~/logcat.txt   # Dump logcat to file
gmtool device -n "DeviceName" logcatclear               # Clear logcat buffer
gmtool device --all logcatdump ~/logs/                   # Dump logcat from all devices
```

### GMTool config options (full reference)

```bash
gmtool config --email <email>
gmtool config --password <password>
gmtool config --license_server <on|off>
gmtool config --license_server_address <url>
gmtool config --statistics <on|off>
gmtool config --virtual_device_path <path>
gmtool config --use_custom_sdk <on|off>
gmtool config --sdk_path <path>
gmtool config --screen_capture_path <path>
gmtool config --proxy <on|off>
gmtool config --proxy_type <http|socks5>
gmtool config --proxy_address <url>
gmtool config --proxy_port <port>
gmtool config --proxy_auth <on|off>
gmtool config --proxy_username <username>
gmtool config --proxy_password <password>
gmtool config --trusted_hosts <host,...>
gmtool config --shared_clipboard <on|off>
gmtool config --hypervisor <virtualbox|qemu>
```

### Error codes

| Code | Message | Scripting Guidance |
|---|---|---|
| 0 | Success | Continue |
| 1 | Command does not exist | Check syntax |
| 2 | Wrong parameter value | Validate inputs |
| 3 | Command failed | Retry or investigate |
| 4 | Virtualization engine does not respond | Check hypervisor (VirtualBox/QEMU running?) |
| 5 | Virtual device not found | Verify device name/UUID |
| 6 | Unable to sign in | Check credentials |
| 7 | Unable to register license key | Verify key |
| 8 | Unable to activate license | Contact Genymotion |
| 9 | License not activated | Run `gmtool license register` |
| 10 | Invalid license key | Verify key format |
| 11 | Missing arguments | Check required params |
| 12 | Unable to stop virtual device | Force kill via hypervisor |
| 13 | Unable to start virtual device | Check resources, try cold boot |
| 14 | Requires Indie/Business license | Upgrade license |

---

## PART 3 — Genymotion Shell for sensor simulation

Genymotion Shell (`genyshell`) is a **separate tool** from GMTool, designed specifically for scripting sensor values on running devices. This is the CLI mechanism for GPS, battery, network, phone, rotation, and other simulations.

### Starting and connecting Genymotion Shell

```bash
# Location:
# Windows: C:\Program Files\Genymobile\Genymotion\genyshell.exe
# macOS: /Applications/Genymotion Shell.app/Contents/MacOS/genyshell
# Linux: ~/genymotion/genymotion-shell (or /opt/genymotion/genymotion-shell)

# Interactive mode:
genyshell

# Single command mode (for scripting):
genyshell -c "gps setlatitude 48.8566"

# Target specific device by IP:
genyshell -r 192.168.56.101 -c "battery setlevel 15"

# Run commands from file:
genyshell -f sensor_commands.txt

# Quiet mode (suppress banner, ideal for scripts):
genyshell -q -c "gps getlatitude"
```

**Shell options:**
| Option | Description |
|---|---|
| `-q` | Quiet mode — suppress banner (ideal for scripting) |
| `-h` | Display help |
| `-r <IP>` | Connect to device at specific IP |
| `-c "<command>"` | Execute single command |
| `-f <file>` | Execute commands from file |

### Device management in Shell

```bash
devices list          # List devices with ID, status, IP, name
devices refresh       # Refresh list
devices select <id>   # Select device by ID number
devices ping          # Check if selected device responds
devices factoryreset <id> [force]  # Factory reset
```

### GPS simulation

```bash
gps setstatus enabled          # Enable GPS
gps setstatus disabled         # Disable GPS
gps setlatitude 48.8566        # Range: -90 to 90
gps setlongitude 2.3522        # Range: -180 to 180
gps setaltitude 35              # Range: -10000 to 10000 (meters)
gps setaccuracy 10              # Range: 0 to 200 (meters)
gps setbearing 180.5            # Range: 0 to 359.99 (degrees)
gps getstatus                   # Get current status
gps getlatitude / getlongitude / getaltitude / getaccuracy / getbearing
```

**GPX route playback**: The GPS widget supports loading and replaying GPX files (since v3.1.0). This is currently a GUI feature — to simulate route playback via CLI, script sequential `gps setlatitude`/`gps setlongitude` commands with `pause` between them. GPX files without altitude or time information are accepted (per release notes).

### Battery simulation

```bash
battery setmode manual          # Enable manual control
battery setmode host            # Mirror host battery
battery setlevel 15             # Set charge 0-100%
battery setstatus discharging   # States: discharging, charging, notcharging, full
battery setstatus charging
battery setstatus full
battery getmode / getlevel / getstatus
```

### Network simulation (Android 8.0+)

```bash
# Enable/disable interfaces
network setstatus wifi enabled
network setstatus mobile disabled
network getstatus wifi

# Signal strength: none, poor, moderate, good, great
network setsignalstrength wifi good
network setsignalstrength mobile poor
network getsignalstrength mobile

# Mobile network profiles: none, gsm, gprs, edge, umts, hsdpa, lte, 5g
network setmobileprofile edge
network getmobileprofile
```

For Android 7.1 and below, a simpler profile system:
```bash
network setprofile wifi          # Profiles: no-data, gprs, edge, 3g, 4g, 4g-high-losses, 4g-bad-dns, wifi
network getprofile
```

### Rotation

```bash
rotation setangle 90    # Values: 0, 90, 180, 270
```

### Phone calls and SMS

```bash
phone call 5551234567              # Simulate incoming call
phone sms 5551234567 "Test msg"    # Simulate incoming SMS

# Baseband-level control:
phone baseband gsm call 5551234567     # Incoming call
phone baseband gsm accept 5551234567   # Accept outgoing call
phone baseband gsm cancel 5551234567   # Hang up
phone baseband gsm hold 5551234567     # Put on hold
phone baseband gsm busy 5551234567     # Report busy
phone baseband gsm status              # Current GSM state
phone baseband gsm voice home          # Voice state: unregistered, home, roaming, searching, denied
phone baseband gsm data home           # Data state
phone baseband gsm signal rssi 20      # Signal strength (0-31)
phone baseband sms send 5551234567 "Hello!"   # SMS via baseband
phone baseband sms pdu <hex_string>    # SMS in PDU format
```

### Disk I/O throttling

```bash
diskio setreadratelimit 1024    # Limit read to 1024 KB/sec (range: 1-2097151, 0=unlimited)
diskio getreadratelimit
diskio clearcache
```

### Device identity manipulation

```bash
android version                     # Get Android version
android getandroidid                # Get Android ID
android setandroidid random         # Generate random Android ID
android setandroidid custom A1B2C3D4E5F6G7H8  # 16 hex digits
android getdeviceid                 # Get IMEI/MEID
android setdeviceid random / none / custom <value>
```

### Genymotion info commands

```bash
genymotion capabilities  # Returns JSON: {"accelerometer":true,"battery":true,"gps":true,...}
genymotion version       # Genymotion version
genymotion license       # License info
genymotion clearcache    # Clear temp files
```

---

## PART 4 — ADB commands in the Genymotion context

### Connecting and identifying devices

```bash
# Auto-connect (GMTool)
gmtool device -n "DeviceName" adbconnect

# Manual connect
adb connect 192.168.56.101:5555

# List all connected devices
adb devices -l
# Output: 192.168.56.101:5555  device product:vbox86p model:Custom_Phone device:generic

# Target a specific device for all subsequent commands
export ANDROID_SERIAL=192.168.56.101:5555
# Or use -s flag per command:
adb -s 192.168.56.101:5555 shell ...
```

### APK installation and app lifecycle

```bash
# Install APK (auto-selects ABI)
adb install app-debug.apk
adb install -t app-debug-androidTest.apk    # Test APK (requires -t flag)
adb install -r app-debug.apk                # Replace existing
adb install -d app-debug.apk                # Allow version downgrade

# Package management
adb shell pm list packages | grep com.example
adb shell pm clear com.example.app           # Clear all app data
adb shell pm uninstall com.example.app
adb shell pm grant com.example.app android.permission.ACCESS_FINE_LOCATION

# Activity lifecycle
adb shell am start -n com.example.app/.MainActivity
adb shell am start -n com.example.app/.DetailActivity --es "item_id" "123"
adb shell am force-stop com.example.app
adb shell am broadcast -a com.example.CUSTOM_ACTION
```

### Disable animations (essential for test stability)

```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

### Screen capture and recording

```bash
# Screenshot
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png ./screenshots/

# Screen recording (max 180 seconds default, max 86400 seconds / 24 hours)
adb shell screenrecord /sdcard/recording.mp4
adb shell screenrecord --time-limit 60 --size 720x1280 /sdcard/recording.mp4
# Stop with Ctrl+C, then pull:
adb pull /sdcard/recording.mp4
```

### Logcat strategies

```bash
adb logcat -c                                    # Clear buffer before test
adb logcat -d > logcat.txt                       # Dump and exit
adb logcat -v threadtime > logcat.txt &          # Background continuous capture
adb logcat -s "MyApp:D" "AndroidRuntime:E"       # Filter by tags
adb logcat *:E                                   # Errors only
adb logcat --pid=$(adb shell pidof com.example.app)  # Filter by app PID

# GMTool shortcut:
gmtool device -n "DeviceName" logcatdump ~/logcat.txt
gmtool device -n "DeviceName" logcatclear
```

### Port forwarding

```bash
adb forward tcp:9999 tcp:5000      # Host:9999 → Device:5000
adb reverse tcp:8080 tcp:8080      # Device:8080 → Host:8080 (for mock servers)
```

### Instrumentation (running tests via ADB)

```bash
# Run all tests
adb shell am instrument -w com.example.test/androidx.test.runner.AndroidJUnitRunner

# Specific test class
adb shell am instrument -w -e class com.example.test.LoginTest \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# Specific method
adb shell am instrument -w -e class com.example.test.LoginTest#testValidLogin \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# Test sharding (for distributing across devices)
adb -s 192.168.56.101:5555 shell am instrument -w \
  -e numShards 3 -e shardIndex 0 \
  com.example.test/androidx.test.runner.AndroidJUnitRunner

# By annotation size
adb shell am instrument -w -e size large \
  com.example.test/androidx.test.runner.AndroidJUnitRunner
```

### System inspection

```bash
adb shell getprop sys.boot_completed           # "1" when fully booted
adb shell getprop init.svc.bootanim            # "stopped" when boot animation done
adb shell getprop ro.product.cpu.abilist       # Supported ABIs
adb shell getprop ro.build.version.sdk         # API level
adb shell dumpsys activity | grep mCurrentFocus  # Current foreground activity
adb shell dumpsys battery                       # Battery state
adb shell dumpsys meminfo com.example.app       # Memory usage
adb shell input tap 500 1000                    # Tap at coordinates
adb shell input text "hello"                    # Type text
adb shell input keyevent KEYCODE_HOME           # Press Home
adb shell input keyevent 82                     # Menu / unlock
```

---

## PART 5 — Test framework integration for Kotlin and Jetpack Compose

### Espresso and Compose UI tests via CLI

Both Espresso and Compose UI tests are **instrumented tests** that run identically via Gradle. For Kotlin + Jetpack Compose, the test dependencies in `build.gradle.kts`:

```kotlin
dependencies {
    // Espresso
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.test:runner:1.6.1")
    androidTestImplementation("androidx.test:rules:1.6.1")
    
    // Compose Testing
    androidTestImplementation("androidx.compose.ui:ui-test-junit4:$compose_version")
    debugImplementation("androidx.compose.ui:ui-test-manifest:$compose_version")
}

android {
    defaultConfig {
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
}
```

Running against Genymotion (device must be ADB-connected):
```bash
./gradlew connectedDebugAndroidTest

# Specific test class
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.ui.ComposeLoginTest

# Test sharding across multiple Genymotion instances
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.numShards=3 \
  -Pandroid.testInstrumentationRunnerArguments.shardIndex=0
```

**Compose-specific testing considerations on Genymotion**: Compose rendering uses **Skia**, which is architecture-independent. The Compose **semantics tree** (used for testing with `testTag`, `onNodeWithText`, `onNodeWithContentDescription`) is completely independent of the rendering backend. Tests using `createComposeRule()` or `createAndroidComposeRule<Activity>()` behave identically on Genymotion x86, ARM physical devices, and Android Studio AVDs. There are no known Compose-specific rendering or behavioral differences on Genymotion.

Test results are at:
- HTML: `app/build/reports/androidTests/connected/index.html`
- JUnit XML: `app/build/outputs/androidTest-results/connected/`

### Genymotion Java API for sensor control from tests

Genymotion provides a **Java API** that enables sensor manipulation directly from instrumented tests — a powerful alternative to Genymotion Shell for test-integrated sensor simulation:

```kotlin
// build.gradle.kts
repositories {
    maven { url = uri("http://api.genymotion.com/repositories/releases/") }
}
dependencies {
    androidTestImplementation("com.genymotion:genymotion-api:1.0.0")
}
```

```kotlin
// In test code:
import com.genymotion.api.GenymotionManager

@Test
fun testLowBatteryWarning() {
    GenymotionManager.getDevice().battery.setLevel(5)
    GenymotionManager.getDevice().battery.setStatus(BatteryStatus.DISCHARGING)
    // Assert app shows warning
}

@Test
fun testLocationFeature() {
    GenymotionManager.getDevice().gps.setLatitude(48.8566)
    GenymotionManager.getDevice().gps.setLongitude(2.3522)
    // Assert app shows Paris location
}
```

### UI Automator

Works identically to real devices since Genymotion exposes a standard ADB interface. API 21+ required (API 26+ for UiAutomator2 driver v6.0+).

```bash
# Dependencies: androidx.test.uiautomator:uiautomator:2.3.0
./gradlew connectedAndroidTest
# Hierarchy dump:
adb shell uiautomator dump /sdcard/ui_dump.xml && adb pull /sdcard/ui_dump.xml
```

### Appium

```json
{
  "platformName": "Android",
  "appium:automationName": "UiAutomator2",
  "appium:deviceName": "Genymotion",
  "appium:platformVersion": "13",
  "appium:udid": "192.168.56.101:5555",
  "appium:app": "/path/to/app.apk",
  "appium:autoGrantPermissions": true
}
```

For parallel testing, use different `udid` per session. **The `--avd` flag does NOT work with Genymotion** — always start devices via gmtool first, then connect via `udid`.

### Maestro

Maestro uses ADB under the hood and works seamlessly with Genymotion. It natively supports Jetpack Compose elements via accessibility/semantics.

```bash
curl -Ls https://get.maestro.mobile.dev | bash
adb install app.apk
maestro test flow.yaml
maestro test --format junit flows/ --output report.xml
```

### Genymotion Gradle Plugin

The official plugin (`com.genymotion:plugin:1.4`) wraps gmtool for automated device lifecycle during `connectedAndroidTest`:

```groovy
buildscript {
    dependencies { classpath 'com.genymotion:plugin:1.4' }
}
apply plugin: 'genymotion'

genymotion {
    config {
        genymotionPath = "/opt/genymotion/"
        taskLaunch = "connectedAndroidTest"
    }
    devices {
        pixel3 {
            template "Google Pixel 3 - 10.0 - API 29 - 1080x2160"
            deleteWhenFinish false   // Preserve device between runs
        }
    }
}
```

**Important**: This plugin (v1.4, last published 2017) may have compatibility issues with the latest AGP versions. For modern projects, scripting with gmtool directly is often more reliable.

---

## PART 6 — CI/CD integration patterns

### The fundamental constraint

**Genymotion Desktop has no headless mode.** The official FAQ confirms: "Genymotion Desktop requires full GPU acceleration and a GUI to render the device display." It cannot run on servers, VMs, VPS, or cloud instances. Genymotion's own support documentation states Desktop is "not optimal for automation tests." For CI/CD, Genymotion recommends their SaaS/Cloud product instead.

Despite this, three workarounds exist for CI with Desktop:

**Workaround 1: Self-hosted CI runner with GPU and display** — The supported approach. Requires bare-metal machine with GPU, X server, and Genymotion Desktop installed. Set `DISPLAY=:0` environment variable.

**Workaround 2: VBoxManage headless** (community, unsupported) — Bypass Genymotion's player entirely and start VMs headlessly through VirtualBox:
```bash
VBoxManage startvm <VM-UUID> --type headless
IP=$(VBoxManage guestproperty get <VM-UUID> androvm_ip_management | grep -oP '[\d]+\.[\d]+\.[\d]+\.[\d]+')
adb connect ${IP}:5555
```

**Workaround 3: Genymotion SaaS via gmsaas** — The recommended path for any runner:
```bash
pip install gmsaas
gmsaas auth token $API_TOKEN
UUID=$(gmsaas instances start <RECIPE_UUID> "test-device")
gmsaas instances adbconnect $UUID
# Run tests...
gmsaas instances stop $UUID
```

### License management in CI

```bash
# Activate license (per-machine; each CI agent consumes one activation)
gmtool config --email "$GENY_EMAIL" --password "$GENY_PASSWORD"
gmtool license register "$GENY_LICENSE_KEY"
# Verify
gmtool license validity   # Returns days remaining
```

Store credentials as CI secrets. License is per-machine — ephemeral CI environments will consume activations.

### GitHub Actions

**Desktop** requires self-hosted runners (GitHub-hosted runners lack VirtualBox, GPU, and Genymotion):
```yaml
name: Tests (Genymotion Desktop)
on: [push]
jobs:
  test:
    runs-on: [self-hosted, linux, genymotion]
    timeout-minutes: 30
    env:
      GMTOOL: /opt/genymotion/gmtool
      DEVICE: ci-${{ github.run_id }}
      DISPLAY: ":0"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '17', distribution: 'temurin' }
      - name: Setup
        run: |
          $GMTOOL config --email "${{ secrets.GENY_EMAIL }}" --password "${{ secrets.GENY_PASSWORD }}"
          $GMTOOL license register "${{ secrets.GENY_LICENSE }}" || true
          $GMTOOL admin create "Samsung Galaxy S10" "Android 11.0" "$DEVICE" --nbcpu 4 --ram 4096
          $GMTOOL --timeout 300 admin start "$DEVICE"
          $GMTOOL device -n "$DEVICE" adbconnect
          for i in $(seq 1 60); do
            [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
            sleep 5
          done
          adb shell settings put global window_animation_scale 0
          adb shell settings put global transition_animation_scale 0
          adb shell settings put global animator_duration_scale 0
      - run: ./gradlew connectedDebugAndroidTest
      - if: always()
        run: |
          $GMTOOL device -n "$DEVICE" logcatdump logcat.txt || true
          $GMTOOL admin stop "$DEVICE" || true
          $GMTOOL admin delete "$DEVICE" || true
```

**SaaS** works on any runner using the official GitHub Action:
```yaml
- uses: genymobile/genymotion-saas-github-action@v1
  with:
    api_token: ${{ secrets.GMSAAS_APITOKEN }}
    recipe_uuid: ea5fda48-fa8b-48c1-8acc-07d910856141
```

### GitLab CI (self-hosted runner with GPU)

```yaml
android-test:
  tags: [genymotion, gpu]
  variables:
    GMTOOL: /opt/genymotion/gmtool
    DISPLAY: ":0"
  before_script:
    - $GMTOOL config --email "$GENY_EMAIL" --password "$GENY_PASSWORD"
    - $GMTOOL license register "$GENY_LICENSE_KEY" || true
  script:
    - DEVICE="ci-${CI_JOB_ID}"
    - $GMTOOL admin create "Samsung Galaxy S10" "Android 11.0" "$DEVICE" --nbcpu 4 --ram 4096
    - $GMTOOL --timeout 300 admin start "$DEVICE"
    - $GMTOOL device -n "$DEVICE" adbconnect
    - |
      for i in $(seq 1 60); do
        [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
        sleep 5
      done
    - ./gradlew connectedDebugAndroidTest
  after_script:
    - $GMTOOL admin stop "ci-${CI_JOB_ID}" || true
    - $GMTOOL admin delete "ci-${CI_JOB_ID}" || true
  artifacts:
    when: always
    paths: [app/build/reports/]
```

---

## PART 7 — Complete workflow recipe scripts

### Recipe 1: single device test run

```bash
#!/usr/bin/env bash
set -euo pipefail

GMTOOL="${GENYMOTION_PATH:-/opt/genymotion}/gmtool"
GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
DEVICE="test-$$"
HW_PROFILE="${HW_PROFILE:-Samsung Galaxy S10}"
OS_IMAGE="${OS_IMAGE:-Android 11.0}"
BOOT_TIMEOUT=120

cleanup() {
    echo "==> Cleanup..."
    "$GMTOOL" device -n "$DEVICE" logcatdump "logcat-${DEVICE}.txt" 2>/dev/null || true
    "$GMTOOL" admin stop "$DEVICE" 2>/dev/null || true
    "$GMTOOL" admin delete "$DEVICE" 2>/dev/null || true
}
trap cleanup EXIT

# Create and start
"$GMTOOL" admin create "$HW_PROFILE" "$OS_IMAGE" "$DEVICE" --nbcpu 4 --ram 4096
"$GMTOOL" --timeout 300 admin start "$DEVICE"
"$GMTOOL" device -n "$DEVICE" adbconnect

# Wait for boot
elapsed=0
while [ $elapsed -lt $BOOT_TIMEOUT ]; do
    bc=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
    [ "$bc" = "1" ] && break
    sleep 5; elapsed=$((elapsed + 5))
done
[ "$bc" != "1" ] && echo "ERROR: Boot timeout" && exit 1

# Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Install and test
"$GMTOOL" device -n "$DEVICE" install app-debug.apk
adb install -t app-debug-androidTest.apk
./gradlew connectedDebugAndroidTest
TEST_RESULT=$?

# Screenshot on failure
if [ $TEST_RESULT -ne 0 ]; then
    adb shell screencap /sdcard/failure.png
    adb pull /sdcard/failure.png ./
fi
exit $TEST_RESULT
```

### Recipe 2: multi-device parallel testing with sharding

```bash
#!/usr/bin/env bash
set -euo pipefail

GMTOOL="${GENYMOTION_PATH:-/opt/genymotion}/gmtool"
NUM_SHARDS=3
DEVICES=()
PIDS=()

CONFIGS=(
    "Samsung Galaxy S10|Android 11.0"
    "Custom Phone|Android 13.0"
    "Google Pixel 4|Android 12.0"
)

cleanup() {
    for d in "${DEVICES[@]}"; do
        "$GMTOOL" admin stop "$d" 2>/dev/null || true
        "$GMTOOL" admin delete "$d" 2>/dev/null || true
    done
}
trap cleanup EXIT

# Create and start all devices
for i in "${!CONFIGS[@]}"; do
    IFS='|' read -r hw os <<< "${CONFIGS[$i]}"
    name="shard-${i}-$$"
    DEVICES+=("$name")
    "$GMTOOL" admin create "$hw" "$os" "$name" --nbcpu 2 --ram 2048
    "$GMTOOL" --timeout 300 admin start "$name"
    "$GMTOOL" device -n "$name" adbconnect
done

# Wait for all to boot
for d in "${DEVICES[@]}"; do
    for j in $(seq 1 60); do
        [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
        sleep 5
    done
done

# Install APK on all devices
for d in "${DEVICES[@]}"; do
    "$GMTOOL" device -n "$d" install app-debug.apk
done

# Run sharded tests in parallel
for i in "${!DEVICES[@]}"; do
    SERIAL=$(adb devices | grep "device$" | sed -n "$((i+1))p" | awk '{print $1}')
    ANDROID_SERIAL=$SERIAL ./gradlew connectedDebugAndroidTest \
        -Pandroid.testInstrumentationRunnerArguments.numShards=$NUM_SHARDS \
        -Pandroid.testInstrumentationRunnerArguments.shardIndex=$i \
        2>&1 | tee "results-shard-${i}.log" &
    PIDS+=($!)
done

# Wait and collect results
OVERALL=0
for pid in "${PIDS[@]}"; do
    wait "$pid" || OVERALL=1
done
exit $OVERALL
```

### Recipe 3: sensor simulation testing

```bash
#!/usr/bin/env bash
set -euo pipefail

GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"

# GPS coordinate sequence
GPS_COORDS=(
    "48.8566|2.3522"     # Paris
    "40.7128|-74.0060"   # New York
    "35.6762|139.6503"   # Tokyo
)

for coord in "${GPS_COORDS[@]}"; do
    IFS='|' read -r lat lon <<< "$coord"
    "$GENYSHELL" -q -c "gps setstatus enabled"
    "$GENYSHELL" -q -c "gps setlatitude $lat"
    "$GENYSHELL" -q -c "gps setlongitude $lon"
    sleep 3  # Allow app to respond
    adb shell screencap /sdcard/gps_${lat}_${lon}.png
    adb pull /sdcard/gps_${lat}_${lon}.png ./screenshots/
done

# Battery state testing
for level in 100 50 15 5 1; do
    "$GENYSHELL" -q -c "battery setmode manual"
    "$GENYSHELL" -q -c "battery setlevel $level"
    "$GENYSHELL" -q -c "battery setstatus discharging"
    sleep 2
    adb shell screencap /sdcard/battery_${level}.png
    adb pull /sdcard/battery_${level}.png ./screenshots/
done

# Orientation testing
for angle in 0 90 180 270; do
    "$GENYSHELL" -q -c "rotation setangle $angle"
    sleep 2
    adb shell screencap /sdcard/rotation_${angle}.png
    adb pull /sdcard/rotation_${angle}.png ./screenshots/
done
```

### Recipe 4: network condition testing

```bash
#!/usr/bin/env bash
set -euo pipefail

GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
RESULTS_DIR="./network-results"
mkdir -p "$RESULTS_DIR"

# Network profiles to test (Android 8.0+ syntax)
declare -A PROFILES=(
    ["wifi_good"]="wifi|enabled|good"
    ["mobile_4g"]="mobile|enabled|great"
    ["mobile_edge"]="mobile|enabled|poor"
    ["offline"]="wifi|disabled|none"
)

for profile_name in "${!PROFILES[@]}"; do
    IFS='|' read -r iface status strength <<< "${PROFILES[$profile_name]}"
    echo "==> Testing profile: $profile_name"
    
    "$GENYSHELL" -q -c "network setstatus $iface $status"
    [ "$status" = "enabled" ] && "$GENYSHELL" -q -c "network setsignalstrength $iface $strength"
    
    if [ "$iface" = "mobile" ] && [ "$status" = "enabled" ]; then
        "$GENYSHELL" -q -c "network setmobileprofile edge"
    fi
    
    sleep 3  # Allow network change to propagate
    
    # Run connectivity-dependent tests
    ./gradlew connectedDebugAndroidTest \
        -Pandroid.testInstrumentationRunnerArguments.annotation=com.example.test.NetworkTest \
        2>&1 | tee "$RESULTS_DIR/${profile_name}.log"
    
    # Capture state
    adb shell screencap /sdcard/net_${profile_name}.png
    adb pull /sdcard/net_${profile_name}.png "$RESULTS_DIR/"
done

# Restore normal connectivity
"$GENYSHELL" -q -c "network setstatus wifi enabled"
"$GENYSHELL" -q -c "network setsignalstrength wifi great"
```

---

## PART 8 — Decision framework: when to use Genymotion

### Genymotion Desktop vs Android Studio Emulator

| Criterion | Genymotion Desktop | Android Studio AVD |
|---|---|---|
| **Speed** | Fast x86 virtualization | Comparable or faster post-2018 |
| **API coverage** | Android 5.0–15.0 | All API levels including latest |
| **Headless mode** | ❌ Not supported | ✅ `-no-window` flag |
| **Docker support** | ❌ Impractical | ✅ Multiple Docker images |
| **Cost** | ~$136+/year (Indie) | Free |
| **CLI tools** | GMTool + Genymotion Shell | `emulator` + `avdmanager` + Gradle Managed Devices |
| **Sensor simulation** | Rich (GPS, battery, network, phone, identity, disk I/O) via Shell | Extended Controls (comparable) |
| **ARM emulation** | x86 only (ARM via unsupported libhoudini); arm64 on Apple Silicon | Native ARM emulation (slow but accurate) |
| **Snapshot support** | Quick Boot (QEMU only); VBoxManage snapshots (unofficial) | Full save/load state support |
| **Google Play** | Via Open GApps widget or manual flash | Built-in "Google APIs" images |
| **Multi-instance** | Not designed for parallel (degrades rapidly) | Designed for multi-instance |
| **Gradle integration** | Plugin (v1.4, outdated) | Gradle Managed Devices (modern, first-party) |

### When Genymotion Desktop is the right choice

- **Local development on Mac (especially Apple Silicon)** for native arm64 Android images
- **Rich sensor simulation workflows** that benefit from Genymotion Shell's scripting capabilities
- **Teams already invested** in the Genymotion ecosystem
- **Quick prototyping** with the device link feature (forward real phone sensors)

### When to use alternatives instead

- **Any CI/CD pipeline** → Use Android Studio AVD (`-no-window`) or Genymotion SaaS
- **Budget-constrained teams** → Use free AVD
- **Parallel test execution at scale** → Use Genymotion SaaS, Firebase Test Lab, or AVD
- **Accurate ARM behavior testing on x86 hosts** → AVD with ARM images or physical devices
- **SafetyNet/Play Integrity testing** → Physical devices only

### Device matrix strategy for maximum coverage

For Kotlin + Jetpack Compose applications, target the **latest 3–4 Android versions** covering 90%+ of your user base. Compose requires API 21+ minimum but practically works best on API 26+.

Recommended minimal matrix (**8 configurations**):

- **Android 12 (API 31)** — 1080×2400, 420dpi — mid-range phone
- **Android 13 (API 33)** — 1440×3200, 560dpi — flagship phone
- **Android 14 (API 34)** — 1080×1920, 320dpi — compact phone
- **Android 15 (API 35)** — 2560×1600, 320dpi — tablet
- Run full matrix nightly; top 2 configs on every PR

---

## PART 9 — Anti-patterns, pitfalls, and reliability killers

### Race conditions in automation scripts

The **most common scripting bug** is running commands against a device that hasn't finished booting. Always implement a boot-wait loop:

```bash
wait_for_boot() {
    local timeout=${1:-120}
    local elapsed=0
    adb wait-for-device
    while [ $elapsed -lt $timeout ]; do
        local bc=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
        local ba=$(adb shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")
        if [ "$bc" = "1" ] && [ "$ba" = "stopped" ]; then
            adb shell input keyevent 82   # Dismiss keyguard
            sleep 2
            # Verify package manager is ready
            adb shell pm list packages 2>/dev/null | head -1 | grep -q "package:" && return 0
        fi
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}
```

### ADB instability patterns

ADB connections to Genymotion can drop when the ADB server restarts (version mismatch), when the host-only network adapter reconfigures, or during VPN state changes. **Automated recovery pattern**:

```bash
ensure_adb_connection() {
    local device="$1"  # e.g., 192.168.56.101:5555
    if ! adb -s "$device" shell echo "ok" 2>/dev/null | grep -q "ok"; then
        adb connect "$device"
        sleep 3
        adb -s "$device" wait-for-device
    fi
}
```

### Memory leaks during extended runs

This is officially documented as unfixable. For test suites running longer than a few hours, implement periodic device recycling:

```bash
# After every N test suites, restart the device
gmtool admin stop "$DEVICE"
sleep 5
gmtool admin start "$DEVICE"
# Re-wait for boot...
```

### Test flakiness sources and mitigations

- **Animations**: Always disable all three animation scales before testing
- **Google Play Services auto-updates**: Can change behavior mid-test. Disable auto-updates in CI: `adb shell pm disable-user com.android.vending`
- **Sensor state leakage**: Reset GPS, battery, network between test suites via Genymotion Shell
- **ARM translation non-determinism**: Build x86 APKs for testing; avoid ARM translation entirely
- **Quick Boot corruption**: Use `--coldboot` flag for CI; Quick Boot state can become invalid after crashes
- **VirtualBox version conflicts**: Pin VirtualBox version; avoid independent upgrades
- **Intel iGPU on Windows**: Known rendering issues; lower OpenGL ES to 2.0/3.0 or use Linux

### Things Genymotion cannot accurately simulate

Bluetooth, NFC, real camera hardware, actual fingerprint sensors (biometric widget is UI-only), real thermal behavior, true cellular radio behavior, SafetyNet/Play Integrity attestation (detects emulator), Widevine L1 DRM. Test these on physical devices.

### Snapshot strategy tradeoffs

Genymotion Desktop does not expose snapshot commands in GMTool. Quick Boot (QEMU) provides a single resume-state snapshot. For full snapshot management with VirtualBox, use VBoxManage directly (unofficial):

```bash
VBoxManage snapshot "VM-Name" take "clean-state"
VBoxManage snapshot "VM-Name" restore "clean-state"
```

Each snapshot consumes **2–8GB** of disk. Budget ~50–100GB for a snapshot library. Snapshots become stale as OS and app versions change — refresh baselines weekly.

### The `gmtool` single-user limitation

From official docs: "If you have different users on your machine, only use GMTool for one user. It is a current limitation." In multi-user CI environments, this requires isolation (separate machines or containers per user).

---

## PART 10 — Key community intelligence and field lessons

### The migration trend

The clear community trend since 2018 is **migration away from Genymotion Desktop toward Android Studio AVD** for CI/CD. PSPDFKit's detailed migration blog (2019) documented their switch: motivations included license costs, no headless mode requiring expensive macOS machines, maintenance burden, and the dramatic improvement in AVD quality after Google's Project Marble. Multiple prominent engineering blogs echo this assessment.

However, **Genymotion Cloud/SaaS remains competitive** for teams wanting managed, scalable cloud infrastructure for mobile testing without maintaining their own device farms.

### Key undocumented tips from the community

- **Since Desktop 3.2.0**, basic gmtool commands (`list`, `start`, `stop`) work without a paid license — enabling basic tooling integration even on the free tier
- The `genyshell -q` flag (quiet mode) suppresses the banner and makes output machine-parseable — essential for scripting but rarely mentioned in guides
- The `player --vm-name "Device Name"` command launches the Genymotion player directly for a specific VM — useful when gmtool's start command fails
- `QT_QUICK_BACKEND` environment variable can reduce CPU usage of Genymotion's own UI
- `gmtool --timeout 300` is essential for `admin start` on slow machines — the default timeout causes premature failures
- The Gradle plugin's `processTimeout` setting (`genymotion.config.processTimeout`) should be increased for slow CI machines
- VirtualBox snapshots work reliably despite being unsupported: `VBoxManage snapshot $VM take snap1 && VBoxManage snapshot $VM restore snap1`

### Real performance expectations

Community-reported boot times: **30–90 seconds** cold boot (varies by Android version and host hardware), **2–5 seconds** with Quick Boot. Test execution speed is comparable to AVD when both use x86 images with hardware acceleration. RAM usage per instance is **1.5–3GB** depending on Android version and installed apps.

---

## Conclusion

Genymotion Desktop provides a capable but constrained CLI toolkit for Android test automation. **The three-tool architecture — GMTool for device lifecycle, Genymotion Shell for sensor simulation, and ADB for everything else — covers most automation needs** when used on a developer workstation. The sensor simulation capabilities via Genymotion Shell are genuinely powerful for systematic GPS, battery, and network testing of Kotlin/Compose applications.

The critical limitation is the **absence of headless mode**, which makes Desktop fundamentally unsuitable for conventional CI/CD pipelines without expensive self-hosted GPU runners. For teams choosing Genymotion Desktop, the optimal pattern is **local development and pre-push testing** on developer machines, with either Genymotion SaaS or Android Studio AVD handling CI/CD. The Gradle Managed Devices feature in modern AGP has largely absorbed the niche that the Genymotion Gradle Plugin once filled.

For the AI coding agent skill, the key decision logic is: use Genymotion Desktop when the developer needs rich sensor simulation, has a GUI-capable machine, and is doing interactive development; switch to `emulator -no-window` with AVD or `gmsaas` for anything headless or CI-bound. Always build x86 APKs for Genymotion testing, always disable animations, always implement boot-wait loops with timeout, and always use the same ADB version across all tools.