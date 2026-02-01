---
description: Create or update the feature specification from a natural language feature description.
argument-hint: |
  Feature description

  Figma Integration Options:
    --figma    Enable Figma integration (will ask: desktop vs online, capture mode)
    --no-figma Skip Figma integration entirely (no questions asked)
    (no flag)  Interactive mode - will ask if you want Figma integration
allowed-tools: ["Bash(cp:*)", "Bash(git:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rm:*)", "Bash(mv:*)", "Task", "mcp__pal__consensus", "mcp__pal__thinkdeep", "mcp__sequential-thinking__sequentialthinking", "mcp__figma-desktop__get_screenshot", "mcp__figma-desktop__get_design_context", "mcp__figma-desktop__get_metadata", "mcp__figma__get_screenshot", "mcp__figma__get_design_context", "mcp__figma__get_metadata"]
---

# Specify Feature (Resumable)

Guided feature specification with codebase understanding and architecture focus.

**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are NEVER lost.

---

## ⚠️ CRITICAL RULES (MUST READ FIRST - High Attention Zone)

### Core Workflow Rules
1. **State Preservation**: ALWAYS checkpoint after user decisions via state file update
2. **Resume Compliance**: NEVER re-ask questions from `user_decisions` - they are IMMUTABLE
3. **Delegation Pattern**: Complex analysis → specialized agents (`design-brief-generator`, `gap-analyzer`)
4. **Skill Invocation**: Figma capture → `specify-figma-capture`, Clarifications → `specify-clarification`
5. **Progressive Disclosure**: Load templates ONLY when phase reached (reference via `@$CLAUDE_PLUGIN_ROOT/templates/prompts/`)
6. **Batching Limit**: AskUserQuestion MAX 4 questions per call - use skill for batching
7. **BA Recommendation**: First option MUST be "(Recommended)" with rationale
8. **Lock Protocol**: Always acquire lock at start, release at completion
9. **Config Reference**: All limits and thresholds from `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`
10. **Structured Responses**: Agents return responses per `@$CLAUDE_PLUGIN_ROOT/templates/agent-response-schema.md`
11. **Unified Checkpoints**: State file ONLY - no HTML comment checkpoints (P4)

### ⛔ MANDATORY REQUIREMENTS (v2.1 - NEVER VIOLATE)
12. **Design Brief MANDATORY**: `design-brief.md` MUST be generated for EVERY specification. NEVER skip, not even for efficiency.
13. **No Question Limits**: There is NO maximum on clarification questions - ask EVERYTHING needed for complete spec.
14. **No Story Limits**: There is NO maximum on user stories or NFRs - capture ALL requirements.
15. **No Iteration Limits**: Continue clarification loops until COMPLETE, not until a counter reaches max.
16. **grok-4 for Variety**: PAL Consensus and ThinkDeep include `x-ai/grok-4` for additional variety. Continue gracefully if unavailable.

### ⚠️ PAL/MODEL FAILURE RULES (v2.2)
17. **PAL Consensus Minimum**: Consensus requires **minimum 2 models**. If < 2 models available → **FAIL** and notify user.
18. **No Model Substitution**: If a ThinkDeep model fails, **DO NOT** substitute with another model. ThinkDeep is for variety - substituting defeats the purpose.
19. **User Notification MANDATORY**: When ANY PAL model fails or is unavailable, **ALWAYS** notify user with clear message (e.g., `"⚠️ Model X unavailable. Continuing with N models."`)

---

## Configuration Reference

**Load configuration from:** `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml`

Key settings used in this workflow:

| Setting | Path | Default |
|---------|------|---------|
| Clarification markers | `limits.clarification_markers_max` | **null** (no limit) |
| Clarification iterations | `limits.clarification_iterations_max` | **null** (no limit) |
| Clarification questions | `limits.max_clarification_questions` | **null** (no limit) |
| User stories | `limits.max_user_stories` | **null** (no limit) |
| NFRs | `limits.max_nfrs` | **null** (no limit) |
| PAL rejection retries max | `limits.pal_rejection_retries_max` | 2 |
| Checklist GREEN threshold | `thresholds.checklist.green` | 85% |
| Checklist YELLOW threshold | `thresholds.checklist.yellow` | 60% |
| PAL GREEN threshold | `thresholds.pal.green` | 16/20 |
| PAL YELLOW threshold | `thresholds.pal.yellow` | 12/20 |
| Incremental gates enabled | `feature_flags.enable_incremental_gates` | true |
| Research discovery enabled | `feature_flags.enable_research_discovery` | true |
| Research default mode | `research_discovery.default_mode` | simple |
| Design brief skip allowed | `design_brief.skip_allowed` | **false** (never skip) |
| grok-4 for variety | `pal_consensus.default_models` | includes grok-4 (optional) |

**⚠️ NO LIMITS ON:**
- Number of clarification questions to ask user
- Number of user stories to write
- Number of acceptance criteria
- Number of non-functional requirements
- Number of clarification batches/iterations

**Always gather ALL information needed for a complete specification.**

---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

---

## Phase 0: Pre-flight & Resume Detection

### Step 0.0: Pre-flight Validation (MUST PASS)

Before proceeding, validate all required components exist:

```bash
# Check required agents
AGENT_CHECK=""
test -f $CLAUDE_PLUGIN_ROOT/agents/design-brief-generator.md && AGENT_CHECK+="✓ design-brief-generator.md\n" || AGENT_CHECK+="✗ MISSING: design-brief-generator.md\n"
test -f $CLAUDE_PLUGIN_ROOT/agents/gap-analyzer.md && AGENT_CHECK+="✓ gap-analyzer.md\n" || AGENT_CHECK+="✗ MISSING: gap-analyzer.md\n"
echo -e "$AGENT_CHECK"

# Check required skills
SKILL_CHECK=""
test -f $CLAUDE_PLUGIN_ROOT/skills/specify-figma-capture/SKILL.md && SKILL_CHECK+="✓ specify-figma-capture\n" || SKILL_CHECK+="✗ MISSING: specify-figma-capture\n"
test -f $CLAUDE_PLUGIN_ROOT/skills/specify-clarification/SKILL.md && SKILL_CHECK+="✓ specify-clarification\n" || SKILL_CHECK+="✗ MISSING: specify-clarification\n"
echo -e "$SKILL_CHECK"

# Check required templates
TEMPLATE_COUNT=$(ls $CLAUDE_PLUGIN_ROOT/templates/prompts/*.md 2>/dev/null | wc -l)
test $TEMPLATE_COUNT -ge 6 && echo "✓ Prompt templates ($TEMPLATE_COUNT files)" || echo "✗ MISSING: Prompt templates (need 6+, found $TEMPLATE_COUNT)"
```

**Validation Gate:**

IF ANY component marked `✗ MISSING`:
→ **ABORT** with message:

```
❌ PRE-FLIGHT VALIDATION FAILED

Missing components detected. Required files:
- $CLAUDE_PLUGIN_ROOT/agents/design-brief-generator.md
- $CLAUDE_PLUGIN_ROOT/agents/gap-analyzer.md
- $CLAUDE_PLUGIN_ROOT/skills/specify-figma-capture/SKILL.md
- $CLAUDE_PLUGIN_ROOT/skills/specify-clarification/SKILL.md
- $CLAUDE_PLUGIN_ROOT/templates/prompts/ (6+ files)

Run: ls -la $CLAUDE_PLUGIN_ROOT/agents/ $CLAUDE_PLUGIN_ROOT/skills/ $CLAUDE_PLUGIN_ROOT/templates/prompts/

Ensure all refactoring phases completed before using this command.
```
→ EXIT

ELSE: → Continue to Step 0.1

---

### Step 0.1: Check for Lock Files

```bash
find specs/ -name ".specify.lock" -type f 2>/dev/null
```

**If lock file found:**

1. Read lock file content (contains timestamp and feature info)
2. Calculate lock age: `current_time - lock_timestamp`

**If lock age > 2 hours (stale):**
→ Log: "Removing stale lock (age: {HOURS}h)"
→ Remove lock file
→ Continue to Step 0.2

**If lock age <= 2 hours (active):**
→ Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "A specification session is in progress for '{FEATURE_NAME}' (locked {MINUTES} min ago). How to proceed?",
    "header": "Lock Found",
    "multiSelect": false,
    "options": [
      {
        "label": "Resume from last checkpoint (Recommended)",
        "description": "Continue from where the previous session left off"
      },
      {
        "label": "View current state",
        "description": "Display current specification status without changes"
      },
      {
        "label": "Force restart",
        "description": "Remove progress and start fresh. WARNING: Unsaved work lost"
      },
      {
        "label": "Exit",
        "description": "Exit without any changes"
      }
    ]
  }]
}
```

→ Handle response:
- "Resume": Set `WORKFLOW_MODE = RESUME`, continue
- "View": Set `WORKFLOW_MODE = VIEW`, display status, exit
- "Force restart": Remove lock AND state file, `WORKFLOW_MODE = NEW`
- "Exit": EXIT immediately

---

### Step 0.2: Check for Existing State Files

```bash
find specs/ -name ".specify-state.local.md" -type f 2>/dev/null
```

**If state files found:**

1. Parse each state file's YAML frontmatter
2. Categorize by status:
   - **INCOMPLETE**: `current_phase` != "COMPLETE"
   - **COMPLETE**: `current_phase` == "COMPLETE"

---

### Step 0.3: Determine Workflow Mode

**Case A: User provided new feature description AND no matching state exists**
→ `WORKFLOW_MODE = NEW`, proceed to Phase 1

**Case B: User provided new feature description AND matching state exists**
→ Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Found existing workflow for '{FEATURE_NAME}'. How to proceed?",
    "header": "Existing",
    "multiSelect": false,
    "options": [
      {
        "label": "Resume Existing (Recommended)",
        "description": "Continue from {CURRENT_PHASE}: {NEXT_STEP}"
      },
      {
        "label": "Create New Workflow",
        "description": "Start new specification (existing preserved)"
      }
    ]
  }]
}
```

