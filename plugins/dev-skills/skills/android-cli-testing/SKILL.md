---
name: android-cli-testing
description: This skill should be used when the user asks to "run Android tests from CLI", "debug Android app with ADB", "set up emulator for CI", "launch headless emulator", "capture logcat output", "profile Android performance", "use adb shell commands", "wait for emulator boot", "run instrumented tests", "set up wireless debugging", "capture Perfetto traces", "check frame jank", "manage AVDs from command line", "disable animations for testing", "configure emulator for CI/CD", "use dumpsys for debugging", "capture bugreport", "record screen with adb", "set up port forwarding", "run am instrument", "set up USB debugging", "run Espresso tests from Gradle", "filter tests by class or annotation", "set up test sharding", "use Android Test Orchestrator", "run Compose UI tests", "set up Paparazzi screenshot tests", "use Roborazzi", "run Maestro flows", "generate code coverage with JaCoCo", "use Gradle Managed Devices", "inspect SQLite database from CLI", "read SharedPreferences from CLI", "run monkey testing", "detect memory leaks from CLI", "analyze ANR traces", "simulate Doze mode", "set up GitHub Actions for Android", "set up GitLab CI for Android", "parse JUnit XML test results", "detect flaky Android tests", "run Android benchmarks from CLI", "generate Baseline Profile", "track APK size", "measure Android startup time", "detect benchmark regressions", "enforce coverage thresholds", "pre-flight CI validation", "diagnose Android crashes from CLI", or mentions ADB, avdmanager, sdkmanager, emulator CLI, dumpsys, screenrecord, Espresso, Compose testing, UIAutomator, Maestro, Robolectric, Paparazzi, Roborazzi, JaCoCo, monkey, StrictMode, Microbenchmark, Macrobenchmark, Baseline Profiles, apkanalyzer, or Android CLI debugging. Covers Android SDK Emulator CLI, ADB testing/debugging, test frameworks (Espresso, Compose, Appium, Maestro), test result parsing, benchmarking, advanced debugging, physical device profiling, and CI/CD pipeline patterns. Delegates Genymotion-specific workflows to genymotion-expert.
version: 2.6.0
allowed-tools: Read, Glob, Grep, Bash
---

# Android CLI Testing and Debugging

CLI-driven Android testing and debugging without Android Studio. Covers ADB, Android SDK Emulator, physical device debugging, and CI/CD pipeline patterns for Kotlin/Jetpack Compose projects.

## When to Use

- Running instrumented or unit tests from the terminal
- Managing emulators (create, launch, configure) via CLI
- Debugging with ADB: logcat, dumpsys, shell commands
- Setting up headless emulators for CI/CD
- Profiling performance (frames, memory, CPU, traces)
- Physical device debugging (USB, wireless, OEM quirks)
- Capturing screenshots, screen recordings, or Perfetto traces
- Simulating network conditions, battery state, or input events
- Running Espresso, Compose, Maestro, or UI Automator tests from CLI
- Screenshot regression testing (Paparazzi, Roborazzi)
- Code coverage with JaCoCo
- Advanced debugging: StrictMode, monkey testing, memory leaks, ANR analysis
- Setting up GitHub Actions or GitLab CI for Android

## When NOT to Use

- **Genymotion emulation** → Use `genymotion-expert` skill
- **Android navigation/permissions** → Use `android-expert` skill
- **Compose UI components** → Use `compose-expert` skill
- **Gradle build issues** → Use `gradle-expert` skill
- **Kotlin coroutines/flows** → Use `kotlin-coroutines` skill

## Decision Framework: Test Target Selection

| Test Type | Target | Rationale |
|-----------|--------|-----------|
| Unit tests (JVM) | `./gradlew testDebugUnitTest` | No device needed |
| Compose UI tests | JVM via Robolectric | Fast, stable, high Compose fidelity |
| Instrumented UI tests | Emulator (GMD) | Primary CI target |
| Screenshot regression | JVM via Roborazzi, or GMD | Deterministic with `swiftshader_indirect` |
| Performance/benchmarks | **Physical device only** | Emulator results non-representative |
| Sensor-dependent tests | Physical device | Emulator sensor simulation insufficient |
| Network condition tests | Emulator (`-netdelay`/`-netspeed`) | Mock network layer for stability |
| OEM-specific validation | Physical device (specific OEM) | OEM skins affect behavior |

**Decision flowchart**: (1) Pure logic or Compose UI without framework -> **JVM**. (2) Needs framework but not hardware -> **Emulator/GMD**. (3) Hardware sensors, biometrics, Bluetooth, NFC, camera -> **Physical device**. (4) Performance benchmark -> **Physical device**. (5) Multi-API compatibility -> **Emulator matrix** via GMD device groups.

