# Execution Roadmap

## Phase A: Backend Repairs & API Expansion
- [x] Task A.1: Expose AI Configuration & BYOK API Routes in `backend/src/app.ts` (`/api/v1/ai/config`, `/api/v1/ai/credentials`, `/api/v1/ai/test-connection`).
- [x] Task A.2: Wire `BYOKService` into `AssistantOrchestrator` and `VisionExtractor`.
- [x] Task A.3: Refactor `SecondaryProviderAdapter` to implement real OpenAI-compatible HTTP fetch rather than hardcoded string simulation.
- [x] Task A.4: Fix error swallowing in `backend/src/modules/multimodal/extractor.ts`.
- [x] Task A.5: Add automated tests in `backend/src/eval/` covering AI config, BYOK endpoints, and secondary adapter.

## Phase B: Flutter Core & Settings Infrastructure
- [x] Task B.1: Fix `mobile/lib/core/config/env_config.dart` default timeout to 30000ms and verify `env_config_test.dart` passes.
- [x] Task B.2: Create `mobile/lib/modules/profile/` models, repository, and `ProfileScreen`.
- [x] Task B.3: Create `mobile/lib/modules/ai/` models, repository for AI configuration.
- [x] Task B.4: Create `SettingsScreen` in `mobile/lib/presentation/screens/settings_screen.dart` featuring:
  - Language & Numeral System toggles.
  - Units configuration.
  - Profile navigation.
  - AI Provider selection & BYOK key custody management.
  - Privacy controls (GDPR export, Account deletion).
- [x] Task B.5: Add Camera/Upload button to `DashboardScreen` and wire up `MultimodalReviewScreen` with real image extraction workflow.
- [x] Task B.6: Expand `_showAddMeasurementDialog` to include all catalog types and enable provenance inspection on observation taps.
- [x] Task B.7: Remove the out-of-spec Sync button as primary from Dashboard and replace with Settings button.

## Phase C: Validation & Quality Gates
- [x] Task C.1: Verify `npm test` passes cleanly in backend (21 files, 169 tests).
- [x] Task C.2: Verify `flutter test` passes cleanly in mobile with zero failures (44 tests).
- [x] Task C.3: Run live end-to-end flow with real backend + PostgreSQL (`scripts/verify_live_journey.ps1`).
- [x] Task C.4: Generate final compliance matrix.
