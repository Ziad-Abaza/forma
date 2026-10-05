# ADR-0003: AI Gateway Multi-Provider Architecture, Tool Execution Engine, and Tiered Context Planner

## Status
Accepted

## Context
Forma requires an AI layer that is safe, grounded, reproducible, and vendor-neutral per Blueprint §10, §11, §12, §27.1, §32, and ADR-005, ADR-018, ADR-019, ADR-020, ADR-022, ADR-023.

Key requirements:
1. **Multi-Provider Text Gateway:** Support at least two independent text adapters (Google Gemini live + Secondary fallback adapter) to prove vendor neutrality.
2. **Capability-Based Server-Mediated Tool Registry:** Tools must have strict schemas, permission classes (`read-only`, `safe-write`, `sensitive-write`, `destructive`), rate limits, and cost classes. User identity must be injected by the server; tools never take `user_id` as a model parameter.
3. **AI Context Engine with Tiered Context (0–4):** Context must be assembled per request starting from the derived Health Snapshot, never exposing raw database queries to the model.
4. **Enforced AI Data Budget:** Budgets must be governed outside the model with runtime counters and graceful degradation ladders.
5. **Content-Free AI Traceability:** Operations must record provider, model, context manifest (identifiers/versions, not values), tool usage, evidence types, safety categories, and budget consumption without persisting user prompts or health data by default.

## Decision
1. Implement `AIGateway` in `backend/src/modules/ai/gateway/` supporting multiple registered provider adapters conforming to `AIProviderAdapter`.
   - Primary: `GeminiAdapter` integrating with Google Generative AI via discovered `gemini-3.8-flash`.
   - Secondary: `SecondaryProviderAdapter` providing a fully compliant fallback text adapter to satisfy the multi-provider text invariant without vendor lock-in.
2. Implement `ToolRegistry` and `ToolExecutor` in `backend/src/modules/ai/tools/`:
   - Every tool declares strict Zod schemas for input and output, a permission class, and a handler function.
   - The executor binds the authenticated session's `userId` server-side, validates inputs, executes the handler, wraps outputs as untrusted data, and logs the execution.
3. Implement `AIContextEngine` in `backend/src/modules/ai/context/`:
   - Categorizes requests into Tiers 0–4.
   - Generates a `ContextManifest` containing only metadata, versions, and watermarks.
   - Performs sufficiency gating before model execution to avoid hallucinated guesses.
4. Implement `AIBudgetEnforcer` in `backend/src/modules/ai/budget/`:
   - Tracks tokens, records, tool calls, and latency against configured budget profiles.
5. Implement `AITraceEmitter` in `backend/src/modules/ai/traces/`:
   - Stores traces in PostgreSQL table `ai_traces` protected by Row-Level Security, integrated into the user privacy export and purge pipeline.

## Consequences
- **Positive:** Full isolation of AI vendor dependencies from domain logic; mathematical guarantees against unauthorized data access via identity injection; strict cost control; complete auditable reproducibility without privacy risks.
- **Trade-off:** Adding server-mediated tool wrapping and context tiering requires explicit schema definitions for every capability, but eliminates hallucination and prompt injection risks.
