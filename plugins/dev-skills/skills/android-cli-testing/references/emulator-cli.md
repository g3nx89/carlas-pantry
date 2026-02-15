# Android SDK Emulator CLI Reference

Complete reference for managing Android emulators from the command line: sdkmanager, avdmanager, emulator flags, config.ini, console commands, and hardware acceleration.

## sdkmanager

**Location**: `$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager`

```bash
# List all available and installed packages
sdkmanager --list
sdkmanager --list --channel=0    # Stable only (default)
sdkmanager --list --channel=3    # Include canary

# Install packages
sdkmanager "system-images;android-34;google_apis;x86_64"
sdkmanager "platform-tools" "emulator" "platforms;android-35"
sdkmanager --install "cmdline-tools;latest"

# Install from file (one package per line)
sdkmanager --package_file=packages.txt

# Update all installed packages
sdkmanager --update

# Uninstall
sdkmanager --uninstall "system-images;android-34;google_apis;x86_64"

# Accept all licenses (critical for CI)
yes | sdkmanager --licenses
```

**All flags**: `--sdk_root=path` (override SDK path), `--channel=N` (0=Stable, 1=Beta, 2=Dev, 3=Canary), `--include_obsolete`, `--no_https`, `--newer` (show only updatable), `--verbose`, `--proxy={http|socks}`, `--proxy_host=IP`, `--proxy_port=N`.

### System Image Variants

| Variant | Package Segment | Includes | Root Access | Best For |
|---------|----------------|----------|-------------|----------|
| AOSP | `default` | Base Android only | Yes (`adb root`) | Need root, no Google deps |
| Google APIs | `google_apis` | Play Services APIs (Maps, FCM) | Yes (`adb root`) | CI testing, apps using Google APIs |
| Google Play | `google_apis_playstore` | Play Services + Play Store | **No** (production-locked) | Testing Play Store interactions |

**For CI, prefer `google_apis`** -- smaller, root-capable, sufficient for most testing. Avoid `google_apis_playstore` in CI; the Pixel Launcher causes background ANRs. For fastest CI, use **ATD images**: `system-images;android-30;aosp_atd;x86` -- purpose-built for automated testing with minimal bloat.

**API level strategy**: Test on `targetSdkVersion` (primary), `minSdkVersion` (compatibility), and 1-2 intermediate levels. Use **x86_64** on Intel/AMD hosts; **arm64-v8a** on Apple Silicon Macs.

## avdmanager

**Location**: `$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager`

```bash
# Create AVD
echo "no" | avdmanager create avd \
  -n "Pixel6_API34" \
  -k "system-images;android-34;google_apis;x86_64" \
  -d "pixel_6"

# All create flags:
#   -n name           Required: AVD name
#   -k "sdk_id"       Required: system image package path
#   -d "device_id"    Device profile (from `avdmanager list device`)
#   -p /path          Custom AVD directory
#   -c 512M           SD card size or path to sdcard image
#   -f / --force      Overwrite existing AVD
#   --tag "google_apis"  Tag (usually auto-detected)
#   --abi "x86_64"    ABI (usually auto-detected)

# List commands
avdmanager list avd          # All created AVDs
avdmanager list device       # Available device profiles
avdmanager list device -c    # Compact (for scripts)
avdmanager list target       # Installed targets/platforms

# Delete
avdmanager delete avd -n "Pixel6_API34"

# Move/rename
avdmanager move avd -n "OldName" -p /new/path -r "NewName"
```

**Common device profiles**: `pixel` (1080x1920, 440dpi), `pixel_2` (1080x1920, 420dpi), `pixel_5` (1080x2340, 440dpi), `pixel_6` (1080x2400, 420dpi), `pixel_7` (1080x2400, 420dpi), `pixel_7_pro` (1440x3120, 512dpi), `pixel_8` (1080x2400, 420dpi), `medium_phone` (1080x2400, 420dpi).

