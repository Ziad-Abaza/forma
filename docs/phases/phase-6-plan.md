# Phase 6 Implementation & Hardening Plan
## Security, Red-Team Hardening, Integration Seams, and Comprehensive Evaluation

**Author:** Antigravity AI (Principal Software Engineer)  
**Date:** October 5, 2026  
**Status:** IN_PROGRESS  
**Authoritative References:** `agent.md` §1–§4; `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1) §10.6, §10.8, §11.9, §12.8, §14.2, §21, §24, §28.1, §31.1, §31.2, §32.

---

### 1. Phase 6 Objectives

The primary objective of Phase 6 is to validate, stress-test, and harden the entire Forma platform against all 15 Quality Gates (§31.1) and implement the contractual integration seams for external device and health data sync (§28.1).

Specifically:
1. **Device & Health Data Ingestion Seams (§28.1):**
   - Implement Database Migration 009: `integration_connections` and `import_batches` with strict PostgreSQL Row-Level Security (`ENABLE` and `FORCE RLS`) and grants to `forma_app`.
   - Build `IntegrationSyncService` providing idempotent deduplication (deterministic hash on external record identifiers), unit conversion to canonical catalog metrics, and deterministic source precedence conflict resolution (`measured` direct device > `imported` summary > `manual` assertion > `estimated`).
2. **Security & Red-Team Adversarial Hardening (Gates 1, 2, 8):**
   - Automated injection test harness: test prompt injections (direct, indirect via image metadata and user records), jailbreak attacks, credential exfiltration, and tool parameter tampering.
   - Double-isolation penetration tests: verify that no cross-user data leak is possible at either the application layer or database RLS layer across all 23 database tables.
3. **End-to-End Privacy Verification (Gate 7, Invariant 14):**
   - Verify complete GDPR machine-readable data export covering 100% of user data domains.
   - Verify cascading account purge: zero residual records across all tables, disk storage unlinking, and trace scrubbing.
4. **AI Evaluation Hardening Matrix (Gate 3, 14, §31.2):**
   - Expand the bilingual (Arabic & English) golden evaluation dataset.
   - Verify numeric fidelity (numbers in assistant prose strictly match tool outputs).
   - Verify AI Data Budget enforcement and content-free trace scrubbing.
5. **Mobile Sync & Security Management UI:**
   - Flutter `SyncScreen` with device connection management, sync status badges, conflict resolution indicators, and export/delete controls.
   - Complete bilingual Arabic RTL and English LTR parity.

---

### 2. Module Breakdown & Deliverables

#### 2.1 Backend Modules
- `backend/src/core/database/migrations/009_integrations_sync_schema.sql`
- `backend/src/modules/integrations/contracts.ts`
- `backend/src/modules/integrations/sync.ts`
- `backend/src/modules/integrations/index.ts`
- `backend/src/eval/red_team.test.ts`
- `backend/src/eval/sync.test.ts`
- `backend/src/eval/privacy_e2e.test.ts`
- `backend/src/eval/eval_matrix.test.ts`

#### 2.2 Mobile Modules
- `mobile/lib/presentation/screens/sync_screen.dart`
- `mobile/lib/l10n/app_en.arb` & `app_ar.arb` (sync & privacy tokens)
- `mobile/test/sync_screen_widget_test.dart`

---

### 3. Exit Criteria
- [ ] 009 migration applied to `forma_dev` and `forma_test` with verified RLS on all 23 tables.
- [ ] Idempotent deduplication and conflict resolution verified by test.
- [ ] Red-team adversarial attacks (injection, jailbreaks, parameter tampering) neutralized with 100% pass rate.
- [ ] GDPR export and cascading account purge verified end-to-end with 0 leaked or orphaned rows.
- [ ] AI eval matrix passes with 100% numeric fidelity and zero content leakage in traces.
- [ ] Flutter analysis clean (`dart analyze` 0 issues) and widget tests pass (`flutter test`).
- [ ] Automated secret scanner clean (0 secrets).
- [ ] `docs/phases/phase-6-report.md` written and committed atomically.
