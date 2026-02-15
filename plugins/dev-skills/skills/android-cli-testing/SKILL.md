---
name: android-cli-testing
description: This skill should be used when the user asks to "run Android tests from CLI", "debug Android app with ADB", "set up emulator for CI", "launch headless emulator", "capture logcat output", "profile Android performance", "use adb shell commands", "wait for emulator boot", "run instrumented tests", "set up wireless debugging", "capture Perfetto traces", "check frame jank", "manage AVDs from command line", "disable animations for testing", "configure emulator for CI/CD", "use dumpsys for debugging", "capture bugreport", "record screen with adb", "set up port forwarding", "run am instrument", "set up USB debugging", "run Espresso tests from Gradle", "filter tests by class or annotation", "set up test sharding", "use Android Test Orchestrator", "run Compose UI tests", "set up Paparazzi screenshot tests", "use Roborazzi", "run Maestro flows", "generate code coverage with JaCoCo", "use Gradle Managed Devices", "inspect SQLite database from CLI", "read SharedPreferences from CLI", "run monkey testing", "detect memory leaks from CLI", "analyze ANR traces", "simulate Doze mode", "set up GitHub Actions for Android", "set up GitLab CI for Android", or mentions ADB, avdmanager, sdkmanager, emulator CLI, dumpsys, screenrecord, Espresso, Compose testing, UIAutomator, Maestro, Robolectric, Paparazzi, Roborazzi, JaCoCo, monkey, StrictMode, or Android CLI debugging. Covers Android SDK Emulator CLI, ADB testing/debugging, test frameworks (Espresso, Compose, Appium, Maestro), advanced debugging, physical device profiling, and CI/CD pipeline patterns. Delegates Genymotion-specific workflows to genymotion-expert.
version: 2.3.0
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
| ADB commands | `references/adb-reference.md` | Architecture, connection, app management, split APKs, cmd package, permissions, logcat, dumpsys, mCurrentFocus, fragment state, input, screen capture |
| Emulator CLI | `references/emulator-cli.md` | sdkmanager, avdmanager, emulator flags, config.ini, console, acceleration |
| Test frameworks | `references/test-frameworks.md` | Espresso, Compose testing (useUnmergedTree/printToLog debugging), UI Automator, Appium (parallel setup), Maestro (studio/CI flags), Robolectric (@Config/Compose gotchas), screenshots (Roborazzi extended), coverage (JaCoCo Kotlin), GMD (groups/GPU), flaky test quarantine (@FlakyTest), debugger attachment |
| Advanced debugging | `references/advanced-debugging.md` | StrictMode (device-wide ADB), SQL tracing, Content Providers, database/SharedPrefs (full round-trip), activity count leak detection, SIGQUIT thread dumps (deadlock detection), ndk-stack tombstone symbolization, ANR (forced simulation), monkey, Doze, battery/display simulation, process lifecycle (am kill vs force-stop), App Standby Buckets, LeakCanary instrumented tests |
| Performance profiling | `references/performance-profiling.md` | Perfetto, trace_processor SQL, gfxinfo framestats CSV, method tracing, heap dumps, Macrobenchmark, Baseline Profiles, APK size, physical device profiling |
| CI/CD patterns | `references/ci-testing-patterns.md` | Pipeline strategy, GMD CI settings (GPU/flaky retry/concurrency), video recording, logcat capture on failure, CI determinism (wipe-data/uninstall), flaky quarantine, physical device keep-awake, Firebase Test Lab CLI, resource cleanup, multi-device, OEM considerations, power tips |
| Workflow recipes | `references/workflow-recipes.md` | End-to-end scripts, GitHub Actions, GitLab CI, local test loop, diagnostics |
| Boot wait script | `scripts/wait-for-boot.sh` | CI emulator setup, reliable boot detection with timeout |

## 1. Emulator Quick Launch (Headless CI)

> **Full reference:** See `references/emulator-cli.md`

```bash
sdkmanager "platform-tools" "emulator" "system-images;android-34;google_apis;x86_64"
yes | sdkmanager --licenses

echo "no" | avdmanager create avd \
  --force -n "ci_test" \
  -k "system-images;android-34;google_apis;x86_64" \
  -d "pixel_6"

emulator -avd ci_test \
  -no-window -no-audio -no-boot-anim \
  -no-snapshot -gpu swiftshader_indirect \
  -memory 2048 -partition-size 4096 -wipe-data &
```

**System image selection**: Prefer `google_apis` for CI (smaller, root-capable). Avoid `google_apis_playstore` (Pixel Launcher causes background ANRs). For fastest CI, use ATD images: `system-images;android-30;aosp_atd;x86`.

