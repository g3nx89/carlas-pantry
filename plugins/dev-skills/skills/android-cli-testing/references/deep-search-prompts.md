# Deep Search Prompts

Browser-based research prompts to generate reports that inform further skill extensions. Each prompt targets tribal knowledge, undocumented behaviors, community-discovered workarounds, and battle-tested CI configs that a coding agent wouldn't have without the skill.

## How to Use

1. Run each prompt as a deep search query in a browser-based research tool (e.g., Perplexity Pro, ChatGPT with browsing, Gemini Deep Research)
2. Save each report as `research-{number}-{topic-slug}.md`
3. Feed reports back to the coding agent for skill extension
4. Agent extracts CLI-actionable information, discards non-actionable content
5. Information is integrated into existing or new reference files following the hub-spoke model

---

## Prompt 1: Flaky Android Test Root Causes and Mitigation

```
Research the most common causes of flaky Android instrumented tests (Espresso, Compose UI tests, UI Automator) and proven CLI-based mitigation strategies.

Focus areas:
- Root causes: animation leaks, race conditions, timezone/locale sensitivity, network timeouts, emulator instability, Choreographer frame drops, WindowManager state
- Community-discovered fixes (Stack Overflow, GitHub issues on AndroidX Test, Google Issue Tracker)
- Undocumented adb shell commands or system settings that improve test stability
- Orchestrator vs non-Orchestrator flakiness differences
- Compose-specific flakiness patterns (recomposition timing, LazyColumn scroll races, ComposeTestRule idle issues)
- Retry strategies: Gradle retry plugins, AndroidX test retry annotations, custom test runners
- How major open-source Android projects (Now in Android, Tivi, Droidcon apps) handle flaky tests

Output as structured markdown with: root cause → detection method (CLI) → fix (CLI command or Gradle config) → source URL.
```

## Prompt 2: Android Emulator CI Optimization — Real-World Configurations

```
Research real-world Android emulator configurations for CI/CD pipelines that maximize stability and minimize boot/test time.

Focus areas:
- GitHub Actions: reactivecircus/android-emulator-runner vs manual emulator setup — which is more reliable in 2024-2025?
- Emulator image comparison: google_apis vs aosp_atd vs google_apis_playstore — actual boot times, stability differences, disk usage on CI
- KVM acceleration on GitHub Actions (Linux runners), Hypervisor.framework on macOS runners — setup commands and verification
- Emulator snapshot save/restore for faster CI boot (cache AVD snapshot between runs)
- Optimal AVD hardware profiles for CI: RAM, heap, screen density, cores — what actually matters
- Headless emulator flags that reduce flakiness: -no-snapshot-load, -no-boot-anim, -gpu swiftshader_indirect vs host
- Known emulator bugs by API level (API 30 DNS issues, API 33 boot hangs, API 34 improvements)
- Firebase Test Lab gcloud CLI commands: test execution, sharding, result download, flaky test detection
- Self-hosted runner physical device management: USB hub reliability, ADB keepalive, thermal monitoring
- GitLab CI specific: Docker-in-Docker emulator, KVM passthrough, shared runners limitations
- Actual .github/workflows YAML from major Android open-source projects

Output as structured markdown with: technique → CLI commands → measured impact → caveats → source URL.
```

## Prompt 3: Android Benchmark CLI Deep Dive — Microbenchmark, Macrobenchmark, Baseline Profiles

```
Research the complete CLI workflow for Android benchmarking: Microbenchmark, Macrobenchmark, and Baseline Profiles. Focus on what's NOT in the official docs — real-world gotchas and optimizations.

Focus areas:
- Microbenchmark: module setup Gradle snippets, BenchmarkRule vs benchmarkRule (Compose), JSON output format, how to parse results from CLI, allocation tracking
- Macrobenchmark: full build.gradle.kts setup, CompilationMode differences (None/Partial/Full/Ignore), StartupMode (COLD/WARM/HOT) actual behavior, custom trace sections, how to read Perfetto traces from CLI output
- Startup measurement: am start -W vs Macrobenchmark — when to use each, fullyDrawnReported implementation pattern, reportFullyDrawn() placement gotchas
- Baseline Profiles: generateBaselineProfile Gradle task, profile rules syntax, how to verify profile is installed (adb shell dumpsys package), cloud profiles vs local profiles
- Benchmark regression detection: JSON schema of benchmark results, statistical significance thresholds, how Jetpack benchmark libraries themselves detect regressions
- Physical device preparation: CPU governor lock, thermal throttle detection, airplane mode, DND mode, screen brightness — full checklist with adb commands
- Common mistakes: running benchmarks on emulator, not clearing app between runs, not accounting for thermal throttling, JIT compilation noise
- How Google's own projects (Jetpack libraries, Now in Android) configure their benchmark CI

Output as structured markdown with: topic → Gradle config snippet → CLI command → expected output format → gotcha/caveat → source URL.
```

