# Mobile-MCP: Complete Technical Manual for AI Coding Agents

**Mobile-MCP** is a Model Context Protocol server that enables AI agents to automate iOS and Android applications across simulators, emulators, and real devices. This manual provides everything needed to build effective mobile automation workflows with Claude Code and other MCP-enabled agents.

## Executive summary

Mobile-MCP bridges the gap between AI assistants and mobile devices by exposing **15+ automation tools** through the MCP protocol, enabling LLMs to interact with native apps without requiring computer vision models. The server uses a dual-mode approach: **Accessibility Mode** (preferred) extracts structured UI hierarchies for fast, deterministic interactions, while **Visual Sense Mode** analyzes screenshots when accessibility labels are unavailable. This architecture makes mobile-mcp significantly lighter and more reliable than purely screenshot-based alternatives.

The toolkit supports both platforms through native integrations—**ADB and UI Automator for Android**, **Xcode instruments and WebDriverAgent for iOS**—with v0.0.38+ automatically installing WebDriverAgent on iOS simulators. Key use cases include automated UI testing, mobile app scraping, cross-platform validation, and AI-assisted app exploration. The server connects to any MCP-compatible client (Claude Desktop, Cursor, VS Code, GitHub Copilot) through a simple npx command, requiring only Node.js v22+ and platform-specific SDKs.

Community adoption has been strong since the December 2024 launch, with **3,200+ GitHub stars** and active development releasing fixes weekly. The most critical best practice emerging from community experience: **prefer accessibility snapshots over screenshots** and **include explicit wait instructions** in prompts to handle mobile UI dynamics reliably.

---

## Technical reference

### Architecture overview

Mobile-MCP operates as a **STDIO-based MCP server** that translates tool calls into platform-specific automation commands:

```
┌─────────────────────┐
│   MCP Client        │  Claude Desktop, Cursor, VS Code, etc.
│  (AI Assistant)     │
└─────────┬───────────┘
          │ STDIO / SSE
┌─────────▼───────────┐
│   Mobile-MCP        │  TypeScript server (@mobilenext/mobile-mcp)
│   Server            │
└─────────┬───────────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌───────┐   ┌───────┐
│Android│   │  iOS  │
│Adapter│   │Adapter│
└───┬───┘   └───┬───┘
    │           │
    ▼           ▼
  ADB +       Xcode +
  UI Auto     WebDriverAgent
    │           │
    ▼           ▼
┌───────┐   ┌───────┐
│Device │   │Device │
└───────┘   └───────┘
```

**Communication modes**: STDIO transport (default, recommended), SSE transport for external services, HTTP mode on port 4723 for debugging.

### Prerequisites and environment setup

| Component | Required Version | Notes |
|-----------|-----------------|-------|
| **Node.js** | v22+ | v18+ works but v22+ recommended |
| **npm** | ≥9 | Bundled with Node.js |
| **Java** | 11+ | Android tooling only |
| **Xcode** | ≥15 | macOS only, iOS development |
| **Android SDK** | Latest platform-tools | ADB required |

**Environment variables**:

```bash
# Android (all platforms)
export ANDROID_HOME=/path/to/android/sdk
export JAVA_HOME=/path/to/java

# iOS (macOS only)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Server configuration (optional)
export MCP_PORT=4723
export MCP_LOG_LEVEL=info  # info|debug|trace
export MCP_SESSION_TIMEOUT=300000
```

**Android setup**:
1. Install Android Platform Tools from developer.android.com
2. Set `$ANDROID_HOME` environment variable
3. Start emulator: `emulator -avd YOUR_AVD_NAME`
4. Verify: `$ANDROID_HOME/platform-tools/adb devices`

**iOS setup** (macOS only):
1. Install Xcode from Mac App Store
2. Run: `xcode-select --install`
3. Boot simulator: `xcrun simctl boot "iPhone 16"`
4. v0.0.38+ auto-installs WebDriverAgent—no manual setup needed

