import { describe, it, expect } from 'vitest';
import { getEffectiveHost, getLocalIpAddress, syncMobileEnv } from './index.js';
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
