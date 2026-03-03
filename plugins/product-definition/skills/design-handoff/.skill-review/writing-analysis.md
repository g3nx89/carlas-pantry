---
lens: "Writing Quality & Conciseness"
lens_id: "writing"
skill_reference: "docs:write-concisely"
target: "design-handoff"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff"
fallback_used: false
findings_count: 14
critical_count: 0
high_count: 2
medium_count: 6
low_count: 4
info_count: 2
---

# Writing Quality & Conciseness Analysis: design-handoff

## Summary

The design-handoff skill is well-structured and largely concise for its genre (instructional reference material for an LLM orchestrator). SKILL.md follows the lean orchestrator pattern effectively, staying under 300 lines with a dispatch-table architecture that avoids procedural bloat. The three reference files examined (designer-dialog.md, output-assembly.md, setup-protocol.md) maintain a consistent instructional voice suited to their audience (an LLM agent).

The primary writing quality issues are: (1) passive voice appears in several key instructions where active voice would be clearer and more forcible, (2) filler phrases and hedging language weaken otherwise direct instructions, (3) a few instances of synonym churn introduce unnecessary terminological variation, and (4) some sentences carry redundant qualifiers that add no meaning. None of these issues rise to CRITICAL severity -- the skill will function correctly -- but addressing the HIGH and MEDIUM findings would tighten the prose and reduce token consumption during agent context loading.

