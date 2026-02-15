# dev-skills

A collection of 22 skills supporting software design, development, and quality assurance activities.

**Version:** 1.1.0 (see `.claude-plugin/plugin.json`)

## Installation

```bash
# From repository root
claude plugins add ./plugins/dev-skills
claude plugins enable dev-skills
```

## Skill Index

Use this index to select the appropriate skill based on your task. Skills are optimized for autonomous agent selection during development and planning workflows.

### Quick Selection Table

| Domain | Skill | Primary Triggers |
|--------|-------|------------------|
| **Mobile** | `mobile-design` | mobile app, React Native, Flutter, iOS, Android, touch UI |
| **Mobile** | `android-expert` | Android navigation, permissions, lifecycle, Manifest |
| **Mobile** | `android-cli-testing` | ADB, emulator CLI, logcat, dumpsys, Perfetto, CI testing |
| **Mobile** | `compose-expert` | Composable, Compose UI, remember, recomposition |
| **Kotlin** | `kotlin-expert` | StateFlow, sealed class, @Immutable, DSL builder |
| **Kotlin** | `kotlin-coroutines` | callbackFlow, supervisorScope, Flow operators |
| **Build** | `gradle-expert` | Gradle error, dependency conflict, version catalog |
| **Web** | `frontend-design` | website, landing page, web UI, React component |
| **Web** | `scroll-experience` | scroll animation, parallax, scroll-triggered |
| **Web** | `accessibility-auditor` | accessibility audit, WCAG, ARIA, a11y |
| **Web** | `web-design-guidelines` | UI review, design audit, best practices check |
| **Data** | `database-design` | database selection, ORM, query optimization |
| **Data** | `database-schema-designer` | schema design, tables, normalization, migrations |
| **API** | `api-patterns` | API design, REST vs GraphQL, tRPC, versioning |
| **Arch** | `c4-architecture` | C4 diagram, architecture diagram, system context |
| **Arch** | `mermaid-diagrams` | diagram, flowchart, sequence, ERD, class diagram |
| **Quality** | `clean-code` | code review, refactor, simplify, naming |
| **Quality** | `qa-test-planner` | test plan, test cases, regression suite, bug report |
| **Figma** | `figma-implement-design` | implement design, Figma to code, build from Figma |
| **Figma** | `figma-code-connect-components` | code connect, map component, link design |
| **Figma** | `figma-create-design-system-rules` | design system rules, Figma guidelines |
| **Figma** | `figma-design-toolkit` | export assets, audit design, extract tokens |

---

## Skills by Domain

### Mobile Development

#### `mobile-design`
**When to use:** Building mobile apps, cross-platform development, mobile-first design.

**Triggers:** "build a mobile app", "create React Native app", "Flutter app", "design for iOS", "design for Android", "mobile performance", "touch interactions"

**Covers:** Platform conventions, touch targets, thumb zones, performance optimization (FlatList, Compose), offline handling, deep linking, mobile security.

---

#### `android-expert`
**When to use:** Android-specific platform features in KMP or native projects.

**Triggers:** "Android navigation", "Compose Navigation", "runtime permissions", "camera permission", "AndroidManifest", "edge-to-edge", "bottom navigation", "ViewModel lifecycle"

**Covers:** Type-safe navigation, Accompanist permissions, Material3 theming, edge-to-edge UI, lifecycle effects, platform APIs.

**Delegates to:** `compose-expert` (shared UI), `kotlin-expert` (language patterns), `gradle-expert` (build issues)

---

#### `android-cli-testing`
**When to use:** Android testing and debugging from the CLI without Android Studio.

**Triggers:** "run Android tests from CLI", "debug with ADB", "set up emulator for CI", "launch headless emulator", "capture logcat", "profile performance", "dumpsys", "Perfetto traces", "screenrecord", "port forwarding", "USB debugging"

**Covers:** ADB commands (logcat, dumpsys, app management, input simulation), SDK Emulator CLI (sdkmanager, avdmanager, emulator flags), performance profiling (Perfetto, gfxinfo, method tracing), CI/CD pipeline patterns, physical device debugging, OEM considerations.

**Delegates to:** `genymotion-expert` (Genymotion emulation), `android-expert` (navigation, permissions), `gradle-expert` (build issues)

---

#### `compose-expert`
**When to use:** Jetpack Compose or Compose Multiplatform UI development.

**Triggers:** "create Composable", "share UI components", "remember", "derivedStateOf", "recomposition", "@Immutable annotation", "Material3 theming", "ImageVector icons"

**Covers:** Shared composable patterns, state management (remember, produceState), recomposition optimization, Material3 theming, custom ImageVector icons.

**Delegates to:** `android-expert` (navigation), `kotlin-expert` (StateFlow, sealed classes)

---

### Kotlin & JVM

