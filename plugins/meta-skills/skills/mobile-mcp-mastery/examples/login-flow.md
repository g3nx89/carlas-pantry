# Example: Login Flow Automation

> Complete workflow demonstrating authentication flow testing with mobile-mcp.

## Scenario

Test a standard login flow: launch app → enter credentials → submit → verify success.

## Prerequisites

- iOS Simulator or Android Emulator running
- Target app installed with known test credentials

## Workflow

### Step 1: Device Verification

```
Tool: mobile_list_available_devices
Parameters: {}

Expected: List of available devices with IDs
```

### Step 2: Launch Application

```
Tool: mobile_launch_app
Parameters: { "bundleId": "com.example.testapp" }

Wait: 3-5 seconds for app to fully load
```

### Step 3: Discover Login Form Elements

```
Tool: mobile_list_elements_on_screen
Parameters: {}

Look for:
- Text field with label "Email" or "Username"
- Text field with label "Password"
- Button with text "Sign In" or "Login"
```

### Step 4: Enter Username

```
# First, tap the username field to focus it
Tool: mobile_click_on_screen_at_coordinates
Parameters: { "x": [center_x of username field], "y": [center_y of username field] }

Wait: 0.5 seconds

# Then enter the username
Tool: mobile_type_keys
Parameters: { "text": "testuser@example.com" }
```

### Step 5: Enter Password

```
# Tap password field
Tool: mobile_click_on_screen_at_coordinates
Parameters: { "x": [center_x of password field], "y": [center_y of password field] }

Wait: 0.5 seconds

# Enter password
Tool: mobile_type_keys
Parameters: { "text": "SecurePassword123" }
```

### Step 6: Submit Login

```
Tool: mobile_click_on_screen_at_coordinates
Parameters: { "x": [center_x of login button], "y": [center_y of login button] }

Wait: 3-5 seconds for network response
```

### Step 7: Verify Success

```
Tool: mobile_list_elements_on_screen
Parameters: {}

Verify:
- Login form is no longer visible
- Dashboard or home screen elements appear
- Welcome message or user avatar present
```

### Step 8: Document Result (Optional)

```
Tool: mobile_take_screenshot
Parameters: {}

Save screenshot for test documentation
```

### Step 9: Cleanup

```
Tool: mobile_terminate_app
Parameters: { "packageName": "com.example.testapp" }
```

## Error Handling

| Issue | Recovery |
|-------|----------|
| Login form not found | Wait longer, scroll up, check bundleId |
| Keyboard covers submit button | Dismiss keyboard with BACK (Android) or tap outside |
| Login fails | Verify credentials, check network connectivity |
| Timeout waiting for response | Increase wait time, check server status |

## Prompt Template

```
Test login flow on [PLATFORM]:
1. Launch [BUNDLE_ID]
2. Wait 3 seconds for app load
3. Find and tap the email/username field
4. Enter "[USERNAME]"
5. Find and tap the password field
6. Enter "[PASSWORD]"
7. Tap the Sign In/Login button
8. Wait 5 seconds for network response
9. Verify logged-in state (dashboard visible, login form gone)
10. Take screenshot for documentation
11. If any popup/dialog appears, dismiss it
12. Terminate app when done
```
