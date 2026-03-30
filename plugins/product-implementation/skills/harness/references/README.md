# Harness Skill — Reference Index

| File | Lines | Size | Purpose |
|------|-------|------|---------|
| `harness-components.md` | ~350 | 12K | Templates and guidance for all 6 harness categories |
| `feature-list-schema.md` | ~100 | 4K | JSON schema, tasks.md→JSON conversion, immutability rules |
| `hooks-catalog.md` | ~150 | 5K | Hook catalog with events, use cases, remediation pattern |
| `cli-agents.md` | ~170 | 6K | External CLI agent (Codex/Gemini) dispatch and instruction templates |

## Cross-References

- `harness-components.md` Section 2d references `feature-list-schema.md` for the JSON contract
- `harness-components.md` Section 2b references `hooks-catalog.md` for the full hook catalog
- `cli-agents.md` references `eval-criteria.md` (generated artifact) for review dispatch
- Both `harness-components.md` and `hooks-catalog.md` reference `.claude/settings.json` format

## Read Order

1. Start with `SKILL.md` (always loaded) — provides the workflow and decision framework
2. Read `harness-components.md` section-by-section as you configure each category
3. Read `feature-list-schema.md` when converting tasks.md in Stage 2d
4. Read `hooks-catalog.md` when choosing hooks in Stage 2b
5. Read `cli-agents.md` when Codex or Gemini CLI is available (Stage 2c/2e)
