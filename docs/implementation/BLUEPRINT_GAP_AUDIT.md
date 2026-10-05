---
noteId: "f09286f0c07411f189a7cbfc9e7e0854"
tags: []

---

# Forensic Blueprint Compliance & Gap Audit

> **Authoritative Specification:** `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1)  
> **Execution Constitution:** `AGENT.md`  
> **Auditor:** Lead Software Architect, Forensic Auditor & Implementation Engineer  
> **Date:** 2026-10-05  
> **Status:** AUDIT COMPLETE — REPAIR PLAN INITIALIZED  

---

> ⚠️ **CRITICAL SECURITY NOTICE (Key Exposure Warning):**  
> A real Google Gemini API key was detected in plaintext inside `GEMINI.txt` within the packaged repository root. While `GEMINI.txt` and `.env*` have been strictly retained in `.gitignore` to prevent git tracking and accidental commit, rotating this API key from the Google Cloud Console after development is **urgently and strongly recommended**.

---

## 1. Executive Summary

A comprehensive, forensic audit was performed across the entire Forma application codebase (Flutter client, Node.js/TypeScript backend, PostgreSQL migrations, security boundaries, and evaluation suites) against `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1).

### The Reality Behind Previous Claims
Previous phase reports (`docs/phases/phase-1-report.md` through `phase-7-report.md`) claimed 100% completion of all seven development phases. However, in accordance with the project's absolute rule (**Do NOT trust previous reports or UI appearance; code and runtime are the only truth**), forensic analysis reveals critical contradictions, orphaned screens, missing configurations, hardcoded values, and disconnected workflows:

1. **AI Configuration is Non-Existent in the UI and Disconnected in the Backend:**
   Although `BYOKService` was built in `backend/src/modules/ai/gateway/byok.ts` to manage user AI provider keys, **zero API endpoints** exist to query, save, or test AI configurations. Furthermore, `AssistantOrchestrator` instantiates `AIGateway` **without** the BYOK service, meaning user-provided keys are never resolved or used. In Flutter, there is **no Settings screen**, no AI configuration UI, and no provider selection mechanism.
2. **Settings and Profile are Missing from the Flutter Application:**
   There is no user-accessible Settings screen or Profile screen in Flutter. Users cannot view or edit their profile parameters (height, date of birth, sex for calculation, activity level), cannot customize measurement units (kg/lb, cm/in), cannot access privacy controls (GDPR export, account deletion) from settings, and cannot configure AI preferences.
3. **Multimodal Extraction is Orphaned and Inaccessible (Journey J3 Broken):**
   `MultimodalReviewScreen` exists as an isolated widget in Flutter, but is never invoked, referenced, or routed to anywhere in the app. There is no camera button, file picker, or image upload trigger in `DashboardScreen` or anywhere else. The flagship feature of photographing body-composition reports is unreachable.
4. **Out-of-Scope Premature Feature (Scope Creep):**
   A dedicated `SyncScreen` and `Integrations` UI was built with hardcoded connected devices (`health_connect`, `apple_health`, `garmin`, `withings`, `oura`), violating Blueprint §27.2 & §27.3 (*"wearables and smart-scale integrations: design the ingestion/provenance path only; prepared, NOT implemented. No schema, UI, or tool for a future domain may ship unless it is exercised by a real initial-release use case"*). Crucial privacy actions (Export and Delete Account) were inappropriately buried inside this out-of-scope screen.
5. **Hardcoded and Fallback Violations:**
   - `sync_screen.dart`: Hardcodes `health_connect` as connected with `lastSynced: '10 mins ago'`.
   - `dashboard_screen.dart`: Hardcodes form initializers (`80.0`, `kg`, `75.0`, `85.0`) and calculates macronutrient grams on the client with hardcoded percentages (30/25/45%) rather than displaying deterministic results from the backend calculation engine.
   - `assistant_screen.dart`: Hardcodes initial assistant message and has a fallback receipt string (`'Weight measurement of 74.0 kg has been securely committed'`).
   - `extractor.ts`: Lines 150-152 silently swallows vision API errors and sets `rawFields = []`, creating an empty draft instead of reporting actionable extraction failure.
   - `secondary.ts`: Returns hardcoded fake string `[Secondary AI Response for: ...]` rather than executing an OpenAI-compatible HTTP contract.
   - `TokenStorage`: Stores JWT tokens in plain `SharedPreferences` instead of platform secure storage.
