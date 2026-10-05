# Phase 7 Plan: Production Hardening, Launch Readiness & Final Invariants Audit

**Phase:** Phase 7  
**Status:** COMPLETED  
**Author:** Principal Software Engineer  
**Reference:** `agent.md` §3, §6, §9; `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1) §8.1, §20, §21, §22, §24, §31, §32, §33, §34  

---

## 1. Objectives & Scope
The objective of Phase 7 is to transition Forma from an integrated feature-complete codebase to an uncompromisingly reliable, production-ready, launch-ready platform.

1. **Gate 11: Resilience, Fault Tolerance & Provider Degradation:**
   - Provider outage simulation: verify graceful degradation when AI providers are unavailable, timing out, or returning 5xx. The system must never crash or block core health tracking.
   - Database fault handling: verify that transaction failures cleanly rollback without orphan data or inconsistent snapshot state.
2. **Gate 12: Observability, Health Endpoints & Alerting:**
   - Production health probes:
     - `GET /health` (liveness check)
     - `GET /health/ready` (readiness check verifying database connectivity and configuration readiness)
     - `GET /health/live` (process liveness)
   - Structured JSON logging with automated redaction of secrets, tokens, passwords, and sensitive health values.
   - Prometheus-compatible or structured metrics for API request latencies, error counts, and AI gateway token budgets.
3. **Production Containerization & Deployment Infrastructure:**
   - Production-grade multi-stage `backend/Dockerfile` with non-root user (`nodejs`/`forma`), security hardening, and dumb-init/tini process supervision.
   - Production Docker Compose (`docker-compose.prod.yml`) with health checks, resource constraints, and isolated networks.
   - Updated GitHub Actions CI workflow verifying the entire test matrix, linter, typechecker, architecture tests, and automated secret scan.
4. **Architectural Invariants & Quality Gates Audit (Blueprint §31 & §32):**
   - Verification of all 15 Blueprint §32 Invariants:
     1. AI has no direct DB access.
     2. No AI value enters health record without receipt-backed confirmation.
     3. Facts are never overwritten (append-only + supersession).
     4. Calculations and safety rules live in pure code.
     5. Every value has provenance and confidence.
     6. Double user isolation (app + DB RLS across all 24 tables).
     7. Canonical unit conversion with original preserved.
     8. Derived data lineage and snapshot invalidation.
     9. AI context assembled solely through Context Engine under budget.
     10. Content-free, secret-free AI traces.
     11. Estimates never represented as measurements.
     12. Domain modules never import provider SDKs.
     13. Health content never appears in logs by default.
     14. Every module implements export and delete contracts.
     15. Dashboard estimates/insights are precomputed and cached.
5. **Runbooks, Documentation & Zero-to-Running Readiness:**
   - Production `README.md` with tested commands.
   - Operational runbooks (`docs/runbooks/`): Incident response, Disaster recovery & restore drills, Key rotation, and Alert triage.

---

## 2. Milestones & Execution Steps

### Milestone 1: Health Probes, Metrics & Observability Endpoints
- Implement `GET /health`, `GET /health/ready`, `GET /health/live` in `backend/src/app.ts` with database ping and uptime report.
- Verify structured logging and PII sanitization filters.
- Write tests in `backend/src/eval/observability.test.ts`.

### Milestone 2: Resilience & Outage Drills (Gate 11)
- Create `backend/src/eval/resilience.test.ts`:
  - Simulate total AI provider failure (500/503/timeout): verify assistant reports graceful fallback without crashing.
  - Simulate database connection dropout: verify clean 503 Service Unavailable response on `/health/ready`.
  - Simulate transaction rollback on partial commit failure: verify atomic rollback of observations and provenance.

### Milestone 3: Production Docker & Multi-Stage Deployment
- Create `backend/Dockerfile` using multi-stage build:
  - Stage 1: Build & TypeScript compile.
  - Stage 2: Production runtime with non-root user, pruned node_modules, and dumb-init.
- Create `docker-compose.prod.yml` with health checks, environment variables, and restart policies.
- Verify Docker build locally.

### Milestone 4: Final Invariants & Quality Gates Audit Suite
- Create `backend/src/eval/invariants_audit.test.ts` formally verifying all 15 Blueprint §32 Invariants with automated assertions.
- Run complete test suite:
  - `npm test` across all backend suites
  - `npm run test:arch` (24 RLS tables)
  - `npm run typecheck` (`tsc --noEmit`)
  - `flutter test` across all mobile suites
  - `dart analyze`
  - `node scripts/secret-scan.js` (0 secrets)

### Milestone 5: Documentation, Runbooks & Launch Sign-off
- Create `docs/runbooks/INCIDENT_RESPONSE.md` and `docs/runbooks/BACKUP_AND_RESTORE.md`.
- Update `README.md` with complete, verified zero-to-running setup guide.
- Create `docs/phases/phase-7-report.md`.
- Update `docs/execution/EXECUTION_STATE.md`.
- Final commit and presentation.

---

## 3. Exit Criteria
- [x] Health and readiness probes (`/health`, `/health/ready`, `/health/live`, `/metrics`) implemented and tested.
- [x] Outage drills and resilience tests passing (Gate 11).
- [x] Observability and structured redaction tests passing (Gate 12).
- [x] Multi-stage production `Dockerfile` and `docker-compose.prod.yml` created and validated.
- [x] All 15 Blueprint §32 invariants explicitly verified in `invariants_audit.test.ts`.
- [x] 100% of all backend and mobile test suites passing with zero skipped tests.
- [x] `tsc --noEmit` and `dart analyze` pass with zero errors and zero warnings.
- [x] Secret scanner passes with zero secrets across the entire repository.
- [x] Zero mock data, zero hardcoded secrets, zero TODOs in production paths.
- [x] Operational runbooks and production `README.md` documented and verified.
