---
lens: "Prompt Engineering Quality"
lens_id: "prompt"
skill_reference: "customaize-agent:prompt-engineering"
target: "figma-console-mastery"
target_path: "/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery"
fallback_used: true
findings_count: 12
critical_count: 0
high_count: 3
medium_count: 5
low_count: 2
info_count: 2
---

# Prompt Engineering Quality Analysis: figma-console-mastery

## Summary

The figma-console-mastery skill is a mature, well-structured prompt artifact that guides Claude through complex Figma design automation workflows. At 255 lines, the SKILL.md orchestrator stays within the recommended lean limit (<300 lines) and effectively delegates procedural detail to 22 reference files. The skill demonstrates strong prompt engineering in its decision matrix, tiered reference loading, and consistent constraint phrasing. However, several areas present ambiguity risks, instruction conflicts between files, and missed opportunities for clearer LLM guidance. No critical issues were found; the skill would function correctly for an experienced user, but three high-severity findings could degrade effectiveness in edge cases or with naive invocations.

---

## Findings

### F1: Inconsistent Category Count Between SKILL.md and socratic-protocol.md

**Severity**: HIGH
**Category**: Instruction clarity and unambiguity
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (line 73) and `references/socratic-protocol.md` (line 6, lines 22-24)

**Current state**: SKILL.md Phase 2 description states "Expanded Socratic Protocol with 11 categories (Cat. 0-10)" and `flow-procedures.md` lists categories 0-9 with the Create mode subset as "Cat. 0, 1, 2 (optional), 5, 6, 7, 8" (7 categories). However, `socratic-protocol.md` header says "10 structured question categories" while actually defining 11 categories (Cat. 0 through Cat. 10). The mode subset table in `socratic-protocol.md` (line 23) includes Cat. 10 for Create mode ("Cat. 0, 1, 2 (optional), 5, 6, 7, 8, 10 (optional)"), but `flow-procedures.md` (line 129) omits Cat. 10 entirely from the Create mode subset: "Create mode: Run Cat. 0, 1, 2 (optional), 5, 6, 7, 8. Skip Cat. 3, 4, 9."

**Recommendation**: Reconcile the category count and mode subsets across all three files. Update `socratic-protocol.md` header to say "11 categories" (matching its actual content and SKILL.md). Update `flow-procedures.md` Create mode subset to include "10 (optional)" to match `socratic-protocol.md`. A subagent loading `flow-procedures.md` for Create mode will currently skip Cat. 10 (Content & Interaction Specifications), while the same subagent loading `socratic-protocol.md` would include it -- producing inconsistent behavior depending on which file is consulted.

---

### F2: Ambiguous Subagent Dispatch Instructions -- No Prompt Template in SKILL.md

**Severity**: HIGH
**Category**: LLM instruction effectiveness
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 75-78)

**Current state**: SKILL.md repeatedly states that phases run "in Sonnet subagent" and "Main context dispatches subagent with approved checklist + references," but never provides an actual dispatch prompt template or specifies exactly which references to inject into the subagent prompt. The instruction to load references "per convergence-protocol.md Subagent Prompt Template" is an indirect reference chain: the reader must navigate from SKILL.md to convergence-protocol.md to find the actual template.

**Recommendation**: Add a minimal dispatch example directly in SKILL.md showing the concrete subagent invocation pattern, including: (1) which `Task()` parameters to use, (2) the minimal reference set to inject per phase, and (3) a one-line example prompt. This can be 5-8 lines. The detailed template can remain in convergence-protocol.md, but the orchestrator (SKILL.md) should not require a two-hop reference chain to perform its core dispatch operation. Alternatively, add a "Subagent Dispatch Quick Reference" subsection after Phase 4 with a table mapping each phase to its required references and a pointer to the full template.

---

### F3: Implicit Mode Guard for Phase Transitions

**Severity**: HIGH
**Category**: Degrees of freedom / edge case coverage
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (lines 53-54)

**Current state**: Phase 2 skip logic is stated as prose: "Skip for: Audit and Targeted modes (go directly to Phase 3)". There is no explicit guard mechanism -- no conditional check template, no state variable to set, and no instruction for how the orchestrator should implement the skip. Similarly, the transition from Phase 3 to Phase 4 lacks an explicit gate check (e.g., "IF execution subagent returned success THEN proceed to Phase 4, ELSE handle failure").

**Recommendation**: Add explicit transition guards as structured decision points. For example:

```
Phase Transition Rules:
- Phase 1 -> Phase 2: IF mode IN {Create, Restructure} THEN Phase 2, ELSE Phase 3
- Phase 2 -> Phase 3: IF user approved checklist THEN Phase 3, ELSE loop Phase 2
- Phase 3 -> Phase 4: IF execution subagent status = "complete" THEN Phase 4, ELSE handle failure
- Phase 4 -> End:     IF audit verdict = "pass" THEN session end, ELSE fix cycle (max N)
```

