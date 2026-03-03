---
lens: "Writing Quality & Conciseness"
lens_source: "docs:write-concisely (Strunk, The Elements of Style)"
fallback_used: false
target_skill: "feature-specify"
target_path: "plugins/product-definition/skills/specify"
files_analyzed:
  - SKILL.md (17,302 bytes)
  - references/orchestrator-loop.md (13,105 bytes)
  - references/stage-2-spec-draft.md (11,093 bytes)
  - references/stage-4-clarification.md (22,431 bytes)
findings_total: 18
findings_by_severity:
  CRITICAL: 0
  HIGH: 3
  MEDIUM: 8
  LOW: 5
  INFO: 2
strengths_count: 4
---

# Writing Quality & Conciseness Analysis: feature-specify

## Summary

The feature-specify skill is a well-structured orchestration document that successfully uses tables, code blocks, and consistent formatting to convey a complex 7-stage workflow. Its greatest writing strengths are its parallel sentence structure in rule lists and its effective use of ASCII diagrams. Its greatest weaknesses are pervasive passive voice in procedural instructions, verbose filler phrases that dilute imperative clarity, and inconsistent terminology for core concepts ("CLI dispatch" vs "MPA" vs "tri-CLI" vs "multi-stance validation"). Across the four files analyzed (~64,000 bytes), roughly 15-20% of prose could be cut without losing meaning.

---

## Findings

### 1. [HIGH] Pervasive passive voice in procedural instructions

**Category:** Active voice (Strunk Rule 10)
**Files:** All four files

**Current state:**
Passive constructions appear throughout instructions that should command the reader to act:
- "Questions are written to `clarification-questions.md`" (SKILL.md, line 23)
- "findings are synthesized" (stage-2-spec-draft.md, line 143)
- "Report is written" (stage-4-clarification.md, line 213)
- "Coordinator summaries are the primary context passed between stages" (orchestrator-loop.md, line 133)
- "State is persisted in state files" (SKILL.md, line 12)
- "All clarification answers are recorded in state file" (stage-4-clarification.md, line 511)

**Recommendation:** Rewrite procedural lines in active voice with the agent or orchestrator as subject. Examples:
- "Write all questions to `clarification-questions.md`"
- "Synthesize findings using haiku agent"
- "Write report to ..."
- "Pass coordinator summaries as primary context between stages"
- "Persist state in state files"
- "Record all clarification answers in state file"

Some instances already use active voice well (e.g., "Dispatch BA agent via Task" in stage-2, line 25). Apply the same pattern everywhere.

---

### 2. [HIGH] Synonym churn for core dispatch concept

**Category:** Consistent terminology
**Files:** SKILL.md, stage-2-spec-draft.md, stage-4-clarification.md

**Current state:**
The same concept -- dispatching external CLI tools for multi-perspective analysis -- is referred to by at least five different names:
- "CLI dispatch" (SKILL.md, line 37)
- "MPA-Challenge CLI dispatch" (SKILL.md, line 106)
- "tri-CLI dispatch" (stage-4-clarification.md, line 15)
- "CLI multi-stance validation" (SKILL.md, line 10)
- "CLI multi-stance eval" (SKILL.md, line 126)
- "MPA-EdgeCases CLI dispatch" (stage-4-clarification.md, line 162)

A reader encountering "tri-CLI dispatch" for the first time cannot know it means the same thing as "MPA-Challenge CLI dispatch" or "CLI multi-stance validation."

**Recommendation:** Choose one canonical term (e.g., "CLI dispatch") and use it consistently. Where specialization is needed, qualify it: "CLI dispatch (Challenge)," "CLI dispatch (Edge Cases)," "CLI dispatch (Triangulation)," "CLI dispatch (Evaluation)." Drop "tri-CLI," "multi-stance," and "MPA-" prefixes from prose. Reserve "MPA" for the pattern name in glossary or architecture docs only.

---

### 3. [HIGH] Verbose conditional preambles bloat step instructions

**Category:** Omit needless words (Strunk Rule 13)
**Files:** stage-2-spec-draft.md, stage-4-clarification.md

**Current state:**
Many steps open with a multi-line conditional check that could be one line:
```
**Check:** `RTM_ENABLED == true` AND `ENTRY_TYPE != "re_entry_after_user_input"`
AND (`rtm_unmapped_count > 0` OR any PENDING_STORY dispositions remain in `rtm.md`)
(from Stage 3 summary flags)

**If any condition is false:** Skip entirely, proceed to Step 4.1.

**If all conditions met:**
```
(stage-4-clarification.md, lines 129-133)