## Prompt 4: ADB Hidden Commands and Undocumented Features

```
Research undocumented or lesser-known ADB shell commands, dumpsys services, and system properties useful for Android testing and debugging from CLI.

Focus areas:
- Hidden dumpsys services: dumpsys jobscheduler, dumpsys alarm, dumpsys netstats, dumpsys usagestats, dumpsys procstats — what each reveals, useful grep patterns
- cmd package commands beyond install/uninstall: compile, reconcile-secondary-dex-files, bg-dexopt-job, list permissions
- Settings database (settings list global/secure/system) hidden keys useful for testing: animator_duration_scale, debug.layout, window_animation_scale, immersive_mode_confirmations
- Activity Manager (am) advanced: broadcast with extras syntax, start with intent flags, profile start/stop, dumpheap
- Package Manager (pm) tricks: grant/revoke permissions by group, list features, trim-caches, set-app-links
- Window Manager (wm) undocumented: density, size, overscan, display-cutout
- Device properties (getprop/setprop) useful for testing: ro.debuggable, persist.sys.timezone, ro.hardware, dalvik.vm.heapsize
- logcat advanced filtering: --pid, --uid, -e regex, --buffer=crash, -T timestamp format
- ADB internal commands: adb reverse, adb forward, adb emu commands beyond kill (geo, network, power, sms, call)
- Community-discovered tricks from XDA Developers, Android Enthusiasts Stack Exchange, Reddit r/androiddev

Output as structured markdown with: command → purpose → example usage → expected output → caveats/API level requirements → source URL.
```

## Prompt 5: Android Test Orchestrator and Sharding — Production Patterns

```
Research real-world patterns for Android Test Orchestrator, test sharding across devices/emulators, and test result aggregation from CLI.

Focus areas:
- Orchestrator: actual performance overhead, when it helps vs when it hurts, clearPackageData gotchas, orchestrator + Compose tests interaction
- Sharding strategies: numShards/shardIndex via Gradle vs am instrument, round-robin vs smart sharding (by test duration), Flank integration
- Multi-device parallel execution: adb -s serial based sharding, device farm orchestration scripts, result merging from multiple JUnit XML files
- JUnit XML merge tools: ant junitreport, custom scripts, what CI systems (GitHub Actions, GitLab) expect
- Test filtering deep dive: -Pandroid.testInstrumentationRunnerArguments combinations (class, notClass, package, notPackage, annotation, notAnnotation, size, count, debug), undocumented runner arguments
- Custom test runners: AndroidJUnitRunner configuration, custom InstrumentationRegistry arguments, test listeners for custom reporting
- GMD (Gradle Managed Devices): device group definition, parallel execution, ftl (Firebase) device specification, actual CI usage patterns
- Test retry at the test level (vs suite level): RetryRule, custom runners, Gradle test retry plugins
- How Netflix, Uber, Square handle Android test orchestration at scale (from their engineering blogs)

Output as structured markdown with: pattern → Gradle/CLI config → measured impact → gotchas → source URL.
```

## Prompt 6: Memory Leak Detection and Heap Analysis from CLI

```
Research CLI-based memory leak detection and heap analysis techniques for Android apps, beyond what LeakCanary provides through its default UI.

Focus areas:
- LeakCanary CLI integration: dumping leaks via adb, SharkCli for heap dump analysis, custom leak detection rules
- adb shell dumpsys meminfo deep dive: reading PSS/RSS/USS, identifying memory categories (Native/Dalvik/Art), detecting leaks from meminfo trends
- Heap dump workflow: adb shell am dumpheap <pid> /data/local/tmp/heap.hprof, adb pull, conversion to standard HPROF, analysis with mat/jhat/android-studio-profiler
- Activity/Fragment leak detection without LeakCanary: counting activities via dumpsys activity, monitoring ViewRootImpl count, tracking Context references
- Bitmap memory analysis: detecting unrecycled bitmaps from hprof, identifying Glide/Coil cache sizing issues
- procstats and memtrack services for long-running leak detection
- Compose-specific memory patterns: remembered state leaks, LaunchedEffect scope leaks, CompositionLocal leaks
- Automated leak detection in CI: heap dump before/after test suite, delta analysis, threshold alerting
- Real-world memory debugging stories from engineering blogs (Square, Google, Netflix Android teams)

Output as structured markdown with: technique → CLI commands → what to look for → interpretation guide → source URL.
```

