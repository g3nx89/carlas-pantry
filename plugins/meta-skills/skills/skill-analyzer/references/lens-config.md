# Lens Configuration

This file defines the default evaluation lenses and the mechanism for overriding them.

## Default Lenses

### Lens 1: Structure & Progressive Disclosure

- **Lens ID**: `structure`
- **Lens Name**: `Structure & Progressive Disclosure`
- **Skill Reference**: `plugin-dev:skill-development`
- **Focus Areas**:
  - Frontmatter quality (name, description, trigger phrases)
  - Third-person voice in description with specific trigger phrases
  - Directory layout (references/, examples/, scripts/)
  - Progressive disclosure (SKILL.md lean, details in references/)
  - Reference file wiring (all referenced files exist, SKILL.md points to them)
  - Writing style (imperative/infinitive form, no second-person)
- **Output Filename**: `structure-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Does the frontmatter use third-person voice with specific trigger phrases that users would actually say?
  2. Is the SKILL.md body under 2,000 words, with detailed content moved to references/?
  3. Are all referenced files (references/, examples/, scripts/) actually present in the directory?
  4. Does the SKILL.md explicitly reference its bundled resources with file paths?
  5. Are instructions written in imperative/infinitive form (not second-person)?
  6. Does the directory structure follow the standard layout (SKILL.md + references/ + examples/)?
  7. Are examples complete, runnable, and well-documented?

### Lens 2: Prompt Engineering Quality

- **Lens ID**: `prompt`
- **Lens Name**: `Prompt Engineering Quality`
- **Skill Reference**: `customaize-agent:prompt-engineering`
- **Focus Areas**:
  - Instruction clarity and unambiguity
  - LLM instruction effectiveness (does the skill guide Claude well?)
  - Degrees of freedom (are instructions specific enough without being over-constrained?)
  - Prompt structure and logical flow
  - Use of examples vs. rules for conveying behavior
- **Output Filename**: `prompt-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Are instructions clear, specific, and unambiguous?
  2. Is the logical flow of the skill coherent (does it guide Claude through a clear process)?
  3. Are there appropriate constraints without being over-prescriptive?
  4. Do examples complement rules, or are they redundant?
  5. Are edge cases and decision points explicitly addressed?
  6. Would another Claude instance follow these instructions correctly without additional context?

### Lens 3: Context Engineering Efficiency

- **Lens ID**: `context`
- **Lens Name**: `Context Engineering Efficiency`
- **Skill Reference**: `customaize-agent:context-engineering`
- **Focus Areas**:
  - Token management (is SKILL.md appropriately sized?)
  - Progressive loading strategy (metadata → body → references)
  - Context degradation risk (what happens when context fills?)
  - Attention placement (is critical information positioned for LLM attention?)
  - Selective reference loading patterns
- **Output Filename**: `context-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Is the SKILL.md sized appropriately for always-loaded content (target: 1,500-2,000 words)?
  2. Is there clear separation between always-loaded content and on-demand references?
  3. Is critical information placed where LLMs attend most (beginning, end, headers)?
  4. Are reference files designed for selective loading (can Claude pick which to load)?
  5. Would context window pressure cause important instructions to be lost?
  6. Are there redundancies between SKILL.md and reference files that waste tokens?

### Lens 4: Writing Quality & Conciseness

- **Lens ID**: `writing`
- **Lens Name**: `Writing Quality & Conciseness`
- **Skill Reference**: `docs:write-concisely`
- **Focus Areas**:
  - Active voice vs. passive constructions
  - Needless words and filler phrases
  - Conciseness (every sentence earns its place)
  - Clarity and readability
  - Consistent terminology
- **Output Filename**: `writing-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Does the writing use active voice consistently?
  2. Are there needless words, filler phrases, or verbose constructions?
  3. Does every sentence convey meaningful information (no filler paragraphs)?
  4. Is terminology consistent throughout (no synonym churn)?
  5. Are sentences structured for clarity (subject-verb-object, short sentences for instructions)?
  6. Could any section be cut in half without losing essential meaning?

### Lens 5: Overall Effectiveness

- **Lens ID**: `effectiveness`
- **Lens Name**: `Overall Effectiveness`
- **Skill Reference**: `customaize-agent:agent-evaluation`
- **Focus Areas**:
  - Evaluation rubric dimensions (completeness, accuracy, reasoning)
  - Does the skill achieve its stated purpose?
  - Instruction-following quality (would Claude follow these correctly?)
  - Coverage of edge cases and error paths
  - Overall coherence and usefulness