### Installation and configuration

**Quick start** (all MCP clients):
```json
{
  "mcpServers": {
    "mobile-mcp": {
      "command": "npx",
      "args": ["-y", "@mobilenext/mobile-mcp@latest"]
    }
  }
}
```

**Claude Code CLI**:
```bash
claude mcp add mobile-mcp -- npx -y @mobilenext/mobile-mcp@latest
```

**Verify installation**:
```bash
# Test server directly
npx -y @mobilenext/mobile-mcp@latest
# Should start without errors if devices are available
```

### Complete tool inventory

#### Device management tools

**mobile_list_available_devices**

Lists all connected devices including simulators, emulators, and physical devices. Call this first to identify available targets.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| (none) | — | — | — |

**Returns**: Array of device objects with identifier, name, type, platform, and state.

```json
// Example response
[
  { "id": "emulator-5554", "name": "Pixel_7_Pro", "type": "emulator", "platform": "android", "state": "device" },
  { "id": "ABCD1234-5678-EFGH", "name": "iPhone 16", "type": "simulator", "platform": "ios", "state": "booted" }
]
```

---

**mobile_get_screen_size**

Returns device screen dimensions in pixels. Essential for calculating swipe coordinates.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| (none) | — | — | — |

**Returns**: `{ "width": 1080, "height": 2400 }`

---

**mobile_get_orientation** / **mobile_set_orientation**

Get or set device orientation between portrait and landscape.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| orientation | string | Yes (set only) | `"portrait"` or `"landscape"` |

---

#### App management tools

**mobile_launch_app**

Launches an application using its bundle/package identifier.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| bundleId | string | Yes | App identifier (e.g., `com.instagram.android`, `com.apple.mobilenotes`) |

**Errors**: App not installed, invalid bundle ID, device locked.

---

**mobile_terminate_app**

Stops and terminates a running application. Use for cleanup.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| packageName | string | Yes | App identifier to terminate |

---

**mobile_install_app** / **mobile_uninstall_app**

Install from file (`.apk`, `.ipa`, `.app`, `.zip`) or uninstall by bundle ID.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| appPath | string | Yes (install) | Path to app file |
| bundleId | string | Yes (uninstall) | App identifier |

---

**mobile_list_apps**

Lists installed applications on the device.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| bundleId | string | No | Filter by specific identifier |

---

#### Screen interaction tools

**mobile_list_elements_on_screen** ⭐ PRIMARY TOOL

Returns all UI elements with coordinates, text, and accessibility properties. **Prefer this over screenshots** for finding tap targets.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| (none) | — | — | — |

**Returns**: Array of element objects:
```json
[
  {
    "type": "Button",
    "text": "Sign In",
    "accessibilityLabel": "Sign In Button",
    "bounds": { "x": 100, "y": 500, "width": 200, "height": 50 },
    "clickable": true
  }
]
```

**Critical note**: Do not cache this result—screen content changes between actions.

---

**mobile_take_screenshot**

Captures current screen as base64-encoded image. Use for visual verification or when accessibility data is unavailable.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| (none) | — | — | — |

**Known issue**: Screenshots exceeding **2000px** may fail with Claude API limits. Restart session if persistent.

---

**mobile_save_screenshot**

Saves screenshot to a file path.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| filePath | string | Yes | Destination path (e.g., `/tmp/screen.png`) |

---

**mobile_click_on_screen_at_coordinates**

Single tap at specific coordinates. Get coordinates from `mobile_list_elements_on_screen`.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| x | number | Yes | X coordinate in pixels |
| y | number | Yes | Y coordinate in pixels |

---

**mobile_double_tap_on_screen**

Double-tap gesture at coordinates.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| x | number | Yes | X coordinate |
| y | number | Yes | Y coordinate |

---

**mobile_long_press_on_screen_at_coordinates**

