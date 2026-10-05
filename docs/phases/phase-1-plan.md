# Phase 1 Implementation Plan: Foundation, Identity & Health Data

## 1. Objectives
Phase 1 builds the foundational core that cannot be retrofitted:
1. Establish identity, sessions, rotating refresh tokens with reuse detection, and consent tracking.
2. Enforce double-layer user isolation: application-level ownership enforcement and PostgreSQL Row-Level Security (RLS).
3. Implement the append-only health observation storage model with mandatory provenance, epistemic classes, and supersession/void lifecycle.
4. Establish the Unit Registry with canonical normalization, original value preservation, and round-trip fidelity.
5. Create the Measurement Type Catalog with validation bounds and dimension mapping.
6. Build user profiles with versioned calculation-relevant attributes.
7. Implement content-free, privacy-preserving audit logging.
8. Establish privacy export and delete contracts across all Phase 1 domains.
9. Build the bilingual localization infrastructure (Arabic RTL and English LTR message catalogs, codes-not-labels).
10. Setup verification infrastructure: unit tests, real PostgreSQL integration tests, RLS bypass attack tests, architecture tests, and secret scanning.

---

## 2. Modules & Architecture
- `backend/src/core/database`: PostgreSQL connection pool, migration runner, RLS transaction context runner (`withUserContext`).
- `backend/src/core/units`: Unit Registry, dimension registry, canonical converters, round-trip precision formatting.
- `backend/src/core/security`: Argon2id password hashing, JWT token issuer/verifier, refresh token family rotation, input sanitization.
- `backend/src/core/localization`: Bilingual message catalogs, locale formatting, digit system preferences.
- `backend/src/modules/identity`: User entity, credential entity, session/refresh-token rotation, consent management, age gate (18+).
- `backend/src/modules/audit`: Append-only audit logger (action, actor, correlation ID, content-minimized).
- `backend/src/modules/measurements`: Measurement type catalog, observations repository, provenance linkage, supersession and voiding logic.
- `backend/src/modules/profile`: Profile entity, history of calculation-relevant attributes (height, sex-for-calculation, DOB, activity level).
- `backend/src/modules/privacy`: Export contract and deletion contract orchestrators.
- `mobile`: Flutter foundation with Riverpod, bilingual localization (ARB/Intl, RTL/LTR), and theme tokens derived from `logo.png`.

---

## 3. Implementation Slices
1. **Slice 1: Core Tooling & Verification Skeleton**
   - Package setup (`backend/package.json`, `tsconfig.json` with strict mode, `vitest` test runner).
   - Database schema & migrations: users, credentials, sessions, consent, audit_logs, measurement_types, observations, provenance_records, profiles, profile_history.
   - PostgreSQL RLS policies ensuring tenant isolation.
2. **Slice 2: Unit Registry & Measurement Type Catalog**
   - Canonical units (mass: kg, length: cm, percentage: ratio, time: seconds, energy: kcal).
   - Conversions (lb, st, oz, in, ft, m, kJ) preserving entered value, unit, and precision.
   - Catalog definitions for initial core measurements (weight, body fat %, muscle mass, visceral fat, bone mass, waist circumference, hip circumference, chest circumference, height, BMI).
3. **Slice 3: Identity, Sessions & Double Isolation**
   - Registration with 18+ age gate and explicit consent.
   - Authentication with Argon2id and JWT access/refresh token pairs.
   - Session family revocation on refresh token reuse.
   - Fastify authentication hooks injecting authenticated user context.
   - Application-level ownership validator + PostgreSQL RLS test suite.
4. **Slice 4: Append-Only Observations & Mandatory Provenance**
   - Atomic observation + provenance insertion.
   - Epistemic classes (`measured`, `calculated`, `estimated`, `asserted`).
   - Correction via supersession (new observation links to old; old marked superseded).
   - Voiding logic (marked voided; never physically deleted outside privacy purge).
5. **Slice 5: Profile & Calculation Attributes**
   - Profile management with historical attribute tracking for reproducibility.
6. **Slice 6: Audit, Privacy Export & Deletion Contracts**
   - Module export methods producing structured JSON payloads.
   - Module purge methods executing complete cascades.
   - Content-free audit trails for all mutations.
7. **Slice 7: Bilingual Localization & Mobile Foundation**
   - English and Arabic message catalogs.
   - RTL/LTR layout mechanics, number system switching (Western vs Arabic-Indic).
   - Flutter application skeleton with Riverpod state management and design tokens.
8. **Slice 8: Quality Gates & Verification**
   - Vitest unit, contract, and integration tests against real PostgreSQL.
   - Cross-user isolation attack tests.
   - Architecture boundary tests (dependency Cruiser / custom boundary rules).
   - Secret scanning test.

---

## 4. Exit Criteria Checklist
- [ ] Cross-user isolation tests are green (API layer and RLS layer).
- [ ] Application ownership enforcement is tested.
- [ ] Database RLS isolation is tested with real PostgreSQL.
- [ ] Provenance is mandatory at the data-layer level (cannot insert observation without provenance).
- [ ] Observation append-only behavior is verified (no UPDATE path for facts).
- [ ] Supersession/void behavior is verified.
- [ ] Unit round-trip tests are green.
- [ ] Arabic/English localization infrastructure is operational.
- [ ] RTL/LTR infrastructure is operational.
- [ ] Applicable security checks pass (password hashing, refresh token reuse detection).
- [ ] Applicable architecture tests pass.
- [ ] Applicable integration tests pass.
- [ ] Phase 1 report is complete with reproduction commands and actual evidence.
- [ ] EXECUTION_STATE.md is updated.
