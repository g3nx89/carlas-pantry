---
name: design-narration
description: >-
  This skill should be used when the user asks to "narrate Figma screens",
  "create a UX narrative", "describe mockups for coding agents",
  "generate interaction descriptions from Figma", "design narration",
  "create a UX-NARRATIVE document", or wants to transform Figma Desktop
  mockups into a detailed UX/interaction description document.
  Produces UX-NARRATIVE.md with per-screen purpose, elements, behaviors,
  states, navigation, and animations — filling the gaps that static
  mockups cannot communicate.
version: 1.0.0
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(mkdir:*)", "Bash(rm:*)", "Task", "mcp__figma-desktop__get_metadata", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__pal__consensus"]
---

# Design Narration Skill — Lean Orchestrator

Transform Figma Desktop mockups into a detailed UX/interaction narrative document (`UX-NARRATIVE.md`).

**Pipeline position:** `refinement (PRD.md) → design-narration (UX-NARRATIVE.md) → specification (spec.md)`

**This workflow is resumable.** Progress persisted in state file. User decisions tracked with full audit trail.

---

## CRITICAL RULES (High Attention Zone — Start)

### Core Workflow Rules
1. **One screen at a time**: User selects each screen in Figma Desktop. Never batch-process screens or assume order.
2. **Coordinator never talks to users**: Screen analyzer returns summary with questions; orchestrator mediates ALL user interaction via AskUserQuestion.
3. **Checkpoint after every screen**: Update state file with screen status, critique scores, and patterns BEFORE asking user to select next screen.
4. **No question limits**: Continue question rounds until critique score reaches GOOD threshold (14+/20) or user signs off.
5. **Mutable decisions with audit trail**: Prior decisions CAN be revised if later analysis warrants it — but EVERY revision requires explicit user confirmation. Never silently change a prior answer.
6. **Config reference**: All thresholds and parameters from `@$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`.
7. **Figma Desktop MCP required**: Verify `mcp__figma-desktop__get_metadata` is available at startup. If unavailable, STOP and notify user.

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/narration-config.yaml`

| Setting | Path | Default |
|---------|------|---------|
| Good score threshold | `self_critique.thresholds.good.min` | 14/20 |
| Acceptable threshold | `self_critique.thresholds.acceptable.min` | 10/20 |
| Max questions per batch | `maieutic_questions.max_per_batch` | 4 |
| Question round limit | `self_critique.max_question_rounds_per_screen` | **No limit** |
| Decisions mutable | `decisions.decisions_mutable` | true |
| PAL models | `validation.pal_consensus.models` | 3 models |
| PAL min models | `validation.pal_consensus.minimum_models` | 2 |
| PAL degradation | `validation.pal_consensus.graceful_degradation` | true |

---

## User Input

```text
$ARGUMENTS
```

Consider user input before proceeding (if not empty).

---

## Workflow Stages

```
+-------------------------------------------------------------------+
|  Stage 1 (Inline): SETUP                                          |
|  Figma MCP check, optional context doc, state init/resume         |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 2 (Loop — narration-screen-analyzer):                      |
|  SCREEN PROCESSING                                                 |
|                                                                    |
|  REPEAT until user says "no more screens":                         |
|    2A: Analyzer captures + describes + critiques + questions       |
|    Orchestrator: mediate questions via AskUserQuestion              |
|    2B: Analyzer refines with user answers, re-critiques            |
|    Handle decision revisions if flagged                            |
|    Sign-off → user picks next screen                               |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 3 (narration-coherence-auditor): COHERENCE CHECK            |
|  Cross-screen consistency, pattern extraction, mermaid diagrams    |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 4 (MPA + PAL): VALIDATION                                  |
|  3 specialist agents in parallel + PAL Consensus + synthesis       |
+-------------------------------+-----------------------------------+
                                |
+-------------------------------v-----------------------------------+
|  Stage 5 (Inline): OUTPUT                                          |
|  Assemble UX-NARRATIVE.md from screens + patterns + validation     |
+-------------------------------------------------------------------+
```

---

## Stage Dispatch Table

| Stage | Name | Delegation | Reference File | User Pause? |
|-------|------|------------|---------------|-------------|
| 1 | Setup | **Inline** | (below) | No |
| 2 | Screen Processing | Coordinator (loop) | `references/screen-processing.md` | Yes (per screen) |
| 3 | Coherence Check | Coordinator | `references/coherence-protocol.md` | Yes (inconsistencies) |
| 4 | Validation | Coordinator | `references/validation-protocol.md` | Yes (critical findings) |
| 5 | Output | **Inline** | `references/output-assembly.md` | No |

---

## Stage 1 — Inline Setup

Execute directly (no coordinator dispatch).

### Step 1.1: Figma Desktop MCP Check

Verify `mcp__figma-desktop__get_metadata` is available. If unavailable:
```
NOTIFY user: "Figma Desktop MCP not detected. Ensure Figma Desktop is open with the Claude plugin active."
STOP workflow.
```

### Step 1.2: Context Document (Optional)

```
PRESENT via AskUserQuestion:
    question: "Provide a context document (PRD, functional description, product brief)?
    This helps the analyzer understand screen purpose and domain vocabulary."

    options:
      - "Yes — I'll paste or reference a document"
      - "No — proceed without context document"

