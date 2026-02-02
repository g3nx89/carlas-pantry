# Mobile-MCP Tool Reference

## Device Management

### mobile_list_available_devices
Lists connected devices (simulators, emulators, physical).
- **Parameters**: `{}` (empty object required)
- **Returns**: `[{id, name, type, platform, state}]`

### mobile_use_device
Selects target device for subsequent operations.
- **Parameters**: `device` (device ID), `deviceType` ("emulator" | "simulator" | "physical")
- **Note**: Call after `mobile_list_available_devices` when multiple devices present

### mobile_get_screen_size
Returns screen dimensions in pixels.
- **Returns**: `{width, height}`

### mobile_get_orientation / mobile_set_orientation
Get or set portrait/landscape.
- **Parameters (set)**: `orientation` ("portrait" | "landscape")

## App Management

> **Parameter naming note**: `launch_app` uses `bundleId` while `terminate_app` uses `packageName` - both refer to the app identifier (e.g., "com.example.app"). This inconsistency exists in the mobile-mcp API.

### mobile_launch_app
- **Parameters**: `bundleId` (e.g., "com.instagram.android", "com.apple.mobilenotes")

### mobile_terminate_app
- **Parameters**: `packageName` (same value as bundleId)

### mobile_install_app / mobile_uninstall_app
- **Parameters**: `appPath` (install: .apk/.ipa/.app) | `bundleId` (uninstall)

### mobile_list_apps
- **Parameters**: `bundleId` (optional filter)

## Screen Interaction

### mobile_list_elements_on_screen (PRIMARY)
Returns UI elements with coordinates, text, accessibility properties.
```json
[{
  "type": "Button",
  "text": "Sign In",
  "accessibilityLabel": "Sign In Button",
  "bounds": {"x": 100, "y": 500, "width": 200, "height": 50},
  "clickable": true
}]
```
**Never cache** - screen content changes between actions.

### mobile_take_screenshot
Base64-encoded image. Use for verification or when accessibility unavailable.
**Known issue**: Screenshots >2000px may fail.

### mobile_save_screenshot
- **Parameters**: `filePath` (e.g., "/tmp/screen.png")

### mobile_click_on_screen_at_coordinates
- **Parameters**: `x`, `y` (pixels)
- **Best practice**: Calculate center of element bounds from `mobile_list_elements_on_screen`

### mobile_double_tap_on_screen
- **Parameters**: `x`, `y`

### mobile_long_press_on_screen_at_coordinates
- **Parameters**: `x`, `y`, `duration` (optional, ms)

### mobile_swipe_on_screen
- **Parameters**:
  - Coordinate mode: `startX`, `startY`, `endX`, `endY`, `duration` (optional)
  - Direction mode: `direction` ("up" | "down" | "left" | "right")
- **Scroll down**: `{startX: 540, startY: 1500, endX: 540, endY: 500}` or `{direction: "up"}`
- **Warning**: Never start swipe from y=0 (status bar causes issues)
- **Natural scrolling note**: Direction refers to finger movement, not content movement:
  - `direction: "up"` = finger moves up = content scrolls down (reveals content below)
  - `direction: "down"` = finger moves down = content scrolls up (reveals content above)

## Input & Navigation

### mobile_type_keys
- **Parameters**: `text`, `submit` (optional, press Enter)
- **Prerequisite**: Field must be focused first

### mobile_press_button
- **Parameters**: `button`
- **Supported**: HOME, BACK (Android), VOLUME_UP, VOLUME_DOWN, ENTER, POWER, MENU (Android)

### mobile_open_url
- **Parameters**: `url` (full URL with scheme)

## Accessibility vs Visual Sense Mode

| Aspect | Accessibility | Visual Sense |
|--------|---------------|--------------|
| Tool | `mobile_list_elements_on_screen` | `mobile_take_screenshot` |
| Speed | Fast | Slower |
| Reliability | Deterministic | Variable |
| Best for | Most interactions | Custom UI without a11y labels |

**Decision**: Always try accessibility first. Screenshot only as fallback.

## Important Notes

### Empty Parameter Requirement
Tools without parameters still require `{}` as input (not empty call).

### Accessibility Mode Limitations

`mobile_list_elements_on_screen` fails on Canvas-based apps that bypass the native accessibility tree:

| App Type | Reason | Detection Hint |
|----------|--------|----------------|
| Unity games | Custom rendering engine | Elements return empty or minimal |
| Flutter apps | Skia rendering (not native views) | Few/no elements despite visible UI |
| Google Maps | WebGL canvas | Map area returns single element |
| Custom drawing apps | Canvas/OpenGL rendering | Drawing area not parseable |
| React Native (some) | Partial native bridge | Mixed results |

**Detection strategy**: If `mobile_list_elements_on_screen` returns fewer than 5 elements when the screen clearly has more UI, the app likely uses custom rendering.

**Fallback**: Use Visual Sense Mode (screenshots) exclusively for these apps.

### Keyboard Management
On-screen keyboard covers ~40% of screen. After `mobile_type_keys`:
- Dismiss with BACK button (Android) or tap outside field (iOS)
- Re-query elements as coordinates shift when keyboard appears/disappears