## Prompt 7: Compose UI Testing — Advanced Patterns and Edge Cases

```
Research advanced Compose UI testing patterns, edge cases, and lesser-known APIs for testing from CLI, beyond basic ComposeTestRule usage.

Focus areas:
- ComposeTestRule vs createAndroidComposeRule vs createComposeRule — when to use each and real-world differences
- Semantics tree debugging: printToLog, printToString, useUnmergedTree gotchas, custom semantics for testing
- Lazy list testing: performScrollToIndex/Key reliability, waitUntil patterns for async content, scrolling + assertion race conditions
- State restoration testing: StateRestorationTester usage from CLI, process death simulation (am kill vs force-stop for Compose)
- Navigation testing: NavHostController in tests, deep link testing, back stack assertions
- Animation testing: ComposeTestRule.mainClock, advanceTimeBy, skipToEnd, testing animated content visibility
- Screenshot testing with Compose: Roborazzi + Compose test rules, preview-based screenshot generation, golden comparison strategies
- Compose + Robolectric: what works and what doesn't (as of 2024-2025), shadow limitations, workarounds
- TestTag best practices: naming conventions, accessibility semantics vs test tags, migrating from Espresso ViewMatchers
- Multi-module Compose testing: shared test utilities, test fixtures Gradle setup, preview parameter providers
- Undocumented/experimental Compose testing APIs from recent AndroidX releases

Output as structured markdown with: pattern → test code snippet → CLI command to run → gotcha/limitation → source URL.
```

## Prompt 8: Android APK Size Analysis and Optimization from CLI

```
Research CLI-based Android APK/AAB size analysis, optimization techniques, and CI integration for size regression detection.

Focus areas:
- apkanalyzer commands: full command reference, file-size breakdown, dex method/reference count, resources by type, compare two APKs
- bundletool: build-apks from AAB, get-size-total, get-device-spec, size comparison across device configurations
- R8/ProGuard analysis from CLI: mapping file reading, removed classes/methods count, optimization verification
- Resource shrinking verification: unused resources detection, resource table analysis, split APK resource distribution
- Native library size: per-ABI size breakdown, symbol stripping verification, NDK strip commands
- Dex file analysis: dex method count tools (dex-member-counts, apk-methods), multidex overhead, class distribution
- CI size tracking: baseline comparison script patterns, GitHub Actions size comment bots, threshold alerting
- Size optimization techniques verifiable from CLI: WebP conversion, vector drawable vs PNG, Kotlin metadata stripping, 64K reference limit monitoring
- Google Play size warnings: download size vs install size vs on-disk size, how to predict each from CLI
- Real-world APK size reduction stories from engineering blogs, before/after measurements

Output as structured markdown with: technique → CLI command → expected output format → CI integration pattern → source URL.
```

## Prompt 9: Perfetto Trace Analysis from CLI

```
Research CLI-based Perfetto trace capture and analysis for Android performance debugging, without requiring the Perfetto UI web app.

Focus areas:
- Perfetto record commands: full record_config syntax, data source configuration, buffer sizes, duration, categories
- On-device trace capture: /system/bin/perfetto vs adb shell perfetto, trace processor shell commands
- trace_processor_shell: SQL queries for common performance questions (slow frames, long main thread work, binder transactions, GC pauses)
- Custom trace sections: Trace.beginSection/endSection, tracing Compose recomposition, coroutine tracing
- Perfetto SDK integration for custom trace events
- Systrace vs Perfetto migration: equivalent commands, feature differences
- Automated Perfetto analysis: scripted SQL queries for regression detection, frame timing extraction, jank classification
- ftrace events useful for Android: sched/freq/idle, binder transactions, GPU rendering
- Integration with Macrobenchmark: how Macrobenchmark captures Perfetto traces, extracting them from test results
- Common Perfetto analysis patterns from Android performance engineering blogs

Output as structured markdown with: use case → capture command → analysis SQL query → interpretation guide → source URL.
```

