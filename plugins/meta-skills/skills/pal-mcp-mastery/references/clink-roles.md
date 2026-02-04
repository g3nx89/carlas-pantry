# Custom Clink Roles

> **Compatibility**: Verified against PAL MCP v1.x (January 2026)

## Overview

Clink roles define specialized behaviors for CLI subagents. Each role combines:
- **System prompt** - Instructions defining agent behavior
- **Role args** - Additional CLI flags for the role
- **CLI capabilities** - What the underlying CLI can do

## Role Categories

| Category | Purpose | Best CLI |
|----------|---------|----------|
| **Analysis** | Deep investigation, debugging | Gemini (1M context) |
| **Review** | Plan/code validation, red teaming | Codex (code-focused) |
| **Testing** | QA, UAT, mobile testing | Gemini + mobile-mcp |
| **Research** | Documentation, web search | Gemini (web access) |
| **Planning** | Architecture, decomposition | Any |

## Pre-Built Roles

### Built-in Roles (Default PAL)

| Role | Available On | Purpose |
|------|--------------|---------|
| `default` | all | General-purpose assistance |
| `planner` | all | Project planning and decomposition |
| `codereviewer` | all | Code quality and security analysis |

### Advanced Roles (Custom)

| Role | Best CLI | Purpose |
|------|----------|---------|
| `deepthinker` | gemini, codex | Systematic deep analysis with ST |
| `planreviewer` | gemini, codex | Red/Blue team plan validation |
| `uat_mobile` | gemini | Mobile UAT testing with mobile-mcp |
| `researcher` | gemini | Documentation research with web search |
| `securityauditor` | codex | OWASP-based security vulnerability assessment |

## Role: deepthinker

**Purpose**: Systematic deep analysis using Sequential Thinking (ST) for complex problems requiring hypothesis testing, evidence gathering, and iterative refinement.

**Best for**:
- Root cause analysis
- Architecture decisions
- Complex debugging
- Multi-hypothesis investigation

**Key features**:
- Mandatory ST integration with branching
- Hypothesis → Evidence → Revision cycle
- Fork-join for comparing alternatives
- Quality enforcement (no rubber-stamping)

**Usage**:
```
clink(
  prompt="Analyze why user sessions expire unexpectedly",
  cli_name="gemini",
  role="deepthinker",
  absolute_file_paths=["/src/auth/", "/src/session/"]
)
```

**ST Protocol summary**:
1. **Initialization** (1-2 thoughts): Hypotheses, tech stack, key files
2. **Investigation** (3-N): Evidence gathering with file:line citations
3. **Revision**: Correct assumptions when evidence contradicts
4. **Branching**: Fork-join for comparing alternatives
5. **Conclusion**: Summary with confidence and remaining uncertainties

**Chain rules**:
- Every 5 thoughts: Re-evaluate totalThoughts
- Checkpoint at 15: Summary of findings
- Circuit breaker at 20: Conclude or request guidance

See: `$SKILL_PATH/examples/clink-roles/deepthinker.txt`

---

## Role: planreviewer

**Purpose**: Critical plan review using Red Team/Blue Team methodology. Challenges assumptions, finds hidden risks, and proposes mitigations.

**Best for**:
- Implementation plan validation
- Migration plan review
- Architecture decision records
- Risk assessment

**Key features**:
- Red Team adversarial analysis
- Blue Team mitigation proposals
- Alternative approach exploration
- Structured verdict output

**Usage**:
```
clink(
  prompt="Review the microservices migration plan",
  cli_name="gemini",
  role="planreviewer",
  absolute_file_paths=["/docs/migration-plan.md", "/docs/architecture.md"]
)
```

**Review Protocol**:
1. **Comprehension**: Understand scope, objectives, timeline
2. **Strengths**: Identify what the plan does well
3. **Red Team**: Attack the plan adversarially
4. **Blue Team**: Propose mitigations
5. **Alternatives**: Consider different approaches
6. **Synthesis**: Integrate findings, deliver verdict

**Output format**:
- Plan Summary
- Strengths (with citations)
- Critical Challenges (severity table)
- Missing Elements
- Recommendations (prioritized)
- Overall Assessment: ready/needs revision/requires rethinking

