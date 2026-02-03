# TC-LOGIN-001: Valid User Login

**Priority:** P0 (Critical)
**Type:** Functional
**Status:** Not Run
**Estimated Time:** 2 minutes
**Module:** Authentication

---

## Objective

Verify registered users can successfully authenticate with valid credentials and access the application.

---

## Preconditions

- [ ] Test user account exists: `test@example.com` / `Test123!`
- [ ] User is not currently logged in
- [ ] Browser cookies and cache cleared
- [ ] Application is accessible at staging URL

---

## Test Steps

1. **Navigate to login page**
   - URL: `https://app.example.com/login`
   - **Expected:** Login page displays with email field, password field, and "Login" button

2. **Enter valid email**
   - Input: `test@example.com`
   - **Expected:** Email field accepts input, no validation errors

3. **Enter valid password**
   - Input: `Test123!`
   - **Expected:** Password field shows masked characters (dots/asterisks)

4. **Click "Login" button**
   - **Expected:**
     - Loading indicator appears briefly
     - User redirected to `/dashboard`
     - Welcome message displayed: "Welcome back, Test User"
     - User avatar/profile image visible in header
     - Navigation menu shows authenticated state

5. **Verify session persistence**
   - Refresh the page (F5)
   - **Expected:** User remains logged in, dashboard still accessible

---

## Test Data

| Field | Value | Notes |
|-------|-------|-------|
| Email | test@example.com | Valid registered email |
| Password | Test123! | Meets password requirements |
| Expected Name | Test User | Display name after login |

---

## Post-conditions

- User session is active
- Authentication token stored in browser
- Login event logged in analytics
- Last login timestamp updated in database

---

## Edge Cases & Variations

| ID | Variation | Input | Expected |
|----|-----------|-------|----------|
| TC-LOGIN-002 | Invalid password | test@example.com / WrongPass | Error: "Invalid credentials" |
| TC-LOGIN-003 | Non-existent email | fake@example.com / Test123! | Error: "Invalid credentials" |
| TC-LOGIN-004 | Empty email | (empty) / Test123! | Validation: "Email required" |
| TC-LOGIN-005 | Empty password | test@example.com / (empty) | Validation: "Password required" |
| TC-LOGIN-006 | SQL injection | `' OR '1'='1` / password | Input sanitized, error shown |
| TC-LOGIN-007 | Case sensitivity | TEST@EXAMPLE.COM / Test123! | Login succeeds (email case-insensitive) |

---

## Related Test Cases

- TC-LOGIN-010: Remember me functionality
- TC-LOGIN-015: Password reset flow
- TC-LOGOUT-001: User logout
- TC-SESSION-001: Session timeout

---

## Execution History

| Date | Tester | Build | Result | Bug ID | Notes |
|------|--------|-------|--------|--------|-------|
| | | | Not Run | | |

---

## Notes

- Password visibility toggle should work correctly
- "Forgot password" link should be present and functional
- Social login options (if implemented) should be tested separately
