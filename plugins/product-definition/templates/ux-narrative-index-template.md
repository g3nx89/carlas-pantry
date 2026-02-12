# UX Narrative: {{PRODUCT_NAME}}

**Status:** {{DOCUMENT_STATUS}}
**Version:** {{VERSION}}
**Generated:** {{DATE}}
**Screens:** {{SCREEN_COUNT}}
**Output Mode:** Multi-file (progressive disclosure)
**Source:** Figma Desktop

---

## How to Use This Document

This is the **index file** for the UX narrative of {{PRODUCT_NAME}}. Individual screen narratives are stored as separate files in `screens/` — this document provides the overview, global patterns, and navigation links.

**For coding agents:** Read this index first, then load only the screen file(s) you need to implement. Each screen file is self-contained with navigation links to adjacent screens.

**For human reviewers:** Start with Global Patterns below, then use the Screen Inventory table to navigate to individual screens.

**Precedence rule:** If there is a conflict between this narrative and the Figma mockup, the narrative takes precedence. The narrative reflects reviewed and validated design decisions, including any corrections identified during the coherence audit.

---

## Global Patterns

### Shared Components

| Component | Description | Appears On |
|-----------|-------------|------------|
{{SHARED_COMPONENTS_TABLE}}

### Navigation Model

```mermaid
{{NAVIGATION_MERMAID}}
```

### User Journey Flows

{{USER_JOURNEY_DIAGRAMS}}

### Interaction Conventions

| Pattern | Gesture | Used On |
|---------|---------|---------|
{{INTERACTION_CONVENTIONS_TABLE}}

### Terminology Glossary

| Term | Meaning |
|------|---------|
{{GLOSSARY_TABLE}}

---

## Screen Inventory

| # | Screen | Node ID | Score | Purpose | File |
|---|--------|---------|-------|---------|------|
{{SCREEN_INVENTORY_TABLE}}

---

## State Machine Diagrams

{{STATE_MACHINE_DIAGRAMS}}

---

## Appendices

| Document | Description | Path |
|----------|-------------|------|
| Coherence Report | Cross-screen consistency audit, shared patterns, mermaid diagrams | [coherence-report.md](coherence-report.md) |
| Validation Synthesis | MPA agent scores, PAL consensus, quality score | [validation/synthesis.md](validation/synthesis.md) |
| Decision Log | Full audit trail of all decisions and revisions | [decision-log.md](decision-log.md) |
| Auto-Resolved Questions | Questions answered automatically from input documents | [working/auto-resolved-questions.md](working/auto-resolved-questions.md) |

---

## Decision Revision Summary

{{DECISION_REVISION_SUMMARY}}

---

## Validation Summary

### MPA Results

| Agent | Score | Key Findings |
|-------|-------|-------------|
{{MPA_RESULTS_TABLE}}

### PAL Consensus

| Model | Verdict | Notes |
|-------|---------|-------|
{{PAL_CONSENSUS_TABLE}}

**Overall Quality Score:** {{QUALITY_SCORE}}/100 | **Recommendation:** {{RECOMMENDATION}}
