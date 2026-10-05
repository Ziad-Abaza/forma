# agent.md — Strict Execution Constitution for Forma

> **This file is law, not a suggestion.** Read it completely before any work, and reread it at the beginning of every phase and whenever there is any uncertainty. The only binding architectural reference is `PRODUCT_ARCHITECTURE_BLUEPRINT.md` (v1.1). In case of conflict: **Blueprint > this file > your own judgment**. Any deviation from the Blueprint requires a recorded ADR. MUST / MUST NOT / SHOULD have their RFC 2119 meanings.

---

## 0. Identity & Mission

* **Product:** Forma — a personal AI-powered fitness and wellness companion. A multi-user health data platform with AI as a layer on top of it.
* **Deliverables:** Flutter application (iOS + Android) + Node.js/TypeScript backend (modular monolith: API process and Worker process from the same codebase) + PostgreSQL (+ pgvector only when demonstrably necessary).
* **Languages:** **Arabic + English with full feature and content parity, supporting both RTL and LTR.**
* **Production standard:** A production-ready product, not a prototype or demo.

---

## 1. Absolute Rules (Zero Tolerance)

Violating any rule here = **task failure**. Work must immediately stop and the violation must be fixed before proceeding.

### 1.1 No Hard-Coding

* ❌ No hard-coded values for: URLs, keys, AI model names, limits, budgets, formula parameters, timeouts, magic numbers.
* ✅ All such values must come from: schema-validated environment configuration at startup, database tables/catalogs, or documented and versioned registries.
* ❌ No UI strings written directly in code. All strings must use message catalogs (ARB/ICU) with **both Arabic and English translations**.
* ❌ No translated labels stored in domain data. **Store codes; render labels** (Blueprint §19).
* ❌ No scattered colors, spacing, or typography values. Use centralized design tokens only.
* ✅ Any project constant (such as physical constants or unit-conversion parameters) must exist in one named, tested location (Unit Registry / Calculation Engine) with its reference.

### 1.2 No Mocks or Fake Data in the Product

* ❌ No `mock`, `fake`, `dummy`, `stub`, `lorem ipsum`, `TODO: implement`, `placeholder`, or embedded sample data in production screens, services, or routes.
* ❌ No temporary `return []`, `return {}`, `Future.value(...)`, or equivalent implementations pretending to work.
* ❌ No screen may display fabricated numbers merely to appear populated. A truthful, carefully designed empty state is the correct behavior (Blueprint §18.1).
* ❌ No disabled tests (`skip`, `xit`, `@Ignore`, or equivalent) to make the build pass.
* ✅ **The only permitted exception:** deterministic *test doubles* for external providers **inside test directories only**, for unit/contract tests (Blueprint §29 Testability). They MUST never be imported by production code.
* ✅ Real integration tests against real PostgreSQL (Testcontainers or equivalent) are required, as well as real integration tests against a real AI provider (see §4).
* ✅ Permitted seed data: **real reference catalogs only** (measurement types, units, goal definitions) through migrations — no fake users or fake measurements outside isolated test/development environments, and such data must be explicitly marked.

### 1.3 No Secrets in Code

* ❌ No key/token/password in source code, commits, logs, prompts, error messages, crash reports, or the Flutter application.
* ❌ **No AI key may ever exist inside the Flutter application.** The client must never communicate directly with an AI provider (Blueprint §20.5, §24).
* ✅ Secrets must be read from the environment (`process.env` through validated configuration) and injected at runtime.
* ✅ Provide `.env.example` containing variable names only and no real values.

### 1.4 No Quality Cheating

* ❌ Never claim "finished" without evidence. Completion = code + green tests + verified actual execution.
* ❌ Never modify tests merely to accommodate incorrect code; fix the code.
* ❌ No `any` in TypeScript, no unjustified `dynamic` in Dart, no `// @ts-ignore`, and no Dart `// ignore:` without a justification comment linked to an ADR.
* ❌ No empty `catch`, silent error swallowing, `console.log`, or `print` in production. Use structured, sanitized logging.

---

## 2. Architectural Invariants from Blueprint §32

These MUST NOT be violated under any circumstances, and each MUST have an automated test:

1. **AI has no direct database access.** It uses only a strict-schema *Tool Registry*. Identity is injected by the server; no tool schema may contain a `userId` parameter.
2. **No AI value enters the health record without user approval** (Propose → Confirm → Commit with receipt). Write success is determined by the receipt, not by what the model claims.
3. **Facts are never overwritten.** Append-only; correction = supersession/void while preserving history. No `UPDATE`/`DELETE` path for facts outside approved workflows.
4. **Calculations and safety rules live in code, not prompts.** The LLM must not calculate BMI/BMR/TDEE or determine safety limits.
5. **Every value has provenance and confidence.** No record-creation path may exist without provenance, enforced at the data layer.
6. **Double user isolation:** centralized ownership checks in the application + Row-Level Security (or equivalent) in the database. This includes endpoints, tools, jobs, caches, embeddings, and files.
7. **Every quantity is converted to its canonical unit at system boundaries while preserving the original value.** Never guess when ambiguity exists.
8. **Derived data never overwrites its source**, and any source change invalidates derived data through lineage. Health Snapshot must not drift from recalculation.
9. **AI context is built only through the AI Context Engine under an enforced AI Data Budget.** No module may feed the model outside this path.
10. **Every significant AI operation produces a trace free of health content and secrets.**
11. **Estimates must never be displayed, stored, or represented as measurements.** `measured / calculated / estimated / AI-generated` must remain visually and logically distinct.
12. **Domain modules must not import any AI-provider SDK.** Provider-specific code belongs exclusively inside gateway adapters.
13. **Health content must not appear in logs or analytics by default.**
14. **Every module implements both export and delete contracts.**
15. **Dashboard Estimates/AI Insights are precomputed and cached.** No screen may require a live AI call merely to render.

---

## 3. Methodology: Phased Execution Without Exception

Blueprint §32.1 prohibits uncontrolled one-pass implementation. The execution layers are:

**Phase 1** Foundation, identity, and health data
→ **Phase 2** Measurements, goals, calculations, Snapshot, Dashboard (useful product without AI)
→ **Phase 3** AI platform (Gateway, Tool Registry, Context Engine, Budget, Traces, Eval Harness)
→ **Phase 4** Assistant and controlled actions
→ **Phase 5** Images and multimodal capabilities
→ **Phase 6** Security/performance/evaluation hardening
→ **Phase 7** Production readiness.

### Phase Rules

1. **Do not start features from a phase until the previous phase's Exit Criteria have been verified** with executed evidence, not claims.
2. At the beginning of every phase, create `docs/phases/phase-N-plan.md` containing: objectives, modules, required tests, and Exit Criteria.
3. At the end of every phase, create `docs/phases/phase-N-report.md` containing: what was built, actual test output, passed quality gates, decisions (ADRs), declared technical debt, and what was honestly not completed.
4. **Stop after every phase**, present the report, and wait for user confirmation before continuing unless the user explicitly instructs continuous execution.
5. **Scope Guardrail (§27.3):** A feature may be introduced only if its absence breaks a critical J1–J11 journey or a security/privacy requirement. No placeholder tables, UI, or tools for future domains (nutrition, exercises, wearables, progressive photos) — only contractual seams through registries (§27.2).

---

## 4. Use of `GEMINI.txt` and API Keys (Strict Rules)

The file contains a real Gemini key. Handle it exactly as follows:

1. **Immediately add `GEMINI.txt` and `.env*` (except `.env.example`) to `.gitignore`, before any commit.** The current file does not exclude it.
2. **Never copy the key value** into any source file, test, documentation, commit message, persisted terminal output, or prompt.
3. Read the key once into the local untracked `.env` under `GEMINI_API_KEY`, then read it only from the environment. Documentation must use `GEMINI_API_KEY=<your-key>`.
4. When printing logs or test results: **always mask keys**. Add an automated scrubbing test that fails if a key pattern appears in logs/traces/errors.
5. **Never include the key in Flutter.** Provider communication happens through the server-side AI Gateway only.
6. **Allowed uses:** connectivity testing, model availability verification, real gateway integration tests, and small eval suites. **Do not** use it for large loops that consume quota. Respect the AI Data Budget and record usage.
7. **Never hard-code a model name.** Discover available models through the official ListModels interface during inspection, record the result in an ADR, and place the selected model in configuration/model registry. Consult current official Google documentation; do not rely on memory.
8. Implement **at least two independent text-capability adapters** (Blueprint §27.1) to prove gateway abstraction. Use Gemini as one adapter (real, using the available key). Build the second using an OpenAI-compatible specification and enable it when a key is available. Without a key, test it contractually using a deterministic test double inside the test directory only, and document honestly that it was not live-tested.
9. If real connectivity fails (quota, network, invalid key): **do not switch to a mock to hide the failure.** Report the actual failure, implement the degradation behavior defined in §22.1, and continue with work that does not depend on AI.

> **User warning (must appear in the first report):** The key is exposed in a text file inside the packaged repository; rotating it from the Google console after development is strongly recommended.

---

## 5. Code & Engineering Standards

### 5.1 Backend (Node.js + TypeScript)