## 2. Boot Wait Pattern (Critical)

> **Script:** See `scripts/wait-for-boot.sh`

`adb wait-for-device` is **insufficient** -- it returns when ADB daemon is reachable, before the system is fully booted. Installing apps or running tests at this point fails.

```bash
# Simplified one-liner (checks sys.boot_completed only):
adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed | tr -d "\r") ]]; do sleep 1; done; input keyevent 82'
```

For production CI, use `scripts/wait-for-boot.sh` instead — it checks **both** `sys.boot_completed == 1` and `init.svc.bootanim == stopped`, verifies PackageManager readiness, and includes a configurable timeout. After boot, disable animations:

```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

## 3. ADB Essentials

> **Full reference:** See `references/adb-reference.md`

ADB uses a server-client-daemon architecture where all commands serialize through a single server process on port 5037. Under heavy parallel load, implement queueing or rate-limiting. Recovery: `adb kill-server && adb start-server`.

### Multi-Device Targeting

```bash
adb -s <serial> <command>           # By serial number
adb -d <command>                    # USB device only
adb -e <command>                    # Emulator only
export ANDROID_SERIAL=emulator-5554 # Environment variable
```

### App-Specific Logcat

```bash
adb logcat --pid=$(adb shell pidof -s com.example.app)
adb logcat -b crash -d > crash_log.txt
adb logcat -e "Exception|Error"
```

### Instrumented Test Execution

```bash
adb shell am instrument -w \
  -e class com.example.test.LoginTest \
  com.example.test/androidx.test.runner.AndroidJUnitRunner
```

Filter by class (`-e class`), method (`#testValidLogin`), package (`-e package`), or annotation (`-e notAnnotation`). See `references/adb-reference.md` for all variants and flags.

## 4. Performance Profiling

> **Full reference:** See `references/performance-profiling.md`

### Frame Jank Detection

```bash
adb shell dumpsys gfxinfo <package> reset   # Reset counters
# ... run test scenario ...
adb shell dumpsys gfxinfo <package>          # Check janky frames
```

### Perfetto Traces (Android 9+)

```bash
adb shell perfetto -o /data/misc/perfetto-traces/trace.perfetto-trace -t 20s \
  sched freq idle am wm gfx view dalvik input res memory
```

See `references/performance-profiling.md` for frame timing interpretation, helper scripts, method tracing, heap analysis, and physical device CPU/thermal profiling.

## 5. Physical Device Debugging

> **Connection commands:** See `references/adb-reference.md`. **Device setup and OEM quirks:** See `references/ci-testing-patterns.md`.

### Wireless Debugging (Android 11+)

```bash
adb pair 192.168.1.100:37885     # Enter 6-digit code (one-time)
adb connect 192.168.1.100:41913  # Connect (DIFFERENT port than pairing)
```

### Binary Data Capture

Always use `adb exec-out` (not `adb shell`) for binary data -- `adb shell` allocates a PTY that mangles `\n` to `\r\n`:

```bash
adb exec-out screencap -p > screen.png
```

## 6. Test Frameworks

> **Full reference:** See `references/test-frameworks.md`

### Gradle Test Filtering (Espresso + Compose)

```bash
# Single class
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.ui.LoginTest

# By annotation
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.annotation=androidx.test.filters.LargeTest

# Sharding across 2 devices
ANDROID_SERIAL=emulator-5554 ./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.numShards=2 \
  -Pandroid.testInstrumentationRunnerArguments.shardIndex=0
```

### Screenshot Testing (No Device)

```bash
./gradlew :ui:recordPaparazziDebug    # Record goldens (Paparazzi, JVM)
./gradlew :ui:verifyPaparazziDebug    # Verify against goldens
./gradlew recordRoborazziDebug        # Record (Roborazzi, Robolectric)
./gradlew verifyRoborazziDebug        # Verify
```

### Code Coverage

```bash
./gradlew createDebugCoverageReport                        # Instrumented only
./gradlew testDebugUnitTest connectedDebugAndroidTest jacocoTestReport  # Merged
```

See `references/test-frameworks.md` for Compose testing patterns, UI Automator, Maestro flows, Orchestrator setup, and GMD configuration.

## 7. Advanced Debugging

> **Full reference:** See `references/advanced-debugging.md`

### Monkey Testing

```bash
adb shell monkey -p com.example.app --throttle 500 -s 42 -v -v 10000 > monkey.log
```

### Doze Mode Simulation

