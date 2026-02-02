# Mobile-MCP Troubleshooting

## Common Issues

| Issue | Frequency | Solution | Status |
|-------|-----------|----------|--------|
| MCP error -32602 on multiple tools | HIGH | Use standard npx config, avoid custom paths | Setup fix |
| Screenshot dimension exceeds max size | MEDIUM | Restart Claude Code session | Open |
| iOS text entry unreliable | MEDIUM | Tap center of field, not first character | Open |
| Windows ADB path resolution | MEDIUM | Update to v0.0.35+ | Fixed |
| Foldable device screenshot failure | LOW | Update to v0.0.33+ | Fixed |

## Troubleshooting Checklist

1. **Device not found**
   - Verify emulator/simulator is running
   - Check `adb devices` (Android) or `xcrun simctl list devices` (iOS)
   - Ensure platform-tools in PATH

2. **Screenshot errors**
   - Restart Claude Code session
   - Check if image exceeds 2000px
   - Try `mobile_save_screenshot` to file instead

3. **Elements not detected**
   - Wait for app to fully load (3-5s)
   - Try scrolling to reveal elements
   - Fall back to screenshot if no accessibility labels

4. **Tap not registering**
   - Verify coordinates from fresh `mobile_list_elements_on_screen`
   - Add wait before tap (UI may still be animating)
   - Check element is actually clickable

5. **Text not entering**
   - Tap field first to ensure focus
   - Use `mobile_type_keys` after tap
   - On iOS: tap center of field, not first character

## Platform-Specific Issues

### iOS
- Requires macOS and Xcode (no workaround)
- v0.0.38+ auto-installs WebDriverAgent
- Text entry: tap center of field

### Android
- Set `$ANDROID_HOME` environment variable
- v0.0.35+ fixed Windows ADB path issues
- Non-ASCII/UTF-8 text input: Install ADBKeyBoard for Unicode character support
  - Standard Android keyboard may fail on emojis, CJK characters, special symbols
  - ADBKeyBoard: https://github.com/nickywhiff/ADBKeyBoard

### Both Platforms
- Screenshot >2000px: restart session
- Permission dialogs: pre-grant or handle in prompt

## Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "No devices found" | Emulator/simulator not running | Start device first |
| "App not installed" | Invalid bundleId | Verify package name |
| "Element not found" | Stale coordinates | Re-query elements |
| "Screenshot failed" | Dimension limits | Restart session |

## Resources

- **Wiki**: https://github.com/mobile-next/mobile-mcp/wiki
- **Slack**: http://mobilenexthq.com/join-slack
- **GitHub Issues**: https://github.com/mobile-next/mobile-mcp/issues
