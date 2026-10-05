# PRODUCT_DATA_TRACEABILITY.md — Forma

**Date:** 2026-10-05 · **Method:** 5 parallel domain audits (read-only, file:line-verified) + prior `docs/implementation/HARDCODED_DATA_FORENSIC_AUDIT.md` (56 findings) + blueprint recovered from git (`557b747^:PRODUCT_ARCHITECTURE_BLUEPRINT.md`).

**Status legend:** COMPLETE · PARTIAL · BACKEND_ONLY · DATABASE_ONLY · FRONTEND_ONLY · MOCKED · BROKEN · UNUSED · SHOULD_REMOVE · NEEDS_REDESIGN

---

## 1. Measurements / Health Records

| Capability | DB | Backend | API | Flutter repo | UI | Status |
|---|---|---|---|---|---|---|
| Type catalog (17 types) | `measurement_types` 002/011 | service | `GET /types` | `listTypes()` exists | **pickers hardcode 15/13 types; `height` unreachable** | BACKEND_ONLY (API uncalled) + PARTIAL UI |
| Record observation | `observations` | service+provenance | `POST /observations` | `recordObservation` | add dialog | COMPLETE |
| Per-type history | `observations` | repository | `GET /observations` | `getObservations` | history sheet | COMPLETE (active-only; no `status` filter sent) |
| Supersede (correct) | supersession cols | service | `POST /:id/supersede` | `supersedeObservation` | history sheet | **BROKEN** — repo reads `resp['observation']`, backend returns `{newObservation, previousObservation}` → crash after success |
| Void | `status`, `voided_at` | service | `POST /:id/void` | `voidObservation` | history sheet + provenance dialog | COMPLETE |
| Provenance detail | `provenance_records` | service | `GET /provenance/:id` | `getProvenance` | info dialog | **BROKEN** — sends `obs.id`, endpoint wants `provenance_id` (model never parses it) → guaranteed 404 → fabricated `'manual_entry'`/`'user'` shown |
| Epistemic class | on `provenance_records` | — | not in observation payload | `?? 'measured'` | badge | **MOCKED** — always "Measured" (snapshot hardcodes too, snapshot.ts:168) |
| `observed_at`, `time_zone`, `quality_flags`, `input_precision`, `status`, `supersedes`, `void_reason` | ✓ | returned | ✓ | **dropped by model** | not shown | DATABASE→UI drop |
| `isVoided` flag | `status` col | sends `status` | ✓ | reads nonexistent `is_voided` → always false | badge dead code | BROKEN |
| Bilateral laterality (4 types) | `measurement_types.laterality` | no side column on `observations` | no field | no field | no control | DATABASE_ONLY + missing schema |
| Audit-trail view (superseded/voided) | ✓ | `status` filter exists | `?status=` | never passes filter | no UI | BACKEND_ONLY |

## 2. Profile / Identity / Goals

| Capability | DB | Backend | API | Flutter | UI | Status |
|---|---|---|---|---|---|---|
| Register/login/refresh/logout | users/credentials/sessions | identity svc (rotation + reuse detection) | 5 routes | auth repo + api_client | login/register | COMPLETE |
| Profile height/sex/activity | `profiles` + `profile_history` | service (history-tracked) | GET/PUT `/profile` | repo | profile screen | COMPLETE |
| `date_of_birth` | ✓ | ✓ | GET only — PUT omits it | displayed | **no edit path anywhere** | PARTIAL |
| `experience_level` | ✓ | ✓ | GET/PUT | repo param exists | never shown/sent | BACKEND_ONLY |
| `constraints` | ✓ | ✓ | GET/PUT | — | — | BACKEND_ONLY |
| `preferences` JSONB (units…) | ✓ | consumed by snapshot | PUT | — | — | BACKEND_ONLY |
| `profile_history` | ✓ | ✓ | `GET /profile/history` | `getHistory` dead method | never displayed | BACKEND_ONLY + UNUSED |
| Consents (3 types) | `consents` | written at register | none (export only) | checkboxes | register only; **no view/revoke**; `withdrawn_at` never written | PARTIAL + BACKEND_ONLY |
| Sessions/devices | `sessions` | reuse-detect internals | **no list/revoke endpoint** | — | — | DATABASE_ONLY |
| Password change | credentials write-once | none | none | — | — | MISSING |
| `onSessionExpired` | — | — | — | empty stub providers.dart:26 | zombie auth state | BROKEN |
| Create goal | goals+goal_versions | service | `POST /goals` | `createGoal` | dashboard dialog | **BROKEN** — `GoalModel.fromJson` reads `type`/flat `targetValue`, backend returns `goalType`/`currentVersion.*` → throws on every 201; UI offers `weight_gain` not in contract enum → guaranteed 400 |
| Goal progress view | — | snapshot `sections.goal` | `/analytics/snapshot` | parsed | goal card | COMPLETE (via snapshot) |
| Goal versions list | `goal_versions` | — | **no list endpoint** | — | — | BACKEND_ONLY (missing API) |
| Goal status change | `goals.status` | service | `PATCH /:id/status` | wired | dropdown | **BROKEN** — UI sends `completed`/`archived`, contract is `active`/`achieved`/`abandoned`/`superseded` |
| `listGoals`/`getPrimaryGoal` | — | — | ✓ | dead methods | — | UNUSED |