**Case C: No arguments AND incomplete state exists**
→ Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Found incomplete specification for '{FEATURE_NAME}' (at {CURRENT_PHASE}). How to proceed?",
    "header": "Resume",
    "multiSelect": false,
    "options": [
      {
        "label": "Resume (Recommended)",
        "description": "Continue from {CURRENT_PHASE}: {NEXT_STEP}"
      },
      {
        "label": "Re-run Current Phase",
        "description": "Restart {CURRENT_PHASE}, preserving earlier phases"
      },
      {
        "label": "Re-run Clarifications",
        "description": "Gather additional clarifications (current score: {LAST_SCORE})"
      },
      {
        "label": "Start Fresh",
        "description": "Discard all progress and begin new specification"
      }
    ]
  }]
}
```

**Case D: No arguments AND COMPLETE state exists**
→ Use `AskUserQuestion`:

```json
{
  "questions": [{
    "question": "Found completed specification for '{FEATURE_NAME}' (PAL: {PAL_SCORE}/20). Improve it?",
    "header": "Improve",
    "multiSelect": false,
    "options": [
      {
        "label": "Re-run Clarifications",
        "description": "Gather additional clarifications (current: {LAST_SCORE})"
      },
      {
        "label": "Re-run Validation",
        "description": "Re-validate spec against checklist"
      },
      {
        "label": "Re-run PAL Gate",
        "description": "Re-run multi-model consensus validation"
      },
      {
        "label": "View Current Status",
        "description": "Display specification status"
      },
      {
        "label": "Start New Feature",
        "description": "Begin specifying different feature"
      }
    ]
  }]
}
```

**Case E: No arguments AND no state exists**
→ Inform: "No feature description provided and no existing workflow found. Please provide a feature description."
→ EXIT

---

### Step 0.4: Handle User Selection

| Selection | WORKFLOW_MODE | Action |
|-----------|---------------|--------|
| Resume | `RESUME` | Load state, jump to `current_phase` |
| Re-run Current Phase | `RERUN_PHASE` | Reset phase status, execute it |
| Re-run Clarifications | `RERUN_CLARIFY` | Jump to Phase 4.5 |
| Re-run Validation | `RERUN_VALIDATE` | Jump to Phase 4 |
| Re-run PAL Gate | `RERUN_PAL` | Jump to Phase 5 |
| Start Fresh | `NEW` | Archive old state (`.bak`), create new |
| Create New Workflow | `NEW` | Proceed with new feature |
| View Current Status | `VIEW` | Display status, exit |

---

### Step 0.5: Build Resume Context (If Required)

**If WORKFLOW_MODE ∈ {NEW}**: `RESUME_CONTEXT = ""` (empty)

**If WORKFLOW_MODE ∈ {RESUME, RERUN_PHASE, RERUN_CLARIFY, RERUN_VALIDATE, RERUN_PAL}**:

1. Read `STATE_FILE` YAML frontmatter
2. Load template: `@$CLAUDE_PLUGIN_ROOT/templates/prompts/resume-context-builder.md`
3. Populate with state data including phase-specific context
4. Set `RESUME_CONTEXT` variable for all subsequent Task prompts

**Phase-Specific Context includes:**
- `FIGMA_CAPTURED`: Connection type, screens captured, context path
- `RESEARCH_DISCOVERY`: Mode, questions generated, user decision, waiting_for_user flag
- `RESEARCH_ANALYSIS`: Reports detected, synthesis complete, findings summary
- `SPEC_DRAFT`: Spec file exists, line count, research context available
- `CHECKLIST_VALIDATION`: Last score, iteration, gaps
- `CLARIFICATION`: Markers found/resolved, pending questions, batches
- `PAL_GATE`: Previous score, iteration, dissenting views

---

## Phase 1: Initialization

**Goal**: Set up feature directory and state tracking.

### Step 1.1: Generate Short Name

Extract 2-4 word short name from feature description:
- Use action-noun format (e.g., "add-user-auth", "fix-payment-bug")
- Preserve technical terms/acronyms (OAuth2, API, JWT)
- Keep concise but descriptive

### Step 1.2: Check Existing Branches

```bash
git fetch --all --prune
# Find highest feature number across:
# - Remote: git ls-remote --heads origin | grep -E 'refs/heads/feature/[0-9]+-<short-name>$'
# - Local: git branch | grep -E '^[* ]*feature/[0-9]+-<short-name>$'
# - Specs: Check for specs/[0-9]+-<short-name>
# Use N+1, or 1 if none found
```

### Step 1.3: Create Feature Directory

```bash
mkdir -p specs/{NUMBER}-{SHORT_NAME}
cp $CLAUDE_PLUGIN_ROOT/templates/spec-template.md specs/{NUMBER}-{SHORT_NAME}/spec.md
cp $CLAUDE_PLUGIN_ROOT/templates/.specify-state-template.local.md specs/{NUMBER}-{SHORT_NAME}/.specify-state.local.md
```

Set variables:
- `FEATURE_DIR` = `specs/{NUMBER}-{SHORT_NAME}`
- `SPEC_FILE` = `FEATURE_DIR/spec.md`
- `STATE_FILE` = `FEATURE_DIR/.specify-state.local.md`
- `LOCK_FILE` = `FEATURE_DIR/.specify.lock`

### Step 1.4: Create Lock File

```bash
echo "locked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
feature: {FEATURE_NAME}
phase: INIT
pid: $$" > {LOCK_FILE}
```

### Step 1.5: Initialize State File (CHECKPOINT)

Update `STATE_FILE` YAML frontmatter:
- `feature_id`: "{NUMBER}-{SHORT_NAME}"
- `feature_name`: "{FEATURE_NAME}"
- `user_input`: "{ORIGINAL_USER_INPUT}"
- `current_phase`: "INIT"
- `phase_status`: "completed"
- Update `phases.init.status`: "completed"

Append to Workflow Log:
```markdown
### {ISO_DATE} - Phase: INIT
- **Action**: Created feature directory and initialized state
- **Outcome**: SUCCESS
- **Feature ID**: {NUMBER}-{SHORT_NAME}
```

---

## Phase 1.5: Figma Design Capture (Optional)

**Checkpoint:** `FIGMA_CAPTURED`

### Step 1.5.0: Determine Figma Mode

Check for explicit flags in `$ARGUMENTS`:
- `--figma` present → Proceed with Figma (ask connection type)
- `--no-figma` present → **SKIP entire phase**, proceed to Phase 2
- Neither → Ask user interactively

### Step 1.5.1: Invoke Figma Capture Skill

**Delegate to skill:** `specify-figma-capture`

Pass context:
- `FEATURE_DIR`
- `ARGUMENTS` (for flag detection)

Skill handles:
- Connection selection (Desktop vs Online)
- Capture mode selection (Selected Frames vs Page)
- Error handling with recovery options
- Screenshot saving to `{FEATURE_DIR}/figma/`
- `figma_context.md` generation

**Returns:**
- `FIGMA_ENABLED`: true/false
- `FIGMA_CONNECTION`: desktop/online/null
- `FIGMA_CONTEXT_FILE`: path or null
- `SCREENS_CAPTURED`: count

### Step 1.5.2: Update State (CHECKPOINT)

Update `STATE_FILE`:
```yaml
user_decisions:
  figma_enabled: {FIGMA_ENABLED}
  figma_connection: "{FIGMA_CONNECTION}"
  figma_capture_mode: "{CAPTURE_MODE}"

phases:
  figma_capture:
    status: completed
    timestamp: "{now}"
    screens_captured: {SCREENS_CAPTURED}
```

---

## Phase 1.7: Research Question Discovery (Optional)

**Checkpoint:** `RESEARCH_DISCOVERY`

**Purpose:** Generate deep research questions that help ground the specification in current market reality, competitive landscape, and user expectations.

### Step 1.7.0: Check Research Discovery Skip

**If resuming and `user_decisions.research_decision` exists:**
- `conduct_research` → Jump to Step 1.7.5 (check for reports)
- `skip_with_context` → Skip to Phase 2 (context already captured)
- `skip_entirely` → Skip to Phase 2

### Step 1.7.1: Check for Existing Research Reports

Before generating questions, check if user already has research:

```bash
# Create research folder structure if it doesn't exist
mkdir -p {FEATURE_DIR}/research/questions
mkdir -p {FEATURE_DIR}/research/reports

# Check for existing research reports in reports folder
find {FEATURE_DIR}/research/reports -name "research-*.md" -o -name "*.research.md" 2>/dev/null | wc -l
```

**If reports found > 0:**
→ Jump to Phase 1.8: Research Report Analysis

### Step 1.7.2: Ask User About Research Mode

**Use `AskUserQuestion`:**

```json
{
  "questions": [{
    "question": "Would you like to generate deep research questions before specification drafting? This helps ground the spec in market reality.",
    "header": "Research",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes, generate questions (Recommended)",
        "description": "Generate targeted research questions I can investigate"
      },
      {
        "label": "Skip - I have domain knowledge",
        "description": "I'll provide context directly, no external research needed"
      },
      {
        "label": "Skip entirely",
        "description": "Proceed directly to specification (BA uses internal knowledge)"
      }
    ]
  }]
}
```

**Handle Response:**
- "Yes, generate questions" → Continue to Step 1.7.3
- "Skip - I have domain knowledge" → Ask for context (Step 1.7.2b), then Phase 2
- "Skip entirely" → Update state, proceed to Phase 2

### Step 1.7.2b: Capture User Domain Knowledge (If Skip with Context)

**Use `AskUserQuestion`:**

```json
{
  "questions": [{
    "question": "Please share your domain knowledge and context that should inform the specification.",
    "header": "Context",
    "multiSelect": false,
    "options": [
      {
        "label": "Provide context now",
        "description": "Enter your domain knowledge in the text field"
      }
    ]
  }]
}
```

**Store response in state:**
```yaml
user_decisions:
  research_decision: "skip_with_context"
  research_context: "{USER_PROVIDED_CONTEXT}"
```

→ Proceed to Phase 2 (BA receives this context)

### Step 1.7.3: Select Research Mode

**Load configuration:** `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` → `research_discovery.default_mode`

Default is "simple" mode (single agent). For complex features, offer MPA mode:

```json
{
  "questions": [{
    "question": "Select research question generation mode:",
    "header": "Mode",
    "multiSelect": false,
    "options": [
      {
        "label": "Simple mode (Recommended)",
        "description": "Single agent generates 4-8 focused questions. Faster, lower cost."
      },
      {
        "label": "Multi-Perspective Analysis (MPA)",
        "description": "3 specialized agents (Business, Technical, UX) with synthesis. More thorough, higher cost (~$0.30)."
      }
    ]
  }]
}
```

**Update state:**
```yaml
user_decisions:
  research_mode: "{simple | mpa}"
```

### Step 1.7.4: Generate Research Questions

**If mode = "simple":**

Use BA agent with Sequential Thinking to generate questions in AI-agent friendly format:

```markdown
## Task: Generate Deep Research Questions (AI-Agent Format)

Feature: {USER_INPUT}
Figma Context: {IF available}

Use `mcp__sequential-thinking__sequentialthinking` to systematically explore:
1. What assumptions is this feature built on?
2. What could invalidate our approach?
3. What do we need to verify about the market/users/competition?

Generate 4-8 DEEP research questions that:
- Cannot be answered with simple Google searches
- Require cross-referencing multiple sources
- Challenge assumptions we might be taking for granted
- Consider competitive landscape and market trends

## Output Format (AI-Agent Friendly)

Write to: {FEATURE_DIR}/research/RESEARCH-AGENDA.md

**IMPORTANT:** Output is designed for AI deep search agents. DO NOT include:
- Workflow instructions ("Run /sdd:01-specify")
- "How to Use This Document" sections
- Human-oriented resume instructions

**DO include:**
- Agent Mission statement at top
- Domain Context (product, target market, legal framework)
- Prioritized questions with Search Targets and Expected Findings
- Search Strategy Guide with keywords and authoritative sources

Use structure from: @$CLAUDE_PLUGIN_ROOT/agents/research-question-synthesis.md (Output Format section)
```

**If mode = "mpa":**

Launch 3 agents in parallel using Task tool:

```markdown
## Parallel Agent Execution

