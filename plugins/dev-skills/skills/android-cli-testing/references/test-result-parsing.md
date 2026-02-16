# Test Result Parsing Reference

JUnit XML parsing, failure triage, flaky test detection, iterative debugging loops, multi-module result aggregation, and CI integration for autonomous test result interpretation.

> For test execution and filtering, see `test-espresso-compose.md`. For CI pipeline strategy and flaky quarantine, see `ci-pipeline-config.md`. For crash diagnosis from test failures, see `debug-crashes-monkey.md`.

## JUnit XML Structure

Android test tasks (`connectedDebugAndroidTest`, GMD tasks) produce JUnit XML reports in `build/outputs/androidTest-results/` (instrumented) and `build/test-results/` (unit tests).

### Schema Overview

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="com.example.app.LoginTest"
           tests="12" failures="2" errors="1" skipped="1"
           time="45.231" timestamp="2024-01-15T10:30:00">
  <properties>
    <property name="device" value="Pixel_6_API_34(AVD)"/>
  </properties>
  <testcase name="loginSuccess" classname="com.example.app.LoginTest" time="3.456"/>
  <testcase name="loginFailure" classname="com.example.app.LoginTest" time="2.100">
    <failure message="expected true but was false" type="java.lang.AssertionError">
      java.lang.AssertionError: expected true but was false
        at com.example.app.LoginTest.loginFailure(LoginTest.kt:42)
    </failure>
  </testcase>
  <testcase name="loginCrash" classname="com.example.app.LoginTest" time="0.050">
    <error message="NullPointerException" type="java.lang.NullPointerException">
      java.lang.NullPointerException: ...
        at com.example.app.AuthManager.validate(AuthManager.kt:15)
    </error>
  </testcase>
  <testcase name="loginBiometric" classname="com.example.app.LoginTest" time="0.000">
    <skipped message="Requires biometric hardware"/>
  </testcase>
</testsuite>
```

### Key Elements

| Element | Meaning | Agent Action |
|---------|---------|--------------|
| `<failure>` | Assertion failed — test logic wrong or regression | Read stack trace, locate assertion line |
| `<error>` | Runtime exception — app code crashed | Read exception chain, find root cause class |
| `<skipped>` | Test not run (assumption failed, filter, device mismatch) | Check skip reason, verify test config |
| `tests` attr | Total test count | Verify expected count (detect missing tests) |
| `time` attr | Execution duration (seconds) | Detect timeouts (compare against expected) |

## CLI Parsing Recipes

### Extract Failures and Errors

```bash
# Find all JUnit XML files
find . -path "*/androidTest-results/**/*.xml" -o -path "*/test-results/**/*.xml" | sort

# Count pass/fail/skip across all suites (requires bash 4+ with globstar, or use find piping)
grep -h '<testsuite' build/outputs/androidTest-results/**/*.xml | \
  awk -F'"' '{for(i=1;i<=NF;i++){if($i~/tests=/){t+=$(i+1)}if($i~/failures=/){f+=$(i+1)}if($i~/errors=/){e+=$(i+1)}if($i~/skipped=/){s+=$(i+1)}}}END{printf "Total: %d  Pass: %d  Fail: %d  Error: %d  Skip: %d\n",t,t-f-e-s,f,e,s}'

# List failed test names with class
grep -B1 '<failure\|<error' build/outputs/androidTest-results/**/*.xml | \
  grep 'testcase' | sed 's/.*classname="\([^"]*\)".*name="\([^"]*\)".*/\1#\2/'
```

### Extract Stack Traces

```bash
# Extract full failure messages (multiline) with xmllint
xmllint --xpath '//failure' build/outputs/androidTest-results/connected/*.xml 2>/dev/null

# Fallback without xmllint — extract between failure tags
sed -n '/<failure/,/<\/failure>/p' build/outputs/androidTest-results/connected/*.xml

# Extract error messages only (first line of each)
grep -A1 '<failure\|<error' build/outputs/androidTest-results/**/*.xml | \
  grep -v '^--$' | grep -v '<failure\|<error'
