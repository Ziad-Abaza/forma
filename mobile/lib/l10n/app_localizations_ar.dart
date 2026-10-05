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
}
