// Response Formatter and Guardrail Linter (Spec §2.2, §4.2, §4.3, §4.4)

export interface FormattingResult {
  formattedText: string;
  formatViolations: number;
  languageMismatch: boolean;
}

export class ResponseFormatter {
  // Banned filler phrases (Spec §2.5)
  private static readonly BANNED_FILLERS_START = [
    /^(\*?\*?great question\*?\*?[.!,:]*\s*)/i,
    /^(\*?\*?certainly\*?\*?[.!,:]*\s*)/i,
    /^(\*?\*?sure thing\*?\*?[.!,:]*\s*)/i,
    /^(\*?\*?as an ai\*?\*?[.!,:]*\s*)/i,
    /^(\*?\*?سؤال رائع\*?\*?[.!,؛:]*\s*)/i,
    /^(\*?\*?بالتأكيد\*?\*?[.!,؛:]*\s*)/i,
    /^(\*?\*?بصفتي ذكاءً? اصطناعياً?\*?\*?[.!,؛:]*\s*)/i
  ];

  private static readonly BANNED_FILLERS_END = [
    /(\s*i hope this helps[.!]?)$/i,
    /(\s*feel free to ask[.!]?)$/i,
    /(\s*let me know if you have any questions[.!]?)$/i,
    /(\s*أتمنى أن يكون هذا مفيداً[.!]?)$/i,
    /(\s*لا تتردد في السؤال[.!]?)$/i
  ];

  /**
   * Sanitizes, lints, and formats the generated AI response text.
   * Enforces headers, fences, blank lines, false success claims (G-A3), and prompt leakage (G-P2).
   */
  public static format(
    rawText: string,
    hasReceiptThisTurn: boolean = false,
    expectedLanguage: 'ar' | 'en' = 'en'
  ): FormattingResult {
    let text = rawText;
    let formatViolations = 0;

    // 1. G-P2: System Prompt Leakage Defense
    // If output contains leaked internal tags, sanitize immediately
    if (
      /<identity>|<out_of_scope>|<action_context>|<response_format>|<structured_blocks>/i.test(
        text
      )
    ) {
      formatViolations += 5;
      const refusal =
        expectedLanguage === 'ar'
          ? 'لا يمكنني مشاركة إعداداتي الداخلية أو تعليمات النظام، ولكن يمكنني مساعدتك في تمارينك أو تغذيتك.'
          : "I cannot share my internal setup or system instructions, but I'm here to help with your training and nutrition.";
      return {
        formattedText: refusal,
        formatViolations,
        languageMismatch: false
      };
    }

    // 2. G-A3: False success claim prevention
    // If the model claims "saved" or "logged" without an executed receipt this turn, rewrite to "ready for confirmation"
    if (!hasReceiptThisTurn) {
      const enFalseSuccess = /\b(i have (?:logged|saved|recorded)|successfully (?:logged|saved|recorded))\b/gi;
      if (enFalseSuccess.test(text)) {
        formatViolations++;
        text = text.replace(
          enFalseSuccess,
          'I have prepared this proposal for your confirmation'
        );
      }

      const arFalseSuccess = /\b(تم (?:حفظ|تسجيل)|قمت ب(?:حفظ|تسجيل))\b/gi;
      if (arFalseSuccess.test(text)) {
        formatViolations++;
        text = text.replace(arFalseSuccess, 'أعددت هذا الإجراء لتقوم بتأكيده');
      }
    }

    // 3. Header Normalization: Downgrade # and ## to ### (Spec §2.2)
    const headerRegex = /^(#{1,2})\s+(.+)$/gm;
    if (headerRegex.test(text)) {
      formatViolations++;
      text = text.replace(headerRegex, '### $2');
    }

    // 4. Strip unknown fenced code blocks into plain text (Spec §2.2)
    // Keep only forma:metrics, forma:suggestions (or if already extracted)
    const codeBlockRegex = /```(?!forma:)[a-zA-Z0-9_-]*\n([\s\S]*?)```/g;
    if (codeBlockRegex.test(text)) {
      formatViolations++;
      text = text.replace(codeBlockRegex, '$1');
    }

    // 5. Remove banned filler phrases at start
    for (const pattern of this.BANNED_FILLERS_START) {
      if (pattern.test(text)) {
        formatViolations++;
        text = text.replace(pattern, '');
      }
    }

    // 6. Remove banned filler phrases at end
    for (const pattern of this.BANNED_FILLERS_END) {
      if (pattern.test(text)) {
        formatViolations++;
        text = text.replace(pattern, '');
      }
    }

    // 7. Collapse more than 2 consecutive blank lines
    text = text.replace(/\n{3,}/g, '\n\n').trim();

    // 8. G-F5: Language mismatch detection
    const arabicChars = (text.match(/[\u0600-\u06FF]/g) || []).length;
    const totalLetters = (text.match(/[\p{L}]/gu) || []).length;
    const detectedLang = totalLetters > 0 && arabicChars / totalLetters >= 0.25 ? 'ar' : 'en';
    const languageMismatch = totalLetters > 10 && detectedLang !== expectedLanguage;

    return {
      formattedText: text,
      formatViolations,
      languageMismatch
    };
  }
}
