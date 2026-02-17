# Robolectric and Screenshot Testing Reference

CLI-only execution of JVM-based testing: Robolectric for fast unit tests without a device, Molecule for Compose state testing, and screenshot/visual regression tools (Paparazzi, Roborazzi, Shot).

> For instrumented testing (Espresso/Compose), see test-espresso-compose.md.

## Robolectric (JVM Tests)

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

### Compose + Robolectric Compatibility (2024-2025)

**What works (full support):**
- Compose semantics tree assertions
- Click, scroll, text input actions
- State management / ViewModel tests
- Navigation tests with `TestNavHostController`
- Screenshot capture via Roborazzi (with visual caveats)
- `createComposeRule()` and `createAndroidComposeRule<ComponentActivity>()`
- `StateRestorationTester` for `rememberSaveable` verification
- `runComposeUiTest { }` (JUnit-free entry point, stable in Compose 1.7+)

**What does NOT work or has issues:**
- `captureToImage()` times out with native graphics (Robolectric issue #8071)
- Elevation shadows not rendered in screenshots (#8081)
- Density changes via `ShadowDisplay` not reflected in Compose (#8476)
- Pixel-perfect rendering differs from devices (font hinting, anti-aliasing)
- Hardware-accelerated Canvas operations may behave differently
- CameraX, Google Maps, and hardware-dependent APIs do not work
- `SwipeUp` bug in Compose 1.7 on Robolectric

**Shadow limitations:**
- `ShadowDisplay` density changes are ignored by Compose layout
- No shadow support for elevation-based Material Design visuals in screenshots
- Font anti-aliasing uses JVM rendering, not device rendering -- screenshots will never be pixel-identical to device output

**Configuration gotchas:**
- Must use `testImplementation` (not `androidTestImplementation`) for Compose testing artifact
- Requires `isIncludeAndroidResources = true` in testOptions:
  ```kotlin
  android {
    testOptions {
      unitTests.isIncludeAndroidResources = true
    }
  }
  ```
- Add `@Config(sdk = [34])` to pin SDK level. Robolectric 4.11+ supports SDK 34
- Enable native graphics with `@GraphicsMode(GraphicsMode.Mode.NATIVE)` for screenshot tests
- AndroidX Room: use Robolectric's in-memory database for testing
- Large Compose suites may leak resources and slow down over time
- Move complex `LaunchedEffect`/`DisposableEffect` async flows to instrumented tests (see `test-espresso-compose.md`)

### State Restoration Testing (JVM)

Verify `rememberSaveable` survives activity recreation without a device:

```kotlin
@get:Rule val composeTestRule = createComposeRule()

@Test
fun stateRestoredAfterRecreation() {
    val restorationTester = StateRestorationTester(composeTestRule)

    restorationTester.setContent { CounterScreen() }

    // Modify state
    composeTestRule.onNodeWithText("Increment").performClick()
    composeTestRule.onNodeWithText("Count: 1").assertExists()

    // Simulate process death / config change
    restorationTester.emulateSavedInstanceStateRestore()

    // Verify state survived
    composeTestRule.onNodeWithText("Count: 1").assertExists()
}
```

CLI:

```bash
./gradlew :app:testDebugUnitTest --tests "*.StateRestorationTest"
```

**Gotcha:** `StateRestorationTester` only tests `rememberSaveable`. It does NOT test ViewModel `SavedStateHandle` persistence. For ViewModel state, use `ViewModelScenario` (added in lifecycle 2.9+). Use `setContent` on the `restorationTester`, not on `composeTestRule` directly.

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

## Screenshot and Visual Regression Testing

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

#### Compose Test Rule Integration

Roborazzi integrates directly with Compose test rules on Robolectric:

```kotlin
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ScreenshotTest {
    @get:Rule val composeTestRule = createComposeRule()

    @Test
    fun profileScreen_snapshot() {
        composeTestRule.setContent { ProfileScreen() }
        composeTestRule.onRoot().captureRoboImage(
            filePath = "src/test/snapshots/ProfileScreen.png"
        )
    }
}
```

**Gotcha:** Always annotate screenshot test classes with `@GraphicsMode(GraphicsMode.Mode.NATIVE)` for proper rendering. Shadows (elevation) do NOT render in screenshots. Font anti-aliasing differs from real devices. For animated previews, use `@RoboComposePreviewOptions` with `ManualClockOptions` to capture at specific timestamps.

#### Preview-Based Screenshot Generation

Zero-test-code approach -- auto-generates screenshot tests from `@Preview` functions:

```kotlin
// build.gradle.kts
roborazzi {
    @OptIn(ExperimentalRoborazziApi::class)
    generateComposePreviewRobolectricTests {
        enable = true
        packages = listOf("com.example.ui")
    }
}
```

CLI:

```bash
# Record preview-based screenshots (JVM-only)
./gradlew recordRoborazziJvm
```

This scans specified packages for `@Preview` composables and generates screenshot tests automatically. Useful for large design systems where writing individual test files is impractical.

#### CLI Commands

```bash
# Record new screenshots
./gradlew recordRoborazziDebug

# Compare against goldens (fails on diff)
./gradlew verifyRoborazziDebug

# Produce visual diffs WITHOUT failing the build
./gradlew compareRoborazziDebug

# Clear all stored screenshots
./gradlew clearRoborazziDebug
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

Output paths: `build/outputs/roborazzi/` (recorded images), `build/outputs/roborazzi/diffs` (diff images from compare/verify). HTML report at `build/reports/roborazzi/index.html`.

### Google Compose Preview Screenshot Testing

Separate from Roborazzi. Generates screenshots only from `@Preview` functions -- no interaction support.

```bash
# Record
./gradlew :app:updateDebugScreenshotTest

# Verify
./gradlew :app:validateDebugScreenshotTest
```

**Gotcha:** Google's tool is preview-only with no click/scroll simulation. Roborazzi supports interaction-based multi-frame capture. Choose based on whether you need interaction in screenshots.

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
| Google Preview Screenshots | No (JVM) | Fast | Preview-only | @Preview validation, no interaction |
| Shot | Yes | Slow | Basic | Legacy view-based screenshots |

## Multi-Module Compose Test Fixtures

Share test utilities across modules via Gradle test fixtures:

```kotlin
// :core:ui module build.gradle.kts
plugins {
    id("com.android.library")
}

android {
    // Enable test fixtures (AGP 8.5.1+)
    testFixtures { enable = true }
}

// :core:ui/src/testFixtures/kotlin/ComposeTestHelpers.kt
fun ComposeTestRule.assertScreenDisplayed(tag: String) {
    onNodeWithTag(tag).assertIsDisplayed()
}

fun ComposeTestRule.waitAndAssert(text: String, timeoutMillis: Long = 5_000) {
    waitUntilAtLeastOneExists(hasText(text), timeoutMillis)
    onNodeWithText(text).assertIsDisplayed()
}

// :feature:profile module build.gradle.kts
dependencies {
    testImplementation(testFixtures(project(":core:ui")))
}
```

### Preview Parameter Providers for Tests

Reuse `@Preview` parameter providers to generate test data across modules:

```kotlin
// :core:ui/src/testFixtures/kotlin/PreviewProviders.kt
class ThemePreviewProvider : PreviewParameterProvider<Boolean> {
    override val values = sequenceOf(true, false)
}

class LocalePreviewProvider : PreviewParameterProvider<Locale> {
    override val values = sequenceOf(Locale.US, Locale.JAPAN, Locale.GERMANY)
}

// Usage in screenshot tests (any module)
@RunWith(ParameterizedRobolectricTestRunner::class)
class ThemedScreenshotTest(private val darkMode: Boolean) {
    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters
        fun params() = listOf(true, false)
    }

    @get:Rule val composeTestRule = createComposeRule()

    @Test
    fun screen_inTheme() {
        composeTestRule.setContent {
            AppTheme(darkTheme = darkMode) { ProfileScreen() }
        }
        composeTestRule.onRoot().captureRoboImage(
            filePath = "src/test/snapshots/Profile_dark$darkMode.png"
        )
    }
}
```

CLI:

```bash
./gradlew :feature:profile:testDebugUnitTest
```

**Gotcha:** AGP test fixtures support landed in 8.5.1. Version 8.9+ auto-includes kotlin-stdlib. Implementation dependencies of fixtures do NOT leak into consuming module's test compile classpath (good for isolation). Place only shared builders, matchers, and assertion extensions in `testFixtures` -- keep test-specific logic in each module's `src/test`.

## Experimental and Recent APIs (Compose 1.7-1.8, 2025)

| API | Status | What It Does |
|-----|--------|-------------|
| `runComposeUiTest { }` | Stable 1.7+ | JUnit-free test entry point, suspend-compatible |
| `MultiModalInjectionScope` | Stable 1.8 | `performKeyInput`, `performRotaryScrollInput` |
| `waitUntilAtLeastOneExists` | Stable 1.4+ | Replaces manual `waitUntil` polling |
| `ComposePreviewScreenshot` | Experimental | Google's preview-based screenshot plugin |
| `ViewModelScenario` | lifecycle 2.9+ | Process death simulation for ViewModels |

**Experimental API reduction:** Compose 1.8 reduced experimental APIs from 172 to 70 (59% decrease). Most testing APIs are now stable.

### runComposeUiTest (JUnit-Free)

Multiplatform-compatible entry point that runs without JUnit rules:

```kotlin
@OptIn(ExperimentalTestApi::class)
@Test fun myTest() = runComposeUiTest {
    setContent { MyComposable() }
    onNodeWithText("Hello").assertExists()
}
```

Runs as a standard JVM test on Robolectric. Accepts suspend blocks since Compose 1.7+.

### ViewModelScenario (Process Death for ViewModels)

Tests ViewModel `SavedStateHandle` persistence (complements `StateRestorationTester` which only covers `rememberSaveable`):

```kotlin
// Requires lifecycle 2.9+
@Test
fun viewModel_survivesProcessDeath() {
    val scenario = ViewModelScenario(MyViewModel::class)
    scenario.onViewModel { vm ->
        vm.updateState("test value")
    }
    scenario.recreate()
    scenario.onViewModel { vm ->
        assertEquals("test value", vm.state.value)
    }
}
```

CLI: `./gradlew :app:testDebugUnitTest --tests "*.ViewModelScenarioTest"`
