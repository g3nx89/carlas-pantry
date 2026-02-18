# Feature Implementation Workflow Diagram

> Auto-generated from `skills/implement/` reference files. Keep in sync with SKILL.md v3.0.0.

## High-Level Orchestrator Flow

```mermaid
flowchart TD
    START(["/product-implementation:implement"]) --> READ_STATE["Read state file\n.implementation-state.local.md"]
    READ_STATE --> MIGRATE{version == 1\nor missing?}
    MIGRATE -- Yes --> V2_MIGRATE["Migrate to v2\n(preserve all v1 fields)"]
    V2_MIGRATE --> DISPATCH_LOOP
    MIGRATE -- No --> DISPATCH_LOOP

    DISPATCH_LOOP["Dispatch Loop\n(stages 1 → 5)"]

    subgraph LOOP["FOR stage IN [1, 2, 3, 4, 5]"]
        direction TB
        CHECK_DONE{stage summary\nalready exists?}
        CHECK_DONE -- Yes --> SKIP_STAGE["SKIP\n(already done)"]
        CHECK_DONE -- No --> CHECK_DELEGATION{delegation\ntype?}

        CHECK_DELEGATION -- inline --> EXEC_INLINE["Execute inline\n(Stage 1 only)"]
        CHECK_DELEGATION -- coordinator --> DISPATCH_COORD["DISPATCH_COORDINATOR(stage)\nvia Task(general-purpose)"]

        EXEC_INLINE --> WRITE_SUMMARY["Write stage summary"]
        DISPATCH_COORD --> CHECK_SUMMARY{summary file\nexists?}

        CHECK_SUMMARY -- No --> CRASH_RECOVERY["CRASH_RECOVERY\nReconstruct from artifacts\nor mark failed"]
        CHECK_SUMMARY -- Yes --> VALIDATE_SUMMARY["Validate required fields:\nstage, status, checkpoint,\nartifacts_written, summary"]

        CRASH_RECOVERY --> USER_CRASH{"User choice"}
        USER_CRASH -- Retry --> DISPATCH_COORD
        USER_CRASH -- Continue degraded --> VALIDATE_SUMMARY
        USER_CRASH -- Abort --> RELEASE_LOCK_ABORT["Release lock & HALT"]

        VALIDATE_SUMMARY --> CHECK_STATUS{summary\nstatus?}

        CHECK_STATUS -- completed --> UPDATE_STATE["Update state:\nstage_summaries[N] = path\ncurrent_stage = next\ncheckpoint timestamp"]
        CHECK_STATUS -- needs-user-input --> USER_RELAY["AskUserQuestion\n(from block_reason)"]
        CHECK_STATUS -- failed --> USER_FAIL{"User: retry /\nskip / abort?"}

        USER_RELAY --> WRITE_INPUT["Write user answer to\nstage-N-user-input.md"]
        WRITE_INPUT --> REDISPATCH["Re-dispatch coordinator\n(reads user-input file)"]
        REDISPATCH --> CHECK_SUMMARY

        USER_FAIL -- Retry --> DISPATCH_COORD
        USER_FAIL -- Abort --> RELEASE_LOCK_ABORT

        UPDATE_STATE --> NEXT_STAGE["Next stage"]
        WRITE_SUMMARY --> CHECK_STATUS
    end

    DISPATCH_LOOP --> CHECK_DONE
    NEXT_STAGE --> CHECK_DONE
    SKIP_STAGE --> NEXT_STAGE

    UPDATE_STATE -- All 5 stages done --> COMPLETE([Implementation Complete])
    RELEASE_LOCK_ABORT --> HALTED([Halted])
```

## Stage 1: Setup & Context Loading (Inline)

