# Product Architecture Blueprint

**Product (Forma):** Personal AI Fitness & Wellness Companion
**Document status:** Authoritative architecture reference for the implementation agent
**Normative language:** MUST / MUST NOT / SHOULD / MAY are used in the RFC 2119 sense.
**Revision:** 1.1 — integrates the architectural review (AI Context Engine, Health Snapshot, AI Data Budget, canonical units, lineage, time-series, traceability, evaluation, progress photos, integration readiness, explicit phases). Appendix A lists every change and every contradiction resolved. Section numbers of v1.0 are preserved; new material is added as subsections.

---

## 1. Executive Summary

The product is a **multi-user personal health and fitness data platform with an AI interaction layer**. Its center of gravity is the user's *own structured, historical, provenance-tracked data*: profile, body measurements, body composition, goals, and (later) nutrition and training. A personal AI assistant sits on top of that data and can answer questions, explain calculations, read documents and images, and, with explicit user confirmation, write data back.

Five decisions define the whole system:

1. **Data is the product; AI is a layer on top.** Business truth lives in an append-only, provenance-aware data model and a deterministic calculation engine. The LLM never owns truth. It retrieves, explains, extracts, and proposes.
2. **The AI has no database access.** It can only call a small catalog of approved, user-scoped, schema-validated capabilities. User identity is injected by the server, never supplied by the model.
3. **Context is decided, not dumped.** An **AI Context Engine** determines what information a request actually needs and supplies the *smallest sufficient* context: usually a compact **Health Snapshot**, sometimes targeted structured queries, and semantic retrieval only when genuinely necessary — always inside an explicit **AI Data Budget**. RAG is one tool of the engine, not the architecture.
4. **Every important value knows where it came from.** Provenance and confidence are first-class, and AI-extracted data is always a *draft* until the user approves it.
5. **Modular monolith, provider-independent AI, future-ready domains.** One deployable backend with strict internal module boundaries, an AI gateway that abstracts providers, and domain seams reserved for nutrition and workouts.

The initial release delivers: accounts, profile, historical measurements on a canonical-unit time-series foundation, goals, deterministic fitness calculations, progress analytics, a Health Snapshot, dashboard, a context-aware AI assistant (Context Engine, AI Data Budget, task/model routing, AI traceability), image-to-structured-data extraction with review, a provider-agnostic AI gateway that is BYOK-ready, an AI evaluation harness, security/privacy controls, and Arabic/English with RTL/LTR. Implementation is **staged** (§32.1). Workouts, full nutrition, wearables, and advanced vision are architecturally prepared, not built.

---

## 2. Product Vision

> A personal digital health and fitness companion that understands the user's history, current condition, goals, progress, and preferences, and can intelligently analyze that information and provide personalized guidance.

What it is not: a tracker, a calorie calculator, a chatbot, a CRUD app, a dashboard, or an AI wrapper. It is a **unified personal health data platform** whose intelligence is *grounded* in that data.

**Experience tenets**

- *It remembers.* The user never re-enters what the system already knows.
- *It shows its work.* Numbers are traceable to a source or a formula.
- *It is honest about uncertainty.* "I don't have enough information" is a valid, respected answer.
- *It never surprises the user with writes.* Nothing is saved without the user's awareness.
- *It is calm.* Health data is emotional. Tone is supportive and factual, not alarmist or gamified.

---

## 3. Product Goals

| # | Goal | Measure of success (reviewable) |
|---|------|--------------------------------|
| G1 | Give users a trustworthy longitudinal record of body measurements | No overwrite of history; every value has source, unit, timestamp |
| G2 | Turn raw data into understandable progress | Trends, rates, goal progress available for any tracked metric with sufficient data |
| G3 | Provide a personalized AI assistant grounded in user data | Numeric claims in AI answers trace to retrieved data or calculations |
| G4 | Reduce data-entry friction through images | Report photo → reviewed, saved measurements with provenance |
| G5 | Protect sensitive health data | Zero cross-user access paths; AI cannot bypass authorization |
| G6 | Stay provider-independent and cost-controlled | Provider swap requires no domain changes; per-user usage limits enforced |
| G7 | Be extensible without rework | Nutrition/workout domains attach via defined seams, not schema rewrites |

**Non-goals (initial release):** medical diagnosis, treatment advice, social/community features, marketplace, coach-to-client multi-tenancy, workout logging, food logging, wearable sync.

---

## 4. Product Scope

Scope is defined authoritatively in §27 (Initial Release) and §28 (Future Scope). Summary rule: **a capability is "in scope now" only if the initial product feels incomplete or unsafe without it.** Everything else gets an architectural seam (a named boundary, an extensible type, a reserved concept) and no implementation.

---

## 5. User Personas / Usage Context

**P1 — The Self-Tracker (primary).** Weighs in weekly, measures body composition at a gym or with a smart scale, wants to know "am I actually progressing?" Cares about trends, not single readings.

**P2 — The Goal-Driven Beginner.** Wants a calorie target and plain-language guidance. Low data literacy; needs explanation and safe defaults.

**P3 — The Experienced Lifter.** Tracks circumferences and composition, wants comparisons across periods and recomposition insight; will later expect full workout tracking.

**P4 — The Document Photographer.** Doesn't want to type. Photographs an InBody-style printout or a scale display and expects extraction.

**Usage context.** Mobile-first, often one-handed, often at a gym or at home in the morning; intermittent connectivity; Arabic and English speakers; sessions are short and frequent. Data is entered rarely (weekly/monthly) but consulted often.

**Assumed risk posture.** Users may be vulnerable to disordered eating or unhealthy goals. The product MUST NOT encourage extreme restriction (see §10.6, §15.5).

---

## 6. Core Capabilities

| Domain | Capability summary | Release |
|---|---|---|
| Identity & Account | Registration, login, sessions/devices, recovery, verification, deletion, export, privacy controls | Initial |
| Profile | Flexible, minimal, extensible personal attributes | Initial |
| Measurements | Historical, typed, unit-aware, provenance-tracked body data | Initial |
| Goals | Evolving, versioned, multi-type goals | Initial |
| Progress & Analytics | Trends, deltas, period comparison, anomaly flags | Initial |
| Calculation Engine | Deterministic BMI/BMR/TDEE/targets/projections | Initial |
| AI Assistant | Conversational analysis, explanation, extraction, proposed actions | Initial |
| AI Context Engine & Health Snapshot | Smallest-sufficient-context planning; compact current-state representation; AI Data Budget | Initial |
| Units & Time Series | Canonical units, normalization, historical/aggregated series | Initial |
| AI Traceability & Evaluation | Content-minimized AI trace records; golden-dataset regression harness | Initial |
| AI Provider Gateway | Multi-provider, BYOK, fallback, limits | Initial |
| Multimodal | Image/document → structured draft → review → save | Initial |
| Provenance | Source and confidence on important records | Initial |
| Dashboard | Modular personalized overview | Initial |
| Localization | ar/en, RTL/LTR, locale-aware formatting & AI language | Initial |
| Notifications | Reminder foundation | Foundation only |
| Nutrition | Food/meal/targets tracking | Prepared |
| Workouts | Exercise library, plans, logs | Prepared |
| Devices/Wearables/Sleep/Recovery | Integrations & new metric types | Prepared |
| Progress Photos | Private, access-controlled visual timeline; visual estimates kept distinct from measurements | Prepared (§28.2) |

---

## 7. Domain Model

This is a conceptual model. Names are indicative; the implementation agent chooses physical schemas.

### 7.1 Core principles

- **Append-only facts.** Measurements and other health observations are never overwritten. A "correction" is a new record that supersedes the old one; the old one remains for audit and trend integrity.
- **Typed, catalog-driven.** New measurement kinds are added as catalog entries, not schema changes.
- **Canonical storage, localized presentation.** Values are stored in canonical units; display units are a presentation concern.
- **Separation of layers** (see §7.4) and **explicit lineage** between them (§7.6).
- **Canonical units** for every quantity, with the original input preserved (§7.5).
- **Time-series thinking** for every health fact (§7.7).
- **"Delete" semantics under append-only.** User-visible deletion of a fact means *voiding* it (status `rejected/voided`, excluded from analytics and AI context, retained for audit and lineage integrity). Physical erasure happens only through the account/privacy deletion flows (§21) or a documented erasure request. This reconciles "append-only" with the user's right to remove data.
- **Everything is user-owned.** Every user-data record carries an owner; no shared mutable user data exists.

### 7.2 Entities and relationships

**Account domain**
- **User** — identity, status, locale/units preferences reference, consent state.
- **Credential** — authentication factors (password hash, linked external identities).
- **Session/Device** — a refreshable login bound to a device; individually revocable.
- **Consent record** — what the user agreed to, version, timestamp (including AI third-party processing consent).

**Profile domain**
- **Profile** — one per user. Stable core attributes: date of birth, sex-for-calculation (optional, with a "prefer not to say" path and documented calculation fallbacks), height, activity level, experience, training frequency, preferences, constraints (e.g., injuries, dietary restrictions *as user-stated free text/tags*).
- **Profile Attribute (extensible)** — typed key/value extension mechanism with its own versioned definitions, so future attributes do not require migrations of core structures.
- **Profile history** — changes to calculation-relevant attributes (e.g., height, activity level) are time-versioned, because past calculations must remain reproducible.

**Measurement domain**
- **Measurement Type (catalog)** — code, category (anthropometric, composition, circumference, other), canonical unit, allowed units, plausible range, laterality (left/right/both where relevant), whether it is user-enterable, whether it is derived.
- **Observation** — one measured value: user, type, value, canonical unit, original value, original unit and input precision as entered (§7.5), *observed-at* (instant or interval) distinct from *recorded-at* (when it was saved), time-zone context, a mandatory provenance reference (**confidence and epistemic class live in provenance, not duplicated on the observation**), quality flags (e.g., outlier, unit-inferred, duplicate-suspect), supersedes/superseded-by link, status (active, superseded, voided).
- **Measurement Session (grouping)** — optional grouping of observations taken together (e.g., one scale report), preserving co-measurement context and the shared source.

**Goal domain**
- **Goal** — user, type (weight loss, fat loss, weight gain, muscle gain, recomposition, maintenance, strength, endurance, measurement-target, consistency), target specification (metric, direction, target value and/or rate, deadline optional), status (draft, active, paused, achieved, abandoned), start baseline snapshot.
- **Goal Version** — goals evolve; edits create versions so historical progress is evaluated against the goal as it was.
- A user MAY have multiple concurrent goals; exactly one MAY be designated *primary* for dashboard and default AI context.

**Derived/analytical domain**
- **Calculated Metric** — deterministic output (BMI, BMR, TDEE, targets) with formula identifier, formula version, input references, and computed-at. Reproducible.
- **Trend/Aggregate** — smoothed series, rates of change, period summaries. Recomputable from observations.
- **Insight** — an AI-authored interpretation tied to the evidence it used. Disposable and regenerable; never source of truth.
- **Recommendation** — an AI- or rule-originated suggestion, labeled as such, with the evidence and calculation references behind it and a safety classification.
- **Health Snapshot** — compact, versioned, per-user derived representation of current important state, with per-element layer, provenance/confidence, and as-of timestamps (§7.8). A read model, never a source of truth.

**Provenance & media domain**
- **Provenance Record** — origin type, origin reference, actor (user/system/AI/device), method/model/version where applicable, confidence, timestamps. See §14.
- **Source Artifact** — an uploaded image/document with storage reference, type, hash, scan status, retention policy, and ownership.
- **Extraction Draft** — AI-proposed structured data awaiting review (see §13). Not part of the health record until committed.

**AI domain**
- **Conversation / Message** — user-visible history.
- **Assistant Memory** — durable, user-visible, user-editable facts and preferences the assistant may rely on (e.g., "prefers kg", "knee injury"). Distinguished from the health record.
- **Action Proposal / Action Receipt** — a proposed write and the system-verified outcome (see §12).
- **AI Trace Record** — content-minimized, per-operation record of what happened and why: provider/model/prompt/policy versions, routing decision, context manifest, tools and calculations invoked, evidence-type composition, safety classification, budget consumption, outcome (§12.8).
- **AI Usage Ledger** — projection of trace data for metering and cost (provider, model, tokens, latency, cost estimate, outcome). Contains no health content.
- **Provider Configuration** — system-level and user-level provider settings; secrets stored separately.

**Platform domain**
- **Reminder/Notification** — minimal schedule + delivery preference (foundation).
- **Audit Event** — security-relevant and data-mutating events, content-minimized.

**Reserved seams (future)**
- **Nutrition:** Food, Serving, Meal, MealItem, NutrientTarget, FoodLogEntry.
- **Workout:** Exercise, MuscleGroup, Equipment, WorkoutPlan, WorkoutSession, SetLog, PersonalRecord.
- **Integrations:** Device, Integration Connection, Imported Batch, Raw Payload reference, External Record Identifier (for idempotent re-sync) — see §28.1.
- **Event-shaped records:** alongside Observations (values over time) and Targets/Plans (intent), the model reserves a third record shape — **Events** (something that happened, with a structured payload: workout session, meal, supplement dose, habit check-in). Same ownership, provenance, append-only, and time-series rules apply.
- **Progress media:** Progress Photo Set, Photo, capture-conditions metadata — see §28.2.
All future entities MUST reuse the same ownership, provenance, append-only, and catalog conventions.

### 7.3 Relationship chain

**User → Profile + Goals → Observations (with Provenance) → Calculated Metrics & Trends → Progress → Insights/Recommendations (AI)**

Each arrow is a one-way dependency. Raw data never depends on derived data. AI outputs never feed back into raw data without a user-confirmed write.

### 7.4 The five layers (MUST NOT be blurred)

| Layer | Nature | Authority | Stored as |
|---|---|---|---|
| Raw measurement | Observed/entered value | Source of truth | Observation |
| Calculated metric | Deterministic function of data | Authoritative, reproducible | Calculated Metric (cacheable) |
| Trend / aggregate | Statistical summary | Authoritative, recomputable | Aggregate (cacheable) |
| AI interpretation | Natural-language reading | Non-authoritative | Insight (disposable) |
| Recommendation | Suggested action | Non-authoritative, safety-checked | Recommendation |

The UI MUST visually and semantically distinguish these (e.g., "Measured", "Calculated", "Estimated", "AI insight").

**Note on the Snapshot.** The Snapshot (§7.8) is not a sixth layer: it is a *materialized composition* of elements from the layers above, each retaining its layer label. It can always be discarded and rebuilt from source data.

### 7.5 Canonical units & normalization