IF "Yes":
    PROMPT for document content or file path
    SAVE to design-narration/context-input.md
```

### Step 1.3: State Initialization or Resume

#### Step 1.3.5: Lock Acquisition

```
LOCK_FILE = design-narration/.narration-lock
IF lock file exists AND age < lock_stale_timeout_minutes (from config):
    PRESENT via AskUserQuestion:
        question: "Another narration session may be active. Override?"
        options:
          - "Yes — override and continue"
          - "No — cancel"
    IF "No": STOP workflow
IF lock file exists AND age >= lock_stale_timeout_minutes:
    NOTIFY user: "Stale lock detected (>60 min). Clearing and proceeding."
WRITE lock file with timestamp
```

#### Step 1.3.6: State Check

```
CHECK if design-narration/.narration-state.local.md exists

IF exists:
    READ state file
    COMPILE onboarding context from completed screens:
        1. Product name + context document summary (2-3 sentences)
        2. Completed screens table: | # | Screen | Score | Key Patterns |
        3. Accumulated patterns (YAML block)
        4. Key decisions made (from audit trail, latest versions only)
        5. Current screen status (if mid-processing)
    NOTIFY user: "Resuming from {current_stage}. {N} screens completed."

IF not exists:
    CREATE directories: design-narration/, design-narration/screens/, design-narration/figma/, design-narration/validation/
    INITIALIZE state file with:
        schema_version: 1
        current_stage: 2
        screens_completed: 0
        screens: []
        patterns: {}
        decisions_audit_trail: []
        coherence: {}
        validation: {}
```

### Step 1.4: First Screen Selection

```
PRESENT via AskUserQuestion:
    question: "Select the first screen to analyze in Figma Desktop, then confirm."

    options:
      - "Ready — I've selected a screen in Figma"

CALL mcp__figma-desktop__get_metadata() to detect selection
EXTRACT node_id and frame name
ADVANCE to Stage 2
```

---

## Stage 2 — Screen Processing Loop

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/screen-processing.md`

This stage loops for each screen:

1. **2A — Analysis dispatch**: Send node_id, screen name, context doc, prior patterns, Q&A history, and completed screens digest to `narration-screen-analyzer` agent
2. **Q&A mediation**: Read analyzer's summary → present questions via AskUserQuestion (batches of 4, "Let's discuss this" option on every question)
3. **2B — Refinement dispatch**: Send user answers back to analyzer for narrative update + re-critique
4. **Decision revision handling**: If analyzer flags contradictions with prior screens, present revisions to user
5. **Sign-off**: Present final score, user approves or flags for review
6. **Pattern accumulation**: Extract shared patterns from completed screen
7. **Next screen**: User selects next screen in Figma or indicates "no more screens"

**Loop exit**: User selects "No more screens — proceed to coherence check" → advance to Stage 3.

---

## Stage 3 — Coherence Check

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/coherence-protocol.md`

Dispatch `narration-coherence-auditor` agent with ALL completed screen narratives. The auditor:
- Runs 5 consistency checks (naming, interaction, navigation, state parity, terminology)
- Extracts shared patterns
- Generates mermaid diagrams (navigation map, user journey flows, state machines)

Orchestrator presents each inconsistency to user for resolution. Updated screen files and patterns stored for Stage 5.

---

## Stage 4 — Validation

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/validation-protocol.md`

1. **MPA — 3 agents in parallel** (single Task message):
   - `narration-developer-implementability`: Can a coding agent build from this?
   - `narration-ux-completeness`: All journeys and states covered?
   - `narration-edge-case-auditor`: Unusual conditions handled?

2. **PAL Consensus** (3 models, graceful degradation if unavailable)

3. **Synthesis**: `narration-validation-synthesis` merges findings
   - CRITICAL findings → presented to user via AskUserQuestion
   - IMPORTANT findings → applied automatically, user notified
   - MINOR findings → applied silently

4. **Validation gate**: If recommendation = `ready` or all critical findings addressed → advance to Stage 5

---

## Stage 5 — Output Assembly

**Read and follow:** `@$CLAUDE_PLUGIN_ROOT/skills/design-narration/references/output-assembly.md`

Assemble `UX-NARRATIVE.md` from per-screen narratives, coherence patterns, validation results, and decision audit trail. Use template `@$CLAUDE_PLUGIN_ROOT/templates/ux-narrative-template.md`.

---

## State Management

