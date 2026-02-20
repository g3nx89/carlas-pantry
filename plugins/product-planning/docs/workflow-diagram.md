# Product Planning Workflow Diagram

## Main 9-Phase Workflow (V-Model)

```mermaid
flowchart TB
    %% Styling
    classDef phase fill:#4A90D9,stroke:#2E5A8B,color:#fff,stroke-width:2px
    classDef decision fill:#F5A623,stroke:#D4880F,color:#fff,stroke-width:2px
    classDef gate fill:#D0021B,stroke:#A00216,color:#fff,stroke-width:2px
    classDef output fill:#7ED321,stroke:#5BA018,color:#fff,stroke-width:2px
    classDef mcp fill:#9013FE,stroke:#6B0FBE,color:#fff,stroke-width:2px
    classDef subphase fill:#50E3C2,stroke:#3BB09A,color:#333,stroke-width:1px
    classDef cli fill:#E91E63,stroke:#AD1457,color:#fff,stroke-width:2px
    classDef devskills fill:#FF9800,stroke:#E65100,color:#fff,stroke-width:1px

    %% Phase 1: Setup & Initialization
    subgraph P1[" Phase 1: Setup & Initialization "]
        direction TB
        P1_1["Prerequisites Check<br/>spec.md, constitution.md"]
        P1_2["Branch & Path Detection"]
        P1_3{"State Exists?"}
        P1_4["Resume"]
        P1_5["Fresh Start"]
        P1_6["Lock Acquisition"]
        P1_7["MCP Availability Check"]
        P1_7b["CLI Detection (1.5b)<br/>CLI availability + role deploy"]
        P1_7c["Dev-Skills Detection (1.5c)<br/>Tech-stack keyword scan"]
        P1_8{"Select Analysis Mode"}

        P1_1 --> P1_2 --> P1_3
        P1_3 -->|Yes| P1_4 --> P1_6
        P1_3 -->|No| P1_5 --> P1_6
        P1_6 --> P1_7 --> P1_7b --> P1_7c --> P1_8
    end

    %% Phase 2: Research & Exploration
    subgraph P2[" Phase 2: Research & Exploration "]
        direction TB
        P2_1["Load Context<br/>spec.md + constitution.md"]
        P2_2["Adaptive Research Depth (A3)<br/>Risk keyword detection"]
        P2_3["Research MCP Enhancement<br/>Context7 / Ref / Tavily"]
        P2_3s["Dev-Skills Loader (2.2c-a)<br/>accessibility, mobile, figma"]
        P2_4["Launch Code Explorers (MPA)<br/>3 parallel agents"]
        P2_5["Learnings Researcher (A2)<br/>Institutional knowledge"]
        P2_6["Sequential Thinking T4-T6<br/>Pattern Recognition"]
        P2_7["TAO Loop Synthesis"]
        P2_8["Consolidate research.md"]
        P2_G{"Gate 1:<br/>Research Quality"}

        P2_1 --> P2_2 --> P2_3
        P2_3 --> P2_3s
        P2_3 --> P2_4
        P2_3s --> P2_6
        P2_4 --> P2_5 --> P2_6 --> P2_7 --> P2_8 --> P2_G
    end

    %% Phase 2b: User Flow Analysis (Complete only)
    subgraph P2b[" Phase 2b: User Flow Analysis "]
        direction TB
        P2b_1["Launch flow-analyzer"]
        P2b_2["Map User Journeys"]
        P2b_3["Generate Decision Tree"]
        P2b_4["Gap Questions for Phase 3"]

        P2b_1 --> P2b_2 --> P2b_3 --> P2b_4
    end

    %% Phase 3: Clarifying Questions
    subgraph P3[" Phase 3: Clarifying Questions "]
        direction TB
        P3_1["Sequential Thinking T1-T3<br/>Problem Decomposition"]
        P3_2["Generate Questions<br/>Scope, Edge Cases, Errors"]
        P3_3["BLOCKING:<br/>Collect User Responses"]
        P3_4["Save Decisions<br/>IMMUTABLE"]

        P3_1 --> P3_2 --> P3_3 --> P3_4
    end

    %% Phase 4: Architecture Design
    subgraph P4[" Phase 4: Architecture Design "]
        direction TB
        P4_0a["Dev-Skills Loader (4.0a)<br/>api-patterns, database, c4,<br/>mermaid, frontend"]
        P4_1["Architecture Pattern Research<br/>Research MCP"]
        P4_2["Launch 3 Architects (MPA)<br/>Grounding / Ideality / Resilience"]
        P4_2w["Wildcard Architect (S5/ToT)<br/>Unconstrained exploration"]
        P4_3["TAO Loop Analysis"]
        P4_4["Diagonal Matrix ST T7a-T8b<br/>Branch exploration"]
        P4_4p["Architecture Pruning Judge<br/>Ranked-choice voting"]
        P4_5["Risk Assessment T11-T13"]
        P4_6["Present Options<br/>Comparison Table"]
        P4_7["Record Architecture Decision"]
        P4_8["Adaptive Strategy (S4)<br/>Direct/Negotiated/Reframe"]
        P4_G{"Gate 2:<br/>Architecture Quality"}

        P4_0a --> P4_2
        P4_1 --> P4_2
        P4_2 --> P4_2w --> P4_3 --> P4_4
        P4_4 --> P4_4p --> P4_5 --> P4_6 --> P4_7 --> P4_8 --> P4_G
    end

    %% Phase 5: Multi-CLI Deep Analysis
    subgraph P5[" Phase 5: Multi-CLI Deep Analysis "]
        direction TB
        P5_1["Check CLI Availability<br/>state.cli.capabilities"]
        P5_2["Prepare Context<br/>Selected Architecture"]
        P5_3["CLI Deep Analysis<br/>3 perspectives x 2 CLIs"]
        P5_4["Synthesize Insights<br/>Convergent vs Divergent"]
        P5_5["Present Findings"]

        P5_1 --> P5_2 --> P5_3 --> P5_4 --> P5_5
    end

    %% Phase 6: Plan Validation
    subgraph P6[" Phase 6: Plan Validation "]
        direction TB
        P6_0a["CLI Plan Review (6.0a)<br/>planreviewer: strategic + feasibility"]
        P6_0["Multi-Judge Debate (S6)<br/>3 rounds: analysis/rebuttal/final"]
        P6_1["CLI Consensus Scoring<br/>advocate + challenger stances"]
        P6_2["Score Divergence Check<br/>delta thresholds: low/moderate/high"]
        P6_3["Score Calculation<br/>20 points across 5 dimensions"]
        P6_V{"Validation<br/>Score?"}
        P6_G["GREEN: Proceed"]
        P6_Y["YELLOW: Document Risks"]
        P6_R["RED: Return to Phase 4"]

        P6_0a --> P6_0 --> P6_1 --> P6_2 --> P6_3 --> P6_V
        P6_V -->|"≥16"| P6_G
        P6_V -->|"12-15"| P6_Y
        P6_V -->|"<12"| P6_R
    end

    %% Phase 6b: Expert Review
    subgraph P6b[" Phase 6b: Expert Review (A4) "]
        direction TB
        P6b_0a["Dev-Skills Loader (6b.0a)<br/>clean-code, api-security"]
        P6b_1["Security Analyst<br/>STRIDE Analysis"]
        P6b_2["Simplicity Reviewer<br/>Over-engineering Check"]
        P6b_CL["CLI Security Audit<br/>securityauditor role"]
        P6b_3{"Blocking<br/>Issues?"}
        P6b_4["Address or Acknowledge"]

        P6b_0a --> P6b_1
        P6b_0a --> P6b_2
        P6b_1 --> P6b_CL --> P6b_3
        P6b_2 --> P6b_3
        P6b_3 -->|Yes| P6b_4
    end

    %% Phase 7: Test Strategy
    subgraph P7[" Phase 7: Test Strategy (V-Model) "]
        direction TB
        P7_1["Load Test Context"]
        P7_1b["Testing Best Practices<br/>Research MCP"]
        P7_1c["Dev-Skills Loader (7.1c)<br/>qa-test-planner, accessibility"]
        P7_3["Risk Analysis<br/>T-RISK-1, T-RISK-2, T-RISK-3"]
        P7_4["Launch QA Agents (MPA)<br/>Strategist / Security / Performance"]
        P7_5["Reconciliation<br/>ST Revision with Phase 5"]
        P7_6["Red Team Branch<br/>Adversarial Analysis"]
        P7_7["TAO Loop QA Synthesis"]
        P7_CL["CLI Test Review<br/>teststrategist role"]
        P7_8["Generate UAT Scripts<br/>Given-When-Then"]
        P7_9["Structure Test Directories"]
        P7_G{"Gate 3:<br/>Test Coverage"}

        P7_1 --> P7_1b --> P7_3
        P7_1 --> P7_1c --> P7_3
        P7_3 --> P7_4
        P7_4 --> P7_5 --> P7_6 --> P7_7 --> P7_CL --> P7_8 --> P7_9 --> P7_G
    end

    %% Phase 8: Test Coverage Validation
    subgraph P8[" Phase 8: Test Coverage Validation "]
        direction TB
        P8_1["Prepare Coverage Matrix<br/>AC + Risks + Stories"]
        P8_2["CLI Consensus Scoring<br/>100% across 5 dimensions"]
        P8_V{"Coverage<br/>Score?"}
        P8_G["GREEN: Proceed"]
        P8_Y["YELLOW: Document Gaps"]
        P8_R["RED: Return to Phase 7"]

        P8_1 --> P8_2 --> P8_V
        P8_V -->|"≥80%"| P8_G
        P8_V -->|"65-79%"| P8_Y
        P8_V -->|"<65%"| P8_R
    end

    %% Phase 8b: Asset Consolidation & Preparation
    subgraph P8b[" Phase 8b: Asset Consolidation "]
        direction TB
        P8b_1["Asset Discovery<br/>Scan spec + design + plan"]
        P8b_2["Manifest Generation<br/>10 asset categories"]
        P8b_3["Self-Critique<br/>3 verification questions"]
        P8b_4{"Assets<br/>Found?"}
        P8b_5["User Validation<br/>Confirm / Edit / Skip"]
        P8b_6["Skip Phase"]

        P8b_1 --> P8b_2 --> P8b_3 --> P8b_4
        P8b_4 -->|"Yes"| P8b_5
        P8b_4 -->|"No"| P8b_6
    end

    %% Phase 9: Task Generation & Completion
    subgraph P9[" Phase 9: Task Generation & Completion "]
        direction TB
        P9_1["Load All Artifacts<br/>spec + plan + design + tests"]
        P9_2["Extract Test IDs<br/>UT / INT / E2E / UAT"]
        P9_2a["Dev-Skills Loader (9.2a)<br/>clean-code"]
        P9_3["Initialize tasks.md"]
        P9_4["Launch Tech-Lead<br/>ST T-TASK-1 to T-TASK-4"]
        P9_5["Clarification Loop<br/>Max 2 iterations"]
        P9_6["Task Validation<br/>Self-critique 5 questions"]
        P9_CL["CLI Task Audit<br/>taskauditor role"]
        P9_7["Generate Final Artifacts"]
        P9_8["Summary Report"]
        P9_9["Post-Planning Menu (A5)"]

        P9_1 --> P9_2 --> P9_2a --> P9_3 --> P9_4
        P9_4 --> P9_5 --> P9_6 --> P9_CL --> P9_7 --> P9_8 --> P9_9
    end

    %% Main Flow Connections
    P1 --> P2
    P2_G -->|"PASS<br/>Complete"| P2b
    P2_G -->|"PASS<br/>Non-Complete"| P3
    P2b --> P3
    P3 --> P4
    P4_G -->|"PASS<br/>Complete/Advanced"| P5
    P4_G -->|"PASS<br/>Standard/Rapid"| P6
    P5 --> P6
    P6_G --> P6b
    P6_Y --> P6b
    P6_R --> P4
    P6b --> P7
    P7_G -->|"PASS"| P8
    P8_G --> P8b
    P8_Y --> P8b
    P8_R --> P7
    P8b_5 --> P9
    P8b_6 --> P9

    %% Apply styles
    class P1_1,P1_2,P1_5,P1_6,P1_7,P2_1,P2_2,P2_4,P2_5,P2_8 phase
    class P1_3,P1_8,P2_G,P4_G,P6_V,P7_G,P8_V,P8b_4 gate
    class P2_3,P2_6,P2_7,P4_1,P4_3,P4_4,P5_1,P5_3,P6_1,P6_2,P7_1b,P7_3,P7_5,P7_6,P7_7,P8_2,P9_4 mcp
    class P6_G,P6_Y,P8_G,P8_Y,P8b_6,P9_7,P9_8 output
    class P2b_1,P2b_2,P2b_3,P6b_1,P6b_2,P8b_1,P8b_2,P8b_3,P8b_5 subphase
    class P5_6,P6_0a,P6b_CL,P7_CL,P9_CL cli
    class P1_7b,P1_7c,P2_3s,P4_0a,P6b_0a,P7_1c,P9_2a devskills
    class P4_2w,P4_4p,P6_0 mcp
```