Launch these agents concurrently:

1. **research-discovery-business** (subagent_type: "research-discovery-business")
   - Focus: Strategic, market, competitive
   - Output: {FEATURE_DIR}/research/questions/questions-strategic.md

2. **research-discovery-technical** (subagent_type: "research-discovery-technical")
   - Focus: Architecture, scalability, compliance
   - Output: {FEATURE_DIR}/research/questions/questions-technical.md

3. **research-discovery-ux** (subagent_type: "research-discovery-ux")
   - Focus: User behavior, community, adoption
   - Output: {FEATURE_DIR}/research/questions/questions-ux.md

After all complete, run synthesis:

4. **research-question-synthesis** (subagent_type: "research-question-synthesis")
   - Input: All question files from {FEATURE_DIR}/research/questions/
   - Output: {FEATURE_DIR}/research/RESEARCH-AGENDA.md
```

### Step 1.7.5: Present Research Questions to User

Read generated `RESEARCH-AGENDA.md` and present summary:

```markdown
## Research Questions Generated

**Total Questions:** {N}
**CRITICAL Priority:** {N} (could invalidate approach)
**HIGH Priority:** {N} (shapes requirements)
**MEDIUM Priority:** {N} (refines understanding)

**Estimated Research Time:** {N-M hours}

Research agenda saved to: {FEATURE_DIR}/research/RESEARCH-AGENDA.md
```

### Step 1.7.6: Research Decision Point (USER PAUSE)

**Use `AskUserQuestion`:**

```json
{
  "questions": [{
    "question": "Research questions are ready. How would you like to proceed?",
    "header": "Research",
    "multiSelect": false,
    "options": [
      {
        "label": "I'll conduct research (Recommended)",
        "description": "Save reports to {FEATURE_DIR}/research/. Run /sdd:01-specify to resume."
      },
      {
        "label": "Proceed without research",
        "description": "Continue to specification draft using AI's internal knowledge"
      }
    ]
  }]
}
```

**If "I'll conduct research":**
→ Update state:
```yaml
current_phase: "RESEARCH_DISCOVERY"
phase_status: "waiting_for_user"
phases:
  research_discovery:
    status: waiting_for_user
    user_decision: "conduct_research"
    questions_generated: {N}
```

→ Output:
```markdown
## Research Phase: User Action Required

Research agenda has been saved to:
`{FEATURE_DIR}/research/RESEARCH-AGENDA.md`

**Instructions:**
1. Review the research agenda in the file above
2. Conduct your research using preferred tools (or AI deep search agents)
3. Save reports to: `{FEATURE_DIR}/research/reports/`
4. Naming convention: `research-{topic}.md` (e.g., `research-competitors.md`)
5. Use template: `$CLAUDE_PLUGIN_ROOT/templates/research-report-template.md`

**When ready to continue:**
```
/sdd:01-specify
```

The workflow will automatically detect your reports and continue.
```

→ **EXIT** (user pause for research)

**If "Proceed without research":**
→ Update state, proceed to Phase 2

### Step 1.7.7: Update State (CHECKPOINT)

```yaml
current_phase: "RESEARCH_DISCOVERY"
phases:
  research_discovery:
    status: completed
    timestamp: "{now}"
    mode: "{simple | mpa}"
    user_decision: "{decision}"
    questions_generated: {N}
    questions_by_perspective:
      strategic: {N}
      technical: {N}
      ux: {N}
    questions_after_synthesis: {N}
    critical_count: {N}
    high_count: {N}
    output_file: "research/RESEARCH-AGENDA.md"