1. **Dimension + canonical unit.** Every Measurement Type (and, later, every nutrient, exercise metric, and sensor channel) declares a **dimension** (mass, length, energy, duration, volume, ratio/percentage, count, rate, temperature, dimensionless score, …). Each dimension has exactly one **canonical unit**, defined in a versioned **Unit Registry** that also holds permitted input/display units, exact conversion factors, and rounding/precision policy.
2. **Normalize at the boundary.** Input from *any* channel (manual, device, import, extraction, AI-proposed action) is converted to canonical form before it reaches domain logic. Calculations, analytics, retrieval, snapshot, and AI tools operate on canonical values only. No component computes on presentation units.
3. **Preserve the original.** Each observation retains as-entered value, as-entered unit, input precision (e.g., significant digits), and the registry/conversion version used, so the original can be faithfully re-displayed and conversions can be audited or re-run if the registry is ever corrected.
4. **Precision integrity.** Canonical storage MUST avoid cumulative floating-point drift and spurious precision (82 kg entered is not displayed as 82.0000001 kg). The numeric representation is an implementation choice; the guarantee is **round-trip fidelity within the input precision**.
5. **Display is a preference.** Per-dimension (and optionally per-type) unit preferences affect presentation and input defaults only; changing them never mutates data. The database is never designed around a presentation unit.
6. **Ambiguity is never silently resolved.** Missing or ambiguous units (kg vs lb in OCR'd "82"; body-fat % vs fraction; kcal vs kJ) are inferred only against plausible-range validation, flagged `unit-inferred`, shown in review, and confidence-reduced; otherwise the user is asked.
7. **Semantic compatibility.** Conversions occur only within a dimension. Percentages/ratios declare their base (e.g., body-fat % of body mass). Derived quantities declare their dimension.
8. **Extensible by registration.** A new metric within a known dimension needs only a catalog entry; a new dimension needs only a registry entry. Energy, nutrient quantities, distance, heart rate, step counts, hydration volume, and durations MUST fit without redesign (ADR-021).
9. **Time as a unit concern.** Instants are stored as absolute UTC plus the user's time-zone context; durations are canonical in seconds. Dietary energy's canonical unit is kilocalorie, with kJ as a registered conversion.

### 7.6 Data lineage

Information flows in one direction and every stage keeps its source:

| Stage | Description | Authority |
|---|---|---|
| 1. Original capture | As-entered manual input; raw device/import payload; source image/document | Source of truth (retained per retention policy) |
| 2. Normalized observation | Canonical, validated, typed record with provenance | Source of truth for analytics |
| 3. Calculated metric | Deterministic, versioned derivation | Reproducible |
| 4. Trend / aggregation | Statistical and rollup computations | Recomputable |
| 5. Snapshot | Compact composition of current state | Recomputable, non-authoritative |
| 6. AI interpretation | Natural-language reading | Disposable |
| 7. Recommendation | Suggested action | Disposable, safety-checked |

**Rules**
1. Each derived item references its inputs by identity **and** version/data-watermark. Derived data MUST NOT silently overwrite or alter upstream data.
2. Lineage is queryable **upstream** ("why is this number what it is?") and **downstream** ("what depends on this record?").
3. A correction, supersession, void, formula-version change, or unit-registry correction triggers **downstream invalidation**: dependent metrics, aggregates, and snapshot sections are recomputed as new versions; stored AI insights/recommendations that depended on superseded inputs are marked stale and are not re-presented as current.
4. Original captures are retained at least as long as the observations derived from them, unless the user deletes the artifact (the provenance pointer persists as a tombstone).
5. Lineage is metadata (identifiers and versions), not duplicated content.

### 7.7 Time-series principles

- Time is a first-class dimension of every health fact: *observed-at* (instant **or interval**), *recorded-at*, time-zone context. "Current value" is never stored as truth; it is the latest active observation or the snapshot's view of it.
- **Point and interval observations** (e.g., sleep, workouts, fasts) and **sparse and dense series** (weekly weigh-ins vs. future sensor streams) are both supported. Each catalog entry declares a **series class** and a **default aggregation semantic** (mean/last/min/max/sum…), because averaging steps or summing weight is a defect.
- **Rollups** (daily/weekly/monthly) are derived, versioned, time-zone-aware, and invalidated by late-arriving, backfilled, or corrected data.
- **Gaps are explicit.** No silent interpolation. Trend and projection methods declare minimum data span/count and report insufficiency instead of extrapolating.
- **Period comparison is like-for-like:** same aggregation, comparable windows, and reported data coverage. Multiple observations per day and irregular sampling follow a declared, user-visible per-type representative rule.
- **Dense data tier (future):** high-volume sensor data MAY live in a store suited to volume with identical ownership, provenance, and deletion semantics and retention-driven downsampling. The initial release does not build it but MUST NOT preclude it (series class, interval support, rollup abstraction).
- **Goal progress is temporal:** evaluated against the goal version in force for each period (§7.2, Goal Version).

### 7.8 Health & Fitness Snapshot

**Definition.** A compact, versioned, per-user, *derived* representation of the user's current important state. Each element carries its layer label (§7.4), provenance/confidence, and as-of time. It exists so common requests do not rebuild the user's history.

**Initial sections:** identity-lite (units, language, age band, sex-for-calculation if provided, height); body status (latest weight and trend, composition trends); goal (primary goal, version, progress, projection with uncertainty); energy (maintenance estimate, targets, assumptions, data-sufficiency); activity level; recent measurements (latest per key type, with dates); anomalies/flags; data-quality summary (coverage, staleness, share of measured vs estimated); last-updated per section. **Future sections** are registered by domains (training status, nutrition adherence, sleep/recovery, integration health).

**Consumers:** AI Context Engine (Tier 1 context, §11.1), dashboard (so the app and the assistant never disagree about the user's state), fast API reads, and data-sufficiency gating.

**Consistency guarantees**
1. Snapshot content derives only from source data and deterministic engines; nothing AI-authored enters it.
2. Each section records the **source data-version watermark** it was computed from.
3. A section is never served as current while behind the data version: it is recomputed on demand or explicitly flagged stale before use.
4. On any conflict, source data wins and the snapshot is rebuilt.
5. Writes affecting a section (observation write/supersede/void, goal change, calculation-relevant profile change, formula-version change, unit-registry correction) invalidate **only the affected sections**.
6. Scheduled reconciliation compares snapshot to recomputation; drift is an alertable defect.

**Update/recalculation strategy (outcomes, not mechanism).** Event-driven invalidation with incremental recomputation is preferred; lazy recomputation at read for rarely-active users; time-based refresh for time-dependent elements ("days since last measurement," rolling windows). The guarantee is **bounded, per-section staleness**, always visible via as-of timestamps. The mechanism is the implementation agent's choice (§33.1).

**Discipline.** Compact by design (a budget class in §11.9); offers a *summary level* for AI and a *detail level* for UI; owner-scoped; exported and deleted with the user; no raw content; the user MAY exclude sensitive sections from AI context. The Snapshot is not a cache of AI answers.

---

## 8. Domain Boundaries

The backend is a **modular monolith**. Modules own their data and expose narrow internal interfaces; no module reads another module's tables directly.

| Module | Owns | May depend on |
|---|---|---|
| `identity` | Users, credentials, sessions, consent | — |
| `profile` | Profile, attributes, preferences | identity |
| `measurements` | Catalog, observations, sessions | identity, provenance |
| `goals` | Goals, versions | measurements (read), profile (read) |
| `calculations` | Formulas, calculated metrics | profile (read), measurements (read) |
| `analytics` | Trends, aggregates/rollups, anomaly flags, **Health Snapshot** (§7.8), lineage-driven invalidation | measurements, goals, calculations |
| `provenance` | Provenance records | — |
| `media` | Source artifacts, scanning, storage | identity |
| `extraction` | Extraction drafts, review/commit workflow | media, measurements, provenance, ai-gateway |
| `ai-gateway` | Provider abstraction, model registry, **task/model routing** (§10.9), credential resolution (system and BYOK), usage ledger, provider-level limits | — (no domain knowledge) |
| `assistant` | Conversations, memory, orchestration, **AI Context Engine** (§11), AI Data Budget enforcement (§11.9), tool registry, safety classification (§10.6.1), action proposals | all domain read interfaces, ai-gateway, ai-trace |
| `ai-trace` | AI Trace Records (§12.8), evaluation linkage | — (receives content-free events from assistant, extraction, gateway) |
| `dashboard` | Widget composition contract | analytics, goals, calculations, assistant |
| `notifications` | Reminders, delivery | identity |
| `privacy` | Export, deletion orchestration, retention | all modules (via deletion/export contracts) |
| `audit` | Audit events | — |

**Boundary rules**

1. `ai-gateway` knows nothing about fitness. It deals in prompts, structured-output schemas, models, and usage.
2. `assistant` is the **only** module that talks to the model about user data, and only through the tool registry (§12).
3. Domain modules MUST expose **read interfaces designed for tool use** (summaries, bounded queries) rather than raw table access.
4. Future `nutrition` and `workouts` modules plug in by registering: catalog entries, tool capabilities, dashboard widgets, calculation formulas, retrieval sources, and deletion/export contracts. If adding a domain requires changing core modules beyond registration, the boundary is wrong.
5. Every module MUST implement the `privacy` export and deletion contracts. This is a quality gate for any new module.
6. Domains contribute to AI by registering **context providers** (what information, sensitivity, cost class, freshness, authorization rule, summary form) and **snapshot sections** with the Context Engine; the engine itself contains no domain-specific knowledge beyond these registrations.
7. Every user-owned record has **exactly one owner** (the user). System catalogs have no user owner and are read-only to users; user-created catalog extensions (future custom foods/exercises) are owner-scoped and not shared by default.

### 8.1 Cross-cutting validation and failure principles

**Validation in layers (defense in depth):** (L1) client-side validation for UX only, never trusted; (L2) API-boundary schema validation; (L3) domain invariants (unit/range plausibility, state transitions, goal consistency); (L4) database constraints (integrity, ownership, append-only enforcement); (L5) AI-specific validation — tool-argument and structured-output validation, extraction validation (§13.2), output claim validation (§10.8).

**Failure principles:** authorization **fails closed**; enrichment (AI, snapshot staleness, insights) **fails soft** and core tracking continues; writes are atomic (a measurement session commits fully or not at all) and idempotent; retries use backoff and never duplicate facts; errors are typed, consistent, and leak no internals. The degradation matrix is in §22.1.

---

## 9. Core User Journeys

**J1 — Onboard.** Register → verify email → consent (including explicit AI-processing disclosure) → minimal profile (only what calculations need; everything else deferred) → pick a goal (or skip) → optional first measurement → dashboard with an honest "getting started" state. *Constraint:* the user reaches value in under a few minutes and is never forced to provide optional sensitive data.

**J2 — Log a measurement manually.** Pick type(s) → enter value/unit → confirm date (defaults to now) → save. Plausibility warnings (not blockers) for outliers. Immediately reflected in trend and dashboard.

**J3 — Photograph a body-composition report.** Camera/upload → processing state → extraction draft showing each value, unit, per-field confidence, and flags → user edits/approves/rejects per field → commit as a measurement session with provenance linking the image → confirmation receipt. *Failure path:* low-quality image → actionable retake guidance, no partial silent save.

**J4 — Ask "How is my progress?"** Assistant resolves the intent → the Context Engine reads the snapshot and, only if the snapshot is insufficient, targeted series/trend/calculation data within the AI Data Budget → responds with grounded numbers, clearly labeled calculations/estimates, caveats about data sufficiency, and optional suggested next actions.

**J5 — "How many calories do I need to lose weight?"** Assistant checks required inputs (age, sex-for-calculation, height, weight, activity). If missing, it asks or states what is missing. Otherwise it invokes the calculation engine, presents maintenance estimate, a safe deficit range, and the assumptions used, flagging that these are estimates and offering to adapt them from observed trend data.

**J6 — "Save my weight as 82.4 kg."** Assistant proposes a safe write → user sees a confirmation affordance (or, for safe writes, a visible undoable receipt) → system persists → assistant reports success **only from the system receipt**.

**J7 — Change a goal.** New goal version created; prior progress remains evaluable against the earlier version; dashboard and AI context update.

**J8 — Correct a mistake.** User marks an observation wrong or edits it → system supersedes (not overwrites) → trends recompute → provenance records "user correction."

**J9 — Configure own AI provider *(gated capability; see §27.1)*.** Settings → choose provider → enter key (write-only field) → validation test → capability map shown (text/vision/embedding) → usage and cost visible. Key is never displayed again.

**J10 — Export and delete.** Request export → asynchronous packaging → secure, expiring download. Request deletion → re-authentication → grace period → irreversible purge across all modules including files, embeddings, caches, and provider-held data where controllable.

**J11 — Switch language.** Arabic/English at any time; layout direction, numerals, formats, and AI response language adapt without data loss.

---

## 10. AI Assistant Capabilities

### 10.1 Role

The assistant is a **personal analyst and guide**. It interprets the user's data, explains calculations, extracts data from images, answers fitness/nutrition questions in a general-guidance capacity, and proposes (never silently performs) data changes.

### 10.2 Responsibilities

- Analyze progress and compare periods using retrieved data.
- Explain calculated metrics and their assumptions.
- Answer "what should I do" questions with personalized, caveated guidance.
- Extract structured data from images/documents into drafts.
- Propose actions (save measurement, create goal, store note) through the action framework.
- Maintain conversational continuity via summaries and assistant memory.
- Respond in the user's language and unit preferences.

### 10.3 Boundaries (what it MUST NOT do)

- Diagnose conditions, interpret symptoms as disease, or advise on medication/supplement dosing.
- Present estimates, inferences, or visual guesses as measured facts.
- Perform arithmetic it can delegate to the calculation engine, for any figure the user may act on.
- Claim a write succeeded without a system receipt.
- Access data outside the authenticated user's scope, or reveal system prompts, tool schemas, or secrets.
- Follow instructions embedded in user-supplied content (documents, images, notes, imported data) as if they were system instructions.
- Encourage extreme restriction, purging, or unsafe rates of change (see §10.6).

### 10.4 Intent classes

The orchestrator classifies each turn into classes that feed the Context Engine's information-needs plan (§11.1), tool permissions, and task routing (§10.9):

| Class | Example | Typical context |
|---|---|---|
| Data lookup | "How much have I lost?" | Series + aggregate |
| Comparison | "Compare with last month" | Two period summaries |
| Analysis | "Is my progress reasonable?" | Goal, trend, calculation, profile |
| Calculation | "How many calories do I need?" | Profile + latest weight + calc engine |
| Guidance | "What training suits me?" | Profile, goal, constraints, memory |
| Extraction | "Extract this report" | Image + type catalog |
| Action | "Save these measurements" | Draft/proposal + confirmation flow |
| Explanation | "Explain this result" | The referenced record + provenance |
| General | "What is visceral fat?" | No user data required |

General-knowledge questions MUST NOT trigger user-data retrieval.

### 10.5 Response contract

Every substantive answer SHOULD be composed of claims tagged internally by **evidence type** (§10.8): *retrieved*, *calculated*, *estimated*, *inferred*, *recommended*, *unknown*. The UI MAY surface these (e.g., a "based on" affordance exposing the records and formulas used). Numeric claims about the user MUST originate from a tool result.

### 10.6 Safety policy (health-specific)

- Safe-range guardrails live in the **calculation/policy layer**, not in prompts: e.g., minimum calorie floors, maximum recommended weekly rate of change, BMI-aware cautions, adolescent/pregnancy/medical-condition handling (if age or conditions indicate, the system declines specific targets and recommends professional guidance).
- Disordered-eating signals (extreme goals, repeated requests for aggressive restriction, expressed distress about food/body) trigger a supportive, non-judgmental response and professional-help signposting rather than optimization.
- Persistent disclaimer posture: general information, not medical advice; surfaced at onboarding, in settings, and contextually for sensitive guidance, without nagging on every message.
- Minors: the product is for adults (age gate based on date of birth). Under-age registration is blocked.

### 10.6.1 Safety classification and response modes

The AI is a **fitness and wellness assistant, not a medical authority.** Every assistant turn is classified (deterministic rules plus a lightweight classifier, independent of the main model, both pre- and post-generation) into:

| Category | Scope | Default response mode |
|---|---|---|
| **A. Wellness/fitness guidance** | General training, habit, recovery, and consistency guidance | Normal, personalized, caveated where data is thin |
| **B. Nutrition guidance** | Calorie/macro targets within engine guardrails, general food-choice principles | Normal within guardrails; no therapeutic/medical diets |
| **C. General educational information** | "What is visceral fat?", how a formula works | Normal, no user data needed |
| **D. Concern signals requiring professional evaluation** | Symptoms (e.g., chest pain, fainting), rapid unexplained weight change, signs of disordered eating, extreme restriction goals, pregnancy/breastfeeding, diagnosed conditions or medication questions, very low BMI, user under age policy, self-harm indicators | **Guarded** (general information only, no individualized targets) or **Redirect** (recommend professional evaluation; urgent signals get region-appropriate emergency guidance) |

**Hard rules:** the AI MUST NOT invent diagnoses, measurements, medical history, or certainty; medical facts about the user exist only if the user stated them and they were stored as provenance-labeled memory; uncertainty is communicated; unsafe recommendations are blocked by the policy/calculation layer, not by prompt wording alone. Classification outcome and any guardrail triggered are recorded in the AI Trace (§12.8) and exercised by the evaluation suite (§31.2).

### 10.7 Memory

- **Conversation history** — retained and summarized; summaries, not raw transcripts, feed future context.
- **Assistant memory** — durable facts/preferences the assistant may use. MUST be visible and editable/deletable by the user. Memory writes are Safe Writes with a visible receipt. Memory is *not* a substitute for the health record: measurements go to the measurement domain only.
- Memory entries carry provenance (stated by user / inferred) and inferred ones MUST be confirmed before being relied upon for health-relevant behavior.

### 10.8 Anti-hallucination architecture

The system MUST distinguish, at the data-structure level and in the UI, these **evidence types**:

| Evidence type | Meaning | Allowed phrasing |
|---|---|---|
| Known fact | Curated, vetted general knowledge | Stated plainly, with scope caveats |
| Retrieved user data | Value read from the user's record | Stated with date and source |
| Calculated value | Output of the calculation engine | Stated with assumptions and formula reference available |
| Estimate | Approximation with real uncertainty (e.g., visual, projected) | Labeled "estimated," with range where defensible |
| Inference | Reasoned conclusion from evidence | Labeled as interpretation, with the evidence cited |
| Recommendation | Suggested action | Labeled as guidance, safety-checked |
| Unknown | Required information absent | "I don't have enough information to determine this," plus what would resolve it |

**Architectural mechanisms**
1. **Sufficiency gating** before generation: missing critical inputs produce a clarification or "unknown" answer rather than a guess (§11.3).
2. **Numeric provenance check:** user-specific numbers in the draft answer must match a tool result from this turn; unmatched numbers cause regeneration or removal.
3. **Structured response envelope:** the model returns claims with evidence-type tags and references to tool results; the presentation layer renders labels and the "based on" view from these references.
4. **Action-claim check:** statements about saved/changed data are permitted only when bound to an Action Receipt (§12.5).
5. **Temporal grounding:** every statement about the user's state carries an as-of date; stale data (beyond a defined freshness window per metric) triggers a caveat.
6. **Confidence propagation:** low-confidence or estimated inputs lower the stated certainty of derived claims.
7. **Refusal-preferred defaults:** the system prompt and policy layer explicitly rank "unknown" above plausible fabrication; evaluation suites reward correct abstention.
8. **Evaluation:** a standing eval set of adversarial and ambiguous questions (missing data, contradictory data, outdated data, injection attempts) gates every model/prompt/provider change.

### 10.9 Task & model routing

**Principle: deterministic first, smallest capable model second.** The first routing question is always *"can this be answered without a model?"* (e.g., "How much weight have I lost?" is a deterministic computation; a model MAY only phrase or contextualize it). Routing is a gateway policy, never hard-coded to a vendor or model.

| Task class | Default execution |
|---|---|
| Calculations, deltas, trends, goal progress, targets | **Deterministic application logic** (no model) |
| Intent classification, query planning, safety pre-screen | Lightweight model or rules |
| Simple conversational / lookup phrasing | Lightweight model |
| General knowledge Q&A | Lightweight-to-mid model, curated knowledge retrieval |
| Structured analysis, comparisons, personalized guidance | Capable model with structured output and tool use |
| Complex multi-step analysis (Tier 4, §11.1) | Most capable approved model, higher budget profile |
| Image/document extraction | **Vision-capable** model (OCR-grade path preferred where sufficient) |
| Summarization (conversation, digests) | Lightweight model |
| Embeddings | Embedding-slot model, independent of chat provider |
| Future: speech, on-device/local tasks | Future/local models where practical |

**Routing inputs:** task class; required capabilities (structured output, tool calling, vision, context window, **Arabic/English quality**); data sensitivity and user consent (e.g., a user may restrict to certain providers or to local models when supported); the user's configured providers; availability/health signals; the applicable budget profile (§11.9); cost/latency policy; and **evaluation approval** — a model serves a task class only if it has passed that class's evaluation suite (§31.2).

**Behavior:** bounded *escalation* (cheap → capable) on low-confidence or failed validation; fallback chains per capability on provider failure/timeouts; consistent structured contracts across providers; provider-specific details confined to adapters (no leakage into domain code); every routing decision (task class, chosen model, reason, fallbacks used) recorded in the trace; users can see which provider/model handled a request.

---

## 11. AI Context Engine & Retrieval Architecture

### 11.1 Principle & the AI Context Engine

The model receives **the minimum relevant, provenance-labeled, token-budgeted context required for this turn** and nothing more. Context is *assembled per request*; the model never "has" the user's database.

**The AI Context Engine** is the logical component (not necessarily a separate service) that decides what a request actually needs. RAG is *one* of its instruments, used only when warranted. Its responsibilities:

1. **Understand the information need** — intent class (§10.4), entities, time expressions, required inputs.
2. **Plan the lowest sufficient tier** (ladder below), validated against permitted tools and the AI Data Budget *before* execution.
3. **Enforce authorization and budget** at every retrieval (§12.2, §11.9).
4. **Assemble** a deduplicated, prioritized, provenance-labeled context package.
5. **Emit a context manifest** (what was included, excluded, why, at what data version) for traceability (§12.8).

**Tier ladder — start at the lowest tier that can satisfy the need; escalate only on detected insufficiency and available budget:**

| Tier | Context supplied | Typical requests |
|---|---|---|
| 0 | **No user data** | General knowledge, small talk, "what is visceral fat?" |
| 1 | **Snapshot only** (specific sections) | "How am I doing?", "What's my calorie target?", "What's my current weight?" |
| 2 | Snapshot + **targeted structured retrieval** (series, aggregates, period comparisons, calculation tools) | "Compare with last month", "What changed since my last measurement?" |
| 3 | Tier 2 + **semantic retrieval** (notes, memory, document text, curated knowledge) | "What did I note about my knee?", "Explain this report" |
| 4 | **Deep analysis:** multiple bounded retrieval rounds, multi-period or cross-domain, stronger model, higher budget profile, user-visible progress | "Review my whole history and suggest a plan" |

**Rules:** never "retrieve everything just in case"; semantic retrieval is never the default path; future domains join by registering context providers (§8, rule 6) and the engine discovers them; planning is deterministic-first (rules, cached plans) with a small model only for ambiguity; the engine does not author answers; provenance and layer labels survive assembly; conversation context enters as rolling summary + recent turns and is counted against the budget.

### 11.2 Information sources

| Source | Kind | Retrieval mode |
|---|---|---|
| **Health Snapshot** (§7.8) | Derived, compact, versioned | Tier 1 default; sections selected per intent; includes the compact profile/units/language "user card" content |
| Profile & preferences (detail) | Structured | Only fields beyond the snapshot, on demand |
| Primary/active goals | Structured | Included when intent is goal/progress/guidance related |
| Observations | Structured, time series | Tool-driven, parameterized by type and time window; never bulk |
| Calculated metrics | Deterministic | Computed on demand or cached; preferred over LLM arithmetic |
| Trends & aggregates | Derived | Precomputed/cached summaries by period |
| Periodic digests | Derived summaries | Weekly/monthly generated summaries enabling long-horizon questions cheaply |
| Assistant memory | Semi-structured facts | Small set, relevance-filtered |
| Conversation summaries | Derived text | Rolling summary + recent turns |
| Notes / documents / extracted report text | Unstructured | **Semantic retrieval** (embeddings) |
| Provenance/confidence | Metadata | Attached to every retrieved fact |
| Static knowledge base (curated fitness/nutrition guidance, formulas' rationale) | Curated, non-user | Semantic retrieval; vetted content only |
| Future-domain providers (training history, nutrition logs, sleep/recovery, integrations) | Structured/derived | Registered context providers; same tiering, authorization, and budget rules |

### 11.3 Retrieval strategy (hybrid, structured-first)

1. **Intent & entity resolution** — classify intent; resolve time expressions ("last month," "since January") and metric references into a normalized query plan. This step MAY use a small/cheap model or rules.
2. **Sufficiency check** — determine which required inputs exist. Missing critical inputs short-circuit to a clarification or "insufficient data" response before spending tokens.
3. **Structured retrieval first** — exact, indexed lookups via tools for measurements, goals, calculations. Structured data is the default answer to numeric questions.
4. **Semantic retrieval only when needed** — for unstructured content (notes, prior discussions, document text, knowledge base). Always user-scoped; the user filter is applied at the retrieval layer, not in the prompt.
5. **Temporal filtering & downsampling** — long series are summarized (endpoints, min/max, rate, smoothed points) rather than sent raw. Raw points are provided only for short windows or when explicitly needed.
6. **Prioritization** — rank by (a) intent relevance, (b) goal relevance, (c) recency, (d) provenance quality/confidence, (e) novelty versus already-included context.
7. **Budgeting** — each turn operates under an **AI Data Budget** (§11.9), whose token component is partitioned across system policy, snapshot, retrieved evidence, conversation, and response headroom. If evidence exceeds budget, lower-priority items are summarized or dropped, and the answer MUST acknowledge material omissions when they affect conclusions.
8. **Iterative retrieval** — the model MAY request additional approved retrievals within a bounded number of tool-call rounds and a bounded total budget.

### 11.4 Embeddings

- Only **unstructured, user-authored or extracted text** is embedded. Numeric observations are NOT embedded; they are retrieved structurally.
- Embeddings are user-scoped, deletable with the user's data, and tagged with the embedding model/version so re-embedding is possible when models change.
- Embedding provider is independent of chat provider (different capability slot, §24/ADR-005).
- Vector storage MUST enforce per-user filtering as a hard constraint of the query, not post-filtering.

### 11.5 Derived summaries

- Periodic digests (weekly/monthly/quarterly) are generated deterministically where possible (aggregates) and optionally narrated by AI. They are cached, versioned, and invalidated when underlying observations are corrected/superseded.
- Digests are a **cost-control and long-horizon-reasoning mechanism**, not a source of truth; they link back to the aggregates they describe.
- **Over-engineering guard (v1.1):** the Snapshot plus aggregates/rollups are the primary compact representations. Digests are an *optimization introduced only when* evaluation or cost data shows long-horizon requests are inadequately served by snapshot + aggregates (§27.1, Phase 3 decision gate).

### 11.6 Trust labeling in context

Every context item carries: source type, observed-at, confidence/quality flag, and layer (§7.4). The model is instructed—and the output validator verifies—that claims preserve these labels (e.g., an AI-extracted low-confidence value is not presented as a firm measurement).

### 11.7 Caching & reuse

Cache calculated metrics, aggregates, digests, and retrieval plans for repeated question patterns, keyed by user + data version. Any observation write/supersession invalidates dependent caches. Avoid re-analyzing unchanged data: if an equivalent insight exists for the current data version, reuse it.

### 11.8 Failure behavior

If retrieval returns nothing relevant, the assistant says so. It MUST NOT fabricate history. If the vector store or a provider is unavailable, the assistant degrades to structured-only answers and tells the user what it could not consult.

### 11.9 AI Data Budget

**Definition.** An **AI Data Budget** is an explicit, enforced allowance governing how much data, context, computation, time, and money a single AI operation (and a user over time) may consume. It prevents excessive token use, unnecessary database reads, huge prompts, slow responses, expensive requests, and uncontrolled agent/tool behavior.

| Dimension | Governs |
|---|---|
| Records & reads | Maximum records returned per retrieval and per turn; maximum rows scanned / database time per tool call |
| Retrieval depth | Maximum time-window span; resolution/downsampling level; semantic top-k; number of retrieval rounds |
| Context size | Total input tokens; partition across policy, snapshot, evidence, conversation, headroom |
| Tool use | Maximum tool calls per turn; maximum sequential rounds; per-tool caps; concurrency |
| Output | Maximum response tokens; maximum structured payload size |
| Time | Per-tool timeouts; end-to-end deadline; first-token target for streaming |
| Media | Images per request, resolution, pages |
| Cost | Per-turn ceiling; per-user daily/monthly allowance; global circuit breakers |
| Provider/model limits | Context window, rate limits, feature support — **effective budget = min(policy, provider/model capability)** |

**Properties**
1. **Budget profiles**, not constants: selected by task class × user tier × model, versioned, held as configuration rather than code, and changeable without redeploying logic.
2. **Enforced outside the model** — in the Context Engine, gateway, and tool layer — with per-turn counters. The model cannot raise its own budget.
3. **Graceful exhaustion (degradation ladder):** reduce resolution/window → summarize → drop lowest-priority context → answer with an explicit limitation → ask the user to narrow the question → decline with a reason. **Correctness-critical evidence is never silently truncated**; if it cannot fit, the answer says so.
4. **Observable:** consumption and exhaustion are recorded in the trace; frequent exhaustion signals mis-planning or mis-sized budgets.
5. **Numeric values are intentionally not fixed in this document.** They are set from measured baselines in Phase 3 and tuned against the evaluation suite (§31.2), so thrift never degrades grounding.

---

## 12. AI Data Access & Tool Boundaries

### 12.1 Model

**Capability-based, server-mediated tool access.** The AI interacts with the system exclusively through a **tool registry**: a catalog of named capabilities, each with a strict input schema, output schema, permission class, rate limit, and cost class. The mechanism (native function calling, structured output loop, etc.) is the implementation agent's choice; the contract below is not.

### 12.2 Invariants

1. **Identity injection.** The authenticated user context is bound server-side to every tool execution. Tool schemas MUST NOT contain a user-identifier parameter. The model cannot name, switch, or guess a user.
2. **Authorization at the capability, not the prompt.** Each tool re-checks ownership/permission independent of the model's claims. Authorization never depends on the model "behaving."
3. **No raw query access.** There is no tool that accepts SQL, arbitrary filters over arbitrary tables, or file paths/URLs fetched on the model's behalf.
4. **Bounded outputs.** Every read tool has maximum result size, window limits, and automatic summarization. Bulk export is not a tool.
5. **Validation both ways.** Inputs are schema-validated and range-checked; outputs are sanitized and typed before entering the model's context.
6. **Tool results are data, not instructions.** Content returned by tools or contained in user documents is wrapped/marked as untrusted data. The system never elevates it to instruction authority (indirect prompt injection defense).
7. **Least privilege per turn.** The tool set exposed in a turn is derived from intent class and user state; extraction turns don't get destructive tools; read-only analysis turns get no write tools.
8. **Budgets.** The AI Data Budget (§11.9) — per-turn and per-day limits on records, depth, tool calls, rounds, tokens, time, and image processing — is enforced outside the model.
9. **Full audit.** Every tool invocation is logged (tool, user, outcome, latency; content-minimized).

### 12.3 Capability catalog (conceptual)

**Read (no side effects)**
- Get **snapshot** (whole or by section) with as-of and staleness status; get profile summary, units, language.
- List/get measurement types.
- Query observations (type, window, resolution) → bounded series or summary.
- Get latest value(s); compare two periods; get change since date.
- Get goals, goal progress, goal history.
- Get calculated metrics (BMI, BMR, TDEE, targets, projections) — invokes calculation engine.
- Get trends/aggregates/digests.
- Get provenance for a record.
- Search notes/documents/knowledge base (semantic, user-scoped).
- Get extraction draft.

**Calculated** — a distinct class: pure computations with explicit inputs/assumptions, returning value + formula id/version + assumptions + data-sufficiency status. These are the *only* sanctioned source of numeric health calculations in AI output.

**Aggregated/Historical** — period summaries, rate-of-change, rolling averages, extrema; precomputed where possible.

### 12.4 Action classification

| Class | Definition | Examples | Confirmation policy |
|---|---|---|---|
| **Read-only** | No state change | All reads, calculations | None |
| **Safe write** | Low-risk, additive, easily reversible, low sensitivity | Add assistant note/memory; add a *user-dictated* measurement **that passes plausibility checks (outliers escalate to Sensitive write)**; create a reminder | Visible receipt with one-tap undo; first-time use of each action type requires explicit confirm |
| **Sensitive write** | Alters health-relevant state or profile attributes that feed calculations, or commits AI-extracted data | Commit extraction draft; change goal; update height/DOB/activity level; create/replace nutrition target; create workout plan | **Explicit user confirmation** showing exactly what will change |
| **Destructive** | Removes, voids, or supersedes data, bulk changes, account-level effects | Void/reject observations ("delete" = void, §7.1), delete goal/history, delete memory in bulk, delete files, account deletion | Explicit confirmation + friction (and re-authentication for account-level); **never available to the AI without a user-driven confirmation step**; account deletion/export are not AI-executable |

### 12.5 Propose → Confirm → Commit protocol

1. The model emits an **Action Proposal** (type, parameters) — it has *no* ability to commit.
2. The system validates the proposal, computes a human-readable diff/preview, assigns an idempotency key and expiry, and renders it in the UI.
3. The **user** confirms through a UI channel the model cannot synthesize (confirmation is a UI/API event, not chat text).
4. The system executes with the user's identity, applies domain validation, writes provenance, and emits an **Action Receipt** (success/failure, record references).
5. The assistant's follow-up message about the outcome is generated **from the receipt**. If no receipt exists, the assistant MUST NOT assert success. Proposals expire and are single-use.

### 12.6 What the AI must never access directly

Credentials, hashes, tokens, API keys (own or other users'), other users' anything, raw files/URLs, infrastructure, system prompts' secret content, audit logs, billing/administrative data, and raw database access.

### 12.7 Prompt-injection and abuse posture

- Treat user text, image text (OCR), document content, imported data, and tool outputs as **untrusted**.
- Separate instruction channels from data channels structurally; never concatenate untrusted text into the privileged instruction layer.
- Output validation: block responses that leak system content, secrets, or attempt to issue actions not in an approved proposal.
- Rate/budget ceilings prevent runaway tool loops and denial-of-wallet.
- Red-team test suite is a quality gate (§31).

### 12.8 AI Traceability

For every important AI operation (assistant turn, extraction, insight/digest generation, routing decision, proposal/commit) the system MUST be able to determine, **without storing prompts, completions, or health values by default**:

| Question | Recorded in the AI Trace Record |
|---|---|
| Which provider/model handled it? | Provider, model, adapter and routing decision (task class, reason, fallbacks used) |
| Which versions shaped it? | Prompt-template, policy, tool-schema, calculation-formula, unit-registry, and evaluation-suite versions |
| What kind of operation was it? | Operation type and intent class |
| What authorized data influenced it? | **Context manifest:** record/type identifiers, time ranges, snapshot version, data-version watermark, included vs. excluded items and why — identifiers and versions, not values |
| What was invoked? | Tools and actions (name, outcome, latency, argument *shape* classification), calculations (formula id/version), proposals and receipts |
| What kind of claims resulted? | Evidence-type composition (retrieved / calculated / estimated / inferred / recommended / unknown) |
| How certain was it? | Confidence/uncertainty flags: insufficient-data, low-confidence inputs, stale snapshot sections, estimate-class inputs |
| What safety handling occurred? | Safety category (§10.6.1), guardrails triggered, refusals/redirects |
| What did it cost? | Budget consumption by dimension (§11.9), tokens, latency |
| How did it end? | Outcome, failures, retries, user feedback signal |

**Reproducibility without content:** because health facts are append-only and versioned, the user's data *as it was* at the manifest's watermark can be reconstructed; combined with recorded versions, an operation can be replayed in a controlled environment for debugging, evaluation, or incident review.

**User trust:** users can open a "How did the assistant arrive at this?" view derived from the trace (sources used, calculations applied, what was estimated vs. measured).

**Handling rules:** traces are owner-linked and deleted/exported with the user's data (content-free operational aggregates MAY persist non-identifiably); debug capture of content is opt-in, time-boxed, and access-controlled (§23); traces never contain secrets; the usage ledger is a projection of traces; trace data feeds observability (§23) and evaluation (§31.2).

---

## 13. Multimodal / Image Intelligence

### 13.1 Capability levels

| Capability | Initial | Notes |
|---|---|---|
| Camera capture & image upload | Yes | Mobile-first capture with guidance |
| Document/report OCR + structured extraction | **Yes (flagship)** | Body-composition reports, scale displays, measurement sheets |
| Image understanding for Q&A | Yes (basic) | "Analyze this image" |
| Food recognition | Seam only | Output is always an *estimate* draft |
| Exercise/equipment recognition | Seam only | Future workout domain |
| Physique/body-photo estimation of body fat | **Not in initial release** | Low reliability, high sensitivity; if added later, stored only as clearly-labeled low-confidence estimates, never as measurements |

### 13.2 Pipeline (conceptual stages)

1. **Capture/upload** — client-side size/format limits, optional on-device downscaling/cropping.
2. **Ingestion security** — content-type verification by inspection (not extension), size limits, malware scanning, metadata (EXIF/GPS) stripped, re-encoding to safe formats, private storage with no public URLs.
3. **Classification** — identify the image kind (report, scale display, food, other) and route accordingly. Unknown/unsupported → graceful message.
4. **Extraction** — vision/OCR via the AI gateway's vision capability producing structured output against the **Measurement Type catalog** (not free-form). Only catalog-known types are extractable; unknown fields are surfaced as "unrecognized" rather than invented.
5. **Validation** — unit normalization, plausibility ranges, cross-field consistency (e.g., components that cannot exceed the whole; BMI vs. weight/height), date detection, duplicate detection against existing observations.
6. **Confidence** — per-field confidence plus overall quality assessment; fields below threshold are flagged and require explicit attention.
7. **Draft** — an Extraction Draft is created; it is *not* health data yet.
8. **Review** — the user sees the source image beside extracted values, can edit, remove, or add fields, and approves per field/session.
9. **Commit** — approved values become Observations in a Measurement Session with provenance (`image`/`AI extraction`, model + version, confidence, source artifact link, "user-reviewed" flag, and original vs. edited values preserved).
10. **Retention** — the user chooses to keep or delete the source image after commit (default policy documented in the privacy section); provenance survives image deletion as a record that an image existed.

### 13.3 Rules

- **AI extraction never auto-saves.** Review is mandatory.
- Ambiguity → ask, don't guess. If two interpretations exist (e.g., kg vs lb, left vs right), present both or request clarification.
- Extraction determinism: structured-output schemas; low temperature; retry/fallback to alternate vision provider within budget.
- Extracted text inside images is untrusted data (prompt-injection vector).
- Visual estimates are labeled as estimates everywhere (UI, AI answers, analytics) and weighted accordingly or excluded from trends by default.
- Image-processing cost controls: downscale before sending, per-user daily image quota, skip vision when OCR-grade text extraction suffices.

### 13.4 Supported inputs, trust tiers, and review intensity

**General workflow:** input → classify → extract → validate + confidence → **review (intensity adapts to confidence/risk)** → confirm/correct → persist with provenance. Nothing extracted by AI becomes trusted record data without user confirmation.

| Input type | Purpose | Availability |
|---|---|---|
| Body-composition report / printout | Measurement session extraction | **Initial** |
| Smart-scale display / scale-app screenshot | Weight/composition extraction | **Initial** |
| Tape-measurement sheet (typed/printed; handwritten best-effort, lower confidence) | Circumference extraction | **Initial** |
| Screenshots from other health apps (history tables) | Import via extraction; lower trust tier than direct reports | Prepared |
| Nutrition labels | Nutrient extraction | Prepared (needs nutrition domain) |
| Food images | **Estimate-class** drafts | Prepared |
| Exercise/equipment images | Recognition for future workout domain | Prepared |
| Progress photos | Stored privately; **not an extraction target**; optional AI analysis is explicit and opt-in (§28.2) | Prepared |
| Clinical/lab documents | **Not supported initially** (avoids becoming a medical-records system); the assistant states this limitation and does not store structured medical results | Out of scope |

**Trust tiers (epistemic):** (1) values read from printed numerals with validation > (2) values read from device displays/screenshots > (3) **visual estimates** (food portions, physique, form). Tier-3 outputs are *Estimate-class*: never stored as measured observations, excluded from default trends and target calculations, and always labeled as estimates.

**Review intensity (refines §13.3's "no auto-save", does not weaken it):** every AI-extracted value requires explicit user confirmation, but the effort adapts — high-confidence, fully validated extractions present a concise one-step confirmation summary; low-confidence, inferred-unit, inconsistent, or duplicate-suspect fields demand per-field attention and cannot be bulk-approved. Relaxing confirmation for any source would require a new ADR and applies only to *non-AI deterministic* sources (e.g., device imports), never to AI extraction.

---

## 14. Data Provenance

### 14.1 Requirement

For every important record the system MUST be able to answer **"Where did this value come from?"** and, where meaningful, **"How confident are we?"**

### 14.2 Provenance record (conceptual contents)

- **Origin type:** manual entry · AI extraction from image · imported document · device/smart scale · wearable · external integration · system calculation · user correction · AI-proposed-then-user-confirmed.
- **Epistemic class:** **measured** (instrument/device or direct reading), **calculated** (deterministic derivation), **estimated** (approximation with real uncertainty, incl. visual estimates and projections), **asserted** (user-stated without instrument). Orthogonal to origin type; drives how values are weighted, labeled, and phrased by analytics, UI, and AI.
- **Actor:** user, system, AI (with provider/model/version), device identifier.
- **Method & version:** formula id/version for calculations; extraction model/prompt-schema version for AI.
- **Source link:** source artifact/draft/session/import batch.
- **Confidence:** normalized score and categorical band; for AI extraction, per-field; for manual, "user-asserted."
- **Review state:** unreviewed / user-reviewed / user-corrected.
- **Timestamps:** observed-at, recorded-at, reviewed-at.
- **Lineage:** supersedes/superseded-by references for corrections.

### 14.3 Rules

1. Provenance is created **in the same transaction** as the record it describes; a record without provenance is invalid.
2. Provenance is immutable. Changes are new records.
3. Analytics and AI MUST be able to filter or weight by provenance/confidence (e.g., "exclude estimates," "prefer device-measured").
4. The UI exposes provenance on demand for any displayed value.
5. Deleting a source image does not delete provenance facts (only the artifact pointer is tombstoned).
6. Calculated metrics carry provenance of their inputs, enabling reproducible recomputation.
7. **Estimates are never presented as measurements.** Epistemic-class labels travel with values into context, UI, and AI output; the output validator rejects phrasing that upgrades an estimate to a measured fact (§10.8).

---

## 15. Calculation Architecture

### 15.1 Separation principle

A **deterministic, versioned, unit-tested calculation engine** — independent of any LLM — is the sole source of numeric health calculations. The LLM requests calculations through a tool, then *explains and contextualizes* the result.

### 15.2 Scope

BMI; BMR (formula selection by available data, e.g., a standard predictive equation by default and a lean-mass-based equation when reliable lean mass exists); TDEE from activity level; maintenance calories; deficit/surplus ranges; macronutrient target ranges; expected rate of weight change; projected goal timeline; trend slope, smoothing, rate of change; period deltas; goal progress percentage; simple body-composition derived values.

### 15.3 Requirements

- **Versioned formulas:** each formula has an identifier and version; results record both. Changing a formula creates a new version; historical results remain reproducible. Persisted derived values reference their input records (lineage, §7.6); a recomputation produces a **new version**, never a silent overwrite.
- **Explicit inputs and assumptions:** the output includes inputs used, assumptions, and **data-sufficiency status** (complete / partial / insufficient with the missing items listed).
- **Units explicit.** No implicit unit conversion inside calculations.
- **Pure and testable:** same inputs → same outputs; property tests and reference-value tests are a quality gate.
- **Trend-aware adaptation:** estimated maintenance can be *refined from observed weight trend vs. intake* once nutrition data exists (future), and from weight trend alone as a coarse sanity check initially. Estimates are always labeled as estimates with uncertainty ranges where defensible.
- **Noise-robust trends:** body weight fluctuates daily; trends use smoothing and require minimum data span/count before claiming a rate. Insufficient data yields "not enough data," not a slope.
- **Anomaly detection (rule/statistics-based):** implausible jumps, unit-likely errors, duplicate entries, and sensor-like outliers are *flagged* for user review, never auto-deleted.

### 15.4 Interaction with data and AI

```
Observations + Profile + Goal ──► Calculation Engine ──► Calculated Metric (with provenance, assumptions, sufficiency)
                                                          │
                                         tool result ◄────┘
                                              │
                                   LLM explains / contextualizes (cannot alter numbers)
```

The output validator checks that numbers in AI prose match tool results for user-actionable figures.

### 15.5 Safety policy in the engine

Hard guardrails live here, not in the prompt: calorie floors, maximum weekly loss/gain rates, caps on deficit/surplus, macro sanity bounds, special-population handling (e.g., unsupported age ranges, pregnancy/medical-condition flags provided by the user → refuse specific targets and recommend professional consultation). Guardrail triggers are visible to the user with explanation.

---

## 16. Future Nutrition Domain

**Status:** architecturally prepared; not implemented in the initial release (except the calorie/macro *target calculations* in §15).

### 16.1 Future entities
Food (canonical item), Serving/Unit definitions, Meal, MealItem, FoodLogEntry, Nutrient profile (macros + micros), NutrientTarget (daily/weekly), Recipe (optional), Barcode mapping, Food source (curated DB / user-created / imported).

### 16.2 Architectural requirements now
- **Nutrients as a catalog** (like Measurement Types): nutrient code, canonical unit, so micronutrients can be added without schema change.
- **Food log entries are append-only observations** with provenance (manual, barcode, image-estimate, import). Food-image recognition outputs *estimate drafts* with confidence, reviewed before save, exactly like extraction drafts.
- **Targets** are produced by the calculation engine (macros, calories) and stored as versioned, user-confirmed objects (Sensitive write).
- **Food database strategy** is an open decision (§33): licensed/open dataset vs. user-generated; the domain MUST isolate the food source behind a provider-style interface.
- **Retrieval/tool seams:** tools such as "get nutrition summary for period" and "get adherence" register into the tool registry; the digest mechanism extends to nutrition.
- **Interaction with analytics:** intake-vs-weight-trend correlation becomes the primary basis for adaptive TDEE.

### 16.3 What must NOT happen now
No food database, no meal logging UI, no barcode scanning, no micronutrient tracking. Do not add placeholder tables that imply these exist.

---

## 17. Future Workout Domain

**Status:** architecturally prepared; not implemented in the initial release.

### 17.1 Future entities
Exercise (catalog), MuscleGroup, Equipment, Exercise media, WorkoutPlan (versioned), WeeklySchedule, WorkoutSession, ExerciseEntry, SetLog (reps, load, RPE, rest, tempo), PersonalRecord (derived), ProgressionRule.

### 17.2 Architectural requirements now
- **Catalog-driven**: exercises/muscle groups/equipment are catalog entries with localized names (ar/en) and stable codes.
- **Logs are append-only user facts** with provenance (manual, imported, wearable).
- **Plans are versioned documents**; AI-generated plans are *proposals* (Sensitive write) the user confirms; plan-to-log relationship supports adherence analytics.
- **Derived analytics** (volume, estimated 1RM, PRs, progressive overload) belong to the calculation engine, never the LLM.
- **Cross-domain value:** training load feeds activity-level estimates and recovery reasoning; measurement trends (muscle mass, circumferences) evaluate program effectiveness.
- **Registration seams:** tools, dashboard widgets, digests, calculation formulas, privacy export/delete contracts.
- **Cardio/wearable ingestion** arrives via the same integration/provenance mechanism (§28).

### 17.3 What must NOT happen now
No exercise library, no plan builder, no set logging, no AI workout generation beyond general textual guidance in chat (which is *not persisted as a plan*). The initial AI MAY say "what type of training may suit you" as guidance, labeled as general, without creating structured plans.

---

## 18. Dashboard & UX Architecture

### 18.1 Dashboard model

A **widget-composition contract**: the dashboard is a ranked list of widgets, each declaring: domain, data requirements, freshness, empty/insufficient-data state, and priority signals. Future domains add widgets without altering the dashboard core.

**Initial widgets**
- *Status & goal:* primary goal, current vs. baseline vs. target, progress, honest projection (with uncertainty).
- *Recent measurements:* latest values with deltas and provenance badges.
- *Trends:* weight and key composition metrics with smoothed trend and period selector.
- *Targets:* calorie/macro targets from calculations, with assumptions link.
- *AI insight:* one concise, evidence-linked insight (cached, regenerated only when data changes).
- *Prompts/reminders:* "time to measure," pending extraction drafts awaiting review.
- *Important changes:* anomalies and notable shifts.

**Dashboard rules:** every widget has a meaningful empty state that teaches the next action; no widget fabricates content from missing data; ordering is relevance-driven, not fixed; no widget requires a live AI call to render (AI insights are precomputed/cached); widgets read the same Snapshot and aggregates the assistant uses, so the app and the AI never disagree about the user's state.

### 18.2 Design language

**Feel:** premium, modern, trustworthy, technical-but-human, data-driven, calm.

**Principles**
1. **Information hierarchy first.** One primary number/message per screen region; secondary details are progressively disclosed.
2. **Data honesty in the visual layer.** Measured / calculated / estimated / AI-generated values are visually distinct and consistently so; confidence is visible where it matters.
3. **Charts as instruments.** Clear axes, units, annotated goals/targets, restrained color, direct labeling; smoothed trend shown alongside raw points; no decorative charts.
4. **Restraint.** Limited palette with semantic color (progress, caution, neutral), no color-only meaning, minimal motion that communicates state (loading, saved, confirmed) and never decorates.
5. **Typography-led.** Strong numeric typography, tabular figures for data, generous spacing, and proper Arabic typography with an Arabic type family selected as a peer of the Latin one, not a fallback.
6. **Human tone.** Copy is supportive and plain; no gamified guilt; no streak shaming.
7. **Assistant as integrated capability, not a chat widget.** The assistant is reachable contextually (ask about *this* chart/value), supports rich responses (embedded values, charts, proposal cards, extraction review) rather than only text bubbles.
8. **Anti-patterns to avoid:** generic chatbot bubbles with gradient avatars, glassmorphism overuse, card soup, stock-illustration onboarding, dashboards of equal-weight tiles, animation for its own sake.
9. **Accessibility is design input,** not QA: contrast, dynamic type scaling, screen-reader semantics (including for charts via summarized descriptions), touch target sizes, reduced-motion support.
10. **Confirmation UX is safety UX.** Action proposals and extraction reviews are first-class designed experiences with clear diffs and reversible affordances.

### 18.3 Key UX states that MUST be designed
Empty/new user, insufficient data, offline, AI unavailable/degraded, extraction in progress/failed/low-confidence, pending proposal, quota reached, provider misconfigured, permission denied (camera), account deletion pending.

### 18.4 Mobile behavior
Offline-tolerant reading of cached data; queued writes with conflict-safe sync (append-only model simplifies this); capture flow resilient to interruption; no blocking spinner for AI-dependent surfaces.

---

## 19. Localization

- **Languages:** Arabic and English at launch. **Architecture MUST permit adding languages** without code changes to domain logic.
- **Direction:** full RTL/LTR support via logical (start/end) layout, mirrored iconography where directional, bidirectional-text-safe handling of mixed Arabic/Latin/numerals (units, product names).
- **Message catalogs** for UI strings, including pluralization/gender rules per language; no string concatenation for sentences.
- **Catalog localization:** measurement types, nutrients (future), exercises (future) have stable codes plus localized display names; **data stores codes, never localized labels.**
- **Formatting:** locale-aware dates (Gregorian default; alternative calendars as a future option), numbers, decimal/thousand separators, and **numeral system preference (Western vs. Eastern Arabic digits) as a user setting.** Charts and tabular data honor it.
- **Units:** independent of language: metric/imperial and per-quantity overrides (e.g., kg + inches is legal). Canonical storage units never change.
- **AI localization:** the assistant responds in the user's language by default and follows mid-conversation language switches; prompts' policy layer is language-agnostic; evidence labels and units are localized in output; Arabic medical/fitness terminology quality is part of AI evaluation. Extraction MUST handle Arabic and English reports, including Arabic-Indic numerals.
- **Time zones:** observed-at stored with an absolute instant plus the user's time zone context; "today/this week" semantics follow the user's zone.
- **Testing:** RTL/LTR visual regression and pseudo-localization are quality gates.

---

## 20. Security Architecture

Health and body data are **sensitive personal data**. Security is architectural.

### 20.1 Authentication
- First-party email + password with modern memory-hard password hashing; breached-password screening; strong-but-usable policy.
- Optional social/OIDC sign-in (Apple/Google) as additional identities linked to one account.
- **Short-lived access tokens + rotating, revocable refresh tokens** bound to a device session; refresh-token reuse detection revokes the session family.
- Email verification required before AI features and data export; password recovery via expiring single-use tokens, with notification on credential change.
- Optional MFA (TOTP/passkeys) is *prepared* (data model, flows) and SHOULD be offered as it's cheap to design in now.
- Secure mobile token storage in platform secure storage; biometric app-lock as an optional user setting.
- Brute-force/credential-stuffing defenses: progressive throttling, generic error messages, anomaly alerts.

### 20.2 Authorization & isolation (non-negotiable)
- **Every** data access path is owner-scoped. Ownership is enforced at a central layer (not ad-hoc per endpoint), and **defense in depth** is required: application-level ownership checks *plus* database-level enforcement (e.g., row-level policies or an equivalent mechanism) so a missed check cannot leak data.
- **IDOR defense:** identifiers are never trusted; resources are resolved *through* the authenticated owner; use non-guessable identifiers; a test suite attempts cross-user access on every endpoint/tool (quality gate).
- Admin/operator access to user data is not part of the product; support tooling, if built, uses explicit, audited, time-boxed, consent-based access.
- Vector retrieval, caches, files, and background jobs carry the owner and are filtered at the storage/query layer.

### 20.3 API security
- TLS everywhere; modern cipher policy; HSTS; certificate pinning considered but not mandated.
- Strict input validation on all boundaries; typed schemas; output encoding; size limits; pagination caps.
- Rate limiting at multiple tiers (IP, user, endpoint, AI-specific); idempotency keys on writes; replay protection for proposals.
- CORS/CSRF posture appropriate to a mobile-first API (no cookie-auth ambient authority for state-changing calls unless explicitly designed).
- Versioned API with deprecation policy; no sensitive data in URLs/logs; consistent error shape that doesn't leak internals.
- Dependency and supply-chain hygiene: lockfiles, vulnerability scanning, SBOM, minimal base images.

### 20.4 AI-specific security
| Threat | Required mitigation |
|---|---|
| Prompt injection (direct) | Instruction/data channel separation; privileged policy never concatenated with user text; output validation |
| **Indirect injection** (OCR text, notes, imported docs, tool outputs) | Untrusted-content marking; no tool-authority from data; least-privilege tool sets per intent; actions require out-of-band UI confirmation |
| Tool abuse | Capability allowlist, schema validation, per-turn/day budgets, loop limits, audit |
| Data exfiltration (e.g., via markdown links/images, tool parameters) | No model-controlled outbound requests; strip/neutralize model-generated URLs and remote-image rendering; no tool with arbitrary network egress |
| Cross-user leakage | Identity injected server-side; storage-layer filtering; no shared context/caches across users |
| Secret leakage | Secrets never enter prompts or context; system prompts treated as non-secret but contain no credentials |
| Denial-of-wallet | Quotas, token/image budgets, cost ceilings, circuit breakers |
| Jailbreak to unsafe health advice | Policy in calculation/guardrail layer + output safety checks, not prompt-only |
| Malicious/poisoned user-supplied BYOK endpoints | Allowlisted provider types; outbound requests only via the gateway; SSRF protections; no arbitrary base URLs unless explicitly designed with network egress controls |

### 20.5 BYOK (user-provided provider keys) and provider credentials
- **No provider secret ever reaches the Flutter client.** System-owned provider credentials exist only server-side. The client MUST NOT call AI providers directly, MUST NOT receive provider credentials, and its only involvement with a user's own key is the **one-time submission to the backend** over TLS.
- **Secrets never appear in logs, traces, prompts, error messages, analytics, or crash reports;** automated scrubbing tests are a quality gate.
- **Provider specifics stay in gateway adapters.** Domain modules never import provider SDKs or reference provider-specific concepts; adding or replacing a provider requires no change to domain or assistant logic.
- Keys are **write-only** from the client's perspective: submitted once over TLS, never returned, only masked metadata displayed.
- Encrypted at rest with envelope encryption (per-record data keys wrapped by a managed key service); decrypted only in the gateway at call time; never logged, never in prompts, never in crash reports.
- Validation call on save; per-key usage tracking; revocation/deletion removes key material immediately.
- Users are informed that their data is processed by *their chosen provider* under *that provider's* terms; consent is recorded.
- Local/self-hosted provider endpoints (future) require explicit network-boundary design (SSRF-safe).

### 20.6 File security
Private object storage, no public buckets; short-lived, user-scoped signed access; upload scanning and re-encoding; hash-based dedupe per user only; EXIF stripping; quota enforcement; per-user key/path namespace; deletion propagates to storage and derivatives.

### 20.7 Secrets & infrastructure
Secrets in a managed secret store, injected at runtime, rotated; no secrets in repos, images, or client apps. Least-privilege service identities; network segmentation (database not publicly reachable); separate environments with no production data in non-production.

### 20.8 Encryption
In transit: TLS 1.2+ (prefer 1.3). At rest: storage-level encryption for database, object storage, backups. **Application-level encryption** for the highest-sensitivity fields is *evaluated per ADR-014*: BYOK secrets MUST be application-encrypted; health observations rely on encrypted storage + strict access controls initially, with a documented path to field-level encryption if required by regulation or threat model.

### 20.9 Auditability
Audit events for: authentication events, session changes, credential/recovery changes, provider key changes, data exports/deletions, sensitive/destructive writes, AI action proposals/commits, consent changes, authorization failures. Audit logs are append-only, access-restricted, content-minimized (identifiers and action types, not health values), and retained per policy.

### 20.10 Security testing
Threat modeling per release; cross-user access tests; AI red-team suite (direct/indirect injection, exfiltration, tool abuse); dependency scanning; SAST/secret scanning in CI; periodic third-party penetration testing before public launch.

---

## 21. Privacy Architecture

- **Data minimization:** collect only what the product needs. Sex-for-calculation, DOB, height, weight are needed for core calculations; anything else is optional and deferred. No collection of sensitive attributes (medical diagnoses, medications, reproductive health) as structured fields in the initial release; if a user states such info in conversation, it is not extracted into structured profile data without explicit design and consent.
- **Purpose limitation & consent:** explicit, versioned consent at onboarding for health-data processing and for **third-party AI processing**. Withdrawal is possible; withdrawing AI consent disables AI features but keeps core tracking.
- **Transparency:** an in-app "what the AI can see and where it goes" explanation; per-provider disclosure; users see which provider/model handled a request.
- **AI data minimization to providers:** send only assembled context; pseudonymous identifiers; never send name/email/contact data; configure providers with no-training/zero-retention terms where available for the system-provided provider; BYOK users are informed their provider's policies apply.
- **User rights:** access and **portable export** (machine-readable open format + human-readable summary; includes observations, goals, profile, memory, conversations, provenance; excludes secrets); **rectification** (corrections via supersession); **deletion** (below); restriction of AI processing.
- **Account deletion:** requires re-authentication; short reversible grace period; then irreversible purge across *all modules*: database records, embeddings, caches, derived digests, source artifacts and derivatives, assistant memory, conversations, usage data linkable to the user (aggregated, non-identifying statistics MAY remain), and queued jobs. Backups age out within a documented window; restore procedures MUST re-apply deletions. Each module implements a deletion contract; the `privacy` module verifies completion and produces a completion record.
- **Retention policy:** defined per data class (observations: until deletion; source images: user-selectable, defaulting to deletion after confirmed commit unless the user opts to keep; conversation transcripts: user-controllable; audit logs: minimal necessary period; AI usage ledger: content-free).
- **Privacy controls UI:** manage consent, AI features, memory, image retention, data export, deletion, active sessions/devices, connected providers.
- **Regulatory posture:** design to satisfy GDPR-style requirements as a baseline (health data as special-category data) and to adapt to regional regimes (e.g., Egypt/GCC data-protection rules, and HIPAA-like expectations if the product ever serves clinical contexts). Legal review before launch is required; the architecture provides the *capabilities* (consent, export, deletion, residency awareness), not legal conclusions.
- **Data residency:** single region initially, with region choice treated as an architectural variable (open question §33) because it affects provider selection and regulation.
- **Analytics/telemetry:** product analytics are opt-in or strictly aggregate and exclude health values; crash reports are scrubbed.

### 21.1 Data ownership and classification

- **Ownership:** the user owns their health/fitness data, including AI-generated insights and memory about them. The platform is a **custodian/processor** acting on the user's instructions; AI providers are sub-processors. Every user-owned record has exactly one owner (§8, rule 7); AI-derived artifacts (insights, digests, traces linked to the user) follow the same export/deletion rules as source data.
- **Sensitivity tiers** govern storage, access paths, retention, and AI eligibility:

| Tier | Examples | Handling |
|---|---|---|
| 1 — Account | Email, credentials hashes, sessions | Standard protection; never sent to AI providers |
| 2 — Health/fitness | Observations, goals, profile attributes, snapshot, conversations, memory | Owner-scoped; AI-eligible via Context Engine under consent and budget |
| 3 — Highly sensitive | Progress photos, source images/documents, raw device payloads, user-stated medical free text, BYOK secrets | Dedicated storage class and access path; AI-ineligible by default (per-use explicit opt-in); strongest retention/deletion discipline; encryption level per ADR-014 (BYOK secrets always application-encrypted) |

### 21.2 Provider data-sharing considerations

- **Sharing matrix (per provider and capability):** what categories may be sent (assembled context only; never credentials, name/email/contact, or Tier-3 data without explicit per-use consent), under what terms (zero-retention/no-training where available for system-provided providers; the user's own terms under BYOK), and where processing occurs. The matrix is documented, versioned, and surfaced in-app (§21, "Transparency").
- Consent is recorded per purpose; withdrawing AI consent disables AI features while core tracking continues. Users can see which provider/model processed a request (trace-derived).

### 21.3 Lifecycle (collection → deletion)

| Data class | Collected when | Retained | Exportable | Deletion |
|---|---|---|---|---|
| Account & sessions | Registration | Until account deletion; sessions until expiry/revocation | Yes (excl. secrets) | Account purge |
| Observations & provenance | User/device/extraction | Until deletion (voiding retains audit linkage) | Yes | Void on request; physical erase in account purge or erasure request |
| Goals, profile, memory | User/AI-proposed + confirmed | Until deletion | Yes | Per-item and account purge |
| Snapshot, aggregates, digests, embeddings | Derived | Rebuildable; not independently retained | Optional (derived) | Purged with owner, invalidated on source change |
| Source images/documents | Upload | User-selectable; default delete-after-commit (provisional, §33 Q7) | Yes if retained | Immediate on user action; derivatives included |
| Conversations & AI traces | Use | User-controllable; traces content-free | Yes (conversations); traces on request | Account purge; aggregates non-identifying |
| Audit events | Security/mutation events | Minimal necessary period | On request | Aged out per policy; identifiers minimized |

### 21.4 Backups and recovery

Backups are encrypted, access-restricted, and restore-tested; retention windows are documented; **restores MUST re-apply completed deletions** (deletion ledger); backup access is audited; keys are managed centrally with rotation (§20.7). Disaster-recovery objectives are set at baseline (§29, Reliability).

---

## 22. Performance Architecture

**Principles**
1. **Mobile first:** fast cold start, instant rendering from local cache, background refresh; AI-dependent UI is never on the critical rendering path.
2. **Efficient APIs:** purpose-built read models for dashboard/trends (batched, cacheable, delta-capable), pagination everywhere, field selection, compression, conditional requests/ETags; avoid chatty multi-call screens.
3. **Efficient data access:** indexes aligned to access patterns (user + type + time), time-bounded queries, precomputed aggregates for common windows, no unbounded scans, connection pooling, query-plan review as a quality gate.
4. **Efficient image handling:** on-device downscaling/compression, resumable uploads, asynchronous processing with progress and notification, thumbnails/derivatives generated server-side, lazy loading.
5. **Streaming AI UX:** stream assistant responses; show retrieval/tool progress states; cap latency with timeouts and fallbacks.
6. **Background work:** extraction, digests, embeddings, exports, deletion, and recomputation run asynchronously with retries, idempotency, and observability.
7. **Scalability posture:** stateless API instances horizontally scalable; worker pool scaled independently; the database is the primary scaling concern, addressed by indexing, read replicas if needed, and partitioning of time-series tables only when data volume demands it (not preemptively).

**AI cost architecture**
- Retrieval and context minimization (§11) are the primary cost levers.
- **Model tiering:** cheap/fast models for classification, routing, summarization, and query planning; stronger models for analysis and complex extraction; chosen per task via the gateway's routing policy (§10.9), not hard-coded.
- **Deterministic first:** calculations, aggregates, and lookups never go through the LLM for arithmetic.
- **Caching:** insight caching keyed by data version; digest reuse; response caching for stable general-knowledge questions (non-personal) where safe; provider-side prompt caching where supported.
- **Avoid re-analysis:** do not regenerate insights when underlying data hasn't changed.
- **Budgets & limits:** per-user daily/monthly token and image budgets, per-feature limits, graceful degradation messaging, system-level cost circuit breakers, per-provider spend tracking.
- **Correctness over thrift:** cost optimizations MUST NOT reduce grounding (e.g., never drop required evidence solely to save tokens; instead, ask a clarifying question or state a limitation).

### 22.1 Failure handling and degradation matrix

| Failure | Required behavior |
|---|---|
| Primary AI provider down/slow | Fallback chain per capability within a timeout; if exhausted, assistant explains, core app continues; dashboard unaffected |
| Vector store unavailable | Degrade to Tier ≤2 (snapshot + structured); tell the user what could not be consulted |
| Snapshot stale/unavailable | Recompute on demand within budget, else flag staleness in the answer; never serve stale as current |
| AI Data Budget exhausted | Degradation ladder (§11.9); explicit limitation in the answer |
| Extraction fails or low quality | Actionable retake/manual-entry guidance; no partial silent save; draft preserved where useful |
| Tool timeout/error | Bounded retry; answer without that evidence and say so; no fabricated substitute |
| Invalid/malformed model output | Structured-output validation → retry/fallback → safe failure message; never execute unvalidated actions |
| Conflicting data (e.g., device vs. manual) | Deterministic precedence policy (§28.1); conflict surfaced to the user when material |
| Offline client | Cached reads; queued append-only writes with idempotency keys; sync conflicts resolved by supersession, never overwrite |
| Job backlog/failures | Retries with backoff, dead-letter handling, user-visible status for long operations |
| Database degradation | Fail closed on writes needing integrity; read-only degraded mode where safe; alerts |

---

## 23. Observability

**Principles:** structured, correlated, privacy-preserving. **Health values, image contents, prompts, and completions MUST NOT appear in logs, traces, or analytics by default.** Debug-level capture of AI content, if ever needed, is opt-in per user/session, time-boxed, and access-controlled.

| Area | Must observe |
|---|---|
| Application | Error rates, crash-free sessions (mobile), latency per endpoint, release health |
| API/Infra | Availability, saturation, queue depth, job failure/retry rates |
| Database | Slow queries, connection saturation, replication/backup status, growth |
| AI | Latency per provider/model/task, success/failure/timeouts, fallback activations, token usage & cost per user/feature/provider, tool-call counts and loops, validation/grounding failures, refusal and safety-trigger rates, budget-exhaustion and degradation events, context-minimization ratio (included vs. actually used), snapshot staleness/recompute/drift rates, routing escalations; **AI Trace Records (§12.8) are the primary source** |
| Extraction | Success rate, low-confidence rate, user edit-rate per field (a quality signal), commit rate |
| Security | Auth failures, token-reuse detections, rate-limit hits, authorization denials, anomalous access, injection-detection triggers, BYOK key failures |
| Background processing | Job latency, retries, dead-letters, deletion/export completion |
| Product (privacy-safe) | Funnel events, feature usage counts (no health content) |

**Capabilities:** distributed tracing across API → assistant → tools → gateway; correlation IDs surfaced to support without exposing content; SLO-based alerting; dashboards for AI cost and quality; audit trail (§20.9) separate from operational logs. **AI quality evaluation** (offline eval suites and sampled, consented review) is an observability concern: grounding accuracy, numeric fidelity, extraction accuracy, refusal appropriateness, language quality.

---

## 24. Technology Stack

The implementation agent retains freedom over exact frameworks, ORMs, packages, and folder structure. The choices below are the *architectural* selections; each has a rationale. Items marked **(free)** are deliberately left open.

| Area | Selection | Rationale |
|---|---|---|
| Mobile | **Flutter** (iOS + Android) | Single codebase, strong rendering control for custom data-rich UI, mature RTL/i18n, good camera/secure-storage ecosystem. State management, navigation, and package choices **(free)**. |
| Backend | **Node.js + TypeScript**, modular monolith | Strong typing end-to-end, large ecosystem for AI SDKs and schema validation, fits team/agent skills. Framework **(free)**. Separate *API process* and *worker process* from one codebase. |
| Primary database | **PostgreSQL** | Relational integrity for append-only, versioned, multi-entity health data; strong time-range indexing; JSON where flexibility is needed; row-level security for defense-in-depth isolation; transactional provenance writes. |
| Vector retrieval | **pgvector within PostgreSQL** (initially) | Embedded content volume per user is small; co-location gives transactional deletion, per-user filtering as a query constraint, and no extra system. A dedicated vector store is a future option only if scale/latency demand it (ADR-004). Exact implementation **(free)**. |
| Cache / queues | **No Redis/broker initially**; Postgres-backed job queue and in-process/DB caches. Introduce Redis (or equivalent) when measured needs appear: distributed rate limiting, hot caches, or queue throughput | Avoids operating extra infrastructure before it is justified (ADR-015). The job abstraction MUST be broker-agnostic so migration is mechanical. |
| Object storage | **S3-compatible private object storage** | Standard, durable, supports signed access, lifecycle rules, server-side encryption, and portability across clouds. |
| AI | **Provider gateway** with capability slots: text/reasoning, vision/OCR, embedding, (future) speech; providers include OpenAI, Gemini, xAI/Grok, other compatible APIs, and future self-hosted models | Prevents lock-in; tasks select models by capability and policy, not by vendor (ADR-005). |
| AI Context Engine / retrieval | Tiered context planning; snapshot-first; structured retrieval; semantic retrieval only when warranted; digests only when justified | See §11 / ADR-006 (amended), ADR-019, ADR-020. |
| AI evaluation | Golden-dataset regression harness integrated with CI and with trace/version metadata | See §31.2; harness tooling **(free)**. |
| Authentication | First-party credentials + optional OIDC social; short-lived access tokens, rotating refresh tokens; passkeys/TOTP-ready | Full control of the sessions/device model; avoids dependency on a third-party identity vendor for sensitive data; can be swapped later behind the `identity` module (ADR-012). |
| Push notifications | Platform push (APNs/FCM) via a thin abstraction; local scheduled notifications first | Reminders can ship without server push complexity. |
| Deployment | **Containerized**, stateless API and workers on a managed container platform; **managed PostgreSQL** with PITR backups; managed object storage; managed secrets/KMS; CDN only for non-sensitive static assets; IaC; separate dev/staging/prod; automated CI/CD with progressive rollout | Minimal ops burden, repeatable environments, security-hardened defaults. Single region initially; region driven by privacy decision (§33). |
| Monitoring | **OpenTelemetry**-based traces/metrics/logs to a managed observability backend; mobile crash/performance reporting; privacy-scrubbed; uptime probes; alerting on SLOs | Vendor-neutral instrumentation; supports AI-specific metrics (§23). |
| Schema & contracts | Single source of truth for API contracts and tool schemas (typed, versioned), used to validate on both server and client **(mechanism free)** | Prevents drift; same mechanism validates AI tool inputs. |

**Explicit non-selections:** microservices (premature), GraphQL as a mandate (open), a separate vector database (premature), a message broker (premature), a Kubernetes mandate (platform choice free), client-side direct calls to AI providers (violates §20/§12), on-device LLMs (future).

---

## 25. Major Architectural Decisions (Summary)

| # | Decision | One-line summary |
|---|---|---|
| ADR-001 | Flutter for mobile | One cross-platform codebase with high UI control |
| ADR-002 | Node.js + TypeScript backend | Typed, ecosystem-rich, matches AI/tooling needs |
| ADR-003 | Modular monolith | Strong boundaries, single deployable, extract later if needed |
| ADR-004 | PostgreSQL (+ pgvector) | Integrity + isolation + co-located retrieval |
| ADR-005 | AI provider abstraction with capability slots | Provider independence, BYOK, fallback, cost control |
| ADR-006 | Hybrid structured-first retrieval *(amended v1.1: now an instrument of the Context Engine)* | Minimal context, correctness, token efficiency |
| ADR-007 | Capability-based AI data access | AI never touches the database; server-injected identity |
| ADR-008 | Propose → confirm → commit for AI writes | AI cannot write; receipts are the only truth of persistence |
| ADR-009 | First-class provenance + append-only facts | Traceability, corrections without history loss |
| ADR-010 | Deterministic calculation engine | Math and safety rules are not probabilistic |
| ADR-011 | Private media pipeline with draft-review-commit | Secure uploads; AI extraction is never auto-saved |
| ADR-012 | First-party auth with rotating sessions | Control over device sessions and recovery |
| ADR-013 | Defense-in-depth tenant isolation | App-level + DB-level enforcement |
| ADR-014 | Encryption strategy | Storage encryption everywhere; app-level encryption for secrets |
| ADR-015 | Infrastructure minimalism (no broker/Redis initially) | Add components only on measured need |
| ADR-016 | Seams for nutrition and workouts via registration | Future domains attach without core change |
| ADR-017 | Localization as architecture | Codes in data, labels in catalogs, logical layout |
| ADR-018 | User-provided provider keys (BYOK) as a gated capability *(amended v1.1: BYOK-ready in launch, user-facing BYOK gated)* | Flexibility without key leakage or SSRF |
| ADR-019 | AI Context Engine with tiered context and Health Snapshot | Smallest sufficient context; common requests never rebuild history |
| ADR-020 | Explicit AI Data Budget | Bounded cost, latency, and agent behavior |
| ADR-021 | Canonical units via dimension registry; original preserved | No presentation-unit coupling; extensible metrics |
| ADR-022 | Content-minimized AI traceability | Debuggable, reproducible, trustworthy AI without logging health data |
| ADR-023 | Deterministic-first task/model routing | Cost, quality, and provider independence per task |
| ADR-024 | Lineage-driven invalidation of derived data | Derived data never drifts from source truth |

---

## 26. Architecture Decision Records

### ADR-001 — Flutter for mobile
- **Decision:** Build the client in Flutter targeting iOS and Android.
- **Reason:** The product is chart- and form-heavy and needs custom, premium visual design with strong RTL support and a camera-centric flow. Flutter gives pixel-level control and one codebase.
- **Alternatives:** Native (Swift/Kotlin) ×2; React Native; PWA.
- **Why preferable:** Native doubles cost for similar UX; React Native offers less rendering control for custom data visualization; PWA is weak for camera, secure storage, and push.
- **Consequences:** Plugin dependence for platform features; need disciplined platform-security configuration; Dart skill requirement.

### ADR-002 — Node.js + TypeScript backend
- **Decision:** Backend in Node.js with TypeScript.
- **Reason:** Strong typing for contracts and tool schemas; excellent async I/O for AI/provider calls and streaming; first-class SDK support across AI providers.
- **Alternatives:** Python (FastAPI), Go, JVM.
- **Why preferable:** Python's AI ecosystem advantage is largely neutralized by provider SDKs/HTTP APIs and the fact that heavy ML is not done in-process; Go/JVM add friction for rapid iteration on schema-driven AI tooling.
- **Consequences:** CPU-heavy work (image processing, batch compute) belongs in workers; avoid event-loop blocking; if specialized ML is needed later, isolate it behind a service interface.

### ADR-003 — Modular monolith
- **Decision:** One deployable backend composed of strictly bounded internal modules (§8), with separate API and worker processes.
- **Reason:** The team/product is early; domain boundaries are still being learned; operational simplicity matters.
- **Alternatives:** Microservices; serverless functions; unstructured monolith.
- **Why preferable:** Microservices impose distributed-systems cost without a scaling need; an unstructured monolith would make future nutrition/workout domains hard to add.
- **Consequences:** Boundaries must be *enforced* (dependency rules, lint/architecture tests); modules own their data; extraction to services remains possible because modules communicate via narrow interfaces.

### ADR-004 — PostgreSQL with pgvector
- **Decision:** PostgreSQL as the system of record and initial vector store.
- **Reason:** The domain is relational and temporal with integrity needs (supersession, ownership, provenance); RLS supports isolation defense-in-depth; per-user embedding volume is small.
- **Alternatives:** MongoDB/document DB; MySQL; dedicated vector DB (e.g., Pinecone/Qdrant); time-series DB.
- **Why preferable:** Document stores weaken integrity guarantees; a time-series DB is unnecessary at per-user low-frequency volumes; a separate vector DB adds consistency, deletion, and isolation complexity for little gain.
- **Consequences:** Retrieval layer MUST sit behind an interface so a dedicated vector store can replace pgvector; time-partitioning is deferred until data volume requires it.

### ADR-005 — AI provider abstraction with capability slots
- **Decision:** A gateway module exposes capability slots (text, vision, embedding) with provider adapters, model registry, routing policy (task → model tier), fallback chains, usage metering, and limits. Domain code and the assistant never call provider SDKs directly.
- **Reason:** Provider quality, price, and availability change rapidly; users may bring their own keys; privacy needs may demand self-hosted models.
- **Alternatives:** Single-provider integration; third-party LLM router/proxy as a hard dependency.
- **Why preferable:** Single-provider creates lock-in; an external router adds a third party handling health data and a point of failure (it MAY be used as an adapter, not as the architecture).
- **Consequences:** Lowest-common-denominator risk is avoided by *capability negotiation* (structured output, tool calling, vision, context size are declared per model). **Embeddings are independent of chat provider**; changing the embedding model requires re-embedding (tracked via model/version tags). Evaluation suites guard against regressions on provider switch.

### ADR-006 — Hybrid structured-first retrieval (amended v1.1)
- **Decision:** Retrieval prioritizes exact structured lookups and deterministic summaries; semantic retrieval is reserved for unstructured text; context is token-budgeted and provenance-labeled.
- **Reason:** Most user questions are numeric/temporal and are best answered exactly; embeddings are poor for numeric precision and cost tokens.
- **Alternatives:** Pure vector-RAG over all data; full-history prompt stuffing; fine-tuning on user data.
- **Why preferable:** Pure vector-RAG is imprecise and expensive for time series; stuffing is costly, leaky, and degrades quality; fine-tuning is unsuitable for per-user, mutable, deletable data.
- **Consequences:** Requires derived summaries and an intent/planning step; digests must be invalidated on corrections.
- **Amendment (v1.1):** v1.0 framed retrieval/RAG as *the* context architecture. It is now one instrument of the **AI Context Engine** (ADR-019); many requests need no retrieval at all (Tier 0–1). The decision itself (structured-first, semantic only for unstructured content, token-budgeted, provenance-labeled) is unchanged.

### ADR-007 — Capability-based AI data access
- **Decision:** The AI accesses data only via registered tools with strict schemas, server-injected identity, least-privilege per intent, bounded outputs, and audit.
- **Reason:** Prevents unrestricted access and authorization bypass by construction.
- **Alternatives:** Text-to-SQL; giving the model an authenticated API client; pre-stuffing all data.
- **Why preferable:** Text-to-SQL and broad API access make cross-user leakage and injection-driven exfiltration plausible; capability scoping makes the safe path the only path.
- **Consequences:** Every new domain must publish tool-friendly read interfaces; some questions need multi-step tool use (bounded).

### ADR-008 — Propose → confirm → commit for AI writes
- **Decision:** The AI emits proposals only; commits occur through user-confirmed, system-executed actions with receipts and idempotency; success claims derive from receipts.
- **Reason:** Preserves data integrity and user trust; defends against injection-triggered writes and hallucinated success.
- **Alternatives:** Autonomous AI writes; chat-text confirmation ("yes").
- **Why preferable:** Autonomy is unacceptable for health records; chat-text confirmation can be spoofed by injected content, whereas a UI-channel event cannot be forged by the model.
- **Consequences:** Slightly more friction (mitigated by one-tap confirmations and undoable safe writes).

### ADR-009 — First-class provenance and append-only facts
- **Decision:** All important facts are immutable records with provenance; corrections supersede.
- **Reason:** Trust, explainability, auditability, and reproducible trends/calculations.
- **Alternatives:** Mutable "current value" fields; audit-log-only history.
- **Why preferable:** Mutable fields destroy history and trend integrity; audit logs alone don't give queryable provenance for analytics/AI weighting.
- **Consequences:** Read models must resolve "active" observations; storage grows modestly (acceptable at this data frequency).

### ADR-010 — Deterministic calculation engine
- **Decision:** A versioned, pure calculation module is the sole source of health math and safety guardrails.
- **Reason:** LLMs are unreliable for arithmetic and unsafe as the owner of health-safety rules.
- **Alternatives:** LLM-computed values; formulas embedded in prompts.
- **Why preferable:** Determinism, testability, reproducibility, and explainability.
- **Consequences:** Every new calculation requires engineering, not prompting; formula changes require versioning.

### ADR-011 — Media architecture (private, scanned, draft-review-commit)
- **Decision:** Private object storage; server-side validation/scanning/re-encoding; asynchronous extraction into drafts; mandatory review; provenance link to artifact; user-controlled retention.
- **Reason:** Images are sensitive, can be malicious, and vision extraction is fallible.
- **Alternatives:** Direct client-to-provider image calls; auto-save after extraction; storing public URLs.
- **Why preferable:** Direct client-to-provider bypasses security/cost controls; auto-save would inject unreviewed errors into the health record.
- **Consequences:** Extraction is asynchronous with state management; review UX is a first-class feature.

### ADR-012 — First-party authentication with rotating sessions
- **Decision:** Own the credential and session model (device-bound refresh rotation, reuse detection), with optional OIDC identities and MFA readiness.
- **Reason:** Sensitive data demands precise control over sessions, revocation, and recovery.
- **Alternatives:** Managed identity provider as the only auth; long-lived static tokens.
- **Why preferable:** Static tokens are unsafe; a managed IdP is acceptable but should sit behind the `identity` module so it remains replaceable.
- **Consequences:** Team owns security-critical code; mandatory security review and test coverage for auth flows. Adopting a managed IdP is permitted *if* it satisfies session/device, deletion, export, and residency requirements.

### ADR-013 — Defense-in-depth tenant isolation
- **Decision:** Ownership enforced in a central application layer *and* at the database layer; isolation tests are mandatory.
- **Reason:** Cross-user leakage is the highest-severity risk; single-layer checks fail by omission.
- **Alternatives:** Per-endpoint ad-hoc checks only; database-per-user.
- **Why preferable:** Ad-hoc checks regress; database-per-user is operationally heavy and unnecessary.
- **Consequences:** Request-scoped identity context must propagate to data access, including background jobs and AI tools.

### ADR-014 — Encryption strategy
- **Decision:** Encryption in transit and at rest everywhere; application-level (envelope) encryption mandatory for provider secrets; field-level encryption for health data is *not* initially mandated but the data layer MUST not preclude it.
- **Reason:** Balances security with query/analytics needs and complexity.
- **Alternatives:** Full field-level encryption of all health fields from day one; storage-level only.
- **Why preferable:** Full field-level encryption complicates analytics/retrieval substantially; storage-level-only is insufficient for secrets.
- **Consequences:** Revisit if regulation, enterprise/clinical use, or threat model demands stronger guarantees; key management is centralized.

### ADR-015 — Infrastructure minimalism
- **Decision:** No message broker or Redis in the initial release; Postgres-backed jobs and caches behind abstractions.
- **Reason:** Fewer moving parts and lower operational/security surface at launch scale.
- **Alternatives:** Redis + BullMQ-style stack from day one; cloud queue service.
- **Why preferable:** Not justified by measured need; abstractions keep migration cheap.
- **Consequences:** Rate limiting must be designed for a single-store implementation initially; revisit upon scale triggers (defined in §29).

### ADR-016 — Registration-based seams for nutrition and workouts
- **Decision:** Future domains integrate by registering catalogs, tools, widgets, formulas, retrieval sources, digests, and privacy contracts — not by modifying core modules.
- **Reason:** Prevents both premature implementation and future rewrites.
- **Alternatives:** Build placeholder tables now; build everything now.
- **Why preferable:** Placeholders create misleading, untested structure; building now inflates scope.
- **Consequences:** The extension contract is itself part of the initial design and is validated by a design review ("could nutrition be added with registrations only?").

### ADR-017 — Localization as architecture
- **Decision:** Stable codes in data; localized labels in catalogs; logical layout; locale-aware formatting; AI language control; units independent of language.
- **Reason:** Arabic/English with RTL is a launch requirement and retrofitting is costly.
- **Alternatives:** Hard-coded strings with later translation; mirrored layouts via flags.
- **Why preferable:** Retrofits cause data-model and layout defects.
- **Consequences:** Content authoring (catalog names, knowledge base) needs bilingual review.

### ADR-018 — BYOK as a gated capability
- **Decision:** Users may configure supported providers with their own key under write-only, encrypted, gateway-only handling, with consent and quotas distinct from system-provided usage.
- **Reason:** Cost relief, user choice, and privacy preference.
- **Alternatives:** System-only keys; arbitrary custom endpoints.
- **Why preferable:** System-only limits flexibility; arbitrary endpoints open SSRF and exfiltration paths.
- **Consequences:** Capability mismatches between providers must be surfaced to users; evaluation guarantees apply only to supported/tested models, and the UI says so.
- **Amendment (v1.1):** v1.0 required user-facing BYOK in the initial release, which risked scope inflation (the product vision says users "may eventually" supply keys). Now: the **gateway MUST be BYOK-ready at launch** (encrypted secret custody, per-request credential resolution, allowlisted provider types) because these are costly to retrofit, while the **user-facing BYOK configuration ships gated** (Phase 6, release-optional pending §33 Q15).

### ADR-019 — AI Context Engine with tiered context and Health Snapshot
- **Decision:** A logical Context Engine plans the lowest sufficient context tier (0: none → 4: deep analysis) per request, preferring a compact, versioned, derived **Health Snapshot** before any retrieval; domains register context providers and snapshot sections.
- **Reason:** Most user questions are about *current state* and recent change; rebuilding history or retrieving semantically for each request wastes tokens, adds latency, and increases leakage surface.
- **Alternatives:** RAG-for-everything; fixed context templates per intent; full-history prompting.
- **Why preferable:** RAG-for-everything is imprecise for numbers and costly; fixed templates don't adapt and bloat; full-history prompting violates minimization and cost goals.
- **Consequences:** The snapshot needs a strict consistency/invalidation contract (§7.8) and a drift-detection mechanism; the planner needs evaluation (context-selection and minimization metrics, §31.2); added moving part is justified by cost and correctness gains. The engine's *mechanism* (rules vs. small-model planning, snapshot storage and refresh) is left to the implementation agent.

### ADR-020 — Explicit AI Data Budget
- **Decision:** All AI operations run under enforced, configurable budget profiles across records, depth, context, tool use, output, time, media, and cost (§11.9).
- **Reason:** Agentic/tool-using systems fail expensively and unpredictably without hard bounds; denial-of-wallet is also a security risk.
- **Alternatives:** Provider-side limits only; prompt instructions asking the model to be brief; global rate limits only.
- **Why preferable:** Only server-enforced, per-operation budgets guarantee bounded behavior and make exhaustion handling testable.
- **Consequences:** Needs baseline measurement before choosing numbers; degradation behavior must be designed and evaluated; budgets are configuration with versioning.

### ADR-021 — Canonical units via dimension registry; original preserved
- **Decision:** Every quantity has a dimension and one canonical unit in a versioned registry; all channels normalize at the boundary; originals (value, unit, precision, conversion version) are retained; display units are preferences only. Dietary energy is canonical in kcal.
- **Reason:** Users mix units; devices and OCR add ambiguity; future metrics (nutrition, sensors) multiply unit variety.
- **Alternatives:** Store in the user's entered unit; store only canonical; store per-user preferred unit.
- **Why preferable:** Entered-unit storage breaks analytics and comparisons; canonical-only loses fidelity and auditability; preferred-unit storage couples data to presentation.
- **Consequences:** Registry governance and versioning; precision policy; conversion errors become testable defects.

### ADR-022 — Content-minimized AI traceability
- **Decision:** Every important AI operation yields a trace of versions, routing, context manifest (identifiers, not values), tools, calculations, evidence mix, safety handling, and budget use, without storing prompts/completions/health values by default.
- **Reason:** Debugging, reproducibility, safety review, and user trust require knowing *what influenced* an answer; privacy forbids logging content.
- **Alternatives:** Full prompt/response logging; usage-only metering; no AI tracing.
- **Why preferable:** Full logging is a privacy liability; metering alone cannot explain behavior; append-only versioned data makes content-free reproducibility possible.
- **Consequences:** Strict versioning discipline for prompts/policies/tool schemas/formulas; opt-in, time-boxed content capture for debugging; trace retention and deletion policy.

### ADR-023 — Deterministic-first task/model routing
- **Decision:** The gateway routes by task class, capability needs, language, sensitivity/consent, budget, health, and evaluation approval; deterministic logic handles whatever needs no model; escalation and fallback are bounded and recorded.
- **Reason:** Cost, latency, and quality differ sharply by task; provider landscape changes rapidly.
- **Alternatives:** One model for everything; user-chosen model only; hard-coded vendor per feature.
- **Why preferable:** A single model overpays and underperforms on some tasks; user-only choice cannot guarantee quality or safety; hard-coding recreates lock-in.
- **Consequences:** Model registry with declared capabilities and eval status; routing policy needs tuning and monitoring; users are shown which provider/model handled a request.

### ADR-024 — Lineage-driven invalidation of derived data
- **Decision:** Derived data (metrics, aggregates, snapshot sections, insights, recommendations) records its inputs by identity and version; changes upstream invalidate and recompute downstream as new versions; stale AI artifacts are never re-presented as current.
- **Reason:** Corrections, late-arriving data, unit-registry fixes, and formula changes would otherwise leave silently wrong derived values.
- **Alternatives:** Time-based cache expiry only; recompute everything on every read; overwrite in place.
- **Why preferable:** Expiry-only is eventually wrong; recompute-always is costly; overwrite destroys reproducibility.
- **Consequences:** Dependency metadata on every derived artifact; granular invalidation logic; reconciliation checks.

---

## 27. Initial Release Scope

### 27.1 MUST exist

| Area | Required |
|---|---|
| Identity | Registration, login, email verification, recovery, device/session management, logout-all, account deletion, data export, consent management, age gate |
| Profile | Minimal profile with versioned calculation-relevant attributes; extensible attribute mechanism |
| Measurements | Catalog-driven historical observations with units, provenance, supersession/correction, quality flags; manual entry; core types (weight, body fat, muscle/lean mass, body water, visceral fat, bone mass, BMI, key circumferences) |
| Goals | Multiple goals, primary goal, versioning, progress evaluation for weight/composition/measurement-target/maintenance types; consistency goal types limited to what measurement logging supports |
| Analytics | Trends, deltas, period comparison, goal progress, anomaly flags |
| Calculations | BMI, BMR, TDEE, maintenance, deficit/surplus ranges, macro target ranges, rate/projection; safety guardrails |
| Units & time series | Unit Registry with canonical normalization and original-preservation (§7.5); lineage and invalidation (§7.6); rollups, series-class/aggregation semantics, interval support (§7.7) |
| Health Snapshot | Initial sections (§7.8) with consistency guarantees and drift reconciliation |
| Dashboard | Widget framework + initial widget set (§18.1) |
| AI assistant | Conversational analysis, explanation, calculation orchestration, memory, streaming responses, evidence labeling, proposals/receipts, safety classification and response modes (§10.6.1), content-free AI traces (§12.8) |
| AI Context Engine | Tiered context planning (Tiers 0–4), snapshot-first, structured retrieval, semantic retrieval for notes/memory/documents/knowledge base where warranted, context manifests, **AI Data Budget** enforcement. *Digests deferred behind a Phase-3 decision gate (§11.5)* |
| AI gateway | Provider abstraction with **at least two independent provider adapters for the text capability** (to prove the abstraction) and at least one for vision and embeddings; **task/model routing** (§10.9), fallback, usage ledger, limits |
| BYOK-readiness | Encrypted secret custody, per-request credential resolution, provider allowlist, SSRF controls (§20.5) **in the gateway at launch**; the *user-facing* BYOK configuration ships gated in Phase 6 and is release-optional (§33 Q15) |
| Multimodal | Camera/upload, secure pipeline, body-composition report / scale-display / tape-sheet extraction (§13.4), adaptive-intensity review, commit, provenance |
| Security & privacy | Everything in §20 and §21 flagged as required for launch |
| Localization | Arabic/English, RTL/LTR, numeral preference, unit preferences, AI language control |
| Notifications | Local reminders for measurement/review (foundation) |
| Observability | §23 baseline including AI metrics and privacy-safe logging |
| Quality | All gates in §31, including the AI evaluation harness and golden datasets (§31.2) |

### 27.2 Prepared, NOT implemented
Workout management and exercise library; nutrition logging/food DB/barcode; wearables and smart-scale integrations (design the ingestion/provenance path only); sleep/recovery/hydration/cardio metric types (catalog extensibility only); advanced computer vision (food, exercise, equipment, physique estimation); **private progress photos (§28.2)**; supplements, habit tracking, barcode scanning, nutrition-label and food-image extraction (§13.4); server push beyond a thin abstraction; social/community; coach/practitioner multi-user relationships; on-device AI; voice interaction.

### 27.3 Scope guardrails
- A feature enters the initial release only if absent it, a core journey (J1–J11) breaks or a safety/privacy requirement fails.
- No schema, UI, or tool for a future domain may ship unless it is exercised by a real initial-release use case.

---

## 28. Future Scope

Ordered by expected product value and architectural readiness (not a commitment):

1. **Nutrition management** (food DB, logging, barcode, food-image estimates, adaptive TDEE from intake vs. trend).
2. **Workout platform** (exercise library, plans, logging, PRs, progressive overload, AI-generated programs as proposals).
3. **Integrations** (smart scales, Apple Health/Health Connect, wearables) via an **Integration Connection** concept: OAuth/credential custody, import batches with provenance and dedupe, conflict resolution rules (device vs. manual), per-source trust weighting.
4. **Sleep, recovery, hydration, cardio** (new catalog types + dashboard widgets + digests).
5. **Advanced notifications** (server push, AI-scheduled reminders with user-approved cadence).
6. **Advanced vision** (food/exercise/form analysis with explicit low-confidence handling).
7. **Self-hosted/local model support** (gateway adapter; network-boundary design).
8. **Coach/practitioner sharing** (explicit, scoped, revocable data sharing — a major privacy and authorization extension that requires its own ADR).
9. **Wellness reports** (shareable/exportable summaries with user control).
10. **MFA/passkeys mandatory options, field-level encryption, enterprise/clinical posture** (if the market requires).

Each future item MUST integrate via the registration seams (ADR-016) and implement the privacy export/delete contract.

### 28.1 Integration readiness (architecture now, implementation later)

Future integrations (Apple Health, Google Health Connect, smart scales, wearables, trackers, sleep, hydration, nutrition systems, barcode services, cardio, recovery, supplements, habits) MUST attach **without redesigning the core health-data model**. The model already provides the seams:

1. **Ingestion path:** Integration Connection (scopes, consent, credential custody, sync state) → Import Batch → Raw Payload reference (retained per policy) → source-specific **mapper** to catalog types and canonical units → validation/dedupe → Observations or Events with provenance (origin = device/integration, source app/device, **external record identifier** for idempotent re-sync, import-batch lineage).
2. **Catalog extensibility:** new metrics (HRV, sleep stages, hydration, steps, supplement doses, habit check-ins) are catalog + registry entries (§7.5, §7.7); dense series use the series-class mechanism.
3. **Record shapes:** Observations (values over time), **Events** (structured happenings), Targets/Plans (intent) — the three shapes cover wearables, workouts, meals, supplements, and habits.
4. **Conflict and trust policy:** deterministic, per-metric **source precedence** (e.g., direct device measurement > imported summary > manual assertion > estimate), configurable by the user where meaningful; conflicts surfaced when material; no silent overwrite (supersession and provenance preserve both).
5. **Consent and lifecycle:** per-integration scopes and consent; revocation stops sync and offers to retain or delete imported data; imported data obeys the same export/deletion/provenance contracts; integration credentials are Tier-3 secrets.
6. **Registration seams:** each integration/domain registers catalog entries, mappers, snapshot sections, context providers, tools, widgets, and privacy contracts (ADR-016).
**Not built now:** any connector, sync scheduler, or dense-data store. Only the seams above are validated by design review.

### 28.2 Progress photos (future capability)

Private progress photos are a plausible, high-sensitivity future feature. The initial architecture reserves the following (no UI, no pipeline now):

- **Entities:** Progress Photo Set (capture session: date, time-zone, context) and Photo (angle: front/side/back/other; artifact link; metadata). **Capture-conditions metadata** (lighting, time of day, fasted/clothing notes, distance/pose guide used, device) to make comparisons meaningful.
- **Storage and access:** Sensitivity **Tier 3** (§21.1): dedicated storage class and access path, short-lived signed access, owner-only, never public, never in notifications or share sheets; app-switcher/screenshot privacy affordances; EXIF/GPS stripped; immediate, complete deletion including derivatives and thumbnails; included in export; encryption level per ADR-014 (flagged for decision, §33 Q17).
- **Comparison:** side-by-side/time-aligned viewing performed locally by default with consistent framing aids; no AI required.
- **AI involvement:** **opt-in per use**, with explicit provider disclosure; photos are never part of default context; no face recognition or identification; no automatic body-composition inference stored as measurement.
- **Epistemics:** any AI visual estimate is **Estimate-class** (§13.4), labeled "visual estimate," excluded from measured trends and calculations by default, and visually distinct from device/report measurements.
- **Sharing:** none initially; any future sharing requires its own ADR and consent model.
- **Seam proof:** the `media` module's sensitivity tiers and the provenance/estimate classes introduced in v1.1 are what make this attachable without core changes.

---

## 29. Non-Functional Requirements

Where numeric targets would be arbitrary at this stage, the principle governs; teams SHOULD establish baselines during the first release and convert principles to SLOs.

| Area | Requirement |
|---|---|
| **Security** | No cross-user access paths (verified by automated tests on every endpoint and tool); secrets never in client/logs/prompts; all findings of high severity from penetration test remediated before public launch; dependency vulnerabilities triaged within a defined SLA |
| **Reliability** | Writes are durable and idempotent; no silent data loss; PITR-capable backups with periodically *tested* restores; graceful degradation when AI/providers are down (core tracking continues); retries with backoff and dead-letter handling for jobs |
| **Performance** | Cached dashboard renders from local data immediately; API read endpoints for dashboard/trends respond within interactive latency budgets (target p95 defined at baseline, e.g., sub-second class); assistant first-token latency tracked and budgeted; image upload resilient to poor networks |
| **Scalability** | Stateless API/workers scale horizontally; defined *scale triggers* (e.g., DB CPU/IO saturation, job queue latency, rate-limit coordination needs) that justify Redis, replicas, partitioning, or vector-store extraction |
| **Maintainability** | Enforced module boundaries; contract-first APIs and tool schemas; consistent error model; documented ADRs kept current; architecture tests |
| **Testability** | Calculation engine property-tested; domain logic unit-tested; API contract tests; end-to-end critical-journey tests; AI eval suites; deterministic test doubles for providers |
| **Accessibility** | WCAG 2.2 AA-equivalent for mobile; screen-reader support including chart alternatives; dynamic type; sufficient contrast; reduced motion; RTL-correct focus order |
| **Localization** | Full parity of Arabic and English for all UI, notifications, errors, exports, and AI responses; no hard-coded strings; RTL visual regression coverage |
| **Privacy** | Export and deletion complete across all modules with verifiable completion; consent recorded; no health content in logs/analytics by default |
| **Observability** | All §23 signals present before launch; correlation across API/assistant/tools/gateway; alerts on SLOs and security events |
| **AI reliability** | Grounding accuracy, numeric fidelity, abstention behavior, and extraction accuracy measured by standing eval suites; regressions block releases; provider failures trigger fallback within a defined timeout |
| **AI cost efficiency** | Per-user and global budgets enforced; cost per assistant turn and per extraction tracked; context size distributions monitored; caching hit rate tracked; cost optimizations validated not to reduce grounding |
| **Data integrity** | Append-only invariants enforced by design (no update/delete paths for facts outside sanctioned flows); referential integrity; provenance mandatory; migrations reversible or safely forward-only with backups; canonical-unit round-trip fidelity; downstream invalidation on every upstream change (§7.6) |
| **Time series & units** | Rollups correct under backfill/corrections and across time zones; per-type aggregation semantics enforced; no silent interpolation; conversions covered by registry-level tests |
| **Snapshot** | Per-section bounded staleness defined at baseline and visible via as-of; zero tolerated unflagged divergence from recomputation (drift alert); common AI requests satisfiable without history reconstruction |
| **AI data budget** | Every AI operation runs under an enforced budget profile; exhaustion yields explicit, tested degradation; budgets configurable and versioned |
| **AI traceability** | Every important AI operation has a trace sufficient to answer §12.8's questions without content or secrets; traces deleted/exported with the user |

---

## 30. Risks & Mitigations

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | **AI hallucination** (invented values, history, or certainty) | High | Sufficiency gating; numeric provenance checks; evidence-type labeling; receipt-bound action claims; eval suite gating (§10.8) |
| R2 | **Incorrect visual extraction** corrupts the record | High | Mandatory review; per-field confidence; plausibility & consistency validation; edit-rate monitoring; no auto-save |
| R3 | **Harmful or medical advice** | High | Guardrails in calculation/policy layer; scope limits; special-population handling; disordered-eating response protocol; professional-help signposting; legal review of disclaimers |
| R4 | **Excessive token/image cost** | Medium | Context minimization; tiered models; caching/digests; budgets and circuit breakers; denial-of-wallet protections |
| R5 | **Unrestricted AI data access** | Critical | Tool-registry-only access; no raw queries; server-injected identity; least privilege; audit |
| R6 | **Cross-user leakage** (IDOR, cache, vector, jobs) | Critical | Central ownership enforcement + DB-level isolation; owner-scoped caches/vectors/jobs; mandatory cross-user test suite |
| R7 | **Prompt injection (direct/indirect)** | High | Channel separation; untrusted-data marking; out-of-band confirmation; per-intent tool sets; red-team gate |
| R8 | **Poor domain boundaries** | High | ADR-003 enforcement; architecture tests; extension-contract design review |
| R9 | **Overengineering / scope inflation** | High | §27 scope guardrails; "no placeholder tables"; ADR-015 minimalism; periodic scope review |
| R10 | **Premature workout/nutrition complexity** | Medium | Seams only; registration contract; explicit §27.2 prohibition |
| R11 | **Data integrity problems** (duplicates, unit errors, silent overwrites) | High | Append-only facts; canonical units; duplicate/outlier detection; supersession; transactional provenance |
| R12 | **Provider lock-in / provider deprecation** | Medium | Gateway abstraction; capability slots; eval suites per provider; independent embedding slot |
| R13 | **Poor mobile performance** | Medium | Local-first reads; purpose-built read models; streaming UX; performance budgets in CI |
| R14 | **Sensitive-data leakage** via logs, crash reports, analytics, providers | High | Privacy-scrubbed telemetry; provider minimization; no PII to providers; data-handling review |
| R15 | **BYOK key compromise or SSRF** | High | Envelope encryption; write-only; gateway-only egress; supported-provider allowlist; SSRF controls |
| R16 | **Regulatory exposure** (health data, minors, cross-border) | High | Privacy architecture capabilities; age gate; consent management; legal review pre-launch; residency decision |
| R17 | **Inconsistent AI behavior across providers/models** | Medium | Capability negotiation; structured outputs; eval-gated model changes; "supported model" list for BYOK |
| R18 | **User over-trust in AI/estimates** | Medium | Evidence labels; visible confidence; calculation transparency; consistent estimate styling |
| R19 | **Vulnerable users / unhealthy goal pursuit** | High | Rate caps; abnormal-goal detection; supportive redirection; no gamified restriction |
| R20 | **Arabic/RTL quality gaps** (OCR, AI language, layout) | Medium | Bilingual eval sets; RTL regression; native-speaker review of catalogs and prompts |
| R21 | **Snapshot staleness or divergence** from source data | High | Watermarks, granular invalidation, on-demand recompute, scheduled reconciliation with drift alerts (§7.8) |
| R22 | **Context Engine over-complexity** (planner becomes a second product) | Medium | Deterministic-first planning; lowest-tier-first rule; digests behind a decision gate; evaluate minimization and correctness before adding sophistication |
| R23 | **Unit conversion/precision errors** | High | Registry-governed conversions, original preserved, round-trip tests, ambiguity never guessed (§7.5) |
| R24 | **Progress-photo sensitivity** (when introduced) | High | Tier-3 handling, opt-in AI, no default context, immediate deletion, explicit visual-estimate labeling (§28.2) |
| R25 | **Integration data conflicts/duplication** (future) | Medium | External identifiers, deterministic source precedence, supersession, import-batch lineage (§28.1) |
| R26 | **Stale AI artifacts presented as current** after corrections | Medium | Lineage-driven invalidation of insights/recommendations (§7.6, ADR-024) |
| R27 | **Eval set drift/overfitting** (suite stops reflecting reality) | Medium | Versioned datasets, production-informed additions (privacy-reviewed), periodic review, human-calibrated judges |
| R28 | **Trace/telemetry becoming a privacy liability** | High | Content-free by default, opt-in time-boxed capture, deletion with user, access control (§12.8, §23) |

---

## 31. Quality Gates

### 31.1 Release gates

A release candidate MUST pass all applicable gates:

1. **Isolation gate:** automated cross-user access tests pass for every endpoint, tool, job type, and retrieval path.
2. **AI safety gate:** red-team suite (direct/indirect injection, exfiltration, tool abuse, unsafe-advice jailbreaks) passes; no unconfirmed writes possible in any test.
3. **AI grounding gate:** eval suite shows numeric fidelity and correct abstention above agreed thresholds on missing/contradictory/stale-data scenarios; thresholds recorded and non-regressing.
4. **Extraction gate:** accuracy and calibration measured on a bilingual (Arabic/English) report set; low-confidence fields are reliably flagged.
5. **Calculation gate:** reference-value and property tests pass for every formula version; guardrails tested at boundaries.
6. **Provenance gate:** no record creation path exists without provenance; supersession tests prove history preservation.
7. **Privacy gate:** export completeness and deletion completeness verified end-to-end, including embeddings, files, caches, derived data, and backups procedure.
8. **Security gate:** SAST, dependency, and secret scans clean; auth flow review; BYOK handling review; pre-launch penetration test.
9. **Localization/Accessibility gate:** RTL/LTR visual regression, screen-reader walkthrough of critical journeys, text-scaling checks, Arabic content review.
10. **Performance/cost gate:** performance budgets met on reference low-end devices; AI cost per turn within budget; query plans reviewed.
11. **Resilience gate:** provider outage and database failover drills show graceful degradation; backup restore tested.
12. **Observability gate:** required signals, alerts, and runbooks exist; log scrubbing verified by test.
13. **Architecture gate:** module-boundary tests pass; ADRs current; extension-contract review confirms nutrition/workouts could attach via registration.
14. **Traceability & budget gate:** every AI operation type emits a compliant trace; budget enforcement and exhaustion degradation verified; no secrets/content in traces by test.
15. **Units, lineage & snapshot gate:** unit round-trip and ambiguity tests pass; correction/void/formula-change invalidation proven downstream; snapshot-vs-recompute reconciliation clean.

---

### 31.2 AI evaluation and regression strategy

AI behavior is evaluated as a first-class engineering concern, not by checking that an API call succeeds. **The harness begins in Phase 3 and grows with every AI feature; Phase 6 hardens it, it does not introduce it.**

**Scenario coverage (minimum):** correct retrieval of user data; correct context selection and **context minimization** (included vs. actually needed); correct use of deterministic calculations (numbers in prose match tool results); avoidance of hallucinated user data and correct abstention on missing/contradictory/stale data; authorization boundaries (no cross-user or out-of-scope access); tool/action behavior (proposal-only writes, receipts, confirmation required); resistance to direct and indirect prompt injection (including text embedded in images/documents); estimate-vs-measured phrasing; safe responses to concerning health situations (§10.6.1 categories); provider/model failures, malformed outputs, timeouts, and budget exhaustion; extraction accuracy and calibration (Arabic and English); and behavior after changes to prompts, models, retrieval/planning, budgets, or tool schemas.

**Golden datasets:** synthetic user personas with scripted histories (no real user data), each with expected *properties* rather than exact wording — required evidence, forbidden claims, expected tier, tools allowed/forbidden, numeric truths, budget ceilings, and expected safety category. Datasets are versioned, bilingual, and reviewed by domain and native-language experts.

**Assertion types:** (1) **deterministic checks** wherever possible — numeric fidelity, tool-call sequence, authorization, manifest within budget, no unlabeled estimate-as-fact; (2) **rubric/model-graded checks** for qualitative aspects (tone, clarity, appropriateness), calibrated against periodic human review and never the sole gate for safety or correctness.

**Run triggers:** any change to prompts/policies, model or provider, routing, retrieval/planning logic, tool schemas, budgets, calculation formulas, or unit registry; scheduled drift runs against production-approved configurations; provider-version change notices.

**Matrix and approval:** results are recorded per (task class × provider/model × language) and linked to the versions in AI traces. A model is eligible for a task class only after passing its suite (§10.9); BYOK-supported models are listed as supported only if evaluated.

**Release criteria:** thresholds are established at baseline, recorded, and **non-regressing**; safety and authorization suites have zero-tolerance failures; failures block release.

**Dataset growth:** failures found in production (via consented, privacy-reviewed, anonymized review or user feedback) are converted into new synthetic regression cases; adversarial/red-team corpora are maintained and expanded.

**Not over-specified:** tooling, scoring libraries, and judge models are the implementation agent's choice, provided the coverage, determinism-first, versioning, and gating properties hold.

---

## 32. Implementation Guidance

This section sets **sequencing principles and invariants**, not coding steps.

### 32.1 Staged implementation (phases)

The architecture is designed for the **complete vision first**; implementation is **staged** and MUST NOT be attempted in one uncontrolled pass. Each phase has an objective, outcome-level deliverables, and exit criteria; later phases do not start their *feature* work until earlier exit criteria hold (preparation and spikes MAY overlap). The implementation agent decides slicing within a phase.

| Phase | Objective | Outcome-level deliverables | Exit criteria |
|---|---|---|---|
| **0 — Architecture & specification** | Settle product and architecture | This blueprint; resolved/triaged open questions (§33); threat model; seed evaluation catalog; ADRs current | Blueprint accepted; blocking open questions answered or defaulted explicitly |
| **1 — Foundation, identity, profile, core health data** | Build what cannot be retrofitted | Identity/sessions/consent; ownership enforcement (app + DB); audit; privacy export/delete contracts (skeleton); contract/validation mechanism; observability skeleton; localization skeleton (ar/en, RTL); **Unit Registry, Measurement Type catalog, append-only Observations with provenance, supersession/void**; profile (versioned calc attributes) | Cross-user isolation tests green; provenance mandatory at the data layer; unit round-trip tests green |
| **2 — Measurements, goals, calculations, snapshot, dashboard** | A valuable product *without AI* | Manual measurement UX; goals (versioned); deterministic calculation engine with guardrails; time-series rollups/trends; **Health Snapshot with invalidation and reconciliation**; dashboard widgets; Arabic/English completeness for these surfaces | Calculation and snapshot-consistency gates pass; app is coherent and useful with AI disabled |
| **3 — AI context & provider infrastructure** | Build the safe AI platform before any assistant behavior | AI gateway (≥2 text adapters, vision/embedding slots), model registry, **task/model routing**, secret custody and BYOK-readiness; **tool registry** and capability catalog; **AI Context Engine** (tiers, manifests); **AI Data Budget** profiles (baselined here); **AI Trace Records**; **evaluation harness v1 with golden-dataset skeleton**; digests decision gate | Tool-authorization and budget-enforcement tests green; traces content-free; eval harness runs in CI |
| **4 — AI assistant & controlled actions** | Grounded, safe, personalized assistant | Conversations, memory, streaming, evidence labeling, safety classification (§10.6.1), propose→confirm→commit with receipts, anti-hallucination mechanisms (§10.8), assistant UX | AI safety, grounding, and action gates pass on the golden datasets; no write path without confirmation |
| **5 — Image & multimodal intelligence** | Photo → reviewed structured data | Media pipeline (scan, re-encode, private storage), classification, extraction, validation, adaptive-intensity review, commit with provenance, source-retention controls | Extraction accuracy/calibration gate (ar/en) passes; no AI extraction persists without confirmation |
| **6 — Security, performance, AI evaluation hardening** | Prove it | Full red-team and injection suites; penetration test and remediation; performance/cost budgets on reference devices; expanded eval matrix per provider/model/language; user-facing BYOK (gated); privacy export/delete end-to-end verification | All §31.1 gates pass; high-severity findings closed |
| **7 — Production hardening** | Operate it | Resilience and restore drills; runbooks and alerts; SLOs from baselines; legal/privacy review complete; launch readiness; incident procedures | Resilience, observability, and privacy gates pass; launch review signed off |
| **Future** | Expand through seams | Nutrition, workouts, integrations (§28.1), progress photos (§28.2), sleep/recovery/hydration, advanced vision, local models, coach sharing | Each registers via ADR-016 seams and ships its privacy contracts |

**Continuous (every phase, not deferred):** security review of new surface, evaluation coverage for new AI behavior, localization parity, privacy contracts for every new module, ADR upkeep, dependency hygiene.

**Sequencing principles (retained from v1.0 and refined)**
1. **Foundations first** — identity, ownership enforcement (app + DB), audit, provenance, units, observability skeleton, contract/validation mechanism cannot be retrofitted.
2. **Core data usable without AI** — the product must be valuable and coherent before the assistant exists.
3. **AI platform before assistant behavior** — gateway, tools, Context Engine, budgets, traces, and the evaluation harness precede extensive prompt tuning.
4. **Evaluation from the start of AI work** (v1.1) — the harness begins in Phase 3; it is hardened, not introduced, in Phase 6.
5. **Multimodal on established provenance** — extraction builds on the finished measurement, unit, and provenance domains.
6. **Experience and hardening throughout, with a dedicated final pass.**

**v1.0 → v1.1 mapping:** v1.0's five milestones map to Phases 1–2 (foundations, core data), 3–4 (AI platform), 5 (multimodal), and 2/6/7 (experience and hardening); the change replaces five loosely-bounded milestones with eight phases that have exit criteria.

**Invariants the implementation MUST preserve**
- The assistant has no capability that a tool in the registry doesn't grant.
- No AI-originated value enters the health record without user approval and provenance.
- Facts are never overwritten; corrections supersede.
- Calculations are never delegated to the LLM; safety rules live outside prompts.
- Every module implements export and deletion contracts.
- Identity context flows through every request, job, tool call, and retrieval.
- Health content never appears in logs or analytics by default.
- Localization codes-not-labels, logical layout, and units independence hold everywhere.
- Domain modules never import provider SDKs.
- AI context is assembled by the Context Engine under an enforced AI Data Budget; no module feeds the model outside that path.
- Every quantity is normalized to its canonical unit at the boundary with the original preserved.
- Derived data never overwrites source data; upstream changes invalidate downstream derived data.
- Every important AI operation produces a content-free trace.
- Estimates are never presented, stored, or phrased as measurements.

**Freedoms (the implementation agent decides):** frameworks, ORM/query layer, state management, folder layout, package choices, exact schema design, exact RAG/vector implementation, tool-calling mechanism, IaC tooling, CI/CD tooling, chart library, and design-system implementation — provided the invariants and contracts above are met.

**Documentation duties:** keep ADRs updated when decisions change; maintain a living API/tool contract reference, an AI evaluation catalog, a threat model, and runbooks. Any deviation from this blueprint requires a recorded ADR amendment.

**Handling ambiguity:** when this blueprint is silent, choose the simplest option that preserves the invariants, record the decision, and flag it for review.

---

## 33. Open Questions

These require product/legal/business input; the architecture accommodates each answer but they should be resolved before or early in implementation.

1. **Regulatory and residency:** Target launch markets and applicable data-protection regimes; required data residency region; need for DPIA and local representative.
2. **Medical positioning:** Is the product strictly "wellness/fitness information," or will any clinical positioning be sought (which would change risk class, claims, and architecture)?
3. **System-provided AI provider(s):** Which provider(s) ship as defaults, under what data-processing terms (zero-retention, no-training), and what are the user-facing usage limits/pricing tiers?
4. **Monetization & quotas:** Free vs. paid tiers, AI usage quotas, BYOK positioning as an unlocker or as a power-user feature.
5. **Food database strategy** (future): licensed vs. open vs. user-generated; regional (Middle East/North Africa) food coverage.
6. **Age policy:** Confirm adults-only (18+) vs. region-specific minimum ages with guardian consent.
7. **Source-image retention default:** Delete-after-commit (privacy-preferred, recommended) vs. keep-by-default.
8. **Social/OIDC providers and platform requirements** (e.g., Apple sign-in obligations) and MFA stance at launch.
9. **Calendar/numeral defaults** for Arabic locales (Gregorian vs. Hijri options; numeral default per region).
10. **Support model:** Will there be support tooling that touches user data? If so, the consent-based, audited access design needs its own ADR.
11. **Offline write scope:** Which writes may be queued offline in the initial release (measurements only, or also goals/notes)?
12. **Smart-scale/wearable priority** and the first integration targets (affects the ingestion design validation).
13. **Branding/tone guidelines** for the assistant persona (name, voice, strictness around health topics).
14. **Curated knowledge base ownership:** Who authors and reviews the fitness/nutrition guidance corpus, and in what languages?
15. **BYOK timing:** Ship user-facing BYOK at launch, post-launch, or not at all? (Gateway BYOK-readiness is built regardless; ADR-018 amendment.)
16. **Guardrail thresholds and clinical review:** Who approves calorie floors, maximum weekly rates, special-population rules, and disordered-eating response wording? (Needs qualified review before launch.)
17. **Progress-photo encryption level** (when built): storage-level only vs. application-level/per-user keys (ADR-014 extension).
18. **Source-precedence defaults** across device/imported/manual/estimate data per metric, and which are user-configurable (§28.1).
19. **AI trace retention window** and the consent model for any opt-in content capture used for debugging or evaluation-set growth.
20. **Emergency-guidance localization:** region-appropriate emergency and professional-help resources for the Concern-signal response mode (§10.6.1).
21. **Evaluation ownership:** who owns golden datasets, human calibration of model-graded checks, and release thresholds?
22. **Digest introduction:** decision gate in Phase 3 — are snapshot + aggregates sufficient for long-horizon questions?

### 33.1 Decisions deliberately deferred to implementation investigation

These are *how* questions; the blueprint constrains outcomes, the implementation agent investigates and records an ADR:

- Snapshot storage and refresh mechanism (event-driven vs. lazy vs. hybrid) meeting the §7.8 guarantees.
- Database-level isolation mechanism (row-level policies or equivalent) and its interaction with background jobs and AI tools.
- Numeric representation preserving round-trip fidelity (§7.5, rule 4).
- Context Engine planner mechanism (rules, cached plans, small-model assist) and measured minimization results.
- Vector storage need/threshold and embedding model choice per language.
- Job queue implementation behind the broker-agnostic abstraction; rate-limit coordination approach.
- Evaluation tooling and calibration method for model-graded checks.
- Dense-series storage tier design (only when a sensor integration is scheduled).

---

## 34. Final Architectural Principles

1. **The user's data is the product; AI is an interface to it.** Truth lives in the record and the calculation engine.
2. **Nothing is overwritten.** History is a feature; corrections supersede.
3. **Every value has an origin.** Provenance and confidence are never optional.
4. **The AI proposes; the user and the system decide.** Success is what a receipt says, not what the model says.
5. **The AI sees only what it needs.** Minimal, labeled, budgeted context via approved capabilities.
6. **Authorization never depends on the model behaving.** Identity is injected; isolation is enforced twice.
7. **Determinism where it matters.** Math, safety limits, and business rules are code, not prompts.
8. **Honesty over fluency.** "I don't have enough information" beats confident fabrication.
9. **Provider-independent by design.** Models are replaceable; the product is not.
10. **Seams, not scaffolding.** Prepare for nutrition and workouts through contracts, not premature implementation.
11. **Simplicity is a security and cost feature.** Add infrastructure and complexity only on measured need.
12. **Privacy is a capability.** Export, deletion, consent, and minimization are built in, not bolted on.
13. **Localize the architecture, not just the strings.**
14. **Design for years of maintenance.** Boundaries enforced, decisions recorded, quality gated.
15. **Smallest sufficient context.** The Context Engine decides what is needed; snapshot first, retrieval only when warranted, always within a budget.
16. **Lineage over overwrite.** Derived data points to its sources and is invalidated, never silently trusted, when sources change.
17. **Canonical inside, native at the edges.** Units are normalized for computation and preserved for fidelity.
18. **Evaluate AI like software.** Every change to a prompt, model, route, budget, or tool is regression-tested against golden datasets.
19. **Estimates are labeled, always.** Measured, calculated, estimated, and interpreted values never blur.
20. **Build in stages.** Design the whole vision; implement it phase by phase with exit criteria.

---

## Appendix A — Revision 1.1 change log

### A.1 Requirement coverage review (22 review items)

| # | Review item | v1.0 status | v1.1 action |
|---|---|---|---|
| 1 | AI Context Engine | Partial (context assembler, RAG-centric) | Added Context Engine + tier ladder (§11.1); renamed §11; ADR-019; ADR-006 amended |
| 2 | Health/Fitness Snapshot | Missing (only a "user card") | Added §7.8, snapshot entity, consistency/update strategy, consumer wiring |
| 3 | AI Data Budget | Partial (token budget, tool limits scattered) | Added §11.9 as first-class concept; ADR-020 |
| 4 | Provenance & confidence | Mostly covered | Added epistemic class (§14.2), estimate rule, de-duplicated confidence placement |
| 5 | Canonical units | Partial | Added §7.5, Unit Registry, original preservation, ADR-021 |
| 6 | Image/document extraction | Mostly covered | Added §13.4 (input types, trust tiers, adaptive review intensity) |
| 7 | Deterministic vs. AI | Covered | Strengthened with persisted-derived-value lineage/versioning (§15.3) |
| 8 | Model/task routing | Partial | Added §10.9, ADR-023 |
| 9 | Provider abstraction | Mostly covered | Added explicit "no secret reaches client / no leakage into domain" rules (§20.5); BYOK reframed |
| 10 | AI evaluation | Partial (gates only) | Added §31.2 strategy, golden datasets, run triggers; harness moved to Phase 3 |
| 11 | AI traceability | Missing | Added §12.8, AI Trace Record, ADR-022 |
| 12 | Integration readiness | Light | Added §28.1 (ingestion path, record shapes, precedence, consent) |
| 13 | Progress photos | Missing | Added §28.2 and Tier-3 sensitivity class |
| 14 | Privacy lifecycle | Mostly covered | Added §21.1–21.4 (ownership, tiers, provider sharing, lifecycle table, backups) |
| 15 | AI safety boundaries | Partial | Added §10.6.1 categories and response modes |
| 16 | Future gym/workout | Covered | Preserved unchanged (§17); strengthened by Events record shape and registration seams |
| 17 | Data lineage | Missing as explicit concept | Added §7.6 and ADR-024 |
| 18 | Time-series thinking | Partial | Added §7.7 |
| 19 | Phased implementation | Partial (5 milestones) | Replaced with 8 phases + exit criteria (§32.1) |
| 20 | Contradiction review | — | See A.2 |
| 21 | Implementation-agnostic | Largely | Preserved; mechanisms left to implementer (§33.1) |
| 22 | Preserve vision | — | All original scope, domains, ADRs 001–018, risks R1–R20, and gates 1–13 preserved |

### A.2 Contradictions, ambiguities, and over-engineering resolved

1. **RAG framed as the universal architecture** vs. "smallest sufficient context" → RAG demoted to an instrument of the Context Engine; ADR-006 amended, not removed.
2. **"User card" vs. Snapshot** (duplicate concept) → the user card is now content of the Snapshot's identity-lite section.
3. **Confidence duplicated** on Observation and Provenance → lives in provenance only.
4. **"Append-only" vs. user "delete"** (ambiguous) → delete = *void*; physical erasure only via privacy flows (§7.1).
5. **Safe write "user-dictated measurement"** vs. sensitivity of outliers → plausibility-failing writes escalate to Sensitive write (§12.4).
6. **Mandatory extraction review** vs. the request for review "when necessary" → confirmation remains mandatory for AI extraction; *intensity* adapts (§13.4). No weakening of safety.
7. **User-facing BYOK at launch** (over-engineering vs. "eventually") → gateway BYOK-readiness at launch, user-facing BYOK gated to Phase 6 (ADR-018 amended; open question Q15).
8. **Digests in the initial release** (possibly premature once a Snapshot exists) → deferred behind a Phase-3 decision gate (§11.5, Q22).
9. **"At least two providers across three capability slots"** (ambiguous/over-broad) → at least two text adapters, one each for vision and embeddings (§27.1).
10. **Usage ledger vs. trace** (overlapping concepts) → ledger is a projection of traces.
11. **AI evaluation placed only as a late gate** → harness starts in Phase 3 so AI behavior is never built unevaluated.
12. **Missing consolidated failure handling and validation layers** → §8.1 and §22.1.
13. **Implicit ownership** → explicit single-owner rule (§8, rule 7) and data-ownership statement (§21.1).

### A.3 Intentionally unchanged
Product vision, personas, journeys J1–J8/J10–J11, domain model core, module list and dependency rules, security architecture (§20) apart from the §20.5 additions, provenance rules, calculation architecture, nutrition and workout future-domain sections (§16–17), localization (§19), technology selections (§24, apart from added rows), ADR-001–005/007–017, risks R1–R20, release gates 1–13, and all NFRs. No requirement was removed; where behavior changed (items 4–9 above) the reasoning is recorded.

---

*End of blueprint. Deviations require a recorded ADR amendment.*