## Prompt 10: Android Test Coverage Beyond JaCoCo

```
Research Android test coverage tools and techniques beyond basic JaCoCo, including alternative coverage tools and advanced JaCoCo configurations for CLI usage.

Focus areas:
- JaCoCo advanced: merged coverage from unit + instrumented tests, exclusion patterns for generated code (Dagger, Room, DataBinding, Compose), custom report formats
- JaCoCo XML parsing: exact XML schema, XPath queries for line/branch/method/class coverage extraction, per-package and per-class breakdown
- Kover (JetBrains): setup, advantages over JaCoCo for Kotlin code, CLI report generation, Compose coverage accuracy
- Coverage for Compose UI tests: what gets covered when running Compose tests, composable function coverage vs lambda coverage
- Coverage for Robolectric tests: JaCoCo + Robolectric integration gotchas, offline vs online instrumentation
- Coverage thresholds in CI: minimum coverage gates, coverage delta (diff coverage — only new/changed lines), diffCover and similar tools
- Coverage for multi-module projects: aggregated reports across modules, Gradle configuration for merged report
- Coverage visualization from CLI: generate HTML report, extract summary statistics, badge generation for README
- Test impact analysis: using coverage data to determine which tests to run for a given code change, Google's TAP-like approaches for Android
- Real-world coverage strategies from large Android projects (what % they target, how they enforce)

Output as structured markdown with: tool/technique → Gradle config → CLI command → output format → gotcha → source URL.
```

## Prompt 11: Android Accessibility Testing from CLI

```
Research CLI-based accessibility testing techniques for Android apps, enabling a coding agent to validate a11y compliance without Android Studio.

Focus areas:
- Accessibility Scanner CLI: adb-based a11y checks, programmatic access to accessibility service results
- Espresso accessibility checks: AccessibilityChecks.enable(), custom check configurations, severity filtering
- Compose accessibility testing: semantics-based assertions (contentDescription, role, stateDescription), Accessibility CTS tests
- adb shell uiautomator dump: extracting accessibility tree, checking content descriptions, NAF (Not Accessibility Friendly) nodes
- Accessibility lint checks: command-line lint with accessibility rules, custom lint rules for project-specific a11y patterns
- TalkBack testing from CLI: adb shell settings put secure enabled_accessibility_services, focus order verification
- Touch target size validation: extracting view bounds from UI hierarchy dump, minimum 48dp verification
- Color contrast checking: extracting colors from layout dumps, WCAG AA/AAA ratio calculation
- Accessibility testing in CI: automated a11y checks in test pipeline, reporting format, common failures
- Real-world Android accessibility testing patterns from Google's guidance and community blogs

Output as structured markdown with: technique → CLI command → validation criteria → common failures → source URL.
```

## Prompt 12: Gradle Test Configuration Deep Dive for Android

```
Research advanced Gradle test configuration for Android projects, focusing on CLI-driven test execution patterns that improve speed, reliability, and debuggability.

Focus areas:
- Test execution options: maxParallelForks, forkEvery, failFast, test retry (Gradle Enterprise / Develocity), TestNG-style test execution order
- Android test options in DSL: animationsDisabled, execution 'ANDROIDX_TEST_ORCHESTRATOR', additionalTestOutputDir, managedDevices
- Gradle Test Filtering advanced: using --tests with wildcards, combining --tests with -P arguments, filtering by annotation, exclude patterns
- Gradle managed devices: full DSL for device definitions, device groups, test distribution, CI properties (managed.device.ci, managed.device.enable.setup.timeout)
- Test caching: Gradle build cache for test tasks, when tests are UP-TO-DATE vs FROM-CACHE, cache hit optimization
- Test logging: showStandardStreams, exceptionFormat, events configuration, custom test logging
- Composite builds and test dependencies: includeBuild testing, test fixtures plugin, shared test resources across modules
- AGP test task names: understanding connectedDebugAndroidTest vs debugAndroidTest, managed device test task naming
- Gradle profiling for test execution: --scan, --profile, build timeline analysis for slow test phases
- Gradle properties for Android testing: android.testInstrumentationRunnerArguments.*, android.builder.sdkDownload, custom properties
- Real CI Gradle configurations from large Android open-source projects

Output as structured markdown with: configuration → Gradle DSL snippet → CLI flag equivalent → impact → gotcha → source URL.
```
