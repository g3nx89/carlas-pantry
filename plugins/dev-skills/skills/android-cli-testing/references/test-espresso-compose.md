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

### Advanced Test Filtering

Beyond class/package/annotation filters, `AndroidJUnitRunner` supports several lesser-known arguments:

```bash
# Exclude specific test class(es)
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.notClass=com.example.SlowTest

# Exclude entire package
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.notPackage=com.example.e2e

# Filter by test size annotation (@SmallTest, @MediumTest, @LargeTest)
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.size=small

# Repeat each test N times (useful for flaky test detection)
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.count=3

# Set per-test timeout (milliseconds)
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.timeout_msec=60000

# Attach a custom RunListener
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.listener=com.example.CIRunListener
```

All arguments can also be set in `build.gradle.kts`:

```kotlin
android {
  defaultConfig {
    testInstrumentationRunnerArguments(mapOf(
      "notClass"    to "com.example.SlowTest",
      "notPackage"  to "com.example.e2e",
      "size"        to "small",
      "count"       to "3",
      "timeout_msec" to "60000"
    ))
  }
}
```

**Combination rules:**
- `class` + `annotation` = intersection (test must match both)
- `class` + `notClass` = `class` wins (`notClass` ignored)
- `package` + `notPackage` = subtraction (package minus notPackage)
- Multiple values for `class`/`notClass` are comma-separated

**Accessing custom arguments at runtime:**

```kotlin
val args = InstrumentationRegistry.getArguments()
val customFlag = args.getString("myCustomArg", "default")
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

**Algorithm note:** Native `numShards` uses round-robin by test method hashCode. Non-deterministic ordering means shard times can be unbalanced (up to 3:1 ratio on heterogeneous suites). For balanced sharding, see the Flank section below.

### Flank Test Runner

Flank replaces native round-robin sharding with smart sharding based on historical test durations, and supports multi-device parallel execution.

```yaml
# flank.yml
gcloud:
  app: app-debug.apk
  test: app-debug-androidTest.apk
  device:
    - model: Pixel2
      version: 30
flank:
  max-test-shards: 8
  smart-flank-gcs-path: gs://bucket/smart-flank.xml
  # Uses JUnit XML timing from previous run
  use-average-test-time-for-new-tests: true
  default-test-time: 120.0    # fallback for unknown tests (seconds)
  shard-time: 120              # target seconds per shard (dynamic shard count)
