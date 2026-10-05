---
noteId: "fd9a6750c07411f189a7cbfc9e7e0854"
tags: []

---

# Execution Roadmap

## Phase A: Backend Repairs & API Expansion
- [ ] Task A.1: Expose AI Configuration & BYOK API Routes in `backend/src/app.ts` (`/api/v1/ai/config`, `/api/v1/ai/credentials`, `/api/v1/ai/preferences`).
- [ ] Task A.2: Wire `BYOKService` into `AssistantOrchestrator` and `VisionExtractor`.
- [ ] Task A.3: Refactor `SecondaryProviderAdapter` to implement real OpenAI-compatible HTTP fetch rather than hardcoded string simulation.
- [ ] Task A.4: Fix error swallowing in `backend/src/modules/multimodal/extractor.ts`.
- [ ] Task A.5: Add automated tests in `backend/src/eval/` covering AI config, BYOK endpoints, and secondary adapter.

## Phase B: Flutter Core & Settings Infrastructure
- [ ] Task B.1: Fix `mobile/lib/core/config/env_config.dart` default timeout to 30000ms and verify `env_config_test.dart` passes.
- [ ] Task B.2: Create `mobile/lib/modules/profile/` models, repository, and `ProfileScreen`.
- [ ] Task B.3: Create `mobile/lib/modules/ai/` models, repository for AI configuration.
- [ ] Task B.4: Create `SettingsScreen` in `mobile/lib/presentation/screens/settings_screen.dart` featuring:
  - Language & Numeral System toggles.
  - Units configuration.
  - Profile navigation.
  - AI Provider selection & BYOK key custody management.
  - Privacy controls (GDPR export, Account deletion).
- [ ] Task B.5: Add Camera/Upload button to `DashboardScreen` and wire up `MultimodalReviewScreen` with real image extraction workflow.
- [ ] Task B.6: Expand `_showAddMeasurementDialog` to include all catalog types and enable provenance inspection on observation taps.
- [ ] Task B.7: Remove the out-of-spec Sync button from Dashboard and replace with Settings button.

## Phase C: Validation & Quality Gates
- [ ] Task C.1: Verify `npm test` passes cleanly in backend.
- [ ] Task C.2: Verify `flutter test` passes cleanly in mobile with zero failures.
- [ ] Task C.3: Run live end-to-end flow with real backend + PostgreSQL.
- [ ] Task C.4: Generate final compliance matrix.