#### `kotlin-expert`
**When to use:** Advanced Kotlin patterns and idioms.

**Triggers:** "StateFlow", "SharedFlow", "sealed class", "sealed interface", "@Immutable", "DSL builder", "inline function", "reified"

**Covers:** Flow state management, sealed hierarchies, immutability patterns, DSL builders, inline/reified functions, value classes.

**Delegates to:** `kotlin-coroutines` (async patterns), `compose-expert` (Compose-specific)

---

#### `kotlin-coroutines`
**When to use:** Complex async operations, Flow operators, structured concurrency.

**Triggers:** "supervisorScope", "callbackFlow", "combine Flows", "flatMapLatest", "backpressure", "runTest", "CoroutineExceptionHandler", "shareIn", "stateIn"

**Covers:** Structured concurrency, callbackFlow patterns, Flow operators (merge, combine, flatMapLatest), backpressure handling, coroutine testing.

**Delegates to:** `kotlin-expert` (basic StateFlow/SharedFlow)

---

#### `gradle-expert`
**When to use:** Build system issues, dependency management, KMP configuration.

**Triggers:** "Gradle build error", "dependency conflict", "version catalog", "libs.versions.toml", "package desktop app", "build performance", "Proguard rules", "KMP build"

**Covers:** Version catalog patterns, multi-module builds, dependency resolution, desktop packaging, build optimization, common error troubleshooting.

---

### Web Frontend

#### `frontend-design`
**When to use:** Building distinctive, production-grade web interfaces.

**Triggers:** "build a website", "landing page", "dashboard", "React component", "style web UI", "beautify page", "web application"

**Covers:** Aesthetic direction selection, typography, color systems, motion/animation, spatial composition, anti-patterns to avoid.

**Delegates to:** `accessibility-auditor` (a11y), `mobile-design` (mobile-first), `scroll-experience` (scroll animations)

---

#### `scroll-experience`
**When to use:** Immersive scroll-driven experiences, parallax effects.

**Triggers:** "scroll animations", "parallax effects", "scroll story", "interactive narrative", "cinematic website", "scroll-triggered reveals"

**Covers:** GSAP ScrollTrigger, Framer Motion, CSS scroll-timeline, parallax layers, sticky sections, performance fixes, accessibility.

---

#### `accessibility-auditor`
**When to use:** Ensuring WCAG compliance and inclusive design.

**Triggers:** "audit accessibility", "WCAG compliance", "fix accessibility", "ARIA attributes", "screen reader", "make accessible", "ADA compliance"

**Covers:** POUR principles, semantic HTML, keyboard navigation, color contrast, focus indicators, ARIA patterns, testing checklists.

---

#### `web-design-guidelines`
**When to use:** Auditing files against web interface best practices.

**Triggers:** "review my UI", "check accessibility", "audit design", "review UX", "best practices check", "validate frontend"

**Covers:** Accessibility, performance, responsiveness, code quality, usability, security checks against Vercel's Web Interface Guidelines.

---

### Database & API

#### `database-design`
**When to use:** Choosing databases, ORMs, and optimization strategies.

**Triggers:** "design a database", "choose database", "PostgreSQL vs SQLite", "select ORM", "Drizzle vs Prisma", "plan indexes", "optimize queries"

**Covers:** Database selection (PostgreSQL, Neon, Turso, SQLite), ORM choices (Drizzle, Prisma, Kysely), indexing strategies, query optimization.

---

#### `database-schema-designer`
**When to use:** Designing production-ready database schemas.

**Triggers:** "design schema", "create tables", "model data", "normalize database", "plan migrations", "foreign keys", "indexing strategy"

**Covers:** Normalization (1NF-3NF), data types, constraints, relationship patterns, SQL/NoSQL design, zero-downtime migrations.

---

#### `api-patterns`
**When to use:** Designing APIs and choosing architectural styles.

**Triggers:** "design API", "REST vs GraphQL", "implement tRPC", "API versioning", "structure responses", "pagination", "rate limiting"

**Covers:** API style selection, REST resource design, GraphQL schemas, tRPC patterns, authentication, rate limiting, documentation.

**Delegates to:** `database-design` (data structure), `database-schema-designer` (schema)

---

### Architecture & Documentation

#### `c4-architecture`
**When to use:** Creating software architecture documentation with C4 model.

**Triggers:** "architecture diagram", "C4 diagram", "system context", "container diagram", "component diagram", "deployment diagram"

**Covers:** All C4 levels (Context, Container, Component, Deployment, Dynamic), Mermaid C4 syntax, microservices patterns, audience-appropriate detail.

---

#### `mermaid-diagrams`
**When to use:** Creating any type of software diagram.

**Triggers:** "create diagram", "visualize", "model architecture", "map flow", "sequence diagram", "flowchart", "ERD", "class diagram"

