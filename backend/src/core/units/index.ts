export type Dimension = 'mass' | 'length' | 'ratio' | 'energy' | 'duration' | 'dimensionless';

export interface UnitDefinition {
  code: string;
  dimension: Dimension;
  factorToCanonical: number; // Multiply by this to get canonical unit
  isCanonical: boolean;
  symbolEn: string;
  symbolAr: string;
}

export const UNIT_REGISTRY_VERSION = '1.0.0';

export const UNIT_DEFINITIONS: Record<string, UnitDefinition> = {
  // Mass (Canonical: kg)
  kg: { code: 'kg', dimension: 'mass', factorToCanonical: 1.0, isCanonical: true, symbolEn: 'kg', symbolAr: 'كجم' },
  g: { code: 'g', dimension: 'mass', factorToCanonical: 0.001, isCanonical: false, symbolEn: 'g', symbolAr: 'جم' },
  lb: { code: 'lb', dimension: 'mass', factorToCanonical: 0.45359237, isCanonical: false, symbolEn: 'lb', symbolAr: 'رطل' },
  st: { code: 'st', dimension: 'mass', factorToCanonical: 6.35029318, isCanonical: false, symbolEn: 'st', symbolAr: 'ستون' },
  oz: { code: 'oz', dimension: 'mass', factorToCanonical: 0.028349523125, isCanonical: false, symbolEn: 'oz', symbolAr: 'أونصة' },

  // Length (Canonical: cm)
  cm: { code: 'cm', dimension: 'length', factorToCanonical: 1.0, isCanonical: true, symbolEn: 'cm', symbolAr: 'سم' },
  m: { code: 'm', dimension: 'length', factorToCanonical: 100.0, isCanonical: false, symbolEn: 'm', symbolAr: 'م' },
  mm: { code: 'mm', dimension: 'length', factorToCanonical: 0.1, isCanonical: false, symbolEn: 'mm', symbolAr: 'مم' },
  in: { code: 'in', dimension: 'length', factorToCanonical: 2.54, isCanonical: false, symbolEn: 'in', symbolAr: 'بوصة' },
  ft: { code: 'ft', dimension: 'length', factorToCanonical: 30.48, isCanonical: false, symbolEn: 'ft', symbolAr: 'قدم' },

  // Ratio / Percentage (Canonical: percent)
  percent: { code: 'percent', dimension: 'ratio', factorToCanonical: 1.0, isCanonical: true, symbolEn: '%', symbolAr: '%' },
  fraction: { code: 'fraction', dimension: 'ratio', factorToCanonical: 100.0, isCanonical: false, symbolEn: 'fraction', symbolAr: 'كسر' },
  kg_per_m2: { code: 'kg_per_m2', dimension: 'ratio', factorToCanonical: 1.0, isCanonical: true, symbolEn: 'kg/m²', symbolAr: 'كجم/م²' },

  // Energy (Canonical: kcal)
  kcal: { code: 'kcal', dimension: 'energy', factorToCanonical: 1.0, isCanonical: true, symbolEn: 'kcal', symbolAr: 'سعرة' },
  cal: { code: 'cal', dimension: 'energy', factorToCanonical: 0.001, isCanonical: false, symbolEn: 'cal', symbolAr: 'كالوري' },
  kJ: { code: 'kJ', dimension: 'energy', factorToCanonical: 0.239005736, isCanonical: false, symbolEn: 'kJ', symbolAr: 'كيلوجول' },

  // Duration (Canonical: seconds)
  seconds: { code: 'seconds', dimension: 'duration', factorToCanonical: 1.0, isCanonical: true, symbolEn: 's', symbolAr: 'ث' },
  minutes: { code: 'minutes', dimension: 'duration', factorToCanonical: 60.0, isCanonical: false, symbolEn: 'min', symbolAr: 'د' },
  hours: { code: 'hours', dimension: 'duration', factorToCanonical: 3600.0, isCanonical: false, symbolEn: 'h', symbolAr: 'س' },
  days: { code: 'days', dimension: 'duration', factorToCanonical: 86400.0, isCanonical: false, symbolEn: 'd', symbolAr: 'يوم' },

  // Dimensionless score
  score: { code: 'score', dimension: 'dimensionless', factorToCanonical: 1.0, isCanonical: true, symbolEn: 'pts', symbolAr: 'نقطة' }
};

export const CANONICAL_UNITS_BY_DIMENSION: Record<Dimension, string> = {
  mass: 'kg',
  length: 'cm',
  ratio: 'percent',
  energy: 'kcal',
  duration: 'seconds',
  dimensionless: 'score'
};

export interface NormalizedQuantity {
  canonicalValue: number;
  canonicalUnit: string;
  originalValue: number;
  originalUnit: string;
  dimension: Dimension;
  inputPrecision: number;
  registryVersion: string;
}

export function detectPrecision(value: number): number {
  const str = value.toString();
  const decimalIndex = str.indexOf('.');
  if (decimalIndex === -1) return 0;
  return str.length - decimalIndex - 1;
}

/**
 * Normalizes an entered value into its canonical form.
 * Preserves the original value, original unit, input precision, and registry version.
 */
export function normalizeToCanonical(value: number, unitCode: string): NormalizedQuantity {
  const unit = UNIT_DEFINITIONS[unitCode];
  if (!unit) {
    throw new Error(`Unrecognized unit code: ${unitCode}`);
  }

  const precision = detectPrecision(value);
  const canonicalUnitCode = CANONICAL_UNITS_BY_DIMENSION[unit.dimension];
  const canonicalValue = value * unit.factorToCanonical;

  return {
    canonicalValue: Number(canonicalValue.toFixed(6)),
    canonicalUnit: canonicalUnitCode,
    originalValue: value,
    originalUnit: unitCode,
    dimension: unit.dimension,
    inputPrecision: precision,
    registryVersion: UNIT_REGISTRY_VERSION
  };
}

/**
 * Converts a canonical quantity to a target unit for display, with round-trip fidelity.
 */
export function convertFromCanonical(
  canonicalValue: number,
  targetUnitCode: string,
  precision?: number
): number {
  const targetUnit = UNIT_DEFINITIONS[targetUnitCode];
  if (!targetUnit) {
    throw new Error(`Unrecognized target unit: ${targetUnitCode}`);
  }

  const converted = canonicalValue / targetUnit.factorToCanonical;
  if (precision !== undefined) {
    const factor = Math.pow(10, precision);
    return Math.round(converted * factor) / factor;
  }
  return Number(converted.toFixed(6));
}

/**
 * Validates that two units belong to the same physical dimension.
 */
export function assertCompatibleUnits(unitA: string, unitB: string): void {
  const defA = UNIT_DEFINITIONS[unitA];
  const defB = UNIT_DEFINITIONS[unitB];
  if (!defA || !defB) {
    throw new Error(`One or both units unrecognized: ${unitA}, ${unitB}`);
  }
  if (defA.dimension !== defB.dimension) {
    throw new Error(`Incompatible unit dimensions: ${unitA} (${defA.dimension}) vs ${unitB} (${defB.dimension})`);
  }
}