## Analysis Modes

```mermaid
flowchart LR
    subgraph COMPLETE["Complete Mode<br/>Base: $0.80-$1.50 | With CLI: $1.10-$2.00"]
        C1["MPA: All Agents"]
        C2["CLI Deep Analysis: 6 dispatches"]
        C3["CLI Consensus Scoring"]
        C4["Fork-Join ST"]
        C5["Red Team Branch"]
        C6["Full Test Plan"]
        C7["Expert Review (A4)"]
        C8["Flow Analysis (A1)"]
        C9["Multi-Judge Debate (S6)"]
        C10["CLI: 6 roles"]
        C11["Dev-Skills Loading"]
    end

    subgraph ADVANCED["Advanced Mode<br/>Base: $0.45-$0.75 | With CLI: $0.55-$0.90"]
        A1["MPA: All Agents"]
        A2["CLI Deep Analysis: 4 dispatches"]
        A3["CLI Consensus Scoring"]
        A4["Linear ST"]
        A5["Red Team Branch"]
        A6["Test Plan"]
        A7["Expert Review (A4)"]
        A8["CLI: 6 roles"]
        A9["Dev-Skills Loading"]
    end

    subgraph STANDARD["Standard Mode<br/>$0.15-$0.30"]
        S1["MPA: Architects"]
        S2["No ThinkDeep"]
        S3["TAO Loop"]
        S4["Basic Test Plan"]
        S5["Dev-Skills Loading"]
        S6["No CLI"]
    end

    subgraph RAPID["Rapid Mode<br/>$0.05-$0.12"]
        R1["Single Agent"]
        R2["No MCP"]
        R3["Minimal Tests"]
        R4["No CLI / Dev-Skills"]
    end

    MCP{"MCP<br/>Available?"}
    MCP -->|"Yes"| COMPLETE
    MCP -->|"Yes"| ADVANCED
    MCP -->|"No"| STANDARD
    MCP -->|"No"| RAPID

    style COMPLETE fill:#4A90D9,stroke:#2E5A8B,color:#fff
    style ADVANCED fill:#7ED321,stroke:#5BA018,color:#fff
    style STANDARD fill:#F5A623,stroke:#D4880F,color:#fff
    style RAPID fill:#D0021B,stroke:#A00216,color:#fff
```

