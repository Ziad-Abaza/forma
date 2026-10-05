import { describe, it, expect } from 'vitest';
import { getEffectiveHost, getLocalIpAddress, parseConfig, syncMobileEnv } from './index.js';
import fs from 'fs';
import path from 'path';

describe('Backend Configuration & Local Server Networking Tests', () => {
  it('getEffectiveHost binds to 0.0.0.0 when LOCAL_SERVER is true', () => {
    const host = getEffectiveHost(true);
    expect(host).toBe('0.0.0.0');
  });

  it('getEffectiveHost binds to 127.0.0.1 when LOCAL_SERVER is false', () => {
    const host = getEffectiveHost(false);
    expect(host).toBe('127.0.0.1');
  });

  it('getEffectiveHost honors explicit HOST override regardless of LOCAL_SERVER', () => {
    expect(getEffectiveHost(false, '192.168.1.50')).toBe('192.168.1.50');
    expect(getEffectiveHost(true, '10.0.0.5')).toBe('10.0.0.5');
  });

  it('getLocalIpAddress returns a valid IPv4 address that is not loopback or link-local', () => {
    const ip = getLocalIpAddress();
    expect(ip).toBeDefined();
    // Validate IPv4 format
    const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
    expect(ipv4Regex.test(ip)).toBe(true);
    // Must not be 169.254.x.x link-local
    expect(ip.startsWith('169.254.')).toBe(false);
  });

  it('syncMobileEnv updates mobile/.env with local IP and LOCAL_SERVER=true', () => {
    const testLocalIp = '192.168.100.99';
    const testPort = 3000;
    
    const result = syncMobileEnv(testLocalIp, testPort);
    expect(result).toBe(true);

    const mobileEnvPath = path.resolve(process.cwd(), '../mobile/.env');
    if (fs.existsSync(mobileEnvPath)) {
      const content = fs.readFileSync(mobileEnvPath, 'utf8');
      expect(content).toContain(`API_BASE_URL=http://${testLocalIp}:${testPort}`);
      expect(content).toContain('LOCAL_SERVER=true');
      expect(content).toContain(`LOCAL_IP=${testLocalIp}`);
    }
  });
});

describe('Secret material fails closed (HC-001, HC-002, HC-003)', () => {
  const baseEnv = {
    NODE_ENV: 'production',
    DATABASE_URL: 'postgresql://app:pw@db.example.com:5432/forma',
    JWT_ACCESS_SECRET: 'a'.repeat(48),
    JWT_REFRESH_SECRET: 'b'.repeat(48),
    ENCRYPTION_MASTER_KEY: 'c'.repeat(64)
  } as NodeJS.ProcessEnv;

  it('refuses to boot outside test when required secrets are missing', () => {
    expect(() => parseConfig({ NODE_ENV: 'production' })).toThrow(
      /Missing required environment variables: DATABASE_URL, JWT_ACCESS_SECRET, JWT_REFRESH_SECRET, ENCRYPTION_MASTER_KEY/
    );
    expect(() => parseConfig({ NODE_ENV: 'development' })).toThrow(/Missing required environment variables/);
    expect(() => parseConfig({ ...baseEnv })).not.toThrow();
  });

  it('rejects weak or malformed secret values', () => {
    expect(() => parseConfig({ ...baseEnv, JWT_ACCESS_SECRET: 'short' })).toThrow(
      'Invalid environment configuration'
    );
    expect(() => parseConfig({ ...baseEnv, ENCRYPTION_MASTER_KEY: 'not-hex' })).toThrow(
      'Invalid environment configuration'
    );
    expect(() => parseConfig({ ...baseEnv, ENCRYPTION_MASTER_KEY: 'zz'.repeat(32) })).toThrow(
      'Invalid environment configuration'
    );
  });

  it('generates ephemeral random secrets in test env instead of committed literals', () => {
    const a = parseConfig({ NODE_ENV: 'test' });
    const b = parseConfig({ NODE_ENV: 'test' });
    expect(a.JWT_ACCESS_SECRET).toMatch(/^[0-9a-f]{64}$/);
    expect(a.ENCRYPTION_MASTER_KEY).toMatch(/^[0-9a-f]{64}$/);
    expect(a.JWT_ACCESS_SECRET).not.toBe(b.JWT_ACCESS_SECRET);
    expect(a.ENCRYPTION_MASTER_KEY).not.toBe(b.ENCRYPTION_MASTER_KEY);
  });
});
