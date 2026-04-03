# External CLI Agent Integration

Configure external CLI agents (Codex, Gemini) as independent evaluators and reviewers.
The harness sets up dispatch scripts and instruction files — it does NOT orchestrate
the agents at runtime. The user or Claude invokes them when needed.

## Why External Agents Matter

1. **Generator ≠ Evaluator** — The model that wrote the code should not be the sole judge.
   An external CLI agent (different model, different training) provides genuinely independent
   evaluation. This is the strongest form of the generator/evaluator split.

2. **Token distribution** — External CLI agents use their own subscriptions (Codex Pro,
   Gemini Pro), distributing the token load and cost across providers.

3. **Different perspectives** — Each model has different strengths: Codex excels at
   correctness/security review, Gemini at spec validation and pattern analysis.

## Detection

Check which CLI agents and plugins are available:

```bash
CODEX_AVAILABLE=$(command -v codex >/dev/null 2>&1 && echo true || echo false)
GEMINI_AVAILABLE=$(command -v gemini >/dev/null 2>&1 && echo true || echo false)

# Check if the OpenAI Codex Plugin for Claude Code is installed
# This provides /codex:review, /codex:adversarial-review, /codex:rescue, stop-gate
CODEX_PLUGIN=$(claude plugins list 2>/dev/null | grep -q "codex" && echo true || echo false)
```

Record results in `analysis.json` under `available_tools.cli_agents`. Include
`codex_plugin: true/false` — the plugin enables significantly richer integration.

---

## Codex Plugin (Preferred When Available)

If the OpenAI Codex Plugin (`codex-plugin-cc`) is installed, prefer its commands over
direct `codex exec` dispatch. The plugin provides persistent job tracking, structured
JSON output, adversarial review mode, and an optional automated evaluation gate — all
patterns that map directly onto the generator/evaluator harness.

### Why the Plugin is Better Than `codex exec`

| Aspect | `codex exec` (fallback) | Codex Plugin (`/codex:*`) |
|--------|------------------------|---------------------------|
| Job tracking | Ephemeral | Persistent IDs, status polling, result retrieval |
| Background execution | Manual | Built-in `--background` with `/codex:status` |
| Review output | Raw text | Structured JSON: verdict, findings[], severity, confidence |
| Adversarial mode | Not available | `/codex:adversarial-review` attacks assumptions |
| Thread resumption | Requires session ID | Auto-detects resumable threads |
| Stop gate | Not available | Automated review on every Claude stop |

### Review Commands

**Standard code review (after completing a feature):**
```
/codex:review --scope auto
```
Returns structured output: `verdict` (approve/needs-attention), `findings[]` with severity,
file paths, line numbers, confidence, and recommendations.

**Adversarial review (for thorough quality bar):**
```
/codex:adversarial-review --scope auto
```
Default skepticism — assumes failure until evidence proves otherwise. Attacks: auth/permissions,
data loss, race conditions, rollback safety, timeouts, version skew, schema drift. Only
reports material findings (not style, not speculative).

**Review against evaluation criteria:**
```
/codex:review --scope auto "Evaluate against criteria in .harness/eval-criteria.md. Grade each dimension 1-5."
```

### Rescue (Delegation to Codex)

For substantial debugging, investigation, or fix tasks — hand them to Codex instead of
doing everything in the Claude session:

```
/codex:rescue "Investigate why the login flow fails on token refresh. Check AuthRepository and TokenManager."
```

Key options:
- `--background` — run in background, check with `/codex:status`
- `--model spark` — use the faster Codex Spark model for simpler tasks
- `--effort high` — increase reasoning depth for complex problems
- `--resume` — continue a previous investigation thread

The rescue pattern is especially useful after an evaluation FAIL — hand the specific
failing criteria to Codex for independent debugging.

### Stop Gate — Automated Evaluation Hook

The most powerful integration: Codex automatically reviews every Claude response before
it's finalized. Enable it with:

```
/codex:setup --enable-review-gate
```

**How it works:**
1. Claude writes code and stops
2. Before the stop is accepted, the Codex stop-gate hook fires
3. Codex reviews Claude's changes and returns `ALLOW` or `BLOCK`
4. If `BLOCK`, Claude receives the feedback and must address the issues
5. This creates an automatic generator→evaluator loop within a single session

**When to configure the stop gate:**

| Quality Bar | Stop Gate |
|-------------|-----------|
| Fast iteration | Disabled — too much overhead |
| Balanced | Disabled by default; user enables for critical features |
| Thorough | Enabled — every code change gets adversarial review |

**Warning:** The stop gate can create long-running Claude/Codex loops and drain usage
limits. Only enable when actively monitoring the session or for critical features.
The harness should document this in the session-startup checklist as an opt-in step.

**Harness configuration:** When the stop gate is appropriate, add to `session-startup.md`:
```markdown
## Optional: Enable Codex stop gate for critical features
To get automatic adversarial review on every code change:
`/codex:setup --enable-review-gate`
Disable when done: `/codex:setup --disable-review-gate`
```

### Plugin Output Integration with Evaluation Reports

The plugin's structured JSON output maps directly to the evaluation report format:

```
Plugin output:          →  Evaluation report mapping:
verdict: "needs-attention"  →  Verdict: FAIL or REVISE
findings[].severity      →  Critical issues (critical/high) vs Advisory (medium/low)
findings[].file/line     →  Evidence location
findings[].recommendation →  Remediation guidance
findings[].confidence    →  Score calibration (high confidence = trust, low = verify)
```

When the plugin is available, the harness should note in `eval-criteria.md` that Codex
reviews produce structured findings that can be mapped to the per-criterion scores.

