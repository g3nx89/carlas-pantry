# CLI Role Templates

> **Version:** `cli_role_version: 1.1.0`
> **Source of Truth:** These templates are the canonical definitions. Phase 1 auto-deploys to `PROJECT_ROOT/conf/cli_clients/` at runtime.

## Role Template Index

| File | Role | CLI | Phase | Read When... |
|------|------|-----|-------|--------------|
| `gemini_deepthinker.txt` | deepthinker | gemini | 5 | Primary deep analysis — broad architecture evaluation |
| `codex_deepthinker.txt` | deepthinker | codex | 5 | Code-level deep analysis — coupling and feasibility |
| `opencode_deepthinker.txt` | deepthinker | opencode | 5 | UX/Product deep analysis — user flows, accessibility, design patterns |
| `gemini_consensus.txt` | consensus | gemini | 6, 8 | Plan/coverage scoring — strategic assessment (advocate) |
| `codex_consensus.txt` | consensus | codex | 6, 8 | Plan/coverage scoring — code-level feasibility (challenger) |
| `opencode_consensus.txt` | consensus | opencode | 6, 8 | Plan/coverage scoring — product alignment (product_lens) |
| `gemini_planreviewer.txt` | planreviewer | gemini | 6 | Strategic plan review, scope assessment |
| `codex_planreviewer.txt` | planreviewer | codex | 6 | Technical feasibility, code conflict detection |
| `opencode_planreviewer.txt` | planreviewer | opencode | 6 | Product risk review, user journey gaps |
| `gemini_teststrategist.txt` | teststrategist | gemini | 7 | Test infra discovery, framework patterns |
| `codex_teststrategist.txt` | teststrategist | codex | 7 | Test code patterns, assertion quality |
| `opencode_teststrategist.txt` | teststrategist | opencode | 7 | UAT quality, accessibility test coverage |
| `gemini_securityauditor.txt` | securityauditor | gemini | 6b | Supply chain, architectural security |
| `codex_securityauditor.txt` | securityauditor | codex | 6b | OWASP code-level vulnerabilities |
| `opencode_securityauditor.txt` | securityauditor | opencode | 6b | Privacy UX, consent flows, PII handling |
| `gemini_taskauditor.txt` | taskauditor | gemini | 9 | Completeness, missing infrastructure tasks |
| `codex_taskauditor.txt` | taskauditor | codex | 9 | File path verification, code structure |
| `opencode_taskauditor.txt` | taskauditor | opencode | 9 | User story coverage, UX task completeness |
| `gemini.json` | — | gemini | — | Gemini CLI client configuration |
| `codex.json` | — | codex | — | Codex CLI client configuration |
| `opencode.json` | — | opencode | — | OpenCode CLI client configuration |

## Multi-CLI MPA Pattern

Every role runs **all available CLIs** (Gemini, Codex, OpenCode) in parallel via Bash dispatch, then the coordinator synthesizes:

```
Coordinator (Phase N)
  Step N.X: CLI Multi-CLI Dispatch (PARALLEL)
  +----------------+      +----------------+      +----------------+
  | Bash(bg=true)  |      | Bash(bg=true)  |      | Bash(bg=true)  |
  | dispatch-cli   |      | dispatch-cli   |      | dispatch-cli   |
  | --cli gemini   |      | --cli codex    |      | --cli opencode |
  | --role X       |      | --role X       |      | --role X       |
  +-------+--------+      +-------+--------+      +-------+--------+
          +----------+-----------+-----------+
                               v
  Step N.X+1: Synthesis (inline)
  - Unanimous (3 agree) -> VERY HIGH confidence
  - Majority (2 agree)  -> HIGH confidence
  - All disagree        -> FLAG for user decision
  - Unique (1 only)     -> VERIFY

  Step N.X+2: Self-Critique via Task subagent
  Task(general-purpose):
    ST CoVe: 3-5 verification Qs -> revise -> output
  -> Returns validated findings only

  WRITE to analysis/cli-{role}-report.md
```

### Why Multi-CLI?

- **Gemini** has 1M token context: excels at broad codebase exploration, pattern discovery, tech stack analysis
- **Codex** specializes in code: excels at import chain tracing, dependency verification, file-level analysis
- **OpenCode** brings UX/Product lens: excels at user flow analysis, accessibility assessment, product alignment
- **Unanimous findings** (all 3 agree) are very high-confidence — no further verification needed
- **Majority findings** (2 of 3 agree) are high-confidence — the dissenting view may surface a blind spot
- **Divergent findings** (all 3 disagree) surface complex trade-offs requiring human judgment

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
- **OpenCode**: No auto-approval flag needed (non-interactive mode auto-rejects permissions)

All CLI roles are **analysis-only** — they explore, read, and report. Role prompts explicitly forbid file modifications via the FORBIDDEN/Quality Requirements section. However, the auto-approval flags grant write access at the CLI level for Gemini and Codex. This is a known trade-off: unattended dispatch requires auto-approval, but the prompt-level restrictions prevent unintended writes under normal operation. OpenCode's non-interactive mode is inherently safe as it auto-rejects permission requests.

## Reduced-CLI Fallback

If not all CLIs are installed, the coordinator gracefully degrades:
- **2 CLIs available**: Dual-CLI mode — synthesis uses convergent/divergent/unique categories
- **1 CLI available**: Single-CLI mode — skips synthesis, marks output as `mode: single_{cli_name}`
- **0 CLIs available**: Skip CLI steps entirely