Long press gesture for context menus, drag initiation.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| x | number | Yes | X coordinate |
| y | number | Yes | Y coordinate |
| duration | number | No | Press duration in ms |

---

**mobile_swipe_on_screen**

Swipe gesture between two points. Use for scrolling and navigation.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| startX | number | Yes | Starting X |
| startY | number | Yes | Starting Y |
| endX | number | Yes | Ending X |
| endY | number | Yes | Ending Y |
| duration | number | No | Swipe duration in ms |

**Scroll down** (reveal content below): swipe from lower Y to higher Y
```json
{ "startX": 540, "startY": 1500, "endX": 540, "endY": 500 }
```

---

#### Input and navigation tools

**mobile_type_keys**

Types text into the currently focused input field.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| text | string | Yes | Text to type |
| submit | boolean | No | Press Enter after typing (default: false) |

---

**mobile_press_button**

Presses hardware/system buttons.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| button | string | Yes | Button name |

**Supported buttons**: `HOME`, `BACK` (Android), `VOLUME_UP`, `VOLUME_DOWN`, `ENTER`, `POWER`, `MENU` (Android)

---

**mobile_open_url**

Opens URL in device's default browser.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| url | string | Yes | Full URL including scheme |

---

### Accessibility mode vs Visual Sense mode

| Aspect | Accessibility Mode | Visual Sense Mode |
|--------|-------------------|-------------------|
| **Data source** | Native accessibility tree | Screenshot analysis |
| **Speed** | Fast (no CV processing) | Slower (image analysis) |
| **Reliability** | Deterministic | Variable |
| **Best for** | Most interactions | Custom UI without a11y labels |
| **Tool** | `mobile_list_elements_on_screen` | `mobile_take_screenshot` |

**Decision rule**: Always try accessibility mode first. Fall back to Visual Sense only when elements lack accessibility labels or when visual verification is specifically needed.

---

## Practical playbook

### Workflow 1: Mobile UI testing automation

**Objective**: Automated regression testing of app flows

```
PHASE 1: Setup
├── mobile_list_available_devices → Select target
├── mobile_install_app (if needed) → Deploy test build
└── mobile_launch_app → Start fresh state

PHASE 2: Test Execution (per test case)
├── mobile_list_elements_on_screen → Find target element
├── mobile_click_on_screen_at_coordinates → Interact
├── [Wait 2-3 seconds]
├── mobile_list_elements_on_screen → Verify state change
└── Repeat for each step

PHASE 3: Verification
├── mobile_take_screenshot → Document result
└── Compare against expected state

PHASE 4: Cleanup
└── mobile_terminate_app → Release resources
```

**Example prompt for Claude Code**:
```
Using the connected Android emulator, test the login flow:
1. Launch app com.example.myapp
2. Wait 3 seconds for splash screen
3. Find and tap the "Sign In" button
4. Enter "testuser@example.com" in the email field
5. Enter "password123" in the password field  
6. Tap the "Submit" button
7. Wait 5 seconds for network response
8. Verify the dashboard screen appears with "Welcome" text
9. Take a screenshot for documentation
10. Terminate the app
```

### Workflow 2: Mobile app scraping

**Objective**: Extract structured data from app screens

```
1. mobile_launch_app → Open target app
2. Navigate to data source (search, lists, etc.)
3. LOOP:
   ├── mobile_list_elements_on_screen → Extract visible data
   ├── Parse text content from elements
   ├── mobile_swipe_on_screen → Scroll to reveal more
   ├── Check if reached end (same elements repeated)
   └── Continue until complete
4. Aggregate extracted data
5. mobile_terminate_app
```

**Key consideration**: Apps may have infinite scroll. Track seen items to detect completion.

### Workflow 3: Cross-platform testing

**Objective**: Validate same functionality on iOS and Android

