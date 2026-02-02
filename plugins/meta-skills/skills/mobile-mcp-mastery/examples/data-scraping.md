# Example: Data Scraping from Mobile App

> Complete workflow demonstrating data extraction from a list-based mobile app.

## Scenario

Extract product listings from an e-commerce app: launch → navigate to category → scroll through items → collect data.

## Prerequisites

- iOS Simulator or Android Emulator running
- Target app installed

## Workflow

### Step 1: Device Verification

```
Tool: mobile_list_available_devices
Parameters: {}
```

### Step 2: Launch Application

```
Tool: mobile_launch_app
Parameters: { "bundleId": "com.example.shopping" }

Wait: 3-5 seconds
```

### Step 3: Handle Initial Popups (if any)

```
Tool: mobile_list_elements_on_screen
Parameters: {}

If promotional popup detected:
- Find "Close", "X", or "Skip" button
- Tap to dismiss
- Re-query elements
```

### Step 4: Navigate to Target Section

```
# Find navigation element (e.g., "Products" tab)
Tool: mobile_list_elements_on_screen
Parameters: {}

# Tap navigation item
Tool: mobile_click_on_screen_at_coordinates
Parameters: { "x": [nav_center_x], "y": [nav_center_y] }

Wait: 2 seconds
```

### Step 5: Extract Visible Data

```
Tool: mobile_list_elements_on_screen
Parameters: {}

Parse elements to extract:
- Product names (typically in larger text elements)
- Prices (text containing "$" or currency symbol)
- Ratings (star icons or numeric ratings)
- Any other relevant metadata
```

### Step 6: Scroll and Continue Extraction

```
# Scroll to reveal more content
Tool: mobile_swipe_on_screen
Parameters: { "direction": "up" }
# Note: "up" = finger moves up = content scrolls down = reveals items below

Wait: 1 second

# Extract newly visible items
Tool: mobile_list_elements_on_screen
Parameters: {}

# Check for duplicates (same items = reached end or no new content)
```

### Step 7: Repeat Until Complete

```
LOOP:
  1. Extract visible data
  2. Scroll down (direction: "up")
  3. Wait 1 second
  4. Check for new elements
  5. IF same elements as before: EXIT (reached end)
  6. IF new elements: CONTINUE
```

### Step 8: Cleanup

```
Tool: mobile_terminate_app
Parameters: { "packageName": "com.example.shopping" }
```

## Data Structure Example

```json
{
  "extracted_items": [
    {
      "name": "Wireless Headphones",
      "price": "$79.99",
      "rating": "4.5",
      "position": 1
    },
    {
      "name": "Bluetooth Speaker",
      "price": "$49.99",
      "rating": "4.2",
      "position": 2
    }
  ],
  "total_items": 24,
  "scroll_iterations": 6
}
```

## Handling Edge Cases

| Situation | Solution |
|-----------|----------|
| Infinite scroll | Set max iterations (e.g., 10 scrolls) |
| Loading spinners | Wait for spinner to disappear before extracting |
| Lazy-loaded images | Text elements load first, proceed without images |
| Pull-to-refresh triggered | Scroll from middle of screen, not top |
| Rate limiting | Add longer delays between actions |

## Prompt Template

```
Scrape [DATA_TYPE] from [APP_NAME]:
1. Launch [BUNDLE_ID]
2. Wait 3 seconds for app load
3. If any popup appears, dismiss it
4. Navigate to [SECTION_NAME] using [NAVIGATION_METHOD]
5. Wait 2 seconds for content to load
6. Extract all visible [ITEM_TYPE] with their [FIELDS]
7. Scroll down to reveal more items
8. Repeat extraction and scrolling until:
   - No new items appear after scroll, OR
   - Reached [MAX_ITEMS] items, OR
   - Completed [MAX_SCROLLS] scroll iterations
9. Return structured data with all extracted items
10. Terminate app when done
```

## Output Format

```markdown
## Extraction Results

**App**: [APP_NAME]
**Section**: [SECTION_NAME]
**Total Items**: [COUNT]
**Extraction Date**: [TIMESTAMP]

### Items

| # | Name | Price | Rating |
|---|------|-------|--------|
| 1 | Item A | $X.XX | X.X |
| 2 | Item B | $X.XX | X.X |
...
```
