/**
 * Quick Debug Session (5 Thoughts)
 *
 * Pattern: Systematic bug investigation with tool interleaving
 * Use when: Root cause analysis of errors, test failures, or unexpected behavior
 */

// THOUGHT 1: Initialize - Generate hypotheses ranked by likelihood
const thought1 = {
  thought: `Analyzing 'Connection Reset' error in payment service. Generating hypotheses:
1. Network firewall blocking (likelihood: 30%)
2. Application timeout misconfiguration (likelihood: 45%)
3. Database connection pool exhaustion (likelihood: 25%)
Starting with Hypothesis 2 due to highest probability.`,
  thoughtNumber: 1,
  totalThoughts: 5,
  nextThoughtNeeded: true
};

// ACTION: Read nginx.conf to check timeout settings
// RESULT: proxy_read_timeout=60s

// THOUGHT 2: Investigate - Analyze tool output
const thought2 = {
  thought: `nginx.conf shows proxy_read_timeout=60s. Upstream service logs show requests taking 90s under load. This confirms timeout mismatch. Hypothesis 2 validated.`,
  thoughtNumber: 2,
  totalThoughts: 5,
  nextThoughtNeeded: true
};

// ACTION: Read upstream service configuration
// RESULT: No timeout limit configured

// THOUGHT 3: Narrow - Focus on confirmed hypothesis
const thought3 = {
  thought: `Upstream service has no timeout limit, allowing unbounded processing. The nginx 60s timeout is the bottleneck. Fix options:
A) Increase nginx timeout to 120s
B) Add request timeout to upstream service
C) Implement async processing pattern
Option A is quickest fix; Option B prevents cascading failures.`,
  thoughtNumber: 3,
  totalThoughts: 5,
  nextThoughtNeeded: true
};

// THOUGHT 4: Decide - Select approach with rationale
const thought4 = {
  thought: `Choosing Option B (upstream timeout) as primary fix because:
- Prevents unbounded requests from consuming resources
- Fails fast rather than failing slow
- Provides better error messages to clients
Will also apply Option A as defense-in-depth.`,
  thoughtNumber: 4,
  totalThoughts: 5,
  nextThoughtNeeded: true
};

// THOUGHT 5: Conclude - State root cause and fix
const thought5 = {
  thought: `ROOT CAUSE: nginx proxy_read_timeout (60s) is shorter than upstream service processing time under load (90s+).

FIX:
1. Add 90s timeout to upstream service (prevents unbounded requests)
2. Increase nginx timeout to 120s (allows headroom)
3. Add monitoring alert for requests >60s

Plan complete.`,
  thoughtNumber: 5,
  totalThoughts: 5,
  nextThoughtNeeded: false  // TERMINATION
};

/**
 * Key patterns demonstrated:
 *
 * 1. Each thought eliminates possibilities or makes progress
 * 2. Tool calls interleaved between thoughts (not batched)
 * 3. Hypotheses ranked by likelihood to prioritize investigation
 * 4. If no progress by thought 5, extend estimate or ask user
 * 5. Final thought explicitly sets nextThoughtNeeded: false
 */
