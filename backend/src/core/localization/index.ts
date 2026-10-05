export type SupportedLocale = 'en' | 'ar';
export type NumeralSystem = 'western' | 'eastern_arabic';
export type TextDirection = 'ltr' | 'rtl';

export interface LocaleConfig {
  locale: SupportedLocale;
  direction: TextDirection;
  nameEn: string;
  nameAr: string;
}

export const SUPPORTED_LOCALES: Record<SupportedLocale, LocaleConfig> = {
  en: {
    locale: 'en',
    direction: 'ltr',
    nameEn: 'English',
    nameAr: 'الإنجليزية'
  },
  ar: {
    locale: 'ar',
    direction: 'rtl',
    nameEn: 'Arabic',
    nameAr: 'العربية'
  }
};

const ARABIC_INDIC_DIGITS = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/**
 * Formats a number according to the user's preferred numeral system.
 */
export function formatNumeral(value: number | string, system: NumeralSystem): string {
  const str = value.toString();
  if (system === 'western') return str;

  return str.replace(/\d/g, (d) => ARABIC_INDIC_DIGITS[parseInt(d, 10)] || d);
}

// Measurement catalog translation dictionary (codes -> localized labels)
export const MEASUREMENT_TYPE_TRANSLATIONS: Record<string, { en: string; ar: string }> = {
  weight: { en: 'Weight', ar: 'الوزن' },
  body_fat_percentage: { en: 'Body Fat Percentage', ar: 'نسبة الدهون' },
  muscle_mass: { en: 'Muscle Mass', ar: 'الكتلة العضلية' },
  body_water_percentage: { en: 'Body Water Percentage', ar: 'نسبة الماء' },
  visceral_fat: { en: 'Visceral Fat', ar: 'الدهون الحشوية' },
  bone_mass: { en: 'Bone Mass', ar: 'كتلة العظام' },
  waist_circumference: { en: 'Waist Circumference', ar: 'محيط الخصر' },
  hip_circumference: { en: 'Hip Circumference', ar: 'محيط الورك' },
  chest_circumference: { en: 'Chest Circumference', ar: 'محيط الصدر' },
  neck_circumference: { en: 'Neck Circumference', ar: 'محيط الرقبة' },
  thigh_circumference: { en: 'Thigh Circumference', ar: 'محيط الفخذ' },
  bicep_circumference: { en: 'Bicep Circumference', ar: 'محيط العضلة ذات الرأسين' },
  height: { en: 'Height', ar: 'الطول' },
  bmi: { en: 'Body Mass Index (BMI)', ar: 'مؤشر كتلة الجسم' }
};

export function getLocalizedMeasurementLabel(code: string, locale: SupportedLocale): string {
  const translation = MEASUREMENT_TYPE_TRANSLATIONS[code];
  if (!translation) return code;
  return translation[locale] || translation.en;
}