* `strict: true` with all strict flags (`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, etc.).
* **Contract-first:** One source of truth for API contracts and tool schemas (e.g. Zod/JSON Schema/OpenAPI generated), used for server validation and Dart client generation/validation, with no drift.
* Module boundaries enforced through *architecture tests* (dependency-cruiser or equivalent) that fail in CI.
* Unified error model that does not leak internal details; `correlation-id` propagated through API → assistant → tools → gateway.
* Idempotency keys on writes; retry with backoff; dead-letter handling for jobs; broker-independent job abstraction (Postgres-backed initially).
* Database migrations must be replayable and safe; no manual schema changes; indexes must be based on inspected query plans (`EXPLAIN`).
* Numeric representation must preserve round-trip precision for units; no naive floating-point arithmetic where precision matters.

### 5.2 Flutter Application

* `flutter analyze` with zero warnings; strict lints; complete null-safety.

* Clear layered architecture (`presentation / domain / data`), dependency injection, and one consistent state-management approach. Choice is flexible but MUST be recorded in an ADR.

* **Offline-tolerant:** immediately render locally cached data; queue writes with safe conflict synchronization; no blocking spinner for AI-dependent surfaces.

* Store tokens using platform secure storage. No health data in logs, crash reports, or analytics.

* **Language and direction:** the application MUST fully support **Arabic and English** with complete feature parity.

  * All UI text MUST exist in both Arabic and English message catalogs.
  * The application MUST dynamically support both **RTL and LTR** layouts.
  * Use logical layout properties (`start/end`) rather than hard-coded `left/right`.
  * Use a deliberate Arabic font paired appropriately with the Latin font; do not rely on accidental fallback.
  * Mixed Arabic/Latin text must be directionally safe.
  * Number formatting preferences (Western/Arabic-Indic digits) must apply consistently to text and charts.
  * Date, time, number, unit, and plural formatting MUST use locale-aware formatting.
  * Language switching MUST work without requiring a reinstall and MUST update the UI direction appropriately.
  * The selected language must persist across application restarts.
  * Arabic and English must receive equal functional coverage; no feature may be implemented only in one language.
  * Accessibility labels, validation errors, empty states, notifications, permissions, dialogs, and system-facing UI text MUST also be localized.
  * AI responses MUST follow the user's current language and support switching language during a conversation.
  * AI image/document extraction MUST support both Arabic and English, including Arabic-Indic digits.
  * Localization tests MUST verify both Arabic/RTL and English/LTR paths.

* **Mandatory designed states (§18.3):**

  * New user
  * Insufficient data
  * Offline
  * AI unavailable/degraded
  * Extraction in progress/failed/low confidence
  * Pending proposal
  * Quota exceeded
  * Misconfigured provider
  * Camera permission denied
  * Account deletion pending

### 5.3 Database

* PostgreSQL with RLS enabled for owner-scoped tables, with automated tests proving that the application role cannot bypass them.
* Fact tables must be append-only by design; supersession/void with lineage.
* pgvector only when measurement proves its necessity, with an ADR containing quantitative evidence. All embedding vectors must be owner-filtered at query level.

### 5.4 Security (Mandatory for Release, Blueprint §20)

* Passwords hashed using a memory-hard algorithm (Argon2id), compromised-password screening, short-lived access tokens + rotating refresh tokens with reuse detection and session-family revocation.
* Email verification required before AI and export features; recovery through single-use expiring tokens.
* Multi-layer rate limiting (IP, user, endpoint, AI); strict input validation; size limits and pagination.
* Defense against direct and indirect prompt injection: separate instruction channels from data, mark untrusted content, confirm actions outside the model, sanitize model-generated links/images, and never provide a tool with unrestricted network access.
* BYOK encryption at application level (envelope encryption), write-only keys, and SSRF allowlist. (User-facing BYOK UI deferred to Phase 6; gateway readiness exists from the beginning.)
* Private files, short-lived signed URLs, image re-encoding, EXIF stripping.
* Append-only audit log free of health values.

### 5.5 Artificial Intelligence (Blueprint §10–13)

* **AI Context Engine:** Tiers 0–4, Snapshot-first, structured queries first, semantic retrieval only when necessary, with a manifest for every context.
* **AI Data Budget:** record/depth/tool-call/round/token/time/image limits enforced outside the model. Exhaustion produces explicit, tested degradation.
* **Safety classification (§10.6.1):** implemented in policy/calculation layers, not prompts alone, including response modes, eating-disorder support, calorie guardrails, and maximum weekly-rate limits.
* **Anti-hallucination (§10.8):** sufficiency gate, provenance checks for numbers, evidence-type labeling, action-claim linkage to receipts, and a respectful "I don't have enough information" behavior.
* **Image extraction:** always produces a draft requiring review, with confidence per field, plausibility/consistency checks, and never automatic persistence. Supports Arabic and English and Arabic-Indic digits.
* Responses must use the user's current language, with language switching supported during conversations.

---

## 6. Testing & Quality Gates (Non-Negotiable)

No phase is considered complete without passing all applicable gates from Blueprint §31.1:

1. **Isolation:** cross-user access tests for every endpoint, tool, function, and retrieval path.
2. **AI Safety:** red-team tests (direct/indirect injection, leakage, tool abuse, jailbreaks, unsafe advice); no writes without confirmation.
3. **AI Grounding:** numerical faithfulness and correct abstention when data is missing, contradictory, or stale.
4. **Extraction:** accuracy and calibration on a bilingual report dataset.
5. **Calculation:** reference-value tests + property-based testing for every formula version and safety boundaries.
6. **Provenance:** no creation path without provenance; supersession tests proving history preservation.
7. **Privacy:** export and deletion completeness, including embeddings, files, caches, and derived data.
8. **Security:** clean SAST, dependency, and secret scans.
9. **Localization/A11y:** RTL/LTR visual regression, screen-reader support, text scaling, and Arabic-content review.
10. **Performance/Cost:** performance and cost budgets per role.
11. **Resilience:** provider outage and database failure simulation.
12. **Observability:** signals, alerts, and runbooks; automated log-sanitization tests.
13. **Architecture:** module-boundary tests; current ADRs.
14. **Traceability & Budget:** every AI operation type emits a compliant trace; tests prove no secrets/health content exist in traces.
15. **Units/Lineage/Snapshot:** round-trip conversion, unit ambiguity, cascading invalidation, and Snapshot equivalence with recalculation.
16. **Localization Parity:** every user-facing feature, screen, state, validation path, notification, and AI interaction MUST be tested in both Arabic/RTL and English/LTR.

**Test suite:** unit + property-based (calculation engine) + contract + integration (real PostgreSQL) + e2e for critical journeys + AI evaluation (synthetic bilingual golden datasets, expected properties rather than literal text, deterministic checks first). Any change to prompts, models, routing, budgets, tool schemas, or formulas MUST trigger the relevant eval suite.

---

## 7. Truth Above Everything: Honesty Protocol

* **If you did not actually execute it, do not claim it works.** Attach actual command output, with secrets masked, to reports.
* If you cannot complete a requirement: state it explicitly in the report, explain why, and provide the proposed alternative. Honest incompleteness is better than a false completion claim.
* When ambiguity exists that the Blueprint does not resolve: choose the simplest option that preserves the invariants, record it in an ADR, and flag it for review (§32 "Handling ambiguity").
* Open questions in §33 that require business/legal decisions (residency, pricing, clinical safety limits, etc.): **do not invent an answer**. Use an explicitly stated safe assumption, record it, and add it to the "Owner Decisions Pending" list in the report.
* Never claim medical or legal review: calorie guardrails and eating-disorder content require qualified review before release — explicitly state this.

---

## 8. Documentation & Hygiene

* ADR for every significant decision (`docs/adr/NNNN-title.md`), and update ADRs whenever deviating from the Blueprint.
* Living references: API/tool contracts, eval catalog, threat model, runbooks.
* Small, atomic commits with descriptive Conventional Commit messages. Never create a commit that breaks the build.
* `README.md` must explain setup from zero using commands that actually work and have been tested.
* Docker Compose for local development (Postgres and other dependencies); production containers; initial IaC; CI runs lint, types, tests, architecture tests, scans, and evals.
* No dead files, commented-out code, or unused dependencies. Lockfiles are mandatory.
* Use the existing `logo.png` as Forma's identity (app icon/splash screen) instead of inventing a logo, and derive the color palette from it through centralized design tokens.

---

## 9. Final Checklist Before Declaring Any Task Complete (Definition of Done)

* [ ] No hard-coding, no production mocks, no TODOs, no secrets. Run automated grep/CI checks.
* [ ] All UI text exists in both Arabic and English catalogs; no embedded strings.
* [ ] Every user-facing feature has complete Arabic/RTL and English/LTR parity.
* [ ] All applicable tests are green and were actually executed; outputs are attached.
* [ ] `analyze` / `lint` / `tsc` are clean.
* [ ] Cross-user isolation tests cover everything added.
* [ ] Provenance, units, and lineage are respected in every new write path.
* [ ] Empty, loading, error, offline, and AI-disabled states are designed and tested.
* [ ] RTL/LTR behavior is tested on the relevant screens and flows.
* [ ] Localization catalogs are complete with no missing translations.
* [ ] ADRs/documentation/reports are updated.
* [ ] No absolute rule in §1 or invariant in §2 has been violated.

> **When in doubt: stop, reread the Blueprint, ask the user — and never guess about security, privacy, data integrity, or localization behavior.**
