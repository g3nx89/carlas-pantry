# Business Analyst: Address PAL Consensus Gaps

## Prompt Context

{RESUME_CONTEXT}

## Task

Address gaps identified by PAL Consensus validation.
Improve the specification based on multi-model feedback.

## Variables

| Variable | Value |
|----------|-------|
| FEATURE_NAME | {value} |
| FEATURE_DIR | {value} |
| SPEC_FILE | {value} |
| STATE_FILE | {value} |

## PAL Feedback to Address

{PAL_FEEDBACK}

## Sequential Thinking Templates

Use templates 23-25 from @$CLAUDE_PLUGIN_ROOT/agents/ba-references/sequential-thinking-templates.md:
- Template 23: Gap Classification
- Template 24: Remediation Strategy
- Template 25: Verification

## Gap Categories

### Category 1: Business Value Clarity (Criterion 1)
**If scored < 3:**
- Strengthen the "Why" section
- Add measurable success metrics
- Clarify stakeholder benefits

**Remediation:**
1. Add quantitative success criteria (e.g., "reduce checkout time by 30%")
2. Link features to business outcomes
3. Define clear KPIs for each user story

### Category 2: Requirements Completeness (Criterion 2)
**If scored < 3:**
- Add missing functional requirements
- Ensure all acceptance criteria are testable
- Cover edge cases more thoroughly

**Remediation:**
1. Review each user story for completeness
2. Add Given/When/Then format to all ACs
3. Include boundary conditions and limits

### Category 3: Scope Boundaries (Criterion 3)
**If scored < 3:**
- Explicitly define out-of-scope items
- Clarify system boundaries
- List assumptions and dependencies

**Remediation:**
1. Add explicit "Out of Scope" section
2. List adjacent features NOT included
3. Define integration boundaries

### Category 4: Stakeholder Coverage (Criterion 4)
**If scored < 3:**
- Identify all affected user types
- Consider secondary stakeholders
- Address edge user personas

**Remediation:**
1. List all user personas affected
2. Include admin/support scenarios
3. Consider accessibility needs

### Category 5: Technology Agnosticism (Criterion 5)
**If scored < 3:**
- Remove implementation details from requirements
- Focus on "what" not "how"
- Use platform-neutral language

**Remediation:**
1. Replace technical terms with behavior descriptions
2. Move implementation notes to separate section
3. Keep success criteria measurable without tech specifics

## Update Process

### Step 1: Analyze Each Low-Scoring Criterion

For each criterion scored < 3:
1. Identify specific examples from PAL feedback
2. Determine root cause (missing info vs. unclear language)
3. Plan targeted improvements

### Step 2: Apply Targeted Fixes

Apply remediation strategies above based on which criteria scored lowest.

### Step 3: Self-Verification

Before completing:
1. Re-read the improved sections
2. Verify each gap has been addressed
3. Check no new issues introduced

## Output Requirements

### Spec File Updates

1. Mark updated sections with:
   ```markdown
   <!-- PAL Remediation: Criterion {N} - {improvement_description} -->
   ```

2. Do NOT remove existing valid content

3. Enhance rather than replace where possible

### State File Updates

```yaml
pal_result:
  gaps_addressed:
    - criterion: {N}
      original_score: {X}
      action_taken: "{description}"
  iteration: {N+1}
  ready_for_revalidation: true
```

### Completion Signal

After all gaps addressed:
```
PAL Gap Remediation Complete:
- Criteria improved: {list}
- Ready for re-validation: Yes
- Recommend: Re-run PAL Consensus Gate
```