```
Define test in platform-agnostic terms:
├── "Find element with text 'Login'" (not platform-specific ID)
├── "Enter text in field labeled 'Email'"
└── "Tap button containing 'Submit'"

For each platform:
1. Start device (iOS Simulator / Android Emulator)
2. Execute identical workflow
3. Handle platform differences:
   ├── Back navigation: BACK button (Android) vs swipe (iOS)
   ├── Permission dialogs: Different UI layouts
   └── Keyboard handling: Done vs Return key
4. Compare results across platforms
```

### Workflow 4: Authentication flow handling

**Objective**: Log into app and maintain session state

```
1. mobile_launch_app
2. mobile_list_elements_on_screen → Identify login form
3. mobile_click_on_screen_at_coordinates → Tap username field
4. mobile_type_keys → Enter username
5. mobile_click_on_screen_at_coordinates → Tap password field
6. mobile_type_keys → Enter password
7. mobile_click_on_screen_at_coordinates → Tap submit
8. [Wait 3-5 seconds for network]
9. mobile_list_elements_on_screen → Verify logged-in state
```

**Important**: Include explicit wait after login submission—network requests take time.

### Workflow 5: Dynamic content handling

**Objective**: Interact with apps showing ads, popups, loading states

**Prompt pattern**:
```
After launching the app:
- If a promotional popup appears, tap the X or "Skip" button
- If an ad is displayed, wait for the skip button (usually 5 seconds) then tap it
- If a loading spinner is visible, wait until content appears
- If a permission dialog appears, tap "Allow" or "OK"
Then proceed with the main task...
```

### Tool orchestration patterns

**Pattern: Element Discovery → Interaction → Verification**
```
1. mobile_list_elements_on_screen  // Find elements
2. Identify target from results    // AI selects correct element
3. mobile_click_on_screen_at_coordinates  // Interact
4. [Wait 2 seconds]
5. mobile_list_elements_on_screen  // Verify state changed
```

**Pattern: Scroll Until Found**
```
REPEAT:
  1. mobile_list_elements_on_screen
  2. Check if target element exists
  3. IF found: proceed to interaction
  4. IF not found: mobile_swipe_on_screen (scroll down)
  5. IF no new elements after scroll: element not present
```

**Pattern: Fallback to Visual Sense**
```
1. mobile_list_elements_on_screen
2. IF target has no accessibility info:
   ├── mobile_take_screenshot
   ├── Analyze image for element location
   └── mobile_click_on_screen_at_coordinates (visual coords)
3. ELSE: use accessibility-based coordinates
```

---

## Patterns and anti-patterns catalog

### Best practices checklist

#### Tool selection
- [ ] **Always call `mobile_list_elements_on_screen` before tapping** to get current coordinates
- [ ] **Prefer accessibility data over screenshots** for faster, deterministic interactions
- [ ] **Use screenshots for verification**, not primary element discovery
- [ ] **Call `mobile_list_available_devices` at start** to confirm device connectivity

#### Timing and synchronization
- [ ] **Add explicit 2-3 second waits** after app launch, navigation, and form submission
- [ ] **Wait for loading indicators to disappear** before interacting with content
- [ ] **Handle animations** by waiting for UI stability
- [ ] **Set reasonable timeouts**: 5s for app launch, 10s for network operations

#### Prompt engineering
- [ ] **Use step-by-step instructions** with numbered actions
- [ ] **Include error handling** in prompts: "If X appears, do Y"
- [ ] **Specify wait conditions**: "Wait until the Submit button is visible"
- [ ] **Define success criteria**: "Verify the confirmation message appears"

#### Resource management
- [ ] **Terminate apps after testing** with `mobile_terminate_app`
- [ ] **Don't leave sessions idle** for extended periods
- [ ] **Restart sessions** if screenshot errors occur repeatedly

#### Cross-platform considerations
- [ ] **Test on both iOS and Android** when applicable
- [ ] **Use text-based element identification** rather than platform-specific IDs
- [ ] **Handle platform-specific navigation** (Android back button vs iOS gestures)

