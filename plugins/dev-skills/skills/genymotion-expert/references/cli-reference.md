# GMTool and Genymotion Shell CLI Reference

Complete command reference for both CLI tools.

## GMTool (`gmtool`)

### Binary Locations

| OS | GMTool Path | Genymotion Shell Path |
|----|-------------|----------------------|
| macOS | `/Applications/Genymotion.app/Contents/MacOS/gmtool` | `/Applications/Genymotion Shell.app/Contents/MacOS/genyshell` |
| Linux | `$HOME/genymotion/gmtool` or `/opt/genymotion/gmtool` | `$HOME/genymotion/genymotion-shell` or `/opt/genymotion/genymotion-shell` |
| Windows | `C:\Program Files\Genymobile\Genymotion\gmtool.exe` | `C:\Program Files\Genymobile\Genymotion\genyshell.exe` |

### Global Options

| Option | Short | Description |
|--------|-------|-------------|
| `--timeout <0-3600>` | `-t` | Timeout in seconds |
| `--verbose` | `-v` | Verbose output |
| `--help` | `-h` | Display help |

### Authentication and License

```bash
gmtool config --email "user@example.com" --password "secret"
gmtool license register YOUR_LICENSE_KEY
gmtool license info          # License type, activated workstations, expiration
gmtool license count         # Number of activated workstations
gmtool license validity      # Days remaining
```

Since Desktop 3.2.0, `gmtool admin list`, `start`, and `stop` work without a paid license. All other admin/device commands require Indie or Business license (error code 14 if attempted without).

### Device Lifecycle

**List available profiles and images:**
```bash
gmtool admin hwprofiles    # Hardware profiles (Samsung Galaxy S10, Pixel 4, Custom Phone, etc.)
gmtool admin osimages      # Android images (5.0 through 15.0)
# Note: 'gmtool admin templates' is DEPRECATED
```

**Create a device:**
```bash
gmtool admin create "<hwprofile>" "<osimage>" "<device_name>" [options]

# Full option list:
#   --density <value>            Screen density (120-640)
#   --width <value>              Screen width in pixels
#   --height <value>             Screen height in pixels
#   --virtualkeyboard <on|off>   Virtual keyboard
#   --navbar <on|off>            Navigation bar
#   --nbcpu <value>              CPU cores
#   --ram <value>                RAM in MB
#   --network-mode <nat|bridge>  Network mode (VirtualBox only)
#   --bridged-if <name>          Bridge interface (VirtualBox only)
#   --quickboot <on|off>         Quick Boot (QEMU only)
#   --root-access <on|off>       Root access
#   --sysprop <property>:<value> System property (MODEL, PRODUCT, MANUFACTURER, etc.)
```

**Start, stop, manage:**
```bash
gmtool admin start "DeviceName"             # Start (Quick Boot if available)
gmtool admin start "DeviceName" --coldboot   # Force full boot
gmtool admin stop "DeviceName"
gmtool admin stopall                        # Stop ALL running devices
gmtool admin list                           # All devices
gmtool admin list --running                 # Running only
gmtool admin list --off                     # Stopped only
gmtool admin details "DeviceName"           # All properties, ADB serial, etc.
```

**Clone, edit, reset, delete:**
```bash
gmtool admin clone "SourceDevice" "NewName"
gmtool admin edit "DeviceName" --width 1080 --height 1920 --density 420
gmtool admin edit "DeviceName" --nbcpu 2 --ram 2048
gmtool admin factoryreset "DeviceName"
gmtool admin delete "DeviceName"
```

**Log generation:**
```bash
gmtool admin logzip ~/Desktop/                    # Archive all logs
gmtool admin logzip -n "DeviceName" ~/Desktop/    # Specific device logs
```

### Device Interaction Commands

All accept `-n <device_name>` or `--all` for all running devices. The `--start` flag auto-starts if not running.

```bash
gmtool device -n "DeviceName" adbconnect
gmtool device -n "DeviceName" adbdisconnect
gmtool device -n "DeviceName" install app.apk
gmtool device -n "DeviceName" push local.txt /sdcard/
gmtool device -n "DeviceName" pull /sdcard/file.txt ./
gmtool device -n "DeviceName" flash archive.zip
gmtool device -n "DeviceName" logcatdump ~/logcat.txt
gmtool device -n "DeviceName" logcatclear
gmtool device --all logcatdump ~/logs/
```

### Configuration Options

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

### Network and Port Forwarding

Genymotion uses NAT mode by default. The special address **`10.0.3.2`** is an alias for the host machine from inside the device — useful for proxy configuration and connecting to local servers.