```mermaid
flowchart TD
    S1_START(["Stage 1: Setup & Context Loading"]) --> BRANCH["1.1 Branch Parsing\ngit branch --show-current"]
    BRANCH --> DERIVE["Derive: PROJECT_ROOT,\nFEATURE_NAME, FEATURE_DIR,\nTASKS_FILE"]
    DERIVE --> BRANCH_OK{branch format\nmatches?}
    BRANCH_OK -- No --> ASK_USER["AskUserQuestion:\nprovide FEATURE_NAME"]
    BRANCH_OK -- Yes --> REQ_FILES
    ASK_USER --> REQ_FILES

    REQ_FILES["1.2 Required Files Check"]
    REQ_FILES --> HAS_TASKS{tasks.md\nexists?}
    HAS_TASKS -- No --> HALT_TASKS(["HALT: Run\n/product-planning:tasks"])
    HAS_TASKS -- Yes --> HAS_PLAN{plan.md\nexists?}
    HAS_PLAN -- No --> HALT_PLAN(["HALT: Run\n/product-planning:plan"])
    HAS_PLAN -- Yes --> OPT_FILES

    OPT_FILES["1.3 Optional Files\nRead: spec, design, contract,\ndata-model, research, test-plan"]
    OPT_FILES --> EXPECTED["1.3a Expected Files Check\nWarn if missing:\ndesign.md, test-plan.md"]
    EXPECTED --> TEST_DISC["1.3b Test Cases Discovery\nScan test-cases/ directory"]
    TEST_DISC --> CONTEXT_LOAD["1.4 Context Loading\nRead tasks.md, plan.md,\noptional files, CLAUDE.md"]
    CONTEXT_LOAD --> VALIDATE_TASKS["1.5 Tasks.md Validation\nParse phases, tasks, [P] markers\nValidate structure"]

    VALIDATE_TASKS --> EMPTY_CHECK{zero phases?}
    EMPTY_CHECK -- Yes --> HALT_EMPTY(["HALT: tasks.md\nhas no parseable phases"])
    EMPTY_CHECK -- No --> DOMAIN_DET

    DOMAIN_DET["1.6 Domain Detection\nScan task paths + plan.md\nvs config domain_mapping"]
    DOMAIN_DET --> MCP_CHECK["1.6a MCP Availability Check\nProbe: Ref, Context7, Tavily"]
    MCP_CHECK --> URL_EXTRACT["1.6b URL Extraction\nfrom planning artifacts"]
    URL_EXTRACT --> LIB_RESOLVE["1.6c Library ID Pre-Resolution\nvia Context7"]
    LIB_RESOLVE --> PRIV_DOCS["1.6d Private Doc Discovery\nvia Ref"]
    PRIV_DOCS --> CLI_CHECK["1.7a CLI Availability Detection\nHealthcheck: codex, gemini"]
    CLI_CHECK --> LOCK["1.7 Lock Acquisition"]

    LOCK --> LOCK_CHECK{state file\nexists?}
    LOCK_CHECK -- No --> INIT_STATE["1.8 State Init (new)"]
    LOCK_CHECK -- Yes --> LOCK_STATUS{lock\nstatus?}
    LOCK_STATUS -- "not acquired" --> ACQUIRE_LOCK["Acquire lock"]
    LOCK_STATUS -- "stale (>60min)" --> OVERRIDE_LOCK["Override stale lock"]
    LOCK_STATUS -- "active" --> HALT_LOCK(["HALT: Another session\nis active"])
    ACQUIRE_LOCK --> RESUME["1.8 Resume: Read state,\nmigrate v1→v2 if needed,\nreconcile with tasks.md"]
    OVERRIDE_LOCK --> RESUME
    INIT_STATE --> USER_INPUT

    RESUME --> USER_INPUT["1.9 User Input Handling\nParse arguments/preferences"]
    USER_INPUT --> WRITE_S1["1.10 Write Stage 1 Summary\ndetected_domains, mcp_availability,\ncli_availability, extracted_urls,\nresolved_libraries, artifacts table"]
    WRITE_S1 --> S1_DONE(["Stage 1 Complete → Stage 2"])
```

## Stage 2: Phase-by-Phase Execution (Coordinator)

