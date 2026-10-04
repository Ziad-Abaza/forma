/**
 * Forma Core Unit Registry (ADR-021)
 *
 * Requirements:
 * 1. Dimension + canonical unit: Each dimension has exactly ONE canonical unit.
 * 2. Boundary normalization: All inputs normalized to canonical before hitting domain logic.
 * 3. Original preservation: as-entered value, unit, precision, and registry version stored.
 * 4. Precision integrity: Exact rounding and zero cumulative floating drift.
 * 5. Extensibility: New units and dimensions registered without schema modification.
 */

export type Dimension = 
  | 'mass'
  | 'length'
  | 'percentage'
  | 'energy'
  | 'duration'
  | 'count'
  | 'score';

export interface UnitDefinition {
  code: string;
  dimension: Dimension;
  name: string;
  symbol: string;
  toCanonicalFactor: number; // multiplier to canonical
  toCanonicalOffset?: number; // for non-proportional scales if ever needed
  isCanonical: boolean;
  defaultDecimals: number;
}

export const REGISTRY_VERSION = '1.0.0';

export class UnitRegistry {
  private static units: Map<string, UnitDefinition> = new Map();
  private static canonicalUnits: Map<Dimension, UnitDefinition> = new Map();

  static {
    // Mass: canonical unit = kilogram (kg)
    this.register({ code: 'kg', dimension: 'mass', name: 'Kilogram', symbol: 'kg', toCanonicalFactor: 1.0, isCanonical: true, defaultDecimals: 1 });
    this.register({ code: 'g', dimension: 'mass', name: 'Gram', symbol: 'g', toCanonicalFactor: 0.001, isCanonical: false, defaultDecimals: 0 });
    this.register({ code: 'lb', dimension: 'mass', name: 'Pound', symbol: 'lb', toCanonicalFactor: 0.45359237, isCanonical: false, defaultDecimals: 1 });
    this.register({ code: 'st', dimension: 'mass', name: 'Stone', symbol: 'st', toCanonicalFactor: 6.35029318, isCanonical: false, defaultDecimals: 2 });

    // Length: canonical unit = centimeter (cm)
    this.register({ code: 'cm', dimension: 'length', name: 'Centimeter', symbol: 'cm', toCanonicalFactor: 1.0, isCanonical: true, defaultDecimals: 1 });
    this.register({ code: 'm', dimension: 'length', name: 'Meter', symbol: 'm', toCanonicalFactor: 100.0, isCanonical: false, defaultDecimals: 2 });
    this.register({ code: 'mm', dimension: 'length', name: 'Millimeter', symbol: 'mm', toCanonicalFactor: 0.1, isCanonical: false, defaultDecimals: 0 });
    this.register({ code: 'in', dimension: 'length', name: 'Inch', symbol: 'in', toCanonicalFactor: 2.54, isCanonical: false, defaultDecimals: 1 });
    this.register({ code: 'ft', dimension: 'length', name: 'Foot', symbol: 'ft', toCanonicalFactor: 30.48, isCanonical: false, defaultDecimals: 2 });

    // Percentage: canonical unit = percent (%)
    this.register({ code: 'percent', dimension: 'percentage', name: 'Percent', symbol: '%', toCanonicalFactor: 1.0, isCanonical: true, defaultDecimals: 1 });
    this.register({ code: 'ratio', dimension: 'percentage', name: 'Ratio', symbol: 'ratio', toCanonicalFactor: 100.0, isCanonical: false, defaultDecimals: 3 });

    // Energy: canonical unit = kilocalorie (kcal) (ADR-021 §7.5)
    this.register({ code: 'kcal', dimension: 'energy', name: 'Kilocalorie', symbol: 'kcal', toCanonicalFactor: 1.0, isCanonical: true, defaultDecimals: 0 });
    this.register({ code: 'cal', dimension: 'energy', name: 'Calorie', symbol: 'cal', toCanonicalFactor: 0.001, isCanonical: false, defaultDecimals: 0 });
    this.register({ code: 'kJ', dimension: 'energy', name: 'Kilojoule', symbol: 'kJ', toCanonicalFactor: 0.239005736, isCanonical: false, defaultDecimals: 0 });

    // Duration: canonical unit = second (s)
    this.register({ code: 's', dimension: 'duration', name: 'Second', symbol: 's', toCanonicalFactor: 1.0, isCanonical: true, defaultDecimals: 0 });
    this.register({ code: 'min', dimension: 'duration', name: 'Minute', symbol: 'min', toCanonicalFactor: 60.0, isCanonical: false, defaultDecimals: 1 });
    this.register({ code: 'h', dimension: 'duration', name: 'Hour', symbol: 'h', toCanonicalFactor: 3600.0, isCanonical: false, defaultDecimals: 2 });

    // Count: canonical unit = count
    this.register({ code: 'count', dimension: 'count', name: 'Count', symbol: '', toCanonicalFactor: 1.0, isCanonical: true, defaultDecimals: 0 });

    // Score / Dimensionless: canonical unit = score
    this.register({ code: 'score', dimension: 'score', name: 'Score', symbol: '', toCanonicalFactor: 1.0, isCanonical: true, defaultDecimals: 1 });
  }