This removes ambiguity about what "skip" means operationally and ensures Claude follows the correct path without inferring the transition logic.

---

### F4: Decision Matrix Lacks "No Match" Fallback

**Severity**: MEDIUM
**Category**: Edge case coverage
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 94-101)

**Current state**: The Decision Matrix (G0 through G3) instructs evaluation in order but provides no fallback for when none of the gates match. If a user request does not fit any gate (e.g., "export all frames as PNG"), the skill provides no guidance on what to do.

**Recommendation**: Add a G4 or default fallback row: "**G4: Unsupported?** | Operation not covered by figma-console tools | ESCALATE | Ask user for clarification or suggest alternative approach". This prevents Claude from silently choosing an inappropriate path when no gate matches.

---

### F5: "Sonnet Subagent" Instruction Couples Skill to Specific Model

**Severity**: MEDIUM
**Category**: Degrees of freedom / over-prescription
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 22, 52, 76, 78)

**Current state**: The skill hardcodes "Sonnet" as the subagent model throughout (Cross-Cutting Principle P2, flow tables, phase descriptions). This creates a tight coupling to a specific model name that may change, be unavailable, or be suboptimal for certain operations.

**Recommendation**: Abstract the model name to a configurable parameter, either via a config file value (e.g., `config/meta-skills-config.yaml: subagent_model: sonnet`) or by using a role-based label (e.g., "execution subagent" or "worker subagent") in SKILL.md and resolving the model name in only one place. This follows the plugin's own config centralization pattern from CLAUDE.md and makes the skill resilient to model name changes.

---

### F6: Loading Tiers Guidance is Incomplete for Subagents

**Severity**: MEDIUM
**Category**: Instruction clarity
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 212-218)

**Current state**: The "Loading Tiers" section lists which files belong to Tier 1 (always), Tier 2 (by task), and Tier 3 (by need), but does not specify which tasks trigger which Tier 2 files. The mapping is left to inference. For example, when should `session-index-protocol.md` be loaded? When should `essential-rules.md` be loaded? The tier system provides categorization but not actionable loading logic.

**Recommendation**: Add a brief trigger condition next to each Tier 2 file, e.g.:
- `flow-procedures.md` -- load when dispatching any Flow 1/Flow 2 phase subagent
- `socratic-protocol.md` -- load when entering Phase 2 (Create/Restructure)
- `essential-rules.md` -- load for any mutating subagent dispatch
- `session-index-protocol.md` -- load when building/querying Session Index

This transforms the tier list from a classification into actionable instructions.

---

### F7: Redundant Rule Statements Across Files

**Severity**: MEDIUM
**Category**: Use of examples vs. rules / prompt structure
**File**: Multiple files

**Current state**: Several rules are stated in full in both SKILL.md and essential-rules.md, and again in flow-procedures.md. For instance:
- "Use `figma_capture_screenshot` for post-mutation validation" appears in SKILL.md Essential Rules (line 128), essential-rules.md rule 6 (line 19), and flow-procedures.md Phase 4 (line 185).
- "Do NOT proceed to Phase 3 until user approves checklist" appears in SKILL.md (line 73), flow-procedures.md (line 134), and socratic-protocol.md (line 282).

While some redundancy aids recall, triple-stating identical rules across files increases maintenance burden and creates drift risk (as seen in F1).

**Recommendation**: Keep the full canonical statement in essential-rules.md. In SKILL.md, use abbreviated references (e.g., "Post-mutation: `figma_capture_screenshot` (see essential-rules.md #6)"). In flow-procedures.md, use the rule inline where it applies but mark it as sourced from essential-rules.md. This maintains recall benefits while establishing a clear canonical source.

---

### F8: Audit Dimension Count Inconsistency in Flow 2

**Severity**: MEDIUM
**Category**: Instruction clarity and unambiguity
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (lines 178-180, 223-234)

**Current state**: In Flow 1 Phase 4, the Standard tier is described as "11-dimension audit (add Layer Structure, Semantic Naming, Component Compliance 3-layer, Constraints, Screen Properties, Instance Override Integrity, Token Bindings, Operational Efficiency, Accessibility Compliance)" which lists 9 items after "add" (plus the 3 from Spot = 12, or the 9 are meant to replace the Spot 3). Meanwhile, Flow 2 Phase 2 explicitly lists D1-D11 as 11 dimensions. The Spot tier in Flow 1 lists "3 dimensions (D1 Visual Quality, D4 Auto-Layout, D10 Operational Efficiency)" -- but if Standard adds 9 more, that is 12 total, not 11. The parenthetical description in Standard is confusing because it says "add" implying additive to Spot's 3.

