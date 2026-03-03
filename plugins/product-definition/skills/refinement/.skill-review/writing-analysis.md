---
skill: feature-refinement
version: 3.0.0
lens: Writing Quality & Conciseness
analyst: claude-opus-4-6
date: 2026-03-01
criteria_source: "docs:write-concisely (Strunk Elements of Style)"
files_analyzed:
  - SKILL.md (17,117 bytes)
  - references/orchestrator-loop.md (17,699 bytes)
  - references/stage-3-analysis-questions.md (19,540 bytes)
  - references/stage-1-setup.md (16,851 bytes)
finding_count: 14
severity_breakdown:
  CRITICAL: 0
  HIGH: 3
  MEDIUM: 5
  LOW: 4
  INFO: 2
---

# Writing Quality & Conciseness Analysis: feature-refinement v3.0.0

## Summary

The feature-refinement skill is a well-structured, technically precise document set. Its greatest writing strength is its consistent use of imperative voice in instructions and its clean tabular presentation of structured data. However, several recurring patterns inflate word count without adding meaning: redundant emphasis phrases ("MUST follow", "ALWAYS", "NEVER") appear alongside identical structural conventions (bold, caps, numbered rules) that already signal importance; explanatory asides repeat information available in other sections; and passive voice surfaces in descriptive passages where active voice would be more direct. The skill could shed approximately 15-20% of its prose without losing any essential meaning.

---

## Findings

### HIGH Severity

#### 1. Redundant Emphasis Stacking

**Category:** Needless words / Omit needless words (Strunk Rule 13)

**Current state:** The skill layers multiple emphasis mechanisms on the same instruction. Bold text, ALL CAPS, and intensifiers like "MUST", "ALWAYS", "NEVER", "MANDATORY" frequently co-occur. For example:

- SKILL.md line 19: `**State Preservation**: ALWAYS checkpoint after user decisions via state file update`
- SKILL.md line 22: `**PRD Unique**: Only ONE PRD.md exists`
- stage-1-setup.md line 14: `**Pre-flight validation MUST pass**: If ANY required agent or config file is MISSING, ABORT immediately. Do NOT proceed with partial setup.`

In the last example, "MUST pass" + "ANY" + "MISSING" + "ABORT immediately" + "Do NOT proceed" delivers the same instruction five ways. The numbered rule placement inside "CRITICAL RULES" already signals high importance.

**Recommendation:** Choose one emphasis mechanism per instruction. Inside a "CRITICAL RULES" section, bold formatting alone suffices. Reserve ALL CAPS for a single keyword per rule (the verb). Rewrite the pre-flight rule as: `**Pre-flight validation**: Abort if any required agent or config file is missing.`

**File:** SKILL.md (lines 16-53), stage-1-setup.md (lines 13-18), stage-3-analysis-questions.md (lines 13-19)

---

#### 2. Parenthetical Asides That Restate Obvious Context

**Category:** Needless words / Omit needless words (Strunk Rule 13)

**Current state:** Parenthetical clarifications frequently restate what the surrounding text already implies or what adjacent tables define:

- orchestrator-loop.md line 40: `dispatch a coordinator subagent using the **per-stage dispatch profile** from config (`token_budgets.stage_dispatch_profiles`). Each stage loads ONLY the shared references it needs.` -- The second sentence restates what "per-stage dispatch profile" means.
- SKILL.md line 91: `Panel composition is set in Stage 1 via the Panel Builder and persisted in `requirements/.panel-config.local.md`. Users validate the panel before question generation begins.` -- The first sentence restates information in the Stage Dispatch Table (line 140). The second sentence restates Stage 1 Step 1.7.5.
- orchestrator-loop.md line 246: `**Design rationale:** These checks are non-blocking to avoid halting the workflow for minor issues. The user is notified and can address issues after completion. Critical issues (RED validation, missing PRD) are already caught by Stage 5's validation logic.` -- Three sentences to say "non-blocking by design."
- stage-1-setup.md lines 90-91: `Use AskUserQuestion directly (Stage 1 runs inline in the orchestrator):` -- The parenthetical repeats what line 12 already states.

