# Forma Backend Service

Forma's modular monolith backend built with TypeScript, Node.js 22, Fastify, and PostgreSQL 18.

## Self-Contained Directory Architecture

This directory is completely self-contained. It contains its own:
- Environment configuration files (`.env`, `.env.example`)
- Local containerized PostgreSQL setup (`docker-compose.yml`)
- TypeScript configurations and build scripts
- Database migrations and RLS schema definitions
- Comprehensive automated test suites (Architecture, Unit, and Integration)
- Production Dockerfile and multi-stage container build

## Prerequisites

- **Node.js**: `v22.x` or later (LTS recommended)
- **npm**: `v10.x` or later
- **Docker**: For running PostgreSQL 18 locally (optional if using external Postgres)

## Getting Started

### 1. Environment Configuration

Copy the example environment configuration:
```bash
cp .env.example .env
```

Ensure the values in `.env` match your environment. In development:
- `PORT=3000`
- `DATABASE_URL=postgresql://forma_app:<APP_ROLE_PASSWORD>@localhost:5432/forma_dev`
- `DATABASE_URL_MIGRATIONS=postgresql://postgres:<SUPERUSER_PASSWORD>@localhost:5432/forma_dev`
- `GEMINI_API_KEY`: Add your Google Gemini API key if testing live AI inference.

### 2. Install Dependencies

```bash
npm install
```

### 3. Launch Local Database

Start PostgreSQL 18 with health checks:
```bash
docker compose up -d
```

### 4. Run Database Migrations

Apply migrations to initialize all tables, indexes, and Row-Level Security (RLS) policies:
```bash
npm run migrate
```

### 5. Start Development Server

Run the development server with live reload:
```bash
npm run dev
```

The API will be available at `http://localhost:3000`.

### Health Check

Verify the service is up:
```bash
curl http://localhost:3000/health
```

Expected response: `{"status":"healthy","uptime":...}`

## Running Tests

- Run all unit and integration tests:
  ```bash
  npm test
  ```
- Run architecture boundary guard tests:
  ```bash
  npm run test:arch
  ```
- Typecheck without emitting files:
  ```bash
  npm run typecheck
  ```

## Building for Production

Compile TypeScript and copy migration assets:
```bash
npm run build
npm run start:prod
```

Or build and run via Docker:
```bash
docker build -t forma-backend .
docker run -p 3000:3000 --env-file .env forma-backend
```