> **Key insight for Compose**: Robolectric + Compose on JVM achieves high fidelity because Compose manages its own UI pipeline, relying less on legacy Android framework behavior. The majority of Compose UI tests can run without any device or emulator.

## Reference Map

| Topic | Reference File | When to Read |
|-------|----------------|--------------|
| ADB connection & apps | `references/adb-connection-apps.md` | Architecture, USB/WiFi/TCP, app install, permissions, Activity Manager |
| ADB logcat & dumpsys | `references/adb-logcat-dumpsys.md` | Logcat filtering/buffers, dumpsys services, window focus, fragment state |
| ADB file I/O & system | `references/adb-io-system.md` | File push/pull, database access, network debug, input, screen capture |
| Emulator CLI | `references/emulator-cli.md` | sdkmanager, avdmanager, emulator flags, config.ini, console, acceleration |
| Espresso & Compose testing | `references/test-espresso-compose.md` | Gradle filtering, sharding, Orchestrator, Compose semantics/debugging/clock |
| UI Automator, Appium, Maestro | `references/test-automation-tools.md` | Cross-app testing, Appium parallel setup, Maestro CLI/flows |
| Robolectric & screenshots | `references/test-robolectric-screenshots.md` | JVM tests, Compose+Robolectric gotchas, Paparazzi, Roborazzi |
| Coverage & GMD | `references/test-coverage-gmd.md` | JaCoCo setup/merging, GMD definition/groups/CI properties |
| Data & storage debugging | `references/debug-data-storage.md` | StrictMode, SQLite/Room, SQL tracing, SharedPreferences |
| UI & memory debugging | `references/debug-ui-memory.md` | UIAutomator dump, window state, Compose semantics, memory leaks, heap dumps |
| Crashes & monkey testing | `references/debug-crashes-monkey.md` | ANR traces, tombstones, ndk-stack, crash testing, monkey |
| System simulation | `references/debug-system-simulation.md` | Doze, battery, density, locale, dark mode, multi-window |
| Performance profiling | `references/performance-profiling.md` | Perfetto, gfxinfo, method tracing, heap analysis, Macrobenchmark |
| Benchmark CLI | `references/benchmark-cli.md` | Microbenchmark, Macrobenchmark, startup measurement, Baseline Profiles, APK size, regression detection |
| Test result parsing | `references/test-result-parsing.md` | JUnit XML parsing, failure triage, flaky detection, iterative debugging loop, CI integration |
| CI pipeline config | `references/ci-pipeline-config.md` | Test tiers, emulator recommendations, GMD CI, determinism, flaky quarantine, Firebase, pre-flight, coverage gates |
| Device setup & OEM | `references/device-setup-oem.md` | Physical device CLI setup, multi-device, OEM quirks, ADB reliability |
| GUI walkthroughs | `references/gui-walkthroughs.md` | Device GUI operations (Developer Options, USB debugging, OEM toggles) |
| Workflow recipes | `references/workflow-recipes.md` | End-to-end scripts, GitHub Actions, GitLab CI |
| Deep search prompts | `references/deep-search-prompts.md` | Browser-based research prompts for further skill enrichment |
| Boot wait script | `scripts/wait-for-boot.sh` | CI emulator setup, reliable boot detection with timeout |

## Essentials

### Emulator Setup for CI

Install SDK components, create AVD, and launch headless with `swiftshader_indirect` GPU. Prefer `google_apis` images (smaller, root-capable) or ATD images (`aosp_atd`) for fastest CI boot. Avoid `google_apis_playstore` (Pixel Launcher ANRs). See `references/emulator-cli.md` for full flags and config.ini options.

### Boot Wait (Critical)

`adb wait-for-device` is **insufficient** — it returns when ADB daemon is reachable, before the system boots. Use `scripts/wait-for-boot.sh` which checks `sys.boot_completed == 1` AND `init.svc.bootanim == stopped` with configurable timeout. After boot, disable animations:

