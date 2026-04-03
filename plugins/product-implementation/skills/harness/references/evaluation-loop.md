# Evaluation Loop — Testing, Judging, and Feedback

Configure an evaluation loop where a separate agent tests the running application as a user
would, judges the coder's output against gradable criteria, and routes structured feedback
back for the next coding session. Read only the section relevant to what you're configuring.

---

## 1. The Evaluation Interface

Every evaluation — regardless of platform, tool, or agent type — follows five steps.
The harness configures each step; the evaluator executes them at runtime.

```
INTERACT  →  OBSERVE  →  QUERY  →  GRADE  →  FEEDBACK
   ↑                                            |
   └────────────── next round ──────────────────┘
```

| Step | What the Evaluator Does | What the Harness Configures |
|------|------------------------|----------------------------|
| **Interact** | Performs user actions on the running app (click, type, navigate, swipe) | Which tools to use, how to launch the app |
| **Observe** | Captures state after interaction (screenshots, DOM/view trees, logs) | Evidence directory, screenshot naming, what to capture |
| **Query** | Checks data beyond UI (API responses, database state, metrics) | Which endpoints to hit, what data to verify |
| **Grade** | Scores each criterion 1-5 with evidence | Criteria definitions, thresholds, rubric |
| **Feedback** | Writes structured report for the coder | Report format, file location, severity levels |

This interface is platform-agnostic. The evaluator uses different tools per platform but
the loop is identical.

## 2. Platform Tool Mapping

Read ONLY the subsection matching your platform (from analysis.json). Skip all others to
save context.

### 2a. Web Applications

**Primary tool:** Playwright MCP (preferred) or Chrome DevTools MCP

| Step | Tool | Example |
|------|------|---------|
| Interact | `playwright.browser_click`, `browser_fill_form`, `browser_navigate` | Navigate to /dashboard, fill login form, click submit |
| Observe | `playwright.browser_take_screenshot`, `browser_snapshot` | Screenshot after login, DOM snapshot of dashboard |
| Query | `playwright.browser_evaluate`, `browser_network_requests` | `fetch('/api/user').then(r => r.json())`, check network tab |
| Grade | Evaluator prompt logic | Score "Login Flow" criterion: 4/5, form works but no loading state |
| Feedback | File write to `.harness/eval-reports/` | Structured per-criterion report |

**App launch:** The harness generates a script that starts the dev server and waits for it
to be ready (e.g., `npm run dev` then poll `http://localhost:3000` until 200).

**Known limitations:**
- Cannot see browser-native `alert()` / `confirm()` / `prompt()` modals — avoid features
  that rely on them, or test those manually
- Subtle visual issues (1px alignment, font rendering) are hard to catch via screenshots
- Audio/video playback cannot be verified programmatically

### 2b. Mobile Applications

**Primary tool:** mobile-mcp

| Step | Tool | Example |
|------|------|---------|
| Interact | `mobile_click_on_screen_at_coordinates`, `mobile_type_keys`, `mobile_swipe_on_screen` | Tap login button, enter credentials, swipe to next screen |
| Observe | `mobile_take_screenshot`, `mobile_list_elements_on_screen` | Screenshot of home screen, UI hierarchy of settings page |
| Query | `mobile_open_url` (deep links), app logs via ADB/Xcode | Open `myapp://profile/123`, read logcat output |
| Grade | Evaluator prompt logic | Score "Navigation" criterion: 3/5, back button doesn't return to correct screen |
| Feedback | File write to `.harness/eval-reports/` | Structured report with screenshot evidence paths |

**App launch:** Clean install cycle — `mobile_uninstall_app` → `mobile_install_app` →
`mobile_launch_app`. Guarantees fresh state for each evaluation round.

**SAV Loop (State-Action-Verify):** For every interaction, the evaluator must:
1. Query current UI state (`mobile_list_elements_on_screen`)
2. Perform one action
3. Re-query to verify the expected change occurred

Never chain multiple interactions without verification — coordinates shift between screens.