## V-Model Test Integration

```mermaid
flowchart TB
    subgraph DEV["Development Phases"]
        direction TB
        REQ["Phase 3: Requirements"]
        ARCH["Phase 4: Architecture"]
        DES["Phase 5: Design"]
        IMPL["Phase 9: Implementation"]

        REQ --> ARCH --> DES --> IMPL
    end

    subgraph TEST["Test Levels"]
        direction TB
        UAT["UAT Scripts<br/>Given-When-Then"]
        E2E["E2E Scenarios<br/>Evidence Collection"]
        INT["Integration Tests<br/>Component Boundaries"]
        UNIT["Unit Tests<br/>TDD: RED-GREEN"]

        UAT --> E2E --> INT --> UNIT
    end

    REQ -.->|"maps to"| UAT
    ARCH -.->|"maps to"| E2E
    DES -.->|"maps to"| INT
    IMPL -.->|"maps to"| UNIT

    subgraph OUTER["Outer Loop: Pre-Release"]
        O1["UAT with PO Sign-off"]
        O2["E2E with Screenshots"]
        O3["Exploratory Testing"]
    end

    subgraph INNER["Inner Loop: CI/Automated"]
        I1["Integration Tests"]
        I2["Unit Tests (TDD)"]
    end

    UAT --> OUTER
    E2E --> OUTER
    INT --> INNER
    UNIT --> INNER

    style DEV fill:#4A90D9,stroke:#2E5A8B,color:#fff
    style TEST fill:#7ED321,stroke:#5BA018,color:#fff
    style OUTER fill:#F5A623,stroke:#D4880F,color:#fff
    style INNER fill:#50E3C2,stroke:#3BB09A,color:#333
```

