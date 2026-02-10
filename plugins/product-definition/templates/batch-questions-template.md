# Batch Questions — Cycle {CYCLE_NUMBER}

> **Product:** {PRODUCT_NAME}
> **Screens analyzed:** {SCREEN_COUNT}
> **Questions in this cycle:** {QUESTION_COUNT}
> **Consolidation stats:** {ORIGINAL_COUNT} raw questions → {CONSOLIDATED_COUNT} after dedup ({REDUCTION_PCT}% reduction)
>
> Answer ALL questions below by marking your choice with `[x]`.
> For "Other", replace the placeholder text with your answer.
> When done, re-run: `/narrate --batch`

---

## How to Answer

For each question:
1. Read the options and their descriptions
2. Mark ONE option with `[x]` (change `[ ]` to `[x]`)
3. If no option fits, mark "Other" and fill in your answer
4. Every question must have exactly one selection

---

## Section 1: Cross-Cutting Decisions `[CROSS]`

> These decisions affect 3 or more screens. Answering them first avoids redundant per-screen questions.

### {PRODUCT}-CQ{NNN}: {Question Title} `[CROSS]`

**Affects screens:** {Screen A}, {Screen B}, {Screen C}, ...

**Question:** {The question text}

| # | Option | Description |
|---|--------|-------------|
| 1 | {Recommended option} *(Recommended)* | {Why this is recommended} |
| 2 | {Alternative A} | {Trade-off description} |
| 3 | {Alternative B} | {Trade-off description} |

**Your choice:**
- [ ] Option 1
- [ ] Option 2
- [ ] Option 3
- [ ] Other: {describe your preference}

---

## Section 2: Conflict Resolutions `[CONFLICT]`

> These questions arise from conflicting assumptions across screens. Resolving them ensures consistency.

### {PRODUCT}-CF{NNN}: {Conflict Title} `[CONFLICT]`

**Conflict between:** {Screen A} vs {Screen B}

**Screen A implies:** {what Screen A's design suggests}
**Screen B implies:** {what Screen B's design suggests}

**Question:** {How should this be resolved?}

| # | Option | Description |
|---|--------|-------------|
| 1 | {Follow Screen A approach} *(Recommended)* | {Rationale} |
| 2 | {Follow Screen B approach} | {Rationale} |
| 3 | {Hybrid approach} | {Description} |

**Your choice:**
- [ ] Option 1
- [ ] Option 2
- [ ] Option 3
- [ ] Other: {describe your preference}

---

## Section 3: Screen-Specific Questions

> Grouped by screen. These apply to individual screens only.

### {SCREEN_NAME_1}

#### {SCREEN_NAME_1}-Q{NNN}: {Question Title}

**Dimension:** {weak critique dimension}

**Question:** {The question text}

| # | Option | Description |
|---|--------|-------------|
| 1 | {Recommended option} *(Recommended)* | {Why this is recommended} |
| 2 | {Alternative A} | {Trade-off description} |
| 3 | {Alternative B} | {Trade-off description} |

**Your choice:**
- [ ] Option 1
- [ ] Option 2
- [ ] Option 3
- [ ] Other: {describe your preference}

---

### {SCREEN_NAME_2}

#### {SCREEN_NAME_2}-Q{NNN}: {Question Title}

**Dimension:** {weak critique dimension}

**Question:** {The question text}

| # | Option | Description |
|---|--------|-------------|
| 1 | {Recommended option} *(Recommended)* | {Rationale} |
| 2 | {Alternative A} | {Trade-off description} |

**Your choice:**
- [ ] Option 1
- [ ] Option 2
- [ ] Other: {describe your preference}

---

## Response Summary

| Section | Total | Answered | Remaining |
|---------|-------|----------|-----------|
| Cross-cutting `[CROSS]` | {N} | {N} | {N} |
| Conflicts `[CONFLICT]` | {N} | {N} | {N} |
| Screen-specific | {N} | {N} | {N} |
| **TOTAL** | **{N}** | **{N}** | **{N}** |