## 3. Analytics / Calculations / Dashboard

| Capability | DB | Backend | API | Flutter | UI | Status |
|---|---|---|---|---|---|---|
| Health snapshot | `health_snapshots` | snapshot.ts (recompute+upsert) | `GET /analytics/snapshot` | SnapshotModel | 5 dashboard cards | COMPLETE (see drops) |
| Snapshot fields dropped by client | — | `identityLite`, `activityLevel`, `anomalies[]`, `dataQuality`, sufficiency flags, `energy.isRefused` | sent | **parsed-out** | not rendered | PARTIAL |
| Snapshot fabrications | — | `activityLevel 'moderately_active'` default, `weeklyRate||0.5`, `epistemicClass 'measured'`, `measuredSharePct 100` | — | — | badges/numbers inherit | MOCKED (backend) |
| Trends | observations | trends.ts | `GET /trends/:typeCode` | repo + provider | trends card | **BROKEN** — `windowDays` never used to filter; all 4 chips return identical data |
| `metric_rollups` | table exists | **never written** | none | — | — | DATABASE_ONLY |
| `anomaly_flags` | table exists | detector exists but **never persisted**; only embedded in snapshot JSONB | inside snapshot | dropped by model | l10n strings exist, dead | DATABASE_ONLY + BACKEND_ONLY |
| `/calculations/*` ×6 (bmi/bmr/tdee/calorie-targets/macros/timeline) | — | engine.ts | 6 routes, **no auth** | **zero calls** | — | UNUSED / BACKEND_ONLY |
| Macro targets | — | engine.ts:338 | via snapshot | parsed | macro bars | PARTIAL — client fabricates 30/25/45 fallback (:841) with different formula than backend |
| Charts | — | — | — | **no chart package** | numbers only | NEEDS_REDESIGN (no visualization anywhere) |
| Pending-drafts prompt | extraction_drafts | — | `GET /drafts/:id` exists | — | none | MISSING (blueprint §18.1 widget) |

## 4. Assistant / AI / Multimodal

| Capability | DB | Backend | API | Flutter | UI | Status |
|---|---|---|---|---|---|---|
| Chat (SSE) | conversations/messages | orchestrator | `POST /assistant/chat` | stream parser | assistant screen | COMPLETE — **2 latent bugs:** `chatStream` double-saves user msg (orchestrator:477+542); `done` sends `fullText`, client reads `content` |
| Metrics/suggestions/evidence/proposal blocks | — | blocks.ts | SSE events | models | grid/chips/sources/proposal cards | COMPLETE |
| Proposal confirm → receipt | `action_proposals.receipt` | proposals.ts (server receiptId) | confirm/decline | repo | card + banner | PARTIAL — works, but UI composes fake receipt message, never shows real `receiptId`, no idempotencyKey |
| Conversation list/history/delete | ✓ | orchestrator | 3 routes | **none** | — | BACKEND_ONLY |
| Memories CRUD | `assistant_memories` | memory.ts | 3 routes | **none** | — | BACKEND_ONLY |
| AI config (provider/models) | `user_ai_credentials` | byok+registry | `GET /ai/config` | repo | settings | PARTIAL — `availableProviders` hardcoded literal; **'anthropic' selectable w/o adapter**; models returned but no model picker |
| BYOK store/delete/test | encrypted col | AES-GCM | 3 routes | repo | settings | COMPLETE — except magic test bypass (app.ts:644) + **P0: master-key literal fallback (HC-001)** |
| `PATCH /ai/preferences` | is_active | byok | ✓ | repo | dropdown | PARTIAL — silent no-op when provider has no stored credential |
| Upload→extract→draft | media_artifacts/extraction_drafts | pipeline+extractor | 5 routes | repo | review screen | PARTIAL — extractor swallows provider failure → confidence-1.0 empty draft + falsified trace (HC-006) |
| **Draft field edits/approvals** | extracted_fields | `PUT /drafts/:id/fields` | ✓ | method exists, **never called** | local-only toggles | **BROKEN** — commit ignores every user edit |
| Draft commit receipt | draft+observations | commitDraft | ✓ | repo | screen | MOCKED — backend returns no `receipt`; UI fabricates `rcpt_*` ID |
| Draft discard/resume | status | 2 routes | ✓ | methods exist, uncalled | local-only | BACKEND_ONLY / FRONTEND_ONLY |
| `ai_traces` | ✓ | emit | **no read route** | — | — | DATABASE_ONLY |