## AVD config.ini

**Location**: `~/.android/avd/<name>.avd/config.ini`

```ini
# Memory
hw.ramSize=4096              # RAM in MB (2048-4096 recommended)
vm.heapSize=512              # VM heap in MB

# Storage
disk.dataPartition.size=6G   # Data partition (2-6G typical)
hw.sdCard=yes
sdcard.size=512M

# Display
hw.lcd.width=1080
hw.lcd.height=2400
hw.lcd.density=420

# GPU
hw.gpu.enabled=yes
hw.gpu.mode=auto             # auto, host, swiftshader_indirect, guest, off

# Input (IMPORTANT: set hw.keyboard=yes for CI)
hw.keyboard=yes
hw.dPad=no
hw.mainKeys=no

# Sensors
hw.accelerometer=yes
hw.sensors.orientation=yes
hw.sensors.proximity=yes
hw.gps=yes

# Camera
hw.camera.back=emulated      # emulated, webcam0, virtualscene, none
hw.camera.front=emulated

# Network
runtime.network.latency=none
runtime.network.speed=full

# Boot
fastboot.forceColdBoot=no    # yes = always cold boot

# CPU
hw.cpu.ncore=4
hw.cpu.arch=x86_64
```

## Emulator Command Flags

**Location**: `$ANDROID_HOME/emulator/emulator`

```bash
emulator -avd <name> [options]
emulator @<name> [options]
emulator -list-avds              # List available AVDs
```

### Headless/CI Flags

| Flag | Purpose |
|------|---------|
| `-no-window` | Run without display window |
| `-no-audio` / `-noaudio` | Disable audio |
| `-no-boot-anim` | Skip boot animation (saves seconds) |
| `-no-snapshot` | Disable snapshot load AND save entirely |
| `-no-snapshot-load` | Cold boot, but save state on exit |
| `-no-snapshot-save` | Quick boot if possible, don't save on exit |

### GPU Modes (`-gpu mode`)

| Mode | Description | Use When |
|------|-------------|----------|
| `auto` | Auto-detect (default) | General use |
| `host` | Host GPU hardware acceleration | Windowed dev, best performance |
| `swiftshader_indirect` | Software rendering via SwiftShader | **Headless/CI (recommended)** |
| `guest` | Guest software rendering (deprecated API >=28) | Legacy only |
| `off` | No GPU emulation | Debugging only |

When launched with `-no-window`, renderer automatically defaults to `swiftshader_indirect` since emulator 28.0.25+.

### Other Important Flags

**Memory**: `-memory 2048` (RAM in MB), `-partition-size 4096` (system/data partition in MB).

**Network**: `-netdelay gsm|hscsd|gprs|edge|umts|hsdpa|lte|evdo|none|NUM|MIN:MAX`, `-netspeed <same options>|full|NUM|UP:DOWN`, `-netfast` (full speed, no delay), `-dns-server 8.8.8.8,8.8.4.4`, `-http-proxy server:port`, `-tcpdump /path/dump.cap`.

**Snapshots**: `-no-snapshot` (disable entirely), `-no-snapshot-load` (cold boot, save on exit), `-no-snapshot-save` (quick boot, no save), `-snapshot <name>` (load/save specific named snapshot).

**Ports**: `-port 5556` (console port; ADB port = port+1), `-ports 5556,5559` (explicit both). Default scheme: 5554/5555, 5556/5557, 5558/5559... up to 5682/5683 (64 instances max).

**Other**: `-wipe-data` (factory reset), `-read-only`, `-camera-back webcam0|emulated|virtualscene|none`, `-camera-front emulated|webcam0|none`, `-webcam-list`, `-verbose`, `-accel auto|on|off`, `-no-accel`, `-timezone "America/New_York"`, `-selinux permissive|disabled`, `-logcat '*:e'` (logcat to terminal), `-show-kernel`, `-skin 1080x1920`, `-feature -Vulkan` (disable Vulkan), `-delay-adb` (suppress ADB until boot complete).

