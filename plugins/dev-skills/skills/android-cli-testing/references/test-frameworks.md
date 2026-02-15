# Test Automation Frameworks Reference

CLI-only execution of Android test frameworks: Espresso, Compose Testing, UI Automator, Appium, Maestro, Robolectric, screenshot testing, and code coverage.

## 1. Espresso and AndroidJUnitRunner

### Gradle CLI Execution

```bash
# All connected tests
./gradlew connectedAndroidTest

# Specific build variant
./gradlew connectedDebugAndroidTest
./gradlew freeDebugAndroidTest

# Useful flags
./gradlew connectedDebugAndroidTest --info --stacktrace
./gradlew connectedDebugAndroidTest --fail-fast
```

### Gradle Test Filtering

Pass `android.testInstrumentationRunnerArguments.*` as `-P` properties:

```bash
# Single test class
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.ui.LoginTest

# Single test method
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.ui.LoginTest#validLogin_showsHome

# Multiple classes
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.ui.LoginTest,com.example.ui.SignupTest

# Filter by package
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.package=com.example.ui.auth

# Filter by annotation
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.annotation=androidx.test.filters.LargeTest

# Exclude annotation
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.notAnnotation=com.example.test.SlowTest
```

### ADB Direct Execution

> **Note:** For `am instrument` basics, see `adb-reference.md`. This section covers advanced usage.

```bash
# List installed instrumentations
adb shell pm list instrumentation

# Sharding — run shard 0 of 4
adb shell am instrument -w -r \
  -e numShards 4 \
  -e shardIndex 0 \
  com.example.app.test/androidx.test.runner.AndroidJUnitRunner
```

The `-r` flag produces raw `INSTRUMENTATION_STATUS` output, one block per test. This is easier to parse programmatically in CI scripts than the default human-readable format. Parse for `INSTRUMENTATION_STATUS_CODE: -1` (failure) or grep for `FAILURES!!!`.

### Debugger Attachment

```bash
# Wait for debugger before running tests (blocks until JDWP debugger connects)
adb shell am instrument -w -r \
  -e debug true \
  -e class com.example.test.FlakyTest \
  com.example.app.test/androidx.test.runner.AndroidJUnitRunner
```

The `-e debug true` flag pauses test execution at launch, showing "Waiting for debugger" — attach from Android Studio or `jdb`. Useful for stepping through a single flaky test.

### Flaky Test Quarantine

Isolate known-flaky tests with the `@FlakyTest` annotation and exclude them from main CI:

```kotlin
import androidx.test.filters.FlakyTest

@FlakyTest(bugId = 12345, detail = "Intermittent timeout on CI emulators")
@Test
fun networkSync_completesEventually() { ... }
```

Filter them out in CI:

```bash
# Exclude flaky tests from main suite
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.notAnnotation=androidx.test.filters.FlakyTest

# Run ONLY flaky tests (nightly quarantine suite)
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.annotation=androidx.test.filters.FlakyTest
```

**Quarantine strategy**: exclude `@FlakyTest` from PR gates, run them in a separate nightly job with retry logic, and fix or delete tests that remain flaky for more than 2 sprints.

### Gradle-Based Sharding

```bash
# On device A (emulator-5554)
ANDROID_SERIAL=emulator-5554 \
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.numShards=2 \
  -Pandroid.testInstrumentationRunnerArguments.shardIndex=0

# On device B (emulator-5556)
ANDROID_SERIAL=emulator-5556 \
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.numShards=2 \
  -Pandroid.testInstrumentationRunnerArguments.shardIndex=1
```

### AndroidJUnitRunner Configuration

```kotlin
android {
  defaultConfig {
    testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    testInstrumentationRunnerArguments["clearPackageData"] = "true"
  }
  testOptions {
    animationsDisabled = true
  }
}
```

### Android Test Orchestrator

Runs each test in isolation (own instrumentation invocation, clean app state). Greatly improves stability of large suites.

Gradle setup:

```kotlin
android {
  testOptions {
    execution = "ANDROIDX_TEST_ORCHESTRATOR"
  }
}

dependencies {
  androidTestUtil("androidx.test:orchestrator:<version>")
}
```

CLI execution is unchanged (`./gradlew connectedDebugAndroidTest`). For pure-ADB flows, install orchestrator + services APKs manually:

```bash
adb install -g -r --force-queryable orchestrator-<version>.apk
adb install -g -r --force-queryable test-services-<version>.apk
```

### Result Collection

Gradle writes results to:
- XML: `app/build/outputs/androidTest-results/connected/` (per device)
- HTML: `app/build/reports/androidTests/connected/`

For ADB-only workflows, parse console output (`-r` flag) or use a custom listener writing XML to device storage, then `adb pull`.

## 2. Jetpack Compose Testing (Instrumented)

### Test Rules

- `createComposeRule()` — pure Compose content, no real Activity
- `createAndroidComposeRule<Activity>()` — real Activity for navigation, resources, lifecycles

```kotlin
class MyComposeTest {
  @get:Rule
  val composeTestRule = createComposeRule()

  @Test
  fun myTest() {
    composeTestRule.setContent {
      AppTheme { MainScreen(uiState = fakeUiState) }
    }
    composeTestRule.onNodeWithText("Continue").performClick()
    composeTestRule.onNodeWithText("Welcome").assertIsDisplayed()
  }
}
```

CLI invocation is identical to Espresso:

```bash
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.MyComposeTest

# Or via ADB:
adb shell am instrument -w -r \
  -e class com.example.MyComposeTest \
  com.example.app.test/androidx.test.runner.AndroidJUnitRunner
```

### Semantics, Tags, and Matchers

Compose tests traverse the **semantics tree**, not the view hierarchy:

```kotlin
@Composable
fun LoginButton(onClick: () -> Unit) {
  Button(
    onClick = onClick,
    modifier = Modifier.semantics { testTag = "login_button" }
  ) { Text("Login") }
}
```

Finders and assertions:

```kotlin
composeTestRule.onNodeWithTag("login_button").performClick()
composeTestRule.onNodeWithText("Login").assertExists()
composeTestRule.onNode(hasContentDescription("Profile picture")).assertExists()
```

Custom matchers:

```kotlin
fun hasClickLabel(label: String) = SemanticsMatcher(
  "Clickable action with label: $label"
) {
  it.config.getOrNull(SemanticsActions.OnClick)?.label == label
}
```

**Best practice**: Avoid polluting production code with `testTag` when stable content descriptions or labels work. Use `testTag` only for genuinely invisible/ambiguous elements. Enable `testTagsAsResourceId` to make tags visible to UIAutomator.

### Debugging Compose Tests

```kotlin
// Print the semantics tree to logcat — essential for understanding what the test "sees"
composeTestRule.onRoot().printToLog("SEMANTICS")
// Output: Printing with useUnmergedTree = 'false'
//   Node #1 at (l=0, t=0, r=1080, b=1920)px
//    |-Node #2 ...

// Use useUnmergedTree = true when finders miss nodes inside merged semantics
// (e.g., Row/Column with mergeDescendants = true)
composeTestRule.onNodeWithText("Submit", useUnmergedTree = true).assertExists()
composeTestRule.onNodeWithTag("icon", useUnmergedTree = true).performClick()
```

When a `onNodeWithText` or `onNodeWithTag` call intermittently fails, add `useUnmergedTree = true` — merged semantics trees collapse child nodes, making them invisible to default finders. Always debug with `printToLog()` first to see the actual tree structure.

### Synchronization and Animations

Compose test rules auto-synchronize with recomposition and idleness.

```kotlin
// Wait for async state changes
composeTestRule.waitUntil {
  composeTestRule.onAllNodesWithTag("loading_indicator")
    .fetchSemanticsNodes().isEmpty()
}

// Other wait APIs (prefer over hardcoded sleeps)
composeTestRule.waitUntilExactlyOneExists(hasText("Welcome"))
composeTestRule.waitUntilDoesNotExist(hasTestTag("loading"))

// Run assertions after idle
composeTestRule.runOnIdle {
  // assertions here
}
```

**Avoid**: `Thread.sleep` — always use semantics-driven waits. Known issue: Compose tests with complex `LaunchedEffect`/`DisposableEffect` patterns can cause `AppNotIdleException` under Robolectric; prefer instrumented tests for complex async flows.

### Clock Control for Animations

For testing animations, timed transitions, or coroutine-driven delays, use `mainClock` to control time precisely:

```kotlin
@Test
fun progressAnimation_reachesEnd() {
  composeTestRule.mainClock.autoAdvance = false  // Pause auto-advance

  composeTestRule.setContent { AnimatedProgressBar() }

  // Advance time manually in controlled steps
  composeTestRule.mainClock.advanceTimeBy(500)   // 500ms
  composeTestRule.onNodeWithTag("progress").assertExists()

  composeTestRule.mainClock.advanceTimeBy(1500)  // Total: 2000ms
  composeTestRule.onNodeWithText("Complete").assertIsDisplayed()

  composeTestRule.mainClock.autoAdvance = true   // Resume normal clock
}
```

- `autoAdvance = false` prevents the test from racing through animations instantly
- `advanceTimeBy(ms)` steps the virtual clock forward by a precise amount
- Use this instead of `Thread.sleep` for deterministic animation testing
- Also controls `LaunchedEffect(Unit) { delay(ms) }` and `AnimatedVisibility` transitions

### Performance Notes

- x86/x86_64 emulators are significantly faster for Compose tests than ARM devices
- Use GMD or `android-emulator-runner` with x86_64 images in CI

## 3. UI Automator

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

- **Compose/Espresso**: In-app process tests
- **UI Automator**: Cross-app flows (notifications, settings, intents, multi-app journeys)

Combine them: use Compose tests for internal semantics, UI Automator for cross-app and accessibility verification.

## 4. Appium (CLI Server + Tests)

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

## 5. Maestro (CLI-First Flows)


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

## 6. Robolectric (JVM Tests)

### When to Use

Use Robolectric when:
- Fast JVM tests without device/emulator
- Testing pure Kotlin logic, ViewModels, some Compose UI
- Screenshot tests via Roborazzi

Prefer device tests when:
- Heavy graphics, animations, or hardware interactions
- Subtle lifecycle or background execution limits
- Verifying actual device behavior (OEM quirks)

### CLI Execution

```bash
./gradlew testDebugUnitTest
./gradlew :feature:testReleaseUnitTest
```

All Gradle CLI filters (`--tests`, etc.) apply.

### API Level Configuration

```kotlin
// Per-test API level simulation
@Config(sdk = [30])
class MyApiTest { ... }

// Per-class with multiple API levels (parameterized)
@Config(sdk = [21, 30, 33])
class MultiApiTest { ... }
```

Global configuration via `src/test/resources/robolectric.properties`:

```properties
sdk=30
```

### Compose + Robolectric Gotchas

- Use `@LooperMode(PAUSED)` and run queued tasks explicitly
- Must use `testImplementation` (not `androidTestImplementation`) for Compose testing artifact
- Requires `isIncludeAndroidResources = true` in testOptions:
  ```kotlin
  android {
    testOptions {
      unitTests.isIncludeAndroidResources = true
    }
  }
  ```
- Known `SwipeUp` bug in Compose 1.7 on Robolectric
- CameraX, Google Maps, and hardware-dependent APIs do not work on Robolectric
- AndroidX Room: use Robolectric's in-memory database for testing
- Large Compose suites may leak resources and slow down over time
- Move complex `LaunchedEffect`/`DisposableEffect` async flows to instrumented tests

### Molecule (Compose State Testing on JVM)

Molecule (Square) tests Compose state logic on the JVM without an Android environment by treating Composable functions as pure functions of state:

```kotlin
// Molecule treats a @Composable as a flow of states
val flow = moleculeFlow(RecompositionMode.Immediate) {
  MyPresenter(events)
}
```

CLI execution is standard JVM tests:

```bash
./gradlew testDebugUnitTest --tests "*.MyPresenterTest"
```

Use Molecule when the app heavily uses Compose for state management (presenters/view models). It enables testing recomposition flows as plain JUnit tests without Robolectric. Not mainstream yet but gaining traction for Compose-heavy architectures.

## 7. Screenshot and Visual Regression Testing

### Paparazzi (No Device, JVM)

```kotlin
plugins {
  id("com.android.library")
  id("app.cash.paparazzi") version "1.3.0"
}
```

Test example (JVM, `test` source set):

```kotlin
class GreetingPaparazziTest {
  @get:Rule
  val paparazzi = Paparazzi(deviceConfig = PIXEL_5)

  @Test
  fun greetingLooksCorrect() {
    paparazzi.snapshot {
      Greeting("Android")
    }
  }
}
```