## MPA (Multi-Perspective Analysis) Pattern

```mermaid
flowchart TB
    subgraph TRIGGER["MPA Trigger Points"]
        T1["Phase 2: Research"]
        T2["Phase 4: Architecture"]
        T3["Phase 7: QA"]
    end

    subgraph P2_MPA["Phase 2 MPA"]
        direction LR
        CE1["Code Explorer 1<br/>Similar Features"]
        CE2["Code Explorer 2<br/>Architecture Patterns"]
        CE3["Code Explorer 3<br/>Integration Points"]
    end

    subgraph P4_MPA["Phase 4 MPA"]
        direction LR
        AR1["Architect 1<br/>Structural Grounding<br/>(Inside-Out × Structure)"]
        AR2["Architect 2<br/>Contract Ideality<br/>(Outside-In × Data)"]
        AR3["Architect 3<br/>Resilience Architecture<br/>(Failure-First × Behavior)"]
    end

    subgraph P7_MPA["Phase 7 MPA"]
        direction LR
        QA1["QA Strategist<br/>V-Model General"]
        QA2["QA Security<br/>STRIDE Analysis"]
        QA3["QA Performance<br/>Load Testing"]
    end

    subgraph TAO["TAO Loop Synthesis"]
        direction TB
        TA["T-AGENT-ANALYSIS<br/>Categorize: Convergent/Divergent/Gaps"]
        TS["T-AGENT-SYNTHESIS<br/>Define Strategy per Category"]
        TV["T-AGENT-VALIDATION<br/>Quality Check"]

        TA --> TS --> TV
    end

    T1 --> P2_MPA
    T2 --> P4_MPA
    T3 --> P7_MPA

    P2_MPA --> TAO
    P4_MPA --> TAO
    P7_MPA --> TAO

    TAO --> OUT["Synthesized Output"]

    style TRIGGER fill:#9013FE,stroke:#6B0FBE,color:#fff
    style TAO fill:#50E3C2,stroke:#3BB09A,color:#333
```

