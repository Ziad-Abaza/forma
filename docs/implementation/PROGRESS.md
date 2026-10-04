# Implementation Progress Checklist

## Phase 0 — Architecture & Specification
- [x] Read and cross-reference `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1)
- [x] Verify host environment runtimes (Node 24, npm 11, Flutter 3.47, Dart 3.13, Git)
- [x] Initialize Git repository
- [x] Create persistent state tracking system in `docs/implementation/`

## Phase 1 — Foundation, Identity, Profile & Core Health Data
- [ ] Backend Architecture & Monorepo Setup
  - [ ] Initialize `backend/` with Node.js, TypeScript, ESLint, Vitest/Jest
  - [ ] Module boundaries enforcement structure (`src/modules/{identity,profile,measurements,goals,calculations,analytics,provenance,media,privacy,audit}`)
  - [ ] Database client & migration runner (PostgreSQL with pgvector readiness)
- [ ] Core Health Data Foundation
  - [ ] Unit Registry & Canonical Normalization Engine (ADR-021)
  - [ ] Measurement Type Catalog (weight, body fat, muscle mass, circumferences, etc.)
  - [ ] Append-only Observations schema with Provenance & Epistemic class (ADR-009, §14)
  - [ ] Supersession, correction, and voiding mechanisms
- [ ] Identity & Security Domain
  - [ ] User & Credential models with memory-hard password hashing
  - [ ] Age verification gate (18+)
  - [ ] Rotating refresh token & device session management (ADR-012)
  - [ ] Consent tracking (health processing + third-party AI processing)
  - [ ] Request authentication & tenant context injection (defense-in-depth, ADR-013)
- [ ] Profile Domain
  - [ ] Profile model with versioned calculation attributes (height, sex-for-calc, DOB, activity)
  - [ ] Extensible key-value attribute definitions
- [ ] Privacy & Audit Foundation
  - [ ] Module export/delete contracts interface
  - [ ] Content-minimized audit logging
- [ ] Mobile Foundation
  - [ ] Flutter workspace initialization (`mobile/`)
  - [ ] Multi-language structure (Arabic & English with RTL/LTR)
  - [ ] Theme & design system tokens
  - [ ] Secure storage for tokens

## Phase 2 — Core Health Domain, Analytics, Calculations & Dashboard
- [ ] Deterministic Calculation Engine (ADR-010)
  - [ ] BMI, BMR, TDEE, Calorie Maintenance formulas with versions
  - [ ] Deficit/Surplus & Macronutrient target ranges
  - [ ] Hard safety guardrails (calorie floors, rate caps, special population warnings)
- [ ] Time-Series Analytics & Trends
  - [ ] Canonical rollups (daily/weekly/monthly) and series aggregation semantics
  - [ ] Noise-robust trend smoothing & rate-of-change calculation
  - [ ] Anomaly & outlier detection flags
- [ ] Goal Domain
  - [ ] Versioned goal model with baselines and deadlines
  - [ ] Goal progress evaluation against active goal version
- [ ] Health Snapshot Engine (ADR-019, §7.8)
  - [ ] Materialized derived snapshot generation
  - [ ] Lineage-driven invalidation (ADR-024)
  - [ ] Reconciliation & drift detection
- [ ] Dashboard Domain
  - [ ] Widget composition contracts & resolvers
- [ ] Flutter Core Features
  - [ ] Onboarding & auth flows
  - [ ] Manual measurement logging with unit conversions
  - [ ] Goal management & progress visualization
  - [ ] Health dashboard with interactive charts

## Phase 3 — AI Platform & Infrastructure
- [ ] AI Gateway (ADR-005)
  - [ ] Provider abstraction & capability slots (text, vision, embedding)
  - [ ] Provider adapters (OpenAI, Gemini)
  - [ ] Model registry & task/model router (ADR-023)
  - [ ] BYOK secret envelope encryption & credential resolution (ADR-018)
  - [ ] AI Usage Ledger
- [ ] Capability-based Tool Registry (ADR-007)
  - [ ] Schema-validated tools with server-injected user identity
  - [ ] Read tools (snapshot, observations, calculations, goals)
  - [ ] Tool execution audit & error handling
- [ ] AI Context Engine & Budget (ADR-019, ADR-020)
  - [ ] Tiers 0–4 context planning
  - [ ] AI Data Budget enforcement & degradation ladder
  - [ ] Context manifest generator
- [ ] AI Traceability (ADR-022)
  - [ ] Content-free AI Trace Records
- [ ] AI Evaluation Harness (§31.2)
  - [ ] Golden dataset regression test suite runner

## Phase 4 — AI Assistant & Controlled Actions
- [ ] Conversation & Memory Domain
  - [ ] Message history & rolling summaries
  - [ ] Durable assistant memory with provenance and UI visibility
- [ ] Safety Classification Engine (§10.6.1)
  - [ ] Wellness, Nutrition, Educational, Concern-signal redirect
- [ ] Propose → Confirm → Commit Protocol (ADR-008)
  - [ ] Action proposals with human-readable diffs & single-use tokens
  - [ ] Out-of-band user confirmation UI
  - [ ] Persistence execution & Action Receipts
- [ ] Anti-Hallucination & Output Verification (§10.8)
  - [ ] Numeric provenance checking against tool outputs
  - [ ] Evidence-type tags (retrieved, calculated, estimated, inferred)
- [ ] Flutter Assistant UI
  - [ ] Chat interface with streaming support
  - [ ] Rich response widgets, "based on" evidence inspect, action proposal cards

## Phase 5 — Multimodal Intelligence
- [ ] Media Pipeline
  - [ ] Private object storage abstraction, EXIF stripping, MIME validation
- [ ] Vision Extraction Engine
  - [ ] Body-composition report & scale display structured extraction
  - [ ] Plausibility range & consistency validation
  - [ ] Per-field confidence scoring
- [ ] Extraction Draft & Review UX
  - [ ] Draft creation & side-by-side review UI
  - [ ] Commit to Measurement Session with provenance

## Phase 6 & 7 — Hardening & Operational Readiness
- [ ] Automated cross-user isolation test suite
- [ ] AI red-team & prompt-injection security tests
- [ ] End-to-end privacy export and erasure verification
- [ ] RTL/LTR and accessibility audits
- [ ] Final quality gates sign-off