```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

### ADB Architecture

ADB serializes all commands through a single server on port 5037. Under heavy parallel load, implement queueing. Recovery: `adb kill-server && adb start-server`. Target devices with `-s <serial>`, `-d` (USB), or `-e` (emulator). See `references/adb-connection-apps.md`.

### Test Execution

Run Espresso/Compose tests via Gradle (`./gradlew connectedDebugAndroidTest`) with filtering by class, method, package, or annotation using `-Pandroid.testInstrumentationRunnerArguments.*`. Shard across devices with `numShards`/`shardIndex`. See `references/test-espresso-compose.md` for full patterns. For Maestro, Appium, or UI Automator, see `references/test-automation-tools.md`.

### Screenshot Testing

Record and verify golden images with Paparazzi (JVM, no device) or Roborazzi (Robolectric). See `references/test-robolectric-screenshots.md`.

### Test Result Parsing

After test runs, parse JUnit XML results to extract failures, classify crash types, detect flaky tests via re-run comparison, and generate PR comment summaries. Enables autonomous test → diagnose → fix → re-run loops. See `references/test-result-parsing.md`.

### Benchmarking

Run Microbenchmarks (tight code loops), Macrobenchmarks (startup, scroll jank), and startup measurement (`am start -W`) from CLI. Generate and verify Baseline Profiles, track APK size, and detect benchmark regressions via JSON comparison. **Physical device required** for meaningful results. See `references/benchmark-cli.md`.

### Performance Profiling

Capture frame jank via `adb shell dumpsys gfxinfo`, trace execution with Perfetto, and analyze heap dumps. See `references/performance-profiling.md`.

### Debugging

Inspect databases/SharedPreferences via `run-as` + `sqlite3` (see `references/debug-data-storage.md`). Detect memory leaks with activity count monitoring or heap dumps (see `references/debug-ui-memory.md`). Analyze ANR traces and tombstones with `ndk-stack` (see `references/debug-crashes-monkey.md`). Simulate Doze, battery, locale, and config changes (see `references/debug-system-simulation.md`).

### CI/CD Pipelines

End-to-end GitHub Actions and GitLab CI templates in `references/workflow-recipes.md`. CI strategy, GMD configuration, flaky test quarantine, and Firebase Test Lab in `references/ci-pipeline-config.md`. Physical device CLI setup and OEM quirks in `references/device-setup-oem.md`.

### Physical Device GUI Operations

Some physical device setup tasks (enabling Developer Options, USB debugging, OEM-specific toggles) require manual GUI interaction and cannot be automated via CLI. **When a GUI-only task is needed**, load `references/gui-walkthroughs.md` and relay the step-by-step instructions to the user. The agent should inform the user that the operation requires manual device interaction and guide them through each step.

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Use `adb wait-for-device` alone as boot check | Poll `sys.boot_completed` AND `init.svc.bootanim` |
| Leave animations enabled in CI | Disable all three animation scales |
| Use `google_apis_playstore` images in CI | Use `google_apis` or `aosp_atd` images |
| Trust `adb shell` exit codes | Parse output or use `adb shell "command; echo \$?"` |
| Use `Thread.sleep` for test synchronization | Use Compose `waitUntil` or Espresso idling resources |
| Push SharedPrefs while app is running | Kill app first; in-memory cache overrides disk |
| Use `am force-stop` to test process death | Use `am kill` — preserves saved instance state |
| Let flaky tests block the PR gate | Quarantine with `@FlakyTest`; run in nightly job |
| Omit `-s <serial>` with multiple devices | Always specify serial in multi-device setups |
| Rely on global state between tests | Use Orchestrator or explicit teardown |
| Run benchmarks on emulators | Use physical devices — emulator numbers are not meaningful |
| Trust Gradle exit code alone for test results | Parse JUnit XML — build errors and test failures differ |
| Use `am start -W` as sole CI startup metric | Use Macrobenchmark with JSON output for regression tracking |

> Domain-specific anti-patterns in `test-coverage-gmd.md`, `debug-system-simulation.md`, `ci-pipeline-config.md`, and `benchmark-cli.md`.

## Quick Reference

| Task | Command |
|------|---------|
| List devices | `adb devices -l` |
| Install APK | `adb install -r -t app.apk` |
| Clear app data | `adb shell pm clear <package>` |
| Force stop app | `adb shell am force-stop <package>` |
| Start activity | `adb shell am start -n <package>/.MainActivity` |
| Deep link test | `adb shell am start -a android.intent.action.VIEW -d "myapp://path"` |
| Screenshot | `adb exec-out screencap -p > screen.png` |
| Screen record | `adb shell screenrecord /sdcard/video.mp4` |
| Check API level | `adb shell getprop ro.build.version.sdk` |
| Enable dark mode | `adb shell cmd uimode night yes` |
| Create AVD | `avdmanager create avd -n <name> -k <image> -d <device>` |
| Launch headless | `emulator -avd <name> -no-window -no-audio -gpu swiftshader_indirect` |
| Kill emulator | `adb emu kill` |
| Run tests (filtered) | `./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=<class>` |
| Record Paparazzi | `./gradlew :ui:recordPaparazziDebug` |
| Verify Roborazzi | `./gradlew verifyRoborazziDebug` |
| Coverage report | `./gradlew createDebugCoverageReport` |
| Monkey test | `adb shell monkey -p <package> --throttle 500 -s 42 -v 10000` |
| Force Doze | `adb shell dumpsys deviceidle force-idle` |
| Bugreport | `adb bugreport bugreport.zip` |

> Full ADB command reference: `references/adb-connection-apps.md`, `references/adb-logcat-dumpsys.md`, `references/adb-io-system.md`.