### Anti-patterns to avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| **Hardcoded coordinates** | Breaks on different devices/orientations | Use `mobile_list_elements_on_screen` to get current coordinates |
| **Screenshot-first approach** | Slow, requires vision processing | Start with accessibility data; screenshot only as fallback |
| **No waits between actions** | Race conditions, stale elements | Add explicit waits after every state-changing action |
| **Fixed sleep everywhere** | Inefficient, still may be insufficient | Use condition-based waits when possible |
| **Ignoring loading states** | Interacts with incomplete UI | Check for loading indicators before proceeding |
| **Chained dependent tests** | One failure cascades to all | Design independent, self-contained workflows |
| **No error recovery** | Automation stops at first failure | Include fallback instructions and retry logic |
| **Skipping device verification** | Mysterious failures | Always call `mobile_list_available_devices` first |
| **Caching element locations** | Coordinates become stale | Re-query elements before each interaction |
| **Not terminating apps** | Memory leaks, state accumulation | Clean up with `mobile_terminate_app` |

### Platform-specific gotchas

| Platform | Issue | Solution |
|----------|-------|----------|
| **iOS** | Requires macOS and Xcode | No workaround—iOS testing needs Mac |
| **iOS** | WebDriverAgent setup | Use v0.0.38+ for auto-installation |
| **iOS** | Text entry on first character unreliable | Tap field center, not first character |
| **Android** | ADB path on Windows | v0.0.35+ fixed—update to latest |
| **Android** | UTF-8 text input issues | See wiki for configuration |
| **Android** | UIAutomator warnings in output | Fixed in recent versions—update |
| **Both** | Screenshot exceeds 2000px | Restart client session |
| **Both** | Permission dialogs interrupt flow | Pre-grant or handle in prompt |

---

## Community insights

### Most reported issues and solutions