```

### Quick Pass/Fail Summary

```bash
# One-liner: did all tests pass?
FAILS=$(grep -rl '<failure\|<error' build/outputs/androidTest-results/ 2>/dev/null | wc -l)
[ "$FAILS" -eq 0 ] && echo "ALL PASSED" || echo "$FAILS file(s) with failures"
```

## Failure Triage Flowchart

Decision tree for autonomous failure diagnosis. At each branch, the agent runs the diagnostic command and follows the appropriate path.

```
Test failed
├── <error> tag present?
│   ├── YES → Runtime crash
│   │   ├── NullPointerException → Read stack trace, find null dereference line
│   │   ├── IllegalStateException → Check lifecycle state, Fragment/Activity order
│   │   ├── SecurityException → Check permissions (adb shell dumpsys package <pkg> | grep permission)
│   │   ├── OutOfMemoryError → Check heap (adb shell dumpsys meminfo <pkg>), see debug-ui-memory.md
│   │   └── Native crash (SIGSEGV/SIGABRT) → See debug-crashes-monkey.md
│   └── NO → <failure> tag present?
│       ├── YES → Assertion failure
│       │   ├── assertEquals/assertTrue → Read expected vs actual, locate test line
│       │   ├── Compose assertion (assertIsDisplayed, assertTextEquals) → Check semantics tree
│       │   │   └── Run: adb shell am instrument -e class <TestClass>#<method> -e debug false ...
│       │   └── Espresso assertion (matches, check) → Check view hierarchy
│       │       └── Run: adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml
│       └── NO → <skipped> tag or timeout
│           ├── time="0.000" + <skipped> → Assumption failure or filter
│           │   └── Check @RequiresDevice, @SdkSuppress, Assume.assumeTrue()
│           └── time > expected threshold → Timeout
│               └── Check: adb shell dumpsys activity activities (stuck activity?)
│               └── Check logcat for ANR: adb logcat -d -b crash -b main | grep -E "ANR|FATAL"
```

## Flaky Test Detection

### Re-Run Strategy

Run the same test multiple times to identify non-deterministic failures:

```bash
# Re-run a specific test class 5 times
for i in $(seq 1 5); do
  echo "=== Run $i ==="
  ./gradlew connectedDebugAndroidTest \
    -Pandroid.testInstrumentationRunnerArguments.class=com.example.app.LoginTest \
    2>&1 | tail -5
done

# Using AndroidX test runner count argument (runs each test N times within a single invocation)
./gradlew connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.app.LoginTest \
  -Pandroid.testInstrumentationRunnerArguments.count=5
```

### Compare Results Across Runs

```bash
# Collect results from multiple runs into numbered directories
for i in $(seq 1 5); do
  ./gradlew connectedDebugAndroidTest 2>/dev/null
  cp -r build/outputs/androidTest-results "results_run_$i"
done

# Diff failure sets between runs — tests appearing in some but not all are flaky
for dir in results_run_*/; do
  echo "=== $dir ==="
  grep -rl '<failure\|<error' "$dir" 2>/dev/null | sed 's|.*/||' | sort
done | sort | uniq -c | sort -rn
# Count < 5 means flaky (didn't fail every run)
```

### Quarantine Workflow

1. **Identify**: Test fails intermittently across re-runs
2. **Annotate**: Add `@FlakyTest` (from `androidx.test.filters`)
3. **Separate in CI**: Run flaky tests in a non-blocking job (see `ci-pipeline-config.md` quarantine section)
4. **Track**: Log flaky test names in a tracking file for periodic review
5. **Fix or remove**: Investigate root cause (animation timing, race condition, network)

```kotlin
// Mark as flaky — excluded from main CI gate via annotation filter
@FlakyTest(bugId = 12345, detail = "Race condition in scroll assertion")
@Test
fun scrollToBottomShowsFooter() { ... }
```

### Common Flakiness Root Causes

| Symptom | Likely Cause | CLI Diagnostic |
|---------|-------------|----------------|
| Passes locally, fails on CI | Animation timing | Check `animator_duration_scale`: `adb shell settings get global animator_duration_scale` |
| Fails on first run only | Cold start race | Check if test assumes warm cache or loaded data |
| Fails after other tests | State leakage | Run test in isolation: filter to single class |
| Intermittent timeout | Emulator resource pressure | Check `adb shell dumpsys cpuinfo` during test |
| Different results per API | SDK behavior change | Run on multiple API levels, compare XML results |

## Iterative Debugging Loop

Agent autonomy pattern for test failure resolution:

```
1. RUN TESTS
   ./gradlew connectedDebugAndroidTest 2>&1 | tee test_output.log

2. PARSE XML
   Extract failures from build/outputs/androidTest-results/

3. IDENTIFY FAILURES
   For each <failure> or <error>:
     - Extract class#method, exception type, stack trace
     - Categorize: assertion | crash | timeout | flaky

4. LOAD RELEVANT REFERENCE
   - Assertion failure → Read test source, check expected values
   - Runtime crash → Load debug-crashes-monkey.md
   - Memory issue → Load debug-ui-memory.md
   - Compose UI issue → Load test-espresso-compose.md

5. APPLY FIX
   - Edit source code based on diagnosis
   - For flaky: add idling resource, waitUntil, or retry annotation

