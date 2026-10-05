# PRODUCT_GAP_ANALYSIS.md — Forma

**Date:** 2026-10-05 · Based on `PRODUCT_DATA_TRACEABILITY.md` + `HARDCODED_DATA_FORENSIC_AUDIT.md` + blueprint (§9 journeys, §18 UX, §27 scope) recovered from git history.

## The core gap

The backend is genuinely rich: append-only observations with provenance/supersession, versioned goals, a real snapshot engine, SSE assistant with proposals/receipts, a real ingestion pipeline with dedup + conflict resolution, BYOK credential custody, GDPR export/purge. The Flutter shell touches most of it — but **several wired paths are silently broken**, **a layer of fabrication masks gaps**, and **entire user-facing capabilities (conversations, memories, drafts management, anomaly surfacing, audit trail, consent management, sessions) have no UI at all**.

## Gap clusters, prioritized

### P0 — Trust & correctness (fabrication + broken writes)
| # | Gap | Impact |
|---|---|---|
| 1 | **Fabricated health data path**: `syncProvider` POSTs fake `8540` steps; sync UI fakes connection state; export tile fakes success | Pollutes append-only record; fake UX |
| 2 | **Broken wired flows**: GoalModel parse crash on every goal response; `weight_gain` 400; goal status enum drift; supersede parse crash; provenance dialog passes obs.id → 404 + fabricated fallback; `isVoided` reads nonexistent field; chatStream double-saves; `windowDays` ignored server-side | User actions appear to work but corrupt/misreport state |
| 3 | **Extraction review is theater**: edits/approvals never persisted; discard never hits backend; commit ignores unchecks; receipt ID fabricated | User "review" does nothing — worst kind of fake |
| 4 | **P0 secrets**: BYOK master-key literal, JWT/DB defaults, real-PII seed script | Credential/auth compromise if deployed |
| 5 | Client fabrications: 30/25/45 macros labeled "calculated", `??` domain defaults, registration prefills, fake receipt messages, snapshot `'measured'`/`100%`/`moderately_active` fabrications | Violates epistemic-honesty invariant |

### P1 — Product completeness (data exists, user can't reach it)
| # | Gap | Value |
|---|---|---|
| 6 | **Connected Devices screen is pure theater** — no health plugin/permissions; blueprint §27.2 says wearables out of scope | Remove cleanly (keep or remove backend ingestion path — decision needed) |
| 7 | **Anomalies + data quality invisible**: detector runs, flags embedded in snapshot, client drops them; `metric_rollups`/`anomaly_flags` tables never written | Dashboard misses "what should I pay attention to" |
| 8 | **No visualization**: zero charts despite time-series everywhere; trends = bare numbers; period chips cosmetic (backend ignores window) | Progress/trends has no product value |
| 9 | **Measurement catalog bypassed**: `GET /types` + `listTypes()` unused; hardcoded 15/13-type lists; `height` unreachable; no bilateral support; no superseded/voided audit view | Incomplete health records |
| 10 | **Profile gaps**: `experience_level`/`constraints`/`preferences` never shown; `profile_history` endpoint+repo dead; DOB immutable forever; no unit prefs UI | Profile ≠ real user state |
| 11 | **Consent + sessions invisible**: no view/withdraw for consents (`withdrawn_at` never written); no session list/revoke; no password change | Account management incomplete |
| 12 | **Assistant surface**: conversation list/history/delete + memories CRUD all BACKEND_ONLY; pending drafts never resumable | "Assistant" is ephemeral chat only |
| 13 | **Settings**: provider select silent-no-ops without credential; no model picker; language toggle clobbers numeral pref; export is clipboard-only | Settings half-wired |

### P2 — Hardening (from prior audit, fold in opportunistically)
Secure token storage, CORS allowlist, EXIF claim, error-propagation instead of catch→null, ~70 localized strings, redaction/audit gaps, `test-connection` bypass removal, provider list derived from adapters, plausibility/enum single-sourcing.

## What the dashboard SHOULD answer (blueprint §18.1) vs today
- Today: body status, goal, "trends" (broken windows), energy targets, recent measurements — all snapshot-driven. ✓ exists but with fabricated badges/fallbacks.
- Missing widgets: **anomalies/important changes** (l10n ready), **pending extraction drafts**, **AI insight** (precomputed), **prompts/reminders**.

## Proposed information architecture
Keep hub model (no router exists). Dashboard = snapshot+anomalies+drafts+sparkline trends. Health Records (history sheet → full screen, catalog-driven types, audit-trail filter). Profile (full editable + history). Goals (list + versions). Assistant (+conversations/memories). Settings (fixed sections + consent + sessions + model picker). **Remove SyncScreen**; multimodal review fixed to persist edits.

## Decisions needed from user (before implementation)
1. **Sync/wearables**: blueprint defers them; no real integration possible without new native work → remove UI. Keep backend ingestion endpoints as the "prepared path," or remove routes too?
2. **Charts**: add `fl_chart` (or similar) dependency for trend visualization? No chart lib exists today.
3. **Scope/sequencing**: confirm P0-then-P1 ordering; whether consent-view/session-list/password-change backend endpoints are in scope (they're missing, not just unexposed).
4. **Secrets**: making `ENCRYPTION_MASTER_KEY`/`JWT_*`/`DATABASE_URL*` required will break boot without `.env` — acceptable for this dev project? `.env.example` becomes names-only.
