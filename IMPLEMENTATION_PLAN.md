# IMPLEMENTATION_PLAN.md — Forma Product-Completeness Remediation

**Date:** 2026-10-05 · **Spec sources:** task brief + `PRODUCT_DATA_TRACEABILITY.md` + `PRODUCT_GAP_ANALYSIS.md` + `HARDCODED_DATA_FORENSIC_AUDIT.md` + blueprint §9/§18/§27 (git `557b747^`).

**Approved decisions:** (1) remove sync UI + backend routes/module, keep tables; (2) add `fl_chart`; (3) new endpoints in scope (consents, sessions, password, goal-versions, drafts list); (4) secrets required-env, fail closed.

**Order:** P0 fabrication → P0 broken flows → secrets → new endpoints → Flutter models/repos → UI/UX → l10n/hardening → validation + final audit.

---

## A. Eliminate fabrication reaching production

- **A1 Remove sync feature (Flutter):** delete `sync_screen.dart`, `integrations_repository.dart`, dashboard sync nav button + `SyncScreen` import, `integrationsRepositoryProvider`, `sync_screen_widget_test.dart`, SyncScreen cases in `responsive_ui_test.dart`, sync-only l10n keys.
- **A2 Remove sync (backend):** delete 5 `/integrations/*` routes (app.ts:732-760), `modules/integrations/{sync,contracts}.ts`, `eval/sync.test.ts`; reduce `modules/integrations/index.ts` to `IntegrationsPrivacyContract` only; re-seed `privacy_e2e.test.ts` via direct SQL.
- **A3 Client fabrications:** remove 30/25/45 macro fallback → insufficient-data state; remove fabricated receipt IDs/messages (3 sites); strip `??` domain defaults in models (175.0, 0.9, 'measured', 'weight_body', DateTime.now(), 1000.0); registration prefills + AI-consent default-ON → off.
- **A4 Backend fabrications:** snapshot.ts — remove 'moderately_active'/'0.5'/'measured'/'100' defaults, propagate sufficiency honestly; extractor.ts — provider failure → `extraction_failed` draft + truthful trace (provider/model/outcome from routing); remove magic test-connection bypass (app.ts:644-650); 'anthropic' out of availableProviders (derive from registered adapters).

## B. Fix broken wired flows

- **B1 Goals:** fix `GoalModel.fromJson` (`goalType`, `currentVersion.{targetValue,startingValue,weeklyRate}`); align status actions to contract enum (achieved/abandoned); remove `weight_gain` option or map correctly; fix goal dialogs.
- **B2 Provenance:** parse `provenance_id` in ObservationModel; call `getProvenance(provenanceId)`; drop fabricated fallbacks.
- **B3 Supersede:** parse `resp['newObservation']`; invalidate providers; show result.
- **B4 isVoided/status:** parse `status` → isVoided; support `?status=all` audit view.
- **B5 Multimodal:** persist field edits via `PUT /drafts/:id/fields`; real `DELETE` discard; commit errors surface; backend `commitDraft` returns real receipt object; UI shows it.
- **B6 Trends:** `windowDays` actually filters observations (query + engine); chips produce different results.
- **B7 Assistant:** fix `chatStream` double-save; `done` key `fullText`↔`content`; send idempotencyKey on confirm; show server receiptId.
- **B8 Session expiry:** `onSessionExpired` → auth logout → login navigation.

## C. Secrets — required env, fail closed

- **C1:** `ENCRYPTION_MASTER_KEY` required in configSchema (64-hex, no default), injected into BYOKService; remove literal fallback.
- **C2:** `JWT_ACCESS_SECRET`/`JWT_REFRESH_SECRET`/`DATABASE_URL`/`DATABASE_URL_MIGRATIONS` required (no defaults); prod guard; `.env.example` names-only; migrate.ts + seed no DSN fallbacks.
- **C3:** `reset_and_seed.ts`: rewrite synthetic-only, env-gated, no real PII/password; or delete. Decide: keep as synthetic seed behind `ALLOW_SEED` guard.

## D. New backend endpoints

- **D1:** `GET /auth/sessions` (list own sessions w/ device_info/created/expires), `POST /auth/logout-all` (family revoke), `DELETE /auth/sessions/:id`.
- **D2:** `POST /auth/change-password` (verify current, argon2 rehash, revoke other sessions).
- **D3:** `GET /consents`, `POST /consents/:policyType/withdraw` (writes `withdrawn_at`, blocks AI features when ai_third_party_processing withdrawn).
- **D4:** `GET /goals/:id/versions` (full version history for a goal).
- **D5:** `GET /multimodal/drafts?status=` (list pending drafts — dashboard widget).
- **D6:** Persist `anomaly_flags` from AnomalyDetector during snapshot build; include `dataQuality`/`sufficiency` honestly. (metric_rollups: leave as prepared table, documented.)

## E. Flutter models/repos/state

- **E1 Models:** fix `??` fabrications; add `provenanceId`, `status`, `observedAt`, `qualityFlags`; SnapshotModel: parse `anomalies[]`, `dataQuality`, sufficiency, `activityLevel`, `identityLite`.
- **E2 Repos:** propagate errors; add sessions/consents/password/versions/drafts-list/memories/conversations methods.
- **E3 Providers:** catalog-driven `measurementTypesProvider`; new state for sessions/consents/versions/drafts/conversations/memories.

## F. UI/UX

- **F1 Dashboard:** anomalies/"important changes" widget (l10n exists), pending-drafts widget, honest epistemic badges, data-quality footer.
- **F2 Health Records:** catalog-driven pickers (is_user_enterable), include height, audit-trail (all-status) view, fixed provenance dialog, per-field epistemic display.
- **F3 Trends:** `fl_chart` line chart (raw + smoothed), real window filtering, in trends card + history detail.
- **F4 Goals:** fixed dialogs + goal list + versions screen.
- **F5 Profile:** experience_level + constraints editing, DOB edit path (backend PUT add), profile history view.
- **F6 Settings:** decouple locale↔numeral; consent section (view/withdraw); sessions section (list/revoke); password change; model picker; export via real dialog (clipboard OK, honest messaging).
- **F7 Assistant:** conversation list/delete UI; memories management screen.
- **F8 Registration:** no prefills; AI consent unchecked default.
- **F9 States:** loading/empty/error per blueprint §18.3 on all touched surfaces.

## G. Localization & hardening

- **G1:** Localize all new strings + known literals (staged; priority = user-facing + AI-bound).
- **G2:** `flutter_secure_storage` for tokens (migrate on upgrade).
- **G3:** CORS allowlist via config; remove SSE `ACAO:*`.
- **G4:** `usesCleartextTraffic`/ATS/debug-signing — keep dev-capable via env guard, document prod requirement.

## H. Validation & final audit

- New/updated tests: goal parse, supersede parse, provenance id, windowDays filtering, draft field persistence, secrets-required boot, consent withdraw, sessions list. Re-run `npm test`, `test:arch`, `typecheck`, `flutter analyze`, `flutter test`, `secret-scan`.
- Write `FINAL_PRODUCT_COMPLETENESS_AUDIT.md`; update `PROJECT_STATE.md`.
