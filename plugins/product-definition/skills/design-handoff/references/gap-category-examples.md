# Gap Category Examples — Calibration Reference

> **Purpose:** Concrete examples for each of the 6 gap categories. Loaded ONLY in the `handoff-gap-analyzer` agent dispatch prompt — NOT in coordinator context.
> **Usage:** Agent uses these to calibrate what constitutes a gap in each category.

---

## 1. Behaviors

What happens when a user interacts with an element? Figma shows static frames, not behavioral outcomes.

| Example Screen | Element | Gap (Invisible to Figma) |
|---------------|---------|--------------------------|
| Login | Submit button | What API endpoint is called? What payload shape? What happens on 200 vs 401 vs 500? Does the button disable during submission? |
| Product List | Product card | Does tapping the card navigate to Product Detail? Or open a bottom sheet preview? Is there a long-press action (add to cart)? |
| Settings | Toggle switch | Does changing the toggle take effect immediately or require a Save action? Is there a confirmation dialog for destructive toggles (e.g., "Delete Account")? |
| Search | Search input | Does search trigger on each keystroke (debounced) or on explicit submit? Is there a minimum character count? |

---

## 2. States

Which UI states exist but are not shown as separate frames or component variants?

| Example Screen | Missing State | Gap |
|---------------|---------------|-----|
| Product List | Empty state | What does the screen show when the user has zero items? Illustration? Call-to-action? |
| Product List | Loading state | Skeleton screens? Spinner? Shimmer placeholders? How many skeleton rows? |
| Product List | Error state | Inline error banner? Full-screen error with retry button? Does it preserve partial data on retry? |
| Checkout Form | Validation error | Per-field inline errors? Summary banner at top? Which fields validate on blur vs on submit? |
| Profile | Offline state | Is the profile cached for offline viewing? Or does it show a "No connection" screen? |

---

## 3. Animations

Micro-interactions, gesture-driven animations, and transition specifications that Figma prototyping cannot fully express.

| Example Screen | Element | Gap |
|---------------|---------|-----|
| Login | Submit button | Loading spinner animation: duration? Easing curve? Does the button shrink to a circle during loading? |
| Product List | Pull-to-refresh | Overscroll distance before refresh triggers? Custom refresh indicator or platform default? |
| Onboarding | Page carousel | Swipe velocity threshold? Snap behavior? Parallax on background layers? |
| Modal | Bottom sheet | Drag-to-dismiss threshold (% of height)? Velocity-based dismiss? Background dimming interpolation? |
| Toast | Success notification | Slide-in direction? Auto-dismiss delay (ms)? Swipe-to-dismiss supported? |

---

## 4. Data

API calls, payloads, response shapes, dynamic content sources, and real-time update behavior.

| Example Screen | Element | Gap |
|---------------|---------|-----|
| Dashboard | Stats cards | Data source? Refresh interval? Are values real-time (WebSocket) or polled? Stale data indicator? |
| Product List | Product items | API endpoint? Pagination strategy (offset vs cursor)? Page size? Sort/filter parameters? |
| Profile | User avatar | Upload endpoint? Max file size? Accepted formats? Crop behavior? Compression? |
| Chat | Message list | Real-time protocol (WebSocket, SSE, polling)? Message grouping by time? Read receipts? |

---

## 5. Logic

Business rules, permission gates, conditional rendering, A/B variations, and feature flags.

| Example Screen | Element | Gap |
|---------------|---------|-----|
| Dashboard | Admin section | Which user roles see this section? What does a non-admin see in its place — hidden entirely or "Upgrade" CTA? |
| Checkout | Promo code field | Validation rules? Server-side or client-side? What discount types (%, fixed, free shipping)? Stacking rules? |
| Product Detail | "Add to Cart" button | Inventory check before adding? What if item goes out of stock while user is on the page? |
| Settings | Feature toggle | Is this gated by a feature flag? A/B test variant? Subscription tier? |

---

## 6. Edge Cases

Boundary conditions, failure modes, and concurrent action scenarios.

| Example Screen | Element | Gap |
|---------------|---------|-----|
| Product List | List rendering | What happens with 0 items? 10,000 items? Does it virtualize? Infinite scroll or paginated? |
| Profile | Display name field | Max character length? Unicode handling? What about extremely long single-word names (layout overflow)? |
| Checkout | Submit order | Double-tap prevention? What if the user backgrounds the app during submission? Resume behavior? |
| Login | Password field | Rate limiting after N failed attempts? Account lockout? CAPTCHA trigger? |
| Any form | Network timeout | Retry policy? Exponential backoff? User-facing timeout message? Data loss on timeout? |