This 5-line preamble appears before the reader reaches the actual instruction. Similar patterns repeat at Steps 4.0 (line 44), 4.1 (line 164), 4.4 (line 314), 2.3 (line 108), and 2.4 (line 182).

**Recommendation:** Collapse guard clauses into a single conditional line at the top of each step:
```
**Guard:** Skip if RTM disabled, re-entry, or no UNMAPPED/PENDING_STORY REQs in rtm.md.
```
Then proceed directly to the instruction body. The full boolean expression belongs in pseudocode blocks, not prose.

---

### 4. [MEDIUM] Filler phrases add no information

**Category:** Omit needless words (Strunk Rule 13)
**Files:** All four files

**Current state:**
- "This stage creates the specification draft, challenges problem framing via CLI dispatch, and validates through incremental quality gates." (stage-2, line 12) -- The blockquote summary restates the heading.
- "This stage discovers edge cases via tri-CLI dispatch, generates all clarification questions (with auto-resolve filtering), writes them to a file for offline user editing, then -- on re-entry -- parses answers and updates the spec." (stage-4, lines 17-19) -- 40-word sentence that restates the heading and step list below it.
- "Read this file at the start of orchestration. It governs how stages are dispatched, how the iteration loop works, and how the orchestrator recovers from failures." (orchestrator-loop, lines 3-4) -- The file name and heading already convey this.
- "**This workflow is resumable and resilient.** Progress is preserved in state files. User decisions are NEVER lost." (SKILL.md, line 12) -- "resumable and resilient" is vague. The next two sentences say the same thing concretely. Cut the first sentence.

**Recommendation:** Delete blockquote introductions that restate the heading. If the heading says "Stage 2: Spec Draft & Gates," the reader knows what the stage does. Jump straight to the critical rules or first step.

---

### 5. [MEDIUM] Redundant CRITICAL RULES REMINDER sections

**Category:** Omit needless words (Strunk Rule 13)
**Files:** SKILL.md (line 291-301), stage-2-spec-draft.md (lines 298-304), stage-4-clarification.md (lines 515-524)

**Current state:**
Every file ends with a "CRITICAL RULES REMINDER" section that repeats rules already stated at the top of the file. SKILL.md devotes 10 lines (291-301) to restating rules 1-28. Stage-2 devotes 6 lines (298-304). Stage-4 devotes 10 lines (515-524). These reminders are nearly verbatim copies.

**Recommendation:** The "High Attention Zone -- Start/End" bookend pattern in SKILL.md is sufficient for rule emphasis. In reference files, replace the reminder block with a single line: "Rules 1-7 above apply to all steps in this stage." This recovers ~26 lines across the three files.

---

### 6. [MEDIUM] Loose sentence chains in explanatory prose

**Category:** Avoid loose sentences (Strunk Rule 14)
**Files:** orchestrator-loop.md

**Current state:**
```
NOTE: This check is intentionally NON-BLOCKING (notification only, does not halt).
The disposition gate in Stage 4 (Step 4.0a) already gave the user a chance to
resolve every UNMAPPED requirement. If any remain UNMAPPED here, it means the user
chose not to answer those disposition questions -- this is their conscious choice.
Blocking again would create an infinite loop. The remaining UNMAPPED entries are
reported in the Stage 7 completion report for future resolution.
```
(orchestrator-loop.md, lines 267-272)

Six consecutive loose sentences, each adding a subordinate thought. The reader must hold the entire chain to understand the design intent.

**Recommendation:** Compress to two sentences:
```
This check is non-blocking: Stage 4 already offered disposition for every
UNMAPPED requirement, so remaining gaps reflect the user's conscious choice.
Remaining UNMAPPED entries appear in the Stage 7 completion report.
```

---

### 7. [MEDIUM] "If ... ELSE ..." blocks use inconsistent formatting

**Category:** Parallel construction (Strunk Rule 15)
**Files:** stage-2-spec-draft.md, stage-4-clarification.md

**Current state:**
Conditional branches appear in at least three different formats:
- Bold-colon: `**If enabled:**` / `**If disabled:**` (stage-2, lines 108, 176)
- Bold-colon-code: `**Check:** \`config.key\`` then `**If enabled AND CLI_AVAILABLE:**` (stage-4, lines 164-166)
- Inline code: `IF ENTRY_TYPE == "re_entry_after_user_input":` inside fenced code blocks (stage-4, line 34)
- Paragraph: "If user chose 'Revise': ..." (stage-2, line 172)

**Recommendation:** Adopt one format for all guard clauses. Suggested: bold-label for the guard, then indented content. Use code blocks only for pseudocode that a coordinator will parse mechanically.

---

### 8. [MEDIUM] Sentences bury the verb after long prepositional chains

**Category:** Keep related words together (Strunk Rule 16)
**Files:** stage-4-clarification.md

