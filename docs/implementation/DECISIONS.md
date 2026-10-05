---
noteId: "058ded10c07511f189a7cbfc9e7e0854"
tags: []

---

# Architectural Decisions (ADRs & Resolutions)

## ADR-0001: Monorepo Architecture & Modular Monolith
Preserved backend as modular monolith and mobile Flutter app in `mobile/`.

## ADR-0002: Gemini Discovery & Selection
Primary vision and conversational tasks routed through official Google Generative Language endpoints.

## ADR-0003: AI Configuration & BYOK Management Flow
- Server manages user-scoped BYOK encryption (AES-256-GCM) in `user_ai_credentials`.
- Endpoints exposed under `/api/v1/ai/config` and `/api/v1/ai/credentials`.
- Client submits write-only key; server never returns plaintext key, only masked fingerprint `...1234`.
- Client Settings UI allows switching between system provider and BYOK.

## ADR-0004: Multimodal Workflow Access
- Camera / Photo trigger integrated directly on `DashboardScreen` and `MeasurementsSection`.
- Generates extraction draft on backend, opens `MultimodalReviewScreen` where user reviews field values, flags, and confidence, and commits with provenance.

## ADR-0005: Out-of-Scope Wearable Sync Scope Correction
- Per Blueprint §27.2 and §27.3, wearables UI is out-of-scope for the initial release.
- Replaced the prominent Sync button on Dashboard with a comprehensive **Settings** action.
- Privacy controls (GDPR export and account purge) moved to the Settings screen.