```

---

## Phase 1.8: Research Report Analysis

**Checkpoint:** `RESEARCH_ANALYSIS`

**Purpose:** Analyze user-provided research reports and synthesize insights for the Business Analyst.

### Step 1.8.0: Check for Research Reports

This phase is triggered when:
1. Resuming after user conducted research, OR
2. Skipping from Phase 1.7 with existing reports

```bash
find {FEATURE_DIR}/research/reports -name "research-*.md" -o -name "*.research.md" 2>/dev/null
```

**If no reports found:**
→ Check state `user_decisions.research_decision`:
- `conduct_research` → Warn user, ask to continue anyway or wait
- `skip_with_context` or `skip_entirely` → Expected, proceed to Phase 2

### Step 1.8.1: Inventory Research Reports

```bash
ls -la {FEATURE_DIR}/research/reports/*.md 2>/dev/null
```

Parse each report for:
- Filename
- Word count
- Category (from content or filename)
- Questions addressed (if tagged with RQ-### references)

### Step 1.8.2: Analyze Reports (Sequential Thinking)

Use `mcp__sequential-thinking__sequentialthinking` for systematic analysis:

```markdown
## Research Report Analysis

**Reports Found:**
{LIST_OF_REPORTS}

**Analysis Protocol (8 steps):**

1. **Extract Key Findings:** Pull main findings from each report
2. **Cross-Reference:** Identify findings that appear in multiple reports
3. **Conflict Detection:** Find contradictions between reports
4. **Evidence Quality:** Assess confidence level of each finding
5. **Gap Analysis:** Identify research gaps (questions not addressed)
6. **Requirement Implications:** Derive requirements from findings
7. **Risk Identification:** Surface risks revealed by research
8. **Synthesis:** Create unified research context for BA

**Output:** Research synthesis for specification drafting
```

### Step 1.8.3: Generate Research Synthesis

Launch synthesis agent:

```markdown
## Task: Synthesize Research Reports

Feature: {FEATURE_NAME}
Reports Directory: {FEATURE_DIR}/research/reports/

Analyze all research reports and create a synthesis document:

**Output:** {FEATURE_DIR}/research-synthesis.md

Use template: @$CLAUDE_PLUGIN_ROOT/templates/research-synthesis-template.md

**Include:**
- Executive summary (2-3 sentences)
- Consensus findings (high confidence)
- Market context and trends
- Competitive landscape
- User expectations
- Technical recommendations
- Contradictions requiring judgment
- Research gaps
- Implications for specification
```

### Step 1.8.4: Present Synthesis Summary

Display key insights to user:

```markdown
## Research Synthesis Complete

**Reports Analyzed:** {N}
**Consensus Findings:** {N} (high confidence)
**Contradictions Found:** {N} (require judgment)
**Research Gaps:** {N}

### Key Insights for Specification:

{TOP_3_INSIGHTS}

### Requirements Derived from Research:

**Must Have:**
{LIST}

**Should Consider:**
{LIST}

**Avoid (Anti-Patterns):**
{LIST}

Full synthesis saved to: {FEATURE_DIR}/research-synthesis.md
```

### Step 1.8.5: Update State (CHECKPOINT)

```yaml
current_phase: "RESEARCH_ANALYSIS"
phases:
  research_analysis:
    status: completed
    timestamp: "{now}"
    reports_detected: {N}
    reports_analyzed:
      - filename: "research-competitors.md"
        word_count: {N}
        insights_extracted: {N}
    synthesis_complete: true
    consensus_findings: {N}
    contradictions: {N}
    research_gaps: {N}
    output_file: "research-synthesis.md"
```

→ Proceed to Phase 2

---

## Phase 2: Specification Draft

**Checkpoint:** `SPEC_DRAFT`

### Step 2.1: Launch Business Analyst Agent

**Task prompt structure:**

```markdown
{RESUME_CONTEXT}

## Task: Create Feature Specification

Perform business analysis and requirements gathering for:
{USER_INPUT}

## Figma Context
{IF FIGMA_CONTEXT_FILE exists: Include content}
{ELSE: "No Figma designs available - proceed without design context"}

## Research Context
{IF research-synthesis.md exists in FEATURE_DIR:
  "Research synthesis available. Key findings:
  @{FEATURE_DIR}/research-synthesis.md (Include executive summary, consensus findings, requirements)

  IMPORTANT: Use @ResearchRef annotations to link requirements to research findings.
  Format: @ResearchRef(finding='CF-001', source='research-competitors.md')"
}
{ELIF user_decisions.research_context exists:
  "User-provided domain context:
  {user_decisions.research_context}

  IMPORTANT: Incorporate this domain knowledge into requirements."
}
{ELSE: "No research context available - proceed using internal knowledge"}

## Variables
- FEATURE_NAME: {value}
- FEATURE_DIR: {FEATURE_DIR}
- SPEC_FILE: {SPEC_FILE}
- STATE_FILE: {STATE_FILE}

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-spec-draft.md

Write specification to {SPEC_FILE} following template structure.
IF figma context provided: Correlate designs with requirements, add @FigmaRef annotations.
IF research context provided: Ground requirements in research, add @ResearchRef annotations.
```

### Step 2.2: Parse Agent Response (P6)

After BA agent completes, parse the structured response:

```yaml
# Expected response format (per agent-response-schema.md)
response:
  status: success | partial | error
  outputs:
    - file: "{SPEC_FILE}"
      action: created
  metrics:
    self_critique_score: {N}
    user_stories_count: {N}
    problem_statement_quality: {1-4}  # For Gate 1
    true_need_confidence: {low|medium|high}  # For Gate 2
  warnings: [...]
  next_step: "..."
```

**If status == error:** Handle according to error recovery protocol.
**If status == partial:** Proceed to incremental gates with warnings noted.
**If status == success:** Proceed to incremental gates.

### Step 2.3: Update State (CHECKPOINT)

After BA agent completes:
- Update `current_phase`: "SPEC_DRAFT"
- Update `phase_status`: "completed"
- Store agent metrics in state file
- Append to Workflow Log

---

## Phase 2.3: MPA-Challenge (Multi-Perspective Analysis)

**Checkpoint:** `MPA_CHALLENGE`

**Purpose:** Challenge problem framing with different model families BEFORE Gate 1. Catches root cause issues and alternative interpretations early.

**Enabled by:** `thinkdeep.integrations.challenge.enabled` in config (default: true)

### Step 2.3.1: Check MPA Enablement

```
IF config.thinkdeep.enabled == false OR config.thinkdeep.integrations.challenge.enabled == false:
    → SKIP to Phase 2.5

IF config.thinkdeep.cost_control.skip_on_simple_features == true:
    # Check simple feature heuristics
    user_stories_count = {from BA response}
    acceptance_criteria_count = {from BA response}

    IF user_stories_count <= config.thinkdeep.simple_feature_heuristics.max_user_stories
       AND acceptance_criteria_count <= config.thinkdeep.simple_feature_heuristics.max_acceptance_criteria:
        → Log: "Skipping MPA-Challenge for simple feature"
        → SKIP to Phase 2.5
```

### Step 2.3.2: Determine Execution Mode

```
IF config.thinkdeep.integrations.challenge.parallel.enabled == true:
    → Execute Parallel Multi-Model (Step 2.3.3a)
ELSE:
    → Execute Single Model (Step 2.3.3b)
```

### Step 2.3.3a: Execute Parallel Multi-Model ThinkDeep

**Dispatch to all configured models in parallel:**

```python
# For each model in config.thinkdeep.integrations.challenge.parallel.models[]
# Launch Task with mcp__pal__thinkdeep

# Model 1: Root Cause Analysis (gpt5.2)
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification.

Challenge my problem framing:

PROBLEM STATEMENT: {spec.problem_statement}
TARGET PERSONA: {spec.persona}
TRUE NEED: {spec.true_need}

Questions to address:
1. Is this problem actually the ROOT CAUSE or just a symptom?
2. What underlying user frustration might this problem mask?
3. Could solving this problem inadvertently cause other issues?

Focus on ROOT CAUSE ANALYSIS. Be specific. Quote spec text you're challenging.""",
    model="gpt5.2",
    thinking_mode="high",
    focus_areas=["root_cause_analysis", "problem_framing"],
    files=["{SPEC_FILE}"]
)

# Model 2: Alternative Interpretations (pro)
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification.

Challenge the problem framing:

PROBLEM STATEMENT: {spec.problem_statement}
TARGET PERSONA: {spec.persona}
TRUE NEED: {spec.true_need}

Questions to address:
1. What alternative interpretations of this need exist?
2. Could the persona be different than assumed?
3. What adjacent problems might users have that we're ignoring?

Focus on ALTERNATIVE INTERPRETATIONS. Be specific. Quote spec text you're challenging.""",
    model="pro",
    thinking_mode="high",
    focus_areas=["alternatives", "scope_boundaries"],
    files=["{SPEC_FILE}"]
)

# Model 3: Assumption Validation (grok-4 via openrouter) - for additional variety
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification.

Challenge the assumptions:

PROBLEM STATEMENT: {spec.problem_statement}
TARGET PERSONA: {spec.persona}
TRUE NEED: {spec.true_need}

Questions to address:
1. What implicit assumptions are being made about user behavior?
2. Is this problem worth solving at all? What's the opportunity cost?
3. What hidden risks or biases exist in the problem framing?

Focus on ASSUMPTION VALIDATION. Be specific. Quote spec text you're challenging.""",
    model="x-ai/grok-4",  # Additional variety - continue if unavailable
    thinking_mode="high",
    focus_areas=["assumptions", "implicit_risks", "contrarian_analysis"],
    files=["{SPEC_FILE}"]
)
# If any model fails: Continue with remaining models. DO NOT substitute.
# ThinkDeep is for VARIETY - substituting defeats the purpose.
```

**⚠️ Model Failure Handling:**
If any model fails during parallel execution:
1. **DO NOT substitute** with another model (defeats variety purpose)
2. **Continue** with remaining successful models
3. **Notify user**: `"⚠️ Model {MODEL} unavailable. Continuing with {N} models."`
4. **Mark in report**: Show `SKIPPED` or `ERROR` status in Model Execution Summary

### Step 2.3.3b: Execute Single Model ThinkDeep (Config-Disabled Parallel)

**Only used when parallel is explicitly DISABLED in config** (not as fallback for failures):

```python
# Single model mode - only when parallel.enabled: false in config
# NOT used when parallel models fail (see failure handling above)
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification.

Challenge my problem framing:

PROBLEM STATEMENT: {spec.problem_statement}
TARGET PERSONA: {spec.persona}
TRUE NEED: {spec.true_need}

Questions to address:
1. Is this problem actually the ROOT CAUSE or just a symptom?
2. What alternative interpretations of this need exist?
3. What adjacent problems might users have that we're ignoring?
4. Is this problem worth solving at all? What's the opportunity cost?
5. What implicit assumptions are being made about user behavior?

Be specific. Quote the spec text you're challenging. Be the devil's advocate.""",
    model="pro",
    thinking_mode="high",
    focus_areas=["problem_framing", "root_cause_analysis", "alternatives", "contrarian_analysis"],
    files=["{SPEC_FILE}"]
)
```
**NOTE:** This path is only for config-disabled parallel mode. When parallel is enabled, failed models are skipped (not substituted).

### Step 2.3.4: Synthesize Findings (Parallel Mode Only)

**If parallel mode, launch synthesizer subagent:**

```
Task(
    description="Synthesize MPA-Challenge findings from {N} models",
    subagent_type="haiku",
    prompt="""You are a synthesis agent for Multi-Perspective Analysis (MPA).

## Input: ThinkDeep Results

### gpt5.2 Analysis (focus: root_cause_analysis)
{gpt5_2_result}

### pro Analysis (focus: alternative_interpretations)
{pro_result}

### grok-4 Analysis (focus: assumption_validation)
{grok_4_result}

## Your Tasks

1. **Parse All Findings** - Extract distinct issues from each model
2. **Cross-Model Agreement** - Issues by 2+ models = HIGH priority, 3/3 = CRITICAL
3. **Semantic Deduplication** - Merge similar findings (similarity > 0.85)
4. **Risk Level** - RED (critical + confirmed), YELLOW (multiple medium), GREEN (minor only)
5. **Generate Report** - Order by priority (CRITICAL → HIGH → MEDIUM → LOW)

## Output Format

Return YAML:
```yaml
synthesis:
  risk_level: "{green|yellow|red}"
  total_findings: {N}
  cross_model_findings: {N}
  deduplicated_count: {N}

findings:
  - id: "CM-001"
    title: "{title}"
    priority: "CRITICAL|HIGH|MEDIUM"
    cross_model: true
    models_agreed: ["gpt5.2", "pro"]
    description: "{merged description}"
    recommendation: "{action}"
    action: "REQUIRES-DECISION|AUTO-INCORPORATED|NOTED"
```
"""
)
```

### Step 2.3.5: Process Results and Gate Decision

**Parse synthesis results:**

| Risk Level | Decision | Action |
|------------|----------|--------|
| GREEN | 🟢 Proceed | Continue to Phase 2.5 |
| YELLOW | 🟡 Proceed with note | Add warnings to state, continue |
| RED | 🔴 RED FLAG | Trigger RED flag workflow |

**If RED (critical issue + cross-model confirmation):**

```json
{
  "questions": [{
    "question": "⛔ CRITICAL ISSUE DETECTED\n\n{ISSUE_DESCRIPTION}\n\nAll/multiple models agree this is a blocking concern. How to proceed?",
    "header": "Challenge",
    "multiSelect": false,
    "options": [
      {
        "label": "Revise problem statement (Recommended)",
        "description": "Return to Phase 2 with guidance on addressing the issue"
      },
      {
        "label": "Acknowledge and proceed",
        "description": "Add warning to state, continue with awareness"
      },
      {
        "label": "Reject finding",
        "description": "Log rejection reason, continue without changes"
      }
    ]
  }]
}
```

### Step 2.3.6: Generate Report

Create analysis report at `{FEATURE_DIR}/analysis/`:

```bash
mkdir -p {FEATURE_DIR}/analysis/
```

- **If parallel mode:** Use template `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-challenge-parallel.md`
- **If single mode:** Use template `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-challenge.md`

### Step 2.3.7: Update State (CHECKPOINT)

```yaml
phases:
  mpa_challenge:
    status: completed
    timestamp: "{now}"
    parallel_mode: {true|false}
    models_executed:
      - alias: "gpt5.2"
        thinking_mode: "high"
        focus: "root_cause_analysis"
        duration_ms: {N}
        status: "success"
        findings_count: {N}
      # ... other models
    synthesis:
      model: "haiku"
      strategy: "union_with_dedup"
      duration_ms: {N}
      final_findings_count: {N}
    findings:
      assumptions_challenged: {N}
      risk_level: "{green|yellow|red}"
      cross_model_findings: {N}
    auto_incorporated: {N}
    user_reviewed: {N}
    action_taken: "{proceed|revise|reject_finding}"
    red_flag_triggered: {true|false}
```

Append to Workflow Log:
```markdown
### {ISO_DATE} - Phase: MPA_CHALLENGE
- **Action**: Multi-Perspective Analysis - Problem Challenge
- **Outcome**: {RISK_LEVEL}
- **Models**: {MODEL_LIST}
- **Findings**: {N} assumptions challenged ({N} cross-model)
- **Report**: analysis/mpa-challenge{-parallel}.md
```

---

## Phase 2.5: Incremental Gate 1 - Problem Quality (P2)

**Checkpoint:** `GATE_1_PROBLEM`

**Purpose:** Validate problem framing quality BEFORE proceeding. Catches bad inputs early.

**Enabled by:** `feature_flags.enable_incremental_gates` in config (default: true)

### Step 2.5.1: Check Gate Enablement

```
IF config.feature_flags.enable_incremental_gates == false:
    → SKIP to Phase 3
```

### Step 2.5.2: Extract Problem Statement

Read from `{SPEC_FILE}` the Problem Statement section.

**Evaluation Criteria** (from `config.incremental_gates.gate_1_problem_quality`):
1. Problem statement is specific (not generic platitudes)
2. Target persona is clearly identified
3. Impact/pain point is measurable or observable
4. Root cause is articulated (not just symptoms)

### Step 2.5.3: Auto-Evaluate Quality

Score each criterion (1 point each, max 4):

```
PROBLEM_QUALITY_SCORE = 0

IF problem_statement contains specific context (not "users want better experience"):
    PROBLEM_QUALITY_SCORE += 1

IF persona is named or characterized (not just "users"):
    PROBLEM_QUALITY_SCORE += 1

IF impact is quantifiable or observable (time lost, errors, frustration):
    PROBLEM_QUALITY_SCORE += 1

IF root cause is stated (not just "it doesn't work"):
    PROBLEM_QUALITY_SCORE += 1
```

### Step 2.5.4: Gate Decision

| Score | Decision | Action |
|-------|----------|--------|
| 4 | 🟢 GREEN | Proceed to Gate 2 |
| 3 | 🟡 YELLOW | Proceed with note, ask user confirmation |
| ≤2 | 🔴 RED | Require refinement before proceeding |

**If YELLOW (score = 3):**

```json
{
  "questions": [{
    "question": "The problem statement scores 3/4 on quality. Review: '{PROBLEM_STATEMENT_EXCERPT}'. Proceed?",
    "header": "Problem",
    "multiSelect": false,
    "options": [
      {
        "label": "Yes, proceed (Recommended)",
        "description": "Problem is specific enough for this feature's scope"
      },
      {
        "label": "Refine problem statement",
        "description": "Return to BA agent to improve problem framing"
      },
      {
        "label": "I'll provide more context",
        "description": "Let me add information to clarify the problem"
      }
    ]
  }]
}
```

**If RED (score ≤ 2):**

```json
{
  "questions": [{
    "question": "The problem statement needs improvement (score: {SCORE}/4). Missing: {MISSING_CRITERIA}. How to proceed?",
    "header": "Problem",
    "multiSelect": false,
    "options": [
      {
        "label": "Refine with BA (Recommended)",
        "description": "Return to BA agent with specific guidance on gaps"
      },
      {
        "label": "I'll rewrite the problem",
        "description": "Let me provide a clearer problem statement"
      },
      {
        "label": "Proceed anyway",
        "description": "Continue despite quality concerns (not recommended)"
      }
    ]
  }]
}
```

### Step 2.5.5: Handle User Decision

| Decision | Action |
|----------|--------|
| Proceed | Continue to Phase 2.7 |
| Refine with BA | Re-invoke BA agent with refinement prompt |
| User provides context | Capture input, re-invoke BA |
| Proceed anyway | Log warning, continue with flag |

### Step 2.5.6: Update State (CHECKPOINT)

```yaml
phases:
  gate_1_problem:
    status: completed
    timestamp: "{now}"
    metrics:
      problem_quality_score: {SCORE}
      criteria_met: [list]
      criteria_missing: [list]
    decision: "proceed|refine|proceed_with_warning"
```

---

## Phase 2.7: Incremental Gate 2 - True Need Validation (P2)

**Checkpoint:** `GATE_2_TRUE_NEED`

**Purpose:** Validate that true business need was identified (not just surface request).

### Step 2.7.1: Extract True Need Analysis

Read from `{SPEC_FILE}` the Business Context and True Need sections.

**Evaluation Criteria** (from `config.incremental_gates.gate_2_true_need`):
1. True need differs from stated request (root cause found)
2. Stakeholder motivations are documented
3. Success criteria are defined
4. Business value is articulated

### Step 2.7.2: Auto-Evaluate Confidence

```
TRUE_NEED_SCORE = 0

IF true_need != stated_request (shows deeper analysis):
    TRUE_NEED_SCORE += 1

IF stakeholder_motivations section exists and is populated:
    TRUE_NEED_SCORE += 1

IF success_criteria are measurable:
    TRUE_NEED_SCORE += 1

IF business_value includes impact/ROI:
    TRUE_NEED_SCORE += 1
```

### Step 2.7.3: Gate Decision

| Score | Decision | Action |
|-------|----------|--------|
| 4 | 🟢 GREEN | Proceed to Phase 3 |
| 3 | 🟡 YELLOW | Proceed with confirmation |
| ≤2 | 🔴 RED | Require iteration |

**If YELLOW or RED:** Use `AskUserQuestion` similar to Gate 1 pattern.

### Step 2.7.4: Update State (CHECKPOINT)

```yaml
phases:
  gate_2_true_need:
    status: completed
    timestamp: "{now}"
    metrics:
      true_need_score: {SCORE}
      confidence: "high|medium|low"
    decision: "proceed|iterate|proceed_with_warning"
```

---

## Phase 3: Checklist Creation

**Checkpoint:** `CHECKLIST_CREATION`

### Step 3.1: Platform Auto-Detection

```bash
# Check existing specs for platform hints
grep -rli "android\|ios\|mobile" specs/*/spec.md 2>/dev/null
```

**Decision:**
- If pattern found OR Figma context contains mobile keywords → `PLATFORM_TYPE = "mobile"`
- Else → Ask user:

```json
{
  "questions": [{
    "question": "What type of application is this feature for?",
    "header": "Platform",
    "multiSelect": false,
    "options": [
      {"label": "Mobile app (Recommended)", "description": "Android/iOS application"},
      {"label": "Web application", "description": "Browser-based web app"},
      {"label": "Backend/API", "description": "Server-side service"},
      {"label": "Generic", "description": "Platform-agnostic"}
    ]
  }]
}
```

### Step 3.2: Create Checklist

Based on `PLATFORM_TYPE`:
- `mobile` → Copy `spec-checklist-mobile.md`
- `web` → Copy `spec-checklist-web.md` (if exists)
- `generic` → Copy `spec-checklist.md`

```bash
cp $CLAUDE_PLUGIN_ROOT/templates/{CHECKLIST_TEMPLATE} {FEATURE_DIR}/spec-checklist.md
```

### Step 3.3: Update State (CHECKPOINT)

Update state with `platform_type` and checklist info.

---

## Phase 4: Checklist Validation

**Checkpoint:** `CHECKLIST_VALIDATION`

### Step 4.1: Launch BA for Validation

**Task prompt:**

```markdown
{RESUME_CONTEXT}