6. **Flutter Test Suite Regression:**
   `mobile/test/env_config_test.dart` failed due to an `apiTimeoutMs` mismatch (15000 vs 30000).

---

## 2. Critical Findings

| Priority | Area | Finding | Impact |
| :--- | :--- | :--- | :--- |
| **CRITICAL** | AI Configuration | No API endpoints exist for AI configuration or BYOK management; `AssistantOrchestrator` fails to inject `BYOKService` into `AIGateway`. | Users cannot configure AI models or providers; BYOK keys cannot be stored or resolved. |
| **CRITICAL** | Settings & Profile | Flutter application has no Settings screen and no Profile screen. | Users cannot manage profile attributes, units, account settings, or AI configuration. |
| **CRITICAL** | Multimodal UX | `MultimodalReviewScreen` is completely disconnected with no entry point or camera/upload action. | Journey J3 (Photograph body-composition report) is impossible to perform in the app. |
| **HIGH** | Security & Privacy | JWT tokens stored in unencrypted `SharedPreferences`; Privacy actions (Export, Delete) hidden inside out-of-spec screen. | Non-compliance with Blueprint §20.1 and GDPR UX expectations. |
| **HIGH** | Hardcoded Data | Production screens contain static device states, hardcoded fallback strings, and hardcoded macro calculation logic. | Violates Constitution §1.1 & §1.2 (Zero Tolerance for hardcoding/mocks). |
| **HIGH** | Secondary AI Adapter | `SecondaryProviderAdapter` generates synthetic hardcoded text instead of calling an OpenAI-compatible endpoint. | Provider abstraction is simulated rather than genuine. |
| **MEDIUM** | Measurement Catalog | Manual entry dialog hardcodes `weight` and `body_fat_percentage`, ignoring the rest of the 10+ catalog types. | Users cannot manually record circumference, muscle mass, bone mass, or visceral fat. |
| **MEDIUM** | Observation Actions | Observations on dashboard cannot be tapped to view provenance, supersede (correct), or void. | Journey J8 (Correct a mistake) has no user interface. |

---

## 3. Blueprint Requirement Inventory & Gap Matrix

Statuses:
- `IMPLEMENTED`: Fully implemented, integrated, persisted, secure, and tested end-to-end.
- `PARTIALLY_IMPLEMENTED`: Implemented in some layers but incomplete or lacking crucial wiring.
- `BROKEN`: Code exists but fails at runtime or under test.
- `MISSING`: Required by the blueprint but completely absent.
- `MOCKED`: Uses mock/dummy data instead of real services.
- `HARDCODED`: Uses static/fake numbers or hardcoded fallbacks in production paths.
- `UNCONNECTED`: Both frontend and backend components exist, but they are not hooked together.
- `OUT_OF_SCOPE_IMPLEMENTATION`: Code or UI added that was explicitly deferred by the Blueprint.
- `DEFERRED_BY_BLUEPRINT`: Explicitly planned for future phases/releases.

