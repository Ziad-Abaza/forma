---
noteId: "f916db00c07411f189a7cbfc9e7e0854"
tags: []

---

# Project State: Forma

> **Active Goal:** Forensic Blueprint Compliance & Real End-to-End Implementation  
> **Authoritative Specification:** `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1)  
> **Execution Constitution:** `AGENT.md`  
> **Last Updated:** 2026-10-05  

---

## Current Status
- **Forensic Gap Audit:** COMPLETED (`docs/implementation/BLUEPRINT_GAP_AUDIT.md`).
- **Core Critical Deficiencies Discovered:**
  1. AI Configuration is completely missing from Flutter UI and has no API endpoints in the backend.
  2. `AssistantOrchestrator` fails to pass `BYOKService` to `AIGateway`, breaking user BYOK key resolution.
  3. `MultimodalReviewScreen` exists but is completely orphaned (no trigger in Dashboard or navigation).
  4. Flutter lacks a Settings screen and a Profile screen.
  5. `SecondaryProviderAdapter` in backend generates fake hardcoded strings instead of calling OpenAI-compatible endpoint.
  6. Out-of-scope `SyncScreen` was built with hardcoded connected devices (`health_connect` synced 10 mins ago).
  7. Production dashboard calculates macros locally using hardcoded percentages instead of calculation engine.
  8. `mobile/test/env_config_test.dart` has a timeout assertion mismatch.
- **Current Phase:** Phase A (Backend Repairs & API Expansion) in progress.

---

## Active Workstreams
1. **Workstream 1 (Backend):**
   - Add AI Configuration & BYOK API routes (`/api/v1/ai/config`, `/api/v1/ai/credentials`, `/api/v1/ai/preferences`).
   - Wire `BYOKService` into `AssistantOrchestrator` and `VisionExtractor`.
   - Upgrade `SecondaryProviderAdapter` to standard OpenAI-compatible HTTP client.
   - Stop swallowing vision extraction errors in `extractor.ts`.
2. **Workstream 2 (Mobile Core & UI):**
   - Fix `env_config_test.dart` timeout default.
   - Build `SettingsScreen` with full Arabic/English parity and RTL/LTR support:
     - Language and Numeral System preferences.
     - Units preferences (kg/lb, cm/in).
     - AI Provider and BYOK Key management.
     - Account info and GDPR Data Export / Purge.
   - Build `ProfileScreen` connected to `/api/v1/profile`.
   - Wire Camera/Photo Upload action in `DashboardScreen` to launch `MultimodalReviewScreen`.
   - Enrich observation interactions (tap to view provenance, supersede, or void).
3. **Workstream 3 (Verification):**
   - Run vitest suite + flutter test suite.
   - Verify all critical user journeys J1-J11 end-to-end.