## CLI Multi-CLI Dispatch Pattern

```mermaid
flowchart TB
    classDef cli fill:#E91E63,stroke:#AD1457,color:#fff,stroke-width:2px
    classDef synthesis fill:#50E3C2,stroke:#3BB09A,color:#333,stroke-width:1px

    subgraph CHECK["Availability Check"]
        CK1{"CLI<br/>Enabled?"}
        CK2{"How Many CLIs<br/>Installed?"}
        CK3["Tri-CLI Mode"]
        CK4["Reduced-CLI Mode<br/>(2 of 3)"]
        CK4b["Single-CLI Degraded"]
        CK5["Skip CLI"]

        CK1 -->|Yes| CK2
        CK1 -->|No| CK5
        CK2 -->|All 3| CK3
        CK2 -->|2 of 3| CK4
        CK2 -->|1 of 3| CK4b
        CK2 -->|None| CK5
    end

    subgraph DISPATCH["Step 1: Parallel Dispatch via Bash"]
        direction LR
        G["Gemini CLI<br/>1M context window<br/>Broad exploration"]
        C["Codex CLI<br/>Code-level precision<br/>Implementation focus"]
        O["OpenCode CLI<br/>UX/Product lens<br/>Accessibility & flows"]
    end

    subgraph SYNTH["Step 2: Synthesis"]
        SY0["Unanimous: VERY HIGH confidence<br/>All 3 CLIs agree"]
        SY1["Majority: HIGH confidence<br/>2 of 3 CLIs agree"]
        SY2["Divergent: FLAG for decision<br/>All CLIs disagree"]
        SY3["Unique: VERIFY first<br/>One CLI only"]
    end

    subgraph CRITIQUE["Step 3: Self-Critique"]
        CR1["Task subagent<br/>CoVe verification"]
        CR2["Context isolation<br/>No coordinator pollution"]
    end

    subgraph REPORT["Step 4: Write Report"]
        RP["analysis/cli-{role}-report.md"]
    end

    subgraph ROLES["5 CLI Roles"]
        direction LR
        R1["deepthinker<br/>Phase 5"]
        R2["planreviewer<br/>Phase 6"]
        R3["securityauditor<br/>Phase 6b"]
        R4["teststrategist<br/>Phase 7"]
        R5["taskauditor<br/>Phase 9"]
    end

    CK3 --> DISPATCH
    CK4 --> DISPATCH
    CK4b --> DISPATCH
    DISPATCH --> SYNTH --> CRITIQUE --> REPORT

    class G,C,O,R1,R2,R3,R4,R5 cli
    class SYNTH synthesis
```

## Dev-Skills Integration

```mermaid
flowchart TB
    classDef devskills fill:#FF9800,stroke:#E65100,color:#fff,stroke-width:1px
    classDef loader fill:#FFF3E0,stroke:#E65100,color:#333,stroke-width:1px

    subgraph DETECT["Phase 1: Detection (Step 1.5c)"]
        D1["Scan spec.md for<br/>technology keywords"]
        D2["Scan project root for<br/>framework markers"]
        D3["Store detected domains<br/>in state.dev_skills"]

        D1 --> D2 --> D3
    end

    subgraph PATTERN["Subagent Loader Pattern"]
        direction TB
        LP1["Dispatch Task subagent"]
        LP2["Load Skill files<br/>5-15K tokens raw"]
        LP3["Extract relevant sections"]
        LP4["Write condensed output<br/>1-3K tokens"]
        LP5["Coordinator reads<br/>small context file only"]

        LP1 --> LP2 --> LP3 --> LP4 --> LP5
    end

    subgraph PHASES["Per-Phase Skill Loading"]
        direction TB
        PH2["Phase 2 (2.2c-a)<br/>accessibility, mobile, figma<br/>Budget: 2500 tokens"]
        PH4["Phase 4 (4.0a)<br/>api-patterns, database, c4,<br/>mermaid, frontend<br/>Budget: 3000 tokens"]
        PH6b["Phase 6b (6b.0a)<br/>clean-code, api-security<br/>Budget: 2000 tokens"]
        PH7["Phase 7 (7.1c)<br/>qa-test-planner, accessibility<br/>Budget: 2000 tokens"]
        PH9["Phase 9 (9.2a)<br/>clean-code<br/>Budget: 800 tokens"]
    end

    subgraph MODES["Mode Availability"]
        M1["Complete"]
        M2["Advanced"]
        M3["Standard"]
        M4["Rapid: SKIP"]
    end

    DETECT --> PHASES
    PHASES --> PATTERN

    class D1,D2,D3,PH2,PH4,PH6b,PH7,PH9 devskills
    class PATTERN loader
```