## 5. Integrations / Privacy / Settings / Platform

| Capability | DB | Backend | API | Flutter | UI | Status |
|---|---|---|---|---|---|---|
| `integration_connections` | ✓ | connect=plain upsert (no OAuth/scopes enforcement); provider NOT Zod-validated | 4 routes | repo | sync screen | **MOCKED** — fake connected state, dead `loadConnections`, local toggle regardless of API |
| `POST /sync` ingestion | import_batches, dedup | real: dedup hash, catalog+unit validation, ±120s conflict supersession | ✓ | `syncProvider` | "Sync" taps | **MOCKED** — client POSTs fabricated `step_count=8540` 'measured' record into append-only record |
| Real device bridge (HealthKit/Health Connect) | — | — | — | **no health plugin, no permissions, no MethodChannel** | — | **SHOULD_REMOVE** (blueprint §27.2: wearables out of scope) |
| `import_batches`/`sync_dedup_records` read | ✓ | written | **no GET routes** | — | — | DATABASE_ONLY |
| Privacy export | all modules | orchestrator | `GET /privacy/export` | repo | settings dialog (SelectableText + clipboard) | PARTIAL — no file/share; **sync-screen copy discards result + always shows success (MOCKED)** |
| Account purge | all tables | purge + system ctx | `DELETE /privacy/account` | repo | settings + sync dup | COMPLETE — but no re-auth/grace period; `audit_logs` orphaned |
| Settings controls (11) | mixed | — | preferences PATCH | — | settings screen | mostly real — **bug:** language toggle force-overwrites numeral-system pref (HC-042) |
| `PATCH /auth/preferences` | users.locale/numeral | identity | ✓ | providers (fire-and-forget, swallow) | toggles | COMPLETE-ish |
| Token storage | — | — | — | **plaintext SharedPreferences** | — | NEEDS_REDESIGN (HC-011) |
| Cleartext HTTP / ATS off / debug release signing | — | — | — | manifest/plist/gradle | — | NEEDS_REDESIGN (HC-023) |
| Wildcard credentialed CORS, SSE `ACAO:*` | — | app.ts | — | — | — | NEEDS_REDESIGN (HC-010) |
| Secret defaults (BYOK key, JWT×2, DB pw×2, seed PII+password) | — | config/migrate/003/seed/.env.example | — | — | — | **P0 — MOCKED/FALLBACK secrets (HC-001..005)** |

## 6. Cross-cutting

- **~70 unlocalized literals** incl. AI-bound prompts + persisted rationale strings; 7 duplicated ARB keys (HC-022/037/053).
- Error-swallowing repos/`catch(_){}` convert failures into fake empty states (HC-025/051).
- `??` domain fabrication: height `175.0`, confidence `0.9`, `'measured'`, `1000.0`, `'weight_body'`, `DateTime.now()` (HC-045/046).
- Register prefills DOB/height + AI-consent default-ON (HC-014).
- Enum drifts: activity `extra_active` vs `extremely_active` (breaks TDEE); goal status `completed/archived` vs `achieved/abandoned/superseded`.

**Counts:** COMPLETE ~15 · PARTIAL ~15 · BACKEND_ONLY ~14 · DATABASE_ONLY ~10 · BROKEN ~8 · MOCKED ~9 · UNUSED ~6 · SHOULD_REMOVE 1 · NEEDS_REDESIGN ~6
