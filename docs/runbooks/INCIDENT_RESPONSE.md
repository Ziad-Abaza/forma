# Operational Runbook: Incident Response & Triage

**Version:** 1.0.0  
**Target Platform:** Forma Production Backend & PostgreSQL Database  
**Compliance Reference:** Forma Product Architecture Blueprint §20, §21, §31, §32

---

## 1. Severity Classification Matrix

| Level | Name | Impact Description | SLA (Response / Resolution) |
|---|---|---|---|
| **SEV-1** | Critical Outage | Entire backend or database down; users unable to authenticate or log data. | 15 min / 2 hours |
| **SEV-2** | Major Degradation | AI service totally unresponsive, or snapshot reconciliation failing widely. | 30 min / 4 hours |
| **SEV-3** | Moderate Incident | Non-critical provider failure, isolated wearable sync errors, partial latency spike. | 2 hours / 12 hours |
| **SEV-4** | Minor / Low | Cosmetic UI issue, isolated log anomaly, non-blocking telemetry delay. | 1 business day / Next sprint |

---

## 2. Emergency Health & Status Probes

Execute rapid diagnostic probes to identify system state:

```bash
# 1. Check basic process liveness
curl -I https://api.forma.app/health

# 2. Check process uptime and memory health
curl https://api.forma.app/health/live

# 3. Check database connectivity & migration readiness (returns HTTP 200 or 503)
curl -I https://api.forma.app/health/ready

# 4. Check runtime operational telemetry
curl https://api.forma.app/metrics
```

---

## 3. Incident Scenarios & Standard Operating Procedures (SOP)

### Scenario A: AI Provider Outage / 503 Overload
- **Symptoms:** Users receive polite fallback message in assistant chat; `GET /health` is 200; `ai_traces` shows outcome `degraded`.
- **Root Cause:** Upstream AI provider (e.g., Google Gemini or secondary) experiencing latency spikes, rate limits (HTTP 429), or service outage (HTTP 503).
- **Triage Steps:**
  1. Inspect AI trace outcomes without exposing user content:
     ```sql
     SELECT provider, model_id, outcome, COUNT(*) 
     FROM ai_traces 
     WHERE created_at > NOW() - INTERVAL '15 minutes' 
     GROUP BY provider, model_id, outcome;
     ```
  2. If upstream quota is exhausted, failover to secondary provider or update `AI_PRIMARY_MODEL` environment variable.
  3. Verify graceful degradation is functioning: the backend automatically returns degraded fallback messages while core health logging (measurements, goals, calculations) remains 100% operational.
  4. Communicate status via status page: "AI Companion is currently running in fallback mode; health tracking is unaffected."

---

### Scenario B: Database Connection Pool Exhaustion or High Latency
- **Symptoms:** `/health/ready` returns HTTP 503; API requests log connection timeout (`5000ms`); latency alerts fire.
- **Triage Steps:**
  1. Check active database connections:
     ```sql
     SELECT count(*), state, usename FROM pg_stat_activity GROUP BY state, usename;
     ```
  2. Identify long-running transactions or deadlocked queries:
     ```sql
     SELECT pid, now() - query_start AS duration, query, state 
     FROM pg_stat_activity 
     WHERE state != 'idle' AND now() - query_start > interval '5 seconds';
     ```
  3. Terminate runaway blocking queries:
     ```sql
     SELECT pg_terminate_backend(<pid>);
     ```
  4. If pool exhaustion is sustained, scale backend replica container pool settings or increase `max_connections` on PostgreSQL.

---

### Scenario C: Snapshot Watermark Desync or Inconsistency
- **Symptoms:** User reports snapshot values differ from recent manual measurement observations.
- **Triage Steps:**
  1. Trigger deterministic snapshot reconciliation for the affected user via the authenticated API:
     ```bash
     curl -X GET https://api.forma.app/api/v1/analytics/snapshot/reconcile \
       -H "Authorization: Bearer <user_access_token>"
     ```
  2. The system executes `AnalyticsService.reconcileSnapshot()`, scans active observations, updates `source_data_watermark`, and commits clean precomputed state.
  3. Check the audit log to verify reconciliation event:
     ```sql
     SELECT action, status, metadata, created_at 
     FROM audit_logs 
     WHERE entity_type = 'snapshot_reconciliation' AND user_id = '<user_uuid>' 
     ORDER BY created_at DESC LIMIT 5;
     ```

---

### Scenario D: Suspected Security Event or Token Leak
- **Symptoms:** High volume of 401 unauthorized requests, suspicious IP patterns, or compromised API credentials reported.
- **Triage Steps:**
  1. Immediately rotate `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` in environment/secrets manager to instantly invalidate all active JWTs.
  2. Trigger rolling restart of `forma-backend` containers:
     ```bash
     docker compose -f docker-compose.prod.yml restart backend
     ```
  3. Purge active sessions in the database:
     ```sql
     DELETE FROM sessions WHERE expires_at > NOW();
     ```
  4. If a user BYOK API key was compromised, delete the credential record:
     ```sql
     DELETE FROM user_ai_credentials WHERE user_id = '<user_uuid>' AND provider = 'gemini';
     ```