---

## Fallback: Direct CLI Invocation

When the Codex plugin is NOT installed, fall back to direct `codex exec` dispatch.
These patterns are also used by the review dispatch script (`.claude/scripts/external-review.sh`).

### Codex (via `codex exec`)

**Custom prompt (read-only, for review):**
```bash
echo "$PROMPT" | codex exec \
  --full-auto \
  --sandbox read-only \
  --ephemeral \
  -o "$OUTPUT_FILE" \
  -
```

Key flags:
- `--full-auto` — automatic execution without approval prompts
- `--sandbox read-only` — prevents any file modifications (safe for review)
- `--ephemeral` — don't persist session files to disk
- `-o $FILE` — write the agent's final message to a file (clean, no noise)
- `-` — read prompt from stdin

**Built-in code review (preferred for git-based reviews):**
```bash
codex exec review \
  --uncommitted \
  --full-auto \
  --ephemeral \
  -o "$OUTPUT_FILE" \
  "Additional instructions: evaluate against criteria in .harness/eval-criteria.md"
```

Review-specific flags:
- `--uncommitted` — review staged, unstaged, and untracked changes
- `--base <BRANCH>` — review changes against a base branch
- `--commit <SHA>` — review a specific commit
- `[PROMPT]` — custom review instructions (appended to built-in review prompt)

### Gemini

**Custom prompt (read-only, for review):**
```bash
gemini --approval-mode plan \
  -p "$PROMPT" \
  2>/dev/null \
  > "$OUTPUT_FILE"
```

Key flags:
- `--approval-mode plan` — read-only mode, no file modifications
- `-p "$PROMPT"` — non-interactive/headless mode
- `2>/dev/null` — **critical**: gemini outputs MCP initialization noise to stderr;
  without this redirect, the output file is polluted with hundreds of lines of
  "Registering notification handlers", "MCP context refresh", etc.

## What to Generate

### 1. Review Dispatch Script

Generate `.claude/scripts/external-review.sh`:

```bash
#!/bin/bash
# .claude/scripts/external-review.sh
# Dispatch code review to an external CLI agent
# Usage: external-review.sh <codex|gemini> [--uncommitted|--base BRANCH|files...]

set -euo pipefail

CLI="${1:?Usage: external-review.sh <codex|gemini> [--uncommitted|--base BRANCH|files...]}"
shift

FEATURE_DIR="{feature_dir}"
EVAL_CRITERIA="$FEATURE_DIR/.harness/eval-criteria.md"
REVIEW_OUTPUT="$FEATURE_DIR/.harness/last-review.md"
TIMEOUT=300  # 5 minutes

case "$CLI" in
  codex)
    if [ "${1:-}" = "--uncommitted" ] || [ "${1:-}" = "--base" ]; then
      # Use built-in code review (git-based)
      timeout "$TIMEOUT" codex exec review \
        "$@" \
        --full-auto \
        --ephemeral \
        -o "$REVIEW_OUTPUT" \
        "Evaluate against these criteria: $(cat "$EVAL_CRITERIA")" \
        || echo "[REVIEW TIMEOUT OR ERROR: exit $?]" >> "$REVIEW_OUTPUT"
    else
      # Custom file-based review
      PROMPT="You are reviewing code. Grade each dimension from 1-5 with evidence.

## Evaluation Criteria
$(cat "$EVAL_CRITERIA")

## Files to Review
$(for f in "$@"; do echo "### $f"; cat "$f" 2>/dev/null || echo "(not found)"; echo; done)

## Output Format
Per-dimension score (1-5) with evidence, then overall verdict: PASS or FAIL"

      echo "$PROMPT" | timeout "$TIMEOUT" codex exec \
        --full-auto \
        --sandbox read-only \
        --ephemeral \
        -o "$REVIEW_OUTPUT" \
        - \
        || echo "[REVIEW TIMEOUT OR ERROR: exit $?]" >> "$REVIEW_OUTPUT"
    fi
    ;;

  gemini)
    PROMPT="You are reviewing code. Grade each dimension from 1-5 with evidence.

## Evaluation Criteria
$(cat "$EVAL_CRITERIA")

## Files to Review
$(for f in "$@"; do echo "### $f"; cat "$f" 2>/dev/null || echo "(not found)"; echo; done)

## Output Format
Per-dimension score (1-5) with evidence, then overall verdict: PASS or FAIL"

    timeout "$TIMEOUT" gemini --approval-mode plan \
      -p "$PROMPT" \
      2>/dev/null \
      > "$REVIEW_OUTPUT" \
      || echo "[REVIEW TIMEOUT OR ERROR: exit $?]" >> "$REVIEW_OUTPUT"
    ;;

  *)
    echo "Unknown CLI: $CLI. Use 'codex' or 'gemini'."
    exit 1
    ;;
esac

echo "Review saved to: $REVIEW_OUTPUT"
echo "---"
cat "$REVIEW_OUTPUT"
```

### 2. CLI Instruction File (AGENTS.md / GEMINI.md)

If Codex or Gemini is available, generate a lean instruction file at the project root.
This file is read by the CLI agent when invoked in the project directory.

**AGENTS.md** (for Codex):

```markdown
# Project Instructions

## Overview
{1-2 sentence project description from plan.md}

## Architecture
See `docs/ARCHITECTURE.md` for system design.

## Build & Test
- Build: `{build_command}`
- Test: `{test_command}`
- Lint: `{lint_command}`

## Review Guidelines
When reviewing code, evaluate against the criteria in:
`{feature_dir}/.harness/eval-criteria.md`

Focus on: correctness, security, edge cases, and spec compliance.
Do not modify source code — only report findings.

## Conventions
{2-3 key conventions from CLAUDE.md}
```

