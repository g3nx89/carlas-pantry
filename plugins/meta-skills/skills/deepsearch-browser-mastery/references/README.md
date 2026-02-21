# DeepSearch Browser Mastery — Reference Files

## File Usage

| File | Lines | Size | Purpose | Load Condition |
|------|-------|------|---------|----------------|
| `provider-interactions.md` | 326 | ~14 KB | Per-provider DOM patterns, input selectors, wait signals, response extraction, onboarding flows, troubleshooting | Always — core operational guide for browser interactions |
| `synthesis-patterns.md` | 225 | ~7 KB | Output templates (Quick Search + Deep Research), synthesis strategies, citation formatting, round management | When producing final output or running multi-round Deep Research mode |
| `deep-research-flows.md` | ~340 | ~13 KB | Native Deep Research activation, configuration, wait strategies, and report saving per provider (ChatGPT, Gemini, Perplexity) | When the user requests native Deep Research (not the skill's own multi-round mode) |

## Cross-References

| Source File | References | Context |
|-------------|-----------|---------|
| `SKILL.md` | `provider-interactions.md` | Provider Timing & Wait Strategy section |
| `SKILL.md` | `synthesis-patterns.md` | Phase 3 / Phase 3-Deep synthesis output |
| `SKILL.md` | `deep-research-flows.md` | Native Deep Research mode activation and report saving |
| `provider-interactions.md` | `synthesis-patterns.md` | Cross-Provider Comparison table informs synthesis strategy selection |
| `synthesis-patterns.md` | `provider-interactions.md` | Source citation rules reference Perplexity extraction patterns |
| `deep-research-flows.md` | `provider-interactions.md` | Reuses input/extraction methods from provider interactions |
| `deep-research-flows.md` | `synthesis-patterns.md` | References Deep Research output template (when synthesis is requested) |

## Content Boundaries

- **provider-interactions.md** owns: DOM discovery, input/submit/wait/extract patterns per provider, troubleshooting
- **synthesis-patterns.md** owns: output templates, synthesis strategies, round management, citation formatting, quality checklist
- **deep-research-flows.md** owns: native Deep Research activation, source/app configuration, extended wait strategies, report saving patterns
- **SKILL.md** owns: workflow orchestration, mode selection, provider selection guide, error handling, anti-patterns
