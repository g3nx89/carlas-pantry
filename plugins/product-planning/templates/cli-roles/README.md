# CLI Role Templates

> **Version:** `cli_role_version: 1.0.0`
> **Source of Truth:** These templates are the canonical definitions. Phase 1 auto-deploys to `PROJECT_ROOT/conf/cli_clients/` at runtime.

## Role Template Index

| File | Role | CLI | Phase | Read When... |
|------|------|-----|-------|--------------|
| `gemini_deepthinker.txt` | deepthinker | gemini | 5 | Supplementing ThinkDeep with broad architecture analysis |
| `codex_deepthinker.txt` | deepthinker | codex | 5 | Supplementing ThinkDeep with code-level coupling analysis |
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

## Dual-CLI MPA Pattern

Every role runs **both** Gemini and Codex in parallel via Bash dispatch, then the coordinator synthesizes:

```
Coordinator (Phase N)
  Step N.X: CLI Dual-CLI Dispatch (PARALLEL)
  +----------------+      +----------------+
  | Bash(bg=true)  |      | Bash(bg=true)  |
  | dispatch-cli   |      | dispatch-cli   |
  | --cli gemini   |      | --cli codex    |
  | --role X       |      | --role X       |
  +-------+--------+      +-------+--------+
          +---------+----------+
                    v
  Step N.X+1: Synthesis (inline)
  - Convergent (both agree) -> HIGH confidence
  - Divergent (disagree) -> FLAG for user decision
  - Unique (one only) -> VERIFY

  Step N.X+2: Self-Critique via Task subagent
  Task(general-purpose):
    ST CoVe: 3-5 verification Qs -> revise -> output
  -> Returns validated findings only

  WRITE to analysis/cli-{role}-report.md
```

### Why Dual-CLI?

- **Gemini** has 1M token context: excels at broad codebase exploration, pattern discovery, tech stack analysis
- **Codex** specializes in code: excels at import chain tracing, dependency verification, file-level analysis
- **Convergent findings** (both agree) are high-confidence — no further verification needed
- **Divergent findings** surface blind spots that single-CLI analysis would miss

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

Both CLI configs use auto-approval flags for unattended CLI dispatch:
- **Gemini**: `--yolo` (auto-approves all tool calls)
- **Codex**: `--dangerously-bypass-approvals-and-sandbox` (bypasses sandbox and approval prompts)

All CLI roles are **analysis-only** — they explore, read, and report. Role prompts explicitly forbid file modifications via the FORBIDDEN/Quality Requirements section. However, the auto-approval flags grant write access at the CLI level. This is a known trade-off: unattended dispatch requires auto-approval, but the prompt-level restrictions prevent unintended writes under normal operation.

## Single-CLI Fallback

If only one CLI is installed, the coordinator runs single-CLI mode:
- Uses whichever CLI is available
- Skips synthesis (no dual findings to merge)
- Marks output as `mode: single_{cli_name}` for traceability