**GEMINI.md** (for Gemini) — same structure, but note:
- Gemini has no MCP access — it relies on file reading only
- Gemini benefits from longer context — include more convention detail
- Gemini works well for spec validation and pattern consistency checks

### 3. Evaluation Criteria Update

When CLI agents are available, add this to `eval-criteria.md`:

```markdown
## External Review

Available CLI agents for independent evaluation:
- Codex: `.claude/scripts/external-review.sh codex --uncommitted`
- Gemini: `.claude/scripts/external-review.sh gemini src/changed-file.ts`

Recommended workflow:
1. Complete a feature (all acceptance criteria met, tests passing)
2. Run external review before marking `passes: true` in feature-list.json
3. Address any CRITICAL findings before proceeding
4. Advisory findings can be deferred to the next session
```

## Workflow Integration

### When to Use External Review

| Quality Bar | When to Review | Which CLI |
|------------|---------------|-----------|
| Fast iteration | End of each phase (batch review) | Either — whichever is faster |
| Balanced | After completing each feature | Alternate between Codex and Gemini |
| Thorough | After each feature + end of phase | Both — compare their findings |

## Configuration in analysis.json

```json
{
  "available_tools": {
    "cli_agents": {
      "codex": true,
      "gemini": true,
      "codex_plugin": true,
      "codex_version": "codex-cli 0.116.0",
      "gemini_version": "0.35.3"
    }
  },
  "harness_decisions": {
    "external_review": {
      "enabled": true,
      "strategy": "alternate",
      "frequency": "per_feature",
      "codex_method": "plugin",
      "stop_gate": false
    }
  }
}
```

## 3. UAT — Testing the Running Application

UAT evaluates the running application from a user's perspective. The harness configures
four mandatory layers — each adds coverage the others cannot provide.

| Layer | Tool | What It Tests | Mandatory |
|-------|------|---------------|-----------|
| **Scripted Regression** | Maestro | Repeatable E2E flows, smoke tests, regression gates | Yes — for mobile projects |
| **Native MCP** (primary) | Playwright / mobile-mcp | Real-time interaction, dynamic behavior, state transitions | Yes — interactive UAT |
| **Figma Visual Parity** | figma-console MCP | Layout, colors, spacing, component fidelity vs. design intent | Yes — for all UI projects |
| **CLI Evidence Review** (complement) | Codex / Gemini | Independent judgment on captured evidence | Yes — when CLI agents available |

**Execution order**: Scripted regression runs first (session-startup smoke gate, zero Claude
tokens). If it passes, native MCP evaluator tests interactively. Then Figma visual parity
checks design fidelity. Finally, CLI agents review captured evidence independently.

All four layers are mandatory when the corresponding tools are available. If a tool is
missing, the harness prompts the user to install it (Section 3a). The user may decline —
but the harness records the gap and adjusts coverage expectations accordingly.

---

### 3a. Tool Detection & Installation Prompting

During Stage 1b analysis, detect which UAT tools are available. Record results in
`analysis.json` under `available_tools.mcp_servers` alongside existing `cli_agents`.

**MCP server detection** — probe each server to confirm it responds:

```bash
# Playwright MCP — check if browser tools respond
# The evaluator prompt will use: browser_navigate, browser_click, browser_take_screenshot, etc.
PLAYWRIGHT_AVAILABLE=false
# Probe: call any lightweight Playwright tool. If the MCP server is registered and responds, it's available.
# In practice, detection happens inside the Claude session via tool probing, not bash.

# mobile-mcp — check for device availability
# The evaluator prompt will use: mobile_list_elements_on_screen, mobile_click_on_screen_at_coordinates, etc.
MOBILE_MCP_AVAILABLE=false

# figma-console MCP — check connection to Figma Desktop
# The evaluator prompt will use: figma_check_design_parity, figma_capture_screenshot, etc.
FIGMA_CONSOLE_AVAILABLE=false

# figma-desktop MCP — alternative Figma bridge
FIGMA_DESKTOP_AVAILABLE=false

# Maestro CLI — scripted E2E regression for mobile
MAESTRO_AVAILABLE=$(command -v maestro >/dev/null 2>&1 && echo true || echo false)
# Also check if Maestro MCP server is registered (provides maestro tools via MCP)
MAESTRO_MCP_AVAILABLE=false
```

**Detection procedure (inside Claude session):**

