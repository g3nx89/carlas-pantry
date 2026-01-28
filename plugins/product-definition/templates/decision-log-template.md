# Decision Log

> Traceability from questions to PRD decisions
> **Generated:** {TIMESTAMP}
> **PRD Version:** {VERSION}

---

## Purpose

This log tracks every decision made during PRD refinement, linking:
- User responses to specific questions
- PRD sections impacted by each decision
- Rationale for chosen options
- Alternatives that were considered

---

## Format

Each decision entry follows this structure:

```markdown
### D-{NNN}: {Decision Title}

**Question:** Q-{NNN} ({Question text})
**Round:** {Round number}
**Selected Answer:** {Option letter} - {Answer text}
**PRD Section:** {Section > Subsection}
**Rationale:** {Why this answer was chosen}
**Alternatives Considered:**
- {Option B}: {Alternative} - Not chosen because {reason}
- {Option C}: {Alternative} - Not chosen because {reason}
```

---

## Decisions

### D-001: {Decision Title}

**Question:** Q-001 ({Question text})
**Round:** 1
**Selected Answer:** A - {Answer text}
**PRD Section:** Executive Summary > Product Vision
**Rationale:** {User's reasoning or "Recommended option selected"}
**Alternatives Considered:**
- B: {Alternative} - Not chosen because {reason}
- C: {Alternative} - Not chosen because {reason}

---

### D-002: {Decision Title}

**Question:** Q-002 ({Question text})
**Round:** 1
**Selected Answer:** {Letter} - {Answer text}
**PRD Section:** Product Definition > What This Product IS
**Rationale:** {Reasoning}
**Alternatives Considered:**
- {Letter}: {Alternative} - {Why not chosen}

---

## Summary by PRD Section

| PRD Section | Decisions | Key Choices |
|-------------|-----------|-------------|
| Executive Summary | D-001, D-005 | {Summary of major choices} |
| Product Definition | D-002, D-006, D-010 | {Summary} |
| Target Users | D-003, D-007 | {Summary} |
| Problem Analysis | D-004, D-008 | {Summary} |
| Value Proposition | D-009, D-011 | {Summary} |
| Core Workflows | D-012, D-015 | {Summary} |
| Feature Inventory | D-013, D-016 | {Summary} |
| Screen Inventory | D-014, D-017 | {Summary} |
| Business Constraints | D-018 | {Summary} |
| Assumptions & Risks | D-019, D-020 | {Summary} |

---

## Custom Responses

Questions where user provided custom answers (Option D):

| Decision | Question | Custom Response |
|----------|----------|-----------------|
| D-{NNN} | Q-{NNN} | {User's custom text} |

---

## Unresolved Items

Questions skipped or marked for follow-up:

| Question | Status | Notes |
|----------|--------|-------|
| Q-{NNN} | Skipped | {Reason} |
| Q-{NNN} | Follow-up | {What needs clarification} |

---

## Traceability Matrix

| Question | Decision | PRD Section | Confidence |
|----------|----------|-------------|------------|
| Q-001 | D-001 | 1.1 Product Vision | High |
| Q-002 | D-002 | 2.1 What This IS | High |
| Q-003 | D-003 | 3.1 Primary Persona | Medium |
| ... | ... | ... | ... |

---

## Version History

| Version | Date | Changes | Decisions Added |
|---------|------|---------|-----------------|
| 1.0.0 | {DATE} | Initial PRD | D-001 to D-{N} |
| 1.1.0 | {DATE} | Extended {sections} | D-{N+1} to D-{M} |