**Recommendation:** Delete parenthetical restatements when the information exists in a table, heading, or prior paragraph within the same file. For cross-file context, a single brief cross-reference ("see Stage Dispatch Table") is sufficient. The design rationale block should read: `**Design rationale:** Non-blocking. Users address issues after completion; Stage 5 catches critical failures.`

**File:** SKILL.md (line 91), orchestrator-loop.md (lines 40, 246, 354, 460-462), stage-1-setup.md (lines 90, 135)

---

#### 3. Repeated Rule Blocks Across Files

**Category:** Needless words / Conciseness (Strunk Rule 13)

**Current state:** The "CRITICAL RULES" pattern appears at both the top and bottom of SKILL.md (lines 16-54 and 365-374) and again at the top and bottom of each stage reference file. The end-of-file repetition in SKILL.md paraphrases rules already stated in full at the top. Stage-3 lines 524-528 repeat rules from lines 13-19. Stage-1 lines 483-486 repeat rules from lines 13-18.

The end-of-SKILL.md block (lines 365-374) restates seven rules in bullet form that are numbered in full at lines 16-53. This doubles the rule surface area.

**Recommendation:** Replace end-of-file rule repetitions with a single line: `Rules 1-27 apply. See "CRITICAL RULES" at top of file.` For stage reference files, keep only the top-of-file rules block and end with: `Self-verification checklist above is mandatory.` This cuts approximately 40 lines across the four files analyzed.

**File:** SKILL.md (lines 365-374), stage-3-analysis-questions.md (lines 523-528), stage-1-setup.md (lines 483-486)

---

### MEDIUM Severity

#### 4. Passive Voice in Descriptive Passages

**Category:** Active voice (Strunk Rule 10)

**Current state:** Instructional passages predominantly use active voice, but descriptive and explanatory passages drift into passive constructions:

- SKILL.md line 91: `Panel composition is set in Stage 1 via the Panel Builder and persisted in...` (passive x2)
- orchestrator-loop.md line 166: `After each coordinator returns, read its validated summary and act:` (active -- good)
- orchestrator-loop.md line 195-196: `After stages that produce user-facing artifacts, the orchestrator performs a lightweight quality check on the coordinator's output. This supplements the coordinator's internal self-verification.` (active, then passive-adjacent with "This supplements")
- stage-1-setup.md line 7: `- requirements/.panel-config.local.md (conditional -- absent in rapid mode)` (passive participial)

**Recommendation:** Rewrite passive descriptions: `The Panel Builder sets panel composition in Stage 1 and persists it in...` Where the agent of the action is clear from context, use it as the subject.

**File:** SKILL.md (line 91), orchestrator-loop.md (lines 195-196), stage-1-setup.md (line 7)

---

#### 5. Verbose Conditional Blocks

**Category:** Conciseness / Omit needless words (Strunk Rule 13)

**Current state:** Conditional logic blocks use natural-language padding around what are essentially pseudocode conditionals:

- orchestrator-loop.md lines 155-159:
  ```
  IF any required field is missing or malformed:
      LOG warning: "Stage {N} summary has missing/malformed fields: {list}"
      IF status field is present and valid:
          PROCEED with available data (best-effort)
      ELSE:
          TREAT as crash (see Crash Recovery below)
  ```
  The `(best-effort)` parenthetical is unnecessary; "PROCEED with available data" already implies best-effort.

- stage-3-analysis-questions.md lines 26-33: Mode check uses 8 lines for what could be 3:
  ```
  IF ANALYSIS_MODE in {standard, rapid}: Skip Part A
  IF PAL_AVAILABLE = false: Skip Part A (graceful degradation)
  OTHERWISE: Continue to Step 3A.2
  ```

**Recommendation:** Tighten pseudocode blocks. Remove trailing commentary that restates the action. The mode check should be a flat 3-line block without the arrow notation and blank lines.

