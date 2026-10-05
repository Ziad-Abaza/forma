import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Forma'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Personal Health & Wellness Companion'**
  String get tagline;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @bodyFat.
  ///
  /// In en, this message translates to:
  /// **'Body Fat'**
  String get bodyFat;

  /// No description provided for @measured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get measured;

  /// No description provided for @calculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated'**
  String get calculated;

  /// No description provided for @estimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get estimated;

  /// No description provided for @asserted.
  ///
  /// In en, this message translates to:
  /// **'Asserted'**
  String get asserted;

  /// No description provided for @ageGateError.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 18 years old to use Forma.'**
  String get ageGateError;

  /// No description provided for @termsConsent.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms of Service and Privacy Policy.'**
  String get termsConsent;

  /// No description provided for @healthConsent.
  ///
  /// In en, this message translates to:
  /// **'I consent to the secure processing of my personal health data.'**
  String get healthConsent;

  /// No description provided for @aiConsent.
  ///
  /// In en, this message translates to:
  /// **'I consent to third-party AI processing for wellness analysis.'**
  String get aiConsent;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @healthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health Records'**
  String get healthRecords;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @emptyMeasurementsTitle.
  ///
  /// In en, this message translates to:
  /// **'No measurements yet'**
  String get emptyMeasurementsTitle;

  /// No description provided for @emptyMeasurementsDescription.
  ///
  /// In en, this message translates to:
  /// **'Log your first weight or circumference to begin tracking your progress.'**
  String get emptyMeasurementsDescription;

  /// No description provided for @addMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Add Measurement'**
  String get addMeasurement;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @supersede.
  ///
  /// In en, this message translates to:
  /// **'Correct Entry'**
  String get supersede;

  /// No description provided for @voidRecord.
  ///
  /// In en, this message translates to:
  /// **'Void Record'**
  String get voidRecord;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @superseded.
  ///
  /// In en, this message translates to:
  /// **'Superseded'**
  String get superseded;

  /// No description provided for @voided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get voided;

  /// No description provided for @primaryGoal.
  ///
  /// In en, this message translates to:
  /// **'Primary Goal'**
  String get primaryGoal;

  /// No description provided for @goalWeightLoss.
  ///
  /// In en, this message translates to:
  /// **'Weight Loss'**
  String get goalWeightLoss;

  /// No description provided for @goalMuscleGain.
  ///
  /// In en, this message translates to:
  /// **'Muscle Gain'**
  String get goalMuscleGain;

  /// No description provided for @goalMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Weight Maintenance'**
  String get goalMaintenance;

  /// No description provided for @goalGeneralFitness.
  ///
  /// In en, this message translates to:
  /// **'General Fitness'**
  String get goalGeneralFitness;

  /// No description provided for @startingValue.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get startingValue;

  /// No description provided for @currentValue.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentValue;

  /// No description provided for @targetValue.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get targetValue;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @projectedTimeline.
  ///
  /// In en, this message translates to:
  /// **'Projected Completion'**
  String get projectedTimeline;

  /// No description provided for @safeRate.
  ///
  /// In en, this message translates to:
  /// **'Safe weekly rate'**
  String get safeRate;

  /// No description provided for @rateWarning.
  ///
  /// In en, this message translates to:
  /// **'Weekly rate exceeds clinical guideline'**
  String get rateWarning;

  /// No description provided for @energyTargets.
  ///
  /// In en, this message translates to:
  /// **'Energy & Nutrition Targets'**
  String get energyTargets;

  /// No description provided for @maintenanceCalories.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Calories'**
  String get maintenanceCalories;

  /// No description provided for @targetCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily Target'**
  String get targetCalories;

  /// No description provided for @calorieFloorApplied.
  ///
  /// In en, this message translates to:
  /// **'Clinical safety calorie floor enforced'**
  String get calorieFloorApplied;

  /// No description provided for @specialPopulationNotice.
  ///
  /// In en, this message translates to:
  /// **'Target calculations paused for health safety (consult physician)'**
  String get specialPopulationNotice;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @fats.
  ///
  /// In en, this message translates to:
  /// **'Fats'**
  String get fats;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbohydrates'**
  String get carbs;

  /// No description provided for @trends.
  ///
  /// In en, this message translates to:
  /// **'Trends & Trajectory'**
  String get trends;

  /// No description provided for @sevenDayAverage.
  ///
  /// In en, this message translates to:
  /// **'7-Day Smoothed'**
  String get sevenDayAverage;

  /// No description provided for @weeklyRate.
  ///
  /// In en, this message translates to:
  /// **'Weekly Rate'**
  String get weeklyRate;

  /// No description provided for @period7d.
  ///
  /// In en, this message translates to:
  /// **'7D'**
  String get period7d;

  /// No description provided for @period30d.
  ///
  /// In en, this message translates to:
  /// **'30D'**
  String get period30d;

  /// No description provided for @period90d.
  ///
  /// In en, this message translates to:
  /// **'90D'**
  String get period90d;

  /// No description provided for @period1y.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get period1y;

  /// No description provided for @insufficientTrendData.
  ///
  /// In en, this message translates to:
  /// **'Need at least 3 points across 4+ days for a trend rate.'**
  String get insufficientTrendData;

  /// No description provided for @anomalyTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement Alert'**
  String get anomalyTitle;

  /// No description provided for @anomalyJump.
  ///
  /// In en, this message translates to:
  /// **'Unusual weight change detected within 24 hours.'**
  String get anomalyJump;

  /// No description provided for @anomalyUnit.
  ///
  /// In en, this message translates to:
  /// **'Possible unit confusion (lbs vs kg). Please review.'**
  String get anomalyUnit;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Forma Assistant'**
  String get assistantTitle;

  /// No description provided for @assistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Evidence-grounded wellness companion'**
  String get assistantSubtitle;

  /// No description provided for @chatInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask anything or log weight...'**
  String get chatInputPlaceholder;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @actionProposed.
  ///
  /// In en, this message translates to:
  /// **'Action Proposed'**
  String get actionProposed;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @declineAction.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineAction;

  /// No description provided for @actionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed & Executed'**
  String get actionConfirmed;

  /// No description provided for @actionDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get actionDeclined;

  /// No description provided for @actionExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get actionExpired;

  /// No description provided for @evidenceBadgeRetrieved.
  ///
  /// In en, this message translates to:
  /// **'Retrieved'**
  String get evidenceBadgeRetrieved;

  /// No description provided for @evidenceBadgeCalculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated'**
  String get evidenceBadgeCalculated;

  /// No description provided for @evidenceBadgeEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get evidenceBadgeEstimated;

  /// No description provided for @evidenceBadgeInferred.
  ///
  /// In en, this message translates to:
  /// **'Inferred'**
  String get evidenceBadgeInferred;

  /// No description provided for @evidenceBadgeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get evidenceBadgeRecommended;

  /// No description provided for @safetyEmergencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Health & Safety Notice'**
  String get safetyEmergencyTitle;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New Conversation'**
  String get newChat;

  /// No description provided for @actionReceiptId.
  ///
  /// In en, this message translates to:
  /// **'Receipt ID: {id}'**
  String actionReceiptId(String id);

  /// No description provided for @multimodalReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Extracted Data'**
  String get multimodalReviewTitle;

  /// No description provided for @adaptiveAttentionWarning.
  ///
  /// In en, this message translates to:
  /// **'Some fields need your attention due to low confidence or values.'**
  String get adaptiveAttentionWarning;

  /// No description provided for @deleteSourceImage.
  ///
  /// In en, this message translates to:
  /// **'Delete source image after saving (Privacy Recommended)'**
  String get deleteSourceImage;

  /// No description provided for @commitToHealthRecord.
  ///
  /// In en, this message translates to:
  /// **'Commit to Health Record'**
  String get commitToHealthRecord;

  /// No description provided for @unrecognizedFields.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized fields omitted'**
  String get unrecognizedFields;

  /// No description provided for @fieldRequiresAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get fieldRequiresAttention;

  /// No description provided for @fieldConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {score}%'**
  String fieldConfidence(int score);

  /// No description provided for @discardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard Draft'**
  String get discardDraft;

  /// No description provided for @editField.
  ///
  /// In en, this message translates to:
  /// **'Edit Value'**
  String get editField;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @noFieldsToCommit.
  ///
  /// In en, this message translates to:
  /// **'No fields selected for commit'**
  String get noFieldsToCommit;

  /// No description provided for @extractedMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Extracted Metrics'**
  String get extractedMetricsTitle;

  /// No description provided for @syncScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected Devices & Sync'**
  String get syncScreenTitle;

  /// No description provided for @healthConnect.
  ///
  /// In en, this message translates to:
  /// **'Health Connect'**
  String get healthConnect;

  /// No description provided for @appleHealth.
  ///
  /// In en, this message translates to:
  /// **'Apple Health'**
  String get appleHealth;

  /// No description provided for @garmin.
  ///
  /// In en, this message translates to:
  /// **'Garmin Connect'**
  String get garmin;

  /// No description provided for @withings.
  ///
  /// In en, this message translates to:
  /// **'Withings Health Mate'**
  String get withings;

  /// No description provided for @oura.
  ///
  /// In en, this message translates to:
  /// **'Oura Ring'**
  String get oura;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String lastSynced(String time);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @connectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectedStatus;

  /// No description provided for @disconnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnectedStatus;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @epistemicResolutionHeader.
  ///
  /// In en, this message translates to:
  /// **'Conflict Resolution & Provenance'**
  String get epistemicResolutionHeader;

  /// No description provided for @epistemicResolutionDesc.
  ///
  /// In en, this message translates to:
  /// **'Direct device readings supersede manual assertions deterministically without loss of history.'**
  String get epistemicResolutionDesc;

  /// No description provided for @privacyDataSection.
  ///
  /// In en, this message translates to:
  /// **'Data Privacy & Management'**
  String get privacyDataSection;

  /// No description provided for @exportUserData.
  ///
  /// In en, this message translates to:
  /// **'Export Health Data (GDPR)'**
  String get exportUserData;

  /// No description provided for @purgeAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account & Purge Data'**
  String get purgeAccount;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data export generated successfully.'**
  String get exportSuccess;

  /// No description provided for @purgeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure? This permanently deletes all your health data across all services.'**
  String get purgeConfirmation;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your health data and AI companion'**
  String get signInSubtitle;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log In'**
  String get alreadyHaveAccount;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please complete all required fields.'**
  String get fillAllFields;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get passwordTooShort;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get sexUnspecified;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @sexForCalculation.
  ///
  /// In en, this message translates to:
  /// **'Sex (for calculations)'**
  String get sexForCalculation;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account? All your health observations, goals, AI memory and profile data will be irreversibly purged.'**
  String get deleteAccountConfirm;

  /// No description provided for @privacyControls.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Data Ownership'**
  String get privacyControls;

  /// No description provided for @privacyControlsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage your health data, export machine-readable copies, or purge your account.'**
  String get privacyControlsDescription;

  /// No description provided for @extractReport.
  ///
  /// In en, this message translates to:
  /// **'Extract Report'**
  String get extractReport;

  /// No description provided for @provenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Provenance'**
  String get provenanceTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
