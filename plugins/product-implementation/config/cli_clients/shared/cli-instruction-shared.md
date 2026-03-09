### Output Standards
- All reviews must include a <SUMMARY> block as the final section
- Every finding must include file:line location and specific recommendation
- Report in severity order: Critical > High > Medium > Low
- Never mix opinions with verifiable facts

### Severity Classification
- **Critical**: Breaks functionality, security vulnerability, data loss risk
- **High**: Likely bugs, significant quality issue. ESCALATE if: user-visible data corruption, UI state contradiction, race condition with user-visible effect
- **Medium**: Code smell, maintainability concern, minor pattern violation
- **Low**: Style preference, minor optimization