**Maestro scripted regression:** Before interactive UAT, run Maestro smoke flows as a
regression gate (`maestro test --include-tags=smoke`). This catches regressions at zero
Claude token cost. See `cli-agents.md` Section 3e for flow generation and invocation, and
Section 2f below for the scripted regression evaluation interface.

### 2c. Desktop Applications

**Primary tool:** Accessibility APIs or OS-level automation (project-specific)

| Step | Tool | Example |
|------|------|---------|
| Interact | OS accessibility API, AppleScript, xdotool | Click menu item, type in text field, press keyboard shortcut |
| Observe | Screenshot capture, accessibility tree dump | Window screenshot, read element hierarchy |
| Query | IPC, local sockets, config files, logs | Check settings file after preference change |
| Grade | Evaluator prompt logic | Score criterion with evidence |
| Feedback | File write to `.harness/eval-reports/` | Structured report |

Desktop automation is project-specific. The harness generates a placeholder launch script
and notes the tooling gap — the user fills in platform-specific details.

### 2d. API-Only / Headless

For backends without UI, the evaluation loop uses HTTP requests instead of interaction tools:

| Step | Tool | Example |
|------|------|---------|
| Interact | `curl`, `httpie`, or code-based HTTP calls | `POST /api/auth/login`, `GET /api/users/1` |
| Observe | Response body, status codes, headers | 200 OK, response matches schema |
| Query | Database queries, log files, metrics | Check user record was created in DB |
| Grade | Evaluator prompt logic | Score "API Correctness": 5/5, all endpoints match OpenAPI spec |
| Feedback | File write to `.harness/eval-reports/` | Structured report |

### 2e. Figma Visual Parity (Cross-Platform)

**Primary tool:** figma-console MCP (preferred) or figma-desktop MCP

Visual parity is a cross-platform evaluation layer — it applies to both web and mobile
projects. It compares the running implementation against the original Figma designs to
verify that what was built matches what was designed.

**Prerequisites:**
- Figma Desktop app running with the target design file open
- figma-console MCP connected (`figma_get_status` returns `{ status: "connected" }`)
- Screen-to-frame mapping in `analysis.json` (maps app screens to Figma node IDs)

| Step | Tool | Example |
|------|------|---------|
| Interact | Platform-specific (Playwright or mobile-mcp) — navigate to target screen | Navigate to /dashboard, wait for load |
| Observe | `browser_take_screenshot` or `mobile_take_screenshot` — capture implementation | Save to `.harness/eval-evidence/dashboard-impl.png` |
| Query | `figma_navigate(nodeId)` → `figma_capture_screenshot` — fetch design reference | Save to `.harness/eval-evidence/dashboard-figma.png` |
| Grade | `figma_check_design_parity` (automated) or evaluator visual comparison (manual) | Score 5 dimensions: layout, color, typography, spacing, component fidelity |
| Feedback | File write to `.harness/eval-reports/` | Per-screen parity scores with both screenshot paths |

Visual parity uses a 5-level tool fallback chain (from `figma_check_design_parity` down to
skip) and optionally includes design token verification via `figma_get_variables`. Findings
are mandatory for all UI projects — any screen scoring below the parity threshold blocks
the feature from being marked as passed.

**Critical rule:** Always use `figma_capture_screenshot` (live state), NOT
`figma_take_screenshot` (cloud cache) for comparison.

See `cli-agents.md` Section 3c for the full procedure: tool fallback chain, screen-to-frame
mapping, design token verification, evaluator prompt additions, and anti-patterns.

### 2f. Maestro Scripted Regression (Mobile)

**Primary tool:** Maestro CLI

Maestro provides a scripted regression layer that runs outside Claude — zero token cost.
YAML flow files define repeatable E2E scenarios. The harness generates flows from sprint
contract criteria and accumulates them as features are completed.

