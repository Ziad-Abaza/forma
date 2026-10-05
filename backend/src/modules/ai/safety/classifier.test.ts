import { describe, it, expect } from 'vitest';
import { SafetyClassifier } from './classifier.js';

describe('SafetyClassifier Bilingual Parity & Normalization (Spec §4.1 G-S1, G-S2)', () => {
  describe('English Red-Flags & Disordered Eating', () => {
    it('detects acute symptom: chest pain', () => {
      const res = SafetyClassifier.classify('I have severe chest pain after working out');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
      expect(res.redirectMessage).toContain('Your safety and health are paramount');
    });

    it('detects acute symptom: shortness of breath and fainting', () => {
      const res = SafetyClassifier.classify('I passed out and had shortness of breath');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });

    it('detects disordered eating: extreme restriction', () => {
      const res = SafetyClassifier.classify('I want to starve myself eating 300 calories');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });

    it('detects disordered eating: purge after eating', () => {
      const res = SafetyClassifier.classify('I purge after eating large meals');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });
  });

  describe('Arabic Red-Flags & Disordered Eating Parity', () => {
    it('detects Arabic chest pain: ألم في الصدر', () => {
      const res = SafetyClassifier.classify('أشعر بألم في الصدر وضيق تنفس');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
      expect(res.detectedLanguage).toBe('ar');
      expect(res.redirectMessage).toContain('سلامتك وصحتك هما أولويتنا القصوى');
    });

    it('detects Arabic chest pain with tashkeel (diacritics)', () => {
      const res = SafetyClassifier.classify('أَشْعُرُ بِـ أَلَمٍ فِي الصَّدْرِ');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
      expect(res.detectedLanguage).toBe('ar');
    });

    it('detects Arabic fainting with alef variants and alef maqsura: إغماء / أغمي علي', () => {
      const res = SafetyClassifier.classify('أغمي علي في الصالة الرياضية');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });

    it('detects Arabic blood in vomit: دم في القيء', () => {
      const res = SafetyClassifier.classify('رأيت دماً في القيء اليوم');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });

    it('detects Arabic disordered eating: أجوع نفسي / تجويع نفسي', () => {
      const res = SafetyClassifier.classify('أريد أن أجوّع نفسي حتى أنزل 10 كغ');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
      expect(res.redirectMessage).toContain('سلامتك وصحتك');
    });

    it('detects Arabic disordered eating: أتقيأ بعد الأكل', () => {
      const res = SafetyClassifier.classify('أتقيأ بعد الأكل للتخسيس');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });

    it('detects Arabic 300 calories starvation: آكل 300 سعرة', () => {
      const res = SafetyClassifier.classify('سأكتفي بأن آكل 300 سعرة في اليوم');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });
  });

  describe('Mixed Language and Normalization', () => {
    it('detects mixed Arabic/English emergency', () => {
      const res = SafetyClassifier.classify('عندي chest pain شديد بعد التمرين');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
    });

    it('passes safe nutrition questions to Category B', () => {
      const enRes = SafetyClassifier.classify('How many calories and protein should I eat?');
      expect(enRes.category).toBe('B');

      const arRes = SafetyClassifier.classify('كم سعرة حرارية وبروتين أحتاج في اليوم؟');
      expect(arRes.category).toBe('B');
    });

    it('passes general knowledge questions to Category C', () => {
      const enRes = SafetyClassifier.classify('What is visceral fat?');
      expect(enRes.category).toBe('C');

      const arRes = SafetyClassifier.classify('ما هو مؤشر كتلة الجسم؟');
      expect(arRes.category).toBe('C');
    });

    it('defaults standard fitness advice to Category A', () => {
      const res = SafetyClassifier.classify('Can you help me design a 3-day workout routine?');
      expect(res.category).toBe('A');
    });
  });
});
