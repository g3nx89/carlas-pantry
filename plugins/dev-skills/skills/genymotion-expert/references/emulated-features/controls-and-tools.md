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

## Google Play Services (Open GApps)

**Google Play Services and Play Store are NOT installed by default** on Genymotion virtual devices. Genymotion ships AOSP Android images without Google proprietary software. Apps that depend on Google Play Services (Maps, Firebase, Google Sign-In, In-App Billing, FCM push notifications) will crash or degrade without them.

Installation is straightforward via the built-in Open GApps widget (available since Genymotion 2.10+, Android 4.4+). **No paid license required** — works on the free edition.

### GUI Installation (Recommended)

1. Start the virtual device
2. Click the **Open GApps** button in the right-side toolbar (cloud icon with a triangle)
3. Read the disclaimer and click **Accept**
4. Wait for the automatic download and flash (progress shown in the toolbar)
5. Click **Restart now** when prompted (or restart later via `adb reboot`)
6. After reboot, Google Play Store appears in the App Drawer
7. Sign in with a Google account to use Play Store and Play Services

### CLI Installation (for Automation)

```bash
# Method 1: gmtool flash (recommended)
# Download the matching Open GApps nano package for your device's Android version and ABI
gmtool device -n "DeviceName" flash open_gapps-x86-11.0-nano-*.zip
adb reboot

# Method 2: adb push + flash script
adb push open_gapps.zip /sdcard/Download/
adb shell "/system/bin/flash-archive.sh /sdcard/Download/open_gapps.zip"
adb reboot
```

### Verification

```bash
# Confirm Google Play Services is installed and its version
adb shell pm list packages | grep google
# Expected: package:com.google.android.gms (Play Services)
#           package:com.android.vending (Play Store)

# Check Play Services version
adb shell dumpsys package com.google.android.gms | grep versionName
```

### Important Caveats

| Caveat | Detail |
|--------|--------|
| **Android 12+ packages** | opengapps.org does NOT provide packages for Android 12+. Use the built-in widget — it handles these versions automatically |
| **Manual download unsupported** | Installing GApps manually from opengapps.org is unsupported and may corrupt the device. Always use the built-in widget or `gmtool flash` |
| **ARM translation ordering** | If ARM translation is needed, install it BEFORE GApps. GApps detects available ABIs during installation |
| **Version match required** | GApps package version must exactly match the device's Android version |
| **CI auto-updates** | Disable Play Store auto-updates in CI to prevent flaky tests: `adb shell pm disable-user com.android.vending` |
| **Golden master pattern** | For CI, install GApps once on a "golden master" device, then clone it. Avoids repeating the flash+reboot on every run (see `ci-and-recipes.md` Recipe 4) |

### When Google Play Services Are Needed

| App Dependency | Requires Play Services? | Alternative Without Play Services |
|---------------|------------------------|----------------------------------|
| Google Maps SDK | Yes | Use OSM/MapLibre, or install GApps |
| Firebase (Analytics, Crashlytics, FCM) | Yes | Firebase falls back gracefully for some features; FCM requires Play Services |
| Google Sign-In | Yes | Use alternative OAuth flows or install GApps |
| In-App Billing | Yes | No alternative — install GApps |
| SafetyNet / Play Integrity | Yes, but fails on emulators regardless | Physical device required |
| AdMob | Yes | Test ads may work partially without it |

**Disclaimer**: GApps are provided by the Open GApps project. Genymotion states: "We assume no liability whatsoever resulting from the download, install and use of Open GApps."