| Tool | Detection Method | Success Indicator |
|------|-----------------|-------------------|
| Playwright | Call `browser_snapshot` or check tool availability | Returns DOM tree or tool exists in MCP list |
| mobile-mcp | Call `mobile_list_available_devices` | Returns device list (may be empty — that's OK, server is running) |
| figma-console | Call `figma_get_status` | Returns `{ status: "connected", fileName: "..." }` |
| figma-desktop | Call `get_metadata` on current selection | Returns node metadata |
| Maestro CLI | `command -v maestro` | Returns path to maestro binary |
| Maestro MCP | Probe maestro MCP tools in MCP list | Maestro tools appear in available tools |

**When tools are missing — installation prompting:**

If a tool needed for the project's platform is not detected, the harness generates an
installation checklist in `session-startup.md`. The harness NEVER installs tools
automatically — it presents the checklist and asks the user.

```markdown
## Missing UAT Tools — Install to Enable Full Evaluation

The following tools would significantly improve evaluation quality for this project:

### Playwright MCP (for web UAT)
- [ ] Install: `npm install -g @anthropic/mcp-playwright` (or project-local)
- [ ] Add to `.mcp.json`:
  ```json
  { "playwright": { "command": "npx", "args": ["-y", "@anthropic/mcp-playwright"] } }
  ```
- [ ] Verify: restart Claude Code, confirm `browser_navigate` tool is available
- **Why:** Enables real-time browser interaction testing — click, type, navigate, screenshot.
  Without it, web UAT is limited to CLI evidence review (static screenshots, no interaction).

### mobile-mcp (for mobile UAT)
- [ ] Install: `npm install -g mobile-mcp`
- [ ] Add to `.mcp.json`:
  ```json
  { "mobile-mcp": { "command": "npx", "args": ["-y", "mobile-mcp"] } }
  ```
- [ ] Start an emulator/simulator or connect a physical device
- [ ] Verify: `mobile_list_available_devices` returns at least one device
- **Why:** Enables real-time mobile app testing with SAV loop (State-Action-Verify).
  Without it, mobile UAT falls back to CLI review of pre-captured screenshots.

### figma-console MCP (for visual parity)
- [ ] Install the Figma Desktop Bridge Plugin in Figma Desktop:
  Right-click canvas → Plugins → Manage plugins → search "Desktop Bridge"
- [ ] Add to `.mcp.json`:
  ```json
  { "figma-console": { "type": "http", "url": "http://127.0.0.1:3845/mcp" } }
  ```
- [ ] Open the target Figma file in Figma Desktop
- [ ] Verify: `figma_get_status` returns `{ status: "connected" }`
- **Why:** Enables automated visual parity checks — compare implementation screenshots
  against Figma designs using `figma_check_design_parity`. Without it, visual comparison
  is manual (exported PNGs) or skipped entirely.

### Maestro (for mobile scripted regression)
- [ ] Install: `curl -fsSL "https://get.maestro.mobile.dev" | bash`
- [ ] Add to PATH: `export PATH=$PATH:$HOME/.maestro/bin`
- [ ] Prerequisite: Java 17+ (`java -version` to check)
- [ ] For Android: ADB in PATH (`adb devices` to check), emulator or device connected
- [ ] For iOS (macOS only): Xcode with Command Line Tools (`xcode-select --install`),
  iOS Simulator running (`xcrun simctl list devices | grep Booted`)
- [ ] Verify: `maestro --version` returns version number
- [ ] Optional: `maestro mcp` starts a Maestro MCP server (add to `.mcp.json` if desired)
- **Why:** Enables repeatable E2E regression flows written in YAML. Runs autonomously
  (zero Claude tokens), produces JUnit XML reports, and serves as a session-startup
  smoke gate. Without it, regression testing requires a full Claude evaluator session.

> **Skip a tool?** All four UAT layers are mandatory when tools are available. If you
> choose not to install a tool, tell the configurator — it records the gap in
> `analysis.json → available_tools.user_declined` and flags reduced coverage in the
> evaluation report. The harness does NOT fall back silently — missing mandatory tools
> are surfaced as a coverage gap in every evaluation.
```

**Configuration in analysis.json:**

```json
{
  "available_tools": {
    "mcp_servers": {
      "playwright": true,
      "mobile_mcp": false,
      "figma_console": true,
      "figma_desktop": true
    },
    "cli_tools": {
      "maestro": true,
      "maestro_version": "1.37.x",
      "maestro_mcp": false
    },
    "cli_agents": {
      "codex": true,
      "gemini": true,
      "codex_plugin": true
    },
    "install_prompted": ["mobile_mcp"],
    "user_declined": []
  }
}
```

---

### 3b. Native MCP UAT (PRIMARY)

Native MCP tools are the primary UAT method because they can **interact with the running
application in real time** — clicking, typing, navigating, verifying state changes. CLI
agents can only review static evidence captured beforehand.

**Platform tool mapping:**

| Platform | Primary Tool | Interact | Observe | Query |
|----------|-------------|----------|---------|-------|
| Web | Playwright MCP | `browser_click`, `browser_fill_form`, `browser_navigate`, `browser_type` | `browser_take_screenshot`, `browser_snapshot` | `browser_evaluate`, `browser_network_requests` |
| Mobile | mobile-mcp | `mobile_click_on_screen_at_coordinates`, `mobile_type_keys`, `mobile_swipe_on_screen` | `mobile_take_screenshot`, `mobile_list_elements_on_screen` | `mobile_open_url` (deep links) |

See `evaluation-loop.md` Section 2a (web) and 2b (mobile) for detailed tool usage per
evaluation step (INTERACT → OBSERVE → QUERY → GRADE → FEEDBACK).

**Evaluator prompt addition for native UAT:**

When native MCP tools are available, add this block to `.harness/evaluator-prompt.md`:

```markdown
## UAT Tools — Native MCP

You have direct access to the running application via MCP tools:

### Web (Playwright)
- Navigate: `browser_navigate` to any URL
- Interact: `browser_click`, `browser_fill_form`, `browser_type`, `browser_select_option`
- Observe: `browser_take_screenshot` (visual), `browser_snapshot` (DOM accessibility tree)
- Query: `browser_evaluate` (run JS in page), `browser_network_requests` (inspect API calls)
- Advanced: `browser_hover`, `browser_drag`, `browser_file_upload`, `browser_press_key`

### Mobile (mobile-mcp)
- Setup: `mobile_list_available_devices` → `mobile_use_device` → `mobile_install_app` → `mobile_launch_app`
- SAV Loop (MANDATORY for every interaction):
  1. STATE: `mobile_list_elements_on_screen` — get UI hierarchy with coordinates
  2. ACTION: One interaction (tap, type, swipe) — calculate center from element bounds
  3. VERIFY: Wait 2-3s, re-query `mobile_list_elements_on_screen`, confirm expected change
- NEVER chain multiple interactions without verification — coordinates shift between screens
- NEVER cache element coordinates — re-query before every tap

### Evidence Capture
Save screenshots to `.harness/eval-evidence/` with descriptive names:
- `{criterion-name}-{state}.png` (e.g., `login-form-validation-error.png`)
- Capture BEFORE and AFTER state changes for comparison
```

**Advantages over CLI-only UAT:**

| Capability | Native MCP | CLI Evidence Review |
|-----------|-----------|-------------------|
| Real-time interaction | Yes — click, type, navigate live | No — reviews pre-captured screenshots |
| Dynamic behavior testing | Yes — state transitions, animations, loading states | No — only sees static snapshots |
| Error state discovery | Yes — can trigger edge cases interactively | Limited — only sees what was captured |
| API verification | Yes — `browser_evaluate`, `browser_network_requests` | No — code review only |
| SAV loop (mobile) | Yes — verify every interaction | No — sequential screenshot review |
| Retry on failure | Yes — re-attempt with different approach | No — single-pass judgment |

---

### 3c. Figma Visual Parity

When figma-console or figma-desktop MCP is available, the harness configures automated
visual parity checks that compare the running implementation against the original Figma
design. This is a cross-platform layer — it works for both web and mobile projects.

**Tool hierarchy** (use the highest available level):

| Level | Tool | What It Does | Accuracy |
|-------|------|-------------|----------|
| 1 | `figma_check_design_parity` | Automated scoring with structured diff output | Highest — built-in comparison engine |
| 2 | `figma_capture_screenshot` + evaluator comparison | Capture Figma state, evaluator compares side-by-side | High — live Figma state, LLM judgment |
| 3 | `figma_take_screenshot` + evaluator comparison | Cloud-cached screenshot (may be stale) | Medium — may not reflect latest edits |
| 4 | Pre-exported PNG from Figma | Static reference images exported before UAT | Low — no guarantee of freshness |
| 5 | Skip visual parity | No Figma tools available | None |

**Prerequisites:**

1. Figma Desktop app running with the target design file open
2. figma-console or figma-desktop MCP connected (`figma_get_status` returns `connected`)
3. Screen-to-frame mapping configured in `analysis.json` (see below)

**Projects without Figma designs:**

Visual parity is mandatory for UI projects, but not all projects use Figma. If designs
live in Sketch, Adobe XD, or no design tool at all, the harness handles this explicitly:

1. During Stage 1c interview, ask if Figma designs are available
2. If no: set `visual_parity.enabled: false` with `reason: "no_figma_designs"` in analysis.json
3. Record as a coverage gap in `session-startup.md` and every evaluation report
4. The evaluator still runs functional UAT (layers 1-2) and CLI review (layer 4) — only
   layer 3 (visual parity) is skipped
5. If designs exist in another tool, note in `analysis.json → visual_parity.alternative_tool`
   and recommend manual screenshot comparison as a workaround (Level 4 in tool hierarchy)

This is NOT a silent fallback — every evaluation report will show "Visual Parity: SKIPPED
(no Figma designs available)" to maintain visibility of the gap.

**Screen-to-frame mapping:**

The harness must know which Figma frame corresponds to which application screen. Configure
this during Stage 2c by inspecting the Figma file:

```bash
# Use figma_get_status to confirm connection, then explore the file structure
# Use figma_search_components or navigate to identify frame node IDs
```

Record the mapping in `analysis.json`:

```json
{
  "harness_decisions": {
    "visual_parity": {
      "enabled": true,
      "method": "figma_check_design_parity",
      "fallback": "figma_capture_screenshot",
      "parity_threshold": 80,
      "figma_file_key": "abc123XYZ",
      "screen_to_frame_map": {
        "login": "1234:5678",
        "dashboard": "1234:9012",
        "settings": "1234:3456",
        "profile": "1234:7890"
      }
    }
  }
}
```

**Visual parity procedure:**

For each screen under test, the evaluator follows this sequence:

```
1. NAVIGATE to the app screen (via Playwright or mobile-mcp)
2. CAPTURE implementation screenshot → .harness/eval-evidence/{screen}-impl.png
3. FETCH Figma reference:
   a. figma_navigate(nodeId) → navigate to the corresponding Figma frame
   b. figma_capture_screenshot → .harness/eval-evidence/{screen}-figma.png
      (use figma_capture_screenshot, NOT figma_take_screenshot — capture reflects
      live Figma state, take uses cloud cache which may be stale)
4. COMPARE:
   a. If figma_check_design_parity is available:
      Call it with the implementation screenshot and Figma frame reference.
      It returns a structured diff with: overall_score, mismatches[], severity per mismatch.
   b. If only figma_capture_screenshot:
      Evaluator compares the two screenshots visually and scores:
      - Layout fidelity (element positions, sizes, alignment)
      - Color accuracy (backgrounds, text, borders, shadows)
      - Typography (font size, weight, line height, letter spacing)
      - Spacing (padding, margins, gaps between elements)
      - Component fidelity (icons, buttons, inputs match design)
5. GRADE: Score 1-5 per dimension. Overall visual parity score.
   - 5: Pixel-perfect match
   - 4: Minor differences (1-2px alignment, subtle color shift)
   - 3: Noticeable differences but functionally correct
   - 2: Significant visual deviations
   - 1: Does not resemble the design
6. REPORT: Write findings to evaluation report with screenshot paths as evidence
```

**Design token verification (bonus when figma-console available):**

Beyond visual comparison, the evaluator can verify that implementation uses correct
design tokens by querying the Figma design system:

```markdown
## Design Token Checks (add to evaluator prompt when figma-console available)

After visual comparison, verify token usage:
1. Call `figma_get_variables` — get all design tokens (colors, spacing, typography)
2. Call `figma_get_styles` — get shared styles
3. Compare against implementation CSS/styles:
   - Are the correct color tokens used? (not hardcoded hex values)
   - Do spacing values match the 4px scale from the design system?
   - Are typography styles consistent with Figma text styles?
4. Flag any hardcoded values that should use tokens
```

**Evaluator prompt addition for Figma visual parity:**

```markdown
## Visual Parity — Figma Comparison

For each UI screen you test, also verify visual fidelity against the Figma design:

### Screen-to-Frame Map
{paste screen_to_frame_map from analysis.json}

### Procedure
1. After testing a screen functionally, capture an implementation screenshot
2. Navigate to the corresponding Figma frame: `figma_navigate({nodeId})`
3. Capture the Figma reference: `figma_capture_screenshot` (NOT figma_take_screenshot)
4. Compare implementation vs. design across 5 dimensions:
   - Layout fidelity | Color accuracy | Typography | Spacing | Component fidelity
5. Score each dimension 1-5. Overall parity threshold: {parity_threshold}%
6. Report mismatches with both screenshot paths as evidence

### Scoring
- MATCH (4-5): Implementation faithfully represents the design
- MINOR (3): Noticeable but acceptable differences — log as advisory
- MAJOR (1-2): Significant deviations — log as critical finding
```

**Anti-patterns:**

- **Never use `figma_take_screenshot` for comparison** — it returns cloud-cached images
  that may not reflect the latest design edits. Always use `figma_capture_screenshot`
  which captures the live Figma state.
- **Always call `figma_get_status` first** — if Figma Desktop is not running or the
  file is closed, all figma tools will fail silently or error. Check connection before
  attempting visual parity.
- **Visual parity failures are blocking** — any screen scoring below the parity threshold
  (default 80%) must be addressed before marking `passes: true`. Visual differences that
  are intentional (responsive adaptations, platform-specific conventions) should be
  documented in the sprint contract as accepted deviations.

---

### 3d. CLI Evidence Review (Complement)

When native MCP tools handle interactive UAT, CLI agents (Codex/Gemini) serve as an
independent second opinion — reviewing the same evidence from a different model's
perspective. This complements native UAT rather than replacing it.

**Workflow:**

```
Native UAT captures evidence → .harness/eval-evidence/
                                       ↓
CLI agent reviews evidence → .harness/eval-reports/cli-uat-{date}.md
                                       ↓
Coder reads BOTH native + CLI reports, addresses findings
```

**CLI UAT dispatch script:**

The harness generates `.claude/scripts/uat-dispatch.sh` for dispatching evidence to CLI
agents. The script is unchanged from previous versions — CLI agents still receive
pre-captured screenshots and sprint contract criteria:

```bash
#!/bin/bash
# .claude/scripts/uat-dispatch.sh
# Dispatch evidence review to an external CLI agent (complement to native MCP UAT)
# Usage: uat-dispatch.sh <codex|gemini> <evidence-dir>
#
# Expects: evidence-dir contains screenshots/snapshots captured by native UAT

set -euo pipefail

CLI="${1:?Usage: uat-dispatch.sh <codex|gemini> <evidence-dir>}"
EVIDENCE_DIR="${2:?Provide evidence directory with screenshots/snapshots}"

FEATURE_DIR="{feature_dir}"
EVAL_CRITERIA="$FEATURE_DIR/.harness/eval-criteria.md"
SPRINT_CONTRACT="$FEATURE_DIR/.harness/sprint-contract.md"
REPORT_DIR="$FEATURE_DIR/.harness/eval-reports"
mkdir -p "$REPORT_DIR"
UAT_REPORT="$REPORT_DIR/cli-uat-$(date +%Y-%m-%d-%H%M).md"
TIMEOUT=600  # 10 minutes

EVIDENCE_LISTING=$(ls -1 "$EVIDENCE_DIR" 2>/dev/null | head -20)

PROMPT="You are an independent UAT evaluator providing a second opinion on evidence
captured from a running application. A native evaluator has already tested the app
interactively — your role is to review the captured evidence with fresh eyes.

## Your Role
- Judge from a USER's perspective, not a developer's
- Be skeptical: the coder AND the native evaluator may have missed issues
- Focus on what you can see in the evidence: layout, data, visual consistency
- Score each criterion 1-5 with specific evidence references
- Any blocking criterion below threshold = FAIL verdict

## Sprint Contract
$(cat "$SPRINT_CONTRACT" 2>/dev/null || echo "No sprint contract found")

## Evaluation Criteria
$(cat "$EVAL_CRITERIA")

## Evidence Files
$EVIDENCE_LISTING

## What to Look For
- Missing UI elements visible in the criteria but absent from screenshots
- Incorrect data or placeholder text that should be real content
- Broken layouts, overlapping elements, truncated text
- Inconsistent styling across screens
- Missing states (loading, error, empty) if screenshots should show them
- Accessibility concerns visible in the evidence (contrast, touch targets)

## Output Format
1. Per-criterion score (1-5) with evidence file reference
2. Critical issues (must fix)
3. Advisory issues (fix when convenient)
4. Comparison note: anything the native evaluator might have missed
5. Overall verdict: PASS | FAIL | PARTIAL"

case "$CLI" in
  codex)
    echo "$PROMPT" | timeout "$TIMEOUT" codex exec \
      --full-auto \
      --sandbox read-only \
      --ephemeral \
      -o "$UAT_REPORT" \
      - \
      || echo "[UAT EVALUATION TIMEOUT OR ERROR: exit $?]" >> "$UAT_REPORT"
    ;;

  gemini)
    timeout "$TIMEOUT" gemini --approval-mode plan \
      -p "$PROMPT" \
      2>/dev/null \
      > "$UAT_REPORT" \
      || echo "[UAT EVALUATION TIMEOUT OR ERROR: exit $?]" >> "$UAT_REPORT"
    ;;

  *)
    echo "Unknown CLI: $CLI. Use 'codex' or 'gemini'."
    exit 1
    ;;
esac

echo "UAT evidence review saved to: $UAT_REPORT"
cp "$UAT_REPORT" "$REPORT_DIR/latest-cli-uat.md" 2>/dev/null || true
echo "---"
cat "$UAT_REPORT"
```

**When to use CLI evidence review:**

| Scenario | Use CLI Review? | Why |
|----------|----------------|-----|
| Native UAT available, balanced quality | End of phase (batch) | Independent second opinion without per-feature overhead |
| Native UAT available, thorough quality | After each feature | Maximum coverage — different model catches different things |
| No native MCP tools | After each feature | Only UAT method available — primary, not complement |
| Figma parity evidence captured | Include in evidence dir | CLI agent also reviews visual comparison screenshots |

---

### 3e. Maestro Scripted Regression (Mobile)

Maestro provides repeatable, scripted E2E testing for mobile apps using YAML flow files.
Unlike mobile-mcp (which Claude drives interactively), Maestro runs autonomously — zero
Claude tokens consumed. This makes it ideal for regression gates and smoke tests.

**Why Maestro alongside mobile-mcp:**

| Aspect | mobile-mcp (Interactive) | Maestro (Scripted) |
|--------|-------------------------|-------------------|
| Driven by | Claude evaluator in real-time | CLI executing YAML flows |
| Token cost | Full evaluator session | Zero — runs outside Claude |
| Best for | Exploratory testing, edge case discovery | Regression, smoke gates, CI |
| Flakiness | Manual retry (SAV loop) | Built-in auto-wait + retry |
| Output | Claude-written report | JUnit XML + named screenshots |
| Repeatability | Different each run (LLM variability) | Deterministic — same flow, same result |

**Flow YAML generation:**

The harness generates Maestro flows from sprint contract criteria during Stage 2c. Each
testable criterion becomes a flow file:

```yaml
# .maestro/flows/smoke/login-flow.yaml
appId: ${APP_ID}
name: "Login Flow — Smoke"
tags:
  - smoke
  - login

- launchApp:
    clearState: true

- tapOn: "Username"
- inputText: ${TEST_USERNAME}

- tapOn:
    id: "password_field"
- inputText: ${TEST_PASSWORD}

- hideKeyboard
- tapOn: "Login"

- assertVisible: "Welcome"
- takeScreenshot: "login-success"
```

**Cross-platform flows (Android + iOS):**

Use `appId: ${APP_ID}` in all flows and inject per-platform at runtime:
- Android: `maestro test -e APP_ID=com.example.app .maestro/` (package name)
- iOS: `maestro test -e APP_ID=com.example.App .maestro/` (bundle identifier)

A single YAML flow works on both platforms — Maestro is architecture-agnostic. Note: iOS
testing requires macOS with Xcode + iOS Simulator. Real iOS device testing is NOT officially
supported by Maestro CLI (use Maestro Cloud or device farms for real devices).

**Workspace config:**

Generate `.maestro/config.yaml` at the project root:

```yaml
# .maestro/config.yaml
flows:
  - ./flows/smoke/      # Session-startup regression gate
  - ./flows/features/   # Per-feature E2E flows
env:
  APP_ID: com.example.app
  TEST_USERNAME: ${MAESTRO_TEST_USERNAME}    # inject via shell: export MAESTRO_TEST_USERNAME=...
  TEST_PASSWORD: ${MAESTRO_TEST_PASSWORD}    # inject via shell: export MAESTRO_TEST_PASSWORD=...
```

**Invocation patterns:**

```bash
# Session-startup smoke gate (fast, <30s)
maestro test --include-tags=smoke --output .harness/eval-reports/maestro-smoke.xml .maestro/

# Post-feature regression (all flows for completed features)
maestro test --output .harness/eval-reports/maestro-regression.xml .maestro/

# Full suite with artifacts
maestro test --output .harness/eval-reports/maestro-full.xml \
  --test-output-dir .harness/eval-evidence/maestro/ \
  .maestro/

# Record video evidence
maestro record .maestro/flows/features/checkout-flow.yaml
```

**JUnit XML parsing for evaluation reports:**

Maestro produces standard JUnit XML (`report.xml`). The harness adds parsing instructions
to the evaluator prompt and session-startup checklist:

```markdown
## Maestro Regression Results

After running `maestro test`, check the JUnit XML report:
- If ALL tests pass: proceed to interactive UAT
- If ANY test fails: fix the regression BEFORE new work
  - Read the failure details in the XML report
  - Check screenshots in `--test-output-dir` for visual context
  - The failing flow YAML shows the exact steps that broke
```

**Flow accumulation pattern:**

As features are completed and pass interactive UAT, their Maestro flows become permanent
regression tests:

```
Feature 1 implemented → login-flow.yaml passes → added to smoke/
Feature 2 implemented → dashboard-flow.yaml passes → added to features/
Feature 3 implemented → checkout-flow.yaml passes → added to features/
...
Session N startup: maestro test --include-tags=smoke runs all accumulated flows
```

This means regression coverage grows organically with every completed feature — no manual
test writing needed after the harness generates the initial flows.

**Flow maintenance when sprint criteria change:**

When sprint contract criteria are renegotiated between sprints (evaluator feedback, scope
changes), the corresponding Maestro flows may become stale. The harness handles this:

1. **Detect stale flows** — when writing a new sprint contract, compare its criteria against
   existing flow files in `.maestro/flows/`. If a criterion changed, flag the flow for update.
2. **Regenerate, don't patch** — delete the stale flow YAML and regenerate from the updated
   criterion. Maestro flows are cheap to generate; patching risks drift.
3. **Preserve passing flows** — flows for criteria that did NOT change stay in the suite.
   Only stale flows are regenerated.
4. **Re-run smoke suite** — after regenerating, run `maestro test --include-tags=smoke` to
   confirm the updated flows pass on the current implementation.

**Maestro MCP integration:**

If `maestro mcp` is registered as an MCP server, Maestro tools become available directly
in Claude Code sessions. This enables hybrid workflows where Claude can invoke Maestro
flows programmatically during evaluation, check results, and combine with interactive
mobile-mcp testing in the same session.

**Configuration in analysis.json:**

```json
{
  "harness_decisions": {
    "maestro": {
      "enabled": true,
      "flows_dir": ".maestro/flows/",
      "config_path": ".maestro/config.yaml",
      "smoke_tags": ["smoke"],
      "report_output": ".harness/eval-reports/maestro-smoke.xml",
      "evidence_dir": ".harness/eval-evidence/maestro/",
      "app_id": "com.example.app",
      "session_startup_gate": true
    }
  }
}
```

**Anti-patterns:**

- **Don't use Maestro for exploratory testing** — its YAML DSL is deterministic; it
  can't discover unexpected edge cases. Use mobile-mcp for exploration, Maestro for
  regression.
- **Don't skip the smoke gate on session startup** — if Maestro flows exist, run them.
  A broken regression found at session-startup costs nothing; the same regression found
  after 2 hours of coding costs an entire session.
- **Don't hardcode app credentials in flow YAML** — use `env:` variables and inject
  via `-e` flags or `config.yaml`. The harness generates env placeholders, not real values.
- **JVM cold-start is ~10s** — acceptable for regression gates, not for tight loops.
  Run smoke suite once at startup, not after every file save.

### Workflow Integration — All Four Layers

| Quality Bar | Maestro Regression | Native MCP UAT | Figma Visual Parity | CLI Evidence Review |
|------------|-------------------|---------------|--------------------|--------------------|
| Fast iteration | Session startup smoke | After each feature | After each UI feature | Code review only (Section 2) |
| Balanced | Session startup + post-feature | After each feature | After each UI feature | End of phase (batch) |
| Thorough | Session startup + post-feature + full suite | After each feature | After each UI feature + token verification | After each feature |

**Harness configuration in analysis.json:**

```json
{
  "harness_decisions": {
    "uat_strategy": {
      "primary": "native_mcp",
      "scripted_regression": "maestro",
      "complement": "cli_evidence_review",
      "native_tool": "playwright",
      "cli_tool": "codex"
    }
  }
}
```

For the full `visual_parity` schema (including `screen_to_frame_map`, `figma_file_key`,
`parity_threshold`), see Section 3c above — that is the canonical definition.

---

## analysis.json — Complete Schema Composition

The `analysis.json` file is assembled from fragments defined across this file. Here are
all top-level keys and their canonical source:

| Top-Level Key | Canonical Location | Purpose |
|---------------|-------------------|---------|
| `available_tools.mcp_servers` | Section 3a (this file) | Playwright, mobile-mcp, figma-console, figma-desktop detection |
| `available_tools.cli_tools` | Section 3a (this file) | Maestro CLI + MCP detection |
| `available_tools.cli_agents` | Section 2 (this file) | Codex, Gemini, Codex Plugin detection |
| `available_tools.install_prompted` | Section 3a (this file) | Tools the harness prompted to install |
| `available_tools.user_declined` | Section 3a (this file) | Tools the user chose not to install |
| `harness_decisions.external_review` | Section 2 (this file) | Review strategy, frequency, method |
| `harness_decisions.uat_strategy` | Section 3d (this file) | Primary/complement/scripted tools |
| `harness_decisions.visual_parity` | **Section 3c** (this file) | Method, fallback, threshold, screen-to-frame map |
| `harness_decisions.maestro` | **Section 3e** (this file) | Flows dir, smoke tags, app ID, startup gate |
| `evaluation_loop` | `evaluation-loop.md` Section 7 | Platform, evaluator type, tools, criteria |

**Composition rule**: The configurator merges all fragments into a single `analysis.json`.
Each key above is defined in exactly one canonical location. Other files may show partial
examples for context but always cross-reference the canonical source. When in doubt,
the canonical location listed here is authoritative.

---

## Robustness Notes

- **Codex output is clean** — `-o file` writes only the agent's final message
- **Gemini stderr is noisy** — always use `2>/dev/null` to strip MCP init logs
- **Timeout**: 5 minutes for code review, 10 minutes for UAT evaluation
- **Not blocking** — external review is advisory; append error note on failure
- **Figma connection** — always call `figma_get_status` before visual parity. If the
  connection drops mid-evaluation, fall back to the next level in the tool hierarchy
- **Native MCP fallback** — if Playwright or mobile-mcp fails during evaluation, the
  evaluator captures whatever evidence it can and falls back to CLI evidence review
- **No retry/parsing infrastructure** — the harness keeps it simple; if complex
  retry logic or 4-tier parsing is needed, that belongs in an orchestrator layer
