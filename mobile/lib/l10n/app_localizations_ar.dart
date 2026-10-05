// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'فورما';

  @override
  String get tagline => 'رفيقك الذكي للصحة واللياقة البدنية';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get dateOfBirth => 'تاريخ الميلاد';

  @override
  String get height => 'الطول';

  @override
  String get weight => 'الوزن';

  @override
  String get bodyFat => 'نسبة الدهون';

  @override
  String get measured => 'مقاس';

  @override
  String get calculated => 'محسوب';

  @override
  String get estimated => 'تقديري';

  @override
  String get asserted => 'مصرّح به';

  @override
  String get ageGateError => 'يجب ألا يقل عمرك عن ١٨ عامًا لاستخدام فورما.';

  @override
  String get termsConsent => 'أوافق على شروط الخدمة وسياسة الخصوصية.';

  @override
  String get healthConsent =>
      'أوافق على معالجة بياناتي الصحية الشخصية بشكل آمن.';

  @override
  String get aiConsent =>
      'أوافق على معالجة الذكاء الاصطناعي الخارجية لتحليل اللياقة.';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get healthRecords => 'السجلات الصحية';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get emptyMeasurementsTitle => 'لا توجد قياسات بعد';

  @override
  String get emptyMeasurementsDescription =>
      'سجّل قياسك الأول لبدء متابعة تقدمك الصحي بدقة.';

  @override
  String get addMeasurement => 'إضافة قياس';

  @override
  String get value => 'القيمة';

  @override
  String get unit => 'الوحدة';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get supersede => 'تصحيح القياس';

  @override
  String get voidRecord => 'إلغاء السجل';

  @override
  String get history => 'السجل الزمني';

  @override
  String get active => 'نشط';

  @override
  String get superseded => 'مستبدل';

  @override
  String get voided => 'ملغى';

  @override
  String get primaryGoal => 'الهدف الأساسي';

  @override
  String get goalWeightLoss => 'إنقاص الوزن';

  @override
  String get goalMuscleGain => 'بناء العضلات';

  @override
  String get goalMaintenance => 'المحافظة على الوزن';

  @override
  String get goalGeneralFitness => 'اللياقة العامة';

  @override
  String get startingValue => 'البداية';

  @override
  String get currentValue => 'الحالي';

  @override
  String get targetValue => 'المستهدف';

  @override
  String get progress => 'التقدم';

  @override
  String get projectedTimeline => 'الموعد المتوقع للإنجاز';

  @override
  String get safeRate => 'معدل أسبوعي آمن';

  @override
  String get rateWarning => 'المعدل الأسبوعي يتجاوز التوصيات الإكلينيكية';

  @override
  String get energyTargets => 'أهداف الطاقة والتغذية';

  @override
  String get maintenanceCalories => 'سعرات الثبات';

  @override
  String get targetCalories => 'المستهدف اليومي';

  @override
  String get calorieFloorApplied =>
      'تم تطبيق الحد الأدنى للسعرات حفاظاً على الأمان الصحي';

  @override
  String get specialPopulationNotice =>
      'تم إيقاف حساب الأهداف حفاظاً على السلامة الصحية (يرجى استشارة طبيب)';

  @override
  String get protein => 'بروتين';

  @override
  String get fats => 'دهون';

  @override
  String get carbs => 'كربوهيدرات';

  @override
  String get trends => 'المسار والاتجاهات';

  @override
  String get sevenDayAverage => 'المعدل المهدأ (٧ أيام)';

  @override
  String get weeklyRate => 'المعدل الأسبوعي';

  @override
  String get period7d => '٧ أيام';

  @override
  String get period30d => '٣٠ يوماً';

  @override
  String get period90d => '٩٠ يوماً';

  @override
  String get period1y => 'سنة';

  @override
  String get insufficientTrendData =>
      'يلزم ٣ قياسات على الأقل عبر ٤ أيام لاحتساب معدل المسار.';

  @override
  String get anomalyTitle => 'تنبيه بخصوص القياس';

  @override
  String get anomalyJump => 'تم رصد تغير غير معتاد في الوزن خلال ٢٤ ساعة.';

  @override
  String get anomalyUnit =>
      'اشتباه في خطأ بالوحدة (باوند مقابل كجم). يرجى المراجعة.';

  @override
  String get assistantTitle => 'مساعد Forma';

  @override
  String get assistantSubtitle => 'مساعدك الصحي الموثق بالأدلة';

  @override
  String get chatInputPlaceholder => 'اسأل عن صحتك أو سجل وزنك...';

  @override
  String get send => 'إرسال';

  @override
  String get actionProposed => 'إجراء مقترح';

  @override
  String get confirmAction => 'تأكيد';

  @override
  String get declineAction => 'رفض';

  @override
  String get actionConfirmed => 'تم التأكيد والتنفيذ';

  @override
  String get actionDeclined => 'تم الرفض';

  @override
  String get actionExpired => 'منتهي الصلاحية';

  @override
  String get evidenceBadgeRetrieved => 'مسترجع';

  @override
  String get evidenceBadgeCalculated => 'محسوب';

  @override
  String get evidenceBadgeEstimated => 'تقديري';

  @override
  String get evidenceBadgeInferred => 'مستنتج';

  @override
  String get evidenceBadgeRecommended => 'موصى به';

  @override
  String get safetyEmergencyTitle => 'تنبيه صحي وأمان';

  @override
  String actionReceiptId(String id) {
    return 'معرف الإيصال: $id';
  }

  @override
  String get multimodalReviewTitle => 'مراجعة البيانات المستخرجة';

  @override
  String get adaptiveAttentionWarning =>
      'بعض الحقول تتطلب انتباهك بسبب انخفاض دقة القراءة أو القيم.';

  @override
  String get deleteSourceImage =>
      'حذف الصورة الأصلية بعد الحفظ (موصى به للخصوصية)';

  @override
  String get commitToHealthRecord => 'حفظ في السجل الصحي';

  @override
  String get unrecognizedFields => 'تم استبعاد الحقول غير المعروفة';

  @override
  String get fieldRequiresAttention => 'يتطلب الانتباه';

  @override
  String fieldConfidence(int score) {
    return 'مستوى الدقة: $score٪';
  }

  @override
  String get discardDraft => 'تجاهل المسودة';

  @override
  String get editField => 'تعديل القيمة';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get noFieldsToCommit => 'لم يتم تحديد أي حقول للحفظ';

  @override
  String get extractedMetricsTitle => 'المؤشرات المستخرجة';

  @override
  String get exportUserData => 'تصدير البيانات الصحية (GDPR)';

  @override
  String get purgeAccount => 'حذف الحساب ومسح البيانات';

  @override
  String get purgeConfirmation =>
      'هل أنت متأكد؟ سيؤدي هذا إلى حذف كافة بياناتك الصحية نهائياً من جميع الخدمات.';

  @override
  String get signInSubtitle =>
      'سجل الدخول للوصول إلى بياناتك الصحية ومساعدك الذكي';

  @override
  String get dontHaveAccount => 'ليس لديك حساب؟ إنشاء حساب جديد';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟ تسجيل الدخول';

  @override
  String get fillAllFields => 'يرجى ملء جميع الحقول المطلوبة.';

  @override
  String get invalidEmail => 'يرجى إدخال بريد إلكتروني صالح.';

  @override
  String get passwordTooShort =>
      'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get sexMale => 'ذكر';

  @override
  String get sexFemale => 'أنثى';

  @override
  String get sexUnspecified => 'غير محدد';

  @override
  String get loading => 'جاري التحميل...';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get errorOccurred => 'حدث خطأ';

  @override
  String get noMeasurementTypesAvailable =>
      'لا توجد أنواع قياسات متاحة حالياً.';

  @override
  String get dataQuality => 'جودة البيانات';

  @override
  String get observationsLabel => 'القياسات';

  @override
  String get measuredShare => 'نسبة القياسات الفعلية';

  @override
  String get staleness => 'عمر البيانات';

  @override
  String get noAnomaliesDetected => 'لم يتم رصد أي شذوذ في سجلاتك.';

  @override
  String get pendingReviews => 'مراجعات معلقة';

  @override
  String get noPendingDrafts => 'لا توجد استخراجات تقارير بانتظار المراجعة.';

  @override
  String get reviewAction => 'مراجعة';

  @override
  String get goalHistory => 'سجل الهدف';

  @override
  String get noGoalVersions => 'لا توجد نسخ للهدف بعد.';

  @override
  String get profileHistory => 'سجل الملف الشخصي';

  @override
  String get noProfileChanges => 'لم يتم تسجيل أي تغييرات بعد.';

  @override
  String get invalidDobFormat => 'استخدم التنسيق YYYY-MM-DD';

  @override
  String get invalidDobAge => 'يجب أن يكون تاريخ ميلاد صالحاً لشخص بالغ';

  @override
  String get trainingExperience => 'خبرة التدريب';

  @override
  String get experienceBeginner => 'مبتدئ';

  @override
  String get experienceIntermediate => 'متوسط';

  @override
  String get experienceAdvanced => 'متقدم';

  @override
  String get addConstraintHint => 'أضف قيداً (مثل: إصابة ركبة)';

  @override
  String get physicalActivityLevel => 'مستوى النشاط البدني';

  @override
  String get calculationParams => 'معاملات الحساب';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get heightCmLabel => 'الطول (سم)';

  @override
  String get heightValidation => 'أدخل طولاً صحيحاً بين 80 و 250 سم';

  @override
  String get activitySedentary => 'خامل (قليل/بدون تمارين)';

  @override
  String get activityLightly => 'نشاط خفيف (1-3 أيام/أسبوع)';

  @override
  String get activityModerately => 'نشاط متوسط (3-5 أيام/أسبوع)';

  @override
  String get activityVery => 'نشاط عالٍ (6-7 أيام/أسبوع)';

  @override
  String get activityExtra => 'نشاط مكثف (تدريب شاق)';

  @override
  String get sexForCalculation => 'الجنس (للحسابات الحيوية)';

  @override
  String get exportData => 'تصدير البيانات';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String get deleteAccountConfirm =>
      'هل أنت متأكد من رغبتك في حذف الحساب نهائياً؟ سيتم مسح كافة قياساتك وسجلاتك وذاكرة المساعد فوراً وبشكل لا يمكن التراجع عنه.';

  @override
  String get privacyControls => 'الخصوصية وملكية البيانات';

  @override
  String get privacyControlsDescription =>
      'تحكم في بياناتك الصحية، واستخرج نسخة منها، أو احذف حسابك نهائياً.';

  @override
  String get extractReport => 'استخراج التقرير';

  @override
  String get extractionDialogHint =>
      'التقط أو اختر صورة للتقرير لاستخراج البيانات ومراجعتها تلقائياً.';

  @override
  String get reportType => 'نوع التقرير';

  @override
  String get capturePhoto => 'التقط صورة';

  @override
  String get retakePhoto => 'إعادة الالتقاط';

  @override
  String get chooseFromGallery => 'اختر من المعرض';

  @override
  String get imageReady => 'الصورة جاهزة — اضغط استخراج للتحليل';

  @override
  String get imageCaptureFailed =>
      'تعذر فتح الكاميرا أو المعرض. تحقق من الأذونات وحاول مجدداً.';

  @override
  String get provenanceTitle => 'مصدر وموثوقية البيانات';

  @override
  String get invalidDateFormat => 'صيغة التاريخ: YYYY-MM-DD';

  @override
  String get invalidHeightRange => 'يجب أن يكون الطول بين 80 و 260 سم';

  @override
  String get consentRequired => 'يرجى الموافقة على شروط الخدمة وبيانات الصحة.';

  @override
  String get selectDate => 'اختر التاريخ';

  @override
  String get appLanguageTitle => 'لغة التطبيق';

  @override
  String get digitsTitle => 'الأرقام';

  @override
  String get digitsWestern => 'الأرقام الغربية (1، 2، 3)';

  @override
  String get digitsEasternArabic => 'الأرقام العربية الشرقية (١، ٢، ٣)';

  @override
  String get healthProfileSubtitle =>
      'الطول، العمر، الجنس البيولوجي، مستوى النشاط';

  @override
  String get aiProviderConfigTitle => 'المساعد الذكي وإعدادات المزود';

  @override
  String get aiProviderConfigDescription =>
      'قم بإعداد نماذج النظام أو أحضر مفتاح API الخاص بك (BYOK) المحفوظ بتشفير كتابة فقط على جهازك.';

  @override
  String aiConfigLoadError(Object error) {
    return 'تعذر تحميل إعدادات الذكاء الاصطناعي: $error';
  }

  @override
  String get activeAiProvider => 'مزود الذكاء الاصطناعي النشط';

  @override
  String get storedCredentialsTitle => 'بيانات اعتماد المزود المخزنة (مشفرة):';

  @override
  String credentialFingerprint(Object fingerprint) {
    return 'البصمة: $fingerprint (AES-256-GCM)';
  }

  @override
  String enterCustomApiKey(Object provider) {
    return 'أدخل مفتاح API المخصص لـ $provider';
  }

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get saveKey => 'حفظ المفتاح';

  @override
  String connectionVerified(Object provider) {
    return 'تم التحقق من الاتصال بـ $provider بنجاح';
  }

  @override
  String get connectionFailed => 'فشل اختبار الاتصال';

  @override
  String get apiKeyTooShort =>
      'يجب أن يكون مفتاح API مكوناً من 8 أحرف على الأقل';

  @override
  String apiKeySaved(Object provider) {
    return 'تم تشفير مفتاح API وتخزينه بأمان لـ $provider';
  }

  @override
  String credentialRevoked(Object provider) {
    return 'تم إلغاء بيانات اعتماد $provider وحذفها';
  }

  @override
  String get exportJsonCopied => 'تم نسخ بيانات JSON المصدرة إلى الحافظة';

  @override
  String get copyJson => 'نسخ JSON';

  @override
  String get close => 'إغلاق';

  @override
  String exportFailed(Object error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get exportSubtitle => 'تنسيق JSON محمول قابل للقراءة آلياً';

  @override
  String get purgeAccountSubtitle =>
      'يمسح جميع السجلات الشخصية والنماذج والوسائط بشكل لا رجعة فيه';

  @override
  String purgeFailed(Object error) {
    return 'فشل حذف الحساب: $error';
  }

  @override
  String get signedInAs => 'تم تسجيل الدخول باسم';

  @override
  String get assistantStatusOnline => 'متصل';

  @override
  String get assistantStatusThinking => 'جارٍ قراءة بياناتك…';

  @override
  String get assistantStatusCalculating => 'جارٍ التحقق من الأرقام…';

  @override
  String get assistantStatusGenerating => 'Forma يكتب الرد…';

  @override
  String get assistantGreeting =>
      'مرحباً! أنا Forma، رفيقك الصحي والشخصي. يمكنني مساعدتك في الإجابة عن أسئلة اللياقة، ومتابعة تقدمك، أو إعداد إجراءات لتسجيل القياسات وتحديث الأهداف.';

  @override
  String get newChat => 'محادثة جديدة';

  @override
  String get jumpToLatest => 'رد جديد';

  @override
  String get confirmingAction => 'جارٍ التأكيد…';

  @override
  String get actionExecuted => 'تم التسجيل بنجاح';

  @override
  String get actionPending => 'في انتظار التأكيد';

  @override
  String get sourcesTitle => 'المصادر';

  @override
  String sourcesCount(Object count) {
    return 'المصادر ($count)';
  }

  @override
  String get messageInputPlaceholder => 'اكتب رسالة لـ Forma…';

  @override
  String get messageTooLongHint => 'الرسالة طويلة جداً — اختصرها إلى 2000 حرف.';

  @override
  String get stopGeneration => 'إيقاف';

  @override
  String get copy => 'نسخ';

  @override
  String get copiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get errorS01Offline =>
      'أنت غير متصل بالإنترنت. يرجى التحقق من اتصالك.';

  @override
  String get errorS02Provider =>
      'تعذر الاتصال بخدمة الذكاء الاصطناعي. بياناتك بأمان.';

  @override
  String get errorS03Timeout =>
      'يستغرق الأمر وقتاً أطول من المعتاد. يرجى المحاولة ثانية.';

  @override
  String get errorS04Interrupted => 'انقطع الرد أثناء البث.';

  @override
  String get errorS05RateLimit =>
      'وصلت إلى حد الرسائل مؤقتاً. حاول مجدداً بعد قليل.';

  @override
  String get errorS06Expired => 'انتهت صلاحية المقترح.';

  @override
  String get errorS07Commit => 'فشل تنفيذ الإجراء.';

  @override
  String get errorS08Malformed => 'تعذر تنسيق الاستجابة.';

  @override
  String get bmiTitle => 'مؤشر كتلة الجسم';

  @override
  String get bmiCategoryUnderweight => 'نقص في الوزن';

  @override
  String get bmiCategoryNormal => 'وزن طبيعي';

  @override
  String get bmiCategoryOverweight => 'وزن زائد';

  @override
  String get bmiCategoryObese => 'سمنة';

  @override
  String projectedCompletionDate(String date) {
    return 'الموعد المتوقع: $date';
  }

  @override
  String remainingToTarget(String diff) {
    return 'المتبقي: $diff كجم';
  }

  @override
  String deltaChange(String delta) {
    return 'التغير: $delta كجم';
  }

  @override
  String get weightAndCompositionSection => 'الوزن وتكوين الجسم';

  @override
  String get bodyCircumferencesSection => 'قياسات المحيط والأبعاد';

  @override
  String get allHistory => 'عرض كامل السجل';

  @override
  String get metabolicSummaryTitle => 'ملخص الأيض والطاقة';

  @override
  String get bmrLabel => 'معدل الأيض الأساسي (BMR)';

  @override
  String get tdeeLabel => 'إجمالي استهلاك الطاقة اليومي (TDEE)';

  @override
  String get unknown => 'غير معروف';

  @override
  String get securitySectionTitle => 'الأمان والجلسات';

  @override
  String get securitySectionSubtitle => 'إدارة كلمة المرور والأجهزة المسجلة';

  @override
  String get sessionsListTitle => 'الجلسات المسجلة';

  @override
  String get sessionUnknownDevice => 'جهاز غير معروف';

  @override
  String sessionCreatedLabel(Object date) {
    return 'أُنشئت في $date';
  }

  @override
  String get sessionRevokedBadge => 'ملغاة';

  @override
  String get revokeSession => 'إلغاء الجلسة';

  @override
  String get sessionRevokedSuccess => 'تم إلغاء الجلسة';

  @override
  String sessionActionFailed(Object error) {
    return 'فشل إجراء الجلسة: $error';
  }

  @override
  String get signOutAllDevices => 'تسجيل الخروج من جميع الأجهزة';

  @override
  String get signOutAllConfirmTitle => 'تسجيل الخروج من كل مكان؟';

  @override
  String get signOutAllConfirmBody =>
      'سيتم تسجيل الخروج من جميع الجلسات على كل الأجهزة — بما في ذلك هذا الجهاز.';

  @override
  String get signOutAllSuccess => 'تم تسجيل الخروج من جميع الأجهزة';

  @override
  String get sessionsEmpty => 'لا توجد جلسات';

  @override
  String sessionsLoadError(Object error) {
    return 'تعذر تحميل الجلسات: $error';
  }

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get changePasswordSubtitle =>
      'حدّث كلمة المرور — سيتم تسجيل خروجك من جميع الأجهزة';

  @override
  String get currentPasswordLabel => 'كلمة المرور الحالية';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String changePasswordFailed(Object error) {
    return 'فشل تغيير كلمة المرور: $error';
  }

  @override
  String get changePasswordSuccessFallback =>
      'تم تحديث كلمة المرور. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get consentsTitle => 'الموافقات والخصوصية';

  @override
  String get consentsSubtitle => 'راجع وأدر الموافقات المرتبطة بحسابك';

  @override
  String get consentPolicyTermsOfService => 'شروط الخدمة';

  @override
  String get consentPolicyHealthData => 'معالجة البيانات الصحية';

  @override
  String get consentPolicyAiThirdParty => 'معالجة الذكاء الاصطناعي الخارجية';

  @override
  String consentGrantedOn(Object date) {
    return 'مُنحت في $date';
  }

  @override
  String consentWithdrawnOn(Object date) {
    return 'سُحبت في $date';
  }

  @override
  String consentVersionLabel(Object version) {
    return 'الإصدار $version';
  }

  @override
  String get consentWithdrawButton => 'سحب الموافقة';

  @override
  String get consentWithdrawConfirm =>
      'سحب الموافقة على معالجة الذكاء الاصطناعي الخارجية؟ ستتوقف الميزات المعتمدة على الذكاء الاصطناعي.';

  @override
  String get consentWithdrawnSuccess => 'تم سحب الموافقة';

  @override
  String consentWithdrawFailed(Object error) {
    return 'فشل سحب الموافقة: $error';
  }

  @override
  String get consentRequiresDeletion =>
      'لا يمكن سحب هذه الموافقة إلا بحذف حسابك.';

  @override
  String get consentsEmpty => 'لا توجد سجلات موافقة';

  @override
  String consentsLoadError(Object error) {
    return 'تعذر تحميل الموافقات: $error';
  }

  @override
  String get aiModelLabel => 'نموذج الذكاء الاصطناعي المفضل';

  @override
  String get aiModelUpdated => 'تم حفظ تفضيل النموذج';

  @override
  String aiModelUpdateFailed(Object error) {
    return 'فشل حفظ تفضيل النموذج: $error';
  }

  @override
  String get conversationsTitle => 'المحادثات';

  @override
  String get conversationsEmpty => 'لا توجد محادثات سابقة بعد.';

  @override
  String get untitledConversation => 'محادثة بدون عنوان';

  @override
  String get conversationLoadFailed => 'تعذر تحميل هذه المحادثة.';

  @override
  String get delete => 'حذف';

  @override
  String get deleteConversationConfirm =>
      'هل تريد حذف هذه المحادثة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteFailed => 'فشل الحذف. يرجى المحاولة مرة أخرى.';

  @override
  String get memoriesTitle => 'ذاكرة المساعد';

  @override
  String get memoriesEmpty =>
      'لا توجد ذكريات بعد. يحتفظ Forma بالتفضيلات والحقائق والروتين والقيود الدائمة هنا.';

  @override
  String get addMemory => 'إضافة ذاكرة';

  @override
  String get memoryCategory => 'الفئة';

  @override
  String get memoryKey => 'المفتاح';

  @override
  String get memoryKeyHint => 'مثال: preferred_units';

  @override
  String get memoryValueHint => 'مثال: kilograms';

  @override
  String get memoryCategoryPreference => 'تفضيل';

  @override
  String get memoryCategoryFact => 'حقيقة';

  @override
  String get memoryCategoryRoutine => 'روتين';

  @override
  String get memoryCategoryConstraint => 'قيد';

  @override
  String get deleteMemoryConfirm => 'هل تريد حذف هذه الذاكرة؟';

  @override
  String get memorySaved => 'تم حفظ الذاكرة';

  @override
  String memorySaveFailed(String error) {
    return 'تعذر حفظ الذاكرة: $error';
  }

  @override
  String get ok => 'حسنًا';

  @override
  String get done => 'تم';

  @override
  String get setPrimaryGoal => 'تعيين الهدف الأساسي';

  @override
  String get managePrimaryGoal => 'إدارة الهدف الأساسي';

  @override
  String get measurementRecorded => 'تم تسجيل القياس بنجاح';

  @override
  String get measurementCorrected => 'تم تصحيح القياس بنجاح';

  @override
  String correctionFailed(String error) {
    return 'فشل التصحيح: $error';
  }

  @override
  String get observationVoided => 'تم إبطال السجل بنجاح';

  @override
  String voidFailed(String error) {
    return 'فشل الإبطال: $error';
  }

  @override
  String metricLabel(String code) {
    return 'المقياس: $code';
  }

  @override
  String canonicalValueLabel(String value, String unit) {
    return 'القيمة القياسية: $value $unit';
  }

  @override
  String epistemicClassLabel(String cls) {
    return 'الفئة المعرفية: $cls';
  }

  @override
  String observedAtLabel(String ts) {
    return 'وقت الملاحظة: $ts';
  }

  @override
  String observationIdLabel(String id) {
    return 'معرّف السجل: $id...';
  }

  @override
  String originTypeLabel(String v) {
    return 'نوع المصدر: $v';
  }

  @override
  String get docTypeBodyComposition => 'تقرير تكوين الجسم (InBody)';

  @override
  String get docTypeScaleDisplay => 'شاشة الميزان الذكي';

  @override
  String get docTypeTapeSheet => 'ورقة قياسات المحيطات';

  @override
  String extractionFailedMsg(String error) {
    return 'فشل الاستخراج: $error';
  }

  @override
  String get goalCreated => 'تم إنشاء الهدف بنجاح';

  @override
  String get activeGoalNotFound => 'لم يتم العثور على الهدف النشط';

  @override
  String get goalAdjustTarget => 'تعديل الهدف / إصدار جديد';

  @override
  String get goalMarkCompleted => 'وضع علامة مكتمل';

  @override
  String get goalArchive => 'أرشفة الهدف';

  @override
  String get goalUpdated => 'تم تحديث الهدف بنجاح';

  @override
  String goalUpdateFailed(String error) {
    return 'فشل تحديث الهدف: $error';
  }

  @override
  String get signOutConfirmBody =>
      'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟';

  @override
  String get appendOnlyNote =>
      'سلامة السجل الإلحاقي: لتصحيح إدخال خاطئ، أبطل هذه الملاحظة.';

  @override
  String get action => 'الإجراء';
}
