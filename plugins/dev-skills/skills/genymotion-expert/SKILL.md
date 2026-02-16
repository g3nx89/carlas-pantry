---
name: genymotion-expert
description: This skill should be used when the user asks to "set up Genymotion emulator", "create a Genymotion device", "run tests on Genymotion", "simulate sensors (GPS, battery, network, motion, biometrics) on emulator", "use gmtool commands", "use genyshell commands", "configure Genymotion for CI", "run Espresso or Compose UI tests on Genymotion", "debug ADB connection issues with Genymotion", "set up parallel testing with Genymotion", "test camera or media injection on Genymotion", "simulate fingerprint on Genymotion", "use gamepad with Genymotion", "forward physical device sensors to emulator", "use Device Link for touch forwarding or screen mirroring", "check genymotion capabilities", "install Google Play Services on Genymotion", "install GApps on emulator", "Google Play Store missing on Genymotion", or mentions Genymotion Desktop, GMTool, or Genymotion Shell in an Android testing context.
version: 1.5.0
allowed-tools: Read, Glob, Grep, Bash
---

# Genymotion Desktop Expert

CLI-driven Android emulation and test automation with Genymotion Desktop. Covers GMTool device lifecycle, Genymotion Shell sensor simulation, emulated features (GPS, battery, network, motion sensors, biometrics, camera injection, gamepad, disk I/O, phone/SMS, device identity), and ADB integration for Kotlin/Jetpack Compose projects.

## When to Use

- Creating, starting, or managing Genymotion virtual devices via CLI
- Running instrumented tests (Espresso, Compose UI, Maestro) against Genymotion
- Simulating sensors: GPS, battery, network, rotation, phone calls, motion sensors, biometrics
- Configuring camera/media injection, gamepad support, Device Link (touch forwarding, screen mirroring, sensor forwarding)
- Automating device setup for local development or self-hosted CI
- Troubleshooting ADB connections, boot failures, or test flakiness on Genymotion
- Choosing between Genymotion Desktop, AVD, or Genymotion SaaS

## When NOT to Use

- **Shared Compose UI patterns** → Use `compose-expert` skill
- **Gradle build configuration** → Use `gradle-expert` skill
- **Android navigation/permissions** → Use `android-expert` skill
- **Kotlin coroutines/flows** → Use `kotlin-coroutines` skill

## Architecture Overview

Genymotion Desktop provides **three CLI tools** for terminal-driven Android automation:

| Tool | Purpose | Key Use |
|------|---------|---------|
| **GMTool** (`gmtool`) | Device lifecycle management | Create, start, stop, delete devices; install APKs |
| **Genymotion Shell** (`genyshell`) | Sensor simulation on running devices | GPS, battery, network, rotation, phone calls |
| **ADB** | Standard Android Debug Bridge | App install, test execution, logcat, screen capture |

### Hypervisor Layer

| Platform | Default Hypervisor | Notes |
|----------|-------------------|-------|
| Linux | QEMU (KVM) | Bundled since v3.3.0 |
| macOS Intel | QEMU (Hypervisor.framework) | VirtualBox deprecated |
| macOS Apple Silicon | QEMU | arm64 Android images; slower than Linux KVM |
| Windows | VirtualBox | QEMU experimental, requires Hyper-V |

**Apple Silicon caveat**: QEMU on M-series Macs lacks hardware-assisted nested virtualization (no KVM equivalent on macOS). Expect slower cold boots and higher CPU usage compared to Intel hosts or Linux KVM. Not all Android versions have arm64 images — verify with `gmtool admin osimages`. This support matured in v3.3+; earlier versions may have incomplete arm64 coverage.

**VirtualBox and Hyper-V are mutually exclusive on Windows.** VirtualBox crashes with Hyper-V enabled, but QEMU on Windows *requires* Hyper-V. This creates conflicts for developers also using WSL2 or Docker Desktop. Switch hypervisors with `gmtool config --hypervisor qemu|virtualbox`.

**Quick Boot** (QEMU only): saves VM state on shutdown, resumes in ~2-5s. Without Quick Boot, cold boot takes ~20-30s on modern hardware with GPU acceleration (longer on Apple Silicon or without GPU). GPU/3D acceleration is required for acceptable performance — software rendering (e.g., via Xvfb) degrades frame rates significantly. Disable per-device with `gmtool admin edit "DeviceName" --quickboot off`. Use `--coldboot` at start time to force full boot cycle when state is corrupted.

### ABI Support

| ABI | Mac M-series (ARM) | PC/Mac Intel (x86) |
|-----|--------------------|--------------------|
| arm64-v8a | Native | Not supported |
| x86_64 | Not supported | Android 11+ |
| x86 | Not supported | Android 5-10 |

