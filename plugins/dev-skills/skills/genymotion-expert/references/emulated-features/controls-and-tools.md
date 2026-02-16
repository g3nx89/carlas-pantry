# Controls and Developer Tools

Minor features and developer utilities with ADB alternatives for automation.

> **Cross-references:** For feature availability, see `index.md`. For sensor persistence, see `sensor-management.md`.

---

## Advanced Developer Tools (v3.4.0+, Paid)

The Advanced Developer Tools widget provides quick access to common Android developer settings.

### Available Toggles

| Toggle | Effect | Testing Use |
|--------|--------|-------------|
| **Root Access** | Enables/disables su access | Security testing, system-level inspection |
| **Show Taps** | Displays touch indicators on screen | Debugging touch targets, recording demos |
| **Show Pointer Location** | Shows pointer coordinates overlay | Verifying touch coordinates in automation scripts |
| **Show Layout Bounds** | Draws layout boundaries for all views | Debugging layout issues, padding/margin verification |
| **Enable/Disable Animations** | Controls system animation scale | Quick toggle vs. manual `settings put` commands |
| **Force Desktop Mode** | Multi-display desktop mode | Requires reboot; testing freeform/desktop UI |

### Root Access Details

When root is enabled, `adb shell` sessions run as root by default. This allows:
- Reading any file on the filesystem
- Modifying system settings directly
- Installing system apps
- Running security analysis tools (Frida, MobSF, etc.)
- Inspecting network traffic at the system level

```bash
# Verify root access
adb shell whoami
# Expected: root (when enabled), shell (when disabled)
```

### ADB Alternatives for Automation

All developer options can also be set via ADB (automatable in CI):

```bash
# Animations (most common — see Test Stability Checklist in test-integration.md)
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# Show taps
adb shell settings put system show_touches 1    # Enable
adb shell settings put system show_touches 0    # Disable

# Pointer location
adb shell settings put system pointer_location 1  # Enable
adb shell settings put system pointer_location 0  # Disable

# Layout bounds
adb shell setprop debug.layout true    # Enable
adb shell setprop debug.layout false   # Disable
adb shell service call activity 1599295570  # Force refresh
```

---

## Capture

The Capture widget provides screenshot and screen recording from the emulator toolbar.

### Capabilities

| Feature | Description |
|---------|-------------|
| Screenshot | Single frame capture to file |
| Screencast | Toggle on/off video recording |
| File Browser | Open capture directory |

**Default directory**: Configurable via **Genymotion > Settings > Device**.

### ADB Alternatives (Automatable)

For CI/CD and scripted capture, use ADB directly:

```bash
# Screenshot
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png ./

# Screen recording (max 180 seconds per recording)
adb shell screenrecord --time-limit 60 --size 720x1280 /sdcard/recording.mp4
# Stop early with Ctrl+C, then:
adb pull /sdcard/recording.mp4 ./

# GMTool shortcut for logcat (related diagnostic):
gmtool device -n "DeviceName" logcatdump ~/logcat.txt
```

---

## Android Controls (v3.3.0+, Paid)

The Android Controls widget provides virtual buttons for hardware controls not present on the emulator window.

| Control | Function | ADB Alternative |
|---------|----------|-----------------|
| D-pad (Up/Down/Left/Right) | Directional navigation | `adb shell input keyevent KEYCODE_DPAD_*` |
| Volume Up/Down | Audio volume | `adb shell input keyevent KEYCODE_VOLUME_UP/DOWN` |
| Call button | Simulate call key | `adb shell input keyevent KEYCODE_CALL` |
| End Call | End call key | `adb shell input keyevent KEYCODE_ENDCALL` |
| Play/Pause | Media playback | `adb shell input keyevent KEYCODE_MEDIA_PLAY_PAUSE` |
| Stop | Stop media | `adb shell input keyevent KEYCODE_MEDIA_STOP` |
| Next/Previous | Media track navigation | `adb shell input keyevent KEYCODE_MEDIA_NEXT/PREVIOUS` |

---

## Other Controls

| Control | Description | Shortcut / ADB |
|---------|-------------|----------------|
| **Sound** | Volume adjustment (click widget to raise/lower) | `adb shell media volume --set <0-15> --stream 3` |
| **Rotate** (v3.3.0+) | 90 left/right rotation | `rotation setangle` via genyshell |
| **Navigation** | Recent apps, Home, Back | `adb shell input keyevent KEYCODE_APP_SWITCH/HOME/BACK` |
| **Power** | Sleep mode; hold for power off | `adb shell input keyevent KEYCODE_POWER` |

---

## Clipboard

Bidirectional clipboard sharing between the host and the virtual device. Enabled by default. Can be disabled in **Genymotion > Settings > Global**.

### ADB Alternative (Automatable)

```bash
# Type text directly into the focused input field (does not use clipboard)
adb shell input text "text_to_type_here"

# For actual clipboard operations, use a clipboard manager app
adb shell am broadcast -a clipper.set -e text "Hello World"
# (requires Clipper app or similar clipboard manager installed)

# For instrumented tests, use AndroidX ClipboardManager APIs
# to programmatically set/read clipboard content
```

---

## File Upload

Transfer files from the host to the virtual device via the File Upload widget or drag-and-drop. APKs are auto-installed, flashable ZIPs are flashed to system, other files go to `/sdcard/Download`.

### ADB Alternative (Automatable)

```bash
# Push any file to the device
adb push local_file.txt /sdcard/Download/

# Install APK via ADB
adb install -r app-debug.apk

# Push multiple files
adb push ./test-assets/ /sdcard/Download/test-assets/
```

**APK not installing**: Check for ABI mismatch (`INSTALL_FAILED_NO_MATCHING_ABIS`) — see Anti-Patterns in SKILL.md.

---

## Open GApps

One-click minimal Google Play Services installation via the toolbar widget.

**Process**: Downloads compatible GApps package, flashes to device, requires reboot.

**CLI alternative** (for automation): See `cli-reference.md` Google Play Services section for `gmtool device flash` commands.

**Disclaimer**: GApps are provided by the Open GApps project. Genymotion states: "We assume no liability whatsoever resulting from the download, install and use of Open GApps."
