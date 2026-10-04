# Architectural & Implementation Decisions

This document records architectural decisions made during development, expanding upon ADR-001 through ADR-024 defined in [PRODUCT_ARCHITECTURE_BLUEPRINT.md](../../PRODUCT_ARCHITECTURE_BLUEPRINT.md).

---

## Decision 001: Persistent Tracking Documentation System
**Date:** 2026-10-05  
**Status:** ACCEPTED  
**Context:** Requirement for an autonomous, resumable execution system that survives interruptions and context loss across multiple sessions without losing state.  
**Decision:** Establish `docs/implementation/` containing `PROJECT_STATE.md`, `ROADMAP.md`, `PROGRESS.md`, `DECISIONS.md`, `BLOCKERS.md`, `VALIDATION.md`, and `CHANGELOG.md`.  
**Consequences:** State is always synchronized with git commits and disk state; any agent session can resume accurately.

---

## Decision 002: Backend Runtime & Framework Selection
**Date:** 2026-10-05  
**Status:** ACCEPTED  
**Context:** ADR-002 mandates Node.js + TypeScript modular monolith. Framework selection was left free. Need high performance, strong type safety, OpenAPI generation, fast startup, and native validation schema support.  
**Decision:** Use Fastify with TypeScript for the API process and a dedicated worker loop. Use Zod for schema validation across API boundaries and tool contracts.  
**Why:** Fastify is lightweight, provides fast request handling, has built-in encapsulation mechanisms matching modular monolith boundaries, and pairs cleanly with Zod.  
**Alternatives Considered:** Express (older, slower, untyped by default), NestJS (heavy reflection, excessive boilerplate for rapid iteration).

---

## Decision 003: Database Abstraction & Driver
**Date:** 2026-10-05  
**Status:** ACCEPTED  
**Context:** ADR-004 mandates PostgreSQL with pgvector readiness, strict relational integrity, and defense-in-depth row-level tenancy enforcement.  
**Decision:** Use a clean repository layer backed by `pg` (node-postgres) with migration tooling (`node-pg-migrate` or clean SQL migration runner). For flexible testing, allow an in-memory SQL/Postgres-compatible driver (e.g. `pg-mem` or Docker Postgres) so unit and integration tests run deterministically and fast in CI and local dev without external services if needed, while maintaining identical SQL constraints.  
**Why:** Direct SQL/query-builder clarity prevents ORM impedance mismatch with append-only temporal queries and pgvector functions.

---

## Decision 004: Unit Registry Precision Architecture
**Date:** 2026-10-05  
**Status:** ACCEPTED  
**Context:** ADR-021 requires canonical normalization at boundaries with original value, unit, and precision preserved to prevent floating-point drift (e.g., 82 kg displayed as 82.0000001 kg).  
**Decision:** Store canonical values as scaled integers or high-precision decimals (`NUMERIC(12, 4)` in SQL), accompanied by `original_value` (numeric), `original_unit` (text), and `input_precision` (integer count of decimals) on all observation records.  
**Consequences:** Round-trip fidelity is mathematically guaranteed.
