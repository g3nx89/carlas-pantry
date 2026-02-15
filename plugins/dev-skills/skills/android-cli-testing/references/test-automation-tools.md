# Cross-App Test Automation Reference

CLI-only execution of cross-app and end-to-end test automation tools: UI Automator for system-level interactions, Appium for cross-platform multi-device testing, and Maestro for YAML-driven flows.

> For Espresso and Compose testing, see test-espresso-compose.md.

## UI Automator

### Hierarchy Inspection

```bash
adb shell uiautomator dump /sdcard/uidump.xml
adb pull /sdcard/uidump.xml .

# Compressed (removes generic wrappers)
adb shell uiautomator dump --compressed /sdcard/uidump_compressed.xml
```

The XML contains class names, resource IDs, text, content descriptions, and bounds.

### Test Execution

UI Automator tests use `UiDevice` API and run via `am instrument` like Espresso:

```bash
adb shell am instrument -w -r \
  -e class com.example.app.UiAutomatorSmokeTest \
  com.example.app.test/androidx.test.runner.AndroidJUnitRunner
```

### When to Use

- **Compose/Espresso**: In-app process tests (see `test-espresso-compose.md`)
- **UI Automator**: Cross-app flows (notifications, settings, intents, multi-app journeys)

Combine them: use Compose tests for internal semantics, UI Automator for cross-app and accessibility verification.

## Appium (CLI Server + Tests)

### Server CLI

```bash
# Start Appium 2.x server
appium server --address 0.0.0.0 --port 4723

# Custom port and log level
appium server --address 0.0.0.0 --port 5000 --log-level info
```

### Parallel Execution Setup

Run multiple Appium servers, each targeting a different device:

```bash
# Server for device 1 (unique port + bootstrap port)
appium -p 4723 -bp 5723 -U emulator-5554 \
  --session-override --relaxed-security --log appium1.log &

# Server for device 2
appium -p 4724 -bp 5724 -U emulator-5556 \
  --session-override --relaxed-security --log appium2.log &

# Run test suites in parallel
pytest tests/ -n 2
```

Key flags for parallel:
- `-bp` (bootstrap port): must be unique per instance to avoid UiAutomator2 port conflicts
- `-U <serial>`: binds server to a specific device
- `systemPort` capability: set unique values per device in capabilities JSON to avoid internal port conflicts
- `--session-override`: allows reconnecting if previous session exists
- `--log <file>`: capture per-server logs for CI debugging

Debug a session manually:

```bash
curl -X POST http://localhost:4723/session \
  -H 'Content-Type: application/json' \
  -d '{"capabilities": {"alwaysMatch": {"platformName": "Android", ...}}}'
```

### Android Capabilities

```json
{
  "platformName": "Android",
  "appium:automationName": "UiAutomator2",
  "appium:deviceName": "emulator-5554",
  "appium:platformVersion": "14",
  "appium:appPackage": "com.example.app",
  "appium:appActivity": "com.example.app.MainActivity",
  "appium:noReset": true,
  "appium:newCommandTimeout": 300
}
```

CLI invocation depends on your test runner (JUnit/TestNG/pytest); everything is scriptable via shell.

## Maestro (CLI-First Flows)


YAML-driven, no test code compilation required.

### Setup and Basic Commands

```bash
maestro --version
maestro devices              # List connected devices

# Run a single flow
maestro test flow.yaml

# Run all flows in directory
maestro test .maestro/

# Record a new flow interactively (captures into YAML with video)
maestro record output_flow.yaml

# Open Maestro Studio — browser-based UI inspector at localhost:9999
maestro studio
```

### CI and Multi-Device Options

```bash
# JUnit XML output for CI result parsing
maestro test flows/ --format junit --output maestro-results/

# Target specific device when multiple connected
maestro test flow.yaml --device emulator-5554

# Skip app reinstall between flow runs (faster iteration)
maestro test flow.yaml --no-setup

# Parallel execution: run separate processes targeting different devices
maestro test flows/ --device emulator-5554 &
maestro test flows/ --device emulator-5556 &
wait
```

Maestro Studio (`maestro studio`) launches a browser-based inspector useful for exploring the UI tree and building selectors interactively.

### Flow Example

```yaml
appId: com.example.app

---
- launchApp
- tapOn: "Login"
- inputText: "user@example.com"
- tapOn: "Submit"
- assertVisible: "Welcome"
```

CI usage: invoke `maestro test` as a job step. Best for high-level E2E scenarios.