## Sequential Thinking (ST) Patterns

```mermaid
flowchart TB
    subgraph FORKJOIN["Diagonal Matrix Fork-Join<br/>Phase 4: Architecture"]
        direction TB
        F1["T7a_FRAME<br/>Decision Point"]
        F2["T7b_GROUNDING<br/>branchId: grounding"]
        F3["T7c_IDEALITY<br/>branchId: ideality"]
        F4["T7d_RESILIENCE<br/>branchId: resilience"]
        F5a["T8a_RECONCILE<br/>Tension Map"]
        F5b["T8b_COMPOSE<br/>Merge & Resolve"]

        F1 --> F2 & F3 & F4
        F2 & F3 & F4 --> F5a --> F5b
    end

    subgraph REDTEAM["Red Team Pattern<br/>Phase 7: Security"]
        direction TB
        R1["T-RISK-1<br/>Failure Modes"]
        R2["T-RISK-REDTEAM<br/>branchId: redteam<br/>Attacker Perspective"]
        R3["T-RISK-REDTEAM-SYNTHESIS<br/>Merge Findings"]

        R1 --> R2 --> R3
    end

    subgraph REVISION["Revision Pattern<br/>Reconciliation"]
        direction TB
        V1["T-RISK-2<br/>Original Analysis"]
        V2["ThinkDeep<br/>Contradicts"]
        V3["T-RISK-REVISION<br/>isRevision: true<br/>revisesThought: 2"]

        V1 --> V2 --> V3
    end

    subgraph TASK["Task Decomposition<br/>Phase 9"]
        direction TB
        K1["T-TASK-1: DECOMPOSE<br/>Establish Levels"]
        K2["T-TASK-2: SEQUENCE<br/>Order Tasks"]
        K3["T-TASK-3: VALIDATE<br/>isRevision if needed"]
        K4["T-TASK-4: FINALIZE<br/>Output Deliverable"]

        K1 --> K2 --> K3 --> K4
    end

    style FORKJOIN fill:#4A90D9,stroke:#2E5A8B,color:#fff
    style REDTEAM fill:#D0021B,stroke:#A00216,color:#fff
    style REVISION fill:#F5A623,stroke:#D4880F,color:#fff
    style TASK fill:#7ED321,stroke:#5BA018,color:#fff
```

## Quality Gates and Checkpoints

```mermaid
flowchart TB
    subgraph GATES["Quality Gates (S3)"]
        G1["Gate 1: Research Completeness<br/>After Phase 2"]
        G2["Gate 2: Architecture Quality<br/>After Phase 4"]
        G3["Gate 3: Test Coverage<br/>After Phase 7"]
    end

    subgraph GATE_FLOW["Gate Evaluation Flow"]
        direction LR
        GF1["Launch<br/>phase-gate-judge"]
        GF2{"Score<br/>≥3.5/5.0?"}
        GF3["PASS:<br/>Continue"]
        GF4["FAIL:<br/>Retry (max 2)"]
        GF5["Escalate<br/>to User"]

        GF1 --> GF2
        GF2 -->|"Yes"| GF3
        GF2 -->|"No"| GF4 --> GF5
    end

    subgraph CHECKPOINTS["State Checkpoints"]
        direction LR
        CP1["SETUP"] --> CP2["RESEARCH"]
        CP2 --> CP3["CLARIFICATION"]
        CP3 --> CP4["ARCHITECTURE"]
        CP4 --> CP5["THINKDEEP"]
        CP5 --> CP6["VALIDATION"]
        CP6 --> CP6b["EXPERT_REVIEW"]
        CP6b --> CP7["TEST_STRATEGY"]
        CP7 --> CP8["TEST_COVERAGE"]
        CP8 --> CP8b["ASSET_CONSOLIDATION"]
        CP8b --> CP9["COMPLETION"]
    end

    subgraph PLAN_VAL["Plan Validation Scoring<br/>20 Points"]
        direction TB
        PV1["Problem Understanding: 20%"]
        PV2["Architecture Quality: 25%"]
        PV3["Risk Mitigation: 20%"]
        PV4["Implementation Clarity: 20%"]
        PV5["Feasibility: 15%"]
    end

    subgraph TEST_VAL["Test Coverage Scoring<br/>100%"]
        direction TB
        TV1["AC Coverage: 25%"]
        TV2["Risk Coverage: 25%"]
        TV3["UAT Completeness: 20%"]
        TV4["Test Independence: 15%"]
        TV5["Maintainability: 15%"]
    end

    GATES --> GATE_FLOW
    GATES --> CHECKPOINTS

    style GATES fill:#D0021B,stroke:#A00216,color:#fff
    style CHECKPOINTS fill:#50E3C2,stroke:#3BB09A,color:#333
    style PLAN_VAL fill:#4A90D9,stroke:#2E5A8B,color:#fff
    style TEST_VAL fill:#7ED321,stroke:#5BA018,color:#fff
```