**Best practice**: Build APKs with x86/x86_64 ABI included. On Apple Silicon, arm64-v8a runs natively. ARM translation (libhoudini) is unsupported and fragile — avoid unless absolutely necessary. If forced to use it: flash the version-matched ZIP *before* GApps, reboot, and verify with `adb shell getprop ro.product.cpu.abilist`. Missing x86 ABI causes `INSTALL_FAILED_NO_MATCHING_ABIS` — see `references/cli-reference.md` for the full installation procedure.

## Essential Workflows

### Device Lifecycle (GMTool)

```bash
# Create device
gmtool admin create "Samsung Galaxy S10" "Android 11.0" "TestDevice" \
  --nbcpu 4 --ram 4096

# Start with timeout (essential on slow machines)
gmtool --timeout 300 admin start "TestDevice"

# Connect to ADB
gmtool device -n "TestDevice" adbconnect

# Wait for boot completion (see Boot Wait Pattern in Quick Reference below)
wait_for_boot 120

# Disable animations (critical for test stability)
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

### Sensor Simulation (Genymotion Shell)

Use `genyshell -q -c` for scripting (quiet mode suppresses banner):

```bash
# GPS
genyshell -q -c "gps setstatus enabled"
genyshell -q -c "gps setlatitude 48.8566"
genyshell -q -c "gps setlongitude 2.3522"

# Battery
genyshell -q -c "battery setmode manual"
genyshell -q -c "battery setlevel 15"
genyshell -q -c "battery setstatus discharging"

# Network (Android 8.0+)
genyshell -q -c "network setstatus wifi enabled"
genyshell -q -c "network setsignalstrength wifi good"

# Rotation
genyshell -q -c "rotation setangle 90"

# Disk I/O (simulate low-end device at 50 MiB/s)
genyshell -q -c "diskio setreadratelimit 51200"

# Phone/SMS
genyshell -q -c 'phone sms "+15551234567" "OTP: 847291"'
```

Target a specific device by IP: `genyshell -r 192.168.56.101 -c "..."`.

**GUI-only features** (v3.6.0+): Biometrics (fingerprint scenarios), Camera/Media Injection, Motion Sensors (accelerometer/gyroscope/magnetometer via yaw/pitch/roll sliders), Device Link (sensor forwarding, touch forwarding, screen mirroring), and Gamepad are configurable only through the Genymotion Desktop UI. See `references/emulated-features/gui-features.md` for full details, testing patterns, and ADB automation alternatives. **When a GUI-only task cannot use ADB alternatives**, load `references/emulated-features/gui-walkthroughs.md` and relay the step-by-step instructions to the user.

**Feature detection**: Use `genyshell -q -c "genymotion capabilities"` to query available features as JSON. Useful in CI to gate tests when a feature requires a paid license.

### Running Tests

```bash
# Gradle (standard)
./gradlew connectedDebugAndroidTest

# Specific test class
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.ui.LoginTest

# Via ADB instrumentation
adb shell am instrument -w \
  com.example.test/androidx.test.runner.AndroidJUnitRunner
