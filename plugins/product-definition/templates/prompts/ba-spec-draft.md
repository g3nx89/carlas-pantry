# Business Analyst: Specification Draft

## Prompt Context

{RESUME_CONTEXT}

## Task

Perform business analysis and requirements gathering for the feature.
Write specification to {SPEC_FILE} using the template structure.

## Figma Context (if available)

{FIGMA_CONTEXT}

IF figma-context provided:
  - Correlate designs with requirements
  - Add @FigmaRef(nodeId="{nodeId}", screen="{screen_name}") annotations
  - Identify screens that map to each user story

## User Input

{USER_INPUT}

## Variables

| Variable | Value |
|----------|-------|
| FEATURE_NAME | {value} |
| FEATURE_ID | {value} |
| FEATURE_DIR | {value} |
| SPEC_FILE | {value} |
| STATE_FILE | {value} |
| PLATFORM_TYPE | {value} |

## Sequential Thinking Templates

Use templates 1-6 from @$CLAUDE_PLUGIN_ROOT/agents/ba-references/sequential-thinking-templates.md:
- Template 1: Problem Domain Setup
- Template 2: User Story Extraction
- Template 3: Acceptance Criteria Definition
- Template 4: Edge Case Identification
- Template 5: Non-Functional Requirements
- Template 6: Synthesis

## Technical Language Prohibition

**CRITICAL: The specification MUST be technology-agnostic.**

The spec describes WHAT the system does and WHY, never HOW it is implemented.

**FORBIDDEN** (never use in specifications):
- **Framework names**: Room, Hilt, Compose, ViewModel, SwiftUI, UIKit, CoreData, React, Redux, Next.js, Express, Django, Rails, Spring Boot, Angular, Vue, Electron, WPF, etc.
- **Architecture patterns**: MVVM, MVI, Clean Architecture, Repository pattern, microservices, monolith, event-driven, CQRS
- **Implementation details**: `data class`, `struct {}`, `interface {}`, `/api/v1/...`, `SELECT * FROM`, REST endpoints, GraphQL schemas, WebSocket, gRPC
- **Concurrency primitives**: Coroutines, Flow, RxJava, async/await, goroutines, threads, workers, queues
- **Storage specifics**: SQLite, PostgreSQL, MongoDB, Redis, S3, Firebase, Supabase

**REQUIRED replacements:**
| Instead of... | Write... |
|---------------|----------|
| "Database with ORM/DAO pattern" | "Local persistent storage with offline access" |
| "REST API endpoint /api/v1/users" | "The system retrieves user information from the backend" |
| "State management with reactive streams" | "The screen displays current state and responds to changes" |
| "Dependency injection framework" | (omit — DI is an implementation choice, not a requirement) |
| "Data model with typed fields" | "An item has a name, description, category, and creation date" |

The full list of forbidden keywords is in `spec_quality.technical_keywords_forbidden` in config.

## Output Requirements

1. Copy spec template:
   ```bash
   cp specs/templates/spec-template.md {SPEC_FILE}
   ```

2. Populate ALL sections:
   - Executive Summary (from Template 1)
   - User Stories with Gherkin format (from Template 2-3)
   - Acceptance Criteria (from Template 3)
   - Edge Cases (from Template 4)
   - Non-Functional Requirements (from Template 5)
   - Out of Scope (explicit boundaries)

3. Quality requirements:
   - NO placeholder text remaining
   - Every user story has at least 2 acceptance criteria
   - Every AC is testable (Given/When/Then format preferred)
   - Mark unclear items with `[NEEDS CLARIFICATION: {reason}]`

4. **⚠️ MANDATORY: Story Splitting (Phase 4.5)**
   - Load @$CLAUDE_PLUGIN_ROOT/agents/ba-references/story-splitting.md
   - Use Sequential Thinking templates T22-T23
   - **Evaluate EVERY story** for atomicity violations:
     - Compound `When` (multiple actions) → SPLIT
     - Multiple `Then` (multiple outcomes) → SPLIT
     - Multiple user roles conflated → SPLIT
     - Effort > 1 sprint → SPLIT
   - Apply the **8 splitting criteria** in order (stop at first match)
   - **REJECT anti-patterns**: layer-based, person-based, technical-component splits
   - **REQUIRE**: Each split story delivers independent testable user value
   - **Track metrics**: `stories_before_split`, `stories_after_split`, `stories_split_count`

5. Apply Self-Critique:
   - Load @$CLAUDE_PLUGIN_ROOT/agents/ba-references/self-critique-rubric.md
   - Score >= 3.5/5 required before completion