## Artifact Flow

```mermaid
flowchart LR
    subgraph INPUT["Input"]
        I1["specs/constitution.md"]
        I2["FEATURE_DIR/spec.md"]
    end

    subgraph P2_OUT["Phase 2"]
        O2["research.md"]
        O2s["skill-context.md<br/>(conditional)"]
    end

    subgraph P4_OUT["Phase 4"]
        O4A["design.grounding.md"]
        O4B["design.ideality.md"]
        O4C["design.resilience.md"]
        O4D["design.md"]
        O4s["skill-context.md<br/>(conditional)"]
    end

    subgraph P5_OUT["Phase 5"]
        O5["analysis/<br/>thinkdeep-insights.md"]
        O5c["analysis/<br/>cli-deepthinker-report.md<br/>(conditional)"]
    end

    subgraph P6_OUT["Phase 6 + 6b"]
        O6A["plan.md"]
        O6B["analysis/<br/>validation-report.md"]
        O6C["analysis/<br/>expert-review.md"]
        O6c1["analysis/<br/>cli-planreview-report.md<br/>(conditional)"]
        O6c2["analysis/<br/>cli-security-report.md<br/>(conditional)"]
    end

    subgraph P7_OUT["Phase 7"]
        O7A["test-plan.md"]
        O7B["test-cases/unit/"]
        O7C["test-cases/integration/"]
        O7D["test-cases/e2e/"]
        O7E["test-cases/uat/"]
        O7c["analysis/<br/>cli-testreview-report.md<br/>(conditional)"]
    end

    subgraph P8_OUT["Phase 8"]
        O8["analysis/<br/>test-coverage-validation.md"]
    end

    subgraph P8b_OUT["Phase 8b"]
        O8b["asset-manifest.md<br/>(optional)"]
    end

    subgraph P9_OUT["Phase 9"]
        O9A["tasks.md"]
        O9B["analysis/<br/>task-test-traceability.md"]
        O9c["analysis/<br/>cli-taskaudit-report.md<br/>(conditional)"]
    end

    subgraph STATE["State"]
        ST1[".planning-state.local.md"]
        ST2[".planning.lock"]
        ST3[".phase-summaries/*.md"]
    end

    INPUT --> P2_OUT --> P4_OUT --> P5_OUT --> P6_OUT --> P7_OUT --> P8_OUT --> P8b_OUT --> P9_OUT

    style INPUT fill:#9013FE,stroke:#6B0FBE,color:#fff
    style P9_OUT fill:#7ED321,stroke:#5BA018,color:#fff
    style STATE fill:#F5A623,stroke:#D4880F,color:#fff
```

## Orchestrator Dispatch Model

```mermaid
flowchart TB
    classDef inline fill:#4A90D9,stroke:#2E5A8B,color:#fff,stroke-width:2px
    classDef coord fill:#9013FE,stroke:#6B0FBE,color:#fff,stroke-width:2px
    classDef cond fill:#F5A623,stroke:#D4880F,color:#fff,stroke-width:2px

    subgraph ORCH["Orchestrator (SKILL.md)"]
        direction TB
        O1["Read State"]
        O2["Dispatch Phase"]
        O3["Read Summary"]
        O4{"Status?"}
        O5["Update State"]
        O6["Next Phase"]
        O7["Relay User Q"]
        O8["Crash Recovery"]

        O1 --> O2 --> O3 --> O4
        O4 -->|completed| O5 --> O6
        O4 -->|needs-user-input| O7 --> O2
        O4 -->|failed/missing| O8
    end

    subgraph DELEG["Delegation Model"]
        direction LR
        D1["Phase 1<br/>INLINE"]
        D3["Phase 3<br/>CONDITIONAL<br/>Inline: Std/Rapid<br/>Coord: Comp/Adv"]
        D2["Phases 2,4-9<br/>COORDINATOR<br/>Task subagent"]
    end

    subgraph SUMMARY["Summary Contract"]
        direction TB
        SF1["phase: string"]
        SF2["status: completed |<br/>needs-user-input |<br/>failed | skipped"]
        SF3["checkpoint: string"]
        SF4["artifacts_written: array"]
        SF5["summary: string"]
    end

    class D1 inline
    class D2 coord
    class D3 cond
```

