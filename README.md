# Forma — Personal AI Health & Fitness Platform

Forma is an uncompromisingly reliable, production-ready personal health and wellness platform built with strict medical safety boundaries, append-only provenance tracking, double-isolated multi-tenant security (application-level + PostgreSQL Row-Level Security), and an integrated AI companion adhering to strict Controlled Actions protocols.

Forma features complete, native bilingual parity in **Arabic (RTL)** and **English (LTR)** across all mobile screens, notification streams, and AI conversation modes.

---

## 1. System Architecture

Forma is architected according to the [Product Architecture Blueprint (v1.1)](docs/PRODUCT_ARCHITECTURE_BLUEPRINT.md) with strict architectural invariants:

- **Backend:** Node.js 22 + TypeScript modular monolith (`/backend`), powered by Fastify for high-throughput HTTP/SSE APIs, with structured JSON logging and automated PII/biometric redaction.
- **Database:** PostgreSQL 16+ enforcing Row-Level Security across all 24 domain tables under limited application credentials (`forma_app`), with append-only observations and audit trails.
- **AI Gateway & Context Engine:** Provider-agnostic gateway (Google Gemini with secondary fallback) featuring token budget management, content-free operational traces, and zero direct database access for LLMs.
- **Controlled Actions Engine:** Propose -> Confirm -> Commit lifecycle ensuring no AI hallucination or suggestion ever writes to user health records without explicit, receipt-backed confirmation.
- **Multimodal Intelligence:** On-device image processing and vision extraction pipeline with adaptive review intensity and draft staging.
- **Wearable & Sync Engine:** HealthKit/Health Connect seams with idempotent deduplication and deterministic epistemic conflict resolution.
- **Mobile Client:** Flutter 3.24+ application (`/mobile`) with Riverpod state management and dynamic locale-driven RTL/LTR presentation.

---

## 2. Quickstart: Zero-to-Running

### Prerequisites
- Node.js >= 20 (v22/v24 recommended)
- PostgreSQL 16+ (Docker or local service)
- Flutter SDK >= 3.24
- Docker & Docker Compose (for containerized deployment)

### Local Development Setup

1. **Configure Environment:**
   ```bash
   cp .env.example .env
   ```

2. **Start Local PostgreSQL Database:**
   ```bash
   docker compose up -d postgres
   ```

3. **Backend Setup & Database Migrations:**
   ```bash
   cd backend
   npm install
   npm run migrate
   npm run dev
   ```
   The backend API will be available at `http://localhost:3000`.

4. **Mobile App Launch:**
   ```bash
   cd mobile
   flutter pub get
   flutter run
   ```

### Local Network Development (Physical Devices on Same Wi-Fi)

To run the backend as a local server accessible by a physical phone on the same Wi-Fi network:

1. **Enable Local Server Mode:**
   In `backend/.env`, set:
   ```env
   LOCAL_SERVER=true
   ```
   Or set the environment variable:
   ```bash
   $env:LOCAL_SERVER="true"   # PowerShell
   export LOCAL_SERVER=true    # Linux / macOS
   ```

2. **Start the Backend:**
   ```bash
   cd backend
   npm run dev
   ```
   - The backend automatically binds to `0.0.0.0` (all interfaces) instead of `127.0.0.1`.
   - The server detects your computer's local IPv4 (e.g. `192.168.x.x`) and automatically synchronizes `mobile/.env`.

3. **Launch Mobile App on Physical Device:**
   ```bash
   cd mobile
   flutter run --dart-define-from-file=.env
   ```
   - `EnvConfig` dynamically routes all requests to `http://<YOUR_LOCAL_IP>:3000`.
   - Android (`usesCleartextTraffic`, internet permissions) and iOS (`NSAllowsLocalNetworking`, `NSLocalNetworkUsageDescription`) are configured to allow local network HTTP traffic.

---

## 3. Production Deployment (Docker Compose)

Forma includes production-grade containerization with a multi-stage Dockerfile running under a non-root system user (`forma:forma`), PID-1 supervision via `dumb-init`, isolated Docker networks, and automatic database healthchecks.

```bash
# 1. Provide production secrets in .env
# 2. Build and start production stack
docker compose -f docker-compose.prod.yml up -d --build

# 3. Verify container health
docker compose -f docker-compose.prod.yml ps
```

### Production Probes & Observability Endpoints
- `GET /health` — Service liveness and version check.
- `GET /health/live` — Process uptime and liveness probe.
- `GET /health/ready` — Database connectivity and migration readiness probe (returns HTTP 200 or HTTP 503).
- `GET /metrics` — Operational runtime telemetry, process memory heap stats, and uptime.

---

## 4. Comprehensive Test Suite & Quality Gates

Run the complete test matrix with 100% pass guarantee:

```bash
# Backend Test Suite (Vitest - 20 test files, 161 tests)
cd backend
npm test

# Architectural Invariants & RLS Policy Tests (24 tables enforced)
npm run test:arch

# Backend TypeScript Typechecking
npm run typecheck

# Mobile Widget & Unit Tests (15 tests passing)
cd ../mobile
flutter test

# Mobile Static Analysis (0 errors, 0 warnings)
dart analyze

# Automated Secret Scanner (Scans all files for leaked credentials)
cd ..
node scripts/secret-scan.js
```

---

## 5. Operational Runbooks

- [Incident Response & Triage Runbook](docs/runbooks/INCIDENT_RESPONSE.md) — Sev-1 to Sev-4 classification, AI provider outage fallback, connection exhaustion, and security event triage.
- [Backup & Disaster Recovery Runbook](docs/runbooks/BACKUP_AND_RESTORE.md) — Continuous WAL archiving, logical `pg_dump` procedures, PITR recovery, and RLS integrity verification.

---

## 6. Blueprint §32 Invariants Checklist

1. [x] **AI has no direct DB access** — AI operates solely through context engine and typed tool calls.
2. [x] **No AI value enters health record without confirmation** — Action proposal engine enforces receipt-backed confirmation.
3. [x] **Facts are never overwritten** — Append-only observations with supersession lineage.
4. [x] **Calculations live in pure code** — Deterministic arithmetic with clinical safety floors.
5. [x] **Every value has provenance & confidence** — Foreign key to `provenance_records`.
6. [x] **Double user isolation** — Application filters + PostgreSQL RLS across all 24 tables.
7. [x] **Canonical unit conversion** — Preserves original value/unit alongside normalized SI standard.
8. [x] **Derived data lineage** — Watermarked snapshots with on-demand deterministic reconciliation.
9. [x] **Bounded AI context** — Context Engine enforces tiered context assembly under token budget.
10. [x] **Content-free AI traces** — Telemetry logs operational metadata without storing raw prompts or biometrics.
11. [x] **Estimates never represented as measurements** — Epistemic class separates measured, calculated, estimated, asserted.
12. [x] **Domain modules never import provider SDKs** — Clean separation via AI Gateway interface.
13. [x] **Health content never appears in logs** — Automated redaction in application logger.
14. [x] **Every module implements export & delete** — Full GDPR portable export and cascading account purge.
15. [x] **Dashboard insights precomputed & cached** — Precomputed health snapshots for fast mobile retrieval.
