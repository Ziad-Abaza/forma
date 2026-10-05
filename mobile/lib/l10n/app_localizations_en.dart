// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Forma';

  @override
  String get tagline => 'AI-Powered Personal Health & Wellness Companion';

  @override
  String get login => 'Log In';

  @override
  String get register => 'Create Account';

  @override
  String get email => 'Email Address';

  @override
  String get password => 'Password';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

  @override
  String get bodyFat => 'Body Fat';

  @override
  String get measured => 'Measured';

  @override
  String get calculated => 'Calculated';

  @override
  String get estimated => 'Estimated';

  @override
  String get asserted => 'Asserted';

  @override
  String get ageGateError => 'You must be at least 18 years old to use Forma.';

  @override
  String get termsConsent =>
      'I accept the Terms of Service and Privacy Policy.';

  @override
  String get healthConsent =>
      'I consent to the secure processing of my personal health data.';

  @override
  String get aiConsent =>
      'I consent to third-party AI processing for wellness analysis.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get healthRecords => 'Health Records';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get emptyMeasurementsTitle => 'No measurements yet';

  @override
  String get emptyMeasurementsDescription =>
      'Log your first weight or circumference to begin tracking your progress.';

  @override
  String get addMeasurement => 'Add Measurement';

  @override
  String get value => 'Value';

  @override
  String get unit => 'Unit';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get supersede => 'Correct Entry';

  @override
  String get voidRecord => 'Void Record';

  @override
  String get history => 'History';

  @override
  String get active => 'Active';

  @override
  String get superseded => 'Superseded';

  @override
  String get voided => 'Voided';
}