6. RE-RUN (targeted)
   ./gradlew connectedDebugAndroidTest \
     -Pandroid.testInstrumentationRunnerArguments.class=<FailedClass>

7. VERIFY
   Parse XML again. If still failing, repeat from step 3.
   If passing, run full suite to check for regressions.
```

## Multi-Module Result Aggregation

Projects with multiple modules produce JUnit XML in separate build directories. Merge for a unified view:

### Locate All Results

```bash
# Find all JUnit XML across modules
find . -path "*/androidTest-results/connected/*.xml" -type f | sort
find . -path "*/test-results/testDebugUnitTest/*.xml" -type f | sort

# Example output:
# ./app/build/outputs/androidTest-results/connected/TEST-device-Pixel_6_API_34.xml
# ./feature-auth/build/outputs/androidTest-results/connected/TEST-device-Pixel_6_API_34.xml
# ./core/build/test-results/testDebugUnitTest/TEST-com.example.core.UtilTest.xml
```

### Unified Summary

```bash
# Aggregate pass/fail across all modules
echo "Module | Tests | Fail | Error | Skip"
echo "-------|-------|------|-------|-----"
for xml in $(find . -path "*/androidTest-results/**/*.xml" -o -path "*/test-results/**/*.xml" | sort); do
  MODULE=$(echo "$xml" | cut -d'/' -f2)
  STATS=$(grep '<testsuite' "$xml" | head -1 | \
    sed 's/.*tests="\([^"]*\)".*failures="\([^"]*\)".*errors="\([^"]*\)".*/\1 \2 \3/')
  SKIP=$(grep '<testsuite' "$xml" | head -1 | grep -o 'skipped="[^"]*"' | grep -o '[0-9]*')
  echo "$MODULE | $STATS | ${SKIP:-0}"
done
```

### Copy Results to Single Directory

```bash
# Merge all XML into one directory for CI artifact upload
mkdir -p test-results-merged
find . -path "*/androidTest-results/connected/*.xml" -exec cp {} test-results-merged/ \;
find . -path "*/test-results/testDebugUnitTest/*.xml" -exec cp {} test-results-merged/ \;
```

## CI Integration

### Exit Code Interpretation

| Exit Code | Meaning | Agent Action |
|-----------|---------|--------------|
| 0 | All tests passed | Proceed |
| Non-zero | Test failures or build error | Parse XML for details |

Gradle wraps the actual test exit code. Check both Gradle output and XML results — Gradle may report failure for build issues unrelated to test execution.

### Artifact Collection Pattern

```bash
# Standard CI artifact paths
ARTIFACTS=(
  "build/outputs/androidTest-results/"     # Instrumented test XML
  "build/reports/androidTests/"             # HTML reports
  "build/test-results/"                     # Unit test XML
  "build/reports/tests/"                    # Unit test HTML
)

# Collect on failure
if [ $TEST_EXIT_CODE -ne 0 ]; then
  mkdir -p ci-artifacts
  for path in "${ARTIFACTS[@]}"; do
    find . -path "*/$path*" -exec rsync -R {} ci-artifacts/ \;
  done
fi
```

### PR Comment Generation from Results

Generate a markdown summary suitable for GitHub PR comments:

```bash
# Generate markdown table from JUnit XML
echo "## Test Results"
echo ""
echo "| Suite | Tests | Pass | Fail | Error | Skip |"
echo "|-------|-------|------|------|-------|------|"
for xml in $(find . -path "*/androidTest-results/**/*.xml" | sort); do
  SUITE=$(grep -o 'name="[^"]*"' "$xml" | head -1 | sed 's/name="//;s/"//')
  TESTS=$(grep -o 'tests="[^"]*"' "$xml" | head -1 | sed 's/[^0-9]//g')
  FAILS=$(grep -o 'failures="[^"]*"' "$xml" | head -1 | sed 's/[^0-9]//g')
  ERRS=$(grep -o 'errors="[^"]*"' "$xml" | head -1 | sed 's/[^0-9]//g')
  SKIP=$(grep -o 'skipped="[^"]*"' "$xml" | head -1 | sed 's/[^0-9]//g')
  PASS=$((TESTS - FAILS - ERRS - ${SKIP:-0}))
  echo "| $SUITE | $TESTS | $PASS | $FAILS | $ERRS | ${SKIP:-0} |"
done

# Append failure details
FAIL_COUNT=$(grep -rl '<failure\|<error' build/outputs/androidTest-results/ 2>/dev/null | wc -l)
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo "### Failures"
  echo '```'
  grep -B1 '<failure\|<error' build/outputs/androidTest-results/**/*.xml | \
    grep 'testcase\|message=' | head -20
  echo '```'
fi
```
