import { describe, it, expect, beforeAll } from 'vitest';
import fs from 'fs';
import path from 'path';
import { CalculationEngine } from '../modules/calculations/engine.js';
import { normalizeToCanonical } from '../core/units/index.js';
import { sanitizeLogData } from '../core/logging/index.js';
import { PrivacyOrchestrator } from '../modules/privacy/index.js';
import { buildApp } from '../app.js';

function findFiles(dir: string, ext = '.ts'): string[] {
  let results: string[] = [];
  const list = fs.readdirSync(dir);
  for (const file of list) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat && stat.isDirectory()) {
      results = results.concat(findFiles(filePath, ext));
    } else if (file.endsWith(ext)) {
      results.push(filePath);
    }
  }
  return results;
}

describe('Final Architectural Invariants Audit (Forma Blueprint §31 & §32)', () => {
  const srcDir = path.resolve(process.cwd(), 'src');
  const allSourceFiles = findFiles(srcDir);
  const prodFiles = allSourceFiles.filter(f => !f.includes('.test.ts'));

  beforeAll(() => {
    // Initialize app to register all modular privacy contracts
    buildApp();
  });

  // --- Invariant 1: AI has no direct DB access ---
  it('Invariant 1: AI Gateway Adapters & Safety Engine have zero direct database access', () => {
    const aiAdaptersDir = path.join(srcDir, 'modules', 'ai', 'gateway', 'adapters');
    const aiSafetyDir = path.join(srcDir, 'modules', 'ai', 'safety');
    const files = [...findFiles(aiAdaptersDir), ...findFiles(aiSafetyDir)];

    for (const f of files) {
      const content = fs.readFileSync(f, 'utf8');
      expect(content.includes("from 'pg'")).toBe(false);
      expect(content.includes('from "pg"')).toBe(false);
      expect(content.includes('SELECT ')).toBe(false);
      expect(content.includes('INSERT INTO ')).toBe(false);
      expect(content.includes('UPDATE ')).toBe(false);
      expect(content.includes('DELETE FROM ')).toBe(false);
    }
  });

  // --- Invariant 2: No AI value enters health record without receipt-backed confirmation ---
  it('Invariant 2: AI proposals require explicit confirmation and idempotency receipts to enter health records', () => {
    const proposalsEnginePath = path.join(srcDir, 'modules', 'assistant', 'proposals.ts');
    expect(fs.existsSync(proposalsEnginePath)).toBe(true);
    const content = fs.readFileSync(proposalsEnginePath, 'utf8');

    expect(content.includes('confirmProposal')).toBe(true);
    expect(content.includes('idempotencyKey')).toBe(true);
    expect(content.includes("status = 'executed'")).toBe(true);
  });

  // --- Invariant 3: Facts are never overwritten (append-only + supersession) ---
  it('Invariant 3: Observations schema and service enforce append-only immutability with supersession', () => {
    const measurementsRepo = path.join(srcDir, 'modules', 'measurements', 'repository.ts');
    const content = fs.readFileSync(measurementsRepo, 'utf8');

    // Never direct in-place UPDATE of value_numeric
    expect(content.includes('UPDATE observations SET canonical_value =')).toBe(false);
    expect(content.includes('UPDATE observations SET original_value =')).toBe(false);
    expect(content.includes('supersedes')).toBe(true);
    expect(content.includes('superseded_by')).toBe(true);
  });

  // --- Invariant 4: Calculations and safety rules live in pure code ---
  it('Invariant 4: CalculationEngine and safety algorithms live in pure code with zero AI/LLM dependence', () => {
    const calcEngine = new CalculationEngine();
    const bmiRes = calcEngine.calculateBmi(70, 175);
    expect(bmiRes.value).toBe(22.9);
    expect(bmiRes.category).toBe('normal');

    const bmrRes = calcEngine.calculateBmr({ weightKg: 70, heightCm: 175, ageYears: 30, sex: 'male' });
    expect(bmrRes.value).toBeGreaterThan(1600);

    const calcFile = path.join(srcDir, 'modules', 'calculations', 'engine.ts');
    const content = fs.readFileSync(calcFile, 'utf8');
    expect(content.includes('AIGateway')).toBe(false);
    expect(content.includes('google')).toBe(false);
  });

  // --- Invariant 5: Every value has provenance and confidence ---
  it('Invariant 5: Every observation record is bound to provenance with origin and confidence score', () => {
    const initialSchema = path.join(srcDir, 'core', 'database', 'migrations', '001_phase1_initial_schema.sql');
    const content = fs.readFileSync(initialSchema, 'utf8');

    expect(content.includes('provenance_id UUID NOT NULL REFERENCES provenance_records(id)')).toBe(true);
    expect(content.includes('confidence_score NUMERIC(4, 3) NOT NULL')).toBe(true);
    expect(content.includes('origin_type VARCHAR(64) NOT NULL')).toBe(true);
    expect(content.includes('epistemic_class VARCHAR(32) NOT NULL')).toBe(true);
  });

  // --- Invariant 6: Double user isolation (app + DB RLS across all 24 tables) ---
  it('Invariant 6: Double User Isolation: All 24 tables enforce PostgreSQL Row Level Security (RLS)', () => {
    const migrationsDir = path.join(srcDir, 'core', 'database', 'migrations');
    const migrationFiles = findFiles(migrationsDir, '.sql');
    const allSql = migrationFiles.map(mf => fs.readFileSync(mf, 'utf8')).join('\n');

    const expectedRlsTables = [
      'users', 'credentials', 'sessions', 'consents', 'profiles',
      'observations', 'provenance_records', 'audit_logs',
      'goals', 'goal_versions', 'health_snapshots', 'metric_rollups', 'anomaly_flags',
      'ai_traces', 'user_ai_credentials',
      'conversations', 'conversation_messages', 'action_proposals', 'assistant_memories',
      'media_artifacts', 'extraction_drafts',
      'integration_connections', 'import_batches', 'sync_dedup_records'
    ];

    expect(expectedRlsTables.length).toBe(24);

    for (const table of expectedRlsTables) {
      expect(allSql).toContain(`ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY;`);
      expect(allSql).toContain(`ALTER TABLE ${table} FORCE ROW LEVEL SECURITY;`);
    }
  });

  // --- Invariant 7: Canonical unit conversion with original preserved ---
  it('Invariant 7: Unit normalization preserves original value & unit while computing canonical', () => {
    const converted = normalizeToCanonical(154.32, 'lb');
    expect(converted.canonicalUnit).toBe('kg');
    expect(converted.canonicalValue).toBeCloseTo(70.0, 1);
    expect(converted.originalUnit).toBe('lb');
    expect(converted.originalValue).toBe(154.32);
  });

  // --- Invariant 8: Derived data lineage and snapshot invalidation ---
  it('Invariant 8: Snapshots track source data watermark and allow on-demand deterministic reconciliation', () => {
    const analyticsServicePath = path.join(srcDir, 'modules', 'analytics', 'service.ts');
    const snapshotPath = path.join(srcDir, 'modules', 'analytics', 'snapshot.ts');
    const content = fs.readFileSync(analyticsServicePath, 'utf8');
    const snapContent = fs.readFileSync(snapshotPath, 'utf8');

    expect(content.includes('reconcileSnapshot')).toBe(true);
    expect(snapContent.includes('source_data_watermark')).toBe(true);
  });

  // --- Invariant 9: AI context assembled solely through Context Engine under budget ---
  it('Invariant 9: AI Context Engine enforces tiered context assembly with token budgets', () => {
    const engineFile = path.join(srcDir, 'modules', 'ai', 'context', 'engine.ts');
    const content = fs.readFileSync(engineFile, 'utf8');

    expect(content.includes('assembleContext')).toBe(true);
    expect(content.includes('ContextManifest')).toBe(true);
  });

  // --- Invariant 10: Content-free, secret-free AI traces ---
  it('Invariant 10: AITraceService logs operational telemetry without storing raw prompts or health metrics', () => {
    const schemaFile = path.join(srcDir, 'core', 'database', 'migrations', '006_ai_traces_schema.sql');
    const content = fs.readFileSync(schemaFile, 'utf8');

    // ai_traces must not contain prompt text or raw message body
    expect(content.includes('prompt_text TEXT')).toBe(false);
    expect(content.includes('user_content TEXT')).toBe(false);
    expect(content.includes('raw_message TEXT')).toBe(false);
    expect(content.includes('context_manifest JSONB NOT NULL')).toBe(true);
  });

  // --- Invariant 11: Estimates never represented as measurements ---
  it('Invariant 11: Estimations and inferences are explicitly tagged and distinguished from direct measurements', () => {
    const contractsFile = path.join(srcDir, 'modules', 'measurements', 'contracts.ts');
    const content = fs.readFileSync(contractsFile, 'utf8');

    expect(content.includes("'measured', 'calculated', 'estimated', 'asserted'")).toBe(true);
  });

  // --- Invariant 12: Domain modules never import provider SDKs ---
  it('Invariant 12: Domain modules MUST NOT import vendor AI SDKs', () => {
    const PROHIBITED_AI_SDKS = ['@google/generative-ai', 'openai', '@anthropic-ai/sdk', '@mistralai/mistralai'];
    const domainFiles = allSourceFiles.filter(f => f.includes('modules' + path.sep) && !f.includes(path.join('modules', 'ai')));

    for (const f of domainFiles) {
      const content = fs.readFileSync(f, 'utf8');
      for (const sdk of PROHIBITED_AI_SDKS) {
        expect(content.includes(`from '${sdk}'`)).toBe(false);
        expect(content.includes(`from "${sdk}"`)).toBe(false);
      }
    }
  });

  // --- Invariant 13: Health content never appears in logs by default ---
  it('Invariant 13: Application logger automatically redacts biometrics, health data, and credentials', () => {
    const sanitized = sanitizeLogData({
      bloodGlucose: 110,
      weightKg: 75.0,
      systolic: 120,
      password: 'secretPassword',
      token: 'jwt-token-value'
    });

    expect(sanitized.bloodGlucose).toBe('[REDACTED]');
    expect(sanitized.weightKg).toBe('[REDACTED]');
    expect(sanitized.systolic).toBe('[REDACTED]');
    expect(sanitized.password).toBe('[REDACTED]');
    expect(sanitized.token).toBe('[REDACTED]');
  });

  // --- Invariant 14: Every module implements export and delete contracts ---
  it('Invariant 14: Privacy Orchestrator enforces GDPR export and cascading purge contracts across all registered modules', () => {
    const registeredModules = PrivacyOrchestrator.getRegisteredModules();
    expect(registeredModules.length).toBeGreaterThan(0);

    for (const mod of registeredModules) {
      expect(typeof mod.exportData).toBe('function');
      expect(typeof mod.purgeUserData).toBe('function');
      expect(typeof mod.moduleName).toBe('string');
    }
  });

  // --- Invariant 15: Dashboard estimates/insights are precomputed and cached ---
  it('Invariant 15: Health snapshots table caches precomputed dashboard state with versioning', () => {
    const schemaFile = path.join(srcDir, 'core', 'database', 'migrations', '005_phase2_schema.sql');
    const content = fs.readFileSync(schemaFile, 'utf8');

    expect(content.includes('CREATE TABLE IF NOT EXISTS health_snapshots')).toBe(true);
    expect(content.includes('sections JSONB NOT NULL DEFAULT \'{}\'::jsonb')).toBe(true);
    expect(content.includes('source_data_watermark VARCHAR(100) NOT NULL')).toBe(true);
  });

  // --- Code Quality & Strict Typing Invariant ---
  it('Code Quality Invariant: No @ts-ignore directives exist anywhere in production code', () => {
    for (const f of prodFiles) {
      const content = fs.readFileSync(f, 'utf8');
      expect(content.includes('@ts-ignore')).toBe(false);
    }
  });
});
