# Mobile-MCP Workflow Patterns

## Core Pattern: SAV Loop (State-Action-Verification)

The fundamental pattern for robust mobile automation:

```
┌─────────────────────────────────────────────┐
│  STATE: Observe current UI state            │
│  ├── mobile_list_elements_on_screen         │
│  └── (or mobile_take_screenshot if needed)  │
└────────────────┬────────────────────────────┘
                 ▼
┌─────────────────────────────────────────────┐
│  ACTION: Perform single interaction         │
│  ├── mobile_click_on_screen_at_coordinates  │
│  ├── mobile_type_keys                       │
│  └── mobile_swipe_on_screen                 │
└────────────────┬────────────────────────────┘
                 ▼
┌─────────────────────────────────────────────┐
│  VERIFY: Confirm expected state change      │
│  ├── Wait 2-3 seconds                       │
│  ├── Re-query elements or screenshot        │
│  └── Compare against expected outcome       │
└─────────────────────────────────────────────┘
```

**Critical**: Never skip verification. UI state changes asynchronously.

### SAV Loop Failure Recovery Protocol

When verification fails, follow this recovery protocol:

```
VERIFICATION FAILED?
├── Retry (up to 3 attempts)
│   ├── Wait 2 seconds (backoff)
│   ├── Re-query state
│   └── Check if expected state now present
│
├── If still failing after retries:
│   ├── Check for blocking elements (popups, dialogs, loading)
│   ├── Dismiss blockers if found
│   └── Retry action from beginning
│
└── If unrecoverable:
    ├── Take screenshot for debugging
    ├── Log current element state
    └── Abort with clear error message
```

**Recovery timing:**
| Attempt | Wait Before Retry |
|---------|-------------------|
| 1st retry | 2 seconds |
| 2nd retry | 4 seconds |
| 3rd retry | 6 seconds |
| Abort | After 3 failures |

**Common verification failures and recovery:**
| Failure | Likely Cause | Recovery |
|---------|--------------|----------|
| Element not found | Screen still loading | Wait longer, check for spinners |
| Wrong screen | Navigation failed | Go back, retry navigation |
| Element present but different | Partial update | Wait for animation to complete |
| Timeout | Network/server delay | Increase wait, check connectivity |

## Pattern: Element Discovery → Interaction → Verification

Standard interaction loop:
```
1. mobile_list_elements_on_screen  // Find elements
2. Identify target from results    // AI selects correct element
3. mobile_click_on_screen_at_coordinates  // Interact
4. [Wait 2 seconds]
5. mobile_list_elements_on_screen  // Verify state changed
```

## Pattern: Scroll Until Found

```
REPEAT:
  1. mobile_list_elements_on_screen
  2. Check if target element exists
  3. IF found: proceed to interaction
  4. IF not found: mobile_swipe_on_screen (scroll down)
  5. IF no new elements after scroll: element not present
```

## Pattern: Fallback to Visual Sense

```
1. mobile_list_elements_on_screen
2. IF target has no accessibility info:
   ├── mobile_take_screenshot
   ├── Analyze image for element location
   └── mobile_click_on_screen_at_coordinates (visual coords)
3. ELSE: use accessibility-based coordinates
```

## Workflow 1: UI Testing Automation

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

**Prompt template**:
```
Test [APP_NAME] on [PLATFORM]:
1. Launch [BUNDLE_ID]
2. Wait 3 seconds for app to load
3. [SPECIFIC TEST STEPS]
4. If popups/ads appear, dismiss them
5. Verify [EXPECTED_OUTCOME]
6. Take screenshot for documentation
7. Terminate app
```

## Workflow 2: Data Scraping

```
1. mobile_launch_app → Open target
2. Navigate to data source
3. LOOP:
   ├── mobile_list_elements_on_screen → Extract visible data
   ├── Parse text content from elements
   ├── mobile_swipe_on_screen → Scroll to reveal more
   ├── Check if reached end (same elements repeated)
   └── Continue until complete
4. Aggregate extracted data
5. mobile_terminate_app
```

**Prompt template**:
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

## Workflow 3: Cross-Platform Validation

```
Define test in platform-agnostic terms:
├── "Find element with text 'Login'" (not platform-specific ID)
├── "Enter text in field labeled 'Email'"
└── "Tap button containing 'Submit'"

For each platform:
1. Start device (iOS Simulator / Android Emulator)
2. Execute identical workflow
3. Handle platform differences:
   ├── Back: BACK button (Android) vs swipe (iOS)
   ├── Permissions: Different UI layouts
   └── Keyboard: Done vs Return key
4. Compare results
```

## Workflow 4: Authentication Flow

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

## Workflow 5: Dynamic Content Handling

**Prompt pattern** for apps with ads, popups, loading states:
```
After launching the app:
- If a promotional popup appears, tap the X or "Skip" button
- If an ad is displayed, wait for skip button (usually 5 seconds) then tap
- If a loading spinner is visible, wait until content appears
- If a permission dialog appears, tap "Allow" or "OK"
Then proceed with the main task...
```

## Workflow 6: System Dialog Handling

### Permission Dialogs

System permission dialogs appear outside the app's accessibility tree but are detectable:

```
1. mobile_list_elements_on_screen
2. Look for system dialog indicators:
   - iOS: "Allow", "Don't Allow", "Allow While Using App"
   - Android: "Allow", "Deny", "While using the app", "Only this time"
3. If permission dialog detected:
   ├── mobile_click_on_screen_at_coordinates (tap Allow/desired option)
   └── Wait 1 second for dialog dismissal
4. Re-query elements to confirm app screen visible
```

**Common permission types:**
| Permission | iOS Text | Android Text |
|------------|----------|--------------|
| Location | "Allow While Using App" | "While using the app" |
| Camera | "OK" / "Allow" | "While using the app" |
| Photos | "Allow Access to All Photos" | "Allow" |
| Notifications | "Allow" | "Allow" |
| Microphone | "OK" | "While using the app" |

### Biometric Authentication (Face ID / Touch ID / Fingerprint)

Biometric prompts cannot be automated directly. Handle with these strategies:

**Strategy 1: Use test credentials instead**
```
For testing, configure app to use password fallback:
1. When biometric prompt appears, look for "Use Password" or "Use Passcode"
2. Tap fallback option
3. Enter test credentials via mobile_type_keys
```

**Strategy 2: Pre-authenticated state**
```
For CI/automation:
1. Use test accounts that don't require biometric
2. Or use app's debug/test mode to bypass biometric
3. Or mock biometric success via test framework (Appium/XCUITest)
```

**Strategy 3: Simulator biometric simulation (iOS)**
```
Before automation:
1. In Simulator menu: Features → Touch ID/Face ID → Enrolled
2. When biometric prompt appears during test:
   - Simulator menu: Features → Touch ID/Face ID → Matching Touch/Face
   - This simulates successful biometric
Note: Requires manual intervention or AppleScript automation
```

**Strategy 4: Android Emulator fingerprint**
```
# From terminal while emulator running:
adb -e emu finger touch 1

# Or use extended controls in emulator UI
```

### Alert Dialogs

Standard alert handling pattern:
```
1. mobile_list_elements_on_screen
2. Check for alert indicators:
   - Button text: "OK", "Cancel", "Yes", "No", "Dismiss"
   - Alert titles: "Error", "Warning", "Confirm"
3. Decide action based on context:
   ├── Confirmations: Tap positive button ("OK", "Yes", "Continue")
   ├── Errors: Take screenshot, tap dismiss, log error
   └── Warnings: Read message, decide proceed/abort
4. Wait 1 second after dismissal
5. Re-query elements
```
