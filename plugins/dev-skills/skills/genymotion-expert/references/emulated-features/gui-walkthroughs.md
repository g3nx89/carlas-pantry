# GUI Walkthrough Instructions

Step-by-step GUI instructions for Genymotion Desktop features that have no CLI equivalent. The coding agent should read this file when it needs to guide the user through manual GUI operations.

> **Cross-references:** For automation alternatives, see `gui-features.md` (motion, biometrics, camera, gamepad, device link), `network.md` (baseband GSM state), and `controls-and-tools.md` (clipboard). For feature availability, see `index.md`.

## When to Use This File

Read this file when a task requires one of the following GUI-only operations. Relay the numbered steps directly to the user — these operations cannot be automated via Genymotion Shell, GMTool, or ADB.

---

## Biometrics: Fingerprint Enrollment

**Prerequisite**: Android 13+ image, Paid license, Biometrics widget visible in toolbar.

1. Open **Settings > Security & Privacy** in the emulator
2. Set up a screen lock (PIN or pattern) if not already configured
3. Navigate to **Fingerprint** and tap **Add fingerprint**
4. In the Genymotion toolbar, open the **Biometrics** widget and click to simulate a finger touch during enrollment
5. Repeat step 4 until enrollment completes (typically requires multiple simulated touches)

**Shortcut**: Toggle **Automatically validate biometric authentication** in the Biometrics widget to auto-respond with "Recognized" during enrollment, reducing it to a single step.

---

## Biometrics: Testing Scenarios

After fingerprint enrollment is complete, use the Biometrics widget to trigger scenarios during app testing.

**Authentication flow:**
1. Launch the app feature requiring biometric auth
2. Wait for the `BiometricPrompt` dialog to appear on screen
3. In the Biometrics widget, click the desired scenario (Recognized, Unrecognized, Dirty, Partial, Insufficient, or Too Fast)
4. Verify the app handles the result correctly (success, error message, retry prompt)

**Lockout testing:**
1. Trigger multiple **Unrecognized** clicks in sequence (typically 5)
2. Verify the app shows the lockout message after the system threshold
3. Verify fallback to PIN/password is offered

**Graceful degradation:**
1. Test on Android 12 image (Biometrics widget unavailable) — verify the app falls back to PIN/password
2. Test on Android 13+ with the Biometrics widget for the full biometric flow

---

## Camera: Input Source Configuration

**Prerequisite**: v3.3.0+, Paid license, Camera widget visible in toolbar.

Open the **Camera** widget in the Genymotion toolbar to assign input sources:

**Video input sources** (assignable independently to front and back camera):

| Source | Notes |
|--------|-------|
| Host webcam | Any connected UVC-compatible webcam |
| Image file | Static image displayed as camera feed |
| Video file | Plays as live camera feed |

**Audio input sources:**

| Source | Notes |
|--------|-------|
| Host microphone | Default system mic |
| Audio file | Plays as microphone input |

