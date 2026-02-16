# Network and Baseband

Network simulation (v3.3.0+, paid) for WiFi and mobile data interfaces, plus Baseband (v3.5.0+, paid) for SIM card and operator data.

> **Cross-references:** For sensor persistence rules and reset scripts, see `sensor-management.md`. For feature availability, see `index.md`. For network degradation recipe, see `ci-and-recipes.md` Recipe 6.

## Interface Control

```bash
# Toggle interfaces
network setstatus wifi enabled|disabled
network setstatus mobile enabled|disabled

# Signal strength per interface
network setsignalstrength wifi|mobile none|poor|moderate|good|great
```

## Mobile Network Profiles

| Profile | Download | Upload | Latency | Packet Loss | Use Case |
|---------|----------|--------|---------|-------------|----------|
| `gsm` (2G) | 14 Kb/s | 14 Kb/s | 500ms | 0% | Extreme degradation testing |
| `gprs` (2G) | 57 Kb/s | 28 Kb/s | 300ms | 0% | Minimal data connectivity |
| `edge` (2G) | 236 Kb/s | 236 Kb/s | 75ms | 0% | Slow mobile testing |
| `umts` (3G) | 384 Kb/s | 384 Kb/s | 75ms | 0% | Standard 3G experience |
| `hsdpa` (3G+) | 13.98 Mb/s | 5.76 Mb/s | 0ms | 10% | Fast 3G with packet loss |
| `lte` (4G) | 173 Mb/s | 58 Mb/s | 5ms | 0% | Modern mobile baseline |
| `5g` | 1174 Mb/s | 211 Mb/s | 5ms | 0% | High-speed mobile |

```bash
network setmobileprofile none|gsm|gprs|edge|umts|hsdpa|lte|5g
```

## Legacy API (Android 7.1 and below)

```bash
network setprofile no-data|gprs|edge|3g|4g|4g-high-losses|4g-bad-dns|wifi
```

## Signal Strength Levels

| Level | Meaning | UI Effect |
|-------|---------|-----------|
| `great` | Excellent signal | Full bars |
| `good` | Normal signal | 3-4 bars |
| `moderate` | Degraded | 2 bars |
| `poor` | Weak | 1 bar |
| `none` | No signal | 0 bars, may show "No Service" |

## Testing Patterns

**Offline mode:**
```bash
genyshell -q -c "network setstatus wifi disabled"
genyshell -q -c "network setstatus mobile disabled"
# Verify: offline banner, cached data, retry mechanisms
```

**WiFi to mobile handoff:**
```bash
genyshell -q -c "network setstatus wifi enabled"
genyshell -q -c "network setsignalstrength wifi great"
sleep 5
genyshell -q -c "network setstatus wifi disabled"
genyshell -q -c "network setstatus mobile enabled"
genyshell -q -c "network setmobileprofile lte"
# Verify: seamless transition, no data loss, UI update
```

**Limitation**: Mobile data is simulated at the interface level — no real baseband or SIM data connection. The network profile controls bandwidth shaping but not actual radio behavior. Sufficient for testing UI states and basic connectivity logic, but not radio-level behavior.

---

## Baseband (v3.5.0+, Paid)

The Baseband widget simulates SIM card and network operator data (MCC/MNC, operator name, SIM info, phone number). GUI-only — not available via Genymotion Shell. Roaming can be simulated via GUI (different MCC/MNC for network vs SIM operator) or via the automatable genyshell commands below.

### ADB Alternative (Automatable)

For basic GSM state control:
```bash
# Voice registration state (home, roaming, searching, denied)
genyshell -q -c "phone baseband gsm voice roaming"
genyshell -q -c "phone baseband gsm voice home"

# Data registration state
genyshell -q -c "phone baseband gsm data home"
```

**Limitation**: Virtual devices do not have a real phone number. The simulated phone number in the Baseband widget is metadata only — it does not enable actual calls or SMS.