## Multiple Emulator Instances

Each instance uses an adjacent port pair: console (even) and ADB (odd). Serial format: `emulator-5554`, `emulator-5556`, etc.

```bash
emulator -avd AVD1 -port 5554 &
emulator -avd AVD2 -port 5556 &
emulator -avd AVD3 -port 5558 &

adb devices                              # Lists all instances
adb -s emulator-5554 install app.apk     # Target specific instance
adb -s emulator-5556 emu kill            # Kill specific instance
```

## Emulator Console (Telnet)

```bash
telnet localhost 5554
# Authenticate with token from ~/.emulator_console_auth_token:
auth <token>
```

### GPS

```
geo fix <longitude> <latitude> [altitude [satellites [velocity]]]
# e.g., geo fix -122.084 37.422 50
```

### Battery/Power

```
power ac on|off
power status charging|discharging|not-charging|full
power capacity 50                   # 0-100
power health good|failed|dead|overvoltage|overheated
power display
```

### SMS/Call

```
sms send 5551234567 "Hello"
gsm call 5551234567
gsm accept|cancel|busy|hold 5551234567
gsm list
gsm data gprs|home|roaming|off
gsm voice home
gsm signal <rssi> [ber]
gsm signal-profile <0-4>
```

### Network

```
network delay gprs|edge|umts|none|NUM|MIN:MAX
network speed edge|full|lte|...
network status
network capture start <file>
network capture stop
```

### Snapshots

```
avd snapshot save <name>
avd snapshot load <name>
avd snapshot list
avd snapshot delete <name>
```

### Other Console Commands

```
finger touch <id>              # Fingerprint (IDs 1-10)
sensor set acceleration 0:9.81:0
rotate
redir add tcp:5000:6000        # Port redirect
kill
ping
```

## Hardware Acceleration

| Platform | Hypervisor | Verification |
|----------|-----------|-------------|
| Linux | KVM | `emulator -accel-check` -> "KVM is installed and usable" |
| macOS | Hypervisor.Framework (built-in since 10.10) | `emulator -accel-check` -> "Hypervisor.Framework" |
| Windows | WHPX (Win10 1803+) or AEHD | `emulator -accel-check` -> "WHPX/AEHD is installed and usable" |

**HAXM is deprecated** since Jan 2023 (emulator 33.x+), removed from emulator 36.2+. AEHD is the Windows replacement.

```bash
# Linux KVM setup:
sudo apt-get install qemu-kvm
# Verify: kvm-ok

# CI Linux KVM permissions:
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=kvm
```

## Performance Optimization

**Cold boot reduction strategies**:
1. Quick Boot (default) -- saves/restores snapshots in ~3-5s vs ~25-30s cold
2. `-no-boot-anim` saves several seconds
3. Pre-baked snapshots: create clean snapshot after initial boot, load in CI
4. Keep emulator running between test runs, just `pm clear`
5. Use `google_apis` instead of `google_apis_playstore` (smaller)
6. ATD images boot faster with fewer background services

**Host requirements**: Minimum 8GB RAM (16GB recommended). Emulator RAM 2048-4096MB. VM heap 256-512MB. At least 2 CPU cores (`hw.cpu.ncore=4` in config.ini). SSD strongly recommended.

## Known Limitations

- **API 30+ (Android 11+)**: Chrome uses Vulkan, can cause issues -- workaround: `-feature -Vulkan`
- **Snapshots + Vulkan**: Creating snapshots with Vulkan not supported
- **ARM images on x86**: Cannot use VM acceleration, extremely slow
- **WebView**: Emulator WebView version may lag behind real devices receiving Play Store updates
- **Compose rendering**: Generally works well with GPU acceleration; `swiftshader_indirect` shows minor visual differences -- acceptable for functional tests, not pixel-perfect UI
- **SD card on Apple Silicon**: Does not work
