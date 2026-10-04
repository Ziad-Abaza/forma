/**
 * Measurement Type Catalog (ADR-009, §7.2, §13.4, §27.1)
 *
 * Rules:
 * - New measurement kinds are added as catalog entries, not schema changes.
 * - Typed: anthropometric, composition, circumference, physiological.
 * - Declares canonical unit, allowed units, series class, default aggregation semantic,
 *   plausible range for validation, and laterality.
 */

import { Dimension } from '../core/units.js';

export type MeasurementCategory = 'anthropometric' | 'composition' | 'circumference' | 'physiological';
export type SeriesClass = 'point' | 'interval';
export type AggregationSemantic = 'latest' | 'mean' | 'min' | 'max' | 'sum';
export type Laterality = 'none' | 'left' | 'right' | 'bilateral';

export interface MeasurementType {
  code: string;
  category: MeasurementCategory;
  dimension: Dimension;
  canonicalUnit: string;
  allowedUnits: string[];
  plausibleRange: {
    min: number; // in canonical units
    max: number; // in canonical units
  };
  warningRange?: {
    min: number; // in canonical units
    max: number; // in canonical units
  };
  seriesClass: SeriesClass;
  defaultAggregation: AggregationSemantic;
  laterality: Laterality;
  isUserEnterable: boolean;
  isDerived: boolean;
  name: {
    en: string;
    ar: string;
  };
  description: {
    en: string;
    ar: string;
  };
}

export class MeasurementCatalog {
  private static types: Map<string, MeasurementType> = new Map();

