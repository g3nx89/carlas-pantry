# Genymotion Expert — Reference Files

## File Usage

| File | Lines | Size | Purpose | When to Read |
|------|-------|------|---------|--------------|
| `emulated-features/index.md` | 121 | ~5K | Feature Availability Matrix, Testing Strategy decision matrix, Shell Utility Commands, feature file dispatch table | Checking which features exist, choosing test approach, feature detection |
| `emulated-features/gps.md` | 93 | ~4K | GPS parameters, route simulation (GPX/KML), geofencing and bearing testing patterns | GPS coordinates, route playback, location testing |
| `emulated-features/battery.md` | 61 | ~2K | Battery modes, states, critical thresholds, drain/charge scripts | Battery level simulation, power state testing |
| `emulated-features/network.md` | 90 | ~4K | Network interface control, mobile profiles (2G-5G), signal strength, Baseband GSM state | WiFi/mobile simulation, offline testing, roaming |
| `emulated-features/phone-sms.md` | 98 | ~4K | Phone calls, SMS, baseband GSM call management, RSSI/signal quality | OTP testing, call interruption, telephony simulation |
| `emulated-features/device-config.md` | 162 | ~6K | Device Identity (Android ID, IMEI), Disk I/O Throttling, Rotation | Device fingerprinting, storage performance testing, orientation |
| `emulated-features/sensor-management.md` | 72 | ~3K | Persistence rules, default values, factory reset, reset script, potential conflicts | Between-suite cleanup, understanding state lifecycle |
| `emulated-features/gui-features.md` | 144 | ~5K | Motion Sensors, Biometrics, Camera/Media Injection, Gamepad, Device Link | GUI-only features and their automation alternatives |
| `emulated-features/gui-walkthroughs.md` | 270 | ~11K | Step-by-step GUI instructions for Biometrics, Camera, Baseband, Motion Sensors, Device Link, Gamepad, Clipboard | Guiding user through GUI-only operations that have no CLI equivalent |
| `emulated-features/controls-and-tools.md` | ~230 | ~9K | Advanced Developer Tools, Capture, Android Controls, Other Controls, Clipboard, File Upload, Google Play Services (Open GApps) installation guide | ADB alternatives for dev tools, media controls, file transfer, GApps installation |
| `cli-reference.md` | 417 | 15K | GMTool and Genymotion Shell complete command reference | Looking up specific commands, options, error codes, ARM translation, proxy setup |
| `ci-and-recipes.md` | ~595 | 19K | CI/CD integration patterns and workflow recipe scripts | Configuring CI pipelines, writing automation scripts, parallel testing |
| `test-integration.md` | ~446 | ~20K | Test framework integration, reliability patterns, and ADB patterns | Setting up Espresso, Compose, Maestro, Appium; diagnosing test flakiness |

## Cross-References Between Files

| Source File | References To | Topic |
|-------------|---------------|-------|
| `emulated-features/index.md` | All `emulated-features/*.md` files | Feature File Map dispatch table |
| `emulated-features/gps.md` | `sensor-management.md`, `ci-and-recipes.md` | Persistence rules, Recipe 5 GPX route playback |
| `emulated-features/gps.md` | `gui-features.md` | Motion Sensors for bearing (compass) alternatives |
| `emulated-features/network.md` | `sensor-management.md`, `ci-and-recipes.md`, `gui-walkthroughs.md` | Persistence rules, Recipe 6 network degradation, Baseband MCC/MNC GUI configuration |
| `emulated-features/gui-features.md` | `sensor-management.md`, `gui-walkthroughs.md` | Persistence rules for camera settings, step-by-step GUI instructions |
| `emulated-features/gui-walkthroughs.md` | `gui-features.md`, `network.md`, `controls-and-tools.md` | Automation alternatives, Baseband GSM commands, Clipboard ADB alternatives |
| `emulated-features/controls-and-tools.md` | `test-integration.md`, `cli-reference.md`, `ci-and-recipes.md`, `gui-walkthroughs.md` | Test Stability Checklist, GApps flash commands, Golden master pattern (Recipe 4), Clipboard toggle walkthrough |
| `emulated-features/sensor-management.md` | `ci-and-recipes.md` | Recipe 2 parallel testing with cleanup |
| `cli-reference.md` | `ci-and-recipes.md` | Boot-wait pattern used in CI recipes |
| `ci-and-recipes.md` | `cli-reference.md` | GMTool commands used in recipes |
| `test-integration.md` | `emulated-features/index.md` | Feature Availability Matrix and Testing Strategy |
| `test-integration.md` | `emulated-features/sensor-management.md` | Canonical sensor reset script |
| `test-integration.md` | `ci-and-recipes.md` | Recipe 2 for parallel testing |
| `test-integration.md` | `cli-reference.md` | Genymotion Shell sensor commands |
| `test-integration.md` | SKILL.md | Concurrent instance limits in Memory Overuse pattern |

## Canonical Definitions

The following definitions live in `SKILL.md` (the hub document) and should not be duplicated in reference files:

- **ABI Support Matrix** — which ABIs work on which platform
- **Hypervisor Layer Table** — default hypervisor per OS
- **Concurrent Instance Limits** — max instances per host RAM
- **Anti-Patterns Table** — common mistakes and corrections
- **Boot Wait Pattern** — canonical `wait_for_boot()` function in Quick Reference
