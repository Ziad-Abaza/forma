# PROJECT_STATE.md — Forma Product-Completeness Remediation

**Session started:** 2026-10-05
**Task:** Full forensic assessment + remediation to make the app expose the real capabilities/data of the backend (DB → Backend → API → Flutter → UI → persistence).
**Predecessor session:** "Forma zero-tolerance hardcoded data remediation" — produced `docs/implementation/HARDCODED_DATA_FORENSIC_AUDIT.md` (56 findings: 6 CRITICAL, 20 HIGH, 19 MEDIUM, 8 LOW, 3 INFO). **No remediation code changes were made** — working tree is clean at commit `557b747`; the audit is read-only output.

---

## 1. Repository Structure (verified)

- `backend/` — Node.js 22 + TypeScript + Fastify modular monolith. Modules: `identity`, `profile`, `measurements`, `goals`, `calculations`, `analytics`, `assistant`, `ai` (gateway/context/safety/tools/budget/traces), `multimodal`, `integrations`, `privacy`, `audit`. 12 SQL migrations under `src/core/database/migrations/`. Tests in `src/eval/` + per-module `*.test.ts`.
- `mobile/` — Flutter 3.x + Riverpod. `lib/` has 52 Dart files: `core/` (theme, api_client, env_config, token_storage, preferences), `modules/{auth,profile,measurements,goals,analytics,assistant,ai,multimodal,integrations,privacy}/` (models + repositories + a few screens), `presentation/screens/` (dashboard 73KB monolith, assistant, settings, sync, multimodal_review) and `presentation/widgets/chat/`. 9 test files.
- `docs/` — **gitignored** (`/docs/` in `.gitignore`). Contains only `implementation/HARDCODED_DATA_FORENSIC_AUDIT.md`. Older tracked docs (AGENT.md, PRODUCT_ARCHITECTURE_BLUEPRINT.md, phase plans) were deleted from git in commits `7e58c55` and `557b747`; recoverable via `git show`.
- `scripts/` — gitignored; icon generation, secret-scan, journey verification scripts.
- `.notebook/` — assets/tmp.

## 2. Verified Baseline (commands actually run)

| Command | Result |
|---|---|
| `backend: npm run typecheck` | PASS (0 errors) |
| `backend: npm test` (vitest) | **22 files / 184 tests ALL PASS** — incl. real PostgreSQL 18 integration tests (migrations auto-applied; a live local DB exists) |
| `mobile: flutter analyze` | **0 issues** |
| `mobile: flutter test` | **54 tests ALL PASS** (note: some tests lock in fake behavior, e.g. sync_screen test asserting fabricated state — see audit HC-007) |

## 3. Data / API Surface (verified)

**26 tables:** users, credentials, sessions, consents, profiles, profile_history, measurement_types (17 seeded types: weight, 6 composition, 8 circumference incl. 4 bilateral, height, bmi-derived), provenance_records, observations (append-only, immutable-value trigger, supersede/void), audit_logs, goals, goal_versions, health_snapshots, metric_rollups, anomaly_flags, ai_traces, user_ai_credentials, conversations, conversation_messages, action_proposals, assistant_memories, media_artifacts, extraction_drafts, integration_connections, import_batches, sync_dedup_records.

**58 routes** in `backend/src/app.ts`: health×4, auth×5 (+preferences), profile×3, measurements×6, privacy×2, goals×5, calculations×6, analytics×3, assistant×8, ai config/credentials×5, multimodal×5, integrations×4.

## 4. Known Deficiencies (from prior audit — re-verification via traceability in progress)

- P0 secrets: BYOK AES key literal fallback (HC-001), JWT secret defaults (HC-002), DB passwords in code/migration/compose (HC-003), real-PII seed script (HC-005).
- Fake data reaching production: fabricated `step_count=8540` sync record (HC-004), fake connect/sync UI state (HC-007), confidence-1.0 empty extraction drafts (HC-006), client-fabricated macros/receipts (HC-008/015/044), magic-substring test-connection bypass (HC-009).
- Connected devices feature is theater — no real HealthKit/Health Connect integration exists in Flutter (no `health` plugin in pubspec).
- ~70 unlocalized strings; enum drift `extra_active` vs `extremely_active`; error-swallowing repositories.

