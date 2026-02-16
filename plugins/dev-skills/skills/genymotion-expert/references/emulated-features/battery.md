# Battery

The Battery widget controls the power state reported to the Android system.

> **Cross-references:** For sensor persistence rules and reset scripts, see `sensor-management.md`.

## Modes

| Mode | Behavior |
|------|----------|
| `host` | Battery level and state mirror the host computer |
| `manual` | Full developer control over level and state |

## States

| State | Description | Testing Use Case |
|-------|-------------|-----------------|
| `discharging` | Battery draining, no power source | Background task throttling, JobScheduler behavior |
| `charging` | Connected to charger, actively charging | Data sync triggers, battery-optimized features re-enabling |
| `notcharging` | Power connected but not charging | Thermal management testing |
| `full` | Battery at 100%, power connected | Charge completion notifications |

## Critical Thresholds to Test

| Level | Android Behavior | What to Verify |
|-------|-----------------|----------------|
| 100% | Full charge | Charge complete notification |
| 15% | Low battery warning | App's power-saving mode activation |
| 5% | Critical battery | Feature degradation, data persistence |
| 1% | Imminent shutdown | Graceful state saving |
| 0% | Device may shut down | N/A (device behavior varies) |

## Shell Script Pattern

```bash
# Test progressive battery drain
for level in 100 75 50 25 15 10 5 1; do
    genyshell -q -c "battery setmode manual"
    genyshell -q -c "battery setlevel $level"
    genyshell -q -c "battery setstatus discharging"
    sleep 3
    # Capture app state at this level
    adb shell screencap "/sdcard/battery_${level}.png"
done

# Test charging transition
genyshell -q -c "battery setlevel 10"
genyshell -q -c "battery setstatus discharging"
sleep 3
genyshell -q -c "battery setstatus charging"
sleep 3
# Verify app re-enables features disabled at low battery
```

## ADB Verification

Confirm Genymotion Shell battery simulation is active:
```bash
adb shell dumpsys battery
# Look for: level, status, AC powered, USB powered
```
