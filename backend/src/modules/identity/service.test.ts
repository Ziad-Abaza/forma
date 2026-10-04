import { describe, it, expect } from 'vitest';
import { IdentityService } from './service.js';

describe('IdentityService (ADR-012, §20.1)', () => {
  it('enforces age gate: rejects users under 18 years old', () => {
    // Born today minus 17 years
    const d = new Date();
    d.setFullYear(d.getFullYear() - 17);
    const underageDob = d.toISOString().split('T')[0];

    expect(IdentityService.verifyAge(underageDob)).toBe(false);
  });

  it('enforces age gate: accepts users 18 years old and older', () => {
    const d = new Date();
    d.setFullYear(d.getFullYear() - 25);
    const adultDob = d.toISOString().split('T')[0];

    expect(IdentityService.verifyAge(adultDob)).toBe(true);
  });

  it('hashes and validates passwords with bcrypt', async () => {
    const pwd = 'StrongSecurePassword123!';
    const hash = await IdentityService.hashPassword(pwd);
    expect(hash).not.toBe(pwd);
    expect(hash.startsWith('$2')).toBe(true);

    const valid = await IdentityService.verifyPassword(pwd, hash);
    expect(valid).toBe(true);

    const invalid = await IdentityService.verifyPassword('WrongPassword', hash);
    expect(invalid).toBe(false);
  });

  it('generates secure rotating refresh tokens and validates hashes', () => {
    const { token, hash } = IdentityService.generateRefreshToken();
    expect(token.length).toBeGreaterThan(32);
    expect(hash.length).toBe(64); // SHA-256 hex string

    expect(IdentityService.verifyTokenHash(token, hash)).toBe(true);
    expect(IdentityService.verifyTokenHash('tampered_token', hash)).toBe(false);
  });
});
