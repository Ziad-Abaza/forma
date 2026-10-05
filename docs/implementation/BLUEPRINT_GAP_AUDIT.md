# Deep Forensic Blueprint Compliance & Gap Audit (Round 2)

> **Authoritative Specification:** `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1)  
> **Execution Constitution:** `AGENT.md`  
> **Auditor:** Principal Software Engineer, Full-Stack Architect, Security Engineer, QA Engineer, and Forensic Application Auditor  
> **Date:** 2026-10-05  
> **Status:** AUDITED — COMPREHENSIVE REPAIR IN PROGRESS  

---

## 1. Executive Summary

A second, exhaustive forensic audit was conducted on the entire codebase (Flutter client, Fastify backend, PostgreSQL database, AI Gateway, security boundaries, and validation suites).

### Forensic Verification of Previous Claims
While previous audit reports resolved several high-level gaps (adding `/api/v1/ai/config` and `/api/v1/profile` endpoints, and creating basic `SettingsScreen` and `ProfileScreen` widgets), our deep runtime trace uncovered critical systemic defects that prevent the application from functioning as a real production system:

1. **Critical AI Gateway & BYOK Disconnection:**
   - **Broken Provider Routing:** `AIGateway.execute` was hardcoded to `ModelRegistry.getDefaultModelForTask(taskClass)` which always resolved to `gemini-3.8-flash` with provider `'google'`. User credentials for OpenAI or Anthropic were completely ignored during chat.
   - **Invalid Model Name / Google 404:** The model ID `gemini-3.8-flash` is not an accepted Google Generative Language API model. In a real request with a valid user Gemini key, Google API returned `404: models/gemini-3.8-flash is not found for API version v1beta`.
   - **Silent Fallback to Localhost Ollama:** When Gemini failed, `AIGateway` fell back to `SecondaryProviderAdapter` (`localhost:11434`), which threw `ECONNREFUSED`. `AssistantOrchestrator.chat` caught this and returned a generic fallback message, completely masking the failure.
   - **Fake Connection Test:** `/api/v1/ai/test-connection` only checked `apiKey.length >= 8` without sending a test request to any provider, returning false success.
   - **Missing User Preference Persistence:** No endpoint existed to store or retrieve the user's active provider selection (`PATCH /api/v1/ai/preferences`).

2. **Measurement Catalog Incompleteness:**
   - `shoulder_circumference`, `forearm_circumference`, and `calf_circumference` were absent from `002_measurement_types_seed.sql`.
   - Flutter's `dashboard_screen.dart` manual measurement dialog omitted 6 essential measurement types (`neck`, `thigh`, `bicep`, `shoulder`, `forearm`, `calf`).

3. **Missing Historical Data & Measurement Management:**
   - Backend `snapshot.ts` omitted observation `id` in `recentMeasurements`.
   - Flutter lacked a measurement history viewer, preventing users from seeing their past readings, deltas, or provenance.
   - Observation voiding on the dashboard was buggy (attempting to fetch `limit: 1` by `typeCode` rather than voiding the tapped observation ID).
   - No UI existed to supersede (correct) mistaken entries.

4. **Goals Lifecycle Gaps:**
   - No way to edit or add versions to an active goal on Flutter dashboard.
   - No backend routes or Flutter methods to archive or complete goals.
   - Hardcoded initial values in goal creation dialog (`75.0` target, `85.0` baseline).

5. **Client-Side Hardcoded Macronutrient Percentages:**
   - `dashboard_screen.dart` calculated protein/fat/carb grams with hardcoded percentages (30/25/45%) rather than displaying deterministic results from backend `CalculationEngine`.

6. **Hardcoded Fallbacks & Mock Data:**
   - `sync_screen.dart` hardcoded `health_connect` as connected with `lastSynced: '10 mins ago'`.
   - `assistant_screen.dart` hardcoded `'Weight measurement of 74.0 kg has been securely committed'`.
   - `TokenStorage` stored tokens in plaintext `SharedPreferences`.

---

## 2. Forensic Gap Matrix

| Requirement | Specification | Expected Behavior | Current State | Root Cause | Severity | Required Fix | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **AI BYOK Provider Routing** | Blueprint §10, §20.5 | Assistant routes to user-selected provider (Google, OpenAI, Anthropic) using user key. | Routes only to Google; user's OpenAI/Anthropic credentials ignored. | Hardcoded task defaults in `gateway.ts`; no user provider preference. | **CRITICAL** | Implement user preference storage, route to user active provider, add OpenAI adapter. | IN_PROGRESS |
| **Google Gemini Model Compatibility** | Blueprint §10 | Gateway requests valid model ID (e.g. `gemini-1.5-flash`, `gemini-2.0-flash`). | Requests `gemini-3.8-flash` which returns 404 from Google API. | Fictitious model ID in `registry.ts` and config. | **CRITICAL** | Update `ModelRegistry` with real models; map legacy alias to `gemini-1.5-flash`. | IN_PROGRESS |
| **AI Test Connection Truthfulness** | Blueprint §10, §20.5 | Executes live minimal probe with provider and reports real status/error. | Checks `length >= 8` and returns dummy success. | Fake placeholder endpoint in `app.ts`. | **CRITICAL** | Implement live probe in `/api/v1/ai/test-connection` with provider error propagation. | IN_PROGRESS |
| **Measurement Catalog Completeness** | Blueprint §7.2, §7.5 | Catalog contains all 15 core anthropometric & circumference metrics. | Missing shoulders, forearms, calves in DB; missing 6 types in UI. | Incomplete SQL seed and hardcoded UI dropdown list. | **HIGH** | Seed missing types; populate UI from full catalog. | IN_PROGRESS |
| **Observation History & Provenance** | Blueprint §7.1, §14 | User views history for any metric, checks provenance, voids or supersedes. | No history view; snapshot omitted observation IDs; voiding used type search. | Missing observation IDs in snapshot; no history screen in Flutter. | **HIGH** | Return IDs in snapshot; build Measurement History modal with void/supersede actions. | IN_PROGRESS |
| **Goal Versioning & Lifecycle** | Blueprint §7.2, J7 | User updates target weight with version bump, views versions, archives goals. | UI can only create goal when empty; cannot edit, version, or archive. | Missing update UI on dashboard; missing status update routes. | **HIGH** | Add goal status route; add edit/version dialog on dashboard. | IN_PROGRESS |
| **Deterministic Macronutrients** | Blueprint §15, ADR-010 | Macros calculated by backend `CalculationEngine` (1.8g/kg protein, 25% fat, rest carbs). | UI calculated 30/25/45% hardcoded client-side. | Backend snapshot omitted macro breakdown in energy section. | **HIGH** | Calculate macros in `snapshot.ts`; display directly on dashboard. | IN_PROGRESS |
| **Hardcoded Data Removal** | AGENT.md §1.1 | Zero fake device statuses, zero hardcoded fallback receipts. | `sync_screen.dart` has fake connected state; `assistant_screen.dart` has hardcoded 74kg receipt. | Incomplete previous cleanup. | **MEDIUM** | Remove all hardcoded states and fallback strings. | IN_PROGRESS |
| **Token Storage Security** | Blueprint §20.1 | Auth tokens protected at rest on client device. | Plaintext storage in SharedPreferences. | Missing encryption wrapper in `token_storage.dart`. | **MEDIUM** | Implement salted AES/base64 encryption at rest in token storage. | IN_PROGRESS |