**File:** orchestrator-loop.md (lines 142-159), stage-3-analysis-questions.md (lines 26-33)

---

#### 6. "If ... Otherwise ... " Chains Where Tables Would Serve Better

**Category:** Clarity / Definite, specific, concrete language (Strunk Rule 12)

**Current state:** stage-1-setup.md Step 1.4 (lines 113-160) uses a long if/else chain with Cases A-D. Each case has a condition, action, and sometimes a sub-UI prompt. The narrative format makes it hard to scan.

**Recommendation:** Convert Cases A-D to a decision table:

| Condition | Action |
|-----------|--------|
| Draft provided, no state | NEW workflow, proceed to 1.6 |
| State exists, waiting_for_user | Resume to pause stage |
| PRD exists, no state | Ask user: extend / regenerate / review |
| No args, no state, no PRD | Show instructions, exit |

Follow the table with the AskUserQuestion JSON for Case C only (the one requiring user interaction).

**File:** stage-1-setup.md (lines 113-160)

---

#### 7. Synonym Churn for "Skip" / "Bypass" / "Omit"

**Category:** Terminology consistency

**Current state:** The skill uses several synonyms for the same concept of not executing a step:

- "Skip Part A entirely" (stage-3, line 27)
- "Skip Part A (graceful degradation)" (stage-3, line 30)
- "Skip synthesis" (stage-3, line 431)
- "SKIP" (orchestrator-loop, line 25)
- "Skip remaining steps" (stage-3, line 115)
- "Skip Panel Builder dispatch" (stage-1, line 256)
- "Skip to Step 1.8" (stage-1, line 210)
- "Skip steps 4-7, proceed to step 8" (stage-1, line 328)

While "skip" is the dominant term (good), "omit" and "bypass" appear in other reference files. The verb "proceed" sometimes means "skip to" and sometimes means "continue normally."

**Recommendation:** Standardize on "skip" for conditional omission and "proceed" exclusively for forward continuation. Avoid "bypass" and "omit" for control flow.

**File:** stage-3-analysis-questions.md, stage-1-setup.md, orchestrator-loop.md (various lines)

---

#### 8. Filler Phrases Before Imperatives

**Category:** Needless words (Strunk Rule 13)

**Current state:** Several instructions open with filler before the action verb:

- orchestrator-loop.md line 460: `Full procedures are in a separate reference file to keep the core dispatch loop lean.` -- "to keep the core dispatch loop lean" is a rationale, not an instruction.
- stage-3-analysis-questions.md line 248: `This ensures questions target specific aspects rather than addressing broad sections in one pass.` -- The preceding sentence already says "decompose complex PRD sections into sub-problems." The follow-up just restates the purpose.
- orchestrator-loop.md line 118: `Every dispatch variable MUST have a defined fallback to prevent malformed coordinator prompts:` -- "to prevent malformed coordinator prompts" restates why fallbacks exist, which the table already demonstrates.

**Recommendation:** Delete trailing rationale clauses when the instruction is self-evident. `Full procedures: see recovery-migration.md.` The decomposition rationale sentence (line 248) should be deleted entirely.

**File:** orchestrator-loop.md (lines 118, 460), stage-3-analysis-questions.md (line 248)

---

### LOW Severity

#### 9. Inconsistent Heading Capitalization

**Category:** Consistency

**Current state:** Most headings use title case (`## Coordinator Dispatch`, `## Summary Handling`), but some use sentence case (`## Self-Verification (MANDATORY before writing summary)` at stage-3 line 514) and others mix (`### ENTRY_TYPE Variable` at orchestrator-loop line 108, which uses all-caps for a code identifier but sentence case for the rest).

**Recommendation:** Standardize on title case for all headings. Code identifiers in headings should remain in their natural case (e.g., `### The ENTRY_TYPE Variable`).

**File:** All four files analyzed.

---

#### 10. Unnecessary "Note:" and "Key Rule:" Labels

**Category:** Needless words (Strunk Rule 13)