CLI:

```bash
# Record golden images
./gradlew :ui:recordPaparazziDebug

# Verify against goldens (CI)
./gradlew :ui:verifyPaparazziDebug
```

### Roborazzi (Robolectric-Based)

```kotlin
plugins {
  id("io.github.takahirom.roborazzi") version "<version>"
}

android {
  testOptions {
    unitTests.isIncludeAndroidResources = true
  }
}
```

CLI:

```bash
# Record new screenshots
./gradlew recordRoborazziDebug

# Compare against goldens (fails on diff)
./gradlew verifyRoborazziDebug

# Produce visual diffs WITHOUT failing the build
./gradlew compareRoborazziDebug

# Clear all stored screenshots
./gradlew clearRoborazziDebug

# Compose Previews integration (JVM-only)
./gradlew recordRoborazziJvm
```

Property-based mode control (alternative to task names):

```bash
# Record mode via property
./gradlew testDebugUnitTest -Proborazzi.test.record=true

# Verify mode via property
./gradlew testDebugUnitTest -Proborazzi.test.verify=true

# Compare mode via property (diffs only, no failure)
./gradlew testDebugUnitTest -Proborazzi.test.compare=true
```

Output paths: `build/outputs/roborazzi/` (recorded images), `build/outputs/roborazzi/diffs` (diff images from compare/verify).

### Shot (Karumi, Instrumentation-Based)

```bash
./gradlew executeScreenshotTests
```

Device/emulator required. Less Compose-specific than Paparazzi/Roborazzi.

### Comparison

| Tool | Requires Device | Speed | Compose Support | Best For |
|------|----------------|-------|-----------------|----------|
| Paparazzi | No (JVM) | Fast | Good | Library modules, preview snapshots |
| Roborazzi | No (Robolectric) | Fast | Good | Full app screenshots with DI |
| Shot | Yes | Slow | Basic | Legacy view-based screenshots |

## 8. Code Coverage (JaCoCo)

### Instrumented Coverage

Enable in `debug` build type:

```kotlin
android {
  buildTypes {
    debug {
      isTestCoverageEnabled = true
    }
  }
}
```

Generate report:

```bash
./gradlew createDebugCoverageReport
```

Reports written to:
- `app/build/reports/coverage/debug/`

### Merging Unit + Instrumented Coverage

```kotlin
plugins {
  id("jacoco")
}

jacoco {
  toolVersion = "0.8.11"  // Match your Kotlin/AGP compatibility
}

tasks.register<JacocoReport>("jacocoTestReport") {
  dependsOn("testDebugUnitTest", "connectedDebugAndroidTest")

  val fileFilter = listOf(
    "**/R.class", "**/R$*.class",
    "**/BuildConfig.*", "**/Manifest*.*",
    "**/*Test*.*", "android/**/*.*"
  )

  val buildDir = layout.buildDirectory.get().asFile

  val javaDebugTree = fileTree(
    "${buildDir}/intermediates/classes/debug"
  ) { exclude(fileFilter) }

  val kotlinDebugTree = fileTree(
    "${buildDir}/tmp/kotlin-classes/debug"
  ) { exclude(fileFilter) }

  sourceDirectories.from(files("${project.projectDir}/src/main/java"))
  classDirectories.from(files(javaDebugTree, kotlinDebugTree))
  executionData.from(
    fileTree(dir = buildDir, includes = listOf(
      "jacoco/testDebugUnitTest.exec",
      "outputs/code-coverage/connected/*coverage.ec"
    ))
  )

  reports {
    xml.required.set(true)
    html.required.set(true)
  }
}
```

CLI:

```bash
./gradlew testDebugUnitTest connectedDebugAndroidTest jacocoTestReport
```

### Kotlin Coverage Fix

Add `includeNoLocationClasses = true` to filter synthetic classes generated by Kotlin compiler:

```kotlin
tasks.withType<Test> {
  jvmArgs(
    "-noverify",
    "-ea"
  )
  extensions.configure<JacocoTaskExtension> {
    isIncludeNoLocationClasses = true
    excludes = listOf("jdk.internal.*")
  }
}
```

### Manual CLI Merging

Merge coverage files from separate test runs using `jacococli.jar`:

