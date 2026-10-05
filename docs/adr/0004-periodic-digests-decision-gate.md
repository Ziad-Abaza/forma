# ADR-0004: Phase 3 Decision Gate — Periodic Digests Deferral

## Status
Accepted

## Context
Blueprint §11.5, §27.1, and §33 Question 22 establish an explicit Phase 3 decision gate regarding Periodic Digests:
*"Over-engineering guard (v1.1): the Snapshot plus aggregates/rollups are the primary compact representations. Digests are an optimization introduced only when evaluation or cost data shows long-horizon requests are inadequately served by snapshot + aggregates."*

In Phase 2, we implemented:
1. `metric_rollups` (daily, weekly, monthly aggregations with mean, min, max, std_dev, and sample count).
2. `health_snapshots` with 8 canonical sections and watermark invalidation.
3. 7-day EMA noise-robust trend smoothing with rate-of-change and sufficiency checks.

## Decision
We evaluate the current representation against typical user query patterns and confirm:
1. **Current State & Recent Progress:** Handled completely by the Health Snapshot (Tier 1 context).
2. **Medium-Horizon (30–90 days) Comparisons & Trends:** Handled deterministically by `metric_rollups` and `computeWeightTrend` (Tier 2 context).
3. **Periodic AI Narrative Digests:** Generating recurring background LLM summaries at this stage would add substantial token costs and database churn without distinct grounded value over our deterministic snapshot and rollups.

**Decision:** Defer automated AI narrative periodic digests. The compact Health Snapshot and metric rollups satisfy all Phase 3 and Phase 4 information needs.

## Consequences
- Prevents unnecessary LLM token expenditure and background worker complexity.
- Keeps long-horizon queries grounded in pure PostgreSQL aggregations.
- Re-evaluation scheduled for Phase 6 during evaluation and cost baseline hardening.