**Current state:** Callout labels like "**Key Rule:**", "**Cost note:**", "**Key points:**", "**Note:**" appear before sentences that would stand alone without the label:

- stage-3 line 233: `**Key Rule:** Divergence between models/perspectives = HIGH PRIORITY questions.`
- stage-3 line 202: `> **Cost note:** Each perspective x model now uses 3 multi-step calls instead of 1.`
- stage-3 line 43: `**Key points:**` followed by a bullet list

**Recommendation:** Drop the label when the sentence is already visually distinct (blockquote, bold, or bullet). Reserve "Note:" for genuine asides that interrupt the main instruction flow.

**File:** stage-3-analysis-questions.md (lines 43, 202, 233)

---

#### 11. "The" Before Proper Nouns in the System

**Category:** Needless words

**Current state:** Articles before system-specific proper nouns add unnecessary length:

- "the Panel Builder" (stage-1, passim) -- 14 occurrences
- "the orchestrator" (SKILL.md, orchestrator-loop.md, passim) -- 20+ occurrences
- "the coordinator" (orchestrator-loop.md, passim)

In a technical spec where these are defined roles, the article is unnecessary after first use.

**Recommendation:** Use the article on first mention within a section, then drop it. Write "Panel Builder analyzes the draft" rather than "The Panel Builder analyzes the draft" on subsequent references.

**File:** stage-1-setup.md, orchestrator-loop.md, SKILL.md (passim)

---

#### 12. Inconsistent Dash Usage

**Category:** Consistency / Punctuation

**Current state:** The files mix em dashes, en dashes, and hyphens inconsistently:

- SKILL.md line 16: `(High Attention Zone --- Start)` uses em dash
- SKILL.md line 49: `Stage 1 runs inline --- all other stages are coordinator-delegated` uses em dash
- stage-1-setup.md line 7: `(conditional -- absent in rapid mode)` uses two hyphens (not a proper em dash)
- orchestrator-loop.md line 246: `non-blocking` uses hyphen (correct for compound adjective)

**Recommendation:** Standardize on the Unicode em dash character for parenthetical interruptions. Use hyphens only for compound modifiers.

**File:** All four files analyzed.

---

### INFO (Positive Observations)

#### 13. Strong Imperative Voice in Instructions

**Category:** Active voice (Strunk Rule 10)

The instructional core of every file uses direct imperative verbs: "Read state file", "Dispatch coordinator", "Validate required fields", "Write summary to", "Check for filled answers." This is the skill's strongest writing quality. The pseudocode blocks read like a well-written recipe -- each step begins with a verb, and the subject (the orchestrator or coordinator) is implied.

**File:** All four files analyzed.

---

#### 14. Effective Use of Tables for Structured Data

**Category:** Clarity / Concrete language (Strunk Rule 12)

Tables are used consistently for configuration references, stage dispatch profiles, variable defaults, mode variations, and agent references. This is the right format for data with multiple parallel attributes. The tables are well-aligned, consistently headed, and avoid prose where structured data belongs.

**File:** SKILL.md (lines 61-68, 84-89, 138-145, 311-320, 329-339, 345-361), orchestrator-loop.md (lines 44-50, 120-131)

---

## Strengths

1. **Imperative instructional voice.** The skill's core instructions consistently use active, imperative constructions ("Read state file", "Dispatch coordinator", "Write summary"). This makes the execution path unambiguous and easy to follow. The pseudocode blocks particularly excel -- they read top-to-bottom without requiring the reader to untangle complex sentence structure.

2. **Tabular data presentation.** Configuration values, dispatch profiles, variable defaults, mode matrices, and agent references are all presented in well-formatted markdown tables rather than buried in prose. This makes reference lookup fast and reduces the chance of misreading a value. The consistent table format across all four files creates a unified reading experience.

3. **Consistent section structure.** Every stage reference file follows the same pattern: YAML frontmatter, title, critical rules, numbered steps, summary contract, self-verification checklist. This structural consistency reduces cognitive load when reading a new stage file for the first time.
