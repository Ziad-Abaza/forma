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
  /// **'New Chat'**
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

  /// No description provided for @extractionDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Capture or select a photo of your report for automated extraction and review.'**
  String get extractionDialogHint;

  /// No description provided for @reportType.
  ///
  /// In en, this message translates to:
  /// **'Report Type'**
  String get reportType;

  /// No description provided for @capturePhoto.
  ///
  /// In en, this message translates to:
  /// **'Capture Photo'**
  String get capturePhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake Photo'**
  String get retakePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// No description provided for @imageReady.
  ///
  /// In en, this message translates to:
  /// **'Photo ready — tap Extract to analyze'**
  String get imageReady;

  /// No description provided for @imageCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera or gallery. Check permissions and try again.'**
  String get imageCaptureFailed;

  /// No description provided for @provenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Provenance'**
  String get provenanceTitle;

  /// No description provided for @invalidDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: YYYY-MM-DD'**
  String get invalidDateFormat;

  /// No description provided for @invalidHeightRange.
  ///
  /// In en, this message translates to:
  /// **'Height must be between 80 and 260 cm'**
  String get invalidHeightRange;

  /// No description provided for @consentRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms of Service and Health Data Consent.'**
  String get consentRequired;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @appLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguageTitle;

  /// No description provided for @digitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get digitsTitle;

  /// No description provided for @digitsWestern.
  ///
  /// In en, this message translates to:
  /// **'Western (1, 2, 3)'**
  String get digitsWestern;

  /// No description provided for @digitsEasternArabic.
  ///
  /// In en, this message translates to:
  /// **'Eastern Arabic (١, ٢, ٣)'**
  String get digitsEasternArabic;

  /// No description provided for @healthProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Height, age, biological sex, activity level'**
  String get healthProfileSubtitle;

  /// No description provided for @aiProviderConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Companion & Provider Configuration'**
  String get aiProviderConfigTitle;

  /// No description provided for @aiProviderConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure system models or bring your own API key (BYOK) stored under client-side write-only encryption.'**
  String get aiProviderConfigDescription;

  /// No description provided for @aiConfigLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load AI config: {error}'**
  String aiConfigLoadError(Object error);

  /// No description provided for @activeAiProvider.
  ///
  /// In en, this message translates to:
  /// **'Active AI Provider'**
  String get activeAiProvider;

  /// No description provided for @storedCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stored Provider Credentials (Encrypted):'**
  String get storedCredentialsTitle;

  /// No description provided for @credentialFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint: {fingerprint} (AES-256-GCM)'**
  String credentialFingerprint(Object fingerprint);

  /// No description provided for @enterCustomApiKey.
  ///
  /// In en, this message translates to:
  /// **'Enter Custom API Key for {provider}'**
  String enterCustomApiKey(Object provider);

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @saveKey.
  ///
  /// In en, this message translates to:
  /// **'Save Key'**
  String get saveKey;

  /// No description provided for @connectionVerified.
  ///
  /// In en, this message translates to:
  /// **'Connection to {provider} verified successfully'**
  String connectionVerified(Object provider);

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection test failed'**
  String get connectionFailed;

  /// No description provided for @apiKeyTooShort.
  ///
  /// In en, this message translates to:
  /// **'API key must be at least 8 characters long'**
  String get apiKeyTooShort;

  /// No description provided for @apiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API key securely encrypted and stored for {provider}'**
  String apiKeySaved(Object provider);

  /// No description provided for @credentialRevoked.
  ///
  /// In en, this message translates to:
  /// **'Credential for {provider} revoked and erased'**
  String credentialRevoked(Object provider);

  /// No description provided for @exportJsonCopied.
  ///
  /// In en, this message translates to:
  /// **'Export JSON copied to clipboard'**
  String get exportJsonCopied;

  /// No description provided for @copyJson.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get copyJson;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(Object error);

  /// No description provided for @exportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Machine-readable portable JSON format'**
  String get exportSubtitle;

  /// No description provided for @purgeAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Irreversibly purge all personal records, models and media'**
  String get purgeAccountSubtitle;

  /// No description provided for @purgeFailed.
  ///
  /// In en, this message translates to:
  /// **'Account purge failed: {error}'**
  String purgeFailed(Object error);

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed In As'**
  String get signedInAs;

  /// No description provided for @assistantStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get assistantStatusOnline;

  /// No description provided for @assistantStatusThinking.
  ///
  /// In en, this message translates to:
  /// **'Reading your latest data…'**
  String get assistantStatusThinking;

  /// No description provided for @assistantStatusCalculating.
  ///
  /// In en, this message translates to:
  /// **'Checking the numbers…'**
  String get assistantStatusCalculating;

  /// No description provided for @assistantStatusGenerating.
  ///
  /// In en, this message translates to:
  /// **'Forma is replying…'**
  String get assistantStatusGenerating;

  /// No description provided for @assistantGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello! I am Forma, your personalized health and wellness companion. I can help answer fitness questions, monitor your progress, or prepare action proposals to log measurements and update goals.'**
  String get assistantGreeting;

  /// No description provided for @jumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'New reply'**
  String get jumpToLatest;

  /// No description provided for @confirmingAction.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get confirmingAction;

  /// No description provided for @actionExecuted.
  ///
  /// In en, this message translates to:
  /// **'Logged successfully'**
  String get actionExecuted;

  /// No description provided for @actionPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Confirmation'**
  String get actionPending;

  /// No description provided for @sourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesTitle;

  /// No description provided for @sourcesCount.
  ///
  /// In en, this message translates to:
  /// **'Sources ({count})'**
  String sourcesCount(Object count);

  /// No description provided for @messageInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Message Forma…'**
  String get messageInputPlaceholder;

  /// No description provided for @messageTooLongHint.
  ///
  /// In en, this message translates to:
  /// **'Message is too long — trim it to 2,000 characters.'**
  String get messageTooLongHint;

  /// No description provided for @stopGeneration.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopGeneration;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @errorS01Offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Check your internet connection.'**
  String get errorS01Offline;

  /// No description provided for @errorS02Provider.
  ///
  /// In en, this message translates to:
  /// **'Forma couldn\'t reach the AI service. Your data is safe.'**
  String get errorS02Provider;

  /// No description provided for @errorS03Timeout.
  ///
  /// In en, this message translates to:
  /// **'Taking longer than usual. Please retry.'**
  String get errorS03Timeout;

  /// No description provided for @errorS04Interrupted.
  ///
  /// In en, this message translates to:
  /// **'Reply interrupted.'**
  String get errorS04Interrupted;

  /// No description provided for @errorS05RateLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the message limit for now. Try again shortly.'**
  String get errorS05RateLimit;

  /// No description provided for @errorS06Expired.
  ///
  /// In en, this message translates to:
  /// **'Action proposal expired.'**
  String get errorS06Expired;

  /// No description provided for @errorS07Commit.
  ///
  /// In en, this message translates to:
  /// **'Failed to commit action.'**
  String get errorS07Commit;

  /// No description provided for @errorS08Malformed.
  ///
  /// In en, this message translates to:
  /// **'Unable to format response.'**
  String get errorS08Malformed;

  /// No description provided for @bmiTitle.
  ///
  /// In en, this message translates to:
  /// **'Body Mass Index'**
  String get bmiTitle;

  /// No description provided for @bmiCategoryUnderweight.
  ///
  /// In en, this message translates to:
  /// **'Underweight'**
  String get bmiCategoryUnderweight;

  /// No description provided for @bmiCategoryNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal Weight'**
  String get bmiCategoryNormal;

  /// No description provided for @bmiCategoryOverweight.
  ///
  /// In en, this message translates to:
  /// **'Overweight'**
  String get bmiCategoryOverweight;

  /// No description provided for @bmiCategoryObese.
  ///
  /// In en, this message translates to:
  /// **'Obese'**
  String get bmiCategoryObese;

  /// No description provided for @projectedCompletionDate.
  ///
  /// In en, this message translates to:
  /// **'Target Date: {date}'**
  String projectedCompletionDate(String date);

  /// No description provided for @remainingToTarget.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {diff} kg'**
  String remainingToTarget(String diff);

  /// No description provided for @deltaChange.
  ///
  /// In en, this message translates to:
  /// **'Change: {delta} kg'**
  String deltaChange(String delta);

  /// No description provided for @weightAndCompositionSection.
  ///
  /// In en, this message translates to:
  /// **'Weight & Body Composition'**
  String get weightAndCompositionSection;

  /// No description provided for @bodyCircumferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Circumference Measurements'**
  String get bodyCircumferencesSection;

  /// No description provided for @allHistory.
  ///
  /// In en, this message translates to:
  /// **'View All History'**
  String get allHistory;

  /// No description provided for @metabolicSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Metabolic Baseline Summary'**
  String get metabolicSummaryTitle;

  /// No description provided for @bmrLabel.
  ///
  /// In en, this message translates to:
  /// **'Basal Metabolic Rate'**
  String get bmrLabel;

  /// No description provided for @tdeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Daily Energy Expenditure'**
  String get tdeeLabel;
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
