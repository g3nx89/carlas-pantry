# Genymotion Expert — Reference Files

## File Usage

| File | Lines | Size | Purpose | When to Read |
|------|-------|------|---------|--------------|
| `emulated-features.md` | ~550 | ~22K | All emulated sensors and features: GPS, battery, network, motion sensors, biometrics, camera injection, gamepad, disk I/O, phone/SMS, device identity, baseband, advanced developer tools, sensor state management, testing strategy matrix | Configuring or testing any emulated feature; understanding feature availability and limitations |
| `cli-reference.md` | 417 | 15K | GMTool and Genymotion Shell complete command reference | Looking up specific commands, options, error codes, ARM translation, proxy setup |
| `ci-and-recipes.md` | 597 | 19K | CI/CD integration patterns and workflow recipe scripts | Configuring CI pipelines, writing automation scripts, parallel testing |
| `test-integration.md` | ~480 | ~20K | Test framework integration, reliability patterns, and ADB patterns | Setting up Espresso, Compose, Maestro, Appium; diagnosing test flakiness |

## Cross-References Between Files

| Source File | References To | Topic |
|-------------|---------------|-------|
| `emulated-features.md` | `cli-reference.md` | Genymotion Shell command syntax referenced for each feature |
| `emulated-features.md` | `ci-and-recipes.md` | Recipe 5 (GPX route playback) and Recipe 6 (network degradation) |
| `emulated-features.md` | `test-integration.md` | Test Stability Checklist for animation disabling via ADB |
| `cli-reference.md` | `ci-and-recipes.md` | Boot-wait pattern used in CI recipes |
| `ci-and-recipes.md` | `cli-reference.md` | GMTool commands used in recipes |
| `test-integration.md` | `emulated-features.md` | Feature Availability Matrix and Testing Strategy decision matrix |
| `test-integration.md` | `ci-and-recipes.md` | Recipe 2 for complete parallel testing with cleanup and result aggregation |
| `test-integration.md` | `cli-reference.md` | Genymotion Shell sensor commands for reset scripts |
| `test-integration.md` | SKILL.md | Concurrent instance limits referenced in Memory Overuse flakiness pattern |

## Canonical Definitions

The following definitions live in `SKILL.md` (the hub document) and should not be duplicated in reference files:

- **ABI Support Matrix** — which ABIs work on which platform
- **Hypervisor Layer Table** — default hypervisor per OS
- **Concurrent Instance Limits** — max instances per host RAM
- **Anti-Patterns Table** — common mistakes and corrections
- **Boot Wait Pattern** — canonical `wait_for_boot()` function in Quick Reference