**Recommendation**: Clarify the Standard tier description in flow-procedures.md to state "11-dimension audit (all D1-D11)" instead of listing the additions. The explicit D1-D11 enumeration in Flow 2 Phase 2 is the clearest format -- replicate it or simply reference it. Remove the "add" phrasing which implies the 3 Spot dimensions plus the listed dimensions.

---

### F9: No Explicit Failure Handling for `figma_get_status` Gate Check

**Severity**: LOW
**Category**: Edge case coverage
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (line 34)

**Current state**: The prerequisite section says: "Gate check: Call `figma_get_status` before any operation. If 'not connected', load `references/gui-walkthroughs.md`." This tells Claude to load a reference file but does not explicitly state to halt execution, retry, or ask the user. After loading the walkthrough, should Claude present it to the user? Retry the connection? Wait?

**Recommendation**: Make the gate check outcome explicit: "If 'not connected': (1) present gui-walkthroughs.md connection steps to user via AskUserQuestion, (2) wait for user confirmation of connection, (3) re-check with `figma_get_status`. Do not proceed to any phase until status confirms connection."

---

### F10: Numbered Step 3.5 in Flow Procedures

**Severity**: LOW
**Category**: Prompt structure and logical flow
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/flow-procedures.md` (line 32)

**Current state**: Phase 1 shared steps use numbering 1, 2, 3, 3.5, 4, 5, 6. The "3.5" step (Build/validate Session Index) was clearly inserted after initial numbering but not renumbered. While a human reader can follow this, LLMs process numbered lists as sequential instructions and the fractional step introduces minor ambiguity about whether it is a substep of step 3 or an independent step.

**Recommendation**: Renumber to sequential integers: 1, 2, 3, 4, 5, 6, 7. This is a mechanical change but aligns with LLM instruction processing norms. Per the project's CLAUDE.md "Section renumbering cascade" pattern, check for cross-references to these step numbers in other files before renumbering.

---

### F11: Comprehensive Quick Start Section

**Severity**: INFO
**Category**: Prompt structure and logical flow
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/SKILL.md` (lines 37-47)

**Current state**: The Quick Start section provides a compact four-line reference covering the most common operations (check, components, create, variables, validate). This section serves as an effective "cheat sheet" that Claude can use for simple requests without loading any reference files.

**Observation**: This is a well-designed prompt pattern -- providing a fast path for common cases before the full flow machinery. It reduces unnecessary reference loading for simple operations.

---

### F12: Consistent "Let's Discuss This" Escape Hatch Pattern

**Severity**: INFO
**Category**: Edge case coverage
**File**: `/Users/afato/Projects/carlas-pantry/plugins/meta-skills/skills/figma-console-mastery/references/socratic-protocol.md` (throughout)

**Current state**: Every single `AskUserQuestion` template in the Socratic Protocol includes a "Let's discuss this" option, consistently applied across all 11 categories. This is reinforced as Cross-Cutting Principle P3 in SKILL.md, MUST rule 22 in essential-rules.md, and restated in the Socratic Protocol overview.

**Observation**: This is excellent prompt engineering for user-facing agent behavior. The consistent escape hatch prevents the agent from forcing users into false dichotomies and provides a graceful fallback for every decision point. The triple reinforcement (principle, rule, protocol) ensures the pattern survives context pressure.

---

## Strengths

### S1: Lean Orchestrator with Progressive Disclosure

SKILL.md at 255 lines stays within the <300 line lean orchestrator target. The "Selective Reference Loading" section with three tiers (Always, By task, By need) creates an effective progressive disclosure system -- the orchestrator carries minimal context and loads detailed references only when needed. This is a strong prompt architecture pattern that prevents context pollution while maintaining access to 22 reference files totaling ~580KB of specialized knowledge.

### S2: Decision Matrix as Structured Routing Logic

The G0-G3 Decision Matrix (SKILL.md lines 94-101) is an exemplary prompt engineering pattern. It provides Claude with a clear, ordered evaluation sequence ("Evaluate G0->G1a->G1b->G2->G3 in order") with specific tools mapped to each gate. This eliminates ambiguity about tool selection -- one of the most error-prone aspects of multi-tool MCP interactions. The matrix format is scannable and unambiguous.

### S3: Dual-Level Rule Presentation

The "Essential Rules (Top 8)" section in SKILL.md provides the most critical MUST and AVOID rules directly in the orchestrator, with a clear pointer to the full 37-rule set in essential-rules.md. This dual-level approach ensures the orchestrator always has the most important constraints in context, while subagents can load the complete ruleset. This is a well-calibrated balance between context efficiency and constraint completeness.

### S4: Mode Selection Table as Behavioral Router

The Mode Selection table (SKILL.md lines 62-67) maps user intent patterns to concrete mode names and then to per-phase behavior. This is an effective "intent classifier" embedded in the prompt that helps Claude correctly route ambiguous requests (e.g., distinguishing "check this frame" from "restructure this design"). The table format makes the routing logic scannable and unambiguous.