```mermaid
flowchart TD
    S2_START(["Stage 2: Phase-by-Phase Execution"]) --> SKILL_RES["2.0 Skill Reference Resolution\nResolve dev-skills for developer\nagent prompts (once)"]
    SKILL_RES --> RESEARCH_RES["2.0a Research Context Resolution\nPre-read URLs via Ref,\nquery Context7 libraries (once)"]
    RESEARCH_RES --> PHASE_LOOP

    subgraph PHASE_LOOP["2.1 Phase Loop (for each phase in tasks.md)"]
        direction TB
        PARSE["Step 1: Parse Phase Tasks\nExtract [P] parallel, sequential,\nfile targets, dependencies"]
        PARSE --> CLI_TEST{CLI test author\nenabled & codex\navailable?}
        CLI_TEST -- Yes --> TEST_AUTHOR["Step 1.8: CLI Test Author\n(Option H)\nCodex generates TDD tests\nfrom test-case specs"]
        CLI_TEST -- No --> DEV_AGENT
        TEST_AUTHOR --> VERIFY_RED["Verify tests FAIL\n(Red phase)"]
        VERIFY_RED --> DEV_AGENT

        DEV_AGENT["Step 2: Launch Developer Agent\nTask(developer)\nTDD: test → implement → verify\nper task in phase"]

        DEV_AGENT --> VERIFY_PHASE["Step 3: Verify Phase\nAll tasks [X]?\nTests passing?\nNo compile errors?"]
        VERIFY_PHASE --> PHASE_OK{verification\npassed?}

        PHASE_OK -- "Sequential fail" --> HALT_SEQ(["HALT: Report\nfailed task"])
        PHASE_OK -- "Parallel [P] fail" --> COLLECT_FAIL["Collect failures,\ncontinue others"]
        PHASE_OK -- Yes --> UPDATE_PROG["Step 4: Update Progress\nMark [X] in tasks.md\nUpdate state file"]

        COLLECT_FAIL --> UPDATE_PROG

        UPDATE_PROG --> AUTO_COMMIT{auto_commit\nstrategy?}
        AUTO_COMMIT -- per_phase --> COMMIT_PHASE["Step 4.5: Auto-Commit\nphase changes"]
        AUTO_COMMIT -- batch --> NEXT_PHASE
        COMMIT_PHASE --> NEXT_PHASE

        NEXT_PHASE{more phases?}
        NEXT_PHASE -- Yes --> PARSE
    end

    NEXT_PHASE -- No --> CLI_AUG{test augmenter\nenabled & gemini\navailable?}
    CLI_AUG -- Yes --> TEST_AUG["2.1a CLI Test Augmenter\n(Option I)\nGemini discovers edge cases\nConfirm bug discoveries"]
    CLI_AUG -- No --> BATCH_CHECK
    TEST_AUG --> BATCH_CHECK

    BATCH_CHECK{batch commit\nneeded?}
    BATCH_CHECK -- Yes --> BATCH_COMMIT["Batch auto-commit\nall phases"]
    BATCH_CHECK -- No --> WRITE_S2
    BATCH_COMMIT --> WRITE_S2

    WRITE_S2["2.3 Write Stage 2 Summary\ntest_count_verified,\ncommits_made,\nresearch_urls_discovered"]
    WRITE_S2 --> S2_DONE(["Stage 2 Complete → Stage 3"])
```

## Stage 3: Completion Validation (Coordinator)

