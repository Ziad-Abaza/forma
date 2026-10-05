# Forma — Personal AI Health & Fitness Companion

Forma is a production-grade personal health and wellness data platform featuring deterministic calculations, append-only health observation records with rigorous provenance tracking, double-isolated multi-tenant security (application-level + PostgreSQL RLS), and an integrated AI assistant.

Forma is fully bilingual in **Arabic (RTL)** and **English (LTR)** with complete functional parity.

---

## Architecture Overview
- **Backend:** Node.js + TypeScript modular monolith (`/backend`), utilizing Fastify for high-performance HTTP APIs and PostgreSQL for transactional relational storage with Row-Level Security.
- **Mobile:** Flutter application (`/mobile`) supporting iOS and Android with Riverpod state management and locale-driven RTL/LTR presentation.
- **Database:** PostgreSQL 18 with append-only observations, provenance records, and tenant RLS policies.
- **AI Gateway:** Provider-agnostic gateway with task routing, budget enforcement, and zero direct database access for LLMs.

---

## Local Development Setup

### Prerequisites
- Node.js >= 20 (v24 recommended)
- npm >= 10
- PostgreSQL 18 (Local service or via Docker Compose)
- Flutter SDK >= 3.24 (3.47 recommended)

### 1. Environment Configuration
Copy `.env.example` to `.env` in the repository root:
```bash
cp .env.example .env
```
Provide your database credentials and runtime secrets in `.env`. (Never commit `.env` or API keys).

### 2. Start PostgreSQL (Docker or Local)
Using Docker Compose:
```bash
docker compose up -d
```
Or ensure local PostgreSQL 18 service is running on port 5432 with databases `forma_dev` and `forma_test`.

### 3. Backend Setup & Tests
```bash
cd backend
npm install
npm run migrate
npm run test
npm run test:arch
npm run start
```

### 4. Mobile Application Setup
```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

### 5. Automated Secret Scanning
Run the repository secret scanner:
```bash
node scripts/secret-scan.js
```
