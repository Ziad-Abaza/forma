# Validation Evidence & Verification Record

## 1. Backend Verification
- Command: `npm test` (vitest run) in `backend/`
- Output: 21 test files passed (21), 169 tests passed (169).
- `npm run build`: successfully built TypeScript to `dist/` with 0 errors and copied 11 SQL migrations to dist.

## 2. Mobile Verification
- Command: `flutter test` in `mobile/`
- Output: 54 tests passed (0 failures).
- `flutter analyze`: clean, 0 issues found!
- Responsive UI test suite: 12 tests passed across screens from 320x568 to 390x844 without any RenderFlex overflow in English LTR and Arabic RTL.

## 3. End-to-End Live User Journey Verification
Executed via `scripts/verify_live_journey.ps1` against live Fastify backend on port 3000 and PostgreSQL 18:
- **J1: User Registration:** Registered user with Argon2id password hashing and JWT session pair.
- **J5: Deterministic Calculations:** Verified pure calculation of BMI (25.9, overweight) and TDEE (2790 kcal) without LLM.
- **Profile Domain:** Successfully queried and updated profile attributes (height: 179cm, activity: very_active) with attribute history recording.
- **J9: AI Configuration & BYOK Management:** Successfully queried `/api/v1/ai/config`, stored OpenAI BYOK key, switched active provider via `PATCH /api/v1/ai/preferences`, tested connection via live probe, and deleted key.
- **J2: Record Observation with Mandatory Provenance & New Types:** Recorded weight observation (82.5 kg) with linked provenance record, recorded new metric `calf_circumference` (38.5 cm), and executed supersession correcting calibration to 82.0 kg.
- **J7: Goal Creation, Versioning & Lifecycle:** Created primary weight loss goal (target 76 kg, version 1), added version 2 (target 75 kg), and updated status to `completed`.
- **Health Snapshot:** Reconciled snapshot dynamically reflecting current weight, primary goal, source watermark, and pure deterministic macro breakdown (protein: 148g, fat: 72g, carbs: 335g).
- **J10: Privacy Export & Purge:** Exported all 9 user modules in machine-readable JSON format, followed by irreversible account purge cascading across all user records in PostgreSQL.