**Current state:**
- "For each UNMAPPED or PENDING_STORY REQ-NNN, write a disposition question to `specs/{FEATURE_DIR}/clarification-questions.md` (prepended before BA clarification questions, in a dedicated `## RTM Dispositions` section):" (lines 136-137)

The verb "write" is separated from its object by a 20-word prepositional tail.

**Recommendation:** Lead with the action:
"Write a disposition question for each UNMAPPED or PENDING_STORY REQ-NNN. Place these in a `## RTM Dispositions` section, prepended before BA clarification questions."

---

### 9. [MEDIUM] Unnecessary "Note" and "Tip" callouts

**Category:** Omit needless words (Strunk Rule 13)
**Files:** stage-4-clarification.md, orchestrator-loop.md

**Current state:**
- "**Note:** RTM disposition questions are part of the clarification file, following the same file-based Q&A pattern. They are processed during the normal answer parsing flow (Step 4.3)." (stage-4, lines 159-160)
- "**Note on iteration:** After this stage, the orchestrator re-dispatches Stage 3 for re-validation." (stage-4, line 502)

These notes restate information that the surrounding context already implies. If disposition questions are written to the clarification file (which the preceding instructions specify), a reader can deduce they follow the same parsing flow.

**Recommendation:** Delete notes that restate the obvious. Reserve "Note:" for genuinely surprising or counter-intuitive behavior.

---

### 10. [MEDIUM] Hedging language weakens instructions

**Category:** Put statements in positive form (Strunk Rule 11)
**Files:** SKILL.md, orchestrator-loop.md

**Current state:**
- "Assume unavailable; prevents failed CLI dispatch calls" (orchestrator-loop.md, Variable Defaults table, line 115)
- "Safe default for first invocation" (orchestrator-loop.md, line 114)
- "Quality gates after Stages 2, 4, and 5 -- non-blocking but user-notified" (SKILL.md, line 300)

"Non-blocking but user-notified" is a double negative construction. "Assume unavailable; prevents failed" uses a negative to explain a negative.

**Recommendation:** Rewrite in positive form:
- "Default false. Detected in Stage 1; overridden when found."
- "Default first_entry."
- "Quality gates after Stages 2, 4, and 5 notify the user and allow the workflow to continue."

---

### 11. [MEDIUM] Overlong parenthetical asides

**Category:** Omit needless words (Strunk Rule 13)
**Files:** stage-4-clarification.md

**Current state:**
- "(prepended before BA clarification questions, in a dedicated `## RTM Dispositions` section)" (line 137)
- "(from Stage 3 summary flags)" (line 129)
- "(check frontmatter timestamp vs file mtime)" (line 284)
- "(with citations)" and "(use recommendation)" on the same line (line 285)
- "(e.g., coordinator crash)" (line 408)

Parentheticals disrupt the sentence flow. Multiple parentheticals in a single sentence force the reader to track nested contexts.

**Recommendation:** Promote important parentheticals to their own sentences. Delete trivial ones. Example: "(from Stage 3 summary flags)" can be cut entirely -- the variable name `rtm_unmapped_count` already implies its source.

---

### 12. [LOW] Inconsistent use of "MUST" vs "must" vs "always"

**Category:** Consistent terminology
**Files:** SKILL.md, orchestrator-loop.md

**Current state:**
- "MUST be generated" (SKILL.md, line 31)
- "must follow" (stage-2, line 14)
- "ALWAYS checkpoint" (SKILL.md, line 19)
- "always" lowercase in "Always acquire lock" (SKILL.md, line 26 -- implied by Rule 7)
- "You MUST NOT interact with users" (orchestrator-loop.md, line 91)

RFC 2119-style keywords (MUST, MUST NOT, SHOULD) are mixed with lowercase equivalents without a defined convention.

**Recommendation:** Add a one-line convention note at the top of SKILL.md: "Capitalized MUST, NEVER, and ALWAYS indicate mandatory requirements." Then apply consistently. Use lowercase for non-normative guidance.

---

### 13. [LOW] Acronyms introduced without definition

**Category:** Definite, specific language (Strunk Rule 12)
**Files:** SKILL.md

**Current state:**
- "MPA-Challenge" first appears at line 106 without expansion. "MPA" is never defined in SKILL.md.
- "RTM" first appears at line 55 without expansion in the critical rules. It appears in the Configuration Reference table (line 78) but is not expanded until the reader reaches the Stage Dispatch Table context.
- "NFR" (line 34) is not expanded.
- "BA" (line 24) is not expanded.

