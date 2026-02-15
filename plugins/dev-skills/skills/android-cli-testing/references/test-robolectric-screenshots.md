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
- Move complex `LaunchedEffect`/`DisposableEffect` async flows to instrumented tests (see `test-espresso-compose.md`)

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