See: `$SKILL_PATH/examples/clink-roles/planreviewer.txt`

---

## Role: uat_mobile

**Purpose**: Execute structured User Acceptance Testing on mobile devices/emulators using mobile-mcp tools.

**Best for**:
- Mobile app UAT
- Cross-device testing
- Visual verification
- Acceptance criteria validation

**Key features**:
- SAV Loop (State-Action-Verify)
- Screenshot evidence capture
- System dialog handling
- Structured test reporting

**Required**: mobile-mcp tools must be available in Gemini CLI

**Usage**:
```
clink(
  prompt="Execute UAT for login flow: verify email login, biometric bypass, error handling",
  cli_name="gemini",
  role="uat_mobile"
)
```

**Test Protocol**:
1. **Setup**: List devices, select target, launch app
2. **Test Steps**: SAV loop for each criterion
3. **Cleanup**: Terminate app, compile report

**Output format**:
```
[TEST STEP #] <Description>
├── Action: <What was done>
├── Expected: <What should happen>
├── Actual: <What happened>
├── Evidence: <Screenshot ref>
└── Result: PASS | FAIL | BLOCKED
```

See: `$SKILL_PATH/examples/clink-roles/uat_mobile.txt`

---

## Role: researcher

**Purpose**: Objective documentation retrieval using web search. Finds current information without implementation bias.

**Best for**:
- API documentation lookup
- Best practices research
- Technology comparison
- Version-specific information

**Key features**:
- Web search enabled
- Source citation required
- Neutral, fact-based output
- No implementation mixing

**Usage**:
```
clink(
  prompt="Research React 19 Server Components streaming patterns",
  cli_name="gemini",
  role="researcher"
)
```

**Simple prompt template**:
```
You are a research assistant focused on finding and summarizing documentation.

Rules:
- Use web search to find current, accurate information
- Always cite sources with URLs
- Present facts neutrally without implementation recommendations
- Distinguish between official docs, community practices, and opinions
- Note version numbers and dates when relevant

Output format:
1. Key Findings (bullet points)
2. Sources (numbered list with URLs)
3. Caveats (version limitations, conflicting info)
```

---

## Role: securityauditor

**Purpose**: Systematic security vulnerability assessment using OWASP Top 10 methodology. Identifies vulnerabilities, assesses exploitability, and provides prioritized remediation.

**Best for**:
- Security code review
- Vulnerability assessment
- Pre-deployment security audit
- OWASP compliance checks

**Key features**:
- OWASP Top 10 checklist integration
- Severity rating (Critical/High/Medium/Low)
- Exploitability assessment
- Prioritized remediation recommendations

**Usage**:
```
clink(
  prompt="Perform security audit of authentication module",
  cli_name="codex",
  role="securityauditor",
  absolute_file_paths=["/src/auth/", "/src/middleware/"]
)
```

**Audit Protocol**:
1. **Reconnaissance**: Map attack surface, entry points, data flows
2. **Vulnerability Scan**: Check each OWASP Top 10 category
3. **Deep Dive**: Analyze critical findings with exploit scenarios
4. **Remediation**: Propose fixes with priority

**OWASP Categories Checked**:
- Broken Access Control
- Cryptographic Failures
- Injection (SQL, NoSQL, command)
- Insecure Design
- Security Misconfiguration
- Vulnerable Components
- Authentication Failures
- Data Integrity Failures
- Logging Failures
- SSRF

**Output format**:
- Executive Summary
- Attack Surface mapping
- Findings table (Critical/High/Medium/Low with location and evidence)
- Remediation Priority list
- Recommendations (immediate, short-term, long-term)

See: `$SKILL_PATH/examples/clink-roles/securityauditor.txt`

---

## Creating Custom Roles

**Prefer project-level configuration** over user-level (`~/.pal/`). This ensures:
- Settings travel with the repository
- Team members share the same roles
- No hidden user-specific behavior

> **Full setup guide**: See `configuration.md` for complete project setup templates including `.env` and `conf/cli_clients/` structure.

### Quick Setup Summary

