# android-cli-testing References

Index of reference files for the `android-cli-testing` skill. See the Reference Map in `SKILL.md` for topic-based routing.

Last verified: 2026-02

## File Inventory

| File | Lines | Words | Size | Topic |
|------|------:|------:|-----:|-------|
| adb-connection-apps.md | 246 | 1,439 | 11K | ADB architecture, USB/WiFi/TCP, app install, permissions, Activity Manager |
| adb-logcat-dumpsys.md | 466 | 2,149 | 15K | Logcat filtering/buffers, dumpsys services, hidden commands, settings database, cmd package, wm, getprop/setprop |
| adb-io-system.md | 163 | 850 | 6.1K | File push/pull, database access, network debug, input, screen capture |
| emulator-cli.md | 363 | 1,750 | 13K | sdkmanager, avdmanager, emulator flags, config.ini, console, acceleration, API-level bugs, CI hardware profiles |
| test-espresso-compose.md | 723 | 2,823 | 25K | Gradle filtering, sharding, Orchestrator, Compose semantics/debugging/clock, flaky patterns, retry strategies, Flank |
| test-automation-tools.md | 156 | 553 | 4.2K | UI Automator, Appium parallel setup, Maestro CLI/flows |
| test-robolectric-screenshots.md | 422 | 1,446 | 13K | JVM tests, Compose+Robolectric compatibility, state restoration, Paparazzi, Roborazzi, multi-module testing |
| test-coverage-gmd.md | 620 | 2,288 | 21K | JaCoCo setup/merging, Kover, diff coverage, Compose coverage, multi-module aggregation, GMD definition/groups/CI |
| debug-data-storage.md | 187 | 771 | 5.9K | StrictMode, SQLite/Room, SQL tracing, SharedPreferences |
| debug-ui-memory.md | 590 | 3,127 | 22K | UIAutomator dump, window state, Compose semantics, memory leaks, heap dumps, SharkCli, procstats, Compose leak patterns, CI leak detection |
| test-result-parsing.md | 317 | 1,595 | 13K | JUnit XML parsing, failure triage, flaky detection, iterative debugging, CI integration |
| benchmark-cli.md | 578 | 2,600 | 20K | Microbenchmark, Macrobenchmark, startup measurement, Baseline Profiles, regression detection, FTL benchmarking |
| apk-size-analysis.md | 469 | 2,300 | 18K | apkanalyzer, bundletool, R8/ProGuard analysis, resource shrinking, native libs, DEX analysis, CI size tracking |
| debug-crashes-monkey.md | 258 | 1,221 | 8.1K | ANR traces, tombstones, ndk-stack, crash testing, monkey, automated crash diagnosis |
| debug-system-simulation.md | 205 | 1,050 | 7.1K | Doze, battery, density, locale, dark mode, multi-window |
| performance-profiling.md | 700 | 2,750 | 22K | Perfetto config/capture/SQL analysis, gfxinfo, method tracing, heap analysis, automated jank detection, Compose tracing |
| ci-pipeline-config.md | 704 | 3,350 | 26K | Test tiers, emulator config, KVM setup, AVD snapshot caching, GMD CI, device hardening, flaky quarantine, Marathon, Firebase, self-hosted runners, pre-flight, coverage gates |
| device-setup-oem.md | 215 | 1,124 | 7.9K | Physical device CLI setup, multi-device, OEM quirks, ADB reliability |
| gui-walkthroughs.md | 193 | 1,053 | 6.9K | GUI-only device operations: Developer Options, USB debugging, OEM toggles |
| accessibility-testing.md | 351 | 1,219 | 11K | Espresso a11y checks, Compose semantics assertions, TalkBack CLI, touch target validation, color contrast, accessibility lint, CI integration |
| workflow-recipes.md | 439 | 1,380 | 11K | End-to-end scripts, GitHub Actions, GitLab CI |
| deep-search-prompts.md | 249 | 2,467 | 18K | Browser-based research prompts for skill enrichment (flaky tests, CI, benchmarks, ADB, coverage, a11y) |
| **Total** | **8,614** | **39,305** | **345K** | |

## Cross-References

Arrows show which files reference which. Each file links to its closest siblings so Claude can navigate without loading SKILL.md again.

| File | References |
|------|------------|
| adb-connection-apps.md | adb-logcat-dumpsys.md, adb-io-system.md |
| adb-logcat-dumpsys.md | adb-connection-apps.md, adb-io-system.md, performance-profiling.md |
| adb-io-system.md | adb-connection-apps.md, adb-logcat-dumpsys.md |
| emulator-cli.md | ci-pipeline-config.md |
| test-espresso-compose.md | test-automation-tools.md, test-robolectric-screenshots.md, test-coverage-gmd.md, adb-connection-apps.md, accessibility-testing.md |
| test-automation-tools.md | test-espresso-compose.md |
| test-robolectric-screenshots.md | test-espresso-compose.md |
| test-coverage-gmd.md | ci-pipeline-config.md |
| debug-data-storage.md | debug-ui-memory.md, debug-crashes-monkey.md, debug-system-simulation.md, adb-io-system.md |
| debug-ui-memory.md | debug-data-storage.md, debug-crashes-monkey.md, debug-system-simulation.md, performance-profiling.md |
| test-result-parsing.md | test-espresso-compose.md, ci-pipeline-config.md, debug-crashes-monkey.md |
| benchmark-cli.md | apk-size-analysis.md, performance-profiling.md, ci-pipeline-config.md, test-espresso-compose.md |
| apk-size-analysis.md | benchmark-cli.md, ci-pipeline-config.md |
| debug-crashes-monkey.md | debug-ui-memory.md, debug-system-simulation.md, test-result-parsing.md |
| debug-system-simulation.md | debug-data-storage.md, debug-crashes-monkey.md |
| performance-profiling.md | debug-ui-memory.md, benchmark-cli.md, apk-size-analysis.md |
| ci-pipeline-config.md | device-setup-oem.md, workflow-recipes.md, test-espresso-compose.md, test-coverage-gmd.md, test-result-parsing.md, emulator-cli.md |
| device-setup-oem.md | ci-pipeline-config.md, adb-connection-apps.md, gui-walkthroughs.md |
| gui-walkthroughs.md | device-setup-oem.md, adb-connection-apps.md |
| accessibility-testing.md | test-espresso-compose.md, debug-ui-memory.md, ci-pipeline-config.md |
| deep-search-prompts.md | (none) |
| workflow-recipes.md | (none) |

## File Groups

Files cluster into nine functional groups. Within each group, sibling cross-references enable navigation without returning to SKILL.md.

- **ADB**: adb-connection-apps.md, adb-logcat-dumpsys.md, adb-io-system.md
- **Emulator**: emulator-cli.md
- **Test Frameworks**: test-espresso-compose.md, test-automation-tools.md, test-robolectric-screenshots.md, test-coverage-gmd.md, test-result-parsing.md
- **Debugging**: debug-data-storage.md, debug-ui-memory.md, debug-crashes-monkey.md, debug-system-simulation.md
- **Performance**: performance-profiling.md, benchmark-cli.md
- **APK Analysis**: apk-size-analysis.md
- **Accessibility**: accessibility-testing.md
- **CI/CD**: ci-pipeline-config.md, device-setup-oem.md, workflow-recipes.md
- **GUI Walkthroughs**: gui-walkthroughs.md
- **Research**: deep-search-prompts.md
