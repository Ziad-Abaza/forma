# Phase 2 Execution Plan — Measurements, Goals, Calculations, Snapshot & Dashboard

> **Objective:** Deliver a complete, valuable, production-ready product *without AI* (Blueprint §32.1).
> All core calculations, goals, noise-robust trend analytics, the Health Snapshot with lineage invalidation, and the Flutter dashboard must be fully functional, deterministic, bilingual, and tested against real PostgreSQL 18.6.

---

## 1. Scope & Modules

### 1.1 Backend Modules
1. **`goals` Module (`src/modules/goals/`)**:
   - Schema & Migration: `goals` and `goal_versions` tables with PostgreSQL RLS.
   - Domain Model: Primary goal (`weight_loss`, `muscle_gain`, `maintenance`, `general_fitness`), target metric, target value in canonical units, starting value, start date, target date, weekly target rate, status (`active`, `achieved`, `abandoned`, `superseded`).
   - Temporal versioning: Evaluation against the active goal version for any historical window.
   - Contracts: CRUD, version creation, progress computation against observations, privacy export and delete.
2. **`calculations` Module (`src/modules/calculations/`)**:
   - Pure, deterministic calculation engine with versioned formula IDs.
   - Formulas:
     - **BMI** (WHO adult categories, formula `bmi_v1`).
     - **BMR** (Mifflin-St Jeor `bmr_mifflin_v1`, Katch-McArdle `bmr_katch_mcardle_v1` using lean body mass).
     - **TDEE** (standard PAL activity multipliers `tdee_pal_v1`).
     - **Calorie Targets** (maintenance, safe deficit/surplus ranges with safety guardrails: female floor 1200 kcal, male floor 1500 kcal, max deficit 1000 kcal or 25%).
     - **Macronutrient Ranges** (protein per kg body mass, fat 20-35% of energy, remainder carbohydrates).
     - **Goal Timeline & Projection** (linear & smoothed projections, expected rate of change with max safe loss limit 1.0 kg/week or 1% body weight/week).
   - Data Sufficiency: `complete`, `partial`, `insufficient` with explicit missing inputs enumeration.
   - Safety Guardrails: Special-population flags (pregnancy, medical flags, extreme age) trigger target refusal and referral to professional care.
   - Contract: Tool-ready evaluation endpoints and internal APIs.
3. **`analytics` Module (`src/modules/analytics/`)**:
   - Time-series rollups: Daily, weekly, monthly aggregates with declared semantics (mean, sum, last).
   - Noise-robust trend engine: Rolling 7-day average, exponential moving average, trend slope, rate-of-change.
   - Sufficiency gating: Refuses slope calculation if observations span less than required window (e.g. minimum 3 points over 7 days).
   - Anomaly detection: Flags implausible jumps (>3 kg in 24h, unit mismatch outliers) for review without deletion.
   - **Health Snapshot Engine (`src/modules/analytics/snapshot.ts`)**:
     - Compact materialized view of current state across 8 initial sections (`identity_lite`, `body_status`, `goal`, `energy`, `activity_level`, `recent_measurements`, `anomalies`, `data_quality`).
     - Lineage watermarking (`source_data_version`).
     - Invalidation mechanics: writes to observations, goals, or profile invalidate only dependent sections.
     - Scheduled / on-demand reconciliation: proves zero drift between snapshot and source recalculation.
4. **`dashboard` API & Composition Contract**:
   - Ranked widget endpoints: Status & Goal, Recent Measurements, Trends, Targets, Important Changes/Anomalies, Prompts/Reminders.
   - Offline-tolerant, precomputed snapshot payload.
5. **Database Migration (`005_phase2_schema.sql`)**:
   - Tables: `goals`, `goal_versions`, `health_snapshots`, `metric_rollups`, `anomaly_flags`.
   - Complete PostgreSQL RLS double-isolation and `forma_app` role grants.

### 1.2 Mobile Client (Flutter)
1. **Presentation & Widgets**:
   - Goal progress card (baseline, current, target, projected timeline).
   - Recent measurements list with epistemic badges and deltas.
   - Trends widget with period selector (7D, 30D, 90D, 1Y) and smoothed vs raw display.
   - Target calories & macros widget with explicit assumptions and safety notes.
   - Honest empty states and data-sufficiency indicators.
2. **Localization (Arabic + English)**:
   - Full ARB catalog extensions for all goal types, calculation labels, anomaly explanations, and trend summaries.
   - Directionality (RTL/LTR) dynamic parity.

---

## 2. Applicable Quality Gates (from Blueprint §31.1)

1. **Gate 2: Calculation Engine (Gate 5 in §31.1)**:
   - Reference-value tests matching clinical/scientific tables.
   - Property-based testing (monotonicity, boundaries, invariance).
   - Hard safety guardrails (calorie floors, maximum weekly rates).
2. **Gate 3: Snapshot Consistency & Lineage (Gate 15 in §31.1)**:
   - Zero drift between snapshot and pure recomputation from source facts.
   - Downstream invalidation when source data is superseded, voided, or added.
3. **Gate 6: Cross-User Isolation**:
   - Cross-user tests on goals, calculations, rollups, and snapshots proving RLS double-isolation.
4. **Gate 12: Privacy Export & Purge**:
   - Goals, snapshots, and rollups included in export bundle and cleanly erased on account purge.
5. **Gate 15: Bilingual Parity**:
   - 100% Arabic and English parity across all Phase 2 widgets, calculations, and error messages.

---

## 3. Exit Criteria
- [ ] Backend Vitest suite passes all unit and integration tests (goals, calculations, analytics, snapshot, isolation).
- [ ] Reference-value and property-based calculation tests pass.
- [ ] Health snapshot recomputation and invalidation tests pass with zero drift.
- [ ] Architecture tests pass with zero AI dependencies in domain modules.
- [ ] TypeScript strict typecheck clean (0 errors).
- [ ] Automated secret scan clean (0 violations).
- [ ] Flutter `dart analyze` and `flutter test` clean with Arabic/English parity verified.
- [ ] Phase 2 completion report (`docs/phases/phase-2-report.md`) created with actual command outputs.
