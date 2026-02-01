# Integration Patterns with Other MCP Servers

## Orchestration Principle

Sequential Thinking acts as the **"Operating System" scheduler**—it decides which other MCP tool to call. It does NOT replace fetch or filesystem; it **wraps** them with deliberate reasoning.

**Pattern:** `Thought → Tool Call → Thought (Analysis) → Tool Call`

**Critical mistake to avoid:** Doing all thinking first, then all actions. This blinds the agent to results of early actions.

## The TAO Loop (Thought-Action-Observation)

The only robust pattern for tool integration:

```
┌─────────────────────────────────────────────┐
│  Thought 1: Plan what information I need    │
└────────────────────┬────────────────────────┘
                     ▼
         ┌───────────────────────┐
         │  Action: tool.call()  │
         └───────────┬───────────┘
                     ▼
┌─────────────────────────────────────────────┐
│  Thought 2: Analyze the result I received   │
└────────────────────┬────────────────────────┘
                     ▼
         ┌───────────────────────┐
         │  Action: next tool    │
         └───────────┬───────────┘
                     ▼
┌─────────────────────────────────────────────┐
│  Thought 3: Synthesize and decide next step │
└─────────────────────────────────────────────┘
```

## Power Stack Configuration

A proven combination for development workflows:

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"],
      "env": {"MCP_TIMEOUT": "15000"}
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/project"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {"GITHUB_TOKEN": "your-token"}
    }
  }
}
```

## Multi-MCP Workflow Pattern

**PR Analysis Example:**

1. **Fetch** — GitHub MCP retrieves PR diff and comments
2. **Think** — Sequential Thinking analyzes changes systematically:
   - Thought 1: Categorize changes by risk level
   - Thought 2: Identify architectural implications
   - Thought 3: Check for test coverage
   - Thought 4: Formulate review feedback
3. **Act** — Post structured review comments via GitHub MCP

## Interleaving Tool Calls Within Thought Chains

**Pattern:** Use thoughts to plan, execute tool calls, then use more thoughts to analyze results.

```
Thought 1: Planning what information I need
→ Tool call: filesystem.read() to get current code
Thought 2: Analyzing the code structure I retrieved
→ Tool call: github.listPRs() to check recent changes
Thought 3: Synthesizing findings and forming recommendation
```

## Installation Commands

### Claude Code

```bash
claude mcp add sequential-thinking -s local -- npx -y @modelcontextprotocol/server-sequential-thinking
```

### Claude Desktop

Add to `claude_desktop_config.json`:
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
```

### VS Code

Add to `.vscode/mcp.json`:

```json
{
  "servers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
```

### Docker

```bash
# Build the image
docker build -t mcp/sequentialthinking -f src/sequentialthinking/Dockerfile .

# Run the container
docker run --rm -i mcp/sequentialthinking
```

### Codex CLI

```bash
codex mcp add sequential-thinking npx -y @modelcontextprotocol/server-sequential-thinking
```

## Environment Variables

| Variable | Default | Effect |
|----------|---------|--------|
| `DISABLE_THOUGHT_LOGGING` | `false` | Set to `true` to suppress console logging of formatted thoughts |
| `MCP_TIMEOUT` | `60000` | Connection timeout in ms. Increase to `15000`+ for stability |

## Domain-Specific Workflows

### The Debugging Stack

Integrates ST with filesystem for autonomous repair:

```
Step 1 (ST):     "Deconstruct the error. Hypothesize 3 potential causes."
Step 2 (FS):     Read relevant code files to verify Hypothesis 1
Step 3 (ST):     "Hypothesis 1 verified. The null check is missing. Plan the fix."
Step 4 (FS):     Apply the fix via Edit tool
Step 5 (ST):     "Review the fix. Is it safe? Are there edge cases?"
Step 6 (Bash):   Run tests to validate
Step 7 (ST):     "Tests pass. Fix complete." → nextThoughtNeeded: false
```

### Requirements Decomposition (The "Spike")

Use ST to break down vague requests into technical specs BEFORE writing code:

```
User request: "Make it look modern"

Workflow:
1. ST Thought 1-3: Decompose "modern" into measurable criteria
2. ST Branch A: Explore "Material Design 3" implications
3. ST Branch B: Explore "Flat/Minimal" implications
4. ST Synthesis: "Material Design 3 aligns with existing component library"
5. Output: Structured task list for subsequent coding session
```

**Key insight:** The output is NOT code—it's a validated plan.

### Risk Assessment (Red Team Branch)

For high-stakes operations (migrations, destructive actions):

```
Main trunk:     Plans the database migration
Branch red-team: Actively tries to find flaws ("What if connection drops mid-migration?")
Main trunk:     Revises plan based on Red Team findings
Execute:        Only after Red Team finds no critical issues
```

### The Safe Refactor Playbook

Complete workflow for safe code restructuring:

```
1. ST:   Analyze file dependencies and identify coupling
2. FS:   Read package.json, imports, and related files
3. ST:   Branch: Create dependency graph analysis
4. ST:   Plan the move sequence (order matters for imports)
5. FS:   mv files to new locations
6. FS:   Update import statements
7. ST:   Plan verification approach
8. Bash: Run test suite
9. ST:   (If fail) Revise plan based on error → Fix → Retest
10. ST:  "Refactor complete. All tests pass." → nextThoughtNeeded: false
```