Evaluation used the `docs:write-concisely` skill (Strunk's *The Elements of Style*), focusing on Rules 10 (active voice), 11 (positive form), 12 (definite language), 13 (omit needless words), 15 (parallel construction), and 18 (emphatic words at end).

---

## Findings

### Finding 1: Passive voice in critical instructions

**Severity:** HIGH
**Category:** Active voice (Strunk Rule 10)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Line 27 reads: "Progress persisted in state file. Designer decisions tracked per-screen." Both sentences use passive constructions with the agent omitted.

**Recommendation:** Rewrite in active voice with an explicit subject: "The state file persists progress. The workflow tracks designer decisions per-screen." This makes the actor clear -- the state file does the persisting, the workflow does the tracking. An agent reading this instruction can immediately identify which component is responsible.

---

### Finding 2: Passive voice pattern across reference files

**Severity:** HIGH
**Category:** Active voice (Strunk Rule 10)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/setup-protocol.md`

**Current state:** Multiple passive constructions appear in procedural steps:
- Line 15: "Gates all subsequent stages by confirming Figma MCP connectivity" (acceptable participial, but the sentence front-loads a vague subject)
- Line 127: "Dispatch `handoff-screen-scanner` (haiku) for frame discovery and structural metrics." (good -- active)
- Line 139: "Scanner writes YAML frontmatter with per-screen..." (good -- active)
- Line 251: "Artifacts on disk:" followed by a bare list (acceptable shorthand)

The file is largely active, but the opening Purpose paragraph (line 15) packs five actions into a single sentence, diluting each one. The sentence buries the emphatic word ("approval") in the middle rather than placing it at the end (Strunk Rule 18).

**Recommendation:** Break the Purpose paragraph into two sentences: "This stage confirms Figma MCP connectivity, scans the designer's page for top-level frames, and scores each frame's handoff-readiness. It recommends a TIER level and obtains designer approval before any Figma mutations begin." Placing "approval" at the sentence boundary gives it the emphasis it deserves as the gate condition.

---

### Finding 3: Needless words -- "ONLY" used as filler emphasis

**Severity:** MEDIUM
**Category:** Omit needless words (Strunk Rule 13)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The word "ONLY" (caps) appears four times in SKILL.md (lines 8, 21, 34, 237) and once in output-assembly.md (line 16). In lines 8 and 21, "covering ONLY what Figma cannot express" is effective emphasis. But in line 34 ("supplement NEVER duplicates Figma content"), the preceding sentence already establishes the constraint, making the "ONLY" in the Critical Rules section redundant with the description block. The repetition across four locations dilutes the emphasis that capitalization is meant to convey.

**Recommendation:** Reserve ONLY-caps for the single most authoritative statement of the rule (Critical Rule 1). In other locations, use lowercase "only" or restructure: "covering what Figma cannot express" (the word "cannot" already implies exclusivity).

---

### Finding 4: Redundant qualifiers -- "Mandatory 9-step checklist"

**Severity:** MEDIUM
**Category:** Omit needless words (Strunk Rule 13)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Line 69 in the workflow diagram reads: "Mandatory 9-step checklist." The word "Mandatory" adds nothing in context -- a checklist within a defined workflow stage is inherently mandatory. Calling it mandatory implies other checklists might be optional, which is not the case.

**Recommendation:** Write "9-step checklist" without the qualifier. The stage structure already communicates that steps must be followed.

---

### Finding 5: Synonym churn -- "dispatch" vs. "launch" vs. "run"

**Severity:** MEDIUM
**Category:** Consistent terminology
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The skill uses "dispatch" (lines 146, 161, 179, 191), "run" (line 241: "Orchestrator runs this stage"), and the workflow diagram uses neither (just stage names). The reference files are more consistent, using "dispatch" almost exclusively. However, SKILL.md line 241 breaks this pattern: "Orchestrator runs this stage directly."

**Recommendation:** Standardize on "dispatch" for agent delegation and "execute" for inline stages. Replace "runs this stage directly" with "executes this stage inline" to match the "(Inline)" label in the Stage Dispatch Table.

---

### Finding 6: Verbose compound prepositions

**Severity:** MEDIUM
**Category:** Omit needless words (Strunk Rule 13)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/designer-dialog.md`

**Current state:** Line 239: "Instead of AskUserQuestion, the orchestrator writes gaps to a file for offline answering." The phrase "Instead of AskUserQuestion" is a roundabout negative. Line 269: "Empty answers are treated as unanswered -- the orchestrator re-prompts for those specific questions." The phrase "those specific questions" could be just "them."

**Recommendation:**
- Line 239: "The orchestrator writes gaps to a file (replacing AskUserQuestion) for offline answering." Or simply: "The orchestrator writes gaps to a file for offline answering."
- Line 269: "Empty answers count as unanswered -- the orchestrator re-prompts for them."

---

### Finding 7: Filler sentence -- "This lets the reviewer jump directly"

**Severity:** MEDIUM
**Category:** Omit needless words (Strunk Rule 13)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/output-assembly.md`

**Current state:** Lines 57-58: After the Screen Reference Table template, the text reads: "This lets the reviewer jump directly to the right Figma frame or brief document." This sentence explains why the table exists. In Strunk's terms, it tells the reader that something is useful rather than demonstrating it -- the table format itself makes the purpose obvious.

**Recommendation:** Delete the sentence. The table header columns (`Node ID`, `Brief`) already communicate the purpose. If context is needed, a terse inline comment within the table template suffices.

---

### Finding 8: Weak negative phrasing -- "No graceful degradation"

**Severity:** MEDIUM
**Category:** Positive form (Strunk Rule 11)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/setup-protocol.md`

**Current state:** Line 19: "If `figma-console` is unavailable, STOP. No graceful degradation." The second sentence states what does NOT happen rather than what does. It is a double negative in spirit: "not graceful" + "degradation" (itself a negative concept).

**Recommendation:** State the positive: "If `figma-console` is unavailable, STOP immediately." The word "immediately" conveys finality more forcibly than explaining what will not happen.

---

### Finding 9: Inconsistent dash usage

**Severity:** LOW
**Category:** Formatting consistency
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The file mixes em-dashes with surrounding spaces (line 23: "refinement (PRD.md) -- [design-narration...]"), en-dashes without spaces in the Critical Rules heading (line 31: "High Attention Zone -- Start"), and bare hyphens in some table cells. The reference files use `—` (em-dash) consistently in headings but `--` in prose.

**Recommendation:** Standardize on `--` (double hyphen) throughout, since this is Markdown consumed by an LLM, not typeset prose. Consistency matters more than typographic correctness here.

---

### Finding 10: Loose sentence pattern in Stage descriptions

**Severity:** LOW
**Category:** Sentence structure (Strunk Rule 14)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** Several stage descriptions follow the same loose pattern: "{Verb phrase} -- {qualifier}. {Read-and-follow instruction}." For example:
- Line 135: "Establish prerequisites, scan the Figma file, and get designer approval before any modifications."
- Line 157: "The core file preparation -- each screen is transformed through a mandatory 9-step checklist."
- Line 187: "Identify what Figma cannot express and what's missing from the design."

The second example (line 157) shifts from a noun phrase to a passive clause joined by a dash, breaking the parallel structure of the other descriptions.

**Recommendation:** Rewrite line 157 as an active imperative: "Transform each screen through the 9-step preparation checklist." This parallels the verb-first pattern of the other stage descriptions ("Establish," "Identify").

---

### Finding 11: "Omit entire section if" repeated four times

**Severity:** LOW
**Category:** Omit needless words / parallel construction (Strunk Rules 13, 15)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/output-assembly.md`

**Current state:** The phrase "Omit entire section if..." appears at lines 83, 89, 115, and a variant at line 25 ("If a template section would have zero rows, omit it entirely"). Each repetition restates Critical Rule 5 from the same file.

**Recommendation:** State the rule once in CRITICAL RULES (already done at line 25) and remove the per-step repetitions, or condense them to a single-word marker like `[omit-if-empty]` after each section heading. This reduces four sentences to four tokens.

---

### Finding 12: Dangling participle risk in pseudocode comments

**Severity:** LOW
**Category:** Grammar (Strunk Rule 7)
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/setup-protocol.md`

**Current state:** Line 141-142: "**If scanner fails or returns zero frames:** NOTIFY... STOP." The bold label uses a conditional clause that grammatically should refer to the subject of the next verb. But the next verb's implied subject is the orchestrator ("NOTIFY"), not the scanner. This is standard pseudocode convention and unlikely to confuse an LLM agent, but it departs from Strunk's Rule 7.

**Recommendation:** No action required for functional correctness. For strict style compliance, rewrite as: "**If the scanner fails or returns zero frames**, the orchestrator notifies the user... and stops."

---

### Finding 13: Effective use of tables over prose

**Severity:** INFO
**Category:** Positive observation
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/references/output-assembly.md`

**Current state:** The output-assembly reference uses tables extensively for variable mappings (Step 5.5), gap-category-to-section mappings (Step 5.3), and the summary report (Step 5.7). This follows both the skill's own "tables over prose" rule and Strunk's preference for definite, concrete language (Rule 12). The `| Gap Category | Template Section | Columns |` table at lines 73-79 is particularly well-constructed -- each cell contains exactly the information needed, nothing more.

---

### Finding 14: Strong imperative voice in Critical Rules

**Severity:** INFO
**Category:** Positive observation
**File:** `/Users/afato/Projects/carlas-pantry/plugins/product-definition/skills/design-handoff/SKILL.md`

**Current state:** The CRITICAL RULES section (lines 33-41) uses direct, positive imperatives: "Verify," "Never batch," "HARD BLOCK," "Never inline." The repetition at the file's end (lines 326-333) restates each rule in compressed form. This bookend pattern places emphatic content at both the beginning and end of the document (Strunk Rule 18), maximizing attention in LLM context windows where primacy and recency effects matter most.

---

## Strengths

1. **Lean orchestrator structure enforces conciseness by design.** SKILL.md stays under 300 lines by delegating procedural detail to reference files. Each stage description is 5-15 lines -- enough to communicate purpose, delegation method, and mode guards without drowning in procedure. This architectural choice prevents the verbosity that plagues monolithic skill files.

2. **Tables-over-prose philosophy is consistently applied.** Across all four files examined, structured data (stage dispatch table, gap categories, template variables, anti-patterns) appears in tables rather than narrative paragraphs. The anti-patterns table in designer-dialog.md (lines 275-282) is an exemplary use of the format: each row is a complete rule expressed in under 15 words per cell, eliminating the need for explanatory prose.

3. **Pseudocode blocks replace natural-language procedure.** The setup-protocol and designer-dialog files use fenced pseudocode blocks for multi-step logic (lock acquisition, state updates, batch processing). This avoids the ambiguity that natural-language instructions introduce when describing conditional branching and loop structures -- a pragmatic conciseness choice for LLM-consumed content.

4. **Consistent section structure across reference files.** Every reference file follows the same skeleton: YAML frontmatter, Purpose paragraph, CRITICAL RULES, numbered Steps, Exit Conditions / Output, CRITICAL RULES REMINDER. This predictable structure reduces cognitive overhead (both for human reviewers and LLM agents) and makes it easy to locate specific information without reading the full file.
