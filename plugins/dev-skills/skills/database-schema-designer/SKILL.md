---
name: database-schema-designer
description: This skill should be used when the user asks to "design a schema", "create tables", "model data", "normalize a database", "plan migrations", "I need a database for...", or needs help designing SQL/NoSQL schemas. Triggers include database design, schema creation, table relationships, foreign keys, indexing strategy, and migration planning.
license: MIT
allowed-tools: Read, Glob, Grep
---

# Database Schema Designer

Design production-ready database schemas with best practices built-in.

## Quick Start

Describe your data model:

```
design a schema for an e-commerce platform with users, products, orders
```

**Include in your request:**
- Entities (users, products, orders)
- Key relationships (users have orders, orders have items)
- Scale hints (high-traffic, millions of records)
- Database preference (SQL/NoSQL) - defaults to SQL if not specified

## Key Terms

| Term | Definition |
|------|------------|
| **Normalization** | Organizing data to reduce redundancy (1NF -> 2NF -> 3NF) |
| **3NF** | Third Normal Form - no transitive dependencies between columns |
| **OLTP** | Online Transaction Processing - write-heavy, needs normalization |
| **OLAP** | Online Analytical Processing - read-heavy, benefits from denormalization |
| **Foreign Key (FK)** | Column that references another table's primary key |
| **Index** | Data structure that speeds up queries (at cost of slower writes) |

## Process Overview

```
Requirements -> Analysis -> Design -> Optimize -> Migrate
```

1. **Analysis**: Identify entities, relationships, access patterns (read vs write heavy)
2. **Design**: Normalize to 3NF (SQL) or embed/reference (NoSQL), define keys and constraints
3. **Optimize**: Plan indexing strategy, consider denormalization for read-heavy queries
4. **Migrate**: Generate reversible migration scripts, ensure backward compatibility

## Quick Reference

| Task | Approach | Key Consideration |
|------|----------|-------------------|
| New schema | Normalize to 3NF first | Domain modeling over UI |
| SQL vs NoSQL | Access patterns decide | Read/write ratio matters |
| Primary keys | INT or UUID | UUID for distributed systems |
| Foreign keys | Always constrain | ON DELETE strategy critical |
| Indexes | FKs + WHERE columns | Column order matters |
| Migrations | Always reversible | Backward compatible first |

## Core Principles

| Principle | WHY | Implementation |
|-----------|-----|----------------|
| Model the Domain | UI changes, domain doesn't | Entity names reflect business concepts |
| Data Integrity First | Corruption is costly to fix | Constraints at database level |
| Optimize for Access Pattern | Can't optimize for both | OLTP: normalized, OLAP: denormalized |
| Plan for Scale | Retrofitting is painful | Index strategy + partitioning plan |

## Anti-Patterns

| Avoid | Why | Instead |
|-------|-----|---------|
| VARCHAR(255) everywhere | Wastes storage, hides intent | Size appropriately per field |
| FLOAT for money | Rounding errors | DECIMAL(10,2) |
| Missing FK constraints | Orphaned data | Always define foreign keys |
| No indexes on FKs | Slow JOINs | Index every foreign key |
| Storing dates as strings | Can't compare/sort | DATE, TIMESTAMP types |
| SELECT * in queries | Fetches unnecessary data | Explicit column lists |
| Non-reversible migrations | Can't rollback | Always write DOWN migration |

## Verification Checklist

After designing a schema:

- [ ] Every table has a primary key
- [ ] All relationships have foreign key constraints
- [ ] ON DELETE strategy defined for each FK
- [ ] Indexes exist on all foreign keys
- [ ] Indexes exist on frequently queried columns
- [ ] Appropriate data types (DECIMAL for money, etc.)
- [ ] NOT NULL on required fields
- [ ] UNIQUE constraints where needed
- [ ] created_at and updated_at timestamps
- [ ] Migration scripts are reversible

## Reference Files

For detailed guidance on specific topics:

| File | When to Read |
|------|--------------|
| **[references/normalization.md](references/normalization.md)** | Understanding 1NF, 2NF, 3NF, when to denormalize |
| **[references/data-types.md](references/data-types.md)** | Choosing string, numeric, date/time types |
| **[references/indexing-strategy.md](references/indexing-strategy.md)** | Index types, composite indexes, pitfalls |
| **[references/constraints.md](references/constraints.md)** | Primary keys, foreign keys, CHECK constraints |
| **[references/relationship-patterns.md](references/relationship-patterns.md)** | One-to-many, many-to-many, polymorphic |
| **[references/nosql-design.md](references/nosql-design.md)** | MongoDB embedding vs referencing |
| **[references/migrations.md](references/migrations.md)** | Zero-downtime migrations, templates |
| **[references/performance-optimization.md](references/performance-optimization.md)** | EXPLAIN, N+1 queries, optimization techniques |
| **[references/schema-design-checklist.md](references/schema-design-checklist.md)** | Comprehensive design checklist |

## Assets

| File | Purpose |
|------|---------|
| **[assets/templates/migration-template.sql](assets/templates/migration-template.sql)** | Starter template for migrations |