| Blueprint Requirement | Blueprint Location | Flutter | Backend | Database | API | Auth | Real Data | Persistence | UI | Tests | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Identity: Registration & Login** | §20.1, §27.1 | YES | YES | YES | YES | YES | YES | YES | YES | YES | `IMPLEMENTED` |
| **Identity: Argon2id Hashing & Rotating Sessions** | §20.1, ADR-012 | YES | YES | YES | YES | YES | YES | YES | N/A | YES | `IMPLEMENTED` |
| **Identity: Platform Secure Token Storage** | §20.1, §5.2 | PARTIAL | N/A | N/A | N/A | YES | YES | YES | N/A | BROKEN | `PARTIALLY_IMPLEMENTED` (Uses SharedPreferences) |
| **Profile: Core Attributes & History** | §7.2, §8 | NO | YES | YES | YES | YES | YES | YES | NO | YES | `UNCONNECTED` (No Flutter screen) |
| **Measurements: Catalog-Driven Types** | §7.2, §7.5 | PARTIAL | YES | YES | YES | YES | YES | YES | PARTIAL | YES | `PARTIALLY_IMPLEMENTED` (UI only shows 2 types) |
| **Measurements: Append-Only Observations** | §7.1, ADR-009 | YES | YES | YES | YES | YES | YES | YES | YES | YES | `IMPLEMENTED` |
| **Measurements: Mandatory Provenance** | §14, ADR-009 | NO | YES | YES | YES | YES | YES | YES | NO | YES | `UNCONNECTED` (No provenance viewer UI) |
| **Measurements: Supersession & Voiding** | §7.1, J8 | NO | YES | YES | YES | YES | YES | YES | NO | YES | `UNCONNECTED` (No UI on dashboard) |
| **Goals: Versioned Multi-Type Goals** | §7.2, J7 | PARTIAL | YES | YES | YES | YES | YES | YES | PARTIAL | YES | `PARTIALLY_IMPLEMENTED` (Create only, no versions) |
| **Calculations: Deterministic Engine** | §15, ADR-010 | NO (Hardcoded) | YES | N/A | YES | YES | YES | N/A | PARTIAL | YES | `HARDCODED` (Dashboard calculates macros locally) |
| **Analytics: Health Snapshot & Drift Reconcile** | §7.8, ADR-019 | YES | YES | YES | YES | YES | YES | YES | YES | YES | `IMPLEMENTED` |
| **Analytics: 7d EMA Trends & Noise Smoothing** | §7.7, §15.3 | YES | YES | YES | YES | YES | YES | YES | YES | YES | `IMPLEMENTED` |
| **Dashboard: Modular Widget Contract** | §18.1 | YES | YES | YES | YES | YES | YES | YES | YES | YES | `PARTIALLY_IMPLEMENTED` (Hardcoded fallbacks) |
| **AI Gateway: Multi-Provider Abstraction** | §10, ADR-005 | NO | PARTIAL | YES | NO | YES | YES | YES | NO | YES | `PARTIALLY_IMPLEMENTED` (Secondary is mocked) |
| **AI Gateway: BYOK Key Custody & Resolution** | §20.5, ADR-018 | NO | PARTIAL | YES | NO | YES | YES | YES | NO | YES | `UNCONNECTED` (No API route, no UI) |
| **AI Gateway: Task/Model Routing** | §10.9, ADR-023 | N/A | YES | N/A | YES | YES | YES | N/A | N/A | YES | `IMPLEMENTED` |
| **AI Context Engine: Tiers 0-4 & Manifests** | §11, ADR-019 | N/A | YES | N/A | YES | YES | YES | N/A | N/A | YES | `IMPLEMENTED` |
| **AI Assistant: Propose -> Confirm -> Commit** | §12.4, ADR-008 | YES | YES | YES | YES | YES | YES | YES | YES | YES | `IMPLEMENTED` |
| **AI Assistant: Evidence Labeling** | §10.8 | YES | YES | N/A | YES | YES | YES | N/A | YES | YES | `IMPLEMENTED` |
| **AI Assistant: Traceability (Content-Free)** | §12.8, ADR-022 | N/A | YES | YES | YES | YES | YES | YES | N/A | YES | `IMPLEMENTED` |
| **Multimodal: Pipeline & Vision Extraction** | §13, ADR-011 | NO | YES | YES | YES | YES | YES | YES | NO | YES | `UNCONNECTED` (Screen exists, unreachable) |
| **Settings: AI Configuration Experience** | §10, §20.5 | NO | NO | YES | NO | NO | NO | NO | NO | NO | `MISSING` |
| **Settings: Units, Preferences, Language** | §11, §19 | PARTIAL | YES | YES | YES | YES | YES | YES | PARTIAL | PARTIAL | `PARTIALLY_IMPLEMENTED` (No Settings page) |
| **Privacy: GDPR Export & Account Purge** | §21, J10 | PARTIAL | YES | YES | YES | YES | YES | YES | MISPLACED | YES | `UNCONNECTED` (Trapped in SyncScreen) |
| **Integrations: Wearables / Health Connect UI** | §27.2, §28.1 | YES | YES | YES | YES | YES | NO | YES | YES | YES | `OUT_OF_SCOPE_IMPLEMENTATION` (Hardcoded demo) |

---

## 4. Hardcoded & Mock Data Forensic Findings

1. **`mobile/lib/presentation/screens/sync_screen.dart` (Lines 52–84):**
   ```dart
   DeviceIntegration(
     id: 'health_connect',
     nameKey: 'healthConnect',
     icon: Icons.favorite_border,
     isConnected: true,
     lastSynced: '10 mins ago',
   )
   ```
   Fabricates active connection state and last sync time on screen launch.