**Resize modes** (when injected media doesn't match camera resolution):

| Mode | Behavior | Best For |
|------|----------|----------|
| **Crop** | Fills frame, clips overflow | QR code scanning (image fills viewport) |
| **Keep Aspect** | Fits within frame, letterboxed | General testing (no distortion) |
| **Resize** | Stretches to fill frame | When exact resolution match matters |

Camera input settings persist across reboots since v3.6.0.

---

## Camera: Prerequisites and Troubleshooting

**Webcam requirements:**
- **UVC standard required**: Host webcams must support USB Video Device Class (UVC). Non-UVC webcams may not be detected
- **Virtual webcams NOT supported**: OBS Virtual Camera and similar software cameras are not compatible with Genymotion's camera API
- **Multi-webcam**: Multiple connected webcams can each be independently assigned to front or back camera

**`FEATURE_CAMERA` troubleshooting:**
- Apps check `PackageManager.hasSystemFeature(FEATURE_CAMERA)` for camera availability
- Returns `true` when camera/media injection is configured and connected
- May return `false` if the host webcam was unavailable at VM startup (e.g., in use by another app)
- **Fix**: Close other apps using the webcam, then restart the VM

**Codec requirements:**
- **Linux/macOS**: Most video/audio formats work out of the box
- **Windows**: Genymotion does not bundle codecs. Install K-Lite Codec Pack Full (codecguide.com) or equivalent

---

## Camera: Testing Walkthroughs

All camera testing requires input source configuration first (see section above).

**QR code / barcode scanning:**
1. Save the QR code as a PNG file
2. Place it in the media directory: macOS `$HOME/Applications/Genymotion.app/Contents/MacOS/media`, Linux `$HOME/.Genymobile/Genymotion/media`, Windows `%LOCALAPPDATA%\Genymobile\Genymotion\media`
3. In the Camera widget, assign the PNG to the **back camera**
4. Select **Crop** resize mode for full-frame display
5. Open the app's scanner — the QR code image appears as the camera feed

**Facial recognition:**
1. Prepare a face image matching your test dataset
2. In the Camera widget, assign to **front camera** with **Keep Aspect** mode
3. Launch the app's face detection flow

**AR app testing:**
1. Assign a video file showing a real-world surface to the **back camera**
2. Test marker detection and overlay rendering
3. **Limitation**: No depth data (LiDAR/ToF) — AR features requiring depth cannot be tested

**Voice command testing:**
1. Record command audio files (WAV or MP3)
2. In the Camera widget, assign as **microphone input**
3. Launch the app's speech recognition feature and verify command processing

---

## Baseband: MCC/MNC Configuration

**Prerequisite**: v3.5.0+, Paid license, Baseband widget visible in toolbar.

### Setting up a roaming simulation

1. Open the **Baseband** widget in the Genymotion toolbar
2. Under **SIM Operator**, set the MCC/MNC to the user's home country (e.g., MCC `310`, MNC `260` for T-Mobile US)
3. Under **Network Operator**, set the MCC/MNC to a **different** country (e.g., MCC `222`, MNC `01` for TIM Italy)
4. Set the **Operator Name** fields to match (e.g., SIM: "T-Mobile", Network: "TIM")
5. Verify the app shows a roaming indicator, reduces data usage, or switches to offline-first mode

### Changing carrier identity for multi-carrier testing

1. Open the **Baseband** widget
2. Under **Network Operator**, change the **MCC**, **MNC**, and **Operator Name** to the target carrier
3. Verify the app handles carrier-specific features (Wi-Fi calling labels, operator-branded notifications)

### Field reference

| Field Group | Field | Description | Example |
|-------------|-------|-------------|---------|
| Network Operator | MCC | Mobile Country Code | 310 (US), 222 (Italy), 208 (France) |
| Network Operator | MNC | Mobile Network Code | 260 (T-Mobile US), 01 (TIM), 01 (Orange) |
| Network Operator | Operator Name | Display name | "T-Mobile", "Vodafone" |
| SIM Operator | MCC/MNC | SIM issuer codes | Same format as network operator |
| SIM Operator | MSIN | Mobile Subscriber ID Number | Unique subscriber identifier |
| SIM Operator | Operator Name | SIM provider name | "AT&T", "Three" |
| SIM Operator | Phone Number | Simulated phone number | "+1234567890" |

**Limitation**: The simulated phone number is metadata only — it does not enable actual calls or SMS.

> **Note:** For automatable GSM voice/data state control (home, roaming, searching), see the Baseband section in `network.md`.

---

## Motion Sensors: Manual Controls

**Prerequisite**: v3.8.0+, Paid license, Motion Sensors widget visible in toolbar.

### Testing a compass or heading-based feature

1. Open the **Motion Sensors** widget in the Genymotion toolbar
2. Drag the **Yaw** slider to set compass heading: 0=North, 90=East, 180=South, 270=West
3. Verify the app's compass needle or heading display updates accordingly
4. Check the **Magnetometer** readout in the widget (uT) to confirm values change

### Testing tilt-based UI

1. Open the **Motion Sensors** widget
2. Adjust the **Pitch** slider (-180 to 180 degrees) to tilt forward/backward
3. Adjust the **Roll** slider (-180 to 180 degrees) to tilt left/right
4. Alternatively, drag the interactive **3D device model** to set orientation visually — slider values update in real-time
5. Check the **Accelerometer** readout (m/s^2) to verify tilt values

### Testing shake detection

1. Open the **Motion Sensors** widget
2. Rapidly drag the **3D device model** back and forth to simulate a shake gesture
3. The **Accelerometer** readout should spike during rapid movement
4. Verify the app triggers its shake-to-undo or shake-to-refresh action

### Enabling emulator window rotation sync

1. In the **Motion Sensors** widget, toggle **Enable emulator window rotation**
2. The emulator display now rotates to match the simulated orientation
3. Use this to verify orientation lock and responsive layout during physical-style rotation (vs discrete `rotation setangle` changes)

### Slider reference

| Axis | Range | Unit |
|------|-------|------|
| Yaw | -180 to 180 | degrees |
| Pitch | -180 to 180 | degrees |
| Roll | -180 to 180 | degrees |

### Sensor readouts (displayed in widget, update in real-time)

| Sensor | Measurement | Unit |
|--------|-------------|------|
| Accelerometer | Linear acceleration including gravity | m/s^2 |
| Gyroscope | Angular velocity | rad/s |
| Magnetometer | Magnetic field strength | uT |

---

## Device Link: Setup and Calibration

**Prerequisite**: v3.8.0+, Paid license, physical Android device with USB debugging enabled.

1. Connect the physical Android device to the host via USB cable
2. Ensure **USB debugging** is enabled on the physical device (Settings > Developer options)
3. In the Motion Sensors widget, click **Setup device link**
4. The physical device appears in the "Available devices" list — click **LINK DEVICE**
5. Once linked, the 3D model syncs with the physical device's orientation in real-time

**Calibration**: Hold the physical device steady during initial linking — the emulator calibrates its reference frame to the device's current orientation.

**Disconnection**: Click the linked device entry to unlink. Sensor values freeze at the last received state.

**Capabilities** (each independently toggleable after linking):
- **Motion sensor forwarding**: Physical device accelerometer/gyroscope/magnetometer → emulator
- **Touch forwarding**: Physical device touch events → emulator (tap, swipe, multi-touch)
- **Screen mirroring**: Emulator display → physical device screen

---

## Gamepad: Controller Setup

**Prerequisite**: v3.8.0+, Android 12+, Paid license, game controller connected to host.

**Controller compatibility:**

| Controller | Windows | macOS | Linux |
|-----------|---------|-------|-------|
| Xbox 360 | Yes | Yes | Yes |
| PS5 DualSense | No* | Yes | Yes |
| Generic USB | Yes | Yes | Yes |

*PS5 DualSense on Windows: Not natively recognized. Use third-party Xbox emulation tools (DS4Windows, DualSenseX) to make the PS5 controller appear as Xbox 360.

**Setup:**
1. Connect the game controller to the host machine
2. Open the **Gamepad** widget in the Genymotion toolbar
3. The connected controller appears in the widget — toggle **Enable** to activate
4. Open the game or app and test button mappings, analog sticks, and triggers

Controllers appear as standard Android gamepad input devices — apps using `InputDevice` and `KeyEvent.KEYCODE_BUTTON_*` work automatically.

---

## Clipboard: Sharing Toggle

Bidirectional clipboard sharing is **enabled by default**. To disable:

1. In Genymotion Desktop, go to **Genymotion > Settings > Global**
2. Toggle **Shared clipboard** off

**When to disable:**
- Security testing: prevent clipboard data leakage between host and device
- Testing app behavior when clipboard access is restricted

> **Note:** For automatable clipboard alternatives (ADB text input, ClipboardManager APIs), see the Clipboard section in `controls-and-tools.md`.
