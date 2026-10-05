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
  String get assistantTitle => 'مساعد فورما';

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
  String get newChat => 'محادثة جديدة';

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
  String get syncScreenTitle => 'الأجهزة المتصلة والمزامنة';

  @override
  String get healthConnect => 'هيلث كونيكت';

  @override
  String get appleHealth => 'آبل هيلث';

  @override
  String get garmin => 'جارمن كونيكت';

  @override
  String get withings => 'ويذينجز';

  @override
  String get oura => 'أورا رينج';

  @override
  String lastSynced(String time) {
    return 'آخر مزامنة: $time';
  }

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get syncing => 'جاري المزامنة...';

  @override
  String get connectedStatus => 'متصل';

  @override
  String get disconnectedStatus => 'غير متصل';

  @override
  String get connect => 'ربط';

  @override
  String get disconnect => 'إلغاء الربط';

  @override
  String get epistemicResolutionHeader => 'فض التضارب ومصدر البيانات';

  @override
  String get epistemicResolutionDesc =>
      'قراءات الأجهزة المباشرة تتفوق نظامياً على الإدخالات اليدوية دون فقدان السجل التاريخي.';

  @override
  String get privacyDataSection => 'خصوصية البيانات وإدارتها';

  @override
  String get exportUserData => 'تصدير البيانات الصحية (GDPR)';

  @override
  String get purgeAccount => 'حذف الحساب ومسح البيانات';

  @override
  String get exportSuccess => 'تم إنشاء تصدير البيانات بنجاح.';

  @override
  String get purgeConfirmation =>
      'هل أنت متأكد؟ سيؤدي هذا إلى حذف كافة بياناتك الصحية نهائياً من جميع الخدمات.';
}
