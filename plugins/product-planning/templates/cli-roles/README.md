# CLI Role Templates

> **Version:** `cli_role_version: 1.1.0`
> **Source of Truth:** These templates are the canonical definitions. Phase 1 auto-deploys to `PROJECT_ROOT/conf/cli_clients/` at runtime.

## Role Template Index

| File | Role | CLI | Phase | Read When... |
|------|------|-----|-------|--------------|
| `gemini_deepthinker.txt` | deepthinker | gemini | 5 | Primary deep analysis — broad architecture evaluation |
| `codex_deepthinker.txt` | deepthinker | codex | 5 | Code-level deep analysis — coupling and feasibility |
| `gemini_consensus.txt` | consensus | gemini | 6, 8 | Plan/coverage scoring — strategic assessment (advocate) |
| `codex_consensus.txt` | consensus | codex | 6, 8 | Plan/coverage scoring — code-level feasibility (challenger) |
| `gemini_planreviewer.txt` | planreviewer | gemini | 6 | Strategic plan review, scope assessment |
| `codex_planreviewer.txt` | planreviewer | codex | 6 | Technical feasibility, code conflict detection |
| `gemini_teststrategist.txt` | teststrategist | gemini | 7 | Test infra discovery, framework patterns |
| `codex_teststrategist.txt` | teststrategist | codex | 7 | Test code patterns, assertion quality |
| `gemini_securityauditor.txt` | securityauditor | gemini | 6b | Supply chain, architectural security |
| `codex_securityauditor.txt` | securityauditor | codex | 6b | OWASP code-level vulnerabilities |
| `gemini_taskauditor.txt` | taskauditor | gemini | 9 | Completeness, missing infrastructure tasks |
| `codex_taskauditor.txt` | taskauditor | codex | 9 | File path verification, code structure |
| `gemini.json` | — | gemini | — | Gemini CLI client configuration |
| `codex.json` | — | codex | — | Codex CLI client configuration |

## Dual-CLI Dispatch Pattern (ntm robot mode)

Every role dispatches **both CLIs** (Gemini + Codex) in parallel via a single ntm session, then the coordinator synthesizes:

```
Coordinator (Phase N)
  Step N.X: CLI Dispatch via ntm (SINGLE CALL)
  dispatch-via-ntm.sh \
    --session "planning-{FEATURE_ID}-{ROLE}" \
    --dispatch "codex:{ROLE}:{PROMPT}:{OUTPUT}" \
    --dispatch "gemini:{ROLE}:{PROMPT}:{OUTPUT}" \
    --timeout {TIMEOUT}
  +----------------+      +----------------+
  | ntm pane: cod  |      | ntm pane: gmi  |
  | role: X        |      | role: X        |
  +-------+--------+      +-------+--------+
          +----------+-----------+
                     v
  Step N.X+1: Synthesis
  - Convergent (both agree) -> HIGH confidence
  - Divergent (disagree)    -> FLAG for user decision
  - Unique (1 only raised)  -> VERIFY

  Step N.X+2: Self-Critique via Task subagent (CoVe)

  WRITE to analysis/cli-{role}-report.md
```

### Why Dual-CLI?

- **Gemini** has 1M token context: excels at broad codebase exploration, pattern discovery, tech stack analysis
- **Codex** specializes in code: excels at import chain tracing, dependency verification, file-level analysis
- **Convergent findings** (both agree) are high-confidence — no further verification needed
- **Divergent findings** surface trade-offs requiring human judgment

### Agent Teams Enhancement

When Agent Teams are enabled (`AGENT_TEAMS_ENABLED`), synthesis is enhanced with perspective-critic team debates. See `skills/plan/references/cli-dispatch-pattern.md` Team-Based Follow-Up Protocol.

## Self-Critique Subagent Pattern

Self-critique runs in a **separate Task subagent** (not inline in the coordinator) to prevent context pollution:

```
Task(subagent_type: "general-purpose", prompt: """
  Apply Chain-of-Verification to these findings:
  {cli_synthesis}

  1. Generate 3-5 verification questions
  2. Answer each question against the evidence
  3. Revise findings where verification fails
  4. Return only validated findings
""")
```

This adds ~5-10s latency but keeps coordinator context clean.

## Deployment

Phase 1 (`phase-1-setup.md`) auto-copies these templates:

```
SOURCE: $CLAUDE_PLUGIN_ROOT/templates/cli-roles/
TARGET: PROJECT_ROOT/conf/cli_clients/

IF target missing OR version marker mismatch:
  COPY all .txt and .json files
  SET state.cli.roles_deployed = true
```

## Security Note: CLI Auto-Approval Flags

CLI configs use auto-approval flags for unattended CLI dispatch:
- **Gemini**: `--yolo` (auto-approves all tool calls)
- **Codex**: `--dangerously-bypass-approvals-and-sandbox` (bypasses sandbox and approval prompts)

All CLI roles are **analysis-only** — they explore, read, and report. Role prompts explicitly forbid file modifications via the FORBIDDEN/Quality Requirements section.

## Reduced-CLI Fallback

If not all CLIs are installed, the coordinator gracefully degrades:
- **1 CLI available**: Single-CLI mode — skips synthesis, marks output as `mode: single_{cli_name}`
- **0 CLIs available**: Skip CLI steps entirely