```bash
adb shell dumpsys deviceidle enable
adb shell dumpsys deviceidle force-idle    # Enter Doze
adb shell dumpsys deviceidle unforce       # Exit
adb shell dumpsys battery reset
```

### Database Inspection

```bash
adb shell run-as com.example.app sqlite3 databases/mydb.db ".tables"
adb shell "run-as com.example.app cat shared_prefs/settings.xml"
```

See `references/advanced-debugging.md` for StrictMode, memory leaks, ANR/tombstone analysis, crash testing, and system simulation.

## 8. Workflow Recipes and CI Templates

See `references/workflow-recipes.md` for end-to-end scripts: local test loop, full regression with coverage, physical device diagnostics, multi-API testing via GMD, network debugging, memory leak investigation, GitHub Actions, and GitLab CI.

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Use `adb wait-for-device` alone as boot check | Poll `sys.boot_completed` AND `init.svc.bootanim` |
| Leave animations enabled in CI | Disable all three animation scales |
| Use `google_apis_playstore` images in CI | Use `google_apis` or `aosp_atd` images |
| Use `kill -9` on emulator processes | Use `adb emu kill` or telnet console `kill` |
| Trust `adb shell` exit codes | Parse output or use `adb shell "command; echo \$?"` |
| Use USB3 ports (connection drops) | Prefer USB2 ports for ADB stability |
| Run `am start` immediately after install | Wait or verify with `pm list packages \| grep <pkg>` |
| Use default 256KB logcat buffer in CI | Increase to 16MB: `adb logcat -G 16M` |
| Omit `-s <serial>` with multiple devices | Always specify serial in multi-device setups |
| Use HAXM (deprecated Jan 2023) | Use KVM (Linux), Hypervisor.Framework (macOS), WHPX/AEHD (Windows) |
| Revoke permission without expecting process kill | `pm revoke` kills the running app; plan restart in next step |
| Use `pm list packages` in hot loops | Use `cmd package list packages` (Binder-based, faster) |
| Use `Thread.sleep` for test synchronization | Use Compose `waitUntil` or Espresso idling resources |
| Overuse `testTag` in production code | Prefer content descriptions and semantic labels |
| Skip StrictMode during development | Enable early to catch disk/network main-thread issues |
| Run monkey with no seed | Use `-s <seed>` for reproducibility |
| Test only happy paths | Exercise offline/error paths via CLI simulation |
| Push SharedPrefs while app is running | Kill app first; in-memory cache overrides disk |
| Guess at DB performance from logs | Use `setprop log.tag.SQLiteStatements VERBOSE` for exact SQL tracing |
| Rely on global state between tests | Use Orchestrator or explicit teardown; tests must be independent |
| Skip locale/orientation/font testing | Run at least a few tests under varied config (dark mode, RTL, large font) |
| Upload raw DB dumps/logcat with PII to CI | Sanitize test data; protect CI artifacts containing user data |
| Skip CI job timeouts | Set `connectedAndroidTest` timeout; hung emulators tie up runners indefinitely |
| Debug with `am profile` on release builds | Use debuggable builds; R8/ProGuard strips symbols from release |
| Use `am force-stop` to test process death | Use `am kill` — it preserves saved instance state for proper recreation testing |
| Let flaky tests block the PR gate | Quarantine with `@FlakyTest` annotation; run in separate nightly job |
| Use default Compose finders for merged semantics | Add `useUnmergedTree = true` when nodes inside merged containers are missed |
| Debug Compose test failures without visibility | Use `printToLog("TAG")` on semantics nodes to see the actual tree |
| Read tombstones without symbolizing | Use `ndk-stack` to convert hex addresses to function names |
| Call `activity.finish()` before Compose assertions | Assert first, then clean up — disposal races cause false failures |
| Over-mock Bundle/Parcel in unit tests | Use Robolectric or instrumented tests; mocks hide serialization bugs |

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
| Port forward | `adb forward tcp:6100 tcp:7100` |
| Reverse forward | `adb reverse tcp:8080 tcp:8080` |
| Set HTTP proxy | `adb shell settings put global http_proxy <ip>:8888` |
| Clear proxy | `adb shell settings put global http_proxy :0` |
| Create AVD | `avdmanager create avd -n <name> -k <image> -d <device>` |
| Launch headless | `emulator -avd <name> -no-window -no-audio -gpu swiftshader_indirect` |
| List AVDs | `emulator -list-avds` |
| Kill emulator | `adb emu kill` |
| Bugreport | `adb bugreport bugreport.zip` |
| Run Gradle tests (filtered) | `./gradlew connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=<class>` |
| Record Paparazzi goldens | `./gradlew :ui:recordPaparazziDebug` |
| Verify Roborazzi screenshots | `./gradlew verifyRoborazziDebug` |
| Code coverage report | `./gradlew createDebugCoverageReport` |
| Monkey test | `adb shell monkey -p <package> --throttle 500 -s 42 -v 10000` |
| Force Doze | `adb shell dumpsys deviceidle force-idle` |
| Inspect database | `adb shell run-as <package> sqlite3 databases/<db>.db` |
| Read SharedPrefs | `adb shell "run-as <package> cat shared_prefs/<name>.xml"` |
| Heap dump | `adb shell am dumpheap <package> /data/local/tmp/heap.hprof` |
| ANR traces | `adb shell "cat /data/anr/traces.txt"` |
| Check focused window | `adb shell dumpsys window windows \| grep mCurrentFocus` |
| Check fragment state | `adb shell dumpsys activity top` (look for Active Fragments + mHidden) |
| Split APK install | `adb shell pm install-create -S <size>` then `install-write`/`install-commit` |
| Cold start benchmark | `adb shell am start -S -W -n <package>/.Activity` (parse TotalTime) |
| Perfetto SQL query | `trace_processor_shell trace.perfetto-trace --query "SELECT ..."` |
| Log all SQL statements | `adb shell setprop log.tag.SQLiteStatements VERBOSE` |
| Flag slow DB queries | `adb shell setprop db.log.slow_query_threshold 200` |
| StrictMode (device-wide) | `adb shell settings put global strict_mode_enabled 1` |
| Query Content Provider | `adb shell content query --uri content://settings` |
| Dump SharedPrefs (runtime) | `adb shell dumpsys activity preferences <package>` |
| Maestro Studio | `maestro studio` |
| Maestro CI (JUnit XML) | `maestro test flows/ --format junit --output results/` |
| Roborazzi compare (no fail) | `./gradlew compareRoborazziDebug` |
| Roborazzi clear screenshots | `./gradlew clearRoborazziDebug` |
| GMD headless GPU | `-Pandroid.testoptions.manageddevices.emulator.gpu=swiftshader_indirect` |
| App Standby Bucket | `adb shell am set-standby-bucket <package> rare` |
| Force ANR trace | `adb shell am hang` |
| Baseline Profile gen | `./gradlew :app:generateReleaseBaselineProfile` |
| APK size analysis | `apkanalyzer apk summary app-release.apk` |
| Do Not Disturb | `adb shell settings put global zen_mode 1` |
| Force RTL layout | `adb shell settings put global debug_force_rtl 1` |
| Set timezone | `adb shell setprop persist.sys.timezone "America/New_York"` |
| Flaky test retry | `-Pandroid.testInstrumentationRunnerArguments.numRetries=1` |
| dmtracedump HTML | `dmtracedump -h profile.trace > profile.html` |
| SurfaceFlinger layers | `adb shell dumpsys SurfaceFlinger --list` |
| SIGQUIT thread dump | `adb shell "kill -3 $(pidof -s <package>)"` (output in logcat) |
| Symbolize tombstone | `ndk-stack -sym <native-libs-path> -dump tombstone_00` |
| Set battery level | `adb shell dumpsys battery set level 5` |
| Set charging status | `adb shell dumpsys battery set status 2` (2=charging, 5=full) |
| Override display density | `adb shell wm density 480` / `adb shell wm density reset` |
| Override display size | `adb shell wm size 1080x1920` / `adb shell wm size reset` |
| Polite process kill | `adb shell am kill <package>` (preserves saved state) |
| Keep screen on (CI) | `adb shell svc power stayon usb` |
| Exclude flaky tests | `-Pandroid.testInstrumentationRunnerArguments.notAnnotation=androidx.test.filters.FlakyTest` |
| Debugger attach in tests | `adb shell am instrument -w -e debug true -e class <test> <runner>` |
| Firebase Test Lab run | `gcloud firebase test android run --type instrumentation --app <apk> --test <test-apk>` |
| Compose clock control | `composeTestRule.mainClock.autoAdvance = false` + `advanceTimeBy(ms)` |
| Simulate low memory | `adb shell am send-trim-memory <package> RUNNING_LOW` |
| List notifications | `adb shell cmd notification list` |
| Create user profile | `adb shell pm create-user "Work"` |
| Switch user | `adb shell am switch-user <user_id>` |
| Multi-window launch | `adb shell am start -n <package>/.Activity --windowingMode 5` |
| Sync changed files | `adb sync data` |