```

Compose UI tests behave identically on Genymotion — the semantics tree is architecture-independent. For in-test sensor control (GPS, battery from Kotlin test code), the Genymotion Java API is available — see `references/test-integration.md`.

## Network Stack

Genymotion uses NAT mode by default. The special address **`10.0.3.2`** reaches the host from inside the device (unlike AVD's `10.0.2.2`). Use `adb reverse tcp:8080 tcp:8080` so the device can reach host services via `localhost:8080`. Bridge mode (VM gets own LAN IP) is VirtualBox-only: `--network-mode bridge --bridged-if eth0`. See `references/cli-reference.md` for port forwarding, proxy interception, and bridge mode ADB caveats.

**VPN interference**: Host VPN can block routing to the `192.168.56.x` subnet. Split-tunneling or disabling VPN during tests may be required.

**Security**: ADB over TCP (port 5555) is unauthenticated. On shared or untrusted networks, restrict the host-only adapter with firewall rules or use NAT mode exclusively. See `references/cli-reference.md` for bridged mode security implications.

## Critical Configuration

### Google Play Services

**Not installed by default.** Genymotion ships AOSP images without Google proprietary software. Apps using Maps, Firebase, Google Sign-In, or In-App Billing require Google Play Services. Install via the Open GApps toolbar widget (free, no license needed, Android 4.4+) or via `gmtool device flash`. See `references/emulated-features/controls-and-tools.md` for the full installation guide, CLI commands, and caveats.

### ADB Version Alignment

**Always** configure Genymotion to use the same ADB as the Android SDK:

```bash
gmtool config --use_custom_sdk on --sdk_path "$ANDROID_HOME"
```

Mismatched ADB versions cause server restarts that disconnect all devices.

### PATH Setup

| OS | GMTool Location |
|----|----------------|
| macOS | `/Applications/Genymotion.app/Contents/MacOS/` |
| Linux | `$HOME/genymotion/` or `/opt/genymotion/` |
| Windows | `C:\Program Files\Genymobile\Genymotion\` |

Genymotion Shell path differs slightly — see `references/cli-reference.md` for exact locations.

## Decision Framework

### When Genymotion Desktop is Right

- Local development on Apple Silicon (native arm64 Android images)
- Rich sensor simulation (GPS, battery, network, motion sensors, biometrics, camera injection)
- Teams already invested in Genymotion ecosystem
- Quick prototyping with the device link feature (forward real phone sensors)

### When to Use Alternatives

- **CI/CD pipelines** → Use AVD (`emulator -no-window`) or Genymotion SaaS (`gmsaas`)
- **Budget-constrained** → Use free AVD (since Desktop 3.2.0, `list`/`start`/`stop` work without paid license, but `create`/`delete`/`install` still require Indie/Business)
- **Parallel testing at scale** → Use Genymotion SaaS, Firebase Test Lab, or AVD with Gradle Managed Devices
- **SafetyNet/Play Integrity** → Physical devices only
- **Accurate ARM behavior on x86 hosts** → AVD with ARM images or physical devices

**Genymotion Desktop has no headless mode** — it requires GPU and a display. On Linux CI servers, use `xvfb-run` as a workaround (see `references/ci-and-recipes.md`). This is the fundamental constraint for CI/CD.

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|-------------|-----------------|
| Running commands before boot completes | Always implement boot-wait loop checking `sys.boot_completed`, `init.svc.bootanim == stopped`, AND `pm list packages` readiness |
| Using different ADB versions | Set `gmtool config --use_custom_sdk on --sdk_path "$ANDROID_HOME"` |
| Leaving animations enabled during tests | Disable all three animation scales before test execution |
| Using Quick Boot in CI | Use `--coldboot` for reproducibility; Quick Boot state can corrupt |
| Running 3+ instances simultaneously | Limit to 1-2 instances; memory leaks degrade performance rapidly |
| Using ARM translation for testing | Build x86/x86_64 APKs; avoid libhoudini entirely |
| Expecting headless operation | Genymotion Desktop requires GUI; use `xvfb-run` on Linux or SaaS/AVD for headless |
| Not resetting sensor state between suites | Reset GPS, battery, network via Genymotion Shell between test runs |
| Leaving Google Play auto-updates enabled in CI | Disable with `adb shell pm disable-user com.android.vending` |
| Ignoring `INSTALL_FAILED_NO_MATCHING_ABIS` | APK lacks x86 ABI; rebuild with `abiFilters` including x86/x86_64 or install ARM translation |
| Connecting to 127.0.0.1 | Use the host-only IP (192.168.56.x); Genymotion uses TCP/IP on host-only network |
| Running gmtool as multiple OS users | Single-user limitation — only use GMTool for one OS user per machine |
| Not handling CI license cleanup | Use `trap cleanup EXIT` to ensure `gmtool admin stop` runs on failure, preventing license lockouts |
| Leaving screen timeout at default | Set `adb shell svc power stayon true` or increase timeout for long-running Appium/Maestro tests |
| Killing Genymotion process outside gmtool | Always use `gmtool admin stop`; force-killing leaves orphaned VMs and hypervisor locks |
| Omitting `-n` with multiple running devices | GMTool errors or picks arbitrarily; always specify `-n <name>` when 2+ devices are running |
| Wrong hypervisor for the platform | Apple Silicon requires QEMU; Windows with Hyper-V requires QEMU; Windows without Hyper-V uses VirtualBox |
| Host sleep/shutdown with VMs running | Stop all VMs before sleep (`gmtool admin stopall`); abrupt power loss can corrupt VM disk state |
| VirtualBox version mismatch | Use the VirtualBox version bundled with or documented for your Genymotion release; mismatches cause silent start failures (error code 4) |
| Relying on deprecated `templates` command | Use `gmtool admin hwprofiles` and `gmtool admin osimages` instead |

## Concurrent Instance Limits

| Host RAM | Max Instances | Per-Instance Config |
|----------|--------------|---------------------|
| 8GB | 1 (possibly 2 lightweight) | 1-2GB RAM, 2 CPU cores |
| 16GB | 2-3 | 2GB RAM, 2 CPU cores each |
| 32GB | 3-4 | 2-3GB RAM, 2 CPU cores each |

**Per-instance RAM usage**: 1.5-3GB depending on Android version and installed apps. Keep total vCPU count across all VMs at or below host physical core count; oversubscribing causes severe context switching.

Memory leaks are an officially acknowledged, unfixable limitation. Not suitable for running more than 1 device for over 12 hours. For extended test suites, implement periodic device recycling (see `references/ci-and-recipes.md`).

## Reference Map

| Topic | Reference File | When to Read |
|-------|----------------|--------------|
| Feature availability and testing strategy | `references/emulated-features/index.md` | Checking which features exist, choosing test approach |
| GPS and location simulation | `references/emulated-features/gps.md` | GPS coordinates, route simulation, geofencing |
| Battery simulation | `references/emulated-features/battery.md` | Battery levels, charging states, thresholds |
| Network and baseband simulation | `references/emulated-features/network.md` | WiFi/mobile profiles, signal strength, GSM state |
| Phone calls and SMS | `references/emulated-features/phone-sms.md` | Incoming calls, SMS, baseband telephony |
| Device Identity, Disk I/O, Rotation | `references/emulated-features/device-config.md` | Android ID, IMEI, disk throttling, orientation |
| Sensor state persistence and reset | `references/emulated-features/sensor-management.md` | Persistence rules, reset scripts, conflicts |
| GUI-only features (motion, biometrics, camera, gamepad, device link) | `references/emulated-features/gui-features.md` | Features requiring GUI + their automation alternatives |
| GUI walkthrough instructions | `references/emulated-features/gui-walkthroughs.md` | Guiding user through GUI-only operations step-by-step |
| Controls and developer tools | `references/emulated-features/controls-and-tools.md` | ADB alternatives for dev tools, capture, controls |
| GMTool and Genymotion Shell CLI | `references/cli-reference.md` | Looking up specific commands, options, error codes |
| Test framework integration and reliability | `references/test-integration.md` | Setting up Espresso, Compose, Maestro, Appium; diagnosing test flakiness |
| CI/CD patterns and workflow recipes | `references/ci-and-recipes.md` | Configuring CI pipelines or writing automation scripts |

## Quick Reference

### GMTool Essentials

```bash
gmtool admin list [--running|--off]       # List devices
gmtool admin create <hw> <os> <name>      # Create device
gmtool --timeout 300 admin start <name>   # Start device
gmtool admin stop <name>                  # Stop device
gmtool admin stopall                      # Stop all devices
gmtool admin delete <name>               # Delete device
gmtool device -n <name> adbconnect       # Connect to ADB
gmtool device -n <name> install app.apk  # Install APK
gmtool device -n <name> logcatdump ~/log.txt  # Dump logcat
```

### Genymotion Shell Essentials

```bash
genyshell -q -c "gps setlatitude <val>"              # GPS latitude (-90 to 90)
genyshell -q -c "gps setlongitude <val>"             # GPS longitude (-180 to 180)
genyshell -q -c "gps setaltitude <val>"              # Altitude (-10000 to 10000m)
genyshell -q -c "gps setaccuracy <val>"              # Accuracy (0-200m)
genyshell -q -c "gps setbearing <val>"               # Bearing (0-359.99 deg)
genyshell -q -c "battery setmode manual|host"        # Battery control mode
genyshell -q -c "battery setlevel <0-100>"           # Battery level
genyshell -q -c "battery setstatus <status>"         # charging|discharging|notcharging|full
genyshell -q -c "network setstatus wifi <on>"        # Network toggle
genyshell -q -c "network setmobileprofile <profile>" # gsm|gprs|edge|umts|hsdpa|lte|5g
genyshell -q -c "network setsignalstrength <i> <s>"  # Interface + none|poor|moderate|good|great
genyshell -q -c "rotation setangle <deg>"            # 0, 90, 180, 270
genyshell -q -c "diskio setreadratelimit <KB/s>"     # Disk I/O limit (0=unlimited)
genyshell -q -c "phone sms <num> <msg>"              # Simulate incoming SMS
genyshell -q -c "phone call <number>"                # Simulate incoming call
genyshell -q -c "android setandroidid random"        # Randomize Android ID
genyshell -q -c "android setdeviceid random"         # Randomize IMEI
genyshell -r <IP> -c "<cmd>"                         # Target specific device
genyshell -f <script.gys>                            # Execute script file
genyshell -q -c "genymotion capabilities"            # JSON of available features
genyshell -q -c "devices factoryreset <device_ID> force"  # Factory reset (destructive)
genyshell -q -c "devices ping"                       # Check device responsive
```

### Boot Wait Pattern

```bash
wait_for_boot() {
    local timeout=${1:-120} elapsed=0
    adb wait-for-device
    while [ $elapsed -lt $timeout ]; do
        local bc=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
        local ba=$(adb shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")
        if [ "$bc" = "1" ] && [ "$ba" = "stopped" ]; then
            adb shell input keyevent 82  # Dismiss keyguard
            sleep 2
            # Verify package manager is ready (prevents race on app install)
            adb shell pm list packages 2>/dev/null | head -1 | grep -q "package:" && return 0
        fi
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}
```