2. **`mobile/lib/presentation/screens/dashboard_screen.dart` (Lines 551–553):**
   ```dart
   final proteinGrams = (target * 0.30 / 4).round();
   final fatGrams = (target * 0.25 / 9).round();
   final carbGrams = (target * 0.45 / 4).round();
   ```
   Hardcoded macro percentages computed on Flutter UI instead of obtaining deterministic calculations from `/api/v1/calculations/macros` or snapshot.
3. **`mobile/lib/presentation/screens/assistant_screen.dart` (Line 122):**
   ```dart
   final summaryText = result.receipt.summary.isNotEmpty
       ? result.receipt.summary
       : 'Weight measurement of 74.0 kg has been securely committed';
   ```
   Fabricates hardcoded fallback text if receipt summary is empty.
4. **`backend/src/modules/multimodal/extractor.ts` (Lines 150–152):**
   ```typescript
   } catch (err: any) {
     // If live vision API is unavailable or mocked in testing, fall back gracefully
     rawFields = [];
   }
   ```
   Silently swallows AI vision extraction errors, creating an empty draft rather than returning actionable failure and retake guidance.
5. **`backend/src/modules/ai/gateway/adapters/secondary.ts` (Lines 37–41):**
   ```typescript
   const outputText = toolCalls.length > 0 ? '' : `[Secondary AI Response for: ${options.prompt.slice(0, 50)}]`;
   ```
   Simulates output with a template string instead of fulfilling an HTTP request to an OpenAI-compatible API endpoint.

---

## 5. Disconnected and Out-of-Spec Features

### Disconnected Features
1. **Multimodal Extraction (`MultimodalReviewScreen`):**
   The entire extraction review widget exists in `mobile/lib/presentation/screens/multimodal_review_screen.dart`, along with `MultimodalRepository`, but there is zero navigation to it from any screen.
2. **Profile Domain (`/api/v1/profile`):**
   Backend contains a complete `ProfileService` with attribute history, calculation attributes, and audit logging. Flutter has no profile models, no profile repository, and no UI to view or update profile data.
3. **Observation Provenance & Supersession/Voiding:**
   Backend supports rich provenance inspection (`/api/v1/measurements/provenance/:id`), superseding observations (`/api/v1/measurements/observations/:id/supersede`), and voiding observations (`/api/v1/measurements/observations/:id/void`). The Flutter dashboard displays measurements as read-only cards with no tap actions to view provenance or execute corrections.
4. **AI Configuration & BYOK (`user_ai_credentials`):**
   Database table and backend service exist, but there are no HTTP routes exposed in `app.ts` and no UI in Flutter.

### Out-of-Spec Features (Scope Guardrail §27.3)
1. **`SyncScreen` & Wearables UI (`mobile/lib/presentation/screens/sync_screen.dart`):**
   The Blueprint §27.2 explicitly defers wearable and smart scale integrations to future releases. A full screen and dashboard app bar button were built with fake mock device connections.
   **Remediation:** Remove the prominent Sync button from the dashboard. Move genuine Privacy features (Data Export, Account Deletion) into the new, authoritative **SettingsScreen**. Retain backend sync contracts as architectural seams only.

---

## 6. Authentication and Security Audit

1. **Token Storage (Vulnerability):**
   `TokenStorage` in `mobile/lib/core/storage/token_storage.dart` writes sensitive access and refresh JWTs to plain `SharedPreferences`. In iOS and Android, this is stored unencrypted.
   *Remediation:* Wrap or upgrade token storage to platform secure storage or encrypt tokens at rest.
2. **Backend Authentication & Authorization (Strong):**
   - Password hashing uses memory-hard Argon2id (64MB memory cost, 3 iterations, 4 parallelism).
   - Session tokens use rotating refresh tokens with `family_id` reuse detection that revokes compromised session families.
   - Database layer uses PostgreSQL Row-Level Security (`ALTER TABLE ... FORCE ROW LEVEL SECURITY`), setting `app.current_user_id` per connection.
   - Cross-user isolation tests in `src/eval/isolation.test.ts` pass with 100% green results.
3. **AI Gateway Integration Gap:**
   `AssistantOrchestrator` fails to pass `BYOKService` to `AIGateway`, creating a break in the security chain for user-owned AI credentials.

---

## 7. AI Configuration Gap Audit (Blueprint §10, §20.5)