```mermaid
flowchart TD
    S3_START(["Stage 3: Completion Validation"]) --> VAL_AGENT["3.1 Launch Validation Agent\nTask(developer)"]
    S3_START --> CLI_SPEC{spec validator\nenabled & gemini\navailable?}

    CLI_SPEC -- Yes --> SPEC_VAL["3.1a CLI Spec Validator\n(Option C)\nGemini cross-validates\nimplementation vs specs"]
    CLI_SPEC -- No --> WAIT_VAL

    VAL_AGENT --> WAIT_VAL["Wait for all validators"]
    SPEC_VAL --> WAIT_VAL

    WAIT_VAL --> MERGE{CLI validator\nran?}
    MERGE -- Yes --> MERGE_RESULTS["Merge results\nConservative: use LOWER\ntest count\nDisagreements: NEEDS\nMANUAL REVIEW"]
    MERGE -- No --> CHECKS

    MERGE_RESULTS --> CHECKS

    subgraph CHECKS["3.2 Validation Checks"]
        direction TB
        C1["✓ Task completeness\n(all [X] in tasks.md)"]
        C2["✓ Specification alignment"]
        C3["✓ Test coverage"]
        C4["✓ Plan adherence"]
        C5["✓ Integration integrity"]
        C6["✓ Test ID traceability\n(if test_cases available)"]
        C7["✓ Constitution compliance\n(if CLAUDE.md exists)"]
        C8["✓ Test coverage delta\n(if test-plan.md available)"]
        C9["✓ Independent test count\n(baseline_test_count)"]
        C10["✓ Stage 2 cross-validation"]
        C11["✓ Test quality gate\n(tautological assertion scan)"]
        C12["✓ API doc alignment\n(if research_context available)"]
    end

    CHECKS --> REPORT["3.3 Validation Report\nPASS / PASS WITH NOTES /\nNEEDS ATTENTION"]

    REPORT --> ISSUES{issues found?}
    ISSUES -- No --> WRITE_S3_OK["Write summary:\nstatus: completed\nvalidation_outcome: passed"]
    ISSUES -- Yes --> WRITE_S3_INPUT["Write summary:\nstatus: needs-user-input\nblock_reason: validation report"]

    WRITE_S3_INPUT --> USER_VAL{"Orchestrator →\nUser choice"}
    USER_VAL -- "Fix now" --> FIX_VAL["Launch developer\nagent to fix issues"]
    USER_VAL -- "Proceed anyway" --> WRITE_S3_PROCEED["validation_outcome:\nproceed_anyway"]
    USER_VAL -- "Stop here" --> WRITE_S3_STOP["validation_outcome:\nstopped → HALT"]

    FIX_VAL --> REVALIDATE["Re-validate"]
    REVALIDATE --> WRITE_S3_FIXED["validation_outcome: fixed"]

    WRITE_S3_OK --> S3_DONE(["Stage 3 Complete → Stage 4"])
    WRITE_S3_PROCEED --> S3_DONE
    WRITE_S3_FIXED --> S3_DONE
    WRITE_S3_STOP --> HALTED_S3(["Halted"])
```

## Stage 4: Quality Review (Coordinator)

