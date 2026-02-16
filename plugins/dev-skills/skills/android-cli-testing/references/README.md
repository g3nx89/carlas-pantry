# android-cli-testing References

Index of reference files for the `android-cli-testing` skill. See the Reference Map in `SKILL.md` for topic-based routing.

## File Inventory

| File | Lines | Words | Size | Topic |
|------|------:|------:|-----:|-------|
| adb-connection-apps.md | 246 | 1,439 | 11K | ADB architecture, USB/WiFi/TCP, app install, permissions, Activity Manager |
| adb-logcat-dumpsys.md | 150 | 804 | 5.5K | Logcat filtering/buffers, dumpsys services, window focus, fragment state |
| adb-io-system.md | 166 | 862 | 6.2K | File push/pull, database access, network debug, input, screen capture |
| emulator-cli.md | 299 | 1,288 | 10K | sdkmanager, avdmanager, emulator flags, config.ini, console, acceleration |
| test-espresso-compose.md | 311 | 1,034 | 10K | Gradle filtering, sharding, Orchestrator, Compose semantics/debugging/clock |
| test-automation-tools.md | 156 | 553 | 4.2K | UI Automator, Appium parallel setup, Maestro CLI/flows |
| test-robolectric-screenshots.md | 184 | 588 | 4.6K | JVM tests, Compose+Robolectric gotchas, Paparazzi, Roborazzi |
| test-coverage-gmd.md | 229 | 664 | 6.1K | JaCoCo setup/merging, GMD definition/groups/CI properties |
| debug-data-storage.md | 187 | 771 | 5.9K | StrictMode, SQLite/Room, SQL tracing, SharedPreferences |
| debug-ui-memory.md | 176 | 739 | 5.6K | UIAutomator dump, window state, Compose semantics, memory leaks, heap dumps |
| test-result-parsing.md | 317 | 1,595 | 13K | JUnit XML parsing, failure triage, flaky detection, iterative debugging, CI integration |
| benchmark-cli.md | 443 | 1,628 | 13K | Microbenchmark, Macrobenchmark, startup measurement, Baseline Profiles, APK size, regression detection |
| debug-crashes-monkey.md | 258 | 1,221 | 8.1K | ANR traces, tombstones, ndk-stack, crash testing, monkey, automated crash diagnosis |
| debug-system-simulation.md | 205 | 1,050 | 7.1K | Doze, battery, density, locale, dark mode, multi-window |
| performance-profiling.md | 305 | 1,375 | 10K | Perfetto, gfxinfo, method tracing, heap analysis, Baseline Profile verification |
| ci-pipeline-config.md | 405 | 1,852 | 14K | Test tiers, emulator config, GMD CI, determinism, flaky quarantine, Firebase, pre-flight, coverage gates |
| device-setup-oem.md | 215 | 1,124 | 7.9K | Physical device CLI setup, multi-device, OEM quirks, ADB reliability |
| gui-walkthroughs.md | 193 | 1,053 | 6.9K | GUI-only device operations: Developer Options, USB debugging, OEM toggles |
| workflow-recipes.md | 439 | 1,380 | 11K | End-to-end scripts, GitHub Actions, GitLab CI |
| deep-search-prompts.md | 249 | 2,467 | 18K | Browser-based research prompts for skill enrichment (flaky tests, CI, benchmarks, ADB, coverage, a11y) |
| **Total** | **5,133** | **23,487** | **220K** | |

## Cross-References

Arrows show which files reference which. Each file links to its closest siblings so Claude can navigate without loading SKILL.md again.

| File | References |
|------|------------|
| adb-connection-apps.md | adb-logcat-dumpsys.md, adb-io-system.md |
| adb-logcat-dumpsys.md | adb-connection-apps.md, adb-io-system.md, performance-profiling.md |
| adb-io-system.md | adb-connection-apps.md, adb-logcat-dumpsys.md |
| emulator-cli.md | (none) |
| test-espresso-compose.md | test-automation-tools.md, test-robolectric-screenshots.md, test-coverage-gmd.md, adb-connection-apps.md |
| test-automation-tools.md | test-espresso-compose.md |
| test-robolectric-screenshots.md | test-espresso-compose.md |
| test-coverage-gmd.md | ci-pipeline-config.md |
| debug-data-storage.md | debug-ui-memory.md, debug-crashes-monkey.md, debug-system-simulation.md, adb-io-system.md |
| debug-ui-memory.md | debug-data-storage.md, debug-crashes-monkey.md, debug-system-simulation.md |
| test-result-parsing.md | test-espresso-compose.md, ci-pipeline-config.md, debug-crashes-monkey.md |
| benchmark-cli.md | performance-profiling.md, ci-pipeline-config.md, test-espresso-compose.md |
| debug-crashes-monkey.md | debug-ui-memory.md, debug-system-simulation.md, test-result-parsing.md |
| debug-system-simulation.md | debug-data-storage.md, debug-crashes-monkey.md |
| performance-profiling.md | debug-ui-memory.md, benchmark-cli.md |
| ci-pipeline-config.md | device-setup-oem.md, workflow-recipes.md, test-espresso-compose.md, test-coverage-gmd.md, test-result-parsing.md |
| device-setup-oem.md | ci-pipeline-config.md, adb-connection-apps.md, gui-walkthroughs.md |
| gui-walkthroughs.md | device-setup-oem.md, adb-connection-apps.md |
| deep-search-prompts.md | (none) |
| workflow-recipes.md | (none) |

## File Groups

Files cluster into six functional groups. Within each group, sibling cross-references enable navigation without returning to SKILL.md.

- **ADB**: adb-connection-apps.md, adb-logcat-dumpsys.md, adb-io-system.md
- **Emulator**: emulator-cli.md
- **Test Frameworks**: test-espresso-compose.md, test-automation-tools.md, test-robolectric-screenshots.md, test-coverage-gmd.md, test-result-parsing.md
- **Debugging**: debug-data-storage.md, debug-ui-memory.md, debug-crashes-monkey.md, debug-system-simulation.md
- **Performance**: performance-profiling.md, benchmark-cli.md
- **CI/CD**: ci-pipeline-config.md, device-setup-oem.md, workflow-recipes.md
- **GUI Walkthroughs**: gui-walkthroughs.md
- **Research**: deep-search-prompts.md
