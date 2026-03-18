# Quick Reference — Variables, CLI Dispatch & Degradation

> Quick-reference card for coordinators. Authoritative values live in
> `$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` and `cli-dispatch-patterns.md`.

## Template Variables

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{FEATURE_DIR}` | Feature directory name | `1-add-user-auth` |
| `{FEATURE_NAME}` | Human-readable feature name | `Add User Authentication` |
| `{USER_INPUT}` | Original user feature description | (text) |
| `{SPEC_FILE}` | Path to spec | `specs/1-add-user-auth/spec.md` |
| `{STATE_FILE}` | Path to state | `specs/1-add-user-auth/.specify-state.local.md` |
| `{LOCK_FILE}` | Path to lock | `specs/1-add-user-auth/.specify.lock` |
| `{FIGMA_CONTEXT_FILE}` | Path to Figma context | `specs/1-add-user-auth/figma_context.md` |
| `{RESUME_CONTEXT}` | Resume context from state | (generated text or empty) |

---

## CLI → Model Mapping

| CLI | Model | Provider | Characteristic |
|-----|-------|----------|----------------|
| `codex` | GPT-4o | OpenAI | Precision, logical rigor, structured analysis |
| `gemini` | Gemini Pro | Google | Breadth, cross-domain synthesis, coverage |
| `opencode` | Grok (via OpenRouter) | xAI | Contrarian, assumption-challenging, unconventional |

---

## Graceful Degradation Matrix

| CLI/MCP Status | Challenge / Edge Cases / Triangulation | Gates | Evaluation (Stage 5) | Design Artifacts |
|----------------|---------------------------------------|-------|----------------------|-----------------|
| CLI + ST + Figma available | Full tri-CLI dispatch | Judge-evaluated | Multi-stance (3 CLIs) | Full |
| CLI available, ST unavailable | Full tri-CLI dispatch | Internal evaluation | Multi-stance (3 CLIs) | Full |
| CLI unavailable, ST available | Skipped (internal reasoning) | Internal evaluation | Skipped (internal gates) | Full |
| Figma unavailable | Full (unaffected) | Full | Full | Spec-only mode |
| All unavailable | Skipped | Internal evaluation | Skipped | Spec-only mode |

*Design artifacts (design-brief.md, design-supplement.md) are ALWAYS generated regardless of CLI/MCP availability.
