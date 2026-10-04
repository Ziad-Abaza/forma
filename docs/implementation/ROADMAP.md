# Implementation Roadmap

This roadmap governs the multi-phase implementation of Forma based strictly on [PRODUCT_ARCHITECTURE_BLUEPRINT.md](../../PRODUCT_ARCHITECTURE_BLUEPRINT.md) (Revision 1.1).

---

## Phase 0 — Architecture & Specification (Complete)
- [x] Analyze `PRODUCT_ARCHITECTURE_BLUEPRINT.md` in full.
- [x] Discover environment, available runtimes (Node 24, Flutter 3.47, Dart 3.13, Python 3.13, Git).
- [x] Initialize Git version control.
- [x] Establish persistent documentation & execution system in `docs/implementation/`.

---

## Phase 1 — Foundation, Identity, Profile & Core Health Data Foundation
**Objective:** Build what cannot be retrofitted (defense-in-depth isolation, append-only invariants, provenance, canonical units, localization).
- [ ] Backend workspace initialization (`backend/`, TypeScript, modular monolith structure).
- [ ] Database schema, migration system, and repository abstraction with PostgreSQL support.
- [ ] Unit Registry & Canonical Normalization Engine (ADR-021): dimensions (mass, length, energy, percentage, etc.), exact conversions, original preservation.
- [ ] Measurement Type Catalog & Append-only Observations schema with mandatory Provenance and Epistemic Class (measured, calculated, estimated, asserted).
- [ ] Identity & Session management: registration, login, rotating refresh tokens, session revocation, age-gate (18+), consent tracking.
- [ ] Profile domain with versioned calculation-relevant attributes (height, sex-for-calc, DOB, activity level) and extensible key-value attributes.
- [ ] Privacy contracts skeleton (export, soft-void, physical purge).
- [ ] Defense-in-depth isolation tests (cross-user access blocked at app and query levels).
- [ ] Mobile foundation (`mobile/`, Flutter cross-platform skeleton, RTL/LTR localization support, theme, secure storage).

---

## Phase 2 — Core Health Domain, Analytics, Calculations & Dashboard
**Objective:** Deliver a complete, valuable, fully functioning product *without AI*.
- [ ] Deterministic Calculation Engine (ADR-010): BMI, BMR, TDEE, calorie maintenance, deficit/surplus ranges, macro targets, with safety guardrails (calorie floors, max rates).
- [ ] Time-series rollups, trend smoothing, period comparisons, deltas, and anomaly detection.
- [ ] Goal domain: versioned goals (weight loss, fat loss, muscle gain, recomposition, maintenance), baseline snapshots, temporal progress evaluation.
- [ ] Health Snapshot engine (ADR-019 / §7.8): derived, compact, versioned representation with lineage-driven invalidation and drift reconciliation.
- [ ] Dashboard widget composition contract & widgets (status/goal, recent measurements, trends, targets, anomaly flags).
- [ ] Flutter UI: onboarding, manual measurement logging, goal setup, trends/charts, settings (Arabic/English, units, numerals).

---

## Phase 3 — AI Platform & Infrastructure
**Objective:** Build the safe AI platform before any assistant behavior.
- [ ] AI Gateway (ADR-005): capability slots (text, vision, embedding), multi-provider adapters (OpenAI, Gemini), model registry, deterministic-first task/model routing (ADR-023), BYOK-readiness (envelope encryption, write-only, client never sees secrets).
- [ ] Capability-based Tool Registry (ADR-007): schema-validated tools, server-injected user identity (zero user ID in tool parameters), bounded outputs, audit logging.
- [ ] AI Context Engine (ADR-019): information-need planning (Tiers 0–4), Snapshot-first retrieval, structured queries, AI Data Budget enforcement (ADR-020).
- [ ] AI Traceability (ADR-022): content-minimized AI Trace Records and AI Usage Ledger.
- [ ] AI Evaluation harness & golden datasets skeleton (§31.2).

---

## Phase 4 — AI Assistant & Controlled Actions
**Objective:** Grounded, safe, personalized conversational assistant.
- [ ] Conversation & memory domain: message history, durable user-editable memory with provenance.
- [ ] Safety classification & response modes (§10.6.1: Wellness, Nutrition, Educational, Concern-signal redirect).
- [ ] Propose → Confirm → Commit protocol (ADR-008): model emits proposals, user confirms out-of-band via UI, persistent receipts required for persistent claims.
- [ ] Anti-hallucination guardrails (§10.8): sufficiency gating, numeric provenance validation against tool results, structured response envelope with evidence tags.
- [ ] Flutter Assistant interface: streaming responses, rich widgets, evidence pills ("based on"), proposal confirmation cards.

---

## Phase 5 — Multimodal & Image Intelligence
**Objective:** Photo/report to reviewed, verified, provenance-backed structured data.
- [ ] Private media pipeline: upload, EXIF stripping, MIME inspection, private storage, user-controlled retention.
- [ ] Vision extraction engine: body-composition reports, smart scale displays, tape measurement sheets.
- [ ] Extraction Draft workflow: catalog mapping, plausibility & consistency validation, per-field confidence scoring.
- [ ] Adaptive-intensity review UI: side-by-side inspection, per-field edit/approval, commit as Measurement Session with image provenance.

---

## Phase 6 — Hardening, Quality Gates & Verification
**Objective:** End-to-end verification across all RFC 2119 quality gates.
- [ ] Cross-user security isolation test suite.
- [ ] AI Red-team suite (direct/indirect injection, data exfiltration, tool abuse, safety bypasses).
- [ ] AI grounding & numeric fidelity regression tests on golden datasets.
- [ ] End-to-end privacy export and deletion verification across all modules.
- [ ] RTL/LTR visual regression and accessibility verification.
- [ ] Performance and budget adherence audit.
