# Synthesis Patterns

Templates and strategies for producing the final research output from multi-provider results.

---

## Quick Search Output Template

For single-round parallel queries:

```markdown
# DeepSearch: {query}

> Searched on: {date}
> Providers: {list of providers that responded, with active model if visible}
> Mode: Quick Search

## Synthesis

{2-4 paragraphs synthesizing findings across all providers}

{Note areas of strong agreement — facts confirmed by 2+ providers}

{Note disagreements or contradictions between providers, with which provider said what}

## Provider Results

### ChatGPT
{Extracted key points — bullet list or paragraphs as appropriate}

### Gemini
{Extracted key points}

### Perplexity
{Extracted key points}

## Sources & References

{Aggregated URLs from all providers, primarily from Perplexity}
{De-duplicate URLs that appear in multiple providers}

- [{title or domain}]({url}) — cited by {provider(s)}
```

---

## Deep Research Output Template

For multi-round iterative research:

```markdown
# DeepSearch: {topic}

> Searched on: {date}
> Providers: {list}
> Mode: Deep Research ({N} rounds)

## Executive Summary

{3-5 sentence overview of the complete findings}

## Key Findings

### {Sub-topic 1}
{Detailed findings, combining information from multiple rounds and providers}
{Inline attribution: "According to ChatGPT..." / "Perplexity sources indicate..."}

### {Sub-topic 2}
{Same structure}

### {Sub-topic N}
{Same structure}

## Contradiction Analysis

| Topic | ChatGPT Says | Gemini Says | Perplexity Says | Assessment |
|-------|-------------|-------------|-----------------|------------|
| {point of disagreement} | {position} | {position} | {position} | {which is likely correct and why} |

## Research Trail

### Round 1: Initial Query
- **Query**: {original query}
- **Providers queried**: All three
- **Key findings**: {brief summary}
- **Gaps identified**: {what was missing or unclear}

### Round 2: Follow-up
- **Query**: {follow-up query}
- **Providers queried**: {targeted providers}
- **Key findings**: {brief summary}
- **Remaining gaps**: {if any}

### Round 3: Final Refinement
{Same structure, if applicable}

## Sources & References

{Comprehensive list, organized by sub-topic}

### {Sub-topic 1}
- [{title}]({url}) — cited by {provider}, round {N}

### {Sub-topic 2}
- [{title}]({url})

## Confidence Assessment

| Finding | Confidence | Basis |
|---------|------------|-------|
| {key claim} | High / Medium / Low | {e.g., "Confirmed by all 3 providers with consistent sources"} |
```

---

## Synthesis Strategies

### Agreement-Based Synthesis

When providers largely agree:
1. Lead with the consensus finding
2. Note which providers confirmed it
3. Add any unique details that only one provider mentioned
4. List shared sources

### Disagreement-Based Synthesis

When providers contradict each other:
1. State the disagreement clearly
2. Present each position with its supporting evidence
3. Assess which is more likely correct based on:
   - Source quality (Perplexity's cited sources are most verifiable)
   - Recency of information
   - Specificity of the claim
4. If unresolvable, present both positions and recommend further research

### Complementary Synthesis

When providers cover different aspects:
1. Map which provider covered which sub-topic best
2. Combine non-overlapping information into a unified narrative
3. Note which provider was the primary source for each section
4. Cross-validate facts where coverage overlaps

---

## Deep Research Round Management

### Round 1: Broad Query

- Submit the user's original query to all three providers
- Focus on collecting the widest coverage
- Extract all source URLs for later reference

### Round 2: Gap-Filling

After analyzing Round 1 results:

1. **Identify gaps**: What questions remain unanswered?
2. **Identify contradictions**: Where do providers disagree?
3. **Formulate follow-up**: Create specific, targeted queries
4. **Select providers**: Send follow-ups to the most relevant provider(s):
   - Factual gaps → Perplexity (web search with citations)
   - Technical depth → ChatGPT
   - Alternative perspectives → Gemini

### Round 3: Verification & Depth

Only if needed after Round 2:

1. **Verify contradictions**: Re-query with specific claims to check
2. **Deepen weak areas**: Target the least-covered sub-topic
3. **Source validation**: Ask Perplexity to verify specific claims with sources

### Round Exit Criteria

Stop iterating when:
- All user questions are answered with reasonable confidence
- No new information is surfacing across rounds
- 3 rounds have been completed (hard limit)
- The user's original scope is fully covered

---

## Citation Formatting

### Inline Citations

When referencing provider-specific findings in the synthesis:
- **Direct attribution**: "ChatGPT notes that..." / "According to Gemini..."
- **Source-backed**: "Perplexity cites [Source Name] reporting that..."
- **Consensus**: "All three providers agree that..."

### Source Aggregation Rules

1. **De-duplicate**: If multiple providers cite the same URL, list it once with all citing providers
2. **Perplexity first**: Perplexity sources are most reliable (web-grounded) — list them prominently
3. **Verify reachability**: Do not include URLs that appear hallucinated (common with ChatGPT)
4. **Group by relevance**: Most relevant sources first, supplementary sources last

---

## Handling Partial and Timeout Responses

When a provider hits the max wait timeout or extraction is incomplete:

1. **Mark clearly**: Add `(partial — extraction timeout)` or `(partial — streaming incomplete)` next to the provider heading
2. **Extract what exists**: Even partial responses contain useful information — extract and include them
3. **Lower weight in synthesis**: Do not give equal weight to a partial response when synthesizing; note that the provider's coverage may be incomplete
4. **Note in sources**: If source URLs were partially extracted, indicate this: "Sources may be incomplete due to timeout"

## Quality Checklist for Output

Before delivering the final synthesis:

- [ ] All queried providers are represented in the output
- [ ] Skipped providers are noted with reason
- [ ] Partial/timeout responses are clearly marked
- [ ] No fabricated sources — only URLs actually cited by providers
- [ ] Contradictions are explicitly called out, not silently resolved
- [ ] The synthesis adds value beyond just concatenating provider responses
- [ ] Sources are de-duplicated and attributed to citing providers
- [ ] The appropriate template (Quick Search vs Deep Research) was used
- [ ] Active model noted per provider when visible (e.g., "ChatGPT 5.2 Thinking", "Grok 4.1")
