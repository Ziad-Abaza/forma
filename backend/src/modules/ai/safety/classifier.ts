// Safety Classification and Response Modes (Blueprint §10.6.1, Spec §4.1 G-S1, G-S2)

export type SafetyCategory = 'A' | 'B' | 'C' | 'D';
export type SafetyResponseMode = 'normal' | 'guarded' | 'redirect';

export interface SafetyClassificationResult {
  category: SafetyCategory;
  mode: SafetyResponseMode;
  guardrailsTriggered: string[];
  redirectMessage?: string | undefined;
  redirectMessageAr?: string | undefined;
  detectedLanguage?: 'ar' | 'en';
}

export class SafetyClassifier {
  // English Emergency & Red-Flag Keywords
  private static readonly EMERGENCY_KEYWORDS_EN = [
    'chest pain',
    'chest pressure',
    'fainting',
    'shortness of breath',
    'passed out',
    'blood in vomit',
    'blood in stool',
    'severe dizziness',
    'intense dizziness',
    'vision loss',
    'heart palpitations',
    'sudden severe headache',
    'signs of stroke',
    'difficulty breathing',
    'coughing blood',
    'coughing with blood',
    'loss of consciousness',
    'diet pills',
    'diet pill',
    'overdose',
    'suicide',
    'self harm',
    'kill myself',
    'end my life'
  ];

  // Arabic Emergency & Red-Flag Keywords
  private static readonly EMERGENCY_KEYWORDS_AR = [
    'الم في الصدر',
    'ضغط في الصدر',
    'وجع في الصدر',
    'ضيق تنفس',
    'صعوبة في التنفس',
    'اغماء',
    'فقدان الوعي',
    'تشوش الرؤية',
    'اغمي علي',
    'دم في القيء',
    'دم في الاستفراغ',
    'دم في البراز',
    'دوخة شديدة',
    'دوار شديد',
    'خفقان القلب',
    'خفقان سريع',
    'صداع شديد مفاجئ',
    'اعراض جلطة',
    'سعال مصحوب بدم',
    'حبوب تنحيف',
    'حبوب تخسيس',
    'جرعة زائدة',
    'ايذاء نفسي',
    'انتحار',
    'انهاء حياتي',
    'قتل نفسي'
  ];

  // English Disordered Eating Keywords
  private static readonly DISORDERED_EATING_KEYWORDS_EN = [
    'starve myself',
    'eat only 400 calories',
    'eating 300 calories',
    'eating 400 calories',
    'eating 500 calories',
    'dry fast',
    'purge my food',
    'purge after eating',
    'vomited after every meal',
    'vomit after meals',
    'vomiting after eating',
    'laxatives can i abuse',
    'taking laxatives to lose weight',
    'fasting for 3 weeks',
    'fasting for 2 weeks',
    'lose 10 kg in 3 days',
    'lose 10 kg in a week',
    'chew and spit'
  ];

  // Arabic Disordered Eating Keywords
  private static readonly DISORDERED_EATING_KEYWORDS_AR = [
    'اجوع نفسي',
    'تجويع نفسي',
    '٤٠٠ سعرة حرارية فقط',
    '400 سعرة حرارية فقط',
    'اكل 300 سعرة',
    'اكل 400 سعرة',
    'اكل 500 سعرة',
    'الصيام الجاف',
    'صيام جاف',
    'التقيؤ بعد الافراط',
    'التخلص من الطعام والتقيؤ',
    'تقيات عمدا',
    'اتقيا بعد الاكل',
    'استفرغ بعد الاكل',
    'التقيو بعد الاكل',
    'صيام لمدة 3 اسابيع',
    'صيام لمدة اسبوعين',
    'انقاص 10 كغ في 3 ايام',
    'خسارة 10 كغ في اسبوع',
    'ملينات لتخفيف الوزن',
    'الملينات التي يمكنني تناولها بكثرة',
    'مدرات للبول للتخسيس',
    'لا اكل شيئا'
  ];

  public static readonly REDIRECT_MESSAGE_EN =
    'Your safety and health are paramount. The symptoms or behaviors you described require immediate evaluation by a licensed healthcare professional or emergency medical services. Forma is an informational companion and does not provide medical treatment or diagnose conditions.';

  public static readonly REDIRECT_MESSAGE_AR =
    'سلامتك وصحتك هما أولويتنا القصوى. تتطلب الأعراض أو السلوكيات التي ذكرتها تقييماً فورياً من قِبل أخصائي رعاية صحية مرخص أو خدمات الطوارئ الطبية. تطبيق Forma رفيق معلوماتي ولا يقدم علاجاً طبياً أو تشخيصاً للحالات.';

  /**
   * Normalizes Arabic text by removing tashkeel (diacritics), tatweel,
   * unifying alefs, ya/alef maqsura, and teh marbuta.
   */
  public static normalizeArabic(text: string): string {
    return text
      // Normalize tanween fath on alef (اً or اً) before stripping diacritics
      // e.g. دماً -> دم
      .replace(/اً/g, '')
      // Remove diacritics (tashkeel: fathah, dammah, kasrah, sukun, shaddah, tanween)
      .replace(/[\u064B-\u065F\u0670]/g, '')
      // Remove tatweel (kashida)
      .replace(/\u0640/g, '')
      // Normalize alef variants (أ, إ, آ, ٱ) -> ا
      .replace(/[أإآٱ]/g, 'ا')
      // Normalize alef maqsura (ى) -> ي
      .replace(/ى/g, 'ي')
      // Normalize teh marbuta (ة) -> ه
      .replace(/ة/g, 'ه')
      // Normalize hamza on waw / ya (ؤ, ئ) -> ء
      .replace(/[ؤئ]/g, 'ء')
      // Normalize Arabic comma, question mark, semicolon to spaces
      .replace(/[،؛؟]/g, ' ');
  }

