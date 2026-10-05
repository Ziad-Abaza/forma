# Changelog

All notable changes to the Forma project are documented in this file.

## [1.1.0] - 2026-10-05

### Forensic Audit & Architecture Integrity
- Performed complete forensic audit between `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1) and codebase.
- Authored `docs/implementation/BLUEPRINT_GAP_AUDIT.md` highlighting critical gaps, mock data, disconnected workflows, and out-of-scope features.
- Established persistent tracking system (`PROJECT_STATE.md`, `ROADMAP.md`, `PROGRESS.md`, `DECISIONS.md`, `BLOCKERS.md`, `VALIDATION.md`, `CHANGELOG.md`).

### Backend Improvements
- Added `/api/v1/ai/config`, `/api/v1/ai/credentials`, and `/api/v1/ai/test-connection` routes for user-managed AI provider settings and BYOK key custody.
- Injected `BYOKService` into `AssistantOrchestrator` and `VisionExtractor`, restoring user key resolution.
- Refactored `SecondaryProviderAdapter` from static text simulation to an OpenAI-compatible HTTP fetch implementation.
- Enhanced Goals request schema to handle parameter names from both client and server contracts without friction.
- Verified 169 automated tests in vitest with 100% pass rate.

### Mobile & UI Improvements
- Created `ProfileModel`, `ProfileRepository`, and `ProfileScreen` for viewing and updating calculation-relevant user attributes.
- Created `AIConfigModel`, `AIConfigRepository`.
- Built `SettingsScreen` with complete Arabic RTL and English LTR parity:
  - Language toggle and Numeral System selector (Western vs Eastern Arabic digits).
  - AI Provider selector and write-only BYOK encrypted key entry with connection test.
  - GDPR Data Export and Account Purge actions.
- Integrated Settings button into `DashboardScreen` AppBar.
- Added Camera / Report Extraction button into Dashboard Health Records, connecting `MultimodalReviewScreen` with draft review and commit flow.
- Added tap interaction on observations for provenance inspection and voiding.
- Expanded manual measurement dialog to all 9 catalog types.
- Fixed RenderFlex overflows across all resolutions (320x568 to 390x844).
- Verified 44 Flutter tests with 0 failures and 0 analyzer issues.