## Task: Validate Specification Against Checklist

Evaluate the specification at {SPEC_FILE} against the checklist at {FEATURE_DIR}/spec-checklist.md.

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-validate.md

For each checklist item:
1. Check if spec adequately addresses it
2. Mark coverage: ✓ (covered), ⚠ (partial), ✗ (missing)
3. Note specific gaps with `[NEEDS CLARIFICATION]` markers

Return: overall_score, coverage_percentage, gaps_list
```

### Step 4.2: Process Validation Results

| Score Range | Coverage | Action |
|-------------|----------|--------|
| ≥85% | HIGH | Proceed to Phase 5 |
| 60-84% | MEDIUM | Proceed to Phase 4.5 (clarifications) |
| <60% | LOW | Iterate with BA to address gaps |

### Step 4.3: Update State (CHECKPOINT)

```yaml
phases:
  checklist_validation:
    last_score: {score}
    last_coverage_pct: {coverage}
    gaps_identified: [list]
    iteration: {N}
```

---

## Phase 4.3: MPA-EdgeCases (Multi-Perspective Analysis)

**Checkpoint:** `MPA_EDGECASES`

**Purpose:** Discover edge cases not covered by standard checklist using extended reasoning from multiple model families.

**Enabled by:** `thinkdeep.integrations.edge_cases.enabled` in config (default: true)

### Step 4.3.1: Check MPA Enablement and Trigger

```
IF config.thinkdeep.enabled == false OR config.thinkdeep.integrations.edge_cases.enabled == false:
    → SKIP to Phase 4.5

IF config.thinkdeep.integrations.edge_cases.trigger == "on_coverage_below":
    IF checklist_coverage >= config.thinkdeep.integrations.edge_cases.trigger_threshold:
        → Log: "Coverage ({coverage}%) above threshold, skipping edge case mining"
        → SKIP to Phase 4.5
```

### Step 4.3.2: Determine Execution Mode

```
IF config.thinkdeep.integrations.edge_cases.parallel.enabled == true:
    → Execute Parallel Multi-Model (Step 4.3.3a)
ELSE:
    → Execute Single Model (Step 4.3.3b)
```

### Step 4.3.3a: Execute Parallel Multi-Model ThinkDeep

**Dispatch to models with different focus areas:**

```python
# Model 1: Security / Performance (pro)
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification for edge cases.

SPECIFICATION: (attached)
CHECKLIST COVERAGE: {coverage_percentage}%
IDENTIFIED GAPS: {gap_list}

Focus on SECURITY and PERFORMANCE edge cases:
1. Security boundaries - authorization, data leakage, injection risks
2. Performance edge cases - large data, slow network, high load
3. Rate limiting and resource exhaustion
4. Sensitive data handling edge cases

For each edge case rate: CRITICAL | HIGH | MEDIUM | LOW
- CRITICAL: Will cause user harm or data loss
- HIGH: Will cause poor UX or broken flow
- MEDIUM: Minor inconvenience
- LOW: Nice to have""",
    model="pro",
    thinking_mode="max",
    focus_areas=["security", "performance", "edge_cases"],
    files=["{SPEC_FILE}", "{CHECKLIST_FILE}"]
)

# Model 2: User Experience (gpt5.2)
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification for edge cases.

SPECIFICATION: (attached)
CHECKLIST COVERAGE: {coverage_percentage}%
IDENTIFIED GAPS: {gap_list}

Focus on USER EXPERIENCE edge cases:
1. Error states and failure modes not covered
2. Edge cases in user input (empty, malformed, boundary values)
3. Concurrent usage scenarios (multi-device, race conditions)
4. Unexpected user journeys and error recovery

For each edge case rate: CRITICAL | HIGH | MEDIUM | LOW""",
    model="gpt5.2",
    thinking_mode="high",
    focus_areas=["error_handling", "user_experience", "concurrency"],
    files=["{SPEC_FILE}", "{CHECKLIST_FILE}"]
)

# Model 3: Accessibility / i18n / Contrarian (grok-4 via openrouter) - for additional variety
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification for edge cases.

SPECIFICATION: (attached)
CHECKLIST COVERAGE: {coverage_percentage}%
IDENTIFIED GAPS: {gap_list}

Focus on ACCESSIBILITY, INTERNATIONALIZATION, and CONTRARIAN edge cases:
1. Accessibility gaps (screen readers, motor impairments, color blindness)
2. Internationalization gaps (RTL, date/time formats, currency, pluralization)
3. Device capability edge cases (old devices, limited storage)
4. Offline behavior and sync conflicts
5. What edge cases are the other models likely to MISS?

For each edge case rate: CRITICAL | HIGH | MEDIUM | LOW
Be the devil's advocate - find what others won't.""",
    model="x-ai/grok-4",  # Additional variety - continue if unavailable
    thinking_mode="high",
    focus_areas=["accessibility", "i18n", "device_capabilities", "contrarian_edge_cases"],
    files=["{SPEC_FILE}", "{CHECKLIST_FILE}"]
)
# If any model fails: Continue with remaining models. DO NOT substitute.
# ThinkDeep is for VARIETY - substituting defeats the purpose.
```

**⚠️ Model Failure Handling:**
If any model fails during parallel execution:
1. **DO NOT substitute** with another model (defeats variety purpose)
2. **Continue** with remaining successful models
3. **Notify user**: `"⚠️ Model {MODEL} unavailable. Continuing with {N} models."`
4. **Mark in report**: Show `SKIPPED` or `ERROR` status in Model Execution Summary

### Step 4.3.3b: Execute Single Model ThinkDeep (Config-Disabled Parallel)

**Only used when parallel is explicitly DISABLED in config** (not as fallback for failures):

```python
# Single model mode - only when parallel.enabled: false in config
# NOT used when parallel models fail (see failure handling above)
mcp__pal__thinkdeep(
    prompt="""Think deeper about this feature specification for edge cases.

SPECIFICATION: (attached)
CHECKLIST COVERAGE: {coverage_percentage}%
IDENTIFIED GAPS: {gap_list}

Find edge cases we've missed:
1. Error states and failure modes not covered
2. Edge cases in user input (empty, malformed, boundary values)
3. Concurrent usage scenarios (multi-device, race conditions)
4. Accessibility and internationalization gaps
5. Security edge cases (authorization, data leakage)
6. Performance edge cases (large data, slow network, offline)
7. What edge cases would developers typically overlook?

For each edge case rate:
- CRITICAL: Will cause user harm or data loss
- HIGH: Will cause poor UX or broken flow
- MEDIUM: Minor inconvenience
- LOW: Nice to have

