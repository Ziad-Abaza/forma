import { describe, it, expect } from 'vitest';
import {
  normalizeToCanonical,
  convertFromCanonical,
  detectPrecision,
  assertCompatibleUnits
} from './index.js';

describe('Unit Registry & Canonical Normalization', () => {
  it('accurately detects decimal precision', () => {
    expect(detectPrecision(82)).toBe(0);
    expect(detectPrecision(82.5)).toBe(1);
    expect(detectPrecision(82.555)).toBe(3);
  });

  it('normalizes kg to canonical kg without precision loss', () => {
    const res = normalizeToCanonical(82.4, 'kg');
    expect(res.canonicalValue).toBe(82.4);
    expect(res.canonicalUnit).toBe('kg');
    expect(res.originalValue).toBe(82.4);
    expect(res.originalUnit).toBe('kg');
    expect(res.inputPrecision).toBe(1);
  });

  it('normalizes lb to canonical kg and preserves round-trip fidelity', () => {
    const inputLb = 181.5;
    const normalized = normalizeToCanonical(inputLb, 'lb');
    expect(normalized.canonicalUnit).toBe('kg');
    expect(normalized.originalUnit).toBe('lb');

    // Round-trip back to lb with original precision (1 decimal place)
    const roundTrip = convertFromCanonical(
      normalized.canonicalValue,
      'lb',
      normalized.inputPrecision
    );
    expect(roundTrip).toBe(inputLb);
  });

  it('normalizes inches to cm and achieves round-trip fidelity', () => {
    const inputInches = 34.25;
    const normalized = normalizeToCanonical(inputInches, 'in');
    expect(normalized.canonicalUnit).toBe('cm');

    const roundTrip = convertFromCanonical(
      normalized.canonicalValue,
      'in',
      normalized.inputPrecision
    );
    expect(roundTrip).toBe(inputInches);
  });

  it('enforces dimension compatibility', () => {
    expect(() => assertCompatibleUnits('kg', 'lb')).not.toThrow();
    expect(() => assertCompatibleUnits('cm', 'in')).not.toThrow();
    expect(() => assertCompatibleUnits('kg', 'cm')).toThrow(/Incompatible unit dimensions/);
  });

  it('rejects unknown unit codes', () => {
    expect(() => normalizeToCanonical(50, 'non_existent_unit')).toThrow(/Unrecognized unit code/);
  });
});
