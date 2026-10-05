# Final Product Completeness Audit — Forma

Generated at the end of the full remediation cycle (phases A–G). Every claim
below is backed by an executed command or a code change that is in the tree.
Nothing is asserted from intent alone.

## Verified command results (actually run this session)

| Command | Result |
|---|---|
| `backend: npm run typecheck` | PASS (0 errors) |
| `backend: npm test` | **21 files / 185 tests ALL PASS** |
| `backend: npm run test:arch` | 4 tests PASS |
| `backend: npm run build` | PASS (tsc + migrations copied to dist) |
| `mobile: dart analyze` | **No issues found** |
| `mobile: flutter test` | **44 tests ALL PASS** (run via `D:\flutter-sdk` junction — native-assets hook is broken when the SDK path contains spaces) |
| `node scripts/secret-scan.js` | PASS — 275 files, no secrets |

## Fabrications eliminated (all verified in tree)

| Defect | Resolution |
|---|---|
| Sync screen fabricated connected state + posted fabricated `8540` steps | Feature removed end-to-end: `sync_screen.dart`, integrations repo, `sync.ts`, `contracts.ts`, 5 routes, sync tests all deleted. Retained tables (`integration_connections`, `import_batches`, `sync_dedup_records`) remain covered by `IntegrationsPrivacyContract` for export/purge; `privacy_e2e.test.ts` seeds them via SQL. |
| Dashboard macros fabricated from 30/25/45 split | Card renders nothing when backend omits macros; test fixture now supplies real values. |
| Client-fabricated receipts (multimodal `rec_…`, assistant "Action Receipt verified") | Both surfaces render the server-issued `receipt.receiptId`/summary verbatim; nothing is invented client-side. |
| Extraction review edits & unchecked fields not persisted | `updateDraftField` is called on every toggle/edit with revert-on-failure; commit uses server state. |
| Extraction discard was client-only | `DELETE /multimodal/drafts/:id` is called; failure surfaces an error, does not fake-pop. |
| Extraction failure drafts fabricated confidence/fields | Backend persists `extraction_failed` drafts with truthful error traces. |
| Goal response parsing crashed on every write | `GoalModel` rewritten to the real contract (`goalType`, `currentVersion`, `progressPct`); status enum aligned to `achieved|abandoned|superseded`; `weight_gain` → `muscle_gain` alias. |
| Provenance dialog fetched `provenance/:observationId` → 404 + fake "manual" origin | Now uses `observation.provenanceId`; missing data renders `unknown`, errors propagate. |
| `isVoided` read a nonexistent JSON field | `ObservationModel.status` drives `isVoided`/`isSuperseded`/`isActive`; history requests `status: 'all'`; supersede/void hidden for non-active rows. |
| `windowDays` ignored server-side | `GET /analytics/trends/:type` filters observations by the window; per-point raw + EMA `series`/`smoothedSeries` now emitted and charted with `fl_chart`. |
| Chat streaming double-saved user message / mismatched conversations | Orchestrator persists the user message once; the done event carries `content`; client no longer saves a duplicate. |
| Session expiry never logged the user out | `ApiClient.onSessionExpired` callback → `AuthNotifier` → unauthenticated state. |
| BYOK master key / JWT / DB had literal defaults | `config/index.ts` fails closed on missing `DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `ENCRYPTION_MASTER_KEY` (tested in `config.test.ts`); migration role password parameterized via `FORMA_APP_DB_PASSWORD`. |
| Real-PII seed data | Seed script quarantined: synthetic `@forma.test` user, one-time generated password, `FORMA_SEED_CONFIRM` + `NODE_ENV=production` guards. |
| Phantom `anthropic` provider; test-key bypass | Provider list is derived from registered adapters; test-connection exercises the real adapter. |
| Registration prefills + default-on AI consent | Removed; height validated, AI consent opt-in only, and AI consent is now *enforced* on `/assistant/chat` (403 `AI_CONSENT_REQUIRED` when absent/withdrawn). |

## New capabilities delivered (backend ↔ Flutter end-to-end)

| Capability | Backend | Flutter |
|---|---|---|
| Session management | `GET/DELETE /auth/sessions`, `POST /auth/logout-all` | Settings → Security & Sessions card: list, per-session revoke, sign-out-all |
| Password change | `POST /auth/change-password` (verifies current, revokes all sessions, audit-logged) | Settings → Change Password dialog |
| Consent view/withdraw | `GET /privacy/consents`, `POST /privacy/consents/:type/withdraw` (only `ai_third_party_processing` withdrawable; others 409 → account deletion) | Settings → Consent & Privacy section |
| Goal version history | `GET /goals/:id/versions` | Goal card → history icon → versions sheet (v, values, rate, dates, rationale) |
| Extraction draft history | `GET /multimodal/drafts[?status]` | Dashboard → Pending Reviews card → resume review → real commit/discard |
| Measurement catalog | `GET /measurements/types` (existing) | Add-measurement dialog + history dropdown are now catalog-driven (`isUserEnterable` filter, plausibility ranges, canonical units) — no hardcoded type lists |
| Anomaly flags + data quality | snapshot `sections.anomalies`/`dataQuality` | Dashboard data-quality card (severity-colored flags, measured share, staleness, observation count) |
| Trend visualization | `series` + `smoothedSeries` added to trend response | `fl_chart` line chart: raw observations (dim) + EMA smoothed (teal), day-axis |
| Conversations | existing list/get/delete routes | Assistant app bar: history sheet (open/delete), new-chat action |
| Assistant memories | existing CRUD | Assistant → memories screen: grouped list, add (category/key/value), delete |
| Profile completeness | `dateOfBirth` added to `PUT /profile` (+18 validation, history tracked) | Profile screen: DOB, experience level, constraints editor, profile-history sheet |
| AI model picker | existing `GET /ai/config`, `PATCH /ai/preferences` | Settings → AI model dropdown (approved models only) |
| Secure token storage | — | `flutter_secure_storage` v11 (always-encrypted); SharedPreferences only for non-secret prefs |

## Honest remaining gaps

1. **Residual English literals (~35)** — older dialogs (supersede/void/provenance copy, goal dialog labels, provenance detail rows) still carry English strings; all *new* UI from this cycle is localized EN/AR. A full sweep is P2 follow-up.
2. **Live device flow not exercised** — suite-level verification only; no emulator/device run against the live DB in this session.
3. **`metric_rollups`** is exported but not a distinct UI surface — the trend chart covers the same analytical signal.
4. **Draft history UI** surfaces pending (`status=draft`) drafts; committed/discarded history is API-available but not a dedicated screen.
5. **Duplicate `retry` key** in `app_en.arb` predates this cycle (JSON last-wins; harmless but should be deduped).
6. `debugPrint` diagnostics remain in `api_client.dart`/`local_server_discovery.dart` — dev-only, no secrets logged.
7. **Flutter Windows path caveat** — `flutter test`/`run` fails if the SDK lives under `C:\Program Files\` (native-assets hook quoting bug); `D:\flutter-sdk` junction works around it.

## Data-model coverage summary

26 tables — all user-owned data now has an intentional surface:
`users/credentials/sessions` (settings security card), `consents` (settings),
`profiles` + `profile_history` (profile screen + history), `measurement_types`
(catalog pickers), `observations` + `provenance_records` (records list, history,
provenance dialog, supersede/void), `goals` + `goal_versions` (goal card,
versions sheet), `health_snapshots`/`metric_rollups`/`anomaly_flags` (body,
energy, trends, data-quality cards), `ai_traces`/`user_ai_credentials` (BYOK
settings), `conversations`/`conversation_messages`/`assistant_memories`
(assistant history + memories), `media_artifacts`/`extraction_drafts`
(upload → review → commit/discard + pending drafts), `audit_logs` (backend),
`integration_connections`/`import_batches`/`sync_dedup_records` (retained for
export/purge only — sync UI removed per decision).
