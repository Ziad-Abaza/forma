import { describe, it, expect } from 'vitest';
import { UnitRegistry, REGISTRY_VERSION } from './units.js';

describe('UnitRegistry (ADR-021)', () => {
  it('registers canonical units for all key dimensions', () => {
    expect(UnitRegistry.getCanonicalUnitForDimension('mass').code).toBe('kg');
    expect(UnitRegistry.getCanonicalUnitForDimension('length').code).toBe('cm');
    expect(UnitRegistry.getCanonicalUnitForDimension('energy').code).toBe('kcal');
    expect(UnitRegistry.getCanonicalUnitForDimension('percentage').code).toBe('percent');
    expect(UnitRegistry.getCanonicalUnitForDimension('duration').code).toBe('s');
  });

  it('normalizes weight correctly with precision and original preserved', () => {
    // 181.5 lb to kg
    const res = UnitRegistry.normalize(181.5, 'lb');
    expect(res.canonicalUnit).toBe('kg');
    expect(res.originalValue).toBe(181.5);
    expect(res.originalUnit).toBe('lb');
    expect(res.inputPrecision).toBe(1);
    expect(res.registryVersion).toBe(REGISTRY_VERSION);
    // 181.5 * 0.45359237 = 82.327015... -> 82.327
    expect(res.canonicalValue).toBeCloseTo(82.327, 2);

    // Convert back to lb
    const displayLb = UnitRegistry.convert(res.canonicalValue, 'lb', 1);
    expect(displayLb).toBe(181.5);
  });

  it('normalizes length correctly with round-trip fidelity', () => {
    // 6 feet
    const res = UnitRegistry.normalize(6.0, 'ft');
    expect(res.canonicalUnit).toBe('cm');
    expect(res.canonicalValue).toBe(182.88);

    const backToFt = UnitRegistry.convert(res.canonicalValue, 'ft', 1);
    expect(backToFt).toBe(6.0);
  });

  it('normalizes energy with canonical kcal', () => {
    const res = UnitRegistry.normalize(2500, 'kcal');
    expect(res.canonicalUnit).toBe('kcal');
    expect(res.canonicalValue).toBe(2500);

    // Kilojoules to kcal
    const kjRes = UnitRegistry.normalize(10000, 'kJ');
    expect(kjRes.canonicalUnit).toBe('kcal');
    expect(kjRes.canonicalValue).toBe(2390.0574);
  });

  it('throws an error when an unregistered unit is requested', () => {
    expect(() => UnitRegistry.getUnit('unknown_unit')).toThrowError(/not registered/);
  });
});