1. Create `PROJECT_ROOT/conf/cli_clients/`
2. Add `{cli_name}.json` with role definitions
3. Add `{cli_name}_{role_name}.txt` prompt files
4. Set `CLI_CLIENTS_CONFIG_PATH=./conf/cli_clients/` in `.env`

### Prompt File Structure

Create `PROJECT_ROOT/conf/cli_clients/{cli_name}_{role_name}.txt`:

```
You are a [specialized agent description].

## Primary Mission
[What this agent does]

## Available Tools
[What tools/capabilities the agent has access to]

## Protocol
[Step-by-step workflow]

## Output Format
[Required output structure]

## Quality Rules
[Constraints and requirements]
```

### Step 5: Test the Role

```
clink(prompt="Test task", cli_name="gemini", role="my_custom_role")
```

### Alternative: User-Level Override (~/.pal/)

Use only when project-level is not possible (personal roles, testing):

```bash
# ~/.pal/cli_clients/gemini.json - user-level override
# ~/.pal/cli_clients/gemini_my_role.txt - user-level prompt
```

**Limitations of ~/.pal/**:
- Only works for clink CLI clients (not model catalogs, env vars)
- Settings don't travel with repository
- Can cause "works on my machine" issues

## Best Practices for Role Design

### 1. Leverage Sequential Thinking

For complex roles, integrate the `sequentialthinking` MCP tool:

```
## Sequential Thinking Integration

You possess the `sequentialthinking` MCP tool. Use it for tasks requiring >3 steps.

Required ST parameters:
- thought: Your reasoning (MUST contain new insight)
- thoughtNumber: Position (starts at 1)
- totalThoughts: Estimated total (adjustable)
- nextThoughtNeeded: Continue? (false = done)

Optional:
- isRevision + revisesThought: Correct earlier conclusion
- branchFromThought + branchId: Explore alternative
- needsMoreThoughts: Extend estimate
```

### 2. Enforce Output Quality

Prevent rubber-stamping with explicit rules:

```
## Quality Requirements

Every thought MUST contain at least ONE of:
- A new hypothesis or data point with evidence
- A decision or conclusion with rationale
- A revision of previous thinking with justification
- A specific finding with file:line citation

FORBIDDEN: "Analyzing...", "Thinking...", "Continuing..."
```

### 3. Define Clear Exit Conditions

```
## Chain Management Rules

- Rule of 5: Re-evaluate every 5 thoughts
- Checkpoint at 15: Summarize if chain exceeds 15
- Circuit Breaker at 20: Conclude or ask for guidance
- Explicit Stop: Final thought MUST set nextThoughtNeeded: false
```

### 4. Structured Output

Always define expected output format:

```
## Output Format

After completing analysis, present findings as:

## Context Analysis
[Tech stack, constraints, observations]

## Key Findings
[Numbered list with citations]

## Recommendations
[Prioritized actions]

## Confidence Assessment
- Level: [exploring/low/medium/high/certain]
- Uncertainties: [what would increase confidence]
```

## CLI Capabilities Quick Reference

> **Full CLI options**: See `tool-clink.md` for complete parameter documentation.

| CLI | Best For | Key Advantage |
|-----|----------|---------------|
| `gemini` | Web search, research, large files | 1M token context |
| `codex` | Code review, security audit | Code-specialized |
| `claude` | General assistance | Familiar codebase context |

## Troubleshooting

### Role Not Found

1. Check JSON syntax in `conf/cli_clients/{cli}.json` (project) or `~/.pal/cli_clients/` (user)
2. Verify `CLI_CLIENTS_CONFIG_PATH` points to correct directory in `.env`
3. Verify prompt file exists at resolved path (relative to JSON directory)
4. Role name must match exactly (case-sensitive)

### Prompt Not Loading

Path resolution order:
1. Relative to JSON directory (`~/.pal/cli_clients/`)
2. Relative to PROJECT_ROOT

### Sequential Thinking Not Working

Verify the CLI has access to the `sequentialthinking` MCP tool. Check MCP server configuration.

## See Also

- **`configuration.md`** - Full configuration reference
- **`tool-clink.md`** - Clink tool parameters and usage
- **`examples/clink-roles/`** - Complete prompt templates