## 5. Blockers / Notes

- `docs/` is gitignored → this file lives at repo root so sessions can read/write it.
- `AGENT.md` / `PRODUCT_ARCHITECTURE_BLUEPRINT.md` deleted from HEAD; recoverable from git history if requirements need re-checking.
- `backend/.env` and `mobile/.env` exist locally (gitignored) — local dev DB is up.

## 6. Progress Log

- [x] Phase 0 baseline: structure mapped, all tests/builds verified green.
- [x] Phase 1 traceability matrix — `PRODUCT_DATA_TRACEABILITY.md` written (5 domain audits complete; ~15 COMPLETE / ~15 PARTIAL / ~8 BROKEN / ~9 MOCKED / ~24 BACKEND_ONLY-or-DATABASE_ONLY capabilities).
- [x] Phase 2 gap analysis — `PRODUCT_GAP_ANALYSIS.md` written; P0 (fabrication+broken writes+secrets), P1 (unexposed capabilities incl. SHOULD_REMOVE sync screen), P2 (hardening).
- [x] Phase 3 — DECISIONS APPROVED: (1) sync UI + backend routes removed, tables kept for GDPR; (2) fl_chart approved; (3) new endpoints in scope; (4) required-env secrets enforced.
- [x] Phase A sync removal — SyncScreen, integrations repo/module/routes, sync.test.ts deleted; privacy_e2e re-seeded via SQL; IntegrationsPrivacyContract retained. Backend 182 tests PASS, dart analyze clean, flutter test 44 PASS.
- [x] Phase A3/A4 fabrications — client: macro 30/25/45 fallback removed, fake receipt IDs removed (3 sites), register prefills + AI-consent default-on fixed, model ??-fabrications stripped. Backend: snapshot honest sufficiency (no fabricated activityLevel/weeklyRate/epistemicClass/measuredSharePct), windowDays filter real, availableProviders derived from adapters, orchestrator double-save + done-key fixed, commitDraft real receipt.
- [x] Phase B partial — goal status enum aligned (achieved/abandoned; route uses GoalStatusSchema), GoalModel rewritten to contract, supersede parse fixed, provenance via provenance_id, multimodal edits persist via PUT /drafts/:id/fields, real discard, commit errors surfaced.
- [x] Phase C — already complete in tree: config requires JWT/ENCRYPTION/DATABASE env (config.test.ts), migrate.ts parameterizes FORMA_APP_DB_PASSWORD, seed quarantined (synthetic + FORMA_SEED_CONFIRM), secret-scan 275 files PASS.
- [x] Phase D backend — NEW routes: GET/DELETE auth/sessions(+logout-all), POST auth/change-password, GET privacy/consents + withdraw, GET goals/:id/versions, GET multimodal/drafts; AI consent enforced on /assistant/chat (403 AI_CONSENT_REQUIRED). typecheck + 182 tests PASS.
- [x] Phase E/F — Flutter repos + UI: sessions/consents/password/model-picker in settings; catalog-driven measurement pickers; fl_chart trend (raw+EMA series); anomalies/data-quality + pending-drafts dashboard cards; goal versions sheet; profile DOB/experience/constraints/history; assistant conversations + memories screen.
- [x] Phase G — flutter_secure_storage v11, CORS allowlist verified, new-UI strings localized EN/AR (~35 older literals remain, documented).
- [x] Phase H — FINAL_PRODUCT_COMPLETENESS_AUDIT.md written. Final: backend 185 tests PASS / typecheck PASS / build PASS / arch 4 PASS; mobile analyze clean / 44 tests PASS; secret-scan PASS (275 files).