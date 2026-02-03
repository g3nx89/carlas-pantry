# BUG-2024-0142: [Checkout] Cart total shows $0 when discount code applied twice

**Severity:** High
**Priority:** P1
**Type:** Functional
**Status:** Open
**Assignee:** [Unassigned]
**Reporter:** QA Team
**Reported Date:** YYYY-MM-DD

---

## Environment

| Property | Value |
|----------|-------|
| **OS** | macOS 14.2 |
| **Browser** | Chrome 120.0.6099.109 |
| **Device** | MacBook Pro 14" |
| **Build/Version** | v2.5.0-rc1 (commit a1b2c3d) |
| **Environment** | Staging |
| **URL** | https://staging.example.com/checkout |

---

## Description

When a discount code is applied twice in quick succession on the checkout page, the cart total incorrectly displays $0.00 instead of the discounted amount. The issue persists until the page is refreshed or the discount code is removed and re-applied.

---

## Steps to Reproduce

**Preconditions:**
- User logged in with items in cart (total > $50)
- Valid discount code available: `SAVE20` (20% off)

**Steps:**
1. Navigate to https://staging.example.com/checkout
2. Verify cart total displays correctly (e.g., $75.00)
3. Enter discount code `SAVE20` in the promo code field
4. Click "Apply" button
5. **Immediately** click "Apply" button again (within 1 second)
6. Observe the cart total

**Reproduction Rate:** 8 out of 10 attempts (80%)

---

## Expected Behavior

Cart total should show the correctly discounted amount:
- Original: $75.00
- Discount (20%): -$15.00
- **Expected Total: $60.00**

The second click should either be ignored or show "Code already applied" message.

---

## Actual Behavior

Cart total displays **$0.00** after the second click.

The discount line shows "-$75.00" (100% discount instead of 20%).

---

## Visual Evidence

**Screenshots:**
- [ ] Before applying code: Cart shows $75.00
- [ ] After double-click: Cart shows $0.00
- [ ] Console errors: Attached below

**Video Recording:** [Link to screen recording]

**Console Errors:**
```
TypeError: Cannot read property 'amount' of undefined
    at calculateDiscount (checkout.js:342)
    at applyPromoCode (checkout.js:128)
```

**Network Errors:**
```
POST /api/cart/apply-discount 200 OK
POST /api/cart/apply-discount 500 Internal Server Error
Response: {"error": "Discount already applied", "code": "DUPLICATE_DISCOUNT"}
```

---

## Impact Assessment

| Aspect | Details |
|--------|---------|
| **Users Affected** | All users attempting checkout with promo codes |
| **Frequency** | ~15% of checkout attempts (users who double-click) |
| **Data Impact** | No data loss, but incorrect pricing displayed |
| **Business Impact** | Potential revenue loss if users complete $0 orders; user frustration |
| **Workaround** | Refresh page and apply code only once; or remove code and re-apply |

---

## Additional Context

**Related Items:**
- Feature: FEAT-890 (Discount code implementation)
- Test Case: TC-CHECKOUT-025 (Apply promo code)
- Similar Bug: None found

**Regression Information:**
- Is this a regression? **Yes**
- Last working version: v2.4.2
- First broken version: v2.5.0-rc1
- Likely cause: PR #1234 (Refactored discount calculation)

**Notes:**
- Issue does not occur when clicking slowly (>2 seconds between clicks)
- Mobile users more likely to experience (touch events may fire twice)
- Affects all discount code types, not just percentage-based

---

## Developer Section

### Root Cause
[To be filled after investigation]

### Fix Description
[To be filled - consider: debounce apply button, validate discount state before calculation]

### Files Changed
- [ ] src/checkout/discount.js
- [ ] src/api/cart.controller.js

### Fix PR
[Link to pull request]

---

## QA Verification

- [ ] Fix verified in dev environment
- [ ] Fix verified in staging
- [ ] Regression tests passed
- [ ] Related test cases updated (TC-CHECKOUT-025)
- [ ] Edge case added: double-click scenario
- [ ] Ready for production

**Verified By:** ___________
**Verification Date:** ___________
**Verification Build:** ___________

---

## Comments

**YYYY-MM-DD HH:MM - QA Team:**
Initial report. High priority due to checkout impact.

**[Add updates here]**
