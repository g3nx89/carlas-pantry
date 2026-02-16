# GUI Walkthrough Instructions

Step-by-step instructions for Android device operations that have no CLI equivalent. The coding agent should read this file when it needs to guide the user through manual GUI operations on a physical device or emulator.

> **Cross-references:** For CLI-actionable device setup commands, see `device-setup-oem.md`. For ADB connection management, see `adb-connection-apps.md`.

## When to Use This File

Read this file when a task requires one of the following GUI-only operations. Relay the numbered steps directly to the user — these operations cannot be automated via ADB or shell commands.

---

## Developer Options: Initial Enable

**Prerequisite**: Physical Android device or emulator with locked Developer Options.

1. Open **Settings > About Phone** (some devices: **Settings > About Device** or **Settings > System > About Phone**)
2. Scroll to **Build number**
3. Tap **Build number** 7 times in quick succession
4. Enter the device PIN/pattern if prompted
5. A toast message confirms: **"You are now a developer!"**
6. Developer Options now appears under **Settings > System > Developer options** (or **Settings > Developer options** on some OEMs)

**Samsung variant**: Settings > About Phone > Software Information > Build number (7 taps).

**Xiaomi variant**: Settings > About Phone > MIUI version (7 taps).

The agent can verify Developer Options is enabled with:

```bash
adb shell settings get global development_settings_enabled   # Returns "1" when enabled
```

---

## USB Debugging: Enable

**Prerequisite**: Developer Options already enabled (see section above).

1. Open **Settings > System > Developer options**
2. Toggle **USB debugging** to ON
3. Confirm the security warning dialog

After enabling, connect the device via USB cable. The agent can verify with:

```bash
adb devices   # Should show device serial with "device" state
```

---

## RSA Key Authorization

**Prerequisite**: USB debugging enabled, device connected via USB.

When connecting a new host computer for the first time, the device shows an RSA fingerprint dialog.

1. Ensure the device screen is **unlocked** (dialog appears only when screen is on and unlocked)
2. A dialog appears: **"Allow USB debugging?"** with the host RSA key fingerprint
3. Check **"Always allow from this computer"** to persist authorization
4. Tap **Allow**

**Troubleshooting** (if device shows "unauthorized" in `adb devices`):
1. Check device screen for pending RSA dialog (screen must be unlocked)
2. If no dialog: toggle USB debugging OFF and ON in Developer Options
3. If still stuck: go to Developer Options > **Revoke USB debugging authorizations**, then reconnect

---

## ADB Authorization Timeout: Disable

**Prerequisite**: Developer Options enabled, Android 11+.

Even with "Always allow," RSA authorization expires after 7 days by default.

1. Open **Settings > System > Developer options**
2. Scroll to **Disable ADB authorization timeout**
3. Toggle it ON

Essential for self-hosted CI runners with physical devices — prevents authorization from expiring between CI runs.

---

## Wireless Debugging: Enable and Pair

**Prerequisite**: Developer Options enabled, Android 11+, device on same WiFi network as host.

### First-Time Pairing

1. Open **Settings > System > Developer options**
2. Toggle **Wireless debugging** to ON
3. Tap **Wireless debugging** (the text, not the toggle) to enter its settings
4. Tap **Pair device with pairing code**
5. Note the **IP address:port** and **6-digit pairing code** displayed on screen
6. Relay these to the agent for the pairing command:

```bash
adb pair <IP>:<PAIRING_PORT>    # Enter the 6-digit code when prompted
```

### Connecting After Pairing

1. In the Wireless debugging settings, note the **IP address and port** shown at the top (this is the CONNECTION port, different from the pairing port)
2. Relay to the agent:

```bash
adb connect <IP>:<CONNECTION_PORT>
```

**Important**: The pairing port and connection port are different. The pairing port appears only in the "Pair device" dialog; the connection port appears on the main Wireless debugging screen.

---

## Samsung: Disable Aggressive Battery Optimization

**Prerequisite**: Samsung device with OneUI.

Samsung's "Sleeping apps" and "Deep sleeping apps" lists aggressively kill background processes, breaking test runs.

1. Open **Settings > Battery and device care > Battery**
2. Tap **Background usage limits**
3. Tap **Never sleeping apps**
4. Tap **+ Add** and select the test app package
5. Confirm the addition

Alternative path on older OneUI versions:
1. Open **Settings > Apps > [Your App]**
2. Tap **Battery**
3. Select **Unrestricted**

---

## Xiaomi: Enable Required Developer Toggles

**Prerequisite**: Xiaomi device with MIUI/HyperOS, Developer Options enabled.

Xiaomi requires additional toggles beyond standard USB debugging. Without these, ADB installs may be blocked or require manual confirmation on every install.

### Install via USB

1. Open **Settings > Additional Settings > Developer options**
2. Scroll to **Install via USB**
3. Toggle ON (may require signing in with a Mi Account)
4. If prompted, sign in and verify

### USB Debugging (Security Settings)

1. In the same Developer Options screen
2. Find **USB debugging (Security settings)**
3. Toggle ON
4. Confirm the security warning

### Disable MIUI Optimization (Optional)

Disabling MIUI Optimization restores standard Android behavior, reducing OEM-specific test interference.

1. In Developer Options, scroll to the bottom
2. Find **Turn off MIUI optimizations** (or **MIUI optimization**)
3. Toggle OFF (disabling the optimization)
4. Confirm the restart dialog — the device will reboot

**Note**: After disabling MIUI Optimization, `adb install` should work without per-install confirmation popups.

---

## Huawei: Disable Aggressive App Launch Management

**Prerequisite**: Huawei device with EMUI/HarmonyOS.

Huawei's power management aggressively kills background apps by default.

1. Open **Settings > Battery > App launch** (or **Settings > Battery > Power-intensive app monitor** on newer versions)
2. Find the test app in the list
3. Toggle OFF the automatic management switch
4. In the dialog that appears, ensure all three options are enabled:
   - **Auto-launch**
   - **Secondary launch**
   - **Run in background**
5. Tap **OK**

---

## Knox Restrictions: Samsung Enterprise Devices

**Prerequisite**: Samsung device with Knox security enabled (common on carrier/enterprise devices).

Knox can block ADB installs entirely. If `adb install` fails with permission errors on a Samsung device:

1. Open **Settings > Biometrics and security > Device admin apps** (or **Device administrators**)
2. Check if any Knox or MDM policies are active
3. If the device is enterprise-managed, ADB install restrictions may require IT admin intervention — this cannot be bypassed from CLI

**Limitation**: Knox policy enforcement is not removable via ADB. If Knox blocks installs, the only options are: (a) contact IT admin, (b) use a non-Knox device for development.
