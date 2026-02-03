/**
 * Fork-Join Architecture Decision
 *
 * Pattern: Evaluate mutually exclusive options with trade-offs
 * Use when: Choosing between technical approaches, libraries, or architectures
 */

// THOUGHT 1: Frame - Define problem, constraints, and options
const thought1 = {
  thought: `DECISION: Caching strategy for user session data.

CONSTRAINTS:
- Must handle 10k concurrent users
- Session data ~2KB per user
- Budget: minimal infrastructure overhead
- Team: 2 backend developers, no DevOps

OPTIONS TO EVALUATE:
A) Redis - external cache server
B) In-Memory - application-level cache`,
  thoughtNumber: 1,
  totalThoughts: 6,
  nextThoughtNeeded: true
};

// THOUGHT 2: Branch A - Analyze Redis option (FORK)
const thought2_branchA = {
  thought: `OPTION A: Redis Cache

PROS:
- Persistence across restarts
- Mature ecosystem, well-documented
- Horizontal scaling if needed
- Shared state across app instances

CONS:
- Infrastructure cost (~$15-50/mo for managed)
- Additional operational overhead
- Network latency for cache hits
- Requires Redis expertise team lacks`,
  thoughtNumber: 2,
  totalThoughts: 6,
  branchFromThought: 1,      // Fork from thought 1
  branchId: "option-redis",  // Unique branch identifier
  nextThoughtNeeded: true
};

// THOUGHT 3: Branch A continued - Assess fit
const thought3_branchA = {
  thought: `Redis FIT ASSESSMENT:
- 10k users * 2KB = 20MB - Redis handles easily
- Team lacks Redis expertise - learning curve ~1 week
- Infrastructure overhead conflicts with 'minimal overhead' constraint
- Overkill for current scale

VERDICT: Over-engineered for requirements.`,
  thoughtNumber: 3,
  totalThoughts: 6,
  branchId: "option-redis",  // Continue in same branch (no branchFromThought)
  nextThoughtNeeded: true
};

// THOUGHT 4: Branch B - Analyze In-Memory option (PARALLEL FORK)
const thought4_branchB = {
  thought: `OPTION B: In-Memory Cache (e.g., node-cache, lru-cache)

PROS:
- Zero infrastructure cost
- Sub-millisecond access
- Team already knows JavaScript
- Simple implementation

CONS:
- No persistence - cache lost on restart
- Memory limits (but 20MB is trivial)
- Not shared across instances (single instance OK for now)
- Must implement eviction policy`,
  thoughtNumber: 4,
  totalThoughts: 6,
  branchFromThought: 1,         // Fork from SAME origin as Branch A
  branchId: "option-inmemory",  // Different branch identifier
  nextThoughtNeeded: true
};

// THOUGHT 5: Synthesize - Compare branches, make recommendation (JOIN)
// NOTE: Return to main trunk by NOT including branchId
const thought5_synthesis = {
  thought: `SYNTHESIS - Comparing branches:

| Criterion | Redis | In-Memory |
|-----------|-------|----------|
| Cost | $15-50/mo | $0 |
| Complexity | High | Low |
| Team skill match | Poor | Good |
| Scale fit | Overkill | Right-sized |
| Risk | Operational burden | Cache loss on restart |

RECOMMENDATION: In-Memory cache.

RATIONALE: Matches constraints (minimal overhead, small team). Cache loss on restart is acceptable for session data - users re-authenticate. Can migrate to Redis later if scale demands.`,
  thoughtNumber: 5,
  totalThoughts: 6,
  // No branchId = back on main trunk
  nextThoughtNeeded: true
};

// THOUGHT 6: Finalize - Document decision
const thought6_final = {
  thought: `DECISION RECORD:

Chosen: In-Memory cache (lru-cache library)

Implementation:
1. Install lru-cache (zero dependencies)
2. Set max 15k entries (headroom for 10k users)
3. TTL 30 minutes (session timeout)
4. Add cache-hit/miss metrics for monitoring

Migration trigger: If we exceed single instance OR need persistence, revisit Redis.

Plan complete.`,
  thoughtNumber: 6,
  totalThoughts: 6,
  nextThoughtNeeded: false  // TERMINATION
};

/**
 * Key patterns demonstrated:
 *
 * 1. FORK: Multiple branches share same branchFromThought (thought 1)
 * 2. PARALLEL: Each branch has unique branchId
 * 3. ANALYZE: 2-3 thoughts per branch evaluate pros/cons
 * 4. JOIN: Synthesis thought returns to main trunk (no branchId)
 * 5. SYNTHESIS: Must explicitly reference findings from BOTH branches
 * 6. Rejected branches remain in history as auditable decision records
 */