```bash
java -jar jacococli.jar merge \
  app/build/jacoco/testDebugUnitTest.exec \
  app/build/outputs/code-coverage/connected/*coverage.ec \
  --destfile merged-coverage.exec

java -jar jacococli.jar report merged-coverage.exec \
  --classfiles app/build/intermediates/classes/debug \
  --sourcefiles app/src/main/java \
  --html coverage-report/
```

Coverage file locations: `.exec` for unit tests, `.ec` for instrumented tests. Known issues with GMD + coverage in AGP 8.1.

## 9. Gradle Managed Devices (GMD)

> **Note:** For CI-specific GMD patterns (test tiers, device groups, ATD image selection), see `ci-testing-patterns.md`.

### Device Definition

```kotlin
android {
  testOptions {
    managedDevices {
      localDevices {
        create("pixel2api30") {
          device = "Pixel 2"
          apiLevel = 30
          systemImageSource = "aosp-atd"  // or "google-atd"
        }
      }
    }
  }
}
```

### CLI

```bash
# Creates emulator, boots, runs tests, shuts down
./gradlew pixel2api30DebugAndroidTest

# With test filtering
./gradlew pixel2api30DebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.smoke.SmokeSuite

# GMD sharding
./gradlew pixel2api30DebugAndroidTest \
  -Pandroid.experimental.androidTest.numManagedDeviceShards=2

# Flaky test retry (re-run failed tests automatically)
./gradlew connectedAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.numRetries=1
```

### Device Groups (Multi-API Testing)

```kotlin
android {
  testOptions {
    managedDevices {
      localDevices {
        create("pixel2api30") {
          device = "Pixel 2"; apiLevel = 30; systemImageSource = "aosp-atd"
        }
        create("pixel2api33") {
          device = "Pixel 2"; apiLevel = 33; systemImageSource = "google-atd"
        }
      }
      groups {
        create("phoneGroup") {
          targetDevices.add(devices["pixel2api30"])
          targetDevices.add(devices["pixel2api33"])
        }
      }
    }
  }
}
```

Run group task: `./gradlew phoneGroupGroupDebugAndroidTest`

### GPU and CI Properties

```bash
# Headless CI rendering (required for swiftshader on GMD)
./gradlew pixel2api30DebugAndroidTest \
  -Pandroid.testoptions.manageddevices.emulator.gpu=swiftshader_indirect

# Intra-device parallelization (shard tests across N emulator instances)
./gradlew pixel2api30DebugAndroidTest \
  -Pandroid.experimental.androidTest.numManagedDeviceShards=4
```

Or set in `gradle.properties`:

```properties
android.testoptions.manageddevices.emulator.gpu=swiftshader_indirect
```

### Output Paths

- Test results: `build/outputs/androidTest-results/managedDevice/<device>/`
- HTML reports: `build/reports/androidTests/managedDevice/`

### Limitations

- ATD images lack hardware rendering; UI screenshot accuracy may differ from real devices
- Default cap: 16 concurrent emulator instances
- GMD + JaCoCo coverage has known issues in AGP 8.1

GMD integrates with Test Orchestrator via `testOptions.execution = "ANDROIDX_TEST_ORCHESTRATOR"`. Some corner cases with UTP config in early versions.

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Use `Thread.sleep` for synchronization | Use Compose `waitUntil` or Espresso idling resources |
| Overuse `testTag` in production code | Prefer content descriptions and semantic labels |
| Leave animations enabled in tests | Set `animationsDisabled = true` or disable via ADB |
| Run Compose async tests under Robolectric | Move complex `LaunchedEffect` flows to instrumented tests |
| Run screenshot tests without stable locale/font | Pin device configs and locale in Paparazzi/Roborazzi |
| Use Shot for Compose-heavy projects | Use Paparazzi or Roborazzi (no device, faster, more stable) |
| Skip test sharding on large suites | Use `numShards`/`shardIndex` or GMD shards for parallelism |
| Test implementation details (view hierarchy) | Test observable behavior via semantics |
| Call `activity.finish()` before assertions complete | Assert first, then clean up; Compose disposal races cause false failures |
| Over-mock Android types (Bundle, Parcel) in unit tests | Use Robolectric or instrumented tests; mocks hide real serialization bugs |
