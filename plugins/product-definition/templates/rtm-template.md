---
feature_id: "{FEATURE_ID}"
spec_version: "{SPEC_VERSION}"
schema_version: 1
coverage:
  total: 0
  covered: 0
  partial: 0
  deferred: 0
  removed: 0
  unmapped: 0
  coverage_pct: 0
---

# Requirements Traceability Matrix: {FEATURE_NAME}

> **Purpose**: Forward traceability from source requirements to specification elements.
> Every requirement extracted from user input must have a conscious disposition — zero UNMAPPED
> requirements allowed before proceeding past Stage 4.

## Traceability Matrix

| REQ ID | Requirement | Disposition | Traced To | Notes |
|--------|-------------|-------------|-----------|-------|
| REQ-001 | {Requirement description} | {DISPOSITION} | {US-NNN, US-NNN.AC-NN, NFR-CAT-NN} | {notes} |

## Disposition Legend

| Disposition | Meaning | Gate Status |
|-------------|---------|-------------|
| COVERED | Requirement fully addressed by one or more spec elements | Passes |
| PARTIAL | Requirement partially addressed — some aspects not yet in spec | Passes (with note) |
| DEFERRED | Requirement acknowledged but explicitly out of scope for this iteration | Passes |
| REMOVED | Entry determined not to be a real requirement after review | Passes |
| UNMAPPED | Requirement not yet addressed — needs disposition decision | **Blocks** |
| PENDING_STORY | User requested a new story be created — awaiting BA in Stage 4.5 | Transient (resolves to COVERED) |

## Backward Trace (Scope Creep Detection)

> Spec elements not traced to any input requirement. These may indicate scope creep
> or requirements that emerged during analysis (which is acceptable if documented).

| Spec Element | Description | Justification |
|--------------|-------------|---------------|
| {US-NNN} | {Story description} | {Why this was added beyond original requirements} |

## Planning Trace

> Reserved for `/plan` — maps REQ-NNN to implementation tasks.
> Populated by the product-planning plugin.

<!-- Planning trace entries will be added by /plan -->

## Verification Trace

> Reserved for `/implement` — maps REQ-NNN to test results.
> Populated by the product-implementation plugin.

<!-- Verification trace entries will be added by /implement -->
