# Accessibility Testing Reference

CLI-only techniques for automated accessibility checks, semantics verification, TalkBack testing, touch target validation, contrast checking, and CI integration -- all without Android Studio.

> For UI hierarchy inspection and `dumpsys accessibility`, see `debug-ui-memory.md`. For Compose semantics matchers and test rules, see `test-espresso-compose.md`. For lint configuration in CI pipelines, see `ci-pipeline-config.md`.

## Espresso Accessibility Checks (ATF)

The Accessibility Test Framework runs 14 checks automatically on every Espresso `ViewAction`.

### Dependencies

```kotlin
// build.gradle
androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
androidTestImplementation("androidx.test.espresso:espresso-accessibility:3.6.1")
```

### Enable in Test Class

```kotlin
import androidx.test.espresso.accessibility.AccessibilityChecks

@RunWith(AndroidJUnit4::class)
class A11yTest {
    init {
        AccessibilityChecks.enable()
            .setRunChecksFromRootView(true)
            .setThrowExceptionFor(AccessibilityCheckResultType.ERROR)
    }
}
```

### Suppress Known Issues

```kotlin
AccessibilityChecks.enable().apply {
    setSuppressingResultMatcher(
        allOf(
            matchesCheck(TextContrastCheck::class.java),
            matchesViews(withId(R.id.legacy_banner))
        )
    )
}
```

### Project-Wide via Custom Test Runner

```kotlin
class A11yTestRunner : AndroidJUnitRunner() {
    init {
        AccessibilityChecks.enable()
            .setRunChecksFromRootView(true)
            .setThrowExceptionFor(AccessibilityCheckResultType.ERROR)
    }
}
```

Configure in `build.gradle`: `testInstrumentationRunner = "com.example.A11yTestRunner"`

### CLI Execution

```bash
# All instrumented tests with a11y checks active
./gradlew connectedDebugAndroidTest

# Target specific a11y test class
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.A11yTest
```

## Compose Accessibility Testing

### ATF Integration (Compose 1.8.0+)

```kotlin
androidTestImplementation("androidx.compose.ui:ui-test-junit4-accessibility:$composeVersion")
```

```kotlin
@get:Rule
val composeTestRule = createAndroidComposeRule<ComponentActivity>()

@Test
fun screenPassesAccessibilityChecks() {
    composeTestRule.setContent { MyScreen() }
    composeTestRule.enableAccessibilityChecks()
    composeTestRule.onRoot().tryPerformAccessibilityChecks()
}

@Test
fun warningLevelChecks() {
    composeTestRule.setContent { MyScreen() }
    val validator = AccessibilityValidator()
        .setThrowExceptionFor(AccessibilityCheckResult.AccessibilityCheckResultType.WARNING)
    composeTestRule.enableAccessibilityChecks(validator)
    composeTestRule.onRoot().tryPerformAccessibilityChecks()
}
```

### Semantics-Based Assertions

```kotlin
// Verify content description exists
composeTestRule.onNodeWithContentDescription("Profile picture").assertIsDisplayed()

// Verify role semantics
composeTestRule.onNode(
    SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button)
).assertExists()

// Verify heading semantics
composeTestRule.onNode(hasContentDescription("Section title"))
    .assert(SemanticsMatcher("is heading") {
        it.config.getOrNull(SemanticsProperties.Heading) != null
    })

// Verify click label for screen readers
composeTestRule.onNode(hasTestTag("action_card"))
    .assert(SemanticsMatcher("has click label") {
        it.config.getOrNull(SemanticsActions.OnClick)?.label == "Open details"
    })

// Detect clickable nodes missing content descriptions
composeTestRule.onAllNodes(hasClickAction())
    .fetchSemanticsNodes()
    .forEach { node ->
        val desc = node.config.getOrNull(SemanticsProperties.ContentDescription)
        assert(!desc.isNullOrEmpty()) { "Clickable node missing contentDescription: $node" }
    }
```

## UIAutomator Accessibility Dump

### Dump and Inspect Hierarchy

```bash
adb shell uiautomator dump /sdcard/window_dump.xml
adb pull /sdcard/window_dump.xml ./ui_dump.xml
```

### Find Missing Content Descriptions

```bash
# Clickable nodes without content-desc (NAF = Not Accessibility Friendly)
grep -E 'clickable="true"' ui_dump.xml | grep 'content-desc=""'

# All clickable elements with their descriptions
grep -oP 'content-desc="[^"]*".*?clickable="[^"]*"' ui_dump.xml
```

### Richer Accessibility Tree

```bash
# dumpsys accessibility provides semantics beyond uiautomator
adb shell dumpsys accessibility
```

