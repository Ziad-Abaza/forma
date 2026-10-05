# Phase 4 Execution Plan — AI Assistant & Controlled Actions

**Phase Objective:** Build the grounded, safe, personalized conversational assistant with multi-turn memory, streaming responses, evidence labeling, the Propose → Confirm → Commit protocol with Action Receipts, and bilingual mobile UX, strictly adhering to Blueprint §10, §11, §12, §24, §27.1, and §32.

---

## 1. Architectural Invariants & Exit Rules (Blueprint §32)

1. **No Write Path Without Confirmation (Propose → Confirm → Commit):** The model cannot execute writes directly. It emits an **Action Proposal**. The system validates it, generates a diff preview, and assigns an idempotency key and expiry. The **user** confirms via a dedicated UI/API action. The system executes the write and emits an **Action Receipt**.
2. **Action Claims Bound to Receipts:** The assistant MUST NOT assert a write succeeded unless bound to a verified Action Receipt.
3. **Anti-Hallucination & Evidence Labeling:** Every substantive claim carries an evidence type: `retrieved`, `calculated`, `estimated`, `inferred`, `recommended`, or `unknown`. Numeric claims about the user must originate from a tool result.
4. **Safety Category D Guard:** Acute symptoms and disordered eating trigger the Redirect mode, declining targets and signposting professional medical evaluation.
5. **Double Isolation & PostgreSQL RLS:** Conversations, messages, action proposals, and memories are protected with PostgreSQL Row-Level Security for the non-superuser role `forma_app`.
6. **Privacy Parity:** Full GDPR/CCPA export and cascading purge across conversations, proposals, receipts, and memories.
7. **Bilingual Parity:** Arabic RTL and English LTR message catalogs and directional layouts.

---

## 2. Milestone Breakdown & Deliverables

### Milestone 1: Database Migration 007 (`007_assistant_schema.sql`)
- Tables: `conversations`, `conversation_messages`, `action_proposals`, `assistant_memories`.
- Full PostgreSQL RLS (`ENABLE` and `FORCE ROW LEVEL SECURITY`) with `forma_app` role permissions.
- Invariant tests updated in `architecture.test.ts` (19 RLS tables total).

### Milestone 2: Propose → Confirm → Commit Engine & Memories
- `action_proposals`: Creation, validation, preview generation, expiration, user confirmation, domain execution, receipt emission.
- `assistant_memories`: Durable facts/preferences, user editable/deletable, provenance tagged.
- Domain executions supported:
  - `log_measurement`: Commits to `MeasurementsService.recordObservation` with provenance `assistant_proposal`.
  - `update_goal`: Commits to `GoalsService.addGoalVersion`.
  - `save_memory`: Commits to `assistant_memories`.

### Milestone 3: Conversational Orchestrator & Evidence Claim Verification
- Multi-turn conversation management with rolling summaries and context budgeting.
- Grounding via `AIContextEngine` (injects compact Health Snapshot).
- Tool execution via `ToolExecutor` (server-injected identity).
- Evidence tagger: tags claims with evidence types and verifies numbers match tool outputs.
- Streaming responses with Server-Sent Events (SSE).

### Milestone 4: Fastify API Routes & Privacy Orchestrator
- `POST /api/v1/assistant/chat` (streaming SSE endpoint).
- `GET /api/v1/assistant/conversations` & `GET /api/v1/assistant/conversations/:id`.
- `POST /api/v1/assistant/proposals/:id/confirm` & `decline`.
- `GET /api/v1/assistant/memories` & `DELETE /api/v1/assistant/memories/:id`.
- `AssistantPrivacyContract` registered in `PrivacyOrchestrator`.

### Milestone 5: Mobile Assistant UI & Bilingual ARB Catalogs
- Assistant screen with Riverpod-driven chat state and streaming token display.
- Action Proposal widget card with visual diff preview and "Confirm" / "Decline" buttons.
- Evidence badges rendered on assistant messages.
- Full ARB key parity in `app_en.arb` and `app_ar.arb`.

### Milestone 6: Verification & Gate Checks
- Complete Vitest test suite (`src/eval/assistant.test.ts`).
- Cross-user isolation tests on conversations and proposals.
- Architecture invariant tests (0 AI imports in domain, RLS verified).
- Secret scanning clean.
- Flutter static analysis (`dart analyze`) & widget tests (`flutter test`).

---

## 3. Exit Criteria for Phase 4

1. **Controlled Actions Gate:** Zero writes possible without explicit user confirmation API call. Unconfirmed proposals expire without mutating domain data.
2. **Action Claims Gate:** Assistant statements about saved data require an Action Receipt.
3. **Anti-Hallucination Gate:** Numeric claims match tool outputs; evidence badges displayed.
4. **Safety Gate:** Category D queries trigger immediate redirect.
5. **Isolation & Privacy Gate:** Cross-user isolation verified; privacy export and purge tested.
6. **All Test Suites Green:** 100% pass across backend and mobile tests.