Be skeptical. Challenge assumptions. Find what's missing.""",
    model="pro",
    thinking_mode="max",
    focus_areas=["edge_cases", "error_handling", "security", "accessibility", "contrarian"],
    files=["{SPEC_FILE}", "{CHECKLIST_FILE}"]
)
```
**NOTE:** This path is only for config-disabled parallel mode. When parallel is enabled, failed models are skipped (not substituted).

### Step 4.3.4: Synthesize Findings (Parallel Mode Only)

**Launch synthesizer with severity boost:**

```
Task(
    description="Synthesize MPA-EdgeCases findings with severity boost",
    subagent_type="haiku",
    prompt="""You are a synthesis agent for edge case mining.

## Input: ThinkDeep Results

### pro Analysis (focus: security_performance)
{pro_result}

### gpt5.2 Analysis (focus: user_experience)
{gpt5_2_result}

### grok-4 Analysis (focus: accessibility_i18n)
{grok_4_result}

## Your Tasks

1. **Parse All Edge Cases** - Extract from each model
2. **Semantic Deduplication** - Merge similar cases (similarity > 0.85)
3. **SEVERITY BOOST** - If 2+ models flag same edge case:
   - MEDIUM → HIGH
   - HIGH → CRITICAL (if 3/3 agree)
4. **Categorize** - error_handling, concurrency, security, performance, accessibility, i18n
5. **Identify Injections** - CRITICAL and HIGH cases become clarification questions

## Output Format

```yaml
synthesis:
  total_cases_before_dedup: {N}
  deduplicated_count: {N}
  final_cases: {N}
  severity_boosted: {N}

edge_cases:
  - id: "EC-001"
    title: "{title}"
    category: "security"
    severity: "CRITICAL"  # boosted from HIGH
    boosted: true
    models_agreed: ["pro", "gpt5.2"]
    scenario: "{description}"
    suggested_requirement: "{text}"
    inject_as_clarification: true

injected_questions:
  - "EC-001: {question derived from edge case}"
  - "EC-003: {question}"
```
"""
)
```

### Step 4.3.5: Inject CRITICAL/HIGH as Clarifications

**If config.thinkdeep.integrations.edge_cases.inject_critical_high == true:**

For each edge case with severity CRITICAL or HIGH:
1. Generate clarification question from edge case
2. Add to `pending_clarifications` for Phase 4.5
3. Track in state as `injected_questions`

Example injection:
```
Edge Case: "What happens when sync fails mid-operation?"
→ Clarification: "How should the app handle a sync failure in the middle of an operation? Should it rollback, retry, or show an error?"
```

### Step 4.3.6: Generate Report

Create analysis report:

- **If parallel mode:** Use template `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-edgecases-parallel.md`
- **If single mode:** Use template `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-edgecases.md`

### Step 4.3.7: Update State (CHECKPOINT)

```yaml
phases:
  mpa_edgecases:
    status: completed
    timestamp: "{now}"
    parallel_mode: {true|false}
    models_executed: [...]
    synthesis:
      severity_boost_applied: true
      deduplicated_count: {N}
      final_findings_count: {N}
    findings:
      critical: {N}
      high: {N}
      medium: {N}
      low: {N}
      by_category:
        error_handling: {N}
        security: {N}
        # etc.
    injected_clarifications: {N}
    injected_questions:
      - "EC-001: What happens when sync fails mid-operation?"
      - "EC-003: How are concurrent edits handled?"
```

Append to Workflow Log:
```markdown
### {ISO_DATE} - Phase: MPA_EDGECASES
- **Action**: Multi-Perspective Analysis - Edge Case Mining
- **Outcome**: {N} edge cases discovered ({N} CRITICAL, {N} HIGH)
- **Injected**: {N} clarification questions
- **Report**: analysis/mpa-edgecases{-parallel}.md
```

---

## Phase 4.5: Clarification Loop

**Checkpoint:** `CLARIFICATION`

### Step 4.5.1: Invoke Clarification Skill

**Delegate to skill:** `specify-clarification`

Pass context:
- `FEATURE_DIR`
- `SPEC_FILE`
- `CHECKLIST_FILE`
- `STATE_FILE`

Skill handles:
- Identifies `[NEEDS CLARIFICATION]` markers
- Checks already-answered questions in state (NEVER re-asks)
- Generates questions with BA recommendations (first option = Recommended)
- Batches in groups of MAX 4
- Saves responses to state IMMEDIATELY after each batch
- Error handling with recovery options

**Returns:**
- `CLARIFICATION_STATUS`: completed/partial/error
- `QUESTIONS_ANSWERED`: count
- `MARKERS_RESOLVED`: count
- `BA_QUESTIONS`: list of questions generated by BA

---

## Phase 4.6: MPA-Triangulate (Multi-Perspective Analysis)

**Checkpoint:** `MPA_TRIANGULATE`

**Purpose:** Surface clarification questions from multiple cognitive perspectives (technical + business) to ensure comprehensive question coverage.

**Enabled by:** `thinkdeep.integrations.triangulation.enabled` in config (default: true)

**Timing:** Executed AFTER BA generates initial questions, BEFORE presenting to user.

### Step 4.6.1: Check MPA Enablement

```
IF config.thinkdeep.enabled == false OR config.thinkdeep.integrations.triangulation.enabled == false:
    → SKIP to Step 4.5.2 (present BA questions directly)

IF "triangulation" IN config.thinkdeep.simple_feature_heuristics.skip_phases:
    → SKIP to Step 4.5.2
```

### Step 4.6.2: Execute Dual-Model ThinkDeep

**Technical Perspective (Gemini Pro):**

```python
mcp__pal__thinkdeep(
    prompt="""Think deeper about these clarification questions.

Current Questions from BA:
{ba_questions}

What technical gaps are missing? Focus on:
- Error handling scenarios (what if X fails?)
- Concurrency/race conditions
- Offline behavior and sync conflicts
- Data validation edge cases
- Performance under load
- Security implications

Generate 2-4 additional TECHNICAL questions not covered above.

Format each as:
- Question: "{question}"
- Focus Area: {area}
- Rationale: {why this matters}""",
    model="{config.thinkdeep.integrations.triangulation.models.technical}",
    thinking_mode="{config.thinkdeep.integrations.triangulation.thinking_mode}",
    focus_areas=["technical", "error_handling", "security"],
    files=["{SPEC_FILE}"]
)
```

**Business Perspective (GPT):**

```python
mcp__pal__thinkdeep(
    prompt="""Think deeper about these clarification questions.

Current Questions from BA:
{ba_questions}

What business gaps are missing? Focus on:
- Unusual user journeys
- Business rule exceptions
- Regulatory/compliance scenarios
- Integration with other features
- Rollback/recovery scenarios
- Edge personas not addressed

Generate 2-4 additional BUSINESS questions not covered above.

Format each as:
- Question: "{question}"
- Focus Area: {area}
- Rationale: {why this matters}""",
    model="{config.thinkdeep.integrations.triangulation.models.business}",
    thinking_mode="{config.thinkdeep.integrations.triangulation.thinking_mode}",
    focus_areas=["business_logic", "user_scenarios", "compliance"],
    files=["{SPEC_FILE}"]
)
```

### Step 4.6.3: Deduplicate and Merge Questions

**Semantic Similarity Check:**

```python
def compute_similarity(q1: str, q2: str) -> float:
    """Uses fast model for semantic similarity."""
    response = mcp__pal__thinkdeep(
        prompt=f"""Rate semantic similarity (0.0-1.0):
Q1: {q1}
Q2: {q2}

Output ONLY a decimal number (e.g., 0.87).""",
        model="{config.thinkdeep.integrations.triangulation.similarity_model}",
        thinking_mode="minimal"
    )
    return float(response.strip())

# Deduplication
all_questions = ba_questions + gemini_questions + gpt_questions
similarity_threshold = config.thinkdeep.integrations.triangulation.similarity_threshold

unique_questions = []
for q in all_questions:
    is_duplicate = False
    for existing in unique_questions:
        if compute_similarity(q, existing) > similarity_threshold:
            is_duplicate = True
            break
    if not is_duplicate:
        unique_questions.append(q)
```

### Step 4.6.4: Cross-Model Agreement Analysis

**Identify questions flagged by multiple sources:**

| Question | BA | Gemini | GPT | Priority |
|----------|:--:|:------:|:---:|----------|
| Q1 | ✓ | ✓ | ✓ | **CRITICAL** (all agree) |
| Q2 | - | ✓ | ✓ | **HIGH** (cross-model) |
| Q3 | ✓ | - | - | MEDIUM (single) |
| Q4 | - | ✓ | - | MEDIUM (single) |

**Priority Boost Rules:**
- All 3 sources agree → CRITICAL (ask first)
- 2 sources agree → HIGH (ask second)
- 1 source only → MEDIUM (ask if room in batch)

### Step 4.6.5: Generate Report

Create analysis report at `{FEATURE_DIR}/analysis/mpa-triangulation.md`

Use template: `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-triangulation.md`

### Step 4.6.6: Update State

```yaml
phases:
  mpa_triangulation:
    status: completed
    timestamp: "{now}"
    models:
      gemini_pro:
        questions_generated: {N}
        duration_ms: {N}
      gpt:
        questions_generated: {N}
        duration_ms: {N}
    original_questions: {N}  # From BA
    deduplicated: {N}
    final_questions: {N}
    cross_model_agreement:
      - question: "Network failure during save?"
        ba: true
        gemini: true
        gpt: true
        priority: "CRITICAL"
      - question: "Admin override behavior?"
        ba: false
        gemini: false
        gpt: true
        priority: "MEDIUM"
```

Append to Workflow Log:
```markdown
### {ISO_DATE} - Phase: MPA_TRIANGULATE
- **Action**: Question Triangulation (Technical + Business)
- **Original Questions**: {N} from BA
- **Added**: {N} from Gemini, {N} from GPT
- **Deduplicated**: {N}
- **Final Questions**: {N}
- **Cross-Model Agreement**: {N} HIGH priority questions
```

### Step 4.6.7: Present Merged Questions

Continue to present the merged, prioritized question set to user via the clarification skill.

**Order questions by priority:**
1. CRITICAL (all sources agree)
2. HIGH (cross-model agreement)
3. MEDIUM (single source)
4. Injected from MPA-EdgeCases (Phase 4.3)

---

### Step 4.5.2: Update Specification

After clarifications collected:

**Task prompt:**

```markdown
{RESUME_CONTEXT}

## Task: Update Specification with Clarifications

Incorporate user answers from state file into {SPEC_FILE}.

## User Decisions
{List all clarification answers from STATE_FILE}

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-update-spec.md

