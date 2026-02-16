# Emulated Features Index

Dispatch table for all emulated sensors and features in Genymotion Desktop. Use this file to identify which feature file to read, check feature availability, and choose the right testing approach.

> **Note:** For the complete Genymotion Shell and GMTool command syntax, see `cli-reference.md`. For CI/CD recipes using these features, see `ci-and-recipes.md`.

## Feature Availability Matrix

Not all features are available on all versions or license tiers. Use this matrix to verify availability before relying on a feature.

| Feature | Min Version | License Required | Android Req | Shell Commands |
|---------|------------|-----------------|-------------|----------------|
| GPS | All | Free | All | Yes |
| Battery | All | Free | All | Yes |
| Rotation | All | Free | All | Yes |
| Device Identity | All | Free | All | Yes |
| Network (WiFi/Mobile) | 3.3.0+ | Paid | 8.0+ (full) | Yes |
| Baseband (SIM/operator) | 3.5.0+ | Paid | All | No (GUI only) |
| Camera/Media Injection | 3.3.0+ | Paid | All | No (GUI only) |
| Disk I/O Throttling | 3.3.0+ | Paid | All | Yes |
| Phone/SMS | All | Free | All | Yes |
| Advanced Developer Tools | 3.4.0+ | Paid | All | No (GUI only) |
| Biometrics (Fingerprint) | 3.6.0+ | Paid | 13+ | No (GUI only) |
| Gamepad | 3.8.0+ | Paid | 12+ | No (GUI only) |
| Motion Sensors | 3.8.0+ | Paid | All | No (GUI only) |
| Device Link | 3.8.0+ | Paid | All | No (GUI only) |
| Clipboard | All | Free | All | No (built-in) |
| File Upload / Drag-and-Drop | All | Free | All | No (use ADB push) |
| Sound Volume | All | Free | All | No (use ADB) |
| Capture (Screenshot/Video) | All | Free | All | No (use ADB) |

**Key**: "Shell Commands" = automatable via `genyshell`. Features marked "GUI only" require the Genymotion Desktop UI widgets and cannot be scripted through Genymotion Shell. For automation of GUI-only features, use ADB alternatives where available (noted per feature below).

### Programmatic Feature Detection

Use `genymotion capabilities` in the Genymotion Shell to query which features are available on the current device as JSON. Useful in CI scripts to conditionally skip tests when a feature is unavailable (e.g., camera on free license, baseband on older images). See **Shell Utility Commands** below for the full output format and a CI gating example.

### Feature File Map

| File | Contents |
|------|----------|
| `gps.md` | GPS and Location (route simulation, testing patterns) |
| `battery.md` | Battery (modes, states, thresholds, shell patterns) |
| `network.md` | Network + Baseband (profiles, signal, GSM state) |
| `phone-sms.md` | Phone/SMS (basic + baseband GSM, RSSI, testing) |
| `device-config.md` | Device Identity + Disk I/O + Rotation |
| `sensor-management.md` | Persistence rules, reset scripts, conflicts |
| `gui-features.md` | Motion Sensors + Biometrics + Camera + Gamepad + Device Link |
| `gui-walkthroughs.md` | Step-by-step GUI instructions for operations without CLI alternatives |
| `controls-and-tools.md` | Advanced Dev Tools + Capture + Controls + Clipboard + File Upload + Open GApps |

---

## Testing Strategy by Feature

Decision matrix for choosing the right testing approach per feature.

| Feature | Genymotion Emulation | Mock in Test Code | Physical Device |
|---------|---------------------|-------------------|-----------------|
| GPS position | Best (full Shell control) | Overkill | Unnecessary |
| GPS route playback | Good (GUI or scripted) | N/A | Unnecessary |
| Battery states | Best (full Shell control) | Overkill | Impractical |
| Network profiles | Best (full Shell control) | Overkill | Impractical |
| Network offline | Best (Shell toggle) | Also good | Impractical |
| Discrete rotation | Best (Shell control) | N/A | Unnecessary |
| Continuous motion | Good (GUI only, v3.8.0+) | Better for CI | Best for accuracy |
| Fingerprint auth | Good (GUI only, v3.6.0+) | Better for CI | Best for full TEE |
| Camera (static image) | Good (GUI injection) | Also good | Unnecessary |
| Camera (live video) | Limited (host webcam) | Mock CameraX | Better |
| Phone calls/SMS | Good (Shell control) | Also good | Unnecessary |
| Disk I/O throttling | Best (Shell control) | N/A | Varies by device |
| Clipboard sharing | Good (built-in) | N/A | Equivalent |
| File upload/install | Good (drag-and-drop) | N/A | Equivalent |
| Bluetooth | Not available | Required | Best |
| NFC | Not available | Required | Best |
| SafetyNet/Play Integrity | Not available | Mock for dev | Required for prod |
| Widevine DRM | Not available (L3 only) | N/A | Required (L1) |
| Thermal behavior | Not available | Mock PowerManager | Varies |
| Barometer/proximity | Not available | Mock SensorManager | Best |

---

## Shell Utility Commands

Genymotion Shell commands for diagnostics and maintenance:

```bash
genymotion capabilities       # JSON of available features on current device
genymotion version            # Genymotion application version
genymotion license            # Current license type and status
genymotion clearcache         # Clear temporary files and logs
devices list                  # List all virtual devices with status/IP
devices ping                  # Check if current device is responsive
devices refresh               # Refresh device list
```

**`genymotion capabilities` output example:**
```json
{
  "accelerometer": true,
  "baseband": true,
  "battery": true,
  "camera": true,
  "deviceid": true,
  "diskio": true,
  "gps": true,
  "network": true,
  "remote_control": true,
  "screencast": true
}
```

Use `capabilities` in CI to gate feature-dependent tests:
```bash
# Skip camera tests if camera is not available (free license)
HAS_CAMERA=$(genyshell -q -c "genymotion capabilities" | python3 -c "import sys,json; print(json.load(sys.stdin).get('camera', False))")
if [ "$HAS_CAMERA" = "True" ]; then
    ./gradlew connectedDebugAndroidTest \
      -Pandroid.testInstrumentationRunnerArguments.annotation=com.example.test.CameraTest
fi
```
