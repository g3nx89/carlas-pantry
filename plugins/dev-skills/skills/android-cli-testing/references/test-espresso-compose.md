# Espresso and Compose Testing Reference

CLI-only execution of Espresso (AndroidJUnitRunner) and Jetpack Compose instrumented tests: filtering, sharding, orchestrator, debugging, and synchronization.

> For UI Automator, Appium, and Maestro, see test-automation-tools.md. For Robolectric and screenshots, see test-robolectric-screenshots.md. For JaCoCo and GMD, see test-coverage-gmd.md.

## Espresso and AndroidJUnitRunner

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

> **Note:** For `am instrument` basics, see `adb-connection-apps.md`. This section covers advanced usage.

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

## Jetpack Compose Testing (Instrumented)

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

**Best practice**: Avoid polluting production code with `testTag` when stable content descriptions or labels work. Use `testTag` only for genuinely invisible/ambiguous elements. Enable `testTagsAsResourceId` to make tags visible to UIAutomator (see `test-automation-tools.md` for UI Automator details).

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

**Avoid**: `Thread.sleep` — always use semantics-driven waits. Known issue: Compose tests with complex `LaunchedEffect`/`DisposableEffect` patterns can cause `AppNotIdleException` under Robolectric (see `test-robolectric-screenshots.md` for Robolectric gotchas); prefer instrumented tests for complex async flows.

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
- Use GMD (see `test-coverage-gmd.md`) or `android-emulator-runner` with x86_64 images in CI
