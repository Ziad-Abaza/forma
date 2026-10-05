# ADR 0001: Repository Structure — Unified Modular Monorepo

## Status
Accepted

## Context
Forma consists of two primary application components:
1. A backend service (Node.js + TypeScript) operating as a modular monolith with unified domain logic, database migrations, and two operational entrypoints (API process and Worker process).
2. A mobile application (Flutter / Dart) targeting iOS and Android with strict offline tolerance, bilingual presentation (Arabic RTL / English LTR), and contract-aligned API consumption.

In addition, the system requires shared contract definitions (OpenAPI/Zod schemas), architecture test suites, end-to-end integration tests, database migrations, CI workflows, and persistent execution state.

The repository must support:
- Atomic commits across contracts, backend implementations, and client updates.
- Centralized CI/CD running linting, type checks, unit/integration/architecture tests, and secret scans.
- High developer velocity without multi-repository version synchronization friction.

## Decision
We choose a **Unified Monorepo** structure:
- `/backend`: Node.js / TypeScript modular monolith (API + worker processes, migrations, PostgreSQL persistence, Fastify server).
- `/mobile`: Flutter application (iOS and Android, Riverpod architecture, full Arabic/English localization).
- `/docs/adr`: Architectural Decision Records.
- `/docs/phases`: Phased implementation plans, quality gates, and completion reports.
- `/docs/execution`: Resumable execution state tracking (`EXECUTION_STATE.md`).
- `/scripts`: Development and verification automation (secret scanning, architecture validation).
- `/.github/workflows`: CI pipeline running lint, typecheck, tests, architecture checks, and secret scans.
- `docker-compose.yml`: Development infrastructure (PostgreSQL 18).

## Consequences
- **Positive:** Single commit history preserves atomic alignment between API contracts, database migrations, backend services, and mobile UI.
- **Positive:** Simplified CI configuration and automated verification.
- **Trade-off:** Requires disciplined directory separation and tooling boundaries, enforced by CI architecture tests.