```bash
# Device can reach host's port 8080 via localhost:8080
adb reverse tcp:8080 tcp:8080

# Host can reach device's port 5000 via localhost:9999
adb forward tcp:9999 tcp:5000
```

Bridge mode (VM gets own IP on physical network via DHCP) is only available with VirtualBox hypervisor:
```bash
gmtool admin create ... --network-mode bridge --bridged-if eth0
```

### Google Play Services (GApps)

Genymotion 2.10+ includes a one-click Open GApps installer widget in the toolbar. For CLI/automation:

```bash
# Download appropriate x86 Open GApps nano package from opengapps.org
# Flash via gmtool:
gmtool device -n "DeviceName" flash open_gapps-x86-11.0-nano-*.zip

# Or via adb:
adb push open_gapps.zip /sdcard/Download/
adb shell "/system/bin/flash-archive.sh /sdcard/Download/open_gapps.zip"
adb reboot
```

**Limitations:**
- GApps version must exactly match the Android version
- OpenGApps website does not have packages for Android 12+ — use the built-in widget for newer versions
- Install ARM translation (if needed) *before* GApps
- For CI, use `deleteWhenFinish false` in the Gradle plugin or use snapshot/clone to preserve the installed state

### Error Codes

| Code | Message | Action |
|------|---------|--------|
| 0 | Success | Continue |
| 1 | Command does not exist | Check syntax |
| 2 | Wrong parameter value | Validate inputs |
| 3 | Command failed | Retry or investigate |
| 4 | Virtualization engine does not respond | Check hypervisor running |
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

## Genymotion Shell (`genyshell`)

### Shell Options

| Option | Description |
|--------|-------------|
| `-q` | Quiet mode (suppress banner, ideal for scripting) |
| `-h` | Display help |
| `-r <IP>` | Connect to device at specific IP |
| `-c "<command>"` | Execute single command |
| `-f <file>` | Execute commands from file |

### Device Management

```bash
devices list              # List devices with ID, status, IP, name
devices refresh           # Refresh list
devices select <id>       # Select device by ID
devices ping              # Check if selected device responds
devices factoryreset <id> [force]
```

### GPS Simulation

```bash
gps setstatus enabled|disabled
gps setlatitude <-90 to 90>
gps setlongitude <-180 to 180>
gps setaltitude <-10000 to 10000>    # meters
gps setaccuracy <0 to 200>           # meters
gps setbearing <0 to 359.99>         # degrees
gps getstatus|getlatitude|getlongitude|getaltitude|getaccuracy|getbearing
```

GPX route playback is GUI-only. Simulate via scripted sequential `gps setlatitude`/`gps setlongitude` with `pause` between calls.

### Battery Simulation

```bash
battery setmode manual|host       # manual=script control, host=mirror host battery
battery setlevel <0-100>
battery setstatus discharging|charging|notcharging|full
battery getmode|getlevel|getstatus
```

### Network Simulation (Android 8.0+)

```bash
network setstatus wifi|mobile enabled|disabled
network setsignalstrength wifi|mobile none|poor|moderate|good|great
network setmobileprofile none|gsm|gprs|edge|umts|hsdpa|lte|5g
network getstatus wifi|mobile
network getsignalstrength mobile
network getmobileprofile
```

For Android 7.1 and below:
```bash
network setprofile no-data|gprs|edge|3g|4g|4g-high-losses|4g-bad-dns|wifi
network getprofile
```

### Rotation

```bash
rotation setangle 0|90|180|270
```

### Phone Calls and SMS

```bash
phone call <number>                # Incoming call
phone sms <number> "message"       # Incoming SMS

# Baseband-level control:
phone baseband gsm call <number>
phone baseband gsm accept <number>
phone baseband gsm cancel <number>
phone baseband gsm hold <number>
phone baseband gsm busy <number>
phone baseband gsm status
phone baseband gsm voice home|unregistered|roaming|searching|denied
phone baseband gsm data home
phone baseband gsm signal rssi <0-31>
phone baseband sms send <number> "message"
```

### Disk I/O Throttling

```bash
diskio setreadratelimit <1-2097151>    # KB/sec (0=unlimited)
diskio getreadratelimit
diskio clearcache
```

### Device Identity

```bash
android version
android getandroidid
android setandroidid random|custom <16-hex-digits>
android getdeviceid
android setdeviceid random|none|custom <value>
```

### System Information

```bash
genymotion capabilities    # JSON: {"accelerometer":true,"battery":true,"gps":true,...}
genymotion version
genymotion license
genymotion clearcache
```
