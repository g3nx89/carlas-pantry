# Mobile-MCP Anti-Patterns

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| **Hardcoded coordinates** | Breaks on different devices/orientations | Use `mobile_list_elements_on_screen` for current coordinates |
| **Blind swipe from y=0** | Status bar intercepts touch, swipe fails | Start swipe from y >= 100 or use `direction` parameter |
| **Screenshot-first approach** | Slow, requires vision processing | Start with accessibility; screenshot only as fallback |
| **No waits between actions** | Race conditions, stale elements | Add explicit waits after every state-changing action |
| **Fixed sleep everywhere** | Inefficient, may be insufficient | Use condition-based waits when possible |
| **Ignoring loading states** | Interacts with incomplete UI | Check for loading indicators before proceeding |
| **Chained dependent tests** | One failure cascades | Design independent, self-contained workflows |
| **No error recovery** | Automation stops at first failure | Include fallback instructions and retry logic |
| **Skipping device verification** | Mysterious failures | Always call `mobile_list_available_devices` first |
| **Caching element locations** | Coordinates become stale | Re-query elements before each interaction |
| **Not terminating apps** | Memory leaks, state accumulation | Clean up with `mobile_terminate_app` |
| **Zombie sessions** | ADB/WDA processes running indefinitely | Restart MCP server between sessions |
| **Using BACK on iOS** | iOS has no hardware BACK button | Use UI back element or swipe right from left edge |

## Best Practices Checklist

### Tool Selection
- [ ] Always call `mobile_list_elements_on_screen` before tapping
- [ ] Prefer accessibility data over screenshots
- [ ] Use screenshots for verification, not primary discovery
- [ ] Call `mobile_list_available_devices` at start

### Timing
- [ ] Add 2-3 second waits after app launch, navigation, submission
- [ ] Wait for loading indicators to disappear
- [ ] Handle animations by waiting for UI stability
- [ ] Timeouts: 5s app launch, 10s network operations

### Prompt Engineering
- [ ] Use step-by-step numbered instructions
- [ ] Include error handling: "If X appears, do Y"
- [ ] Specify wait conditions: "Wait until Submit is visible"
- [ ] Define success criteria: "Verify confirmation appears"

### Resource Management
- [ ] Terminate apps after testing
- [ ] Don't leave sessions idle
- [ ] Restart sessions if screenshot errors persist

### Cross-Platform
- [ ] Test on both iOS and Android when applicable
- [ ] Use text-based element identification
- [ ] Handle platform-specific navigation differences