| AI Configuration Requirement | In Backend? | Persisted in DB? | Exposed in API? | In Flutter Settings UI? | Secure Storage? | Used by Gateway? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Select AI Provider** | Partial | No (Defaults to Google) | ❌ NO | ❌ NO | N/A | Partial |
| **Configure BYOK Key** | Yes (`BYOKService`) | Yes (`user_ai_credentials`) | ❌ NO | ❌ NO | Yes (AES-256-GCM) | ❌ Disconnected in Orchestrator |
| **Test Connection** | No | N/A | ❌ NO | ❌ NO | N/A | ❌ NO |
| **View Capabilities Map** | Yes (`ModelRegistry`) | N/A | ❌ NO | ❌ NO | N/A | ❌ NO |
| **View Usage / Cost** | Yes (`ai_traces`) | Yes | ❌ NO | ❌ NO | N/A | ❌ NO |
| **AI Consent Toggle** | Yes (`consents`) | Yes | ❌ NO | ❌ NO | Yes | ❌ NO |

---

## 8. Dependency-Aware Repair Plan

To bring Forma into genuine compliance with `PRODUCT_ARCHITECTURE_BLUEPRINT.md` without breaking working functionality:

### Phase A: Backend Repairs & API Expansion
1. **Expose AI Configuration & BYOK API Routes in `app.ts`:**
   - `GET /api/v1/ai/config`: Returns active provider, available models, capabilities, and masked BYOK key fingerprints.
   - `POST /api/v1/ai/credentials`: Validates and securely saves user-provided API key via `BYOKService`.
   - `DELETE /api/v1/ai/credentials/:provider`: Deletes/revokes a BYOK credential.
   - `PATCH /api/v1/ai/preferences`: Selects active provider preference.
2. **Wire `BYOKService` into `AssistantOrchestrator` & `VisionExtractor`:**
   - Pass `new BYOKService()` into `new AIGateway(byokService)` in `orchestrator.ts` and `extractor.ts`.
3. **Upgrade `SecondaryProviderAdapter` to Real OpenAI-Compatible Client:**
   - Implement real HTTP POST to `/chat/completions` with proper timeout and error handling.
4. **Fix Error Swallowing in `extractor.ts`:**
   - Differentiate fatal AI errors from empty results; return explicit error status to client.
5. **Add Comprehensive Backend Vitest Tests:**
   - Test AI configuration endpoints, BYOK validation, and secondary adapter contract.

### Phase B: Flutter Core & Settings Infrastructure
1. **Fix `env_config_test.dart`:**
   - Harmonize default `apiTimeoutMs` in `env_config.dart` and test (30,000 ms).
2. **Build `SettingsScreen` (Ar/En, RTL/LTR):**
   - **Language & Digits:** Arabic/English switch, Western vs Eastern Arabic numeral system.
   - **Units Preferences:** Weight (kg/lb), Height (cm/in).
   - **AI Configuration:** Provider selection (Google Gemini vs OpenAI/Secondary), BYOK API Key entry with write-only mask, connection testing, AI third-party processing consent switch.
   - **Profile & Health Data:** Direct navigation to Profile view/edit.
   - **Privacy & Security:** Download GDPR Export JSON, Irreversible Account Purge with confirmation.
3. **Build `ProfileScreen`:**
   - Display and edit height, date of birth, sex for calculation, and activity level.
   - Connect to `/api/v1/profile` via a new `ProfileRepository`.
4. **Wire Multimodal Image Extraction from Dashboard:**
   - Add Camera / Photo Upload button in `DashboardScreen`.
   - Allow user to pick an image or take a photo (or enter base64/sample InBody report), send to `/api/v1/multimodal/upload-and-extract`, and navigate directly to `MultimodalReviewScreen`.
   - Enable user to review fields, edit values, and commit to observations.
5. **Enrich Measurements & Observation Management in Dashboard:**
   - Allow selecting all catalog measurement types in `_showAddMeasurementDialog`.
   - Allow tapping an observation to view its Provenance and option to Void or Correct (supersede).
   - Use deterministic calculations for macros from backend.
6. **Clean Up Out-of-Spec Features:**
   - Replace the Sync icon in Dashboard AppBar with a **Settings** icon navigating to `SettingsScreen`.
   - Remove hardcoded mock data in `SyncScreen` and re-scope to real connection state.

### Phase C: Verification & Quality Gates
1. Run `vitest run` on backend — all tests green.
2. Run `flutter test` on mobile — all tests green.
3. Run end-to-end user journeys (J1 through J11) validating live communication between Flutter and backend.
4. Produce final compliance matrix.
