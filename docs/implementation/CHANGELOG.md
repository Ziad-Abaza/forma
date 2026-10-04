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
