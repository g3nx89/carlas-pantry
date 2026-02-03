# Smoke Test Suite: E-Commerce Platform

**Duration:** 20-30 minutes
**Frequency:** Daily / Every Build
**Purpose:** Quick sanity check before detailed testing

---

## Suite Overview

| ID | Test | Priority | Time | Status |
|----|------|----------|------|--------|
| SMOKE-001 | Application loads | P0 | 1 min | [ ] |
| SMOKE-002 | User can login | P0 | 2 min | [ ] |
| SMOKE-003 | Homepage displays | P0 | 1 min | [ ] |
| SMOKE-004 | Product search works | P0 | 2 min | [ ] |
| SMOKE-005 | Add to cart functions | P0 | 2 min | [ ] |
| SMOKE-006 | Checkout accessible | P0 | 2 min | [ ] |
| SMOKE-007 | Payment gateway responds | P0 | 3 min | [ ] |
| SMOKE-008 | User can logout | P0 | 1 min | [ ] |
| SMOKE-009 | API health check | P0 | 1 min | [ ] |
| SMOKE-010 | Database connectivity | P0 | 1 min | [ ] |

**Total Estimated Time:** 16 minutes (buffer to 20-30 min)

---

## Test Cases

### SMOKE-001: Application Loads

**Steps:**
1. Open browser and navigate to application URL
2. Verify page loads without errors

**Expected:**
- Page loads within 5 seconds
- No 500 errors
- No blank/white screen
- Basic layout visible

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-002: User Can Login

**Preconditions:** Test account exists

**Steps:**
1. Navigate to login page
2. Enter valid credentials
3. Click Login

**Expected:**
- Login succeeds
- User redirected to dashboard/home
- User name/avatar visible

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-003: Homepage Displays

**Steps:**
1. Navigate to homepage (logged in or out)
2. Verify key elements present

**Expected:**
- Navigation menu visible
- Featured products/content loads
- Search bar functional
- Footer present

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-004: Product Search Works

**Steps:**
1. Enter search term in search bar
2. Submit search

**Expected:**
- Search results page loads
- Relevant results displayed
- No errors

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-005: Add to Cart Functions

**Steps:**
1. Navigate to any product
2. Click "Add to Cart"

**Expected:**
- Item added to cart
- Cart count updates
- Confirmation message shown

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-006: Checkout Accessible

**Preconditions:** Item in cart

**Steps:**
1. Navigate to cart
2. Click "Proceed to Checkout"

**Expected:**
- Checkout page loads
- Cart items displayed
- Payment form visible

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-007: Payment Gateway Responds

**Steps:**
1. On checkout, enter test card details
2. Verify payment form validates

**Expected:**
- Card fields accept input
- Validation works (card number format)
- No gateway connection errors
- (Do NOT complete actual payment)

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-008: User Can Logout

**Preconditions:** User logged in

**Steps:**
1. Click user menu/profile
2. Click Logout

**Expected:**
- User logged out
- Redirected to home/login
- Session cleared

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-009: API Health Check

**Steps:**
1. Call health endpoint: `GET /api/health`

**Expected:**
- Response: 200 OK
- Body: `{"status": "healthy"}`
- Response time < 500ms

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

### SMOKE-010: Database Connectivity

**Steps:**
1. Verify API can read data (e.g., products load)
2. Verify API can write data (e.g., cart updates)

**Expected:**
- Read operations succeed
- Write operations succeed
- No timeout errors

**Pass:** [ ] **Fail:** [ ] **Blocked:** [ ]

---

## Execution Summary

**Date:** ___________
**Build:** ___________
**Tester:** ___________
**Environment:** ___________

### Results

| Result | Count |
|--------|-------|
| Pass | /10 |
| Fail | /10 |
| Blocked | /10 |

### Pass/Fail Criteria

**PASS Suite:** All 10 tests pass
**FAIL Suite:** Any test fails → Stop, report, fix before proceeding

### Failed Tests

| ID | Issue | Bug ID |
|----|-------|--------|
| | | |

### Blocked Tests

| ID | Blocker | Resolution |
|----|---------|------------|
| | | |

---

## Notes

- Run this suite before any detailed testing
- If smoke fails, do not proceed with full regression
- Report failures immediately to development team
- Update suite when critical paths change

---

## Next Steps After Smoke

**If PASS:**
- Proceed to targeted regression
- Continue with new feature testing
- Run full regression (if release)

**If FAIL:**
- Stop testing
- Report blocker to team
- Wait for hotfix
- Re-run smoke after fix