Update spec to address clarified items. Remove [NEEDS CLARIFICATION] markers.
Preserve existing content. Only ADD or REFINE, never remove requirements.
```

### Step 4.5.3: Re-validate (Loop Until Complete)

After update, return to Phase 4 for re-validation.

**NO ITERATION LIMIT** - Continue until:
1. Coverage reaches GREEN (≥85%), OR
2. All clarification markers are resolved, OR
3. User explicitly requests to proceed

**⚠️ NEVER proceed with coverage <60% automatically.**
If coverage remains below 60% after clarifications:
→ Ask user: "Coverage is {X}%. Continue gathering clarifications or proceed with warnings?"

The goal is a COMPLETE specification, not a fast one.

---

## Phase 5: PAL Consensus Gate

**Checkpoint:** `PAL_GATE`

### Step 5.1: Prepare PAL Evaluation

Read evaluation criteria from: `@$CLAUDE_PLUGIN_ROOT/templates/prompts/pal-spec-eval.md`

**Evaluation Dimensions (1-4 each):**
1. Business Value Clarity
2. Requirements Completeness
3. Scope Boundaries
4. Stakeholder Coverage
5. Technology Agnosticism

### Step 5.2: Execute PAL Consensus

**NOTE:** grok-4 included for additional variety. Continue gracefully if any model unavailable.

```python
mcp__pal__consensus(
    step="Evaluate specification for {FEATURE_NAME} against quality criteria",
    step_number=1,
    total_steps=2,
    next_step_required=True,
    findings="[Your independent analysis]",
    models=[
        {
            "model": "gemini-3-pro-preview",
            "stance": "neutral"
        },
        {
            "model": "gpt-5.2",
            "stance": "for",
            "stance_prompt": "Advocate for the specification strengths. Focus on completeness."
        },
        {
            "model": "x-ai/grok-4",  # Additional variety - continue if unavailable
            "stance": "against",
            "stance_prompt": "Challenge every assumption. Find hidden risks. Be skeptical of claimed coverage. Find what's missing."
        }
    ],
    relevant_files=["{SPEC_FILE}", "{CHECKLIST_FILE}"]
)
```

**⚠️ PAL Consensus Requirements:**
- Minimum **2 models** must respond for valid consensus
- If a model fails, notify user: `"⚠️ Model {MODEL} unavailable. Continuing with {N} models."`
- If only 1 model responds: **FAIL** consensus (see Step 5.2a)

### Step 5.2a: Handle Insufficient Models

**If fewer than 2 models respond:**

```
❌ PAL Consensus FAILED: Insufficient Models

Only {AVAILABLE} model(s) available. Minimum 2 required for consensus.

Available: {LIST_OF_WORKING_MODELS}
Unavailable: {LIST_OF_FAILED_MODELS}

Options:
1. Retry consensus (recommended) - will attempt to reconnect to models
2. Skip PAL validation (not recommended) - proceed without multi-model validation
3. Abort workflow - stop and investigate PAL/model issues
```

Use `AskUserQuestion` to present these options.

### Step 5.3: Process PAL Result

**Only process if ≥ 2 models responded:**

| Total Score | Agreement | Decision |
|-------------|-----------|----------|
| ≥16/20 | ≥80% | **APPROVED** → Phase 5.5 |
| 12-15/20 | 60-79% | **CONDITIONAL** → Phase 5.5 with warnings |
| <12/20 | <60% | **REJECTED** → Address gaps |

**If only 2 of 3 models responded, notify user:**
`"⚠️ PAL Consensus: 2/3 models responded. Results may have reduced variety."`

### Step 5.4: Handle REJECTED

If REJECTED (max 2 attempts):

**Task prompt:**

```markdown
{RESUME_CONTEXT}

## Task: Address PAL Feedback

PAL Consensus REJECTED the specification (Score: {SCORE}/20).

## Dissenting Views
{List feedback from PAL}

## Instructions
@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-address-gaps.md

Address EACH dissenting view with specific spec updates.
Preserve existing requirements. Add missing elements.
```

After update → Return to Step 5.2

### Step 5.5: Update State (CHECKPOINT)

```yaml
phases:
  pal_gate:
    pal_score: {score}
    pal_agreement_pct: {percentage}
    decision: "APPROVED|CONDITIONAL|REJECTED"
    dissenting_views: [list if any]
    iteration: {N}
```

---

## Phase 5.5: Design Feedback Generation (MANDATORY)

**Checkpoint:** `DESIGN_FEEDBACK`

**⚠️ CRITICAL RULE: BOTH design-brief.md AND design-feedback.md are MANDATORY and NEVER skipped.**
- Not for efficiency reasons
- Not for "simple" features
- Not even when Figma designs are "aligned" or unavailable

Every specification MUST have BOTH files generated:
- `design-brief.md` - Screen and state inventory from spec perspective
- `design-feedback.md` - Design analysis and recommendations

**Routing Logic (UPDATED - Both Files Always Required):**

| Condition | Action |
|-----------|--------|
| `figma_enabled = false` | Launch `design-brief-generator` AND `gap-analyzer` (spec-only analysis) |
| `figma_enabled = true` | Launch `design-brief-generator` AND `gap-analyzer` (with Figma context) |

### Step 5.5.1a: Design Brief (ALWAYS EXECUTED)

**Launch agent:** `design-brief-generator`

**MANDATORY** - This step is NEVER skipped regardless of Figma availability.

Pass context:
- `FEATURE_DIR`
- `SPEC_FILE`
- `CHECKLIST_FILE`
- `PLATFORM_TYPE`

Agent uses Sequential Thinking (6 thoughts) to:
1. Setup screen derivation problem
2. Inventory user stories
3. Identify required screens
4. Map state requirements
5. Integrate edge cases
6. Synthesize final inventory

**Output:** `{FEATURE_DIR}/design-brief.md` (REQUIRED)

### Step 5.5.1b: Design Feedback (ALWAYS EXECUTED)

**Launch agent:** `gap-analyzer`

**MANDATORY** - This step is NEVER skipped regardless of Figma availability.

Pass context:
- `FEATURE_DIR`
- `SPEC_FILE`
- `CHECKLIST_FILE`
- `FIGMA_CONTEXT_FILE` (if available, otherwise spec-only analysis)

Agent uses Sequential Thinking (6 thoughts) to:
1. Inventory requirements (FR-*, NFR-*, US-*, AC-*)
2. Inventory screens (from Figma if available, or derive from spec)
3. Forward mapping (Req → Screen) with confidence
4. Reverse mapping (Screen → Req) for orphans
5. Edge case gap analysis
6. Gap prioritization and recommendations

**PAL Validation** (triggered if any of these):
- LOW confidence mappings > 0
- P1 Critical gaps > 0
- Orphan screens > 2

```python
# PAL validation with multiple models for variety
mcp__pal__consensus(
    ...
    models=[
        {"model": "gemini-3-pro-preview", "stance": "neutral"},
        {"model": "gpt-5.2", "stance": "for"},
        {"model": "x-ai/grok-4", "stance": "against",
         "stance_prompt": "Challenge the design-spec correlation. Find missing screens."}
    ]
)
# NOTE: Continue if any model unavailable. Minimum 2 models required.
```

**Output:** `{FEATURE_DIR}/design-feedback.md`

### Step 5.5.2: Verify Outputs (MANDATORY CHECK)

**BEFORE proceeding to Phase 6, verify BOTH files exist:**

```bash
# MANDATORY - design-brief.md MUST exist
test -f {FEATURE_DIR}/design-brief.md || echo "BLOCKER: design-brief.md not generated"

# MANDATORY - design-feedback.md MUST exist (regardless of Figma)
test -f {FEATURE_DIR}/design-feedback.md || echo "BLOCKER: design-feedback.md not generated"
```

**If either file is missing:** DO NOT proceed. Re-run the missing step:
- Missing design-brief.md → Re-run Step 5.5.1a
- Missing design-feedback.md → Re-run Step 5.5.1b

### Step 5.5.3: Update State (CHECKPOINT)

```yaml
phases:
  design_feedback:
    type: "brief_and_analysis"  # Always both regardless of Figma
    design_brief_generated: true  # MANDATORY - must be true
    design_feedback_generated: true  # MANDATORY - must be true
    output_files:
      - "{FEATURE_DIR}/design-brief.md"  # REQUIRED (always)
      - "{FEATURE_DIR}/design-feedback.md"  # REQUIRED (always)
    screens_identified: {count}
    gaps_flagged: {count}
```

---

## Phase 5.7: Test Strategy Generation (V-Model)

**Checkpoint:** `TEST_STRATEGY`

**Purpose:** Generate comprehensive V-Model test strategy with AC → Test traceability BEFORE completion.

**Enabled by:** `feature_flags.enable_test_strategy` in config (default: true)

### Step 5.7.0: Check Test Strategy Enablement

```
IF config.feature_flags.enable_test_strategy == false:
    → SKIP to Phase 6
```

### Step 5.7.1: Gather Context Files

Collect all context needed for test strategy generation:

```bash
# Required files
SPEC_FILE="{FEATURE_DIR}/spec.md"
DESIGN_BRIEF_FILE="{FEATURE_DIR}/design-brief.md"

# Optional files (enhance test coverage if available)
FIGMA_CONTEXT_FILE="{FEATURE_DIR}/figma_context.md"  # For visual oracles
EDGE_CASES_REPORT=$(find {FEATURE_DIR}/analysis -name "mpa-edgecases*.md" 2>/dev/null | head -1)
DESIGN_FEEDBACK_FILE="{FEATURE_DIR}/design-feedback.md"
```

### Step 5.7.1b: Validate Required Inputs (MANDATORY CHECK)

**BEFORE launching QA Strategist, verify required files exist:**

```bash
# MANDATORY - spec.md MUST exist
test -f {FEATURE_DIR}/spec.md || echo "BLOCKER: spec.md not found"

# MANDATORY - design-brief.md MUST exist (from Phase 5.5)
test -f {FEATURE_DIR}/design-brief.md || echo "BLOCKER: design-brief.md not found"
```

**If either file is missing:** DO NOT proceed to Step 5.7.2. Handle as follows:
- Missing spec.md → Critical error. Return to Phase 2.
- Missing design-brief.md → Re-run Phase 5.5 (Step 5.5.1a)

**Only proceed when both required files exist.**

### Step 5.7.2: Launch QA Strategist Agent

**Task prompt:**

```markdown
{RESUME_CONTEXT}

## Task: Generate V-Model Test Strategy

Generate a comprehensive test plan following V-Model methodology with AC → Test traceability.

Feature: {FEATURE_NAME}
Feature Directory: {FEATURE_DIR}

## Context Files
- **Specification (REQUIRED)**: {SPEC_FILE}
- **Design Brief (REQUIRED)**: {DESIGN_BRIEF_FILE}
- **Figma Context (OPTIONAL)**: {FIGMA_CONTEXT_FILE or "Not available"}
- **Edge Cases Report (OPTIONAL)**: {EDGE_CASES_REPORT or "Not available"}
- **Design Feedback (OPTIONAL)**: {DESIGN_FEEDBACK_FILE}

## Test Strategy Configuration
Reference: @$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml → test_strategy

## Instructions

1. **Risk Analysis (Sequential Thinking - 2 thoughts)**
   - Identify failure modes: network, permissions, empty states, process death, config changes
   - Map critical user flows requiring E2E coverage

2. **Unit Test Planning (TDD)**
   - Define unit tests for ViewModels, UseCases, Repositories
   - Focus on business logic, state management, error handling
   - Pattern: Tests written BEFORE implementation

3. **Integration Test Planning**
   - Define integration tests for component boundaries
   - ViewModel ↔ Repository, Repository ↔ Database, Screen ↔ Navigation

4. **E2E Test Planning**
   - Define end-to-end tests for user journeys
   - Happy path, error scenarios, edge cases
   - Screenshot evidence at checkpoints

5. **Visual Test Planning**
   - Map visual oracles from Figma (if available) or design-brief
   - Define screen states requiring visual regression tests

6. **Traceability Matrix**
   - Map EVERY Acceptance Criterion to at least one test
   - Ensure 100% AC coverage across test levels

## Output
Write test plan to: {FEATURE_DIR}/test-plan.md
Template: @$CLAUDE_PLUGIN_ROOT/templates/test-plan-template.md

