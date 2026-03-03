---
lens: "Writing Quality & Conciseness"
lens_id: "writing"
skill_reference: "docs:write-concisely"
target: "figma-console-mastery"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery"
fallback_used: true
findings_count: 14
critical_count: 0
high_count: 2
medium_count: 6
low_count: 4
info_count: 2
---

# Writing Quality & Conciseness Analysis: figma-console-mastery

## Summary

The figma-console-mastery skill demonstrates strong technical writing overall. The SKILL.md file is well-structured as a lean dispatch table, and the reference files maintain a consistent instructional tone. The primary weaknesses are (1) redundancy across files where the same concept is restated in slightly different words, (2) passive voice in procedural sections that should use imperative commands, and (3) verbose constructions in the Socratic Protocol that could be trimmed significantly without losing meaning.

**Files reviewed**: `SKILL.md`, `references/essential-rules.md`, `references/socratic-protocol.md`, `references/flow-procedures.md`

---

## Findings

### F1: Redundant Restatement of Screenshot Tool Distinction

**Severity**: HIGH
**Category**: Conciseness (needless repetition)
**File**: Multiple files

**Current state**: The distinction between `figma_capture_screenshot` (live) and `figma_take_screenshot` (cached/stale) appears in at least 5 separate locations:

- SKILL.md lines 46, 128-129 (Quick Start table + Essential Rules MUST #5)
- SKILL.md line 245 (Troubleshooting table)
- essential-rules.md line 19 (MUST #6)
- essential-rules.md line 52 (AVOID #11)
- flow-procedures.md line 185

Each instance uses slightly different wording to say the same thing: use `figma_capture_screenshot` after mutations, not `figma_take_screenshot`.

**Recommendation**: State the rule once canonically in `essential-rules.md` MUST #6. In all other locations, use a terse reminder without re-explaining the reason. For example, in the Troubleshooting table: "`figma_take_screenshot` shows stale content | Use `figma_capture_screenshot`" (drop the parenthetical explanation already covered in essential-rules.md). Remove AVOID #11 entirely since it restates MUST #6 in negated form.

---

### F2: SKILL.md Description Frontmatter Is Overloaded

**Severity**: HIGH
**Category**: Conciseness (sentence density)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state** (line 4): The `description` field is a single run-on value spanning ~60 words and listing 11 trigger phrases, 5 capability nouns, and a cross-skill delegation note, all in one sentence.

**Recommendation**: Trim to the essential trigger phrases and move the capability list to the Overview section. The description field exists for matching user intent, not for documenting the skill's architecture. Proposed:

```
description: This skill should be used when the user asks to "create a Figma design", "use figma_execute", "design in Figma", "create Figma components", "set up design tokens in Figma", "build a UI in Figma", or "use figma-console MCP". For Draft-to-Handoff workflows, use the design-handoff skill instead.
```

This removes the redundant enumeration of internal capabilities ("2 flows", "subagent-first orchestration", "quality model", "selective reference loading") that do not help with intent matching.

---

### F3: Passive Voice in Flow Procedures Phase Steps

**Severity**: MEDIUM
**Category**: Active voice
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md`

**Current state**: Several procedural steps use passive constructions where imperative would be clearer:

- Line 14: "Replaces Session Protocol, Quick Audit, and Design Restructuring workflows" (passive/ambiguous subject)
- Line 58: "Each category prompts the user with key questions, captures decisions, and builds a checklist" (weak subject "each category" — categories do not prompt)
- Line 201: "Does NOT generate manifest — only ensures handoff readiness" (dangling subject)

**Recommendation**: Rewrite as imperative instructions addressed to the executor:

- "This flow unifies Session Protocol, Quick Audit, and Design Restructuring."
- "Prompt the user with each category's key questions, capture decisions, and build a checklist."
- "This flow ensures handoff readiness. It does not generate the manifest."

---

### F4: Socratic Protocol Questions Contain Redundant Framing

**Severity**: MEDIUM
**Category**: Conciseness (filler phrases)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/socratic-protocol.md`

**Current state**: Many question templates include framing phrases that add no information:

- Line 88: "Based on Phase 1 analysis, I found [N issues]. Two approaches are available:" — "Two approaches are available" is implied by listing them.
- Line 109: "I found [N] deeply nested GROUP layers (5+ levels). Should I flatten these to improve hierarchy clarity?" — "to improve hierarchy clarity" restates what flattening does.
- Line 129: "I identified [N] frames that should use auto-layout: [list]. Approve this list?" — "Approve this list?" is implied by the options that follow.

**Recommendation**: Trim framing to essential content. The pattern "[observation]. [proposed action]. [options]" does not need a trailing confirmation question when the options already serve that role. Example: "Found [N] deeply nested GROUP layers (5+ levels). Flatten?" with options below.

---

### F5: Synonym Churn for "Subagent" Delegation

**Severity**: MEDIUM
**Category**: Terminology consistency
**File**: Multiple files

**Current state**: The skill uses multiple phrasings for the same concept:

- "Sonnet subagent" (SKILL.md lines 52, 70, 87-90; flow-procedures.md)
- "subagent" without qualifier (SKILL.md line 22)
- "Main context dispatches subagent" (flow-procedures.md line 138)
- "Main context dispatches audit subagent" (flow-procedures.md line 174)
- "Modification subagent (Sonnet)" (flow-procedures.md line 250)
- "Audit subagent (Sonnet, separate dispatch)" (flow-procedures.md line 258)

**Recommendation**: Standardize on "Sonnet subagent" for all references where Sonnet model is required, and plain "subagent" only in the general principle definition. Remove the "(Sonnet)" parenthetical annotations in flow-procedures.md headings since the principle already mandates Sonnet for all dispatches.

---

### F6: Verbose Output Descriptions in Socratic Protocol

**Severity**: MEDIUM
**Category**: Conciseness (every sentence earns its place)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/socratic-protocol.md`

**Current state**: Each category ends with an **Output** line that often restates the obvious in long-form:

- Line 40: `Reference to existing docs (file path or user-provided content) OR "No documentation — proceeding without reference"`
- Line 98: `"Path A" or "Path B" with brief rationale (e.g., "Path A chosen to preserve 12 prototype connections")`
- Line 118: `Approved structural changes list (e.g., "Flatten 8 GROUP layers in left nav, reparent 5 floating cards to Main Content section")`

The parenthetical examples are helpful but the lead-in text is often a restatement of the category purpose.

**Recommendation**: Shorten output lines to just the format spec. For example: `Output: file path to reference doc | "No documentation"`. The examples can remain as they demonstrate the expected granularity.

---

### F7: Essential Rules AVOID Section Duplicates MUST Negations

**Severity**: MEDIUM
**Category**: Conciseness (structural redundancy)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/essential-rules.md`

**Current state**: Several AVOID rules are direct negations of MUST rules:

| MUST | AVOID |
|------|-------|
| #6: Use `figma_capture_screenshot` for post-Plugin-API validation | #11: Never use `figma_take_screenshot` to validate recent Plugin API mutations |
| #9: Converge, never regress | #7: Never redo an operation already in the journal |
| #20: Run quality audit per tier | #14: Never skip Standard/Deep audit at phase boundaries |

**Recommendation**: Merge each AVOID rule into its MUST counterpart as a "Not:" suffix. Example: MUST #6: "Use `figma_capture_screenshot` for post-Plugin-API validation. Not `figma_take_screenshot` (stale cloud cache)." This reduces the AVOID list from 14 to 11 and eliminates semantic duplication.

---

### F8: "Mode notes" Sections Add Marginal Value

**Severity**: MEDIUM
**Category**: Conciseness (filler paragraphs)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/socratic-protocol.md`

**Current state**: Every category in the Socratic Protocol ends with a "Mode notes" line. Most are trivially derivable from the Mode-Specific Category Subsets table at the top:

- Line 42: "Applies to both Create and Restructure modes." (7 occurrences of essentially this same statement)
- Line 62: "Optional for Create mode (skip if user has no specific vision). Always run for Restructure if major changes planned." (adds minor nuance)
- Line 100: "Restructure mode only. Skip for Create mode." (3 occurrences)

**Recommendation**: Remove "Mode notes" lines that merely restate the table. Keep only the ones that add genuinely new information (e.g., line 62's "skip if user has no specific vision" and line 237's "Optional for Create mode if user requests interactive prototype"). This eliminates approximately 8 of 11 mode notes lines.

---

### F9: Inconsistent Dash Style in Tables

**Severity**: LOW
**Category**: Clarity and readability
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: Tables use em-dashes inconsistently:

- Line 15: "native tools for search, instantiation, screenshots, variable management, and `figma_execute` for Plugin API access" (no dash)
- Line 124: "the outer `return` is required for Desktop Bridge" (no dash, uses "is required for")
- Line 97: "`figma_search_components` → `figma_instantiate_component`" (arrow used instead of dash)

Additionally, some table cells use sentence fragments while others use complete sentences.

**Recommendation**: Standardize table cells to terse fragments without articles. Use arrows for tool chains and dashes for explanatory notes. This is a minor polish item.

---

### F10: "See X" Cross-References Could Be More Terse

**Severity**: LOW
**Category**: Conciseness (needless words)
**File**: Multiple files

**Current state**: Cross-references use varying patterns:

- "See `flow-procedures.md` SS1.1" (terse, good)
- "Full procedures: `references/flow-procedures.md`" (good)
- "(see `convergence-protocol.md`)" (good but parenthetical)
- "See `quality-dimensions.md` for audit model, `quality-audit-scripts.md` for scripts, `quality-procedures.md` for procedures" (verbose chain)

**Recommendation**: Standardize on the shortest form: `(ref: filename.md)` or `(ref: filename.md SS#)` for section-specific links. The word "see" and "full" add no information.

---

### F11: SKILL.md Overview Paragraph Mixes Scope and Mechanics

**Severity**: LOW
**Category**: Clarity (sentence structure)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state** (lines 15-16): "**figma-console** (Southleft, 60 tools) connects to Figma Desktop via the Desktop Bridge Plugin (WebSocket ports 9223-9232). It provides native tools for search, instantiation, screenshots, variable management, and `figma_execute` for Plugin API access."

This sentence mixes connection mechanics (WebSocket ports) with feature inventory (search, instantiation) in a way that forces the reader to parse two topics in one breath.

**Recommendation**: Split into two sentences with clearer focus: "**figma-console** (Southleft, 60 tools) connects to Figma Desktop via the Desktop Bridge Plugin on WebSocket ports 9223-9232. Native tools cover search, instantiation, screenshots, and variable management; `figma_execute` provides Plugin API access for everything else."

---

### F12: Repeated "(up to 100)" Qualifier for Batch Tools

**Severity**: LOW
**Category**: Conciseness (needless repetition)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md`

**Current state**: Lines 44 and 115-116 both include "(up to 100)" after `figma_batch_create_variables` and `figma_batch_update_variables`. This detail appears 4 times across SKILL.md alone.

**Recommendation**: State the batch limit once in the Quick Reference table footnote: "Batch tools accept up to 100 items per call." Remove inline repetitions.

---

### F13: Flow Procedures Duplicates Socratic Protocol Content

**Severity**: INFO
**Category**: Conciseness (structural observation)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md`

**Current state**: Flow-procedures.md SS1.2 (lines 52-134) summarizes each Socratic category in 3-4 lines. Socratic-protocol.md provides the full version with question templates and options. The summaries are useful as a quick-reference but duplicate approximately 40% of the Socratic Protocol content.

**Recommendation**: This is an acceptable trade-off for progressive disclosure (subagents loading flow-procedures.md get enough context without needing to also load socratic-protocol.md). No action required unless file size becomes a concern. Noting for awareness.

---

### F14: Second-Person "I" Voice in Question Templates

**Severity**: INFO
**Category**: Terminology consistency (voice observation)
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/socratic-protocol.md`

**Current state**: Question templates use first-person "I" from the agent's perspective: "I found [N issues]", "I identified [N] frames", "I propose: Cards=16px". This is appropriate for user-facing prompts that will be presented via `AskUserQuestion`.

**Recommendation**: No change needed. The first-person voice is correct for dialogue templates. This observation is noted because the project's CLAUDE.md specifies avoiding second-person "you" in instructional text, and the Socratic Protocol correctly uses first-person "I" for agent speech and second-person "you" only in questions directed at the user ("Do you have design briefs...").

---

## Strengths

### S1: SKILL.md Achieves Lean Dispatch Table Goals

The SKILL.md file stays under 260 lines while covering two flows, four modes, a decision matrix, essential rules, and a full selective-loading catalog. It delegates detail to references rather than embedding it, following the Hub-Spoke pattern effectively. Section headers are descriptive, tables are dense, and the Quick Start section provides a genuine 10-second orientation.

### S2: Essential Rules Use Consistent Imperative Voice

The 23 MUST rules and 14 AVOID rules in essential-rules.md consistently use bold imperative verbs ("Wrap", "Use", "Load", "Set", "Check", "Never mutate", "Never return"). Each rule leads with the action, follows with the technical reason, and stays within 1-2 lines. This is exemplary instructional writing for an AI-consumed reference file.

### S3: Decision Matrix Is Maximally Dense

The Decision Matrix in SKILL.md (lines 94-101) packs gate evaluation, branching logic, and tool selection into a 5-row table with zero filler. Each row earns its place. The "Evaluate G0->G1a->G1b->G2->G3 in order" instruction is a single sentence that replaces what could be a multi-paragraph explanation.

### S4: Cross-References Sections Are Consistent

Every reference file ends with a "Cross-References" section listing related files. This pattern is applied uniformly and uses a terse bullet format. It avoids the common trap of embedding cross-file explanations inline.