| Step | Tool | Example |
|------|------|---------|
| Interact | Maestro YAML commands: `tapOn`, `inputText`, `swipe`, `scroll` | `- tapOn: "Login"`, `- inputText: ${USERNAME}` |
| Observe | `takeScreenshot`, `assertVisible`, `assertNotVisible` | `- assertVisible: "Welcome"`, `- takeScreenshot: "post-login"` |
| Query | `evalScript` (JavaScript), `assertScreenshot` | Check dynamic content, visual snapshot comparison |
| Grade | JUnit XML report (pass/fail per flow) | `report.xml` with test results parseable by CI and evaluator |
| Feedback | Report file + screenshots in `--test-output-dir` | `.harness/eval-reports/maestro-smoke.xml` |

**When Maestro runs:**
- **Session startup** — smoke flows as regression gate (before any new work)
- **Post-feature** — feature-specific flow after implementation completes
- **Pre-evaluation** — full suite before interactive UAT (catches regressions so Claude
  evaluator doesn't waste tokens on broken basics)

**Key difference from mobile-mcp:** Maestro is deterministic (same YAML, same result).
mobile-mcp is exploratory (Claude drives, different each run). Use both: Maestro for
regression certainty, mobile-mcp for interactive discovery.

See `cli-agents.md` Section 3e for flow generation, invocation patterns, accumulation
strategy, and Maestro MCP integration.

---

## 3. Sprint Contract Negotiation

Before each sprint, the coder and evaluator agree on what "done" looks like. The sprint
contract transforms vague "it works" claims into testable, gradable criteria. Without it,
the evaluator has no objective basis for scoring — it would fall back to subjective
impressions, which defeats the purpose of automated evaluation.

See `harness-components.md` Section 2f for the unified sprint contract template.

### Protocol

1. **Coder writes contract proposal** → `.harness/sprint-contract.md`
   - Which feature(s) from `feature-list.json` will be implemented
   - Proposed acceptance verification: how each criterion will be tested
   - Out-of-scope items for this sprint

2. **Evaluator reviews contract** → `.harness/contract-review.md`
   - Are criteria concrete and testable? (not "looks good" but "login form submits and redirects to /dashboard within 2s")
   - Are any criteria missing? (edge cases, error states, accessibility)
   - Are criteria realistic for one sprint?

3. **Iterate until agreement** — coder revises, evaluator re-reviews. Max 2 rounds.
   If no agreement after 2 rounds, proceed with evaluator's version (bias toward rigor).

The key insight: vague criteria like "user can log in" become concrete verifiable criteria
like "POST /auth/login with valid credentials returns 200 + JWT, Playwright navigates to
/dashboard, dashboard shows user's name." This specificity is what makes automated
evaluation possible.

---

## 4. Evaluator Configuration

### 4a. Native Claude Evaluator

A separate Claude session with its own prompt, calibrated to be skeptical. The harness
generates this prompt — it's NOT the same session that wrote the code.

**Why separate sessions matter:** When asked to evaluate their own work, agents "confidently
praise the work — even when the quality is obviously mediocre." A separate session with a
QA-focused prompt doesn't have this bias, and tuning it to be skeptical is far more
tractable than making a generator critical of itself.

**Evaluator session prompt template:**

```markdown
You are a QA evaluator. Your job is to TEST the implementation of {feature_name} by
interacting with the running application, then GRADE it against the criteria below.

## Critical Rules
1. Be skeptical — assume the builder thinks everything works. Your job is to verify.
2. Test every criterion by actually interacting with the app, not just reading code.
3. A score of 3 means "acceptable" — don't grade higher just because it doesn't crash.
4. If ANY blocking criterion scores below its threshold, verdict is FAIL. No averaging.
5. Write evidence for every score — screenshot path, exact behavior observed, what you expected.

## Tools Available
{platform_tools — e.g., "Playwright MCP for browser interaction"}

## App Launch
{launch_instructions — e.g., "Run `npm run dev`, navigate to http://localhost:3000"}

## Sprint Contract
{paste from .harness/sprint-contract.md}

## Evaluation Criteria
{paste from .harness/eval-criteria.md — includes per-criterion thresholds}

## Output
Write your evaluation report to: `.harness/eval-reports/eval-{YYYY-MM-DD-HHmm}.md`
Copy the same file to `.harness/eval-reports/latest.md` for easy coder access.
Use the format specified in the report template below.
```

### 4b. Evaluator Calibration

Out-of-the-box, Claude is a lenient QA agent. Calibrate using:

1. **Few-shot examples** — Include 2-3 grading examples in the evaluator prompt showing
   the expected level of rigor:

   ```markdown
   ## Calibration Examples

   **Example 1 — Score: 2 (FAIL)**
   Criterion: "User can create a new project and see it in the project list"
   Evidence: Project creation form works, but after submit, project list doesn't refresh.
   User must manually reload the page to see the new project.
   Why not 3: Auto-refresh after creation is part of the criterion, not a nice-to-have.

   **Example 2 — Score: 4 (PASS)**
   Criterion: "Dashboard loads within 2 seconds and shows all widgets"
   Evidence: Dashboard loads in 1.2s. All 6 widgets render. Chart widget shows "No data"
   for empty datasets instead of crashing. One widget has a minor alignment issue (8px off).
   Why not 5: Minor visual polish issue, but all functional criteria met.
   ```

2. **Tuning loop** — After the first evaluation round, review the report:
   - Find scores where the evaluator was too lenient (found issues but scored 3+)
   - Find scores where the evaluator was too strict (penalized acceptable behavior)
   - Update the evaluator prompt to correct the calibration
   - This is an iterative process — expect 2-3 rounds of tuning over the project lifetime

### 4c. External CLI Evaluator

External CLI agents (Codex, Gemini) provide genuinely independent evaluation — different
model, different training data. This is the strongest form of the generator/evaluator split.

**When to use native vs. CLI evaluators:**

| Factor | Native Claude Session | External CLI (Codex/Gemini) |
|--------|----------------------|----------------------------|
| Independence | Same model family, different session | Different model entirely |
| Tool access | Full MCP access (Playwright, mobile-mcp, figma-console) | Limited (file reading, code review) |
| Interactive UAT | Real-time interaction with running app (SAV loops, live debugging) | Static evidence review only (pre-captured screenshots) |
| Visual parity | `figma_check_design_parity` (automated scoring) or `figma_capture_screenshot` (LLM comparison) | Manual comparison of exported PNG pairs (subjective) |
| Best for | Interactive UAT, browser/mobile testing, Figma visual parity | Code review, spec compliance, security, independent second opinion |

**Recommendation:** Native MCP is the primary UAT method — it can interact with the
running app and access Figma for visual parity. External CLI agents complement native UAT
by providing genuinely independent review of captured evidence (different model = different
blind spots). When both are available:

1. **Native evaluator first** — interactive UAT + Figma visual parity (captures evidence)
2. **CLI evidence review second** — reviews the captured evidence with fresh eyes
3. **Compare findings** — disagreements between native and CLI often reveal real issues

See `cli-agents.md` Section 3 for the full four-layer UAT architecture: Maestro scripted
regression (Section 3e), native MCP (Section 3b), Figma visual parity (Section 3c), and
CLI evidence review (Section 3d).

### 4d. Stop Gate — Automated In-Session Evaluation

If the Codex Plugin (`codex-plugin-cc`) is installed, a third evaluation mode becomes
available: the **stop gate**. This is a hook that automatically triggers a Codex adversarial
review every time Claude stops after making code changes — creating an automated
generator→evaluator loop within a single session.

This is the highest-autonomy evaluation pattern: no manual dispatch, no separate session.
The coder writes code, Codex reviews it, and if Codex says `BLOCK`, Claude must address
the issues before proceeding.

**Trade-offs:** The stop gate is powerful but expensive — it can create long-running
Claude/Codex loops and drain usage limits. Use it selectively for critical features or
thorough quality bars. See `cli-agents.md` "Stop Gate" section for configuration details.

**Harness configuration:** When appropriate, add the stop gate as an opt-in step in
`session-startup.md`. The harness does NOT enable it by default — it documents how to
enable it for critical sprints.

---

## 5. Evaluation Report Format

The evaluator writes a timestamped report that the coder reads in the next session.
Reports are preserved across rounds to enable trend analysis.

**File naming:**
- Each report: `.harness/eval-reports/eval-{YYYY-MM-DD-HHmm}.md`
- Latest report: `.harness/eval-reports/latest.md` (symlink or copy of most recent)

The evaluator always writes to a new timestamped file and updates `latest.md`. Never
overwrite previous reports — they provide the score trend data needed for refine/pivot
decisions.

### Report Template

```markdown
# Evaluation Report — {date}

## Verdict: {PASS | REVISE | FAIL}

## Sprint Contract
Features evaluated: {feature_ids}
Contract criteria: {N} | Tested: {N} | Passed: {N} | Failed: {N}

## Score Trend
Read prior reports in `.harness/eval-reports/` to fill this section.
| Round | Date | Verdict | Blocking Avg | Key Change |
|-------|------|---------|-------------|------------|
| 1 | {date} | {verdict} | {avg}/5 | Initial evaluation |
| 2 | {date} | {verdict} | {avg}/5 | {what improved or regressed} |

## Per-Criterion Scores

### {Criterion Name} — {Score}/5 {PASS|REVISE|FAIL}
**Threshold:** {min_score} (blocking|advisory)
**Evidence:** {what was observed — screenshot path, exact behavior}
**Expected:** {what should have happened per contract}
**Gap:** {specific difference, or "None" if passing}

{repeat for each criterion}

## Weighted Score (optional)
If dimensions have percentage weights in eval-criteria.md:
- {Dimension}: {score}/5 x {weight}% = {weighted}
- Total weighted: {sum}/100
- Thresholds: >=80 = PASS, 65-79 = REVISE, <65 = FAIL

## Issues

### Critical (must fix before proceeding)
1. {issue} — Evidence: {screenshot/log reference}

### Advisory (fix when convenient)
1. {issue} — Evidence: {screenshot/log reference}

## Evaluator Notes
{any observations not captured by criteria — patterns noticed, suggestions for approach}
```

### Verdict Rules

- **PASS** — All blocking criteria meet their thresholds
- **REVISE** — All blocking criteria meet their thresholds, but advisory criteria have
  issues OR any blocking criterion scores borderline (3/5)
- **FAIL** — Any blocking criterion below threshold

### Evidence Requirements

Every score must include evidence. "It works" or "looks fine" are not evidence. Evidence is:
- A screenshot path: `.harness/eval-evidence/login-success.png`
- Exact output: `API returned 200 with body {"user": {"id": 1, "name": "Test"}}`
- A specific observation: `After clicking Submit, the form spinner appeared for 3.2s, then redirected to /dashboard`

---

## 6. Feedback Re-Ingestion

How the coding agent reads and acts on evaluation feedback in the next session.

### Session Startup Addition

Add this step to `session-startup.md` when evaluation loop is configured:

```markdown
## After Step 4 (Verify baseline), Before Step 5 (Sprint contract):

4b. **Check evaluation reports**: Read the most recent file in `.harness/eval-reports/`:
    - If FAIL: address ALL critical issues before new work
    - If REVISE: address critical issues, consider advisory issues
    - If PASS: proceed to next feature
    - Check the Score Trend: if scores are flat/declining across 2+ rounds, consider
      PIVOTING to a different approach rather than refining the same one
```

### Refine or Pivot Decision

After receiving FAIL or REVISE feedback, the coder makes a strategic choice:

- **Refine** (default) — Fix the specific issues identified in the report. Best when
  scores are trending up and the approach is sound but has bugs.
- **Pivot** — Abandon the current approach and try a fundamentally different one. Best when
  scores are flat or declining across multiple evaluation rounds, suggesting the approach
  itself is flawed.

The harness doesn't automate this decision — it's a judgment call the coder (or user) makes.
But the timestamped evaluation reports provide the data needed: compare scores across rounds
in `.harness/eval-reports/` to see the trend.

### Decision Heuristic
- Scores improved from last round → **Refine** (continue current approach)
- Scores flat or declined for 2+ rounds → **Pivot** (different approach needed)
- Same criterion fails repeatedly → **Pivot** on that specific aspect
- First evaluation round → Always **Refine** (no trend data yet)

The harness does not automate this decision, but the timestamped reports provide the data.
The user or coder reads the trend and decides.

### Multi-Round Cycle

The expected flow across sessions:

```
Session 1: Coder implements feature → commits
Session 2: Evaluator tests → writes report (FAIL)
Session 3: Coder reads report → fixes issues → commits
Session 4: Evaluator re-tests → writes report (PASS)
Session 5: Coder proceeds to next feature
```

In practice, QA rounds are fast (7-10 minutes) relative to build rounds (1-2 hours).
The harness configures this by noting in `session-startup.md` which role the current
session plays (build vs. QA).

---

## 7. Harness Configuration Checklist

When configuring the evaluation loop in Stage 2c, generate these artifacts:

| Artifact | Location | When |
|----------|----------|------|
| Evaluator session prompt | `.harness/evaluator-prompt.md` | Always (when eval loop enabled) |
| Evaluation report template | `.harness/evaluation-report-template.md` | Always |
| Sprint contract template | `.harness/sprint-contract.md` | Always |
| Evaluation reports directory | `.harness/eval-reports/` | Always (created at first eval) |
| Evaluator tuning log | `.harness/evaluator-tuning-log.md` | Always (tracks calibration changes) |
| App launch script | `.claude/scripts/launch-app.sh` | When app has a runnable UI |
| UAT dispatch script (CLI) | `.claude/scripts/uat-dispatch.sh` | When CLI agents available |
| Evidence directory | `.harness/eval-evidence/` | Created by evaluator at runtime |
| Visual parity config | `analysis.json → visual_parity` | When figma-console or figma-desktop available |
| Screen-to-frame map | `analysis.json → visual_parity.screen_to_frame_map` | When visual parity enabled |
| Maestro workspace | `.maestro/config.yaml` + `.maestro/flows/` | When Maestro available + mobile project |
| Maestro smoke report | `.harness/eval-reports/maestro-smoke.xml` | Created by Maestro at session startup |
| Maestro config | `analysis.json → maestro` | When Maestro available |
| Install prompts | `session-startup.md` install checklist | When needed tools are missing |

### analysis.json Additions

```json
{
  "evaluation_loop": {
    "enabled": true,
    "platform": "web|mobile|desktop|api",
    "primary_uat": "native_mcp",
    "scripted_regression": "maestro",
    "evaluator_type": "native|cli|both",
    "report_format": "timestamped",
    "tools": {
      "interact": "playwright|mobile-mcp|maestro|accessibility-api|curl",
      "observe": "screenshots|dom-snapshots|view-hierarchy|response-body|junit-xml"
    },
    "criteria_count": 5,
    "blocking_criteria": 3,
    "cli_agents": {
      "codex": true,
      "gemini": false,
      "role": "complement"
    }
  }
}
```

For the `visual_parity` configuration schema (method, fallback, parity_threshold,
figma_file_key, screen_to_frame_map), see the canonical definition in
`cli-agents.md` Section 3c. It lives under `harness_decisions.visual_parity` in
`analysis.json`, not under `evaluation_loop`.

---

## 8. Project-Specific Adaptations

The patterns above are platform-agnostic. When configuring the evaluation loop, the model
should also research and add project-specific adaptations that go beyond what this reference
prescribes. The skill provides the skeleton; the model fills in domain knowledge.

### What to Adapt

| Area | How to Adapt | Example |
|------|-------------|---------|
| **Evaluation criteria** | Add domain-specific dimensions beyond the generic ones | E-commerce: "Cart accuracy", Healthcare: "HIPAA compliance" |
| **Testing patterns** | Research the project's framework for idiomatic testing | Next.js: test Server Components with RSC-aware patterns; Flutter: use integration_test |
| **Tool configuration** | Look up the specific MCP/tool setup for the project's stack | Playwright: configure `webServer` in config to auto-start dev server |
| **Evaluator procedures** | Add step-by-step testing procedures specific to the UI flows | "Navigate to /settings, change theme to dark, verify all components respect the theme" |
| **Launch script** | Adapt to the project's actual build and serve commands | Gradle: `./gradlew installDebug && adb shell am start`; Vite: `npx vite --port 3000` |
| **Sprint contract criteria** | Make criteria as concrete as the project allows | "POST /api/cart returns 200 with updated item count" not "cart API works" |

### How to Research

During Stage 2c, after loading this reference, the model should:
1. Read the project's existing test setup (test config, existing test files) for patterns
2. Check the project's package manager for testing/automation dependencies already installed
3. Search the project's docs/ for any testing or quality guidelines
4. Adapt evaluator procedures to the specific UI flows described in the plan

**Document what you find.** Record discoveries in `analysis.json` under `project_adaptations`
so they are available to all downstream stages:

```json
{
  "project_adaptations": {
    "idiomatic_test_patterns": [
      "Tests use vitest with @testing-library/react, co-located as *.test.tsx"
    ],
    "framework_specific_tools": [
      "Playwright already configured in playwright.config.ts with webServer auto-start"
    ],
    "existing_quality_standards": [
      "ESLint with jsx-a11y plugin, coverage threshold 80% in CI"
    ],
    "discovered_conventions": [
      "All API endpoints return { data, error, meta } envelope"
    ]
  }
}
```

This checklist forces the model to prove it researched the project before generating
artifacts. If `project_adaptations` is empty, the harness output is likely generic.

The goal: a harness that feels custom-built for this project, not a generic template with
placeholders swapped. If the model discovers a project-specific pattern (e.g., the project
uses Storybook for component testing, or has a custom lint rule for accessibility), encode
it in the harness artifacts.

### Observability Evaluation for Backend/API Projects

For projects without UI, the evaluation loop focuses on API correctness and performance.
The evaluator needs structured access to system health data — not just HTTP responses.

**Discovery checklist** (run during Stage 1b to populate `analysis.json`):

| Check | How to Detect | Records In |
|-------|--------------|------------|
| Application logs | `docker compose logs`, log files in `/var/log/`, stdout capture | `analysis.json → observability.logs` |
| Response timing | `curl -w '%{time_total}'`, framework-level timing middleware | `analysis.json → observability.timing` |
| Database access | `docker compose exec db psql`, `sqlite3`, ORM CLI | `analysis.json → observability.db_access` |
| Metrics endpoint | `/metrics`, `/health`, Prometheus exposition | `analysis.json → observability.metrics_endpoint` |
| Structured logging | JSON log format, correlation IDs | `analysis.json → observability.structured_logs` |

**Evaluator observability procedure** (add to evaluator prompt for API projects):

```markdown
## Observability Checks (after API testing)

1. **Logs**: Read application logs for the test period. Flag:
   - Any ERROR or WARN entries not caused by intentional error-path testing
   - Unhandled exceptions or stack traces
   - Slow query warnings (if DB logging enabled)
   Command: `{log_command}` (e.g., `docker compose logs --since=5m app`)

2. **Response timing**: For each tested endpoint, record response time.
   Flag any endpoint exceeding {sla_ms}ms (default: 2000ms).
   Command: `curl -s -o /dev/null -w '%{time_total}' {endpoint}`

3. **Database state**: After write operations, verify data integrity.
   Check that created/updated/deleted records match expectations.
   Command: `{db_query_command}` (e.g., `docker compose exec db psql -c "SELECT ..."`)

4. **Health check**: Verify the app is still healthy after all tests.
   A crashed or degraded app after testing indicates stability issues.
   Command: `curl -s {health_endpoint}` (e.g., `http://localhost:8000/health`)
```

**Harness artifacts for observability:**
- Add an `## Observability` section to `eval-criteria.md` with timing SLAs and log rules
- Add observability commands to `launch-app.sh` (start log capture alongside app)
- Include observability checks in the evaluator prompt's testing procedure

The harness configurator should discover what observability is available in the project
and configure the evaluator to use it — don't assume Docker or any specific stack.