  /**
   * Normalizes text for keyword matching:
   * lowercases, normalizes Arabic, strips punctuation, collapses whitespace.
   */
  public static normalizeText(text: string): string {
    const lower = text.toLowerCase();
    const normalizedArabic = this.normalizeArabic(lower);
    // Strip common punctuation (keep Arabic/Latin letters, digits, whitespace)
    const stripped = normalizedArabic.replace(/[!?,.:;'"/\\()\[\]{}_-]/g, ' ');
    // Collapse whitespace
    return stripped.replace(/\s+/g, ' ').trim();
  }

  /**
   * Detects whether Arabic characters represent a significant portion (>25%) of the text.
   */
  public static isArabic(text: string): boolean {
    const arabicChars = text.match(/[\u0600-\u06FF]/g) || [];
    const totalLetters = text.match(/[\p{L}]/gu) || [];
    if (totalLetters.length === 0) return false;
    return arabicChars.length / totalLetters.length >= 0.25;
  }

  public static classify(userPrompt: string): SafetyClassificationResult {
    const rawLower = userPrompt.toLowerCase();
    const normalized = this.normalizeText(userPrompt);
    const guardrailsTriggered: string[] = [];
    const detectedLang: 'ar' | 'en' = this.isArabic(userPrompt) ? 'ar' : 'en';

    // 1. Check Category D: English Emergency Keywords
    for (const kw of this.EMERGENCY_KEYWORDS_EN) {
      if (rawLower.includes(kw) || normalized.includes(kw)) {
        guardrailsTriggered.push(`acute_symptom_${kw.replace(/\s+/g, '_')}`);
      }
    }

    // 2. Check Category D: Arabic Emergency Keywords
    for (const kw of this.EMERGENCY_KEYWORDS_AR) {
      const normKw = this.normalizeText(kw);
      if (normalized.includes(normKw)) {
        guardrailsTriggered.push(`acute_symptom_${normKw.replace(/\s+/g, '_')}`);
      }
    }

    // 3. Check Category D: English Disordered Eating Keywords
    for (const kw of this.DISORDERED_EATING_KEYWORDS_EN) {
      if (rawLower.includes(kw) || normalized.includes(kw)) {
        guardrailsTriggered.push(`disordered_eating_${kw.replace(/\s+/g, '_')}`);
      }
    }

    // 4. Check Category D: Arabic Disordered Eating Keywords
    for (const kw of this.DISORDERED_EATING_KEYWORDS_AR) {
      const normKw = this.normalizeText(kw);
      if (normalized.includes(normKw)) {
        guardrailsTriggered.push(`disordered_eating_${normKw.replace(/\s+/g, '_')}`);
      }
    }

    if (guardrailsTriggered.length > 0) {
      const redirect = detectedLang === 'ar' ? this.REDIRECT_MESSAGE_AR : this.REDIRECT_MESSAGE_EN;
      return {
        category: 'D',
        mode: 'redirect',
        guardrailsTriggered,
        redirectMessage: redirect,
        redirectMessageAr: this.REDIRECT_MESSAGE_AR,
        detectedLanguage: detectedLang
      };
    }

    // Category C: General Education
    if (
      rawLower.startsWith('what is') ||
      rawLower.startsWith('explain') ||
      rawLower.includes('definition') ||
      normalized.startsWith('ما هو') ||
      normalized.startsWith('ما هي') ||
      normalized.startsWith('اشرح') ||
      normalized.startsWith('فسر')
    ) {
      if (
        !rawLower.includes('my') &&
        !rawLower.includes('i ') &&
        !rawLower.includes('me ') &&
        !normalized.includes('لي') &&
        !normalized.includes('وزني') &&
        !normalized.includes('بياناتي')
      ) {
        return {
          category: 'C',
          mode: 'normal',
          guardrailsTriggered: [],
          detectedLanguage: detectedLang
        };
      }
    }

    // Category B: Nutrition & Metabolic Guidance
    if (
      rawLower.includes('calorie') ||
      rawLower.includes('protein') ||
      rawLower.includes('carb') ||
      rawLower.includes('macro') ||
      rawLower.includes('diet') ||
      rawLower.includes('food') ||
      rawLower.includes('bmr') ||
      rawLower.includes('tdee') ||
      normalized.includes('سعره') ||
      normalized.includes('سعرات') ||
      normalized.includes('بروتين') ||
      normalized.includes('غذاء') ||
      normalized.includes('اكل') ||
      normalized.includes('وجبه')
    ) {
      return {
        category: 'B',
        mode: 'normal',
        guardrailsTriggered: [],
        detectedLanguage: detectedLang
      };
    }

    // Category A: Wellness/Fitness Guidance
    return {
      category: 'A',
      mode: 'normal',
      guardrailsTriggered: [],
      detectedLanguage: detectedLang
    };
  }
}
