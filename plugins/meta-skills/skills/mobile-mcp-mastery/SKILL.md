---
name: mobile-mcp-mastery
description: This skill should be used when the user asks to "automate mobile app", "test mobile UI", "scrape mobile app data", "tap button on phone", "interact with iOS Simulator", "control Android Emulator", "use mobile-mcp tools", "click on mobile screen", or when developing skills/commands that use mobile-mcp. Provides tool selection, workflow patterns, and selective reference loading for the mobile-mcp MCP server.
---

# Mobile-MCP Mastery

> **Compatibility**: Verified against mobile-mcp v0.0.38+ (February 2026)

## Overview

Mobile-MCP bridges AI assistants and mobile devices through **15+ automation tools** via MCP protocol. It uses dual-mode approach: **Accessibility Mode** (preferred) for structured UI hierarchy, **Visual Sense Mode** (screenshots) as fallback.

**Core principle**: Always prefer `mobile_list_elements_on_screen` over screenshots - faster, deterministic, no CV processing.

## Quick Start

**Simple tasks** - invoke tools directly:
- **Launch app** → `mobile_launch_app(bundleId="com.example.app")`
- **Find elements** → `mobile_list_elements_on_screen()`
- **Tap element** → `mobile_click_on_screen_at_coordinates(x, y)` (center of element bounds)

**Complex workflows** - load references as needed:
```
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/workflows.md      # Workflow patterns
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/tools-quick.md   # Tool parameters
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/troubleshooting.md
```

## Tool Selection Decision Tree

```
Need device info or status?
├── YES → mobile_list_available_devices
└── NO ↓

Need to see screen content?
├── Structured data? → mobile_list_elements_on_screen ✓ PREFER
└── Visual verification? → mobile_take_screenshot (fallback)

Need to interact with element?
├── Element in accessibility tree? → Calculate center → mobile_click_on_screen_at_coordinates
└── No accessibility data? → Screenshot → Visual Sense → coordinates

Need to input text?
└── Tap field first → mobile_type_keys(text, submit?)

Need to scroll/navigate?
├── Scroll content → mobile_swipe_on_screen
├── Go back → mobile_press_button("BACK") [Android] or swipe
└── Go home → mobile_press_button("HOME")

Need to manage app lifecycle?
├── Start → mobile_launch_app
├── Stop → mobile_terminate_app
└── Install/Remove → mobile_install_app / mobile_uninstall_app
```

## Quick Reference

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `mobile_list_available_devices` | List devices | `{}` (required) |
| `mobile_use_device` | Select target device | `device` (ID), `deviceType` (emulator/simulator/physical) |
| `mobile_launch_app` | Start app | `bundleId` |
| `mobile_terminate_app` | Stop app | `packageName` |
| `mobile_list_elements_on_screen` | Get UI elements | `{}` (required) |
| `mobile_click_on_screen_at_coordinates` | Tap | `x`, `y` |
| `mobile_type_keys` | Enter text | `text`, `submit` |
| `mobile_swipe_on_screen` | Scroll/swipe | `direction` or `startX/Y`, `endX/Y` |
| `mobile_take_screenshot` | Capture screen | `{}` (required) |
| `mobile_press_button` | Hardware button | `button` (HOME, BACK, ENTER) |

**Note**: Tools marked `{}` require empty object as parameter, not empty call.

## Essential Rules

1. **Follow SAV Loop** - State → Action → Verify (never skip verification)
2. **Always verify device first** - call `mobile_list_available_devices` before any automation
3. **Accessibility over screenshots** - `mobile_list_elements_on_screen` is faster and deterministic
4. **Add explicit waits** - 2-3s after app launch, navigation, form submission
5. **Never cache coordinates** - re-query elements before each interaction
6. **Clean up** - terminate apps with `mobile_terminate_app` when done

**SAV Loop**: Query state → Perform action → Wait → Verify change. See `workflows.md` for diagram and **failure recovery protocol**.

## Timing Guidelines

| Action | Wait |
|--------|------|
| App launch | 3-5s |
| Navigation | 2s |
| Form submission | 3-5s |
| Scroll | 1s |

## Selective Reference Loading

**Load only when needed:**

### Reference Files
```
# Workflow templates (testing, scraping, cross-platform, system dialogs, biometric handling)
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/workflows.md

# Full tool parameters and examples
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/tools-quick.md

# Platform setup (Android/iOS prerequisites)
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/setup.md

# Common errors and fixes
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/troubleshooting.md

# Anti-patterns to avoid
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/anti-patterns.md
```

### Example Workflows
```
# Complete login flow automation example
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/examples/login-flow.md

# Data scraping from list-based apps
Read: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/examples/data-scraping.md
```

### Utility Scripts
```bash
# Verify Android/iOS prerequisites are installed (macOS/Linux)
Bash: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/scripts/check-prerequisites.sh [android|ios|all]

# Cross-platform version (Windows compatible)
Bash: node $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/scripts/check-prerequisites.js [android|ios|all]

# List available devices (emulators, simulators, physical)
Bash: $CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/scripts/list-devices.sh [android|ios|all]
```

## Troubleshooting Quick Index

| Symptom | Quick Fix |
|---------|-----------|
| Device not found | Verify emulator/simulator running |
| Screenshot errors | Restart Claude Code session |
| Elements not detected | Wait for app load, try scrolling |
| Tap not registering | Verify coordinates, add wait |
| Text not entering | Tap field to focus first |
| Permission dialog blocking | See `workflows.md` → System Dialog Handling |
| Biometric prompt appears | Use password fallback or pre-auth state |

**Full reference**: `$CLAUDE_PLUGIN_ROOT/skills/mobile-mcp-mastery/references/troubleshooting.md`

## When Accessibility Mode Fails

Canvas-based apps bypass accessibility tree - use Visual Sense Mode (screenshots) exclusively.

**Common examples**: Unity games, Flutter apps (custom rendering), Google Maps (WebGL), custom drawing apps.

> **Full list and detection guidance**: See `tools-quick.md` → "Accessibility Mode Limitations"

## When NOT to Use Mobile-MCP

- Web automation (use browser tools instead)
- Desktop app automation
- Tasks not requiring device interaction
- When native app testing frameworks (Appium, Maestro) are already configured
