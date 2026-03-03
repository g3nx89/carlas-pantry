---
lens: "Writing Quality & Conciseness"
lens_id: "writing"
skill: "feature-planning"
skill_path: "plugins/product-planning/skills/plan"
skill_reference: "docs:write-concisely"
fallback_used: false
date: "2026-03-01"
findings_count: 12
severity_breakdown:
  critical: 0
  high: 2
  medium: 5
  low: 3
  info: 2
---

# Writing Quality & Conciseness Analysis

**Skill:** feature-planning (`plugins/product-planning/skills/plan`)
**Lens:** Writing Quality & Conciseness (via `docs:write-concisely` — Strunk's *The Elements of Style*)
**Date:** 2026-03-01

## Files Reviewed

| File | Lines | Role |
|------|-------|------|
| `SKILL.md` | 293 | Primary orchestrator entry point |
| `references/orchestrator-loop.md` | 404 | Dispatch loop, crash recovery, state migration |
| `references/phase-1-setup.md` | 460 | Inline setup phase instructions |

---

## Strengths

### S1. Lean Dispatch Table Design
**File:** `SKILL.md` (lines 129-142)

The Phase Dispatch Table is a model of concise technical writing. Each row communicates six dimensions (delegation type, file, prior summaries, user interaction, CLI role, checkpoint) without a single wasted word. The table format replaces what would otherwise be dozens of verbose paragraphs. This exemplifies Strunk's Rule 13: "Omit needless words."

### S2. Consistent Imperative Voice in Pseudocode
**File:** `references/phase-1-setup.md`

The pseudocode blocks use direct imperative verbs consistently: VERIFY, GET, ASK, CREATE, CHECK, SET, LOG, COPY. This active, commanding voice avoids the passive constructions that plague many technical specification documents. Each instruction tells the executor exactly what to do.

### S3. Effective Use of ASCII Diagrams
**File:** `SKILL.md` (lines 73-119)

The V-Model workflow diagram conveys the entire 11-phase architecture and its test-level mapping in a single visual. This replaces what would require several paragraphs of prose, and readers grasp the structure immediately.

---

## Findings

### F1. Bloated Introductory Sentence in SKILL.md Description
**Severity:** MEDIUM
**Category:** Omit needless words (Strunk Rule 13)
**File:** `SKILL.md` (line 3)

**Current state:**
> `This skill should be used when the user asks to "plan a feature", "create an implementation plan", "design the architecture", "break down a feature into tasks", "decompose a specification", "plan development", "plan tests", or needs multi-perspective analysis for feature implementation.`

This 47-word sentence in the YAML `description` field lists seven trigger phrases. The trailing clause ("or needs multi-perspective analysis for feature implementation") shifts voice from concrete triggers to abstract capability description.

**Recommendation:** Trim to the most distinctive triggers. The matching engine does not need exhaustive synonyms:
```
description: Plan features into actionable implementation tasks with architecture design, V-Model test strategy, and multi-perspective analysis. Triggers on "plan a feature", "design the architecture", "break down tasks", or "plan tests".
```

---

### F2. Passive Voice in Critical Rules
**Severity:** MEDIUM
**Category:** Active voice (Strunk Rule 10)
**File:** `SKILL.md` (lines 44-54)

**Current state:**
- Rule 1: "Checkpoint after user decisions. User decisions are IMMUTABLE once saved."
- Rule 8: "Delegated phases execute via `Task(subagent_type="general-purpose")` coordinators."
- Rule 9: "Between phases, read ONLY summary files..."
- Rule 11: "The orchestrator injects a requirements digest..."

Rules 1 and 8 use passive constructions ("are IMMUTABLE once saved," "phases execute via"). Rules are commands — they should command.

**Recommendation:** Rewrite in imperative active voice:
- Rule 1: "Checkpoint after every user decision. Never overwrite a saved user decision."
- Rule 8: "Delegate phases via `Task(subagent_type="general-purpose")` coordinators. Execute Phase 1 inline. Execute Phase 3 inline for Standard/Rapid."

---

### F3. Verbose CLI Dispatch Paragraph
**Severity:** HIGH
**Category:** Omit needless words (Strunk Rule 13)
**File:** `SKILL.md` (lines 67-68)

**Current state:**
> `CLI Multi-CLI Dispatch (Complete/Advanced): When cli_custom_roles is enabled and CLI tools are installed, phases 5, 6, 6b, 7, and 9 run supplemental analysis via Gemini + Codex + OpenCode in parallel using Bash process-group dispatch (scripts/dispatch-cli-agent.sh), then synthesize and self-critique findings. Each CLI brings a different lens: Gemini (strategic/broad), Codex (code-level/challenger), OpenCode (UX/product). Tri-CLI synthesis uses unanimous (VERY HIGH), majority (HIGH), and divergent (FLAG) confidence levels. This adds ~6-9 min total latency but provides broader coverage.`

This 82-word paragraph packs three separate ideas into a single block: (1) what triggers dispatch, (2) what each CLI does, (3) synthesis logic. The opening uses "CLI Multi-CLI Dispatch" — redundant naming. The sentence "This adds ~6-9 min total latency but provides broader coverage" is a loose justification that belongs in trade-off documentation, not in the dispatch specification.

**Recommendation:** Split into a compact table or three short sentences:
```
**CLI Dispatch** (Complete/Advanced, requires `cli_custom_roles`):
Phases 5, 6, 6b, 7, 9 dispatch Gemini + Codex + OpenCode in parallel via `scripts/dispatch-cli-agent.sh`.

| CLI | Lens |
|-----|------|
| Gemini | Strategic/broad |
| Codex | Code-level/challenger |
| OpenCode | UX/product |

Synthesis: unanimous = VERY HIGH, majority = HIGH, divergent = FLAG. Adds ~6-9 min latency.
```

---

### F4. Filler Phrase "It is worth noting" Pattern
**Severity:** LOW
**Category:** Omit needless words (Strunk Rule 13)
**File:** `references/orchestrator-loop.md` (line 374)

**Current state:**
> `Non-breaking: all existing v1 fields are preserved. Orchestrator continues from last checkpoint.`

While this specific instance is reasonably concise, the file uses explanatory asides that state the obvious. Line 374 tells the reader what the migration does after 20 lines of pseudocode already demonstrated it. If the code shows it, the prose need not repeat it.

**Recommendation:** Delete the trailing explanation. The pseudocode already shows fields are preserved.

---

### F5. Synonym Churn: "Coordinator" vs. "Phase" vs. "Stage"
**Severity:** HIGH
**Category:** Consistent terminology
**File:** `SKILL.md`, `references/orchestrator-loop.md`

**Current state:**
- SKILL.md uses "phases" (line 71: "Workflow Phases"), "coordinator" (line 188: "coordinator dispatch"), and "delegation" (line 128: "Phase Dispatch Table")
- orchestrator-loop.md uses "coordinator" (line 190: "DISPATCH_COORDINATOR"), "phase" throughout, and "stage" never appears

The terms "phase" and "coordinator" refer to different things (the workflow step vs. the subagent executing it), but the text sometimes conflates them. Line 68 in orchestrator-loop.md says "RE-DISPATCH_COORDINATOR(phase)" — the function takes a phase identifier but is named after the coordinator. This is not a synonym problem per se, but the prose frequently switches between "dispatch a phase" and "dispatch a coordinator" when describing the same action.

**Recommendation:** Establish a consistent lexicon in SKILL.md's Critical Rules section:
- "Phase" = a workflow step (Phase 1, Phase 2, etc.)
- "Coordinator" = the subagent that executes a phase
- "Dispatch" = sending a coordinator to execute a phase

Then audit all prose to use "dispatch the Phase N coordinator" rather than alternating between "dispatch Phase N" and "dispatch coordinator for Phase N."

---

### F6. Redundant Explanation in Architecture Decision Record
**Severity:** MEDIUM
**Category:** Omit needless words (Strunk Rule 13)
**File:** `references/orchestrator-loop.md` (lines 387-403)

**Current state:**
> `Alternative considered: On-demand inline loading — orchestrator reads and executes each phase file directly, dropping context between phases. This achieves the same context reduction (336-838 lines per phase) without delegation overhead.`
>
> `Why delegation was chosen:`
> `- Fault isolation: coordinator crash does not crash orchestrator`
> `- Enables future parallelism (e.g., Phase 7 QA agents could use different model tiers)`
> `- Clean separation via summary contract enforces explicit inter-phase communication`

The ADR section spans 17 lines for a decision that three bullet points already justify. "Alternative considered" restates what anyone reading "delegation vs inline loading" already understands. "This achieves the same context reduction (336-838 lines per phase) without delegation overhead" is an aside that undermines the chosen approach.

**Recommendation:** Cut to the essentials:
```
## ADR: Coordinator Delegation

**Chosen:** `Task(general-purpose)` delegation over inline loading.

**Reasons:** fault isolation, future parallelism, explicit summary contracts.

**Trade-off:** 5-15s latency per dispatch (~40-120s cumulative). Consider inline for non-interactive phases if overhead becomes problematic.
```

---

### F7. Loose Sentence Chains in Phase 1 Steps
**Severity:** MEDIUM
**Category:** Avoid loose sentences (Strunk Rule 14)
**File:** `references/phase-1-setup.md` (lines 179-230)

**Current state (Step 1.5c):**
> `Purpose: Detect whether the dev-skills plugin is installed and which skill domains are relevant to this feature based on spec.md content and codebase markers.`

This 29-word purpose statement could be halved. The pseudocode block that follows (50 lines) already demonstrates exactly what the step detects. Purpose statements should orient the reader, not preview the implementation.

Similar pattern at Step 1.5d (line 234):
> `Purpose: Detect algorithm/math complexity keywords in spec.md that may warrant deep reasoning escalation in later phases. This is detection only — no escalation happens in Phase 1. The orchestrator uses this flag when quality gates fail in Phase 4, 6, or 7.`

Three sentences where one suffices.

**Recommendation:**
- Step 1.5c: "Detect installed dev-skills domains relevant to this feature."
- Step 1.5d: "Scan spec.md for algorithm keywords (detection only; escalation happens at gate failures)."

---

### F8. "The fact that" Pattern in Requirements Digest
**Severity:** LOW
**Category:** Omit needless words (Strunk Rule 13)
**File:** `references/orchestrator-loop.md` (lines 241-245)

**Current state:**
> `This ensures every coordinator has baseline visibility into the original requirements, even if the phase file doesn't list spec.md in artifacts_read.`

The clause "even if the phase file doesn't list spec.md in artifacts_read" explains an edge case that the code handles by design. It adds 13 words to justify what the injection mechanism already guarantees.

**Recommendation:** "Injects the requirements digest into every coordinator dispatch prompt." The code speaks for itself.

---

### F9. Overlong Deep Reasoning Escalation Block
**Severity:** MEDIUM
**Category:** Conciseness / Omit needless words
**File:** `references/orchestrator-loop.md` (lines 80-141)

**Current state:**
The gate failure handling block spans 62 lines of pseudocode with deeply nested conditionals (4 levels of IF). Each branch includes inline comments that re-explain what the variable names already convey (e.g., `# Determine escalation type (specific beats generic)` before an IF-ELIF chain that demonstrates exactly that).

**Recommendation:**
1. Extract the escalation type determination into a named function: `DETERMINE_ESCALATION_TYPE(phase, state, config) -> (type, flag, template, target_phase)`
2. Remove inline comments that merely narrate the code. Let the function and variable names carry the meaning.
3. This would reduce the block from 62 lines to approximately 25.

---

### F10. Inconsistent Bullet Formatting in Error Handling
**Severity:** LOW
**Category:** Express coordinate ideas in similar form (Strunk Rule 15)
**File:** `SKILL.md` (lines 277-283)

**Current state:**
```
- **Missing prerequisites** - Provide guidance to create spec.md
- **MCP unavailable** - Graceful degradation to simpler modes
- **Agent failure** - Retry once, then continue with partial results
- **Lock conflict** - Wait or manual intervention guidance
- **RED gates** - Loop back (Phase 6 RED -> Phase 4, Phase 8 RED -> Phase 7)
- **Coordinator crash** - See orchestrator-loop.md for crash recovery and summary reconstruction
```

Some entries describe an action ("Retry once"), others describe an outcome ("Graceful degradation"), and one delegates to another file ("See orchestrator-loop.md"). Parallel construction (Strunk Rule 15) requires that coordinate items share the same grammatical form.

**Recommendation:** Use consistent verb-first form:
```
- **Missing prerequisites** - Guide user to create spec.md
- **MCP unavailable** - Degrade to simpler modes
- **Agent failure** - Retry once, then continue with partial results
- **Lock conflict** - Wait or guide manual intervention
- **RED gates** - Loop back (Phase 6 -> Phase 4, Phase 8 -> Phase 7)
- **Coordinator crash** - Reconstruct summary from artifacts (see orchestrator-loop.md)
```

---

### F11. Emphatic Words Buried Mid-Sentence
**Severity:** INFO
**Category:** Place emphatic words at end (Strunk Rule 18)
**File:** `SKILL.md` (line 40)

**Current state:**
> `Transform feature specifications into actionable implementation plans with integrated test strategy. This orchestrator delegates phases to coordinator subagents, reading only standardized summary files between phases.`

The emphatic concept — "reading only standardized summary files between phases" — sits at the end of the second sentence, which is correct. However, the first sentence buries the key differentiator ("integrated test strategy") behind a prepositional phrase. The most important word should close the sentence.

**Recommendation:**
> `Transform feature specifications into implementation plans with integrated test strategy.`

Remove "actionable" — all implementation plans imply action. This places "test strategy" at the sentence's emphatic close.

---

### F12. Effective Brevity in Summary Convention
**Severity:** INFO
**Category:** Positive observation
**File:** `SKILL.md` (lines 164-168)

**Current state:**
```
- **Path:** `{FEATURE_DIR}/.phase-summaries/phase-{N}-summary.md`
- **Template:** `$CLAUDE_PLUGIN_ROOT/templates/phase-summary-template.md`
- **Size:** 30-80 lines (YAML frontmatter + markdown)
- **Critical section:** "Context for Next Phase" — this is what the next coordinator reads to understand priorities
```

Four bullets. Each begins with a bold label and delivers one fact. No filler. This section demonstrates that the authors can write concisely when the format encourages it. The rest of the skill would benefit from applying this same density.

---

## Summary

The feature-planning skill demonstrates strong structural writing — tables, pseudocode blocks, and ASCII diagrams communicate effectively. The main weakness is **prose density in explanatory passages**: purpose statements, inline comments, and justification paragraphs that restate what the code already shows. Strunk's Rule 13 ("Omit needless words") applies most frequently.

The two HIGH findings (F3 and F5) address a verbose dispatch paragraph that should be a table, and inconsistent terminology that forces readers to map between "phase" and "coordinator" mentally. Fixing these would improve both scannability and comprehension.

The five MEDIUM findings target redundant purpose statements, passive voice in rules, loose sentence chains, and an overlong pseudocode block. Together, addressing these could reduce total prose by an estimated 15-20% without losing any essential meaning.

**Priority order for remediation:**
1. F5 (terminology consistency) — affects the entire skill
2. F3 (CLI dispatch paragraph) — most-read section, highest information density deficit
3. F2 (passive voice in rules) — rules should command
4. F7 (purpose statement bloat) — quick wins across phase files
5. F6, F9 (orchestrator-loop verbosity) — reduces reference file size
