---
noteId: "0ba511b0c07511f189a7cbfc9e7e0854"
tags: []

---

# Validation Evidence & Verification Record

## 1. Backend Verification
- Command: `npm test` (vitest run) in `backend/`
- Target: 100% green tests across real PostgreSQL instance on port 5432.
- Baseline result: 21 test files, 167 tests passed.

## 2. Mobile Verification
- Command: `flutter test` in `mobile/`
- Target: Zero test failures, full RTL/LTR parity, widget tests passing.

## 3. End-to-End User Journey Verification
- J1: Onboarding & Account Registration
- J2: Manual Measurement Logging (multiple catalog types)
- J3: Multimodal Extraction & Review
- J4: Conversational Progress Analysis (AI)
- J5: Deterministic TDEE & Target Calculation
- J6: AI Action Proposal & Confirmation Receipt
- J7: Goal Versioning
- J8: Observation Correction / Supersession / Voiding
- J9: AI Configuration & BYOK Management
- J10: Privacy Export & Purge
- J11: Language & Direction Switch (Arabic RTL / English LTR)
