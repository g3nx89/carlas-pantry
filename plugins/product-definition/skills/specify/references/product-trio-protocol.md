---
stage: stage-2-spec-draft
artifacts_written:
  - specs/{FEATURE_DIR}/spec.md (via PM agent)
  - specs/{FEATURE_DIR}/design-brief.md (via Designer agent, conditional — Figma absent only)
  - specs/{FEATURE_DIR}/analysis/qa-early-findings.md (via QA-Lead agent)
---

# Product Trio Co-creation Protocol

> Collaborative team of PM + Designer + QA-Lead working concurrently instead of sequential
> BA → design-brief → qa-strategist waterfall. Replaces the standard Step 2.1 (solo BA dispatch)
> when PRODUCT_TRIO_ENABLED == true.

## Applicability

- `PRODUCT_TRIO_ENABLED == true` (from dispatch context, resolved in Stage 1)
- Profile mapping: `thorough` = 3 agents (PM + Designer + QA-Lead), `standard` = 2 agents (PM + QA-Lead), `rapid` = disabled
- Replaces standard Stage 2 Step 2.1 (solo BA dispatch) with team-based co-creation
- Stage 5: design-brief step SKIPPED when trio Designer produced it
- Stage 6: qa-strategist still runs full strategy (trio QA-Lead does early AC review only)

---

## Team Composition

| Role | Agent Source | Spawns When | File Ownership |
|------|-------------|-------------|----------------|
| `product-manager` | `business-analyst.md` | Always (when trio enabled) | `spec.md` |
| `designer` | `design-brief-generator.md` | Figma ABSENT only (`FIGMA_ENABLED == false AND HANDOFF_SUPPLEMENT_AVAILABLE == false`) | `design-brief.md` |
| `qa-lead` | `qa-strategist.md` (AC review subset) | Profile `thorough` only | `analysis/qa-early-findings.md` |

**File ownership rule:** Each agent writes ONLY to its owned file. No cross-writing.

---

## Team Lifecycle

### Step TRIO.1: Create Team

```
TeamCreate(
  team_name: "specify-{FEATURE_ID}-trio",
  description: "Product trio co-creation for {FEATURE_NAME}"
)

IF TeamCreate fails:
    LOG: "Product trio unavailable — falling back to sequential BA dispatch"
    GOTO Fallback Protocol (below)
```

### Step TRIO.2: Spawn Team Members

**Spawn PM (always):**
```
Agent(
  team_name: "specify-{FEATURE_ID}-trio",
  name: "product-manager",
  subagent_type: "general-purpose",
  prompt: """
    Read agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/business-analyst.md

    You are the Product Manager in a collaborative trio. Write spec.md using the
    same process as solo BA (Sequential Thinking, 8 phases). As you complete each
    major section, notify the team via SendMessage.

    After completing each section, send:
        SendMessage(to: "*", message: "section-ready:{section_name}")

    After completing each batch of user stories with ACs, send:
        SendMessage(to: "*", message: "ac-batch:{US-NNN}")

    When all sections are complete, send:
        SendMessage(to: "*", message: "spec-complete")

    If a teammate flags an issue (e.g., untestable AC), address it and send:
        SendMessage(to: "*", message: "ac-revised:{AC-ID}")

    Feature: {FEATURE_NAME}
    User input: {USER_INPUT}
    {IF figma_context: Figma: @specs/{FEATURE_DIR}/figma_context.md}
    {IF handoff_supplement: Handoff: @{HANDOFF_SUPPLEMENT_PATH}}
    Output: specs/{FEATURE_DIR}/spec.md
  """
)
```

**Spawn Designer (conditional):**
```
IF FIGMA_ENABLED == false AND HANDOFF_SUPPLEMENT_AVAILABLE == false:
    Agent(
      team_name: "specify-{FEATURE_ID}-trio",
      name: "designer",
      subagent_type: "general-purpose",
      prompt: """
        Read agent instructions: @$CLAUDE_PLUGIN_ROOT/agents/design-brief-generator.md

        You are the Designer in a collaborative trio. Generate design-brief.md
        incrementally as the PM sends section-ready messages. For each section:
        1. Wait for "section-ready:{name}" from product-manager
        2. Read the corresponding section in spec.md
        3. Derive screens, states, and journeys for that section
        4. Append to design-brief.md
        5. Send: SendMessage(to: "*", message: "screens-derived:{section}:{count}")

        When product-manager sends "spec-complete", finalize design-brief.md
        and send: SendMessage(to: "*", message: "design-brief-complete")

        Output: specs/{FEATURE_DIR}/design-brief.md
      """
    )
```