- **Output Filename**: `effectiveness-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Does the skill clearly state its purpose and deliver on it?
  2. Would Claude follow these instructions correctly in a real scenario?
  3. Are edge cases, error paths, and "when NOT to use" scenarios covered?
  4. Is the skill internally consistent (no contradictory instructions)?
  5. Does the skill provide enough context for Claude to make good decisions?
  6. Is the skill complete — or are there obvious gaps in coverage?

### Lens 6: Reasoning & Decomposition

- **Lens ID**: `reasoning`
- **Lens Name**: `Reasoning & Decomposition Quality`
- **Skill Reference**: `customaize-agent:thought-based-reasoning`
- **Focus Areas**:
  - Reasoning methodology selection (CoT, ToT, ReAct, Reflexion, Least-to-Most)
  - Explicit step-by-step logic vs. implicit reasoning leaps
  - Decomposition of complex problems into manageable subproblems
  - Verification and self-correction mechanisms
  - Decision framework clarity (when to branch, when to converge)
  - Anti-patterns (rubber-stamping, infinite loops, orphaned branches)
- **Output Filename**: `reasoning-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Does the skill rely on complex multi-step reasoning without making the chain explicit?
  2. Are decision points structured with clear criteria, or left to implicit judgment?
  3. Would the skill benefit from multiple independent reasoning paths (self-consistency)?
  4. Can the skill's core problem be decomposed into simpler subproblems (Least-to-Most)?
  5. Does the skill include self-correction or verification after critical steps?
  6. Are there reasoning anti-patterns (assumptions without evidence, circular logic, missing termination criteria)?
  7. Does the skill interact with external tools in a way that benefits from interleaved reasoning and action (ReAct)?

### Lens 7: Architecture & Coordination

- **Lens ID**: `architecture`
- **Lens Name**: `Architecture & Coordination Quality`
- **Skill Reference**: `sadd:multi-agent-patterns`
- **Focus Areas**:
  - Coordination pattern appropriateness (supervisor, peer-to-peer, hierarchical)
  - Information flow between components (file-based, context passing, summary bus)
  - Bottleneck identification (supervisor context accumulation, serial dependencies)
  - Failure propagation and recovery (what happens when a stage fails?)
  - Output validation between stages (pre/post-conditions)
  - Agent/component specialization justification (avoiding unnecessary complexity)
- **Output Filename**: `architecture-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Is the coordination pattern (supervisor, peer, hierarchical) appropriate for the skill's complexity?
  2. How does information flow between components — is it explicit and traceable?
  3. Where are the bottleneck risks (context accumulation, serial dependencies, single points of failure)?
  4. How do errors in one stage propagate to downstream stages — is there isolation?
  5. Is output validated before being passed between components?
  6. Are agent/component specializations justified, or does the skill over-complicate with unnecessary agents?
  7. Could consensus problems (sycophancy, false agreement) occur in multi-agent steps?
  8. Is the architecture simpler than it could be, or does it add coordination overhead without proportional value?

## Optional Lenses

The following lenses are available for specialized analysis. Add them via `additional_lenses` when relevant.

### Optional: Configuration Quality

- **Lens ID**: `config`
- **Lens Name**: `Configuration & State Quality`
- **Skill Reference**: `plugin-dev:plugin-settings`
- **When to use**: Skills with hardcoded thresholds, project-specific paths, model names, or persistent state.
- **Focus Areas**:
  - Values that should be externalized to config (thresholds, paths, model names)
  - Per-project customization surface (`.claude/plugin-name.local.md` pattern)
  - State persistence across invocations (progress tracking, user decisions)
  - Hardcoded values that vary by project or user preference
- **Output Filename**: `config-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Does the skill hardcode values (thresholds, file paths, model names) that vary by project?
  2. Should the skill support per-project configuration via `.claude/plugin-name.local.md`?
  3. What state should persist across sessions (iteration count, progress, decisions)?
  4. Can users enable/disable skill features without editing skill files?
  5. Are there magic numbers or strings that should be configurable?
  6. Does the skill document `.gitignore` entries for local/state files?

### Optional: Agent Design

