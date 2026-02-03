---
name: clean-code
description: This skill should be used when the user asks to "review code quality", "refactor this code", "simplify this function", "improve naming", "reduce complexity", "apply guard clauses", "remove nested ifs", "follow clean code principles", or "establish coding guidelines". Provides pragmatic coding standards for AI-assisted development, emphasizing concise, direct, solution-focused code without over-engineering or unnecessary comments.
allowed-tools: Read, Write, Edit
---

# Clean Code - Pragmatic AI Coding Standards

> **CRITICAL SKILL** - Be **concise, direct, and solution-focused**.

---

## Core Principles

| Principle | Rule |
|-----------|------|
| **SRP** | Single Responsibility - each function/class does ONE thing |
| **DRY** | Don't Repeat Yourself - extract duplicates, reuse |
| **KISS** | Keep It Simple - simplest solution that works |
| **YAGNI** | You Aren't Gonna Need It - don't build unused features |
| **Boy Scout** | Leave code cleaner than you found it |

---

## Naming Rules

| Element | Convention |
|---------|------------|
| **Variables** | Reveal intent: `userCount` not `n` |
| **Functions** | Verb + noun: `getUserById()` not `user()` |
| **Booleans** | Question form: `isActive`, `hasPermission`, `canEdit` |
| **Constants** | SCREAMING_SNAKE: `MAX_RETRY_COUNT` |

> **Rule:** If you need a comment to explain a name, rename it.

---

## Function Rules

| Rule | Description |
|------|-------------|
| **Small** | Max 20 lines, ideally 5-10 |
| **One Thing** | Does one thing, does it well |
| **One Level** | One level of abstraction per function |
| **Few Args** | Max 3 arguments, prefer 0-2 |
| **No Side Effects** | Don't mutate inputs unexpectedly |

---

## Code Structure

| Pattern | Apply |
|---------|-------|
| **Guard Clauses** | Early returns for edge cases |
| **Flat > Nested** | Avoid deep nesting (max 2 levels) |
| **Composition** | Small functions composed together |
| **Colocation** | Keep related code close |

---

## AI Coding Style

| Situation | Action |
|-----------|--------|
| User asks for feature | Write it directly |
| User reports bug | Fix it, don't explain |
| No clear requirement | Ask, don't assume |

---

## Anti-Patterns (DON'T)

| ❌ Pattern | ✅ Fix |
|-----------|-------|
| Comment every line | Delete obvious comments |
| Helper for one-liner | Inline the code |
| Factory for 2 objects | Direct instantiation |
| utils.ts with 1 function | Put code where used |
| "First we import..." | Just write code |
| Deep nesting | Guard clauses |
| Magic numbers | Named constants |
| God functions | Split by responsibility |

---

## Code Examples

### Example 1: Guard Clauses (Flat > Nested)

```kotlin
// ❌ BAD: Deep nesting
fun processOrder(order: Order?): Result {
    if (order != null) {
        if (order.items.isNotEmpty()) {
            if (order.isPaid) {
                return processPayment(order)
            } else {
                return Result.Error("Not paid")
            }
        } else {
            return Result.Error("Empty order")
        }
    } else {
        return Result.Error("No order")
    }
}

// ✅ GOOD: Guard clauses, flat structure
fun processOrder(order: Order?): Result {
    if (order == null) return Result.Error("No order")
    if (order.items.isEmpty()) return Result.Error("Empty order")
    if (!order.isPaid) return Result.Error("Not paid")

    return processPayment(order)
}
```

### Example 2: Naming (Intent-Revealing)

```typescript
// ❌ BAD: Cryptic names
const d = new Date();
const n = users.filter(u => u.a && u.s > 0);
function calc(x: number, y: number) { return x * y * 0.1; }

// ✅ GOOD: Self-documenting
const currentDate = new Date();
const activeUsersWithBalance = users.filter(
    user => user.isActive && user.balance > 0
);
function calculateTax(price: number, quantity: number): number {
    const TAX_RATE = 0.1;
    return price * quantity * TAX_RATE;
}
```

### Example 3: Single Responsibility

```kotlin
// ❌ BAD: God function doing everything
fun handleUserRegistration(email: String, password: String) {
    // Validate email (10 lines)
    // Validate password (15 lines)
    // Hash password (5 lines)
    // Save to database (10 lines)
    // Send welcome email (20 lines)
    // Log analytics (5 lines)
}

// ✅ GOOD: Composed small functions
fun handleUserRegistration(email: String, password: String) {
    validateEmail(email)
    validatePassword(password)
    val hashedPassword = hashPassword(password)
    val user = saveUser(email, hashedPassword)
    sendWelcomeEmail(user)
    logRegistration(user)
}
```

---

## 🔴 Before Editing ANY File (THINK FIRST!)

**Before changing a file, ask yourself:**

| Question | Why |
|----------|-----|
| **What imports this file?** | They might break |
| **What does this file import?** | Interface changes |
| **What tests cover this?** | Tests might fail |
| **Is this a shared component?** | Multiple places affected |

**Quick Check:**
```
File to edit: UserService.ts
└── Who imports this? → UserController.ts, AuthController.ts
└── Do they need changes too? → Check function signatures
```

> 🔴 **Rule:** Edit the file + all dependent files in the SAME task.
> 🔴 **Never leave broken imports or missing updates.**

---

## Summary

| Do | Don't |
|----|-------|
| Write code directly | Write tutorials |
| Let code self-document | Add obvious comments |
| Fix bugs immediately | Explain the fix first |
| Inline small things | Create unnecessary files |
| Name things clearly | Use abbreviations |
| Keep functions small | Write 100+ line functions |

> **Remember: The user wants working code, not a programming lesson.**

---

## 🔴 Self-Check Before Completing (MANDATORY)

**Before saying "task complete", verify:**

| Check | Question |
|-------|----------|
| ✅ **Goal met?** | Did I do exactly what user asked? |
| ✅ **Files edited?** | Did I modify all necessary files? |
| ✅ **Code works?** | Did I test/verify the change? |
| ✅ **No errors?** | Lint and TypeScript pass? |
| ✅ **Nothing forgotten?** | Any edge cases missed? |

> 🔴 **Rule:** If ANY check fails, fix it before completing.

---

## Note

This skill intentionally has no `references/` directory. Unlike technology-specific skills (android-expert, gradle-expert) that require detailed reference documentation, clean-code is a methodology skill with principles that fit in a single file. The examples above demonstrate the patterns; no additional reference material is needed.