  static {
    // 1. Weight (Mass)
    this.register({
      code: 'weight',
      category: 'anthropometric',
      dimension: 'mass',
      canonicalUnit: 'kg',
      allowedUnits: ['kg', 'lb', 'st'],
      plausibleRange: { min: 20.0, max: 400.0 },
      warningRange: { min: 35.0, max: 250.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Weight', ar: 'الوزن' },
      description: { en: 'Total body mass', ar: 'إجمالي كتلة الجسم' },
    });

    // 2. Height (Length)
    this.register({
      code: 'height',
      category: 'anthropometric',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'm', 'in', 'ft'],
      plausibleRange: { min: 50.0, max: 270.0 },
      warningRange: { min: 120.0, max: 220.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Height', ar: 'الطول' },
      description: { en: 'Stature', ar: 'طول القامة' },
    });

    // 3. Body Fat Percentage
    this.register({
      code: 'body_fat_pct',
      category: 'composition',
      dimension: 'percentage',
      canonicalUnit: 'percent',
      allowedUnits: ['percent'],
      plausibleRange: { min: 3.0, max: 70.0 },
      warningRange: { min: 5.0, max: 55.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Body Fat %', ar: 'نسبة الدهون' },
      description: { en: 'Percentage of total body weight consisting of adipose tissue', ar: 'نسبة الدهون من إجمالي وزن الجسم' },
    });

    // 4. Skeletal Muscle Mass (Mass)
    this.register({
      code: 'skeletal_muscle_mass',
      category: 'composition',
      dimension: 'mass',
      canonicalUnit: 'kg',
      allowedUnits: ['kg', 'lb'],
      plausibleRange: { min: 10.0, max: 150.0 },
      warningRange: { min: 15.0, max: 80.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Skeletal Muscle Mass', ar: 'الكتلة العضلية الهيكلية' },
      description: { en: 'Muscle mass attached to the skeleton', ar: 'كتلة العضلات المتصلة بالهيكل العظمي' },
    });

    // 5. Fat-Free Mass / Lean Body Mass
    this.register({
      code: 'lean_mass',
      category: 'composition',
      dimension: 'mass',
      canonicalUnit: 'kg',
      allowedUnits: ['kg', 'lb'],
      plausibleRange: { min: 15.0, max: 200.0 },
      warningRange: { min: 25.0, max: 120.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Lean Body Mass', ar: 'كتلة الجسم غير الدهنية' },
      description: { en: 'Total body mass minus body fat', ar: 'إجمالي كتلة الجسم منقوصاً منها الدهون' },
    });

    // 6. Total Body Water
    this.register({
      code: 'body_water',
      category: 'composition',
      dimension: 'mass',
      canonicalUnit: 'kg',
      allowedUnits: ['kg', 'lb'],
      plausibleRange: { min: 10.0, max: 150.0 },
      warningRange: { min: 20.0, max: 80.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Total Body Water', ar: 'ماء الجسم الإجمالي' },
      description: { en: 'Total water content in the body', ar: 'كمية السوائل الإجمالية داخل الجسم' },
    });

    // 7. Visceral Fat Level / Score
    this.register({
      code: 'visceral_fat_level',
      category: 'composition',
      dimension: 'score',
      canonicalUnit: 'score',
      allowedUnits: ['score'],
      plausibleRange: { min: 1.0, max: 50.0 },
      warningRange: { min: 1.0, max: 30.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Visceral Fat Level', ar: 'مستوى الدهون الحشوية' },
      description: { en: 'Estimated rating of abdominal visceral adipose tissue', ar: 'تقييم الدهون الحشوية المحيطة بالأعضاء الداخلية' },
    });

    // 8. Bone Mass
    this.register({
      code: 'bone_mass',
      category: 'composition',
      dimension: 'mass',
      canonicalUnit: 'kg',
      allowedUnits: ['kg', 'lb'],
      plausibleRange: { min: 0.5, max: 15.0 },
      warningRange: { min: 1.5, max: 7.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Bone Mineral Content', ar: 'الكتلة العظمية' },
      description: { en: 'Estimated mineral weight of bones', ar: 'الوزن التقريبي للمعادن العظمية' },
    });

    // 9. Waist Circumference
    this.register({
      code: 'waist_circ',
      category: 'circumference',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'in'],
      plausibleRange: { min: 40.0, max: 250.0 },
      warningRange: { min: 55.0, max: 180.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Waist Circumference', ar: 'محيط الخصر' },
      description: { en: 'Horizontal measurement around the narrowest part of waist or umbilicus', ar: 'محيط منطقة الخصر' },
    });

    // 10. Hip Circumference
    this.register({
      code: 'hip_circ',
      category: 'circumference',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'in'],
      plausibleRange: { min: 50.0, max: 250.0 },
      warningRange: { min: 70.0, max: 180.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Hip Circumference', ar: 'محيط الأرداف' },
      description: { en: 'Measurement around the widest portion of the buttocks', ar: 'محيط منطقة الأرداف' },
    });

    // 11. Chest Circumference
    this.register({
      code: 'chest_circ',
      category: 'circumference',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'in'],
      plausibleRange: { min: 50.0, max: 250.0 },
      warningRange: { min: 65.0, max: 180.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'none',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Chest Circumference', ar: 'محيط الصدر' },
      description: { en: 'Measurement around the widest portion of the chest', ar: 'محيط منطقة الصدر' },
    });

    // 12. Arm Circumference (Bilateral / laterality aware)
    this.register({
      code: 'arm_circ_left',
      category: 'circumference',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'in'],
      plausibleRange: { min: 15.0, max: 80.0 },
      warningRange: { min: 20.0, max: 60.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'left',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Left Arm Circumference', ar: 'محيط الذراع الأيسر' },
      description: { en: 'Circumference of upper left arm at peak bicep', ar: 'محيط أعلى الذراع الأيسر' },
    });
    this.register({
      code: 'arm_circ_right',
      category: 'circumference',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'in'],
      plausibleRange: { min: 15.0, max: 80.0 },
      warningRange: { min: 20.0, max: 60.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'right',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Right Arm Circumference', ar: 'محيط الذراع الأيمن' },
      description: { en: 'Circumference of upper right arm at peak bicep', ar: 'محيط أعلى الذراع الأيمن' },
    });

    // 13. Thigh Circumference
    this.register({
      code: 'thigh_circ_left',
      category: 'circumference',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'in'],
      plausibleRange: { min: 25.0, max: 120.0 },
      warningRange: { min: 35.0, max: 90.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'left',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Left Thigh Circumference', ar: 'محيط الفخذ الأيسر' },
      description: { en: 'Circumference of upper left thigh', ar: 'محيط الفخذ الأيسر' },
    });
    this.register({
      code: 'thigh_circ_right',
      category: 'circumference',
      dimension: 'length',
      canonicalUnit: 'cm',
      allowedUnits: ['cm', 'in'],
      plausibleRange: { min: 25.0, max: 120.0 },
      warningRange: { min: 35.0, max: 90.0 },
      seriesClass: 'point',
      defaultAggregation: 'latest',
      laterality: 'right',
      isUserEnterable: true,
      isDerived: false,
      name: { en: 'Right Thigh Circumference', ar: 'محيط الفخذ الأيمن' },
      description: { en: 'Circumference of upper right thigh', ar: 'محيط الفخذ الأيمن' },
    });
  }

  static register(type: MeasurementType): void {
    this.types.set(type.code.toLowerCase(), type);
  }

  static get(code: string): MeasurementType {
    const type = this.types.get(code.toLowerCase());
    if (!type) {
      throw new Error(`Measurement type '${code}' is not recognized in catalog`);
    }
    return type;
  }

  static getAll(): MeasurementType[] {
    return Array.from(this.types.values());
  }

  static validatePlausibility(code: string, canonicalValue: number): {
    isValid: boolean;
    isWarning: boolean;
    reason?: string;
  } {
    const type = this.get(code);
    if (canonicalValue < type.plausibleRange.min || canonicalValue > type.plausibleRange.max) {
      return {
        isValid: false,
        isWarning: true,
        reason: `Value ${canonicalValue} ${type.canonicalUnit} is outside biologically plausible limits (${type.plausibleRange.min} - ${type.plausibleRange.max} ${type.canonicalUnit})`,
      };
    }
    if (type.warningRange && (canonicalValue < type.warningRange.min || canonicalValue > type.warningRange.max)) {
      return {
        isValid: true,
        isWarning: true,
        reason: `Value ${canonicalValue} ${type.canonicalUnit} is atypical (${type.warningRange.min} - ${type.warningRange.max} ${type.canonicalUnit})`,
      };
    }
    return { isValid: true, isWarning: false };
  }
}
