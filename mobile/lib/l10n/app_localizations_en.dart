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

  @override
  String get primaryGoal => 'Primary Goal';

  @override
  String get goalWeightLoss => 'Weight Loss';

  @override
  String get goalMuscleGain => 'Muscle Gain';

  @override
  String get goalMaintenance => 'Weight Maintenance';

  @override
  String get goalGeneralFitness => 'General Fitness';

  @override
  String get startingValue => 'Starting';

  @override
  String get currentValue => 'Current';

  @override
  String get targetValue => 'Target';

  @override
  String get progress => 'Progress';

  @override
  String get projectedTimeline => 'Projected Completion';

  @override
  String get safeRate => 'Safe weekly rate';

  @override
  String get rateWarning => 'Weekly rate exceeds clinical guideline';

  @override
  String get energyTargets => 'Energy & Nutrition Targets';

  @override
  String get maintenanceCalories => 'Maintenance Calories';

  @override
  String get targetCalories => 'Daily Target';

  @override
  String get calorieFloorApplied => 'Clinical safety calorie floor enforced';

  @override
  String get specialPopulationNotice =>
      'Target calculations paused for health safety (consult physician)';

  @override
  String get protein => 'Protein';

  @override
  String get fats => 'Fats';

  @override
  String get carbs => 'Carbohydrates';

  @override
  String get trends => 'Trends & Trajectory';

  @override
  String get sevenDayAverage => '7-Day Smoothed';

  @override
  String get weeklyRate => 'Weekly Rate';

  @override
  String get period7d => '7D';

  @override
  String get period30d => '30D';

  @override
  String get period90d => '90D';

  @override
  String get period1y => '1Y';

  @override
  String get insufficientTrendData =>
      'Need at least 3 points across 4+ days for a trend rate.';

  @override
  String get anomalyTitle => 'Measurement Alert';

  @override
  String get anomalyJump => 'Unusual weight change detected within 24 hours.';

  @override
  String get anomalyUnit =>
      'Possible unit confusion (lbs vs kg). Please review.';

  @override
  String get assistantTitle => 'Forma Assistant';

  @override
  String get assistantSubtitle => 'Evidence-grounded wellness companion';

  @override
  String get chatInputPlaceholder => 'Ask anything or log weight...';

  @override
  String get send => 'Send';

  @override
  String get actionProposed => 'Action Proposed';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get declineAction => 'Decline';

  @override
  String get actionConfirmed => 'Confirmed & Executed';

  @override
  String get actionDeclined => 'Declined';

  @override
  String get actionExpired => 'Expired';

  @override
  String get evidenceBadgeRetrieved => 'Retrieved';

  @override
  String get evidenceBadgeCalculated => 'Calculated';

  @override
  String get evidenceBadgeEstimated => 'Estimated';

  @override
  String get evidenceBadgeInferred => 'Inferred';

  @override
  String get evidenceBadgeRecommended => 'Recommended';

  @override
  String get safetyEmergencyTitle => 'Health & Safety Notice';

  @override
  String get newChat => 'New Conversation';

  @override
  String actionReceiptId(String id) {
    return 'Receipt ID: $id';
  }

  @override
  String get multimodalReviewTitle => 'Review Extracted Data';

  @override
  String get adaptiveAttentionWarning =>
      'Some fields need your attention due to low confidence or values.';

  @override
  String get deleteSourceImage =>
      'Delete source image after saving (Privacy Recommended)';

  @override
  String get commitToHealthRecord => 'Commit to Health Record';

  @override
  String get unrecognizedFields => 'Unrecognized fields omitted';

  @override
  String get fieldRequiresAttention => 'Needs Attention';

  @override
  String fieldConfidence(int score) {
    return 'Confidence: $score%';
  }

  @override
  String get discardDraft => 'Discard Draft';

  @override
  String get editField => 'Edit Value';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get noFieldsToCommit => 'No fields selected for commit';

  @override
  String get extractedMetricsTitle => 'Extracted Metrics';

  @override
  String get syncScreenTitle => 'Connected Devices & Sync';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Health';

  @override
  String get garmin => 'Garmin Connect';

  @override
  String get withings => 'Withings Health Mate';

  @override
  String get oura => 'Oura Ring';

  @override
  String lastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncing => 'Syncing...';

  @override
  String get connectedStatus => 'Connected';

  @override
  String get disconnectedStatus => 'Disconnected';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get epistemicResolutionHeader => 'Conflict Resolution & Provenance';

  @override
  String get epistemicResolutionDesc =>
      'Direct device readings supersede manual assertions deterministically without loss of history.';

  @override
  String get privacyDataSection => 'Data Privacy & Management';

  @override
  String get exportUserData => 'Export Health Data (GDPR)';

  @override
  String get purgeAccount => 'Delete Account & Purge Data';

  @override
  String get exportSuccess => 'Data export generated successfully.';

  @override
  String get purgeConfirmation =>
      'Are you sure? This permanently deletes all your health data across all services.';

  @override
  String get signInSubtitle =>
      'Sign in to access your health data and AI companion';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign Up';

  @override
  String get alreadyHaveAccount => 'Already have an account? Log In';

  @override
  String get fillAllFields => 'Please complete all required fields.';

  @override
  String get invalidEmail => 'Please enter a valid email address.';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters.';

  @override
  String get logout => 'Log Out';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexUnspecified => 'Unspecified';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get sexForCalculation => 'Sex (for calculations)';

  @override
  String get exportData => 'Export Data';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirm =>
      'Are you sure you want to permanently delete your account? All your health observations, goals, AI memory and profile data will be irreversibly purged.';

  @override
  String get privacyControls => 'Privacy & Data Ownership';

  @override
  String get privacyControlsDescription =>
      'Manage your health data, export machine-readable copies, or purge your account.';

  @override
  String get extractReport => 'Extract Report';

  @override
  String get provenanceTitle => 'Data Provenance';
}