**Recommendation:** Expand each acronym on first use: "Multi-Perspective Analysis (MPA)," "Requirements Traceability Matrix (RTM)," "Non-Functional Requirement (NFR)," "Business Analyst (BA)." Subsequent uses can use the acronym alone.

---

### 14. [LOW] Tense inconsistency in step descriptions

**Category:** Keep to one tense (Strunk Rule 17)
**Files:** stage-2-spec-draft.md

**Current state:**
Step descriptions alternate between imperative and declarative:
- "Dispatch BA agent via `Task`" (line 25) -- imperative
- "Agent uses Sequential Thinking (if available) for 8 phases" (line 62) -- declarative present
- "Extract from agent output:" (line 66) -- imperative
- "Auto-evaluate 4 criteria:" (line 184) -- imperative
- "Same GREEN/YELLOW/RED logic as Gate 1." (line 217) -- sentence fragment, declarative

**Recommendation:** Use imperative mood throughout step instructions (the coordinator is the implied subject). Rewrite "Agent uses Sequential Thinking..." as "The BA agent uses Sequential Thinking..." or simply "Sequential Thinking guides 8 analysis phases (if available)."

---

### 15. [LOW] "See above" / "see below" cross-references are vague

**Category:** Definite, specific language (Strunk Rule 12)
**Files:** stage-2-spec-draft.md, orchestrator-loop.md

**Current state:**
- "Same GREEN/YELLOW/RED logic as Gate 1." (stage-2, line 217)
- "see Coordinator Dispatch below" (orchestrator-loop.md, line 26)
- "see Summary Handling" (orchestrator-loop.md, line 29)
- "see Crash Recovery" (orchestrator-loop.md, line 180)

**Recommendation:** Use section-anchor links or explicit step numbers: "Same logic as Step 2.4 (Gate 1)." In markdown, use `[Summary Handling](#summary-handling)` for in-document links.

---

### 16. [LOW] "Self-Verification" sections repeat the summary contract

**Category:** Omit needless words (Strunk Rule 13)
**Files:** stage-2-spec-draft.md (lines 289-296), stage-4-clarification.md (lines 504-513)

**Current state:**
The "Self-Verification" checklists largely restate what the Summary Contract already requires (e.g., "Summary YAML frontmatter has no placeholder values" appears in both the contract and the verification checklist).

**Recommendation:** Merge verification items into the Summary Contract section as a pre-write checklist. This eliminates the separate section and reduces duplication by ~10 lines per file.

---

### 17. [INFO] Code blocks serve as effective concise specification

**Category:** Positive observation

The skill makes excellent use of YAML and bash code blocks to specify exact formats, file paths, and dispatch commands. These blocks are unambiguous and leave no room for misinterpretation. Examples include the Summary Contract YAML template (SKILL.md, lines 179-208), the CLI dispatch bash commands (stage-2, lines 120-141), and the state checkpoint schemas (stage-4, lines 415-451). This is the most concise way to express structured data contracts.

---

### 18. [INFO] Table-driven configuration is exemplary

**Category:** Positive observation

The Configuration Reference table (SKILL.md, lines 63-81), Variable Defaults table (orchestrator-loop.md, lines 112-126), Stage Dispatch Table (SKILL.md, lines 144-152), and Agent References table (SKILL.md, lines 241-247) all follow Strunk's principle of expressing parallel ideas in parallel form. Each table has consistent columns, no prose padding, and serves as a scannable reference. This pattern should be maintained and extended.

---

## Strengths

### 1. Parallel structure in rule lists
The CRITICAL RULES section (SKILL.md, lines 18-55) uses consistent formatting: bold number, bold keyword, colon, imperative statement. This parallel construction aids scanning and makes each rule independently readable. The pattern is well-maintained across all 28 rules.

### 2. Effective ASCII workflow diagram
The workflow diagram (SKILL.md, lines 97-138) provides a scannable overview of the entire 7-stage pipeline in ~40 lines. It uses consistent box-and-arrow notation, includes stage names and key activities, and marks the iteration loop visually. This is more concise and more useful than the equivalent prose description would be.

### 3. Stage Dispatch Table as single source of truth
The table at SKILL.md lines 144-152 maps every stage to its delegation type, reference file, checkpoint name, user pause behavior, and optionality in seven columns. A reader can answer "what happens in Stage 4?" without reading 500 lines of reference file. This is the skill's best application of Strunk's Rule 13 (omit needless words) -- the table replaces paragraphs of prose.

### 4. Clear separation between orchestrator and coordinator concerns
The skill consistently distinguishes what the orchestrator does (dispatch, iterate, mediate user interaction) from what coordinators do (execute stage logic, write artifacts, signal status). This separation keeps each document focused on one topic per section (Strunk Rule 8), making the overall architecture comprehensible despite its complexity.
