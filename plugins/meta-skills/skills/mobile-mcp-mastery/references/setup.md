# Mobile-MCP Setup Guide

## Prerequisites

| Component | Required Version | Notes |
|-----------|-----------------|-------|
| Node.js | v22+ | v18+ works but v22+ recommended |
| npm | >=9 | Bundled with Node.js |
| Java | 11+ | Android only |
| Xcode | >=15 | macOS only, iOS development |
| Android SDK | Latest platform-tools | ADB required |

## Installation

### Claude Code CLI
```bash
claude mcp add mobile-mcp -- npx -y @mobilenext/mobile-mcp@latest
```

### MCP Config (all clients)
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

### Verify
```bash
npx -y @mobilenext/mobile-mcp@latest
```

## Environment Variables

```bash
# Android (all platforms)
export ANDROID_HOME=/path/to/android/sdk
export JAVA_HOME=/path/to/java

# iOS (macOS only)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Server config (optional)
export MCP_PORT=4723
export MCP_LOG_LEVEL=info  # info|debug|trace
export MCP_SESSION_TIMEOUT=300000
```

## Android Setup

1. Install Android Platform Tools from developer.android.com
2. Set `$ANDROID_HOME` environment variable
3. Start emulator: `emulator -avd YOUR_AVD_NAME`
4. Verify: `$ANDROID_HOME/platform-tools/adb devices`

## iOS Setup (macOS only)

1. Install Xcode from Mac App Store
2. Run: `xcode-select --install`
3. Boot simulator: `xcrun simctl boot "iPhone 16"`
4. v0.0.38+ auto-installs WebDriverAgent

**Alternative for physical devices**: If go-ios fails, try libimobiledevice:
```bash
brew install libimobiledevice
idevice_id -l  # List connected devices
```

## Architecture

```
┌─────────────────────┐
│   MCP Client        │  Claude Code, Cursor, VS Code
└─────────┬───────────┘
          │ STDIO
┌─────────▼───────────┐
│   Mobile-MCP        │  TypeScript server
│   Server            │
└─────────┬───────────┘
    ┌─────┴─────┐
    ▼           ▼
┌───────┐   ┌───────┐
│Android│   │  iOS  │
│Adapter│   │Adapter│
└───┬───┘   └───┬───┘
    ▼           ▼
  ADB +       Xcode +
  UIAutomator WebDriverAgent
```

**Communication modes**: STDIO (default), SSE (external services), HTTP port 4723 (debugging)
