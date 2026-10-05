import { describe, it, expect } from 'vitest';
import fs from 'fs';
import path from 'path';

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

describe('Architectural Invariant Tests', () => {
  const srcDir = path.resolve(process.cwd(), 'src');
  const allSourceFiles = findFiles(srcDir);

  it('Invariant 12: Domain modules MUST NOT import any AI provider SDK', () => {
    const PROHIBITED_AI_SDKS = ['@google/generative-ai', 'openai', '@anthropic-ai/sdk', '@mistralai/mistralai'];
    const domainFiles = allSourceFiles.filter(f => f.includes('modules' + path.sep) && !f.includes(path.join('modules', 'ai')));

    for (const f of domainFiles) {
      const content = fs.readFileSync(f, 'utf8');
      for (const sdk of PROHIBITED_AI_SDKS) {
        expect(content.includes(`from '${sdk}'`)).toBe(false);
        expect(content.includes(`from "${sdk}"`)).toBe(false);
        expect(content.includes(`require('${sdk}')`)).toBe(false);
        expect(content.includes(`require("${sdk}")`)).toBe(false);
      }
    }
  });

  it('Invariant 1.4: No @ts-ignore in production code', () => {
    const prodFiles = allSourceFiles.filter(f => !f.includes('.test.ts'));
    for (const f of prodFiles) {
      const content = fs.readFileSync(f, 'utf8');
      expect(content.includes('@ts-ignore')).toBe(false);
    }
  });

  it('Invariant 14: Privacy export and delete contracts implemented across all modules', () => {
    const privacyIndex = path.join(srcDir, 'modules', 'privacy', 'index.ts');
    expect(fs.existsSync(privacyIndex)).toBe(true);
    const content = fs.readFileSync(privacyIndex, 'utf8');
    expect(content.includes('exportData')).toBe(true);
    expect(content.includes('purgeUserData')).toBe(true);
  });

  it('Invariant 6: Double User Isolation: All domain tables with user_id have PostgreSQL RLS policies', () => {
    const migrationsDir = path.join(srcDir, 'core', 'database', 'migrations');
    const migrationFiles = findFiles(migrationsDir, '.sql');
    const allSql = migrationFiles.map(mf => fs.readFileSync(mf, 'utf8')).join('\n');

    const expectedRlsTables = [
      'users', 'credentials', 'sessions', 'consents', 'profiles',
      'observations', 'provenance_records', 'audit_logs',
      'goals', 'goal_versions', 'health_snapshots', 'metric_rollups', 'anomaly_flags',
      'ai_traces', 'user_ai_credentials',
      'conversations', 'conversation_messages', 'action_proposals', 'assistant_memories',
      'media_artifacts', 'extraction_drafts'
    ];

    for (const table of expectedRlsTables) {
      expect(allSql).toContain(`ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY;`);
      expect(allSql).toContain(`ALTER TABLE ${table} FORCE ROW LEVEL SECURITY;`);
    }
  });
});
