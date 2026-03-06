<!-- Variable sources:
  - version: schema version (always 1)
  - entry_count: number of learning entries currently in file
  - Entries appended by orchestrator-loop.md APPEND_LEARNING function
  - Categories: error (current). Future: build, test, config, dependency, pattern
  - FIFO: when entry_count >= max_entries, oldest entry is removed before appending
-->
---
version: 1
entry_count: 0
---

# Implementation Learnings (Ralph Loop)

Cross-iteration learnings captured when a coordinator fails and then succeeds on retry.
Read by Stage 1 to inject operational context into the summary for downstream stages.
