import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
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
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'BloodPulse'**
  String get appName;

  /// No description provided for @appSlogan.
  ///
  /// In en, this message translates to:
  /// **'You give today , They live today.'**
  String get appSlogan;

  /// No description provided for @letsStart.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Start'**
  String get letsStart;

  /// No description provided for @termsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our terms of clinical excellence and community altruism.'**
  String get termsDisclaimer;

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @navBloodHub.
  ///
  /// In en, this message translates to:
  /// **'Blood Hub'**
  String get navBloodHub;

  /// No description provided for @navCommunities.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get navCommunities;

  /// No description provided for @navHealthHub.
  ///
  /// In en, this message translates to:
  /// **'Health Hub'**
  String get navHealthHub;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @menuLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get menuLearnMore;

  /// No description provided for @menuContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get menuContactUs;

  /// No description provided for @menuAboutUs.
  ///
  /// In en, this message translates to:
  /// **'About us'**
  String get menuAboutUs;

  /// No description provided for @menuLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get menuLogOut;

  /// No description provided for @menuLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch Language / ভাষা পরিবর্তন'**
  String get menuLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageBangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get languageBangla;

  /// No description provided for @feedTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Feed'**
  String get feedTitle;

  /// No description provided for @feedSharePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Share a blood request or update...'**
  String get feedSharePlaceholder;

  /// No description provided for @feedCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get feedCreatePost;

  /// No description provided for @feedImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get feedImage;

  /// No description provided for @feedText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get feedText;

  /// No description provided for @feedFeeling.
  ///
  /// In en, this message translates to:
  /// **'Feeling'**
  String get feedFeeling;

  /// No description provided for @feedCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get feedCheckIn;

  /// No description provided for @feedPostBtn.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get feedPostBtn;

  /// No description provided for @feedReact.
  ///
  /// In en, this message translates to:
  /// **'React'**
  String get feedReact;

  /// No description provided for @feedComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get feedComment;

  /// No description provided for @feedRepost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get feedRepost;

  /// No description provided for @feedWriteComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get feedWriteComment;

  /// No description provided for @feedCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get feedCommentsTitle;

  /// No description provided for @feedNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first to comment!'**
  String get feedNoComments;

  /// No description provided for @hubOverview.
  ///
  /// In en, this message translates to:
  /// **'Hub Overview'**
  String get hubOverview;

  /// No description provided for @hubSearchDonors.
  ///
  /// In en, this message translates to:
  /// **'Search Donors'**
  String get hubSearchDonors;

  /// No description provided for @hubRequestBlood.
  ///
  /// In en, this message translates to:
  /// **'Request Blood'**
  String get hubRequestBlood;

  /// No description provided for @hubVitalCommunity.
  ///
  /// In en, this message translates to:
  /// **'Vital Community'**
  String get hubVitalCommunity;

  /// No description provided for @hubHeartOfGiving.
  ///
  /// In en, this message translates to:
  /// **'The Heart of Giving'**
  String get hubHeartOfGiving;

  /// No description provided for @hubSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search for Donor'**
  String get hubSearchTitle;

  /// No description provided for @hubSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Access our verified database of local donors filtered by blood type, proximity, and availability.'**
  String get hubSearchDesc;

  /// No description provided for @hubFindNow.
  ///
  /// In en, this message translates to:
  /// **'Find Now →'**
  String get hubFindNow;

  /// No description provided for @hubRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Request for Blood'**
  String get hubRequestTitle;

  /// No description provided for @hubRequestDesc.
  ///
  /// In en, this message translates to:
  /// **'Instantly notify all eligible donors in your area for urgent transfusion needs or planned procedures.'**
  String get hubRequestDesc;

  /// No description provided for @hubUrgentRequests.
  ///
  /// In en, this message translates to:
  /// **'Urgent Blood Requests'**
  String get hubUrgentRequests;

  /// No description provided for @hubUnitsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Units Needed'**
  String get hubUnitsNeeded;

  /// No description provided for @hubHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get hubHospital;

  /// No description provided for @hubContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get hubContact;

  /// No description provided for @commTitle.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get commTitle;

  /// No description provided for @commJoin.
  ///
  /// In en, this message translates to:
  /// **'Join Community'**
  String get commJoin;

  /// No description provided for @commDiscussions.
  ///
  /// In en, this message translates to:
  /// **'Discussions'**
  String get commDiscussions;

  /// No description provided for @commMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get commMembers;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Hub'**
  String get healthTitle;

  /// No description provided for @healthScannerTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Blood Report Scanner'**
  String get healthScannerTitle;

  /// No description provided for @healthScannerDesc.
  ///
  /// In en, this message translates to:
  /// **'Upload CBC or hemoglobin lab reports to extract parameters & verify donation readiness.'**
  String get healthScannerDesc;

  /// No description provided for @healthSelectReport.
  ///
  /// In en, this message translates to:
  /// **'Select or Scan Report Document'**
  String get healthSelectReport;

  /// No description provided for @healthAttachedReport.
  ///
  /// In en, this message translates to:
  /// **'Report File Attached'**
  String get healthAttachedReport;

  /// No description provided for @healthProcessBtn.
  ///
  /// In en, this message translates to:
  /// **'Process Report'**
  String get healthProcessBtn;

  /// No description provided for @healthAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing Document with AI...'**
  String get healthAnalyzing;

  /// No description provided for @healthSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Health Summary'**
  String get healthSummary;

  /// No description provided for @healthAuthenticity.
  ///
  /// In en, this message translates to:
  /// **'Document Authenticity'**
  String get healthAuthenticity;

  /// No description provided for @healthExtractedParams.
  ///
  /// In en, this message translates to:
  /// **'Extracted Parameters:'**
  String get healthExtractedParams;

  /// No description provided for @healthReadyOptimal.
  ///
  /// In en, this message translates to:
  /// **'Result: Patient is in optimal condition for voluntary blood donation.'**
  String get healthReadyOptimal;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Donor Profile'**
  String get profileTitle;

  /// No description provided for @profileHistory.
  ///
  /// In en, this message translates to:
  /// **'Donation History'**
  String get profileHistory;

  /// No description provided for @profileBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges & Recognition'**
  String get profileBadges;

  /// No description provided for @profileEligibility.
  ///
  /// In en, this message translates to:
  /// **'Eligibility Status'**
  String get profileEligibility;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get authPhone;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get authFullName;

  /// No description provided for @authAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get authAge;

  /// No description provided for @authGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get authGender;

  /// No description provided for @authBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get authBloodGroup;

  /// No description provided for @authOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get authOtpTitle;

  /// No description provided for @authOtpDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your phone number'**
  String get authOtpDesc;

  /// No description provided for @authVerifyBtn.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get authVerifyBtn;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get chooseLanguage;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to the community.\nYour donation matters.'**
  String get loginSubtitle;

  /// No description provided for @usernameOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Username or Phone'**
  String get usernameOrPhone;

  /// No description provided for @enterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials'**
  String get enterCredentials;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get createAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your BloodPulse account?'**
  String get logoutConfirm;

  /// No description provided for @regTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get regTitle;

  /// No description provided for @regSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join the network to save lives across Bangladesh.'**
  String get regSubtitle;

  /// No description provided for @regStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get regStudent;

  /// No description provided for @regCivilian.
  ///
  /// In en, this message translates to:
  /// **'Civilian'**
  String get regCivilian;

  /// No description provided for @regCategory.
  ///
  /// In en, this message translates to:
  /// **'User Category'**
  String get regCategory;

  /// No description provided for @regFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name (English)'**
  String get regFullName;

  /// No description provided for @regEmail.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get regEmail;

  /// No description provided for @regPhonePrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary Phone (SMS OTP)'**
  String get regPhonePrimary;

  /// No description provided for @regAltPhone.
  ///
  /// In en, this message translates to:
  /// **'Alternative Phone (Optional)'**
  String get regAltPhone;

  /// No description provided for @regPassword.
  ///
  /// In en, this message translates to:
  /// **'Password (min. 6 characters)'**
  String get regPassword;

  /// No description provided for @regConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get regConfirmPassword;

  /// No description provided for @regAge.
  ///
  /// In en, this message translates to:
  /// **'Age (18-65 years)'**
  String get regAge;

  /// No description provided for @regGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get regGender;

  /// No description provided for @regMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get regMale;

  /// No description provided for @regFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get regFemale;

  /// No description provided for @regBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get regBloodGroup;

  /// No description provided for @regDivision.
  ///
  /// In en, this message translates to:
  /// **'Division'**
  String get regDivision;

  /// No description provided for @regDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get regDistrict;

  /// No description provided for @regUpazila.
  ///
  /// In en, this message translates to:
  /// **'Upazila'**
  String get regUpazila;

  /// No description provided for @regSubmit.
  ///
  /// In en, this message translates to:
  /// **'Register & Verify'**
  String get regSubmit;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @loginHere.
  ///
  /// In en, this message translates to:
  /// **'Login Here'**
  String get loginHere;

  /// No description provided for @hubTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Hub Overview'**
  String get hubTabOverview;

  /// No description provided for @hubTabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search Donors'**
  String get hubTabSearch;

  /// No description provided for @hubTabRequest.
  ///
  /// In en, this message translates to:
  /// **'Request Blood'**
  String get hubTabRequest;

  /// No description provided for @hubEmergencyHotline.
  ///
  /// In en, this message translates to:
  /// **'Emergency Hotline: 16263'**
  String get hubEmergencyHotline;

  /// No description provided for @hubCallDonor.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get hubCallDonor;

  /// No description provided for @hubChatDonor.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get hubChatDonor;

  /// No description provided for @hubFilterBloodGroup.
  ///
  /// In en, this message translates to:
  /// **'Blood Group'**
  String get hubFilterBloodGroup;

  /// No description provided for @hubFilterLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get hubFilterLocation;

  /// No description provided for @feedCommunityFeed.
  ///
  /// In en, this message translates to:
  /// **'Community Feed'**
  String get feedCommunityFeed;

  /// No description provided for @feedQuickImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get feedQuickImage;

  /// No description provided for @feedQuickText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get feedQuickText;

  /// No description provided for @feedQuickFeeling.
  ///
  /// In en, this message translates to:
  /// **'Feeling'**
  String get feedQuickFeeling;

  /// No description provided for @feedQuickCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get feedQuickCheckIn;

  /// No description provided for @feedPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish Post'**
  String get feedPublish;

  /// No description provided for @feedLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get feedLike;

  /// No description provided for @feedShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get feedShare;

  /// No description provided for @commSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with verified donor networks & hospitals.'**
  String get commSubtitle;

  /// No description provided for @commTabNetworks.
  ///
  /// In en, this message translates to:
  /// **'Donor Networks'**
  String get commTabNetworks;

  /// No description provided for @commTabHospitals.
  ///
  /// In en, this message translates to:
  /// **'Hospitals & Banks'**
  String get commTabHospitals;

  /// No description provided for @commTabGuides.
  ///
  /// In en, this message translates to:
  /// **'Area Guides'**
  String get commTabGuides;

  /// No description provided for @commSearchNetworks.
  ///
  /// In en, this message translates to:
  /// **'Search networks...'**
  String get commSearchNetworks;

  /// No description provided for @commSearchHospitals.
  ///
  /// In en, this message translates to:
  /// **'Search hospitals...'**
  String get commSearchHospitals;

  /// No description provided for @commSearchGuides.
  ///
  /// In en, this message translates to:
  /// **'Search area guides...'**
  String get commSearchGuides;

  /// No description provided for @healthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal health & donation intelligence center.'**
  String get healthSubtitle;

  /// No description provided for @healthStatusOptimal.
  ///
  /// In en, this message translates to:
  /// **'Donor Health Status: Optimal'**
  String get healthStatusOptimal;

  /// No description provided for @healthStatusDesc.
  ///
  /// In en, this message translates to:
  /// **'You meet all biological parameters for safe blood donation.'**
  String get healthStatusDesc;

  /// No description provided for @healthToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools & Analytics'**
  String get healthToolsTitle;

  /// No description provided for @healthToolScanner.
  ///
  /// In en, this message translates to:
  /// **'AI Report Scanner'**
  String get healthToolScanner;

  /// No description provided for @healthToolScannerDesc.
  ///
  /// In en, this message translates to:
  /// **'Upload CBC/Hemoglobin lab test'**
  String get healthToolScannerDesc;

  /// No description provided for @healthToolReadiness.
  ///
  /// In en, this message translates to:
  /// **'Donation Readiness'**
  String get healthToolReadiness;

  /// No description provided for @healthToolReadinessDesc.
  ///
  /// In en, this message translates to:
  /// **'WHO biological eligibility check'**
  String get healthToolReadinessDesc;

  /// No description provided for @healthToolCountdown.
  ///
  /// In en, this message translates to:
  /// **'Donation Countdown'**
  String get healthToolCountdown;

  /// No description provided for @healthToolCountdownDesc.
  ///
  /// In en, this message translates to:
  /// **'120-day safe recovery interval'**
  String get healthToolCountdownDesc;

  /// No description provided for @healthToolCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Blood Compatibility'**
  String get healthToolCompatibility;

  /// No description provided for @healthToolCompatibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Universal donor & recipient matrix'**
  String get healthToolCompatibilityDesc;

  /// No description provided for @healthToolHydration.
  ///
  /// In en, this message translates to:
  /// **'Hydration Tracker'**
  String get healthToolHydration;

  /// No description provided for @healthToolHydrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Optimal pre-donation fluid goals'**
  String get healthToolHydrationDesc;

  /// No description provided for @healthToolRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery & Aftercare'**
  String get healthToolRecovery;

  /// No description provided for @healthToolRecoveryDesc.
  ///
  /// In en, this message translates to:
  /// **'Clinical post-donation guidelines'**
  String get healthToolRecoveryDesc;

  /// No description provided for @healthToolResources.
  ///
  /// In en, this message translates to:
  /// **'Resources & FAQs'**
  String get healthToolResources;

  /// No description provided for @healthToolResourcesDesc.
  ///
  /// In en, this message translates to:
  /// **'Blood bank directory & helpline'**
  String get healthToolResourcesDesc;

  /// No description provided for @healthWellnessTip.
  ///
  /// In en, this message translates to:
  /// **'Daily Clinical Wellness Tip'**
  String get healthWellnessTip;

  /// No description provided for @profileDonationHistory.
  ///
  /// In en, this message translates to:
  /// **'Donation History'**
  String get profileDonationHistory;

  /// No description provided for @profileLastDonated.
  ///
  /// In en, this message translates to:
  /// **'Last Donation'**
  String get profileLastDonated;

  /// No description provided for @profileNextEligible.
  ///
  /// In en, this message translates to:
  /// **'Next Eligible Date'**
  String get profileNextEligible;

  /// No description provided for @profileTotalDonations.
  ///
  /// In en, this message translates to:
  /// **'Total Donations'**
  String get profileTotalDonations;

  /// No description provided for @profileLivesSaved.
  ///
  /// In en, this message translates to:
  /// **'Lives Saved'**
  String get profileLivesSaved;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifTabFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get notifTabFeed;

  /// No description provided for @notifTabRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get notifTabRequest;

  /// No description provided for @notifTabMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notifTabMessages;

  /// No description provided for @notifTabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get notifTabProfile;

  /// No description provided for @notifNoItems.
  ///
  /// In en, this message translates to:
  /// **'No notifications in this category yet.'**
  String get notifNoItems;
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
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
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