Key sections: `ActiveWindowInfo`, `FocusedWindowInfo`, `AccessibilityServiceConnections`. Grep for specifics: `dumpsys accessibility | grep "contentDescription"`. Unlike `uiautomator dump`, the accessibility dump includes service metadata, focus chain, and event dispatch state.

### Accessibility Scanner CLI Alternatives

Google Accessibility Scanner is a GUI-only Android app with no CLI API. For programmatic accessibility scanning without Espresso, use these alternatives:

- **ATF in Espresso** (recommended): `AccessibilityChecks.enable()` runs the same checks as the Scanner app (see Espresso section above)
- **dumpsys accessibility**: `adb shell dumpsys accessibility` for service state and focus chain inspection
- **UIAutomator dump + parsing**: `adb shell uiautomator dump` produces XML in traversal order, parseable with custom scripts for missing descriptions, undersized targets, etc.

## TalkBack Testing from CLI

### Enable and Disable

```bash
# Enable TalkBack
adb shell settings put secure enabled_accessibility_services \
  com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService
adb shell settings put secure accessibility_enabled 1

# Disable TalkBack
adb shell settings put secure enabled_accessibility_services ""
adb shell settings put secure accessibility_enabled 0
```

### Simulate Accessibility Display Conditions

```bash
# Large font scale (test dynamic type)
adb shell settings put system font_scale 2.0
adb shell settings put system font_scale 1.0    # reset

# Color blindness simulation
adb shell settings put secure accessibility_display_daltonizer_enabled 1
adb shell settings put secure accessibility_display_daltonizer 11   # deuteranomaly
adb shell settings put secure accessibility_display_daltonizer 12   # protanomaly
adb shell settings put secure accessibility_display_daltonizer 13   # tritanomaly

# High contrast text
adb shell settings put secure high_text_contrast_enabled 1

# Color inversion
adb shell settings put secure accessibility_display_inversion_enabled 1

# Reset all display conditions
adb shell settings put secure accessibility_display_daltonizer_enabled 0
adb shell settings put secure high_text_contrast_enabled 0
adb shell settings put secure accessibility_display_inversion_enabled 0
```

### Screenshot Under Conditions

```bash
adb shell settings put system font_scale 2.0
adb shell screencap /sdcard/a11y_fontscale.png
adb pull /sdcard/a11y_fontscale.png
adb shell settings put system font_scale 1.0
```

## Focus Order and Traversal Verification

Elements in `uiautomator dump` XML appear in document order, which matches the default accessibility traversal (focus) order.

```bash
# Extract interactive elements in traversal order
adb shell uiautomator dump /sdcard/traversal.xml && adb pull /sdcard/traversal.xml
grep -E 'clickable="true"|focusable="true"' traversal.xml | grep -oP 'content-desc="[^"]*"|text="[^"]*"'
```

For Compose, use `isTraversalGroup` and `traversalIndex` semantics modifiers. Verify via `composeTestRule.onRoot().printToLog("TRAVERSAL")` which prints the full semantics tree to logcat. CI check: parse the dump XML and verify every `clickable="true"` element has a non-empty `content-desc` or `text`.

## Touch Target Size Validation

### Extract Bounds and Check 48dp Minimum

```bash
# Get device density for dp conversion
adb shell wm density
# Returns e.g. "Physical density: 480" -> divide by 160 for factor (3x)
```

```bash
# Parse UI dump and flag undersized touch targets
python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('ui_dump.xml')
density = 480  # from 'adb shell wm density'
min_px = int(48 * (density / 160))
for node in tree.iter('node'):
    if node.get('clickable') == 'true':
        bounds = node.get('bounds')
        coords = bounds.replace('][', ',').strip('[]').split(',')
        w = int(coords[2]) - int(coords[0])
        h = int(coords[3]) - int(coords[1])
        if w < min_px or h < min_px:
            desc = node.get('content-desc') or node.get('text') or 'unnamed'
            print(f'UNDERSIZED: {desc} ({w}x{h}px, need {min_px}px)')
"
```

ATF's `TouchTargetSizeCheck` catches the same issue automatically when `AccessibilityChecks.enable()` is active (see Espresso section above).

## Color Contrast Checking

### WCAG Thresholds

| Content Type | AA Ratio | AAA Ratio |
|---|---|---|
| Normal text (<18sp) | 4.5:1 | 7:1 |
| Large text (>=18sp or >=14sp bold) | 3:1 | 4.5:1 |
| UI components / graphics | 3:1 | N/A |

ATF's `TextContrastCheck` and `ImageContrastCheck` run automatically with `AccessibilityChecks.enable()` -- no separate setup needed.

