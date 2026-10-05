# Validation Evidence & Verification Record

## 1. Backend Verification
- Command: `npm test` (vitest run) in `backend/`
- Output: 21 test files passed (21), 169 tests passed (169).
- Duration: 5.15s.
- `npm run typecheck`: clean, 0 errors under `strict: true` and `exactOptionalPropertyTypes: true`.
- `npm run build`: successfully built TypeScript to `dist/` and copied migrations.

## 2. Mobile Verification
- Command: `flutter test` in `mobile/`
- Output: 44 tests passed (0 failures).
- `flutter analyze`: clean, 0 issues found!
- Responsive UI test suite: 12 tests passed across screens from 320x568 to 390x844 without any RenderFlex overflow in English LTR and Arabic RTL.

## 3. End-to-End Live User Journey Verification
Executed via `scripts/verify_live_journey.ps1` against live Fastify backend on port 3000 and PostgreSQL:
- **J1: User Registration:** Registered `live_audited_user_22897@example.com` with Argon2id password hashing and JWT session pair.
- **J5: Deterministic Calculations:** Verified pure calculation of BMI (25.9, overweight) and TDEE (2790 kcal) without LLM.
- **Profile Domain:** Successfully queried and updated profile attributes (height: 179cm, activity: very_active) with attribute history recording.
- **J9: AI Configuration & BYOK Management:** Successfully queried `/api/v1/ai/config`, tested provider connectivity, stored encrypted API key with fingerprint `...5678`, and deleted key.
- **J2: Record Observation with Mandatory Provenance:** Recorded weight observation (82.5 kg) with linked provenance record in PostgreSQL.
- **J7: Goal Creation & Versioning:** Created primary weight loss goal (target 76 kg, version 1) and added version 2 (target 75 kg).
- **Health Snapshot:** Reconciled snapshot dynamically reflecting current weight and primary goal with data watermark.
- **J10: Privacy Export & Purge:** Exported all 9 user modules in machine-readable JSON format, followed by irreversible account purge cascading across all user records in PostgreSQL.
