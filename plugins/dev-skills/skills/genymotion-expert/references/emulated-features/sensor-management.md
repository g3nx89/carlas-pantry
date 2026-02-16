# Sensor State Management

Understanding how sensor state persists and resets is critical for reliable testing.

> **Cross-references:** This file is referenced by all per-feature files for persistence behavior. For the complete reset script in CI context, see also `ci-and-recipes.md` Recipe 2.

## Persistence Rules

| Event | GPS | Battery | Network | Rotation | Identity | Disk I/O | Camera* |
|-------|-----|---------|---------|----------|----------|----------|---------|
| App restart | Persists | Persists | Persists | Persists | Persists | Persists | Persists |
| Device reboot | Resets | Resets | Resets | Resets | Persists | Resets | Persists |
| Factory reset | Resets | Resets | Resets | Resets | Resets | Resets | Resets |
| VM stop/start | Resets** | Resets** | Resets** | Resets** | Persists | Resets** | Persists |

*Camera input settings persist across reboots since v3.6.0.

**Quick Boot may preserve some state if the VM was not cleanly shut down.

## Default Values After Boot

| Sensor | Default |
|--------|---------|
| GPS | Disabled, 0/0 coordinates |
| Battery | Host mode (mirrors host) |
| Network | WiFi enabled, great signal |
| Rotation | 0 (portrait) |
| Android ID | Generated on first boot |
| Device ID | `000000000000000` |
| Disk I/O | Unlimited (0) |
| Camera | Not configured (no input source) |
| Clipboard | Enabled (bidirectional) |

## Factory Reset via Shell

For a complete reset to initial device state (removes all user data, apps, and settings):

```bash
# Interactive (prompts for confirmation)
genyshell -q -c "devices factoryreset <device_ID>"

# Force (no confirmation — use in CI)
genyshell -q -c "devices factoryreset <device_ID> force"
```

**Warning**: Factory reset is destructive and requires a reboot. Use the lighter reset script below for between-suite cleanup.

## Reset Script for Test Suites

Run between test suites to ensure clean state:

```bash
#!/usr/bin/env bash
GENYSHELL="${GENYMOTION_PATH:-/opt/genymotion}/genymotion-shell"
"$GENYSHELL" -q -c "gps setstatus disabled"
"$GENYSHELL" -q -c "battery setmode host"
"$GENYSHELL" -q -c "network setstatus wifi enabled"
"$GENYSHELL" -q -c "network setstatus mobile disabled"
"$GENYSHELL" -q -c "network setsignalstrength wifi great"
"$GENYSHELL" -q -c "network setmobileprofile none"
"$GENYSHELL" -q -c "rotation setangle 0"
"$GENYSHELL" -q -c "diskio setreadratelimit 0"
```

## Potential Conflicts

| Conflict | Behavior |
|----------|----------|
| WiFi disabled + mobile disabled | Complete offline — no connectivity |
| WiFi enabled + mobile enabled | WiFi takes priority (standard Android behavior) |
| Battery mode host + setlevel | `setlevel` ignored in host mode — switch to manual first |
| GPS enabled + no coordinates set | Apps receive 0,0 (Null Island, Gulf of Guinea) |
