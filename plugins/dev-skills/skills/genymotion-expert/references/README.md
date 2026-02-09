# Genymotion Expert — Reference Files

## File Usage

| File | Lines | Size | Purpose | When to Read |
|------|-------|------|---------|--------------|
| `cli-reference.md` | 417 | 15K | GMTool and Genymotion Shell complete command reference | Looking up specific commands, options, error codes, ARM translation, proxy setup |
| `ci-and-recipes.md` | 597 | 19K | CI/CD integration patterns and workflow recipe scripts | Configuring CI pipelines, writing automation scripts, parallel testing |
| `test-integration.md` | 467 | 19K | Test framework integration, reliability patterns, and ADB patterns | Setting up Espresso, Compose, Maestro, Appium; diagnosing test flakiness |

## Cross-References Between Files

| Source File | References To | Topic |
|-------------|---------------|-------|
| `cli-reference.md` | `ci-and-recipes.md` | Boot-wait pattern used in CI recipes |
| `ci-and-recipes.md` | `cli-reference.md` | GMTool commands used in recipes |
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
