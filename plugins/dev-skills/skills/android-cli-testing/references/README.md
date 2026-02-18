# android-cli-testing References

Index of reference files for the `android-cli-testing` skill. See the Reference Map in `SKILL.md` for topic-based routing.

Last verified: 2026-02

## File Inventory

| File | Lines | Words | Size | Topic |
|------|------:|------:|-----:|-------|
| adb-connection-apps.md | 246 | 1,439 | 11K | ADB architecture, USB/WiFi/TCP, app install, permissions, Activity Manager |
| adb-logcat-dumpsys.md | 507 | 2,388 | 20K | Logcat filtering/buffers, dumpsys services, hidden commands, settings database, cmd package, wm, getprop/setprop, deep link verification, JDWP |
| adb-io-system.md | 163 | 847 | 8.0K | File push/pull, database access, network debug, input, screen capture |
| emulator-cli.md | 373 | 1,846 | 16K | sdkmanager, avdmanager, emulator flags, config.ini, console, acceleration, API-level bugs, CI hardware profiles, boot time comparison |
| test-espresso-compose.md | 896 | 3,682 | 36K | Gradle filtering, sharding, Orchestrator, Compose semantics/debugging/clock, flaky root cause diagnostics, retry strategies, Flank, navigation testing, process death, JVM test config |
| test-automation-tools.md | 156 | 553 | 8.0K | UI Automator, Appium parallel setup, Maestro CLI/flows |
| test-robolectric-screenshots.md | 422 | 1,446 | 16K | JVM tests, Compose+Robolectric compatibility, state restoration, Paparazzi, Roborazzi, multi-module testing |
| test-coverage-gmd.md | 647 | 2,481 | 24K | JaCoCo setup/merging, Kover, diff coverage, Compose coverage, multi-module aggregation, GMD definition/groups/CI, per-class extraction, offline instrumentation |
| debug-data-storage.md | 187 | 771 | 8.0K | StrictMode, SQLite/Room, SQL tracing, SharedPreferences |
| debug-ui-memory.md | 633 | 3,359 | 28K | UIAutomator dump, window state, Compose semantics, memory leaks, heap dumps, SharkCli, procstats, Compose leak patterns, CI leak detection, LeakCanary broadcast, ObjectInspectors, force GC |
| test-result-parsing.md | 317 | 1,595 | 16K | JUnit XML parsing, failure triage, flaky detection, iterative debugging, CI integration |
| benchmark-cli.md | 645 | 3,220 | 28K | Microbenchmark, Macrobenchmark, startup measurement, Baseline Profiles, regression detection, FTL benchmarking, custom trace sections, cloud profiles, StartupMode |
| apk-size-analysis.md | 514 | 2,105 | 20K | apkanalyzer, bundletool, R8/ProGuard analysis, resource shrinking, native libs, DEX analysis, CI size tracking, R8 full mode, 64K limit monitoring |
| debug-crashes-monkey.md | 258 | 1,221 | 12K | ANR traces, tombstones, ndk-stack, crash testing, monkey, automated crash diagnosis |
| debug-system-simulation.md | 205 | 1,050 | 8.0K | Doze, battery, density, locale, dark mode, multi-window |
| performance-profiling.md | 778 | 3,046 | 28K | Perfetto config/capture/SQL analysis, gfxinfo, method tracing, heap analysis, automated jank detection, Compose tracing, coroutine tracing, trace sharing |
| ci-pipeline-config.md | 828 | 3,993 | 32K | Test tiers, emulator config, KVM setup, AVD snapshot caching, GMD CI, device hardening, flaky quarantine, Marathon, Firebase, self-hosted runners, pre-flight, coverage gates, GitLab CI, build cache |
| device-setup-oem.md | 215 | 1,122 | 8.0K | Physical device CLI setup, multi-device, OEM quirks, ADB reliability |
| gui-walkthroughs.md | 193 | 1,053 | 8.0K | GUI-only device operations: Developer Options, USB debugging, OEM toggles |
| accessibility-testing.md | 377 | 1,477 | 16K | Espresso a11y checks, Compose semantics assertions, TalkBack CLI, touch target validation, color contrast, accessibility lint, CI integration, focus order, dumpsys a11y |
| workflow-recipes.md | 439 | 1,380 | 12K | End-to-end scripts, GitHub Actions, GitLab CI |
| deep-search-prompts.md | 249 | 2,467 | 20K | Browser-based research prompts for skill enrichment (flaky tests, CI, benchmarks, ADB, coverage, a11y) |
| **Total** | **9,248** | **42,541** | **384K** | |

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
