# Phone and SMS

The Phone widget simulates incoming calls and text messages. Messages appear as notifications and in the Messaging app.

> **Cross-references:** For sensor persistence rules, see `sensor-management.md`. For feature availability, see `index.md`. For GSM voice/data state, see also `network.md` Baseband section.

## Basic Commands

```bash
# Incoming call (shows call screen with caller number)
phone call "+1234567890"

# Incoming SMS (appears in notification and Messaging app)
phone sms "+1234567890" "Your OTP is 123456"
```

## Baseband GSM Control (Advanced)

For fine-grained telephony simulation:

**Call management:**
```bash
phone baseband gsm call <number>      # Create incoming call
phone baseband gsm accept <number>    # Answer call
phone baseband gsm hold <number>      # Place on hold
phone baseband gsm busy <number>      # Mark as busy (caller hears busy tone)
phone baseband gsm cancel <number>    # Hang up
phone baseband gsm list               # List all active calls
phone baseband gsm status             # GSM registration status
```

**Voice and data registration:**
```bash
phone baseband gsm voice home         # Normal home network
phone baseband gsm voice roaming      # Roaming state
phone baseband gsm voice searching    # Searching for network
phone baseband gsm voice denied       # Registration denied
phone baseband gsm voice unregistered # Not registered
phone baseband gsm voice off          # Radio off

phone baseband gsm data home          # Data connected
```

**Signal quality:**
```bash
phone baseband gsm signal rssi <0-31>      # Signal strength (0=weak, 31=strong)
phone baseband gsm signal ber <0-7>        # Bit error rate (% — lower is better)
phone baseband gsm signal rs_snr <-200 to 300>  # Signal-to-noise ratio
```

**RSSI to signal bars mapping:**
| RSSI | Signal Quality | Approx. dBm | UI Bars |
|------|---------------|-------------|---------|
| 0-6 | Very poor | < -100 | 0-1 |
| 7-12 | Poor | -100 to -90 | 1-2 |
| 13-18 | Moderate | -90 to -80 | 2-3 |
| 19-24 | Good | -80 to -70 | 3-4 |
| 25-31 | Excellent | > -70 | 4-5 |

**CDMA (if applicable):**
```bash
phone baseband cdma ssource nv|ruim    # Subscription source
phone baseband cdma prl_version <val>  # PRL version
```

**SMS in PDU format:**
```bash
phone baseband sms send <number> "message"   # Standard SMS
phone baseband sms pdu <hex_string>           # Raw PDU format (for protocol testing)
```

## Testing Patterns

**OTP/SMS verification flow:**
```bash
# Start the app's login/verification flow, then:
genyshell -q -c 'phone sms "+15551234567" "Your verification code is 847291"'
# Verify: app auto-reads SMS, extracts code, proceeds with verification
```

**Call interruption handling:**
```bash
# While the app is performing a critical operation:
genyshell -q -c 'phone call "+15559876543"'
sleep 10  # Wait for call screen
genyshell -q -c 'phone baseband gsm cancel "+15559876543"'
# Verify: app resumes correctly after call ends, no data loss
```

**Signal degradation with call quality:**
```bash
genyshell -q -c "phone baseband gsm signal rssi 25"  # Good signal
sleep 5
genyshell -q -c "phone baseband gsm signal rssi 5"   # Very poor signal
# Verify: app shows connectivity warning if VoIP-based
```

**Limitation**: Genymotion cannot send or receive actual phone calls or SMS. All telephony is simulated — the notification and Messaging app receive the data, but no real network communication occurs.