- **Lens ID**: `agent-design`
- **Lens Name**: `Agent Design Quality`
- **Skill Reference**: `plugin-dev:agent-development`
- **When to use**: Skills that define, dispatch, or coordinate autonomous agents.
- **Focus Areas**:
  - Agent triggering conditions (description field clarity and specificity)
  - System prompt completeness (responsibilities, edge cases, termination)
  - Tool permission boundaries (principle of least privilege)
  - Responsibility separation between agents
  - Example quality (2-4 concrete triggering examples)
- **Output Filename**: `agent-design-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Are agent triggering conditions clear enough for reliable autonomous activation?
  2. Does each agent's system prompt define clear responsibilities and edge case handling?
  3. Is tool access restricted to what each agent actually needs (least privilege)?
  4. Are there 2-4 concrete examples showing when the agent should trigger?
  5. Are agent descriptions specific about methodology, not vague about "helping"?
  6. Could responsibility boundaries between agents cause overlap or gaps?

### Optional: Reasoning Methodology

- **Lens ID**: `reasoning-method`
- **Lens Name**: `Reasoning Methodology Depth`
- **Skill Reference**: `meta-skills:sequential-thinking-mastery`
- **When to use**: Skills with complex decision trees, hypothesis testing, or diagnostic workflows.
- **Relationship to default `reasoning` lens**: The default reasoning lens evaluates general chain quality (explicit steps, decomposition, verification). This optional lens goes deeper into structured methodology — hypothesis-test-eliminate cycles, branching/revision mechanics, evidence protocols. When both are active, synthesis should treat reasoning-method findings about anti-patterns as potential duplicates of the default reasoning lens.
- **Focus Areas**:
  - Hypothesis generation and elimination discipline
  - Branching and revision mechanics (when to fork, when to revise)
  - Evidence collection and interpretation protocols
  - Checkpoint discipline (consolidation of findings)
  - Termination criteria (when analysis is complete)
- **Output Filename**: `reasoning-method-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Does the skill define how to generate and rank hypotheses by likelihood?
  2. Are there clear rules for when to branch into parallel exploration vs. revise assumptions?
  3. Is evidence collection structured (what counts as evidence, how to interpret conflicting signals)?
  4. Are there checkpoints for consolidating findings before proceeding?
  5. What are the termination criteria (verification, exhaustion of options, actionable plan)?
  6. Are anti-patterns addressed (rubber stamping, orphaned branches, infinite loops)?

### Optional: Escalation Strategy

- **Lens ID**: `escalation`
- **Lens Name**: `Escalation & Model Selection`
- **Skill Reference**: `meta-skills:deep-reasoning-escalation`
- **When to use**: Skills that delegate to external reasoning models or make complexity-based routing decisions.
- **Focus Areas**:
  - Escalation trigger clarity (when to delegate vs. handle locally)
  - Task verifiability assessment (abstract vs. verifiable reasoning)
  - Cost-benefit awareness (latency, token cost, value delivered)
  - Anti-patterns (escalating creative/subjective tasks, unnecessary round-trips)
- **Output Filename**: `escalation-analysis.md`
- **Fallback Criteria** (if Skill tool invocation fails):
  1. Are escalation triggers explicit and measurable (not subjective)?
  2. Does the skill distinguish verifiable from non-verifiable reasoning tasks?
  3. Is there cost-benefit awareness (latency, token cost vs. value gained)?
  4. Are anti-patterns addressed (escalating tasks where Claude already excels)?
  5. Does the skill define what constitutes a "failed attempt" before escalation?
  6. Is the escalation prompt structured for the target model's strengths?

## Override Mechanism

Override the default lens list by specifying parameters when invoking the skill:

- **`override_lenses`**: Replace the entire default list. Provide a list of `{lens_id, skill_reference, focus_areas}` objects.
- **`additional_lenses`**: Append to the default list. Same format as above.
- **`exclude_lenses`**: Remove specific lenses by `lens_id` (e.g., `exclude_lenses: [writing, effectiveness]`).

### Custom Lens Template

Any installed skill can serve as a lens. Define a custom lens with:

```
lens_id: custom-lens-name
lens_name: Human-Readable Name
skill_reference: plugin-name:skill-name
focus_areas:
  - Area 1
  - Area 2
fallback_criteria:
  1. Question if skill not available?
  2. Another fallback question?
output_filename: custom-lens-analysis.md
```

**Maximum recommended lenses**: 11 (7 default + 4 pre-defined optional). Each lens adds ~10-20K tokens. See `config/skill-analyzer-config.yaml` for limits.