## Agent Reference
@$CLAUDE_PLUGIN_ROOT/agents/qa-strategist.md
```

### Step 5.7.3: Parse Agent Response

After QA Strategist agent completes, parse the structured response:

```yaml
# Expected response format
response:
  status: success | partial | error
  outputs:
    - file: "{FEATURE_DIR}/test-plan.md"
      action: created
  metrics:
    unit_tests_planned: {N}
    integration_tests_planned: {N}
    e2e_tests_planned: {N}
    visual_tests_planned: {N}
    acceptance_criteria_count: {N}
    acs_without_coverage: {N}  # Should be 0
    figma_integration: {true|false}
```

### Step 5.7.4: Validate Test Coverage

**Coverage Requirements:**
- All ACs must have at least one test (`acs_without_coverage == 0`)
- At least 1 unit test if business logic exists
- At least 1 E2E test for primary user flow
- Visual tests if UI screens exist

**If acs_without_coverage > 0:**

```json
{
  "questions": [{
    "question": "Test plan has {N} Acceptance Criteria without test coverage. How to proceed?",
    "header": "Coverage Gap",
    "multiSelect": false,
    "options": [
      {
        "label": "Add missing tests (Recommended)",
        "description": "Re-run QA Strategist to add tests for uncovered ACs"
      },
      {
        "label": "Proceed with gaps",
        "description": "Continue to completion with coverage warning"
      },
      {
        "label": "View gaps",
        "description": "Show which ACs lack test coverage"
      }
    ]
  }]
}
```

### Step 5.7.5: Verify Test Plan Output

```bash
# MANDATORY - test-plan.md MUST exist
test -f {FEATURE_DIR}/test-plan.md || echo "BLOCKER: test-plan.md not generated"
```

**If test-plan.md missing:** Re-run Step 5.7.2

### Step 5.7.6: Update State (CHECKPOINT)

```yaml
phases:
  test_strategy:
    status: completed
    timestamp: "{now}"
    output_file: "{FEATURE_DIR}/test-plan.md"
    metrics:
      unit_tests_planned: {N}
      integration_tests_planned: {N}
      e2e_tests_planned: {N}
      visual_tests_planned: {N}
      total_tests_planned: {N}
      acceptance_criteria_count: {N}
      acs_with_coverage: {N}
      acs_without_coverage: {N}
      coverage_percentage: {%}
      risk_areas_identified: {N}
      figma_integration: {true|false}
    validation:
      full_ac_coverage: {true|false}
      tdd_compliance: {true|false}
```

Append to Workflow Log:
```markdown
### {ISO_DATE} - Phase: TEST_STRATEGY
- **Action**: V-Model Test Strategy Generation
- **Outcome**: {SUCCESS|PARTIAL}
- **Tests Planned**: {N} total ({N} unit, {N} integration, {N} E2E, {N} visual)
- **AC Coverage**: {N}/{N} ({%})
- **Report**: test-plan.md
```

---

## Phase 6: Completion

**Checkpoint:** `COMPLETE`

### Step 6.1: Generate Completion Report

```markdown
# ✅ Specification Complete: {FEATURE_NAME}

## Summary
| Metric | Value |
|--------|-------|
| Feature ID | {NUMBER}-{SHORT_NAME} |
| PAL Score | {PAL_SCORE}/20 ({PAL_DECISION}) |
| Checklist Coverage | {COVERAGE}% |
| Clarifications | {CLARIFICATION_COUNT} |
| Figma Integration | {FIGMA_ENABLED ? "Yes" : "No"} |

## Generated Artifacts
- `{FEATURE_DIR}/spec.md` - Feature specification
- `{FEATURE_DIR}/spec-checklist.md` - Validation checklist
- `{FEATURE_DIR}/design-brief.md` - Design brief (ALWAYS generated)
- `{FEATURE_DIR}/design-feedback.md` - Design analysis (ALWAYS generated)
- `{FEATURE_DIR}/test-plan.md` - V-Model test strategy (ALWAYS generated)
{IF figma_context.md: - `{FEATURE_DIR}/figma_context.md` - Figma context}

## Next Steps
1. Review specification with stakeholders
2. Review test plan for TDD compliance
3. Run `/sdd:02-plan` to create architecture plan
4. {IF test coverage gaps: Address test coverage gaps in test-plan.md}
5. {IF design gaps flagged: Address design gaps before implementation}
```

### Step 6.2: Release Lock

```bash
rm -f {LOCK_FILE}
echo "✓ Workflow lock released"
```

### Step 6.3: Final State Update

```yaml
current_phase: "COMPLETE"
phase_status: "completed"
completed_at: "{ISO_DATE}"
```

Append to Workflow Log:
```markdown
### {ISO_DATE} - Phase: COMPLETE
- **Outcome**: SUCCESS
- **PAL Score**: {PAL_SCORE}/20
- **Test Plan**: {TOTAL_TESTS} tests planned ({AC_COVERAGE}% AC coverage)
- **Artifacts**: spec.md, spec-checklist.md, design-brief.md, design-feedback.md, test-plan.md
```

---

## ⚠️ UNIFIED CHECKPOINT PROTOCOL (P4 - High Attention Zone)

**Single Source of Truth:** State file ONLY. Lock file tracks liveness, NOT phase.

**Reference:** `$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` → `checkpoint_protocol` section

**After EVERY phase completion, you MUST:**

### 1. Update State File (MANDATORY)

```yaml
# In {STATE_FILE} YAML frontmatter
current_phase: "{PHASE_NAME}"
phase_status: "completed"
updated: "{ISO_TIMESTAMP}"
next_step: "{DESCRIPTION_OF_NEXT_ACTION}"

phases:
  {phase_name}:  # e.g., spec_draft, gate_1_problem, checklist_validation
    status: completed
    timestamp: "{ISO_TIMESTAMP}"
    outputs:
      - file: "{path}"
        action: created | updated
    metrics:
      # Phase-specific metrics
      score: {N}
      items_count: {N}
```

### 2. Update Lock File (Liveness ONLY)

```yaml
# Lock file tracks ONLY session liveness, not workflow state
locked_at: {original_timestamp}
feature: {FEATURE_NAME}
last_activity: "{ISO_TIMESTAMP}"  # Update this on each action
pid: $$
```

**Note:** `phase` field REMOVED from lock file. State file is authoritative.

### 3. Append to Workflow Log

```markdown
### {ISO_DATE} - Phase: {PHASE_NAME}
- **Action**: {WHAT_WAS_DONE}
- **Outcome**: SUCCESS | PARTIAL | ERROR
- **Key Outputs**: {FILES_OR_DECISIONS}
- **Metrics**: {KEY_METRICS if applicable}
```

### 4. User Decisions (IMMUTABLE once recorded)

```yaml
user_decisions:
  {decision_key}: "{user_selected_value}"
  {decision_key}_timestamp: "{ISO_TIMESTAMP}"
```

**DEPRECATED (P4):**
- ~~HTML comment checkpoints in agent output~~: `<!-- CHECKPOINT: X -->`
- ~~Phase tracking in lock file~~: `phase: X`

**NEVER skip state file update.** Resume capability depends on accurate state.

---

## Error Handling

### Build/Tool Errors

If any tool call fails:
1. Log error to state file `error_log` section
2. Offer recovery options via AskUserQuestion
3. If recoverable: retry or skip
4. If critical: abort with clear message

### PAL Service Unavailable

If `mcp__pal__consensus` fails:
1. Log: "PAL service unavailable"
2. Offer options:
   - Retry (wait and try again)
   - Skip PAL (proceed without validation - add warning)
   - Manual review (show spec, ask user to validate)

### Figma Service Unavailable

Handled by `specify-figma-capture` skill with recovery options.

---

## Template & Config References (Progressive Disclosure)

### Configuration (Load at Start)

| Config | Purpose |
|--------|---------|
| `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml` | All limits, thresholds, feature flags |
| `@$CLAUDE_PLUGIN_ROOT/templates/agent-response-schema.md` | Structured response format (P6) |

### Templates (Load When Phase Reached)

| Template | Phase | Purpose |
|----------|-------|---------|
| `@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-spec-draft.md` | Phase 2 | Spec generation instructions |
| `@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-validate.md` | Phase 4 | Validation criteria |
| `@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-clarify.md` | Phase 4.5 | Question generation |
| `@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-update-spec.md` | Phase 4.5 | Spec update instructions |
| `@$CLAUDE_PLUGIN_ROOT/templates/prompts/ba-address-gaps.md` | Phase 5 | PAL rejection handling |
| `@$CLAUDE_PLUGIN_ROOT/templates/prompts/pal-spec-eval.md` | Phase 5 | PAL evaluation criteria |
| `@$CLAUDE_PLUGIN_ROOT/templates/prompts/resume-context-builder.md` | Phase 0 | Resume context template |

### New Phase Templates (P2 Incremental Gates)

| Template | Phase | Purpose |
|----------|-------|---------|
| Config: `incremental_gates.gate_1_problem_quality` | Phase 2.5 | Problem quality evaluation criteria |
| Config: `incremental_gates.gate_2_true_need` | Phase 2.7 | True need validation criteria |

---

## Agent References

| Agent | When Used | Purpose |
|-------|-----------|---------|
| `design-brief-generator` | Phase 5.5 (no Figma) | Generate design briefs via Sequential Thinking |
| `gap-analyzer` | Phase 5.5 (with Figma) | Correlate designs with spec, find gaps |
| `business-analyst` | Phases 2, 4, 4.5 | Core BA work (spec, validate, clarify) |

---

## Skill References

| Skill | When Used | Purpose |
|-------|-----------|---------|
| `specify-figma-capture` | Phase 1.5 | Figma integration with error handling |
| `specify-clarification` | Phase 4.5 | Question batching with BA recommendations |
| `mpa-synthesizer` | Phase 2.3, 4.3 | Parallel model synthesis for MPA |

---

## MPA Framework References

### Configuration

| Config | Purpose |
|--------|---------|
| `@$CLAUDE_PLUGIN_ROOT/config/specify-config.yaml → thinkdeep` | MPA master config |
| `thinkdeep.integrations.challenge` | Phase 2.3 config |
| `thinkdeep.integrations.edge_cases` | Phase 4.3 config |
| `thinkdeep.integrations.triangulation` | Phase 4.6 config |
| `thinkdeep.cost_control` | Budget presets and limits |

### Templates (Analysis Output)

| Template | Phase | Purpose |
|----------|-------|---------|
| `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-challenge.md` | 2.3 | Single-model challenge report |
| `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-challenge-parallel.md` | 2.3 | Parallel-model challenge report |
| `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-edgecases.md` | 4.3 | Single-model edge cases |
| `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-edgecases-parallel.md` | 4.3 | Parallel-model edge cases |
| `@$CLAUDE_PLUGIN_ROOT/templates/analysis/mpa-triangulation.md` | 4.6 | Question triangulation report |

### Tools

| Tool | Purpose |
|------|---------|
| `mcp__pal__thinkdeep` | Extended reasoning from external models |
| `mcp__pal__consensus` | Multi-model voting (used in Phase 5) |