```mermaid
flowchart TD
    S4_START(["Stage 4: Quality Review"]) --> SKILL_REV["4.1a Skill Reference Resolution\nResolve skills + conditional\nreview dimensions"]
    SKILL_REV --> RESEARCH_REV["4.1b Research Context Resolution\nRe-read accumulated URLs (Ref cache)\nContext7 pitfalls/deprecations"]
    RESEARCH_REV --> DISPATCH_TIERS["4.1 Three-Tier Dispatch\n(all available tiers in parallel)"]

    DISPATCH_TIERS --> TIER_A
    DISPATCH_TIERS --> TIER_B
    DISPATCH_TIERS --> TIER_C

    subgraph TIER_A["Tier A: Native Multi-Agent Review (always)"]
        R1["Reviewer 1: developer\nSimplicity / DRY / Elegance"]
        R2["Reviewer 2: developer\nBugs / Functional Correctness"]
        R3["Reviewer 3: developer\nProject Conventions"]
        R_COND["+ Dev-skills conditional\nreviewers (always native)"]
    end

    subgraph TIER_B["Tier B: Plugin Review (if installed)"]
        PLUGIN_CHECK{code-review\nplugin available?}
        PLUGIN_CHECK -- Yes --> PLUGIN_INVOKE["Invoke code-review:\nreview-local-changes\nvia context-isolated subagent"]
        PLUGIN_CHECK -- No --> PLUGIN_SKIP["Skip Tier B"]
    end

    subgraph TIER_C["Tier C: CLI Multi-Model Review (if enabled)"]
        direction TB
        CLI_P1["Phase 1 (parallel):\nCodex correctness\n+ conditional security\n+ Gemini android domain"]
        CLI_P1 --> CLI_MERGE["Consolidation checkpoint:\nextract Critical/High"]
        CLI_MERGE --> CLI_P2{Critical/High\nfindings?}
        CLI_P2 -- Yes --> CLI_PATTERN["Phase 2: Gemini\ncodebase pattern search\n(1M context)"]
        CLI_P2 -- No --> CLI_DONE["Phase 2 skipped"]
    end

    TIER_A --> CONSOLIDATE
    TIER_B --> CONSOLIDATE
    TIER_C --> CONSOLIDATE

    CONSOLIDATE["4.3 Finding Consolidation\nConfidence scoring,\ndeduplicate, classify severity,\nreclassify Medium → High\n(escalation triggers)"]

    CONSOLIDATE --> AUTO_DECISION{auto-decision\nmatrix}

    AUTO_DECISION -- "No findings" --> ACCEPTED["status: completed\nreview_outcome: accepted"]
    AUTO_DECISION -- "Low only" --> ACCEPTED_LOW["Auto-accept Low\nreview_outcome: accepted"]
    AUTO_DECISION -- "Medium ≤ threshold" --> ACCEPTED_MED["Auto-accept Medium+Low\nreview_outcome: accepted"]
    AUTO_DECISION -- "Critical/High or\nexcessive Medium" --> ESCALATE["status: needs-user-input\nblock_reason: findings"]

    ESCALATE --> USER_REV{"Orchestrator →\nUser choice"}
    USER_REV -- "Fix now" --> CHECK_FIX{CLI fix engineer\nenabled & codex\navailable?}
    USER_REV -- "Fix later" --> DEFER["Write review-findings.md\nreview_outcome: deferred"]
    USER_REV -- "Proceed as-is" --> PROCEED["review_outcome: accepted"]

    CHECK_FIX -- Yes --> CLI_FIX["Option F: Codex Fix Engineer\nFix Critical + High findings"]
    CHECK_FIX -- No --> NATIVE_FIX["Native developer agent\nFix Critical + High findings"]

    CLI_FIX --> POST_FIX
    NATIVE_FIX --> POST_FIX

    POST_FIX["Post-fix validation:\n- Tests pass?\n- test_count ≥ baseline?\n- Write deferred findings\n- Auto-commit fixes"]
    POST_FIX --> FIXED["review_outcome: fixed"]

    ACCEPTED --> WRITE_S4
    ACCEPTED_LOW --> WRITE_S4
    ACCEPTED_MED --> WRITE_S4
    DEFER --> WRITE_S4
    PROCEED --> WRITE_S4
    FIXED --> WRITE_S4

    WRITE_S4["4.5 Write Stage 4 Summary"]
    WRITE_S4 --> S4_DONE(["Stage 4 Complete → Stage 5"])
```

## Stage 5: Feature Documentation (Coordinator)

```mermaid
flowchart TD
    S5_START(["Stage 5: Feature Documentation"]) --> VERIFY["5.1 Implementation Verification\nCheck all tasks [X] in tasks.md"]
    VERIFY --> COMPLETE{all tasks\ncomplete?}

    COMPLETE -- Yes --> SKILL_DOC
    COMPLETE -- No --> WRITE_S5_INPUT["status: needs-user-input\nblock_reason: incomplete tasks"]

    WRITE_S5_INPUT --> USER_DOC{"Orchestrator →\nUser choice"}
    USER_DOC -- "Fix now" --> FIX_TASKS["Launch developer agent\nto fix incomplete tasks"]
    USER_DOC -- "Document as-is" --> NOTE_GAPS["Note incomplete areas\nas known limitations"]
    USER_DOC -- "Stop here" --> HALTED_S5(["Halted"])

    FIX_TASKS --> REVERIFY["Re-verify completion"]
    REVERIFY --> COMPLETE
    NOTE_GAPS --> SKILL_DOC

    SKILL_DOC["5.1a Skill Reference Resolution\nResolve documentation skills\n(mermaid-diagrams, etc.)"]
    SKILL_DOC --> RESEARCH_DOC["5.1b Research Context Resolution\nRe-read accumulated URLs (Ref)\nLink generation, examples,\nmigration notes"]
    RESEARCH_DOC --> TECH_WRITER["5.2 Launch Tech-Writer Agent\nTask(tech-writer)"]

    TECH_WRITER --> DOC_SCOPE

    subgraph DOC_SCOPE["Documentation Scope"]
        D1["Load context:\nspec, plan, tasks,\ncontract, data-model"]
        D2["Review implementation:\nmodified files, solutions"]
        D3["Update docs/:\nAPI guides, usage examples,\narchitecture updates"]
        D4["Update READMEs:\nin affected folders"]
    end

    DOC_SCOPE --> DOC_SUMMARY["5.3 Documentation Summary"]
    DOC_SUMMARY --> AUTO_COMMIT_DOC["5.3a Auto-Commit\ndocumentation changes"]
    AUTO_COMMIT_DOC --> RELEASE["5.4 State Update &\nLock Release"]
    RELEASE --> WRITE_S5["5.5 Write Stage 5 Summary"]
    WRITE_S5 --> S5_DONE(["Stage 5 Complete\nImplementation Finished ✓"])
```