  static register(unit: UnitDefinition): void {
    this.units.set(unit.code.toLowerCase(), unit);
    if (unit.isCanonical) {
      this.canonicalUnits.set(unit.dimension, unit);
    }
  }

  static getUnit(code: string): UnitDefinition {
    const unit = this.units.get(code.toLowerCase());
    if (!unit) {
      throw new Error(`Unit '${code}' is not registered in Unit Registry v${REGISTRY_VERSION}`);
    }
    return unit;
  }

  static getCanonicalUnitForDimension(dimension: Dimension): UnitDefinition {
    const canonical = this.canonicalUnits.get(dimension);
    if (!canonical) {
      throw new Error(`No canonical unit defined for dimension '${dimension}'`);
    }
    return canonical;
  }

  /**
   * Determine decimal precision of an entered numeric value.
   */
  static getPrecision(value: number | string): number {
    const str = typeof value === 'number' ? value.toString() : value;
    if (str.includes('.')) {
      return str.split('.')[1].length;
    }
    return 0;
  }

  /**
   * Convert an entered value with a specified unit to the canonical value of its dimension.
   */
  static normalize(value: number, unitCode: string): {
    canonicalValue: number;
    canonicalUnit: string;
    originalValue: number;
    originalUnit: string;
    inputPrecision: number;
    registryVersion: string;
  } {
    const unit = this.getUnit(unitCode);
    const precision = this.getPrecision(value);
    const canonical = this.getCanonicalUnitForDimension(unit.dimension);

    let rawCanonical = value * unit.toCanonicalFactor;
    if (unit.toCanonicalOffset) {
      rawCanonical += unit.toCanonicalOffset;
    }

    // Round canonical value to maintain reasonable precision without floating drift (max 4 decimal places)
    const canonicalValue = Math.round(rawCanonical * 10000) / 10000;

    return {
      canonicalValue,
      canonicalUnit: canonical.code,
      originalValue: value,
      originalUnit: unit.code,
      inputPrecision: precision,
      registryVersion: REGISTRY_VERSION,
    };
  }

  /**
   * Convert canonical value to a target display unit with round-trip fidelity.
   */
  static convert(canonicalValue: number, targetUnitCode: string, targetPrecision?: number): number {
    const targetUnit = this.getUnit(targetUnitCode);
    let converted = canonicalValue / targetUnit.toCanonicalFactor;
    if (targetUnit.toCanonicalOffset) {
      converted -= targetUnit.toCanonicalOffset;
    }

    const precision = targetPrecision !== undefined ? targetPrecision : targetUnit.defaultDecimals;
    const factor = Math.pow(10, precision);
    return Math.round(converted * factor) / factor;
  }
}