```

**Impact:** Flank reads previous-run JUnit XML, groups tests into equal-time buckets. Reduces max-shard-time variance from ~3:1 (native) to ~1.2:1 (smart). If no history exists, falls back to the `default-test-time` estimate per test.

**Multi-device parallel execution script** (manual approach without Flank):

```bash
#!/bin/bash
DEVICES=($(adb devices | grep -w device | awk '{print $1}'))
NUM=${#DEVICES[@]}
for i in "${!DEVICES[@]}"; do
  adb -s "${DEVICES[$i]}" shell am instrument -w \
    -e numShards "$NUM" -e shardIndex "$i" \
    com.app.test/androidx.test.runner.AndroidJUnitRunner \
    > "results-${i}.txt" &
done
wait
```

**Result merging across shards:**

```bash
# pip install junitparser
junitparser merge results/shard-*.xml merged-results.xml
```

**Gotcha:** Duplicate test names across shards (from retries) cause CI parsers to double-count. Deduplicate by test class+method before merging.

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

**Measured impact:** ~2x total wall-clock time reported by multiple teams (GitHub issue #608). Per-test overhead is 2-5 seconds for process spawn + app cold start. A 200-test suite taking 8 min without orchestrator takes ~15 min with it.

#### Orchestrator Decision Matrix

| Scenario | Recommendation | Rationale |
|----------|----------------|-----------|
| Small suite (<50 tests), tests are independent | Skip orchestrator | Isolation overhead dominates; little benefit |
| Tests leak state (singletons, DB, SharedPreferences) | Orchestrator without clearPackageData | Isolates process state; avoids `pm clear` overhead |
| Full hermetic isolation, can tolerate 2x slowdown | Orchestrator + clearPackageData | Resets all app data between tests |
| Need isolation + code coverage | Orchestrator + external coverage path | `clearPackageData` wipes `.ec` files; redirect to `/sdcard/coverage/` |
| Large suite needing speed + isolation | Marathon or Flank + orchestrator | Dynamic device assignment reduces tail latency ~30% |
| CI with no physical devices | GMD + ATD images | Faster boot, lighter images; see test-coverage-gmd.md |

#### Orchestrator Gotchas

**clearPackageData destroys coverage files:** `clearPackageData=true` runs `pm clear` between tests, which wipes `.ec` coverage files before they can be pulled. Known issue (android/android-test#829). Workaround: redirect coverage to external storage that survives `pm clear`:

```bash
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.clearPackageData=true \
  -Pandroid.testInstrumentationRunnerArguments.coverageFilePath=/sdcard/coverage/
```

**Whitespace in test names caused hangs:** Test method names containing spaces (e.g., from parameterized tests with display names) caused the orchestrator to hang on versions prior to 1.5.0. Fixed in orchestrator 1.5.0+. Long test names also caused crashes in older versions.

**Permissions reset:** `clearPackageData` revokes runtime permissions between tests. Tests must re-grant via `GrantPermissionRule` or `adb shell pm grant`:

```kotlin
@get:Rule
val permissionRule = GrantPermissionRule.grant(
    android.Manifest.permission.CAMERA,
    android.Manifest.permission.ACCESS_FINE_LOCATION
)
```

**Compose startup overhead:** Orchestrator restarts the process between tests, so `createAndroidComposeRule()` pays full Activity launch cost per test. No shared composition state. No Compose-specific bugs reported with orchestrator, but the startup overhead compounds on large Compose test suites.

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

### Compose Flaky Test Patterns

Common Compose-specific flakiness root causes and fixes.

#### Recomposition Timing

**Root cause:** Test asserts before recomposition triggered by a state change completes. Compose auto-sync usually handles this, but external state sources (Flow, LiveData) may not be tracked by the Compose idling mechanism.

**Fix:**

```kotlin
// Let Compose finish all pending recompositions
composeTestRule.waitForIdle()

// For external async state (Flow, LiveData collectors):
composeTestRule.waitUntil(timeoutMillis = 3_000L) {
    composeTestRule.onAllNodesWithText("Result").fetchSemanticsNodes().isNotEmpty()
}
```

#### LazyColumn Scroll Races

**Root cause:** `scrollToIndex` or `performScrollToNode` triggers recomposition of new items. The assertion fires before the scrolled-to items are laid out. Missing `key {}` in `LazyColumn` causes unnecessary recompositions during scroll because Compose treats items as deleted and recreated rather than moved.

**Fix (test code) -- wait after scroll:**

```kotlin
composeTestRule.onNodeWithTag("list")
    .performScrollToNode(hasText("Item 50"))
composeTestRule.waitForIdle()  // critical: wait after scroll
composeTestRule.onNodeWithText("Item 50").assertIsDisplayed()
```

**Fix (production code) -- stable keys eliminate spurious recompositions:**

```kotlin
LazyColumn {
    items(data, key = { it.id }) { item ->
        ItemRow(item)
    }
}
```

Without stable keys, scrolling large lists in tests is inherently flaky because Compose cannot track item identity across recompositions.

#### Infinite Animation Idling Timeout

**Root cause:** `rememberInfiniteTransition`, Lottie animations, or shimmer effects keep Compose perpetually "busy." The `ComposeIdlingResource` never reports idle, causing `IdlingResourceTimeoutException`.

**Fix -- gate animation in test builds:**

```kotlin
// In production code, use a flag to disable infinite animations during tests
val showAnimation = !isInstrumentedTest()
if (showAnimation) { LottieAnimation(...) }
```

**Fix -- control clock manually:**

```kotlin
composeTestRule.mainClock.autoAdvance = false
// perform actions while infinite animation is frozen
composeTestRule.mainClock.advanceTimeBy(1000L)
// assert state
composeTestRule.mainClock.autoAdvance = true
```

The `mainClock` approach is preferred when you need to test animation mid-states. The build-flag approach is preferred when the animation is purely decorative and irrelevant to the test.

### Performance Notes

- x86/x86_64 emulators are significantly faster for Compose tests than ARM devices
- Use GMD (see `test-coverage-gmd.md`) or `android-emulator-runner` with x86_64 images in CI

## Unit Test Filtering (--tests)

The `--tests` flag works only for local JVM unit tests (`test{Variant}UnitTest`). For instrumented test filtering, use `-P` properties (see Gradle Test Filtering above).

```bash
# Exact class
./gradlew testDebugUnitTest --tests "com.example.MyTest"

# Wildcard method
./gradlew testDebugUnitTest --tests "*MyTest.should*"

# Package wildcard (text-based, not package-aware)
./gradlew testDebugUnitTest --tests "com.example.feature.*"

# Multiple filters (AND logic within task, repeat flag)
./gradlew testDebugUnitTest --tests "*Fast*" --tests "*Unit*"
```

DSL equivalent for permanent include/exclude patterns:

```kotlin
tasks.withType<Test> {
    filter {
        includeTestsMatching("*IntegrationTest")
        excludeTestsMatching("*Slow*")
    }
}
```

**Gotcha:** `--tests` is a JVM Test task flag. Passing it to `connectedDebugAndroidTest` has no effect. Use `-Pandroid.testInstrumentationRunnerArguments.*` for instrumented filtering.

## AGP Test Task Naming Conventions

| Scenario | Task Pattern | Example |
|---|---|---|
| Local unit tests (all) | `test` | `./gradlew test` |
| Local unit tests (variant) | `test{Variant}UnitTest` | `./gradlew testDebugUnitTest` |
| Instrumented (connected) | `connected{Variant}AndroidTest` | `./gradlew connectedDebugAndroidTest` |
| Instrumented (managed device) | `{deviceName}{Variant}AndroidTest` | `./gradlew pixel2api30DebugAndroidTest` |
| Instrumented (device group) | `{groupName}Group{Variant}AndroidTest` | `./gradlew ciDevicesGroupDebugAndroidTest` |
| Managed device setup | `{deviceName}Setup` | `./gradlew pixel2api30Setup` |

**Gotcha:** Task abbreviation works (`./gradlew cDAT` for `connectedDebugAndroidTest`), but ambiguous abbreviations fail silently with wrong task selection.

## Test Logging Configuration

Control test output verbosity via the `testLogging` DSL block. No CLI flags exist for individual settings; use `--info` or `--debug` to activate the corresponding log-level overrides.

```kotlin
tasks.withType<Test> {
    testLogging {
        events("passed", "skipped", "failed", "standardOut", "standardError")
        exceptionFormat = TestExceptionFormat.FULL
        showStandardStreams = true
        showCauses = true
        showStackTraces = true
        // Per-log-level overrides:
        debug {
            events("started", "skipped", "failed")
            exceptionFormat = TestExceptionFormat.FULL
        }
        info {
            events("failed", "skipped")
        }
    }
}
```

- `showStandardStreams = true` surfaces `println` output from tests
- `exceptionFormat = FULL` prints complete stack traces on failure (default is `SHORT`)
- For readable CI logs with parallel execution (where interleaved output is noisy), use the `gradle-test-logger-plugin`:

```kotlin
plugins { id("com.adarshr.test-logger") version "4.0.0" }
```

## Gradle Profiling for Tests

```bash
# HTML profile report (local, no upload)
./gradlew testDebugUnitTest --profile
# Output: build/reports/profile/

# Develocity build scan (detailed timeline, test-by-test breakdown)
./gradlew testDebugUnitTest --scan
# Uploads to scans.gradle.com; shows parallel utilization, per-test duration, cache hit rate
```

- `--scan` timeline view reveals: tests that block parallel slots, cache miss patterns, and slow individual tests
- `--profile` is local-only, less detailed but requires no upload
- **Privacy note:** `--scan` uploads build data to Gradle's servers (or your Develocity instance). Review data-sharing policies before enabling in production CI

## Test Caching Behavior

Unit tests are cacheable by default since AGP 3.6. Instrumented tests are NOT cacheable (non-deterministic device state).

```bash
# Force re-run (bypass cache)
./gradlew testDebugUnitTest --rerun

# Diagnostics — shows UP-TO-DATE / FROM-CACHE labels per task
./gradlew testDebugUnitTest --info
```

- **UP-TO-DATE:** Local incremental build; inputs unchanged since last local run
- **FROM-CACHE:** Restored from build cache (local or remote); inputs hash matched a prior execution

CI with remote build cache can skip test execution entirely when code and dependencies are unchanged.

**Gotcha:** Tests with non-deterministic inputs (timestamps, random data, system properties) poison the cache. Declare all variable inputs explicitly, or disable caching for specific tasks:

```kotlin
tasks.withType<Test> { outputs.cacheWhen { false } }
```

## Retry Strategies

Gradle's `test-retry-gradle-plugin` does **not** work for `connectedAndroidTest` (it only retries JVM `Test` tasks). For instrumented test retries, use JUnit rules or Marathon.

### JUnit RetryRule (Per-Test Granularity)

Implement a custom `TestRule` that catches failures and re-runs the test body:

```kotlin
class RetryRule(private val maxRetries: Int = 3) : TestRule {
    override fun apply(base: Statement, desc: Description) = object : Statement() {
        override fun evaluate() {
            var lastError: Throwable? = null
            repeat(maxRetries) { attempt ->
                try {
                    base.evaluate()
                    return  // passed, stop retrying
                } catch (e: Throwable) {
                    lastError = e
                    Log.w("RetryRule", "Attempt ${attempt + 1}/$maxRetries failed: ${e.message}")
                }
            }
            throw lastError!!
        }
    }
}
```

Usage:

```kotlin
@get:Rule
val retryRule = RetryRule(maxRetries = 3)

@Test
fun flakyNetworkTest() { ... }
```

Alternatively, use the `cortinico/rules4android` library for annotation-driven retries:

```kotlin
@get:Rule val retry = RetryRule()

@RetryOnFailure(times = 2)
@Test fun flakyNetworkTest() { ... }
```

**Trade-off:** In-process retry is simple but masks root causes. Use alongside `@FlakyTest` quarantine (see above) so retried tests are tracked and fixed, not silently passed.

### Marathon Test Runner (Retry at Scale)

Marathon replaces `connectedAndroidTest` entirely, providing per-test retry quotas, flakiness-aware scheduling, and push-to-free-device assignment.

```kotlin
// build.gradle.kts
plugins {
    id("com.malinskiy.marathon") version "0.9.1"
}

marathon {
    retryStrategy {
        fixedQuota {
            totalAllowedRetryQuota = 200
            retryPerTestQuota = 3
        }
    }
    flakinessStrategy {
        probabilityBased {
            minSuccessRate = 0.8
            maxCount = 3
            timeLimit = Instant.now().minus(30, ChronoUnit.DAYS)
        }
    }
    filteringConfiguration {
        allowlist {
            add(TestFilterConfiguration.AnnotationFilterConfiguration("com.example.StableTest"))
        }
    }
}
```

**Key advantage over Orchestrator + native sharding:** Marathon implements push-to-free-device (dynamic assignment) rather than static round-robin sharding. Devices that finish early pick up remaining tests automatically, reducing tail latency by ~30%.
