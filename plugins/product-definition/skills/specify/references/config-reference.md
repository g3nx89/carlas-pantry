# Quick Reference — Variables, Profiles & Degradation

> Quick-reference card for coordinators. Feature flags and thresholds are resolved
> by Stage 1 (Step 1.2b) from the selected profile and passed via dispatch context.
> Profile definitions: `$CLAUDE_PLUGIN_ROOT/config/specify-profile-definitions.yaml`.
> User config: `$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` (clarification + CLI paths only).

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
| `{PROFILE}` | Selected quality profile | `standard` |

---

## Profile Summary

| Profile | CLI Dispatch | Gates | Test Strategy | RTM | Retro | Coverage | Max Iter | CLI Timeout |
|---------|-------------|-------|---------------|-----|-------|----------|----------|-------------|
| Rapid | OFF | OFF | OFF | OFF | OFF | 85% | 5 | 1.0x |
| Standard | ON | ON | ON | ON | ON | 85% | 10 | 1.0x |
| Thorough | ON | ON | ON | ON | ON | 90% | 15 | 1.5x |

---

## CLI → Model Mapping

| CLI | Model | Provider | Characteristic |
|-----|-------|----------|----------------|
| `codex` | GPT-4o | OpenAI | Precision, logical rigor, structured analysis |
| `gemini` | Gemini Pro | Google | Breadth, cross-domain synthesis, coverage |

**Dispatch tool:** ntm (Named Tmux Manager). Install: `brew install dicklesworthstone/tap/ntm`

---

## Graceful Degradation Matrix

| CLI/MCP Status | Challenge / Edge Cases / Triangulation | Gates | Evaluation (Stage 5) | Design Artifacts |
|----------------|---------------------------------------|-------|----------------------|-----------------|
| ntm + CLIs + ST + Figma available | Full dual-CLI dispatch via ntm | Judge-evaluated | Dual-stance (2 CLIs) | Full |
| ntm + CLIs available, ST unavailable | Full dual-CLI dispatch via ntm | Internal evaluation | Dual-stance (2 CLIs) | Full |
| CLIs unavailable or ntm missing | Skipped (internal reasoning) | Internal evaluation | Skipped (internal gates) | Full |
| Figma unavailable | Full (unaffected) | Full | Full | Spec-only mode |
| All unavailable | Skipped | Internal evaluation | Skipped | Spec-only mode |

*Design artifacts (design-brief.md, design-supplement.md) are ALWAYS generated regardless of CLI/MCP availability or profile.