**Spawn QA-Lead (conditional):**
```
IF PROFILE == "thorough":  # thorough profile only — QA-Lead for maximum rigor
    Agent(
      team_name: "specify-{FEATURE_ID}-trio",
      name: "qa-lead",
      subagent_type: "general-purpose",
      prompt: """
        You are the QA Lead in a collaborative trio. Your role is early AC
        testability review — NOT full test strategy (that's Stage 6).

        When product-manager sends "ac-batch:{US-NNN}":
        1. Read the ACs for that user story in spec.md
        2. Check each AC for testability:
           - Has observable outcome (not subjective)
           - Has defined trigger condition
           - Has measurable criteria
        3. If an AC is untestable, send:
           SendMessage(to: "product-manager", message: "untestable-ac:{AC-ID}:{reason}")
        4. Log all findings to analysis/qa-early-findings.md

        When product-manager sends "spec-complete":
        1. Finalize qa-early-findings.md with summary
        2. Send: SendMessage(to: "*", message: "qa-review-complete:{total_acs}:{flagged}")

        Output: specs/{FEATURE_DIR}/analysis/qa-early-findings.md
      """
    )
```

### Step TRIO.3: Monitor & Wait

The coordinator monitors team progress:

```
WAIT for product-manager to send "spec-complete"
THEN WAIT for designer to send "design-brief-complete" (if spawned, timeout: 120s after spec-complete)
THEN WAIT for qa-lead to send "qa-review-complete" (if spawned, timeout: 60s after spec-complete)

OVERALL TIMEOUT: 600 seconds (10 minutes) from team creation
```

### Step TRIO.4: Shutdown & Cleanup

```
SendMessage(to: "product-manager", message: {type: "shutdown_request", reason: "Trio complete"})
{IF designer spawned:}
SendMessage(to: "designer", message: {type: "shutdown_request", reason: "Trio complete"})
{IF qa-lead spawned:}
SendMessage(to: "qa-lead", message: {type: "shutdown_request", reason: "Trio complete"})

WAIT for shutdown_response from each (timeout: 30s)
TeamDelete(team_name: "specify-{FEATURE_ID}-trio")
```

### Step TRIO.5: Record Trio Outcomes

```
SET trio_design_brief_generated = (designer was spawned AND design-brief.md exists)
SET trio_qa_findings_count = (qa-lead was spawned AND qa-early-findings.md exists ? count : 0)

# These flags inform downstream stages:
# - Stage 5 Step 5.5: SKIP design-brief-generator if trio_design_brief_generated == true
# - Stage 6 Step 6.3: Load qa-early-findings.md as optional input
```

---

## Communication Protocol

Message types (plain text, prefixed for parsing):

| Sender | Message | Meaning |
|--------|---------|---------|
| PM → all | `section-ready:{section_name}` | A spec section is stable, ready for review |
| PM → all | `ac-batch:{US-NNN}` | ACs for a user story are written |
| PM → all | `spec-complete` | Full spec is done |
| PM → qa-lead | `ac-revised:{AC-ID}` | AC has been updated after QA feedback |
| Designer → all | `screens-derived:{section}:{count}` | Screens extracted for a section |
| Designer → all | `design-brief-complete` | Design brief finalized |
| QA → PM | `untestable-ac:{AC-ID}:{reason}` | AC needs revision for testability |
| QA → all | `qa-review-complete:{total}:{flagged}` | QA review done |

---

## Fallback Protocol

When TeamCreate fails (feature not enabled, experimental flag not set):

```
EXECUTE standard Step 2.1 (solo BA agent via Task dispatch)
    — No designer or QA-lead involvement at this stage
    — Design brief generated separately in Stage 5 (if Figma absent)
    — Test strategy generated in Stage 6 (no early QA findings)

This is identical to the non-trio workflow — zero regression.
```

---

## Interaction with File-Based Pause

The trio team MUST complete before the Stage 4A file-based pause. Teams cannot survive
cross-session pauses. The trio produces all its artifacts within the Stage 2 continuous
execution segment.

**Timeline constraint:**
```
Stage 1 (inline) → Stage 2 [TRIO RUNS HERE] → Stage 3 → Stage 4A [PAUSE] → ...
                    ^^^^^^^^^^^^^^^^^^^^^^^^
                    Trio must complete within this window
```

---

## Summary Contract Additions

When trio runs, add to Stage 2 summary flags:

```yaml
flags:
  # ... existing flags ...
  trio_mode: true
  trio_agents: {2|3}
  trio_design_brief_generated: {true|false}
  trio_qa_findings: {N|0}
  trio_untestable_acs: {N|0}
```

When trio does NOT run (disabled or fallback):
```yaml
flags:
  trio_mode: false
```
