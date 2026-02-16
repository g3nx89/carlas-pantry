# GUI-Only Features

Features that require the Genymotion Desktop GUI and cannot be scripted through Genymotion Shell. Each section includes automation alternatives where available.

> **Cross-references:** For sensor persistence rules, see `sensor-management.md`. For feature availability, see `index.md`.

---

## Motion Sensors (v3.8.0+, Paid)

The Motion Sensors widget emulates accelerometer, gyroscope, and magnetometer via GUI-only yaw/pitch/roll controls and a 3D device model. Not available via Genymotion Shell.

### Automation Alternatives

**Option 1 — Discrete rotation** (limited but automatable — see `device-config.md` Rotation section for full details):
```bash
genyshell -q -c "rotation setangle 0"    # Portrait
genyshell -q -c "rotation setangle 90"   # Landscape left
genyshell -q -c "rotation setangle 180"  # Portrait inverted
genyshell -q -c "rotation setangle 270"  # Landscape right
```

**Option 2 — Mock SensorManager in test code**:
```kotlin
// For continuous motion testing, mock at the Android API level
// in instrumented tests when Genymotion Shell is insufficient
@Test
fun testShakeDetection() {
    // Use SensorManager test APIs or custom test doubles
    // to inject accelerometer events programmatically
}
```

**Option 3 — Device Link**: Connect a physical device and physically manipulate it. Best for manual QA validation of motion-heavy features (AR, compass, games).

### Testing Patterns

- **Compass app testing**: Use discrete rotation angles (0=North, 90=East, 180=South, 270=West) via `rotation setangle` and verify compass heading display
- **Tilt-based UI**: Mock SensorManager in instrumented tests to inject pitch/roll values for tilt-responsive features
- **Shake detection**: Mock accelerometer events programmatically — GUI manipulation is not automatable

---

## Device Link (v3.8.0+, Paid)

Device Link provides three capabilities using a physical Android device as an emulation companion:

| Feature | Description |
|---------|-------------|
| **Motion sensor forwarding** | Forward accelerometer, gyroscope, and magnetometer data from the physical device to the emulator |
| **Touch forwarding** | Forward touch events from the physical device screen to the emulator |
| **Screen mirroring** | Mirror the emulator display onto the physical device screen |

Each capability can be independently enabled/disabled. Setup requires USB-connected physical device with USB debugging enabled, then linking via the Motion Sensors widget GUI.

**Use cases**: QA testing with natural gestures (touch forwarding), AR/VR prototyping (motion forwarding), demo recording (screen mirroring).

**Automation**: Device Link is **GUI-only** — no Genymotion Shell commands exist. For automated sensor input, use discrete `rotation setangle` commands or mock SensorManager in test code (see Motion Sensors section above).

---

## Biometrics (v3.6.0+, Android 13+, Paid)

The Biometrics widget simulates fingerprint recognition scenarios for testing `BiometricPrompt` and fingerprint-gated features. GUI-only — requires fingerprint enrollment via device Settings before use.

### Fingerprint Scenarios

| Scenario | Behavior | Testing Use Case |
|----------|----------|-----------------|
| **Recognized** | Fingerprint matches enrolled print | Happy path authentication |
| **Unrecognized** | Fingerprint does not match | Error handling, retry prompts, lockout after N failures |
| **Dirty** | Sensor reports dirty finger | Sensor cleaning prompt |
| **Partial** | Only partial fingerprint captured | Repositioning guidance |
| **Insufficient** | Quality too low for recognition | Quality feedback to user |
| **Too Fast** | Finger removed before capture completes | "Hold finger longer" messaging |

### Automation (Recommended for CI)

Biometrics are **GUI-only** — no Genymotion Shell commands exist. Use `BiometricPrompt` test APIs:

```kotlin
// Use AndroidX Biometric testing library
androidTestImplementation("androidx.biometric:biometric:1.2.0-alpha05")

// In test code, use the CryptoObject mock or
// BiometricPrompt.AuthenticationCallback test doubles
```

**Graceful degradation**: Test on Android 12 image (biometrics widget unavailable) to verify the app falls back to PIN/password authentication.

---

## Camera and Media Injection (v3.3.0+, Paid)

The Camera widget replaces the virtual device's camera and microphone inputs with host webcam, image files, or video files (front/back independently). GUI-only — not available via Genymotion Shell. Camera input settings persist across reboots since v3.6.0.

### Media File Storage Paths

Media files placed in these directories are available in the injection widget:

| OS | Path |
|----|------|
| Windows | `%LOCALAPPDATA%\Genymobile\Genymotion\media` |
| Linux | `$HOME/.Genymobile/Genymotion/media` |
| macOS | `$HOME/Applications/Genymotion.app/Contents/MacOS/media` |

### Testing Patterns (Automatable)

**ADB push for camera images:**
```bash
# Push a QR code image to the device storage
adb push qr_code.png /sdcard/DCIM/Camera/
# The app can then open the image from storage
```

**Mocking CameraX/Camera2 in tests** (recommended for CI):
```kotlin
// Use CameraX test utilities or mock the camera provider
// to inject test images programmatically in instrumented tests
```

**Limitation**: No depth data (LiDAR/ToF) — AR features requiring depth cannot be tested on Genymotion.

---

## Gamepad (v3.8.0+, Android 12+, Paid)

The Gamepad feature forwards host-connected game controllers (Xbox 360, PS5 DualSense on macOS/Linux, generic USB) to the Android emulator. Controllers appear as standard Android gamepad input devices. GUI-only — no shell commands.

### Automation via ADB

```bash
# Simulate gamepad button press via ADB input
adb shell input keyevent KEYCODE_BUTTON_A    # A button
adb shell input keyevent KEYCODE_BUTTON_B    # B button
adb shell input keyevent KEYCODE_BUTTON_X    # X button
adb shell input keyevent KEYCODE_BUTTON_Y    # Y button
adb shell input keyevent KEYCODE_DPAD_UP     # D-pad up
adb shell input keyevent KEYCODE_DPAD_DOWN   # D-pad down
adb shell input keyevent KEYCODE_DPAD_LEFT   # D-pad left
adb shell input keyevent KEYCODE_DPAD_RIGHT  # D-pad right
```

**Accessibility testing**: D-pad navigation uses the same input events as gamepad D-pad — verify app support for users with external controllers.