| Issue | Frequency | Solution | Status |
|-------|-----------|----------|--------|
| **MCP error -32602** on multiple tools | HIGH | Use standard npx config, avoid custom paths | Fixed in setup |
| **Screenshot dimension exceeds max size** | MEDIUM | Restart Claude Code session | Open (Issue #140) |
| **iOS text entry unreliable** | MEDIUM | Tap center of field, not first character | Open (Issue #124) |
| **Windows ADB path resolution** | MEDIUM | Update to v0.0.35+ | Fixed |
| **Foldable device screenshot failure** | LOW | Update to v0.0.33+ | Fixed |

### Community-recommended prompt structure

From community experience, this prompt structure produces reliable results:

```
1. [Device Context] Use the active emulator listed under adb devices
2. [App Action] Open the [App Name] application
3. [Wait Instruction] Wait for 3 seconds for the app to load
4. [Task Action] [Specific action to perform]
5. [Error Handling] If any popups or ads appear, close them
6. [Verification] Confirm [expected result]
7. [Next Action] Continue with [next step]
```

### Comparison with alternatives

| Feature | Mobile-MCP | Appium | Maestro | Detox |
|---------|------------|--------|---------|-------|
| **AI/LLM Integration** | Native MCP | Requires wrapper | Limited YAML | None |
| **Setup Complexity** | Low (npx) | High | Low | Medium |
| **Platforms** | iOS + Android | Cross-platform | iOS + Android | React Native |
| **Approach** | Accessibility + Visual | WebDriver | YAML scripts | Gray-box |
| **Best For** | AI agents, exploration | Enterprise CI/CD | Simple UI flows | RN testing |

**When to choose mobile-mcp**: AI-assisted automation, rapid prototyping, LLM-driven testing, exploratory workflows.

**When to choose Appium**: Enterprise CI/CD pipelines, existing test suites, maximum platform coverage, detailed control.

**When to choose Maestro**: Simple UI test automation, YAML-based workflows, quick setup for straightforward flows.

### Real-world case studies

**Case 1: YouTube Automation** (Medium tutorial)
- Platform: Android emulator + Claude Desktop
- Workflow: Launch → Search → Handle ads → Play video
- Key learning: Include explicit ad handling; screenshots become stale during popups

**Case 2: StockPulse Testing** (dev.to article)
- Platform: Android + Claude Code
- Workflow: Open app → Add stock → Save → Verify
- Result: Complete test in under 2 minutes with auto-generated report

### Resources and community

- **Official Wiki**: https://github.com/mobile-next/mobile-mcp/wiki
- **Slack Community**: http://mobilenexthq.com/join-slack
- **GitHub Discussions**: https://github.com/mobile-next/mobile-mcp/discussions
- **Video Demo (Cline)**: https://www.youtube.com/watch?v=OYuJrKQSAok

---

## Claude Code skill design blueprint

### Skill overview

```yaml
name: mobile-mcp-automation
description: Automate iOS and Android apps using mobile-mcp MCP server
triggers:
  - "test mobile app"
  - "automate app"
  - "mobile automation"
  - "interact with device"
  - "scrape mobile app"
```

### Decision tree for tool selection

```
User Request
    │
    ├─► Need device info?
    │   └─► mobile_list_available_devices
    │
    ├─► Need to see screen content?
    │   ├─► Need structured data? → mobile_list_elements_on_screen ✓ PREFER
    │   └─► Need visual verification? → mobile_take_screenshot
    │
    ├─► Need to interact with element?
    │   ├─► Element found in accessibility? → Calculate center, use mobile_click_on_screen_at_coordinates
    │   └─► No accessibility data? → mobile_take_screenshot + Visual Sense + coordinates
    │
    ├─► Need to type text?
    │   └─► mobile_type_keys (ensure field is focused first)
    │
    ├─► Need to scroll/navigate?
    │   ├─► Scroll content → mobile_swipe_on_screen
    │   ├─► Go back → mobile_press_button("BACK") [Android] or swipe gesture
    │   └─► Go home → mobile_press_button("HOME")
    │
    └─► Need to manage app?
        ├─► Start app → mobile_launch_app
        ├─► Stop app → mobile_terminate_app
        └─► Install/remove → mobile_install_app / mobile_uninstall_app
```

### Prompt templates

**Template: App Testing**
```
Test the [APP_NAME] app on [PLATFORM]:
1. Launch [BUNDLE_ID]
2. Wait 3 seconds for app to load
3. [SPECIFIC TEST STEPS]
4. If popups/ads appear, dismiss them
5. Verify [EXPECTED_OUTCOME]
6. Take screenshot for documentation
7. Terminate app
```

**Template: Data Extraction**
```
Extract [DATA_TYPE] from [APP_NAME]:
1. Launch [BUNDLE_ID]
2. Navigate to [SCREEN_NAME]
3. List all visible elements
4. Extract [SPECIFIC_DATA] from each [ELEMENT_TYPE]
5. Scroll to reveal more content
6. Repeat until all data collected
7. Return structured results
```

**Template: Cross-Platform Validation**
```
Validate [FEATURE] works on both platforms:

On Android emulator:
1. [STEPS]
2. Record results

On iOS simulator:
1. [SAME STEPS with platform adjustments]
2. Record results

Compare results and report differences.
```

### Error handling recommendations

```python
# Pseudocode for robust automation
def interact_with_element(target_text):
    max_retries = 3
    for attempt in range(max_retries):
        elements = mobile_list_elements_on_screen()
        target = find_element_by_text(elements, target_text)
        
        if target:
            mobile_click_on_screen_at_coordinates(target.center_x, target.center_y)
            wait(2)
            return True
        
        # Not found - try scrolling
        mobile_swipe_on_screen(scroll_down)
        wait(1)
    
    # Still not found - fall back to screenshot
    screenshot = mobile_take_screenshot()
    coords = visual_sense_find(screenshot, target_text)
    if coords:
        mobile_click_on_screen_at_coordinates(coords.x, coords.y)
        return True
    
    return False  # Element truly not present
```

### Context requirements

The skill should request/verify:
1. **Device availability**: Is a device/emulator running?
2. **Platform target**: iOS or Android (affects navigation patterns)
3. **App identifier**: Bundle ID/package name for launch
4. **Success criteria**: How to verify task completion
5. **Error tolerance**: Should failures stop or continue?

### Example optimal agent interactions

**Interaction 1: Simple app launch**
```
User: Open the Instagram app on my Android emulator

Agent:
1. Calls mobile_list_available_devices
2. Confirms Android emulator is connected
3. Calls mobile_launch_app with bundleId="com.instagram.android"
4. Waits 3 seconds
5. Calls mobile_list_elements_on_screen to confirm app launched
6. Reports success with visible elements
```

**Interaction 2: Data extraction**
```
User: Get the titles of the top 5 posts in my Reddit feed

Agent:
1. Launches Reddit app
2. Waits for feed to load
3. Calls mobile_list_elements_on_screen
4. Identifies post title elements by type/structure
5. Extracts first 5 titles
6. Scrolls if fewer than 5 visible
7. Returns structured list of titles
```

**Interaction 3: Complex workflow with recovery**
```
User: Book a table at a restaurant on OpenTable

Agent:
1. Launches OpenTable
2. Handles any promotional popups
3. Searches for restaurant
4. Selects date/time
5. If slot unavailable, tries alternative time
6. Completes booking form
7. Verifies confirmation screen
8. Takes screenshot of confirmation
9. Reports booking details
```

### Key skill behaviors

1. **Always verify device connectivity** before attempting actions
2. **Prefer accessibility mode** (`mobile_list_elements_on_screen`) over screenshots
3. **Include explicit waits** after state-changing actions (2-3 seconds minimum)
4. **Handle dynamic content** proactively (ads, popups, loading states)
5. **Provide clear progress updates** during multi-step workflows
6. **Document results** with screenshots when appropriate
7. **Clean up resources** by terminating apps after completion
8. **Gracefully handle failures** with retry logic and fallbacks

---

## Appendix: Quick reference card

### Essential commands

```bash
# Install/run
npx -y @mobilenext/mobile-mcp@latest

# Claude Code setup
claude mcp add mobile-mcp -- npx -y @mobilenext/mobile-mcp@latest

# Android device check
adb devices

# iOS simulator list
xcrun simctl list devices

# Boot iOS simulator
xcrun simctl boot "iPhone 16"
```

### Tool quick reference

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `mobile_list_available_devices` | List devices | (none) |
| `mobile_launch_app` | Start app | `bundleId` |
| `mobile_terminate_app` | Stop app | `packageName` |
| `mobile_list_elements_on_screen` | Get UI elements | (none) |
| `mobile_click_on_screen_at_coordinates` | Tap | `x`, `y` |
| `mobile_type_keys` | Enter text | `text`, `submit` |
| `mobile_swipe_on_screen` | Scroll/swipe | `startX`, `startY`, `endX`, `endY` |
| `mobile_take_screenshot` | Capture screen | (none) |
| `mobile_press_button` | Hardware button | `button` |

### Timing guidelines

| Action | Recommended Wait |
|--------|-----------------|
| App launch | 3-5 seconds |
| Navigation | 2 seconds |
| Form submission | 3-5 seconds |
| Scroll | 1 second |
| Animation | 0.5 seconds |

### Troubleshooting checklist

1. **Device not found**: Verify emulator/simulator is running
2. **Screenshot errors**: Restart client session
3. **Elements not detected**: Ensure app has loaded, try scrolling
4. **Tap not registering**: Verify coordinates, add wait before tap
5. **Text not entering**: Tap field first to focus, then type

---

*Manual version: February 2026 | mobile-mcp v0.0.38+ | Confidence level: HIGH for core features, MEDIUM for advanced patterns*