# Changelog

All notable changes to the Forma codebase will be documented in this file.

## [Unreleased] - 2026-10-05

### Added
- **Phase 0 Discovery & Framework:**
  - Audited `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1).
  - Initialized Git version control and persistent execution tracker under `docs/implementation/`.
- **Phase 1 Foundation & Health Data Architecture:**
  - Established modular monolith backend in `backend/` with Node.js, TypeScript, and Fastify.
  - Implemented `UnitRegistry` (ADR-021) with canonical units, exact conversion factors, and input precision preservation.
  - Implemented `MeasurementCatalog` covering anthropometric, composition, and circumference types with strict biological plausibility boundaries and warning thresholds.
  - Implemented append-only `Observation` and `Provenance` domain (ADR-009, §14) with mandatory EpistemicClass (`measured`, `calculated`, `estimated`, `asserted`), non-destructive supersession, and audit-safe voiding.
  - Implemented `IdentityService` (ADR-012) with mandatory 18+ age verification gate, bcrypt password hashing, and rotating SHA-256 hashed refresh tokens.
  - Implemented `ProfileService` with calculation snapshot versioning for reproducible historical math.
  - Implemented `PrivacyContract` and `PrivacyManager` module interfaces for GDPR-compliant export and purge.
  - Implemented content-minimized `AuditService` (ADR-009, §20.9).
  - Initialized cross-platform Flutter project in `mobile/`.
- **Phase 2 Core Health Domain, Analytics, Calculations & Dashboard:**
  - Implemented `CalculationEngine` (ADR-010): versioned BMI, BMR (Mifflin-St Jeor & Katch-McArdle), TDEE, Calorie Targets, and Macronutrient splits.
  - Implemented hard safety guardrails (minimum calorie floor: 1500 kcal male / 1200 kcal female; max safe loss rate: 1.0 kg/week; max deficit clamp: 1000 kcal).
  - Implemented `AnalyticsService` for time-series trend smoothing (moving average), weekly rates of change, and sudden outlier/anomaly detection.
  - Implemented versioned `GoalService` (ADR-009) supporting weight, composition, and target metrics with temporal progress tracking.
  - Implemented `SnapshotEngine` (ADR-019, §7.8) with granular sections, watermarks, data sufficiency, and drift reconciliation.
  - Implemented `DashboardService` (ADR-003, §18.1) for deterministic widget composition directly from Health Snapshot.
- **Phase 3 AI Platform & Infrastructure:**
  - Implemented `AiGateway` (ADR-005) with capability slots, multi-provider adapters (OpenAI, Gemini), BYOK envelope encryption (AES-256-GCM), and deterministic-first task routing (ADR-023).
  - Implemented `ToolRegistry` (ADR-007) with schema validation and server-injected user context.
  - Implemented `AiContextEngine` (ADR-019) with Tier 0–4 context planning and context manifest generation.
  - Implemented content-free `AiTraceService` (ADR-022) with zero sensitive health content logging.
- **Phase 4 AI Assistant & Controlled Actions:**
  - Implemented `ActionProtocolService` (ADR-008) for Propose -> Confirm -> Commit workflow with single-use tokens and `ActionReceipt` guarantees.
  - Implemented `SafetyClassifier` (§10.6.1) for medical concern-signal detection and emergency guidance redirection in English and Arabic.
  - Implemented `OutputValidator` (§10.8) for anti-hallucination numeric grounding against tool outputs.
- **Phase 5 Multimodal Intelligence:**
  - Implemented `ExtractionService` (ADR-011, §13) with Draft creation, plausibility/confidence validation, and Measurement Session commit with image provenance.
- **Phase 6 Quality & Security Verification:**
  - Implemented cross-tenant isolation security tests (`src/eval/isolation.test.ts`).
  - Successfully verified TypeScript compilation (`tsc`, 0 errors), 39/39 passing unit tests, and Flutter test suite.
