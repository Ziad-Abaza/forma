# Phase 5 Execution Plan — Multimodal Image Intelligence & Vision Extraction Pipeline

**Phase Objective:** Build the secure media pipeline, image classification, vision-based catalog extraction, validation with cross-field consistency, adaptive-intensity review, and commit with epistemic provenance, adhering strictly to Blueprint §13, §14, §20.4, §27.1, §31.1 (Gate 4), and §32.

---

## 1. Architectural Invariants & Exit Rules (Blueprint §13, §14, §32)

1. **AI Extraction Never Auto-Saves:** An AI extraction creates an **Extraction Draft**; it MUST NOT be written to `observations` until the user explicitly reviews and commits it.
2. **Catalog-Bound Extraction:** The vision pipeline extracts strictly against the **Measurement Type catalog** (`weight`, `height`, `body_fat_percentage`, `muscle_mass_percentage`, `water_percentage`, `visceral_fat`, `bone_mass`, circumferences). It never invents new types or free-form keys.
3. **Epistemic Class Fidelity:** Values read from printed numerals or device displays carry epistemic class `measured`; food/visual estimates carry epistemic class `estimated`.
4. **Adaptive Review Intensity:** High-confidence, fully consistent extractions present a concise one-step confirmation; extractions with low-confidence fields (< 0.8), unit ambiguity, or cross-field inconsistencies require per-field review before commit.
5. **Full Data Provenance:** Committed observations record `origin_type: 'ai_extraction'`, model identifier, confidence score, source artifact link, and review state (`user_reviewed` or `user_corrected`).
6. **Source Image Retention Control:** The user can choose to delete the source image upon commit (default privacy posture); provenance survives image deletion as immutable lineage.
7. **Double Isolation & PostgreSQL RLS:** `media_artifacts` and `extraction_drafts` are protected by PostgreSQL Row-Level Security for role `forma_app`.
8. **Privacy Parity:** Full GDPR export and cascading account purge across media artifacts, disk storage, and extraction drafts.
9. **Bilingual Parity:** Arabic RTL and English LTR message catalogs and adaptive review screens.

---

## 2. Milestone Breakdown & Deliverables

### Milestone 1: Database Migration 008 (`008_multimodal_schema.sql`)
- Tables: `media_artifacts`, `extraction_drafts`.
- Row-Level Security (`ENABLE` and `FORCE ROW LEVEL SECURITY`) with `forma_app` role grants.
- Update `architecture.test.ts` to include the 2 new tables (21 RLS tables total).

### Milestone 2: Media Pipeline & Vision Extractor (`backend/src/modules/multimodal/`)
- Ingestion security: MIME magic-number verification, size limits, metadata stripping, private storage.
- Classifier: body composition report, scale display, tape sheet, nutrition, food, clinical document (rejected with guidance).
- Vision extraction via `AIGateway` (`taskClass: 'vision_extraction'`).
- Validation & Cross-field consistency: unit normalization, plausibility bounds, component sum checks (body fat + muscle <= 100%).
- Confidence calibration & adaptive review flagging (`requiresFieldAttention`).

### Milestone 3: Draft Review Service & Provenance Commit
- Draft lifecycle: `draft` -> `reviewed` -> `committed` / `discarded`.
- Field editing (`user_corrected` provenance flag).
- Commit to `MeasurementsService.recordObservation` with full provenance.
- Image deletion toggle upon commit.

### Milestone 4: Fastify API Routes & Privacy Orchestrator
- `POST /api/v1/multimodal/upload-and-extract`
- `GET /api/v1/multimodal/drafts/:id`
- `PUT /api/v1/multimodal/drafts/:id`
- `POST /api/v1/multimodal/drafts/:id/commit`
- `DELETE /api/v1/multimodal/drafts/:id`
- Register `MultimodalPrivacyContract` in `PrivacyOrchestrator`.

### Milestone 5: Mobile Adaptive Review UI (`mobile/`)
- `MultimodalReviewScreen` displaying image preview, adaptive attention flags, field editors, and retention toggle.
- 100% Arabic RTL & English LTR ARB key parity.

### Milestone 6: Verification & Quality Gates
- Vitest suite `src/eval/multimodal.test.ts`.
- Architecture invariant tests (21 RLS tables, 0 AI imports in domain).
- TypeScript strict typecheck & secret scan.
- Flutter static analysis (`dart analyze`) & widget tests (`flutter test`).

---

## 3. Exit Criteria for Phase 5

1. **Extraction Gate:** Report extraction accurately matches catalog types with confidence scores; low-confidence fields reliably flagged.
2. **Controlled Commit Gate:** Zero observations written without explicit draft commit API call.
3. **Provenance Gate:** Committed records link to source artifact with `ai_extraction` origin and appropriate epistemic class.
4. **Retention Gate:** Source image deletion removes file bytes while preserving provenance lineage.
5. **Isolation & Privacy Gate:** Cross-user isolation verified; privacy export and account purge tested.
6. **All Tests Green:** 100% pass across backend and mobile tests.