**Covers:** Class diagrams, sequence diagrams, flowcharts, ERDs, state diagrams, git graphs, gantt charts, theming.

**Delegates to:** `c4-architecture` (C4 model), `database-schema-designer` (schema design)

---

### Code Quality & QA

#### `clean-code`
**When to use:** Improving code quality, refactoring, establishing guidelines.

**Triggers:** "review code quality", "refactor code", "simplify function", "improve naming", "reduce complexity", "guard clauses", "clean code principles"

**Covers:** SOLID principles, naming rules, function size, guard clauses, anti-patterns, verification checklists.

---

#### `qa-test-planner`
**When to use:** Creating test documentation and quality assurance artifacts.

**Triggers:** "create test plan", "generate test cases", "regression suite", "smoke tests", "validate against Figma", "bug report", "QA documentation"

**Covers:** Test plans, manual test cases, regression suites, bug reports, Figma validation, priority/severity classifications.

---

### Figma Integration

#### `figma-implement-design`
**When to use:** Translating Figma designs to production code.

**Triggers:** "implement design", "build from Figma", "generate code from design", "Figma to code", Figma URLs

**Requires:** Figma MCP server (`figma` or `figma-desktop`)

**Covers:** Design context fetching, variable extraction, screenshot validation, asset downloading, 1:1 visual fidelity.

---

#### `figma-code-connect-components`
**When to use:** Linking Figma components to code implementations.

**Triggers:** "connect Figma to code", "code connect", "map component to code", "link design to code"

**Requires:** Figma MCP server, components published to team library

**Covers:** Component mapping, Code Connect API, metadata extraction, codebase scanning for matches.

---

#### `figma-create-design-system-rules`
**When to use:** Establishing project-wide Figma-to-code conventions.

**Triggers:** "create design system rules", "generate Figma rules", "set up design rules", "configure Figma integration"

**Requires:** Figma MCP server

**Covers:** CLAUDE.md rule generation, token extraction, component organization analysis, styling conventions.

---

#### `figma-design-toolkit`
**When to use:** Bulk operations via Figma REST API.

**Triggers:** "export Figma assets", "audit design system", "extract design tokens", "generate CSS variables", "analyze Figma file"

**Requires:** Figma access token (not MCP)

**Covers:** Batch export (PNG, SVG, JPG, PDF), design token extraction (CSS, SCSS, JS), accessibility auditing, client packages.

---

## Skill Selection Algorithm

For autonomous agents selecting skills:

```
1. Parse user intent for domain keywords
2. Match against skill triggers (exact > partial)
3. If multiple matches, apply specificity ranking:
   a. Platform-specific > Cross-platform
      (android-expert > mobile-design for Android tasks)
   b. Framework-specific > Domain-general
      (compose-expert > frontend-design for Compose UI)
   c. Schema-level > Database-level
      (database-schema-designer > database-design for table design)
   d. Check delegation hints in skill descriptions
4. If Figma URL present → figma-implement-design
5. If MCP dependency required → verify server configured
```

### Specificity Ranking

When triggers overlap, prefer the more specialized skill:

| General Skill | Specific Skill | Choose Specific When |
|---------------|----------------|----------------------|
| `mobile-design` | `android-expert` | Android platform features |
| `mobile-design` | `android-cli-testing` | CLI testing/debugging |
| `mobile-design` | `compose-expert` | Compose UI patterns |
| `frontend-design` | `scroll-experience` | Scroll/parallax effects |
| `frontend-design` | `accessibility-auditor` | WCAG/a11y focus |
| `database-design` | `database-schema-designer` | Schema/table design |
| `mermaid-diagrams` | `c4-architecture` | C4 model specifically |
| `kotlin-expert` | `kotlin-coroutines` | Async/Flow operators |

### Common Routing Patterns

| User Request | Primary Skill | May Delegate To |
|--------------|---------------|-----------------|
| "Build Android app with Compose" | `android-expert` | `compose-expert`, `kotlin-expert` |
| "Debug Android app with ADB" | `android-cli-testing` | `android-expert` |
| "Set up emulator for CI" | `android-cli-testing` | `genymotion-expert` |
| "Create a React dashboard" | `frontend-design` | `accessibility-auditor` |
| "Design database for e-commerce" | `database-schema-designer` | `database-design` |
| "Implement this Figma design" | `figma-implement-design` | `figma-code-connect-components` |
| "Add parallax to landing page" | `scroll-experience` | `frontend-design` |
| "Review code for quality" | `clean-code` | - |
| "Create architecture diagram" | `c4-architecture` | `mermaid-diagrams` |

---

## Contributing

See `CLAUDE.md` for skill authoring standards and development guidelines, including:
- Hub-Spoke Model for skill structure
- Required sections (When to Use, When NOT to Use, Reference Map)
- Cross-reference validation between skills
- Generalization rules (no project-specific content)

## License

MIT