**State file:** `design-narration/.narration-state.local.md`
**Schema version:** 1

State uses YAML frontmatter with append-only workflow log.

**Top-level fields:**
- `schema_version`: 1
- `current_stage`: 1-5
- `screens_completed`: N
- `context_document`: path or null

**Per-screen structure:**
```yaml
screens:
  - node_id: "{NODE_ID}"
    name: "{SCREEN_NAME}"
    status: pending | in_progress | described | critiqued | questions_asked | refined | signed_off
    narrative_file: "screens/{nodeId}-{name}.md"
    screenshot_file: "figma/{nodeId}-{name}.png"
    critique_scores:
      completeness: [1-4]
      interaction_clarity: [1-4]
      state_coverage: [1-4]
      navigation_context: [1-4]
      ambiguity: [1-4]
      total: [X/20]
    flagged_for_review: false
```

**Patterns (accumulated across screens):**
```yaml
patterns:
  shared_components: []
  navigation_patterns: []
  naming_conventions: []
  interaction_patterns: []
```

**Decision audit trail (mutable with tracking):**
```yaml
decisions_audit_trail:
  - id: "screen-1-q3"
    screen: "login-screen"
    question: "What happens on failed login?"
    answer: "Show inline error"
    timestamp: "{ISO}"

  - id: "screen-1-q3-rev1"
    screen: "home-screen"
    revises: "screen-1-q3"
    question: "What happens on failed login?"
    answer: "Show error toast notification"
    revision_reason: "Toast pattern used consistently across app"
    timestamp: "{ISO}"
```

**Stage tracking:**
```yaml
coherence:
  status: pending | completed
  inconsistencies_found: N
  inconsistencies_resolved: N

validation:
  status: pending | completed
  quality_score: N
  recommendation: ready | needs-revision
  pal_status: completed | partial | skipped
```

---

## Agent References

| Agent | Stage | Purpose | Model |
|-------|-------|---------|-------|
| `narration-screen-analyzer` | 2 | Per-screen analysis, narrative generation, self-critique, question generation | sonnet |
| `narration-coherence-auditor` | 3 | Cross-screen consistency, pattern extraction, mermaid diagrams | sonnet |
| `narration-developer-implementability` | 4 | MPA: implementability evaluation | sonnet |
| `narration-ux-completeness` | 4 | MPA: journey and state coverage | sonnet |
| `narration-edge-case-auditor` | 4 | MPA: unusual condition handling | sonnet |
| `narration-validation-synthesis` | 4 | Merge MPA + PAL findings, prioritize fixes | opus |

---

## Output Artifacts

| Artifact | Stage | Description |
|----------|-------|-------------|
| `design-narration/UX-NARRATIVE.md` | 5 | Final UX/interaction narrative document |
| `design-narration/screens/{nodeId}-{name}.md` | 2 | Per-screen narrative |
| `design-narration/figma/{nodeId}-{name}.png` | 2 | Per-screen Figma screenshot |
| `design-narration/context-input.md` | 1 | User-provided context document |
| `design-narration/coherence-report.md` | 3 | Cross-screen consistency findings + mermaid diagrams |
| `design-narration/validation/mpa-implementability.md` | 4 | Developer implementability audit |
| `design-narration/validation/mpa-ux-completeness.md` | 4 | UX completeness audit |
| `design-narration/validation/mpa-edge-cases.md` | 4 | Edge case audit |
| `design-narration/validation/synthesis.md` | 4 | Merged validation findings |
| `design-narration/.narration-state.local.md` | All | State persistence |

---

## Reference Map

| Reference | Purpose | Load When |
|-----------|---------|-----------|
| `references/screen-processing.md` | Per-screen loop: dispatch, Q&A, refinement, sign-off | Stage 2 execution |
| `references/coherence-protocol.md` | Cross-screen auditor dispatch, mermaid diagrams | Stage 3 execution |
| `references/validation-protocol.md` | MPA + PAL dispatch, synthesis, findings | Stage 4 execution |
| `references/critique-rubric.md` | 5-dimension self-critique rubric | Passed to screen analyzer |
| `references/output-assembly.md` | Stage 5: final document assembly steps | Stage 5 execution |
| `references/recovery-protocol.md` | Crash detection and recovery procedures | Skill re-invocation with incomplete state |
| `references/README.md` | File index, sizes, cross-references | Orientation |

---

## CRITICAL RULES (High Attention Zone — End)

Rules 1-7 above MUST be followed. Key reminders:
- One screen at a time — user drives the order
- Coordinator never talks to users — orchestrator mediates all interaction
- Checkpoint after every screen — state updated before next screen selection
- No question limits — ask everything needed for completeness
- Decisions are mutable but EVERY revision requires explicit user confirmation
- Figma Desktop MCP is required — stop if unavailable
- All thresholds from config — never hardcode values
