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
| Tool access | Full MCP access (Playwright, mobile-mcp) | Limited (file reading, code review) |
| UAT capability | Can interact with running app | Code review + static analysis only |
| Best for | Interactive UAT, browser testing | Code review, spec compliance, security |

**Recommendation:** Use native Claude evaluator for interactive UAT (it needs MCP tools),
and external CLI agents for code-level review (they bring independence). When both are
available, run both — they catch different things.

See also `cli-agents.md` Section 3 for the full capability comparison and dispatch scripts.

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

### analysis.json Additions

```json
{
  "evaluation_loop": {
    "enabled": true,
    "platform": "web|mobile|desktop|api",
    "evaluator_type": "native|cli|both",
    "report_format": "timestamped",
    "tools": {
      "interact": "playwright|mobile-mcp|accessibility-api|curl",
      "observe": "screenshots|dom-snapshots|view-hierarchy|response-body"
    },
    "criteria_count": 5,
    "blocking_criteria": 3,
    "cli_agents": {
      "codex": true,
      "gemini": false
    }
  }
}
```

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

The goal: a harness that feels custom-built for this project, not a generic template with
placeholders swapped. If the model discovers a project-specific pattern (e.g., the project
uses Storybook for component testing, or has a custom lint rule for accessibility), encode
it in the harness artifacts.

### Observability for Backend/API Projects

For projects without UI, the evaluation loop focuses on API correctness and performance.
Beyond the basic HTTP checks in Section 2d, the evaluator should also:
- Read application logs (`docker logs`, log files) for errors or warnings during test
- Check response times and flag any endpoint >2s (or project-specific SLA)
- Verify database state after operations (if DB access is available)
- Check for memory leaks or connection pool exhaustion in long-running tests

These checks are project-specific — the harness configurator should discover what
observability is available and configure the evaluator to use it.
