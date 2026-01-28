# Questions - Round {N}

> **Generated:** {TIMESTAMP}
> **Analysis Mode:** {ANALYSIS_MODE}
> **Round:** {N}
> **PRD Mode:** {NEW|EXTEND}
> **Total Questions:** {COUNT}

---

## Instructions

For each question:
1. Select **ONE** answer by marking `[x]` in the checkbox
2. If no answer is suitable, use "Other" and specify your text
3. Add notes in the dedicated section (optional but helpful)
4. When complete → run `/product-definition:requirements` to continue

**Estimated time:** {N} minutes

---

## Section 1: Product Definition

### Q-001: {Question Title}

**Question:** {Clear and complete question}

**Context:**
{Why this question is important. What happens if it's not answered.}

**Multi-Perspective Analysis:**
- 🎯 **Product Strategy:** {Insight from product perspective}
- 👤 **User Experience:** {Insight from UX perspective}
- 💼 **Business Ops:** {Insight from operations perspective}

| # | Answer | Pro | Con | Recommendation |
|---|--------|-----|-----|----------------|
| A | **{Option A}** | {Specific benefits} | {Specific drawbacks} | ★★★★★ (Recommended) |
| B | {Option B} | {Specific benefits} | {Specific drawbacks} | ★★★☆☆ |
| C | {Option C} | {Specific benefits} | {Specific drawbacks} | ★★☆☆☆ |

**Your choice:**
- [ ] A. {Option A short} (Recommended)
- [ ] B. {Option B short}
- [ ] C. {Option C short}
- [ ] D. Other: _________________

**Additional notes:**
<!--
Write here any:
- Reasons for your choice
- Specific context for your case
- Particular constraints to consider
- Clarification questions
-->

**PRD Section:** {Executive Summary / Product Definition / Target Users / etc.}
**Priority:** {CRITICAL / HIGH / MEDIUM}

---

### Q-002: {Next Question Title}

**Question:** {Question}

**Context:**
{Context}

**Multi-Perspective Analysis:**
- 🎯 **Product Strategy:** {Insight}
- 👤 **User Experience:** {Insight}
- 💼 **Business Ops:** {Insight}

| # | Answer | Pro | Con | Recommendation |
|---|--------|-----|-----|----------------|
| A | **{Option A}** | {Pro} | {Con} | ★★★★★ (Recommended) |
| B | {Option B} | {Pro} | {Con} | ★★★☆☆ |
| C | {Option C} | {Pro} | {Con} | ★★☆☆☆ |

**Your choice:**
- [ ] A. {Option A short} (Recommended)
- [ ] B. {Option B short}
- [ ] C. {Option C short}
- [ ] D. Other: _________________

**Additional notes:**
<!-- Reasons, context, constraints -->

**PRD Section:** {Section}
**Priority:** {Priority}

---

## Section 2: Target Users

### Q-00N: {Question}
{Repeat structure}

---

## Section 3: Problem Analysis

### Q-00N: {Question}
{Repeat structure}

---

## Section 4: Value Proposition

### Q-00N: {Question}
{Repeat structure}

---

## Section 5: Workflows and Features

### Q-00N: {Question}
{Repeat structure}

---

## Section 6: Constraints and Risks

### Q-00N: {Question}
{Repeat structure}

---

## Response Summary

| ID | Question | PRD Section | Priority | Answer | Completed? |
|----|----------|-------------|----------|--------|------------|
| Q-001 | {Short title} | Product Definition | CRITICAL | ☐ | ☐ |
| Q-002 | {Short title} | Target Users | HIGH | ☐ | ☐ |
| Q-003 | {Short title} | Problem Analysis | HIGH | ☐ | ☐ |
| ... | ... | ... | ... | ... | ... |

**Progress:** 0/{N} questions answered
**Completion Rate:** 0%

---

## Related Questions

Some questions are related and answers should be consistent with each other:

| Group | Questions | Consistency Note |
|-------|-----------|------------------|
| MVP Scope | Q-001, Q-007, Q-015 | Answers together define the MVP boundaries |
| Target User | Q-003, Q-004, Q-012 | Should describe the same type of person |
| Business Model | Q-002, Q-018, Q-020 | Should be economically consistent |

---

## Completion Notes

### Response Priority
1. **CRITICAL** - Complete these questions first
2. **HIGH** - Important for PRD completeness
3. **MEDIUM** - Useful but not blocking

### If Uncertain
- Use "Other" with your best interpretation
- Add notes explaining your doubts
- The system will handle uncertainties in the next round

### Timing
- Don't rush: thoughtful answers = better PRD
- You can save and resume at any time

---

## After Completing

**Git (optional but recommended):**
```bash
git add requirements/working/QUESTIONS-{NNN}.md
git commit -m "answer(req): round {N} responses completed"
```

**Continue:**
```bash
/product-definition:requirements
```

The workflow will automatically detect your answers and proceed.