### Runtime Color Contrast Extraction

No built-in CLI tool for runtime contrast. Workflow: `adb exec-out screencap -p > screen.png`, then extract pixel colors with ImageMagick (`convert screen.png -crop 1x1+X+Y txt:-`) and apply WCAG formula: `(L1 + 0.05) / (L2 + 0.05)` where L1/L2 are relative luminance (4.5:1 minimum for normal text). Prefer ATF's `TextContrastCheck` + `ImageContrastCheck` in Espresso tests over manual pixel extraction.

### Find Hardcoded Colors in Layouts

```bash
# Flag hardcoded hex colors (should use theme attributes for dark mode compat)
grep -rn '#[0-9A-Fa-f]\{6,8\}' app/src/main/res/layout/ | grep -i 'color\|background\|textColor'
```

## Accessibility Lint Checks

### Run from CLI

```bash
./gradlew lintDebug
# or check specific rules only
./gradlew lint -Dlint.check=ContentDescription,LabelFor,ClickableViewAccessibility
```

### Accessibility Lint Rules

| Rule ID | What It Catches |
|---|---|
| `ContentDescription` | ImageView/ImageButton missing `android:contentDescription` |
| `LabelFor` | EditText without `android:hint` or associated `android:labelFor` |
| `ClickableViewAccessibility` | View overrides `onTouchEvent` without `performClick` |
| `KeyboardInaccessibleWidget` | Clickable widget not focusable |
| `GetContentDescOverride` | Overriding `getContentDescription()` (breaks a11y services) |

### Promote to Errors

```kotlin
android {
    lint {
        error += listOf(
            "ContentDescription", "LabelFor",
            "ClickableViewAccessibility", "KeyboardInaccessibleWidget",
            "GetContentDescOverride"
        )
        abortOnError = true
        htmlReport = true
        htmlOutput = file("${project.buildDir}/reports/lint-accessibility.html")
    }
}
```

## CI Integration

### Pipeline Stages

```yaml
accessibility-checks:
  steps:
    # Stage 1: Static analysis (no device needed)
    - run: ./gradlew lintDebug

    # Stage 2: Instrumented a11y tests (needs emulator/device)
    - run: ./gradlew connectedDebugAndroidTest

    # Stage 3: UI hierarchy validation (needs running app)
    - run: |
        adb shell uiautomator dump /sdcard/a11y_dump.xml
        adb pull /sdcard/a11y_dump.xml
        python3 scripts/validate_a11y_tree.py a11y_dump.xml
```

### Machine-Parseable Lint Output

```kotlin
android {
    lint {
        error += listOf("ContentDescription", "LabelFor", "KeyboardInaccessibleWidget")
        abortOnError = true
        xmlReport = true
        xmlOutput = file("${project.buildDir}/reports/lint-results.xml")
    }
}
```

### Common CI Failures

| Failure | Root Cause | Fix |
|---|---|---|
| `SpeakableTextPresentCheck` | Decorative icon marked clickable | Add `contentDescription` or set `importantForAccessibility="no"` |
| `TouchTargetSizeCheck` | Icon button without padding | Set `minWidth`/`minHeight` to 48dp |
| `TextContrastCheck` | Light gray text on white | Use theme colors meeting 4.5:1 ratio |
| `ContentDescription` lint | New ImageView added | Add `android:contentDescription` or `@null` for decorative |
| `LabelFor` lint | EditText without label | Add `android:hint` or link via `android:labelFor` |
| `TraversalOrderCheck` | Custom layout wrong tab order | Set `accessibilityTraversalBefore/After` |
| Font scale overflow | Text truncated at 200% | Use `sp` units, allow multi-line, avoid fixed heights |

## Anti-Patterns

| DON'T | DO |
|-------|-----|
| Set `contentDescription` on EditText | Use `android:hint` or `android:labelFor` on an associated label |
| Add redundant type info in descriptions (e.g., "Button for submit") | Describe the action: "Submit order" |
| Skip `setRunChecksFromRootView(true)` | Always check the entire hierarchy, not just the acted-on view |
| Use `importantForAccessibility="no"` on actionable views | Only suppress decorative/redundant elements |
| Test accessibility only on default font scale | Run with `font_scale 2.0` to catch overflow and truncation |
| Hardcode hex colors in layout XML | Use theme attributes for automatic dark mode and contrast compliance |
| Rely solely on lint for a11y coverage | Combine lint (static) + ATF (runtime) + UIAutomator dump (hierarchy) |
| Suppress ATF failures project-wide | Suppress per-check, per-view with `setSuppressingResultMatcher` |
