# Phase 3 Execution Plan — AI Context & Provider Infrastructure

**Phase Objective:** Build the safe, grounded, budget-enforced AI platform *before* any assistant conversational behavior or prompt tuning is introduced, strictly fulfilling Blueprint §10, §11, §12, §27.1, and §32.

---

## 1. Scope & Architectural Invariants (Blueprint §32)

1. **AI Platform Before Assistant Behavior:** The gateway, model registry, tool execution engine, Context Engine, budgets, traces, and evaluation harness precede extensive prompt engineering.
2. **Domain Isolation:** Core domain modules (`calculations`, `measurements`, `goals`, `analytics`, `profile`, `identity`) MUST NOT import AI provider SDKs.
3. **Identity Injection at Server Boundary:** The authenticated user context is bound server-side to every tool invocation. Tool schemas MUST NOT accept a user ID parameter.
4. **No Raw Query Access:** No tool accepts arbitrary SQL or unrestricted DB filters. Tool outputs are bounded, sanitized, and wrapped as untrusted data.
5. **Multi-Provider Text Gateway:** The gateway supports at least two independent text adapters (Google Gemini live + Secondary/Local adapter) to prove vendor neutrality.
6. **Tiered Context Planning & Minimization:** Requests are planned at the lowest sufficient tier (0–4) starting from the Health Snapshot; models never have direct DB access.
7. **Sufficiency Gating:** Missing critical inputs produce a clarification or "unknown" response before spending tokens.
8. **AI Data Budget:** Enforced externally per operation; degradation ladder on exhaustion.
9. **Content-Free Traceability:** Every AI operation emits a trace recording provider, model, context manifest (identifiers/versions, not values), tools, and safety outcomes without storing raw prompts or health payloads by default.
10. **Evaluation Harness v1:** Automated evaluation with golden datasets gates release in CI.

---

## 2. Milestone Breakdown & Deliverables

### Milestone 1: AI Gateway, Provider Adapters & Model Registry
- [ ] Create `backend/src/modules/ai/gateway/`
  - `types.ts`: Provider interfaces, capability flags, model definitions, generation parameters, response shapes.
  - `registry.ts`: Model registry listing supported models, task classes, token cost, context limits, and eval status.
  - `adapters/gemini.ts`: Live Google Gemini adapter (uses discovered `gemini-3.8-flash` via real API key in `.env`).
  - `adapters/mock_secondary.ts`: High-fidelity secondary provider adapter to prove multi-provider abstraction without external billing/lock-in.
  - `router.ts`: Task/model routing (deterministic first, capability negotiation, fallback chain).
  - `byok.ts`: Encrypted secret custody framework and per-request credential resolver.
- [ ] Record ADR-0003: AI Gateway Multi-Provider Architecture, Tool Execution Engine, and Tiered Context Planner.

### Milestone 2: Tool Registry & Secure Execution Engine
- [ ] Create `backend/src/modules/ai/tools/`
  - `types.ts`: Tool definition interface, permission classes (`read-only`, `safe-write`, `sensitive-write`, `destructive`), rate limits, cost classes.
  - `registry.ts`: Catalog of registered capabilities.
  - Core Tool Implementations:
    - `get_health_snapshot`: Retrieves full or section-specific snapshot.
    - `query_observations`: Parameterized time-series observation lookup with bounded pagination.
    - `get_calculated_metrics`: Deterministic calculation engine invocation (BMI, BMR, TDEE, Calorie targets with clinical floors).
    - `get_goals_progress`: Retrieves user's active goals and dynamic progress.
    - `get_trends`: Retrieves noise-robust trends with sufficiency flags.
  - `executor.ts`: Secure server-side tool executor:
    - Injects authenticated `userId`.
    - Enforces least privilege per intent class.
    - Validates inputs against Zod schema and clamps ranges.
    - Wraps outputs as bounded, untrusted data.
    - Emits audit and trace events.

### Milestone 3: AI Context Engine & Tiered Planning
- [ ] Create `backend/src/modules/ai/context/`
  - `tiers.ts`: Definition of Context Tiers (0: none, 1: snapshot, 2: structured, 3: semantic, 4: deep analysis).
  - `planner.ts`: Deterministic intent-to-tier planner with information-needs analyzer.
  - `sufficiency.ts`: Sufficiency checker validating required data existence before spending LLM tokens.
  - `manifest.ts`: Context Manifest generator (identifiers, versions, timestamps, watermarks; zero secrets/health data in manifest).
  - `engine.ts`: AI Context Engine assembling the minimal, provenance-labeled context bundle under budget.

### Milestone 4: AI Data Budget & External Enforcement
- [ ] Create `backend/src/modules/ai/budget/`
  - `types.ts`: Budget dimensions (records, depth, context tokens, tool calls, time, cost).
  - `profiles.ts`: Configurable budget profiles (e.g. `minimal`, `standard`, `deep_analysis`).
  - `enforcer.ts`: Per-turn runtime counters tracking consumption and triggering graceful degradation on exhaustion.

### Milestone 5: Database Migration 006 & AI Traceability
- [ ] Create `backend/src/core/database/migrations/006_ai_traces_schema.sql`
  - `ai_traces` table: `id`, `user_id`, `provider`, `model_id`, `task_class`, `intent_class`, `context_manifest` (JSONB), `tools_invoked` (JSONB), `safety_category`, `budget_consumed` (JSONB), `created_at`.
  - Full PostgreSQL RLS and `forma_app` non-superuser grants.
- [ ] Create `backend/src/modules/ai/traces/`
  - `emitter.ts`: Content-free trace writer.
  - `service.ts`: Trace repository and query service.
  - Privacy export and purge contracts for AI traces.

### Milestone 6: Evaluation Harness v1 & Golden Datasets
- [ ] Create `backend/src/eval/golden/`
  - Versioned golden datasets with synthetic user personas:
    - Normal progress queries.
    - Missing data scenarios (asserts correct abstention / "unknown").
    - Stale snapshot scenarios (asserts temporal caveats).
    - Direct/indirect prompt injection scenarios (asserts defense).
    - Medical/disordered-eating red flags (asserts Category D redirect / refusal).
- [ ] Create `backend/src/eval/ai_harness.test.ts`
  - Deterministic assertions: numeric fidelity (numbers match tool results), tool-call authorization, context minimization, content-free traces, budget enforcement.

### Milestone 7: Digests Decision Gate
- [ ] Evaluate long-horizon requirements against snapshot + rollups.
- [ ] Record decision in `docs/adr/0004-periodic-digests-decision-gate.md`.

---

## 3. Exit Criteria for Phase 3

1. **Tool Authorization Gate:** Automated cross-user tests prove LLM tool executor cannot access unauthorized user data.
2. **Budget Enforcement Gate:** Tests prove operations halt or degrade when budget limits are exceeded.
3. **Traceability Gate:** Tests prove all AI operations emit traces containing zero prompts, completions, or health values by default.
4. **Grounding & Abstention Gate:** Eval harness proves correct abstention on missing data and numeric fidelity on calculations.
5. **Architecture Invariant:** Zero AI SDK imports in domain packages (`calculations`, `measurements`, `goals`, `analytics`, `profile`, `identity`).
6. **All Test Suites Green:** Vitest suite, architecture tests, TypeScript clean, secret scan clean.
