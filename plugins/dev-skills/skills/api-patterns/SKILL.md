---
name: api-patterns
description: This skill should be used when the user asks to "design an API", "choose between REST and GraphQL", "implement tRPC", "plan API versioning", "structure API responses", "add pagination", "implement rate limiting", or needs guidance on API style selection, authentication patterns, and documentation best practices.
allowed-tools: Read, Write, Edit, Glob, Grep
---

# API Patterns

> API design principles and decision-making for 2025.
> **Learn to THINK, not copy fixed patterns.**

## Selective Reading Rule

**Read ONLY files relevant to the request!** Check the content map, find what you need.

---

## Content Map

| File | Description | When to Read |
|------|-------------|--------------|
| `references/api-style.md` | REST vs GraphQL vs tRPC decision tree | Choosing API type |
| `references/rest.md` | Resource naming, HTTP methods, status codes | Designing REST API |
| `references/response.md` | Envelope pattern, error format, pagination | Response structure |
| `references/graphql.md` | Schema design, when to use, security | Considering GraphQL |
| `references/trpc.md` | TypeScript monorepo, type safety | TS fullstack projects |
| `references/versioning.md` | URI/Header/Query versioning | API evolution planning |
| `references/auth.md` | JWT, OAuth, Passkey, API Keys | Auth pattern selection |
| `references/rate-limiting.md` | Token bucket, sliding window | API protection |
| `references/documentation.md` | OpenAPI/Swagger best practices | Documentation |
| `references/security-testing.md` | OWASP API Top 10, auth/authz testing | Security audits |

---

## Related Skills

| Need | Skill |
|------|-------|
| Data structure | `database-design` |
| Database schema | `database-schema-designer` |
| Code quality | `clean-code` |

---

## Decision Checklist

Before designing an API:

- [ ] **Asked user about API consumers?**
- [ ] **Chosen API style for THIS context?** (REST/GraphQL/tRPC)
- [ ] **Defined consistent response format?**
- [ ] **Planned versioning strategy?**
- [ ] **Considered authentication needs?**
- [ ] **Planned rate limiting?**
- [ ] **Documentation approach defined?**

---

## Anti-Patterns

**DON'T:**
- Default to REST for everything
- Use verbs in REST endpoints (/getUsers)
- Return inconsistent response formats
- Expose internal errors to clients
- Skip rate limiting

**DO:**
- Choose API style based on context
- Ask about client requirements
- Document thoroughly
- Use appropriate status codes

---

## Script

| Script | Purpose | Command |
|--------|---------|---------|
| `scripts/api_validator.py` | API endpoint validation | `python scripts/api_validator.py <project_path>` |

