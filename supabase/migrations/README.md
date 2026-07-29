# Database Migrations

## Rules

Migrations in this directory follow these conventions:

1. **Forward-only** — Migrations are never rolled back in production. Write compensating migrations instead.

2. **One concern per file** — Each migration addresses a single, focused change. Do not bundle unrelated changes.

3. **Never edited after merge** — Once a migration is merged to `main`, it is immutable. Any correction requires a new migration file.

4. **Applied to production only through CI** — Migrations are applied using Corveo's credential held in GitHub secrets. Never apply migrations to `staging` or `prod` from a local terminal.

## Naming

Use the format: `YYYYMMDDHHMMSS_description.sql`

Example: `20260729120000_create_observation_table.sql`

## Review requirements

All PRs touching this directory require Ben's review before merge.

## Key custody

The migration credential is held by Corveo in GitHub secrets. Ben authors and reviews; the CI pipeline applies.