---

## 9. Deep Reasoning Escalation Flow

Shows when and how the orchestrator offers deep reasoning escalation to external models (GPT-5 Pro, Google Deep Think). All 4 escalation types are gated by feature flags and mode checks.

```mermaid
flowchart TD
    subgraph TRIGGERS["Escalation Triggers"]
        T1["Gate RED after 2 retries<br/>(circular_failure)"]
        T2["Phase 6 RED → Phase 4 loop<br/>(architecture_wall)"]
        T3["2+ CRITICAL security findings<br/>(security_deep_dive)"]
        T4["Algorithm keywords in spec<br/>(abstract_algorithm_detection)"]
    end

    T1 --> CHECK
    T2 --> CHECK
    T3 --> CHECK
    T4 -->|"Detection only<br/>in Phase 1"| DETECT["Set state flag:<br/>algorithm_detected = true"]
    DETECT -->|"Later gate failure"| CHECK

    CHECK{"Feature flag enabled?<br/>Mode in (Complete, Advanced)?<br/>Escalation limits OK?"}
    CHECK -->|"No"| FALLBACK["Existing behavior:<br/>retry / skip / abort"]
    CHECK -->|"Yes"| ASSEMBLE

    subgraph DISPATCH["Deep Reasoning Dispatch (Steps A-F)"]
        direction TB
        ASSEMBLE["Step A: Context Assembly<br/>Read summaries + artifacts"]
        GENERATE["Step B: CTCO Prompt Generation<br/>Load template, fill variables"]
        PRESENT["Step C: User Presentation<br/>via AskUserQuestion"]
        ASSEMBLE --> GENERATE --> PRESENT

        PRESENT -->|"User accepts"| SUBMIT["User submits to<br/>GPT-5 Pro / Deep Think<br/>(3-15 min wait)"]
        PRESENT -->|"User skips"| FALLBACK2["Continue without<br/>escalation"]

        SUBMIT --> INGEST["Step D: Response Ingestion<br/>Write to analysis/ directory"]
        INGEST --> STATE["Step E: State Update<br/>Record in escalations[]"]
        STATE --> REDISPATCH["Step F: Re-dispatch<br/>Coordinator with response"]
    end

    REDISPATCH --> CONTINUE["Continue workflow"]
    FALLBACK2 --> CONTINUE
    FALLBACK --> CONTINUE

    subgraph RESUME["Resume Handling"]
        R1["On workflow resume:<br/>check pending_escalation"]
        R1 -->|"Found"| R2["Re-present saved prompt"]
        R2 -->|"User provides response"| R3["Ingest → State → Re-dispatch"]
        R2 -->|"User skips"| R4["Clear pending, continue"]
    end

    classDef trigger fill:#ff6b6b,stroke:#333,color:#fff
    classDef check fill:#ffa94d,stroke:#333,color:#fff
    classDef dispatch fill:#845ef7,stroke:#333,color:#fff
    classDef fallback fill:#868e96,stroke:#333,color:#fff
    classDef success fill:#51cf66,stroke:#333,color:#fff
    classDef resume fill:#339af0,stroke:#333,color:#fff

    class T1,T2,T3,T4 trigger
    class CHECK check
    class ASSEMBLE,GENERATE,PRESENT,SUBMIT,INGEST,STATE,REDISPATCH dispatch
    class FALLBACK,FALLBACK2 fallback
    class CONTINUE success
    class DETECT,R1,R2,R3,R4 resume
```

---

## Legend

| Color | Meaning |
|-------|---------|
| Blue | Core workflow phases and steps |
| Purple | MCP-dependent features (ST, Research) |
| Green | Outputs and success paths |
| Orange | Decision points, warnings, and dev-skills integration |
| Red | Quality gates, failure paths, and escalation triggers |
| Teal | Sub-phases and synthesis |
| Pink | CLI Multi-CLI integration |
| Violet | Deep reasoning escalation dispatch |

## Usage

These diagrams can be rendered in:
- GitHub/GitLab markdown preview
- VS Code with Mermaid extension
- Mermaid Live Editor (https://mermaid.live)
- Any documentation tool supporting Mermaid

---

*Updated: 2026-02-12 | Skill version: 3.0.0*