## Inter-Stage Data Flow

```mermaid
flowchart LR
    subgraph S1["Stage 1 Summary (Context Bus)"]
        S1A["detected_domains"]
        S1B["mcp_availability"]
        S1C["cli_availability"]
        S1D["extracted_urls"]
        S1E["resolved_libraries"]
        S1F["private_doc_urls"]
        S1G["test_cases_available"]
        S1H["Planning Artifacts Table"]
    end

    subgraph S2["Stage 2 Summary"]
        S2A["test_count_verified"]
        S2B["commits_made"]
        S2C["research_urls_discovered"]
        S2D["augmentation_bugs_found"]
    end

    subgraph S3["Stage 3 Summary"]
        S3A["baseline_test_count"]
        S3B["validation_outcome"]
        S3C["test_coverage_delta"]
    end

    subgraph S4["Stage 4 Summary"]
        S4A["review_outcome"]
        S4B["test_count_post_fix"]
        S4C["commit_sha"]
    end

    subgraph S5["Stage 5 Summary"]
        S5A["documentation_outcome"]
        S5B["commit_sha"]
    end

    S1 -->|"domains, MCP,\nCLI, URLs,\nlibraries"| S2
    S1 -->|"domains,\ntest_cases"| S3
    S1 -->|"domains,\ncli_availability"| S4
    S1 -->|"detected_domains"| S5

    S2 -->|"test_count,\nresearch_urls"| S3
    S2 -->|"research_urls"| S4
    S2 -->|"research_urls"| S5

    S3 -->|"baseline_test_count,\nvalidation_outcome"| S4
    S3 -->|"validation result"| S5
    S4 -->|"review_outcome"| S5
```

## Resume & Recovery Logic

```mermaid
flowchart TD
    RESUME_START(["Resume from state file"]) --> READ_STATE["Read .implementation-state.local.md"]
    READ_STATE --> CHECK_VER{version?}

    CHECK_VER -- "v1 or missing" --> MIGRATE["Auto-migrate v1 → v2\nAdd stage_summaries,\norchestrator section"]
    CHECK_VER -- v2 --> CHECK_STAGE

    MIGRATE --> CHECK_STAGE{current_stage?}

    CHECK_STAGE -- "< 2" --> FROM_S1["Start from Stage 1"]
    CHECK_STAGE -- "= 2" --> FROM_S2["Resume Stage 2\nfrom first phase in\nphases_remaining"]
    CHECK_STAGE -- "= 3" --> CHECK_VAL{validation_outcome\nexists?}
    CHECK_STAGE -- "= 4" --> CHECK_REV{review_outcome\nexists?}
    CHECK_STAGE -- "= 5" --> CHECK_DOC{documentation_outcome\nexists?}

    CHECK_VAL -- "stopped" --> HALTED(["Halted\n(user previously stopped)"])
    CHECK_VAL -- other --> FROM_S4["Skip to Stage 4"]
    CHECK_VAL -- missing --> FROM_S3["Resume Stage 3"]

    CHECK_REV -- exists --> FROM_S5["Skip to Stage 5"]
    CHECK_REV -- missing --> FROM_S4_R["Resume Stage 4"]

    CHECK_DOC -- exists --> ALREADY_DONE(["Already complete\nReport status"])
    CHECK_DOC -- missing --> FROM_S5_R["Resume Stage 5"]
```
