import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('ja'),
    Locale('ko')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Osaka Live'**
  String get appName;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @cameraPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone access is required'**
  String get cameraPermissionTitle;

  /// No description provided for @cameraPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone access is needed to record live video. Please allow access in Settings.'**
  String get cameraPermissionMessage;

  /// No description provided for @locationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Location access is required'**
  String get locationPermissionTitle;

  /// No description provided for @locationPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Location access is needed to see nearby live content and update the map. Please allow access in Settings.'**
  String get locationPermissionMessage;

  /// No description provided for @storagePermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage access is required'**
  String get storagePermissionTitle;

  /// No description provided for @storagePermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Storage access is needed to download files. Please allow access in Settings.'**
  String get storagePermissionMessage;

  /// No description provided for @noInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetTitle;

  /// No description provided for @noInternetMessage.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection and try again.'**
  String get noInternetMessage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pageError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get pageError;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found.'**
  String get pageNotFound;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete'**
  String get downloadComplete;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @coverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover photo'**
  String get coverPhoto;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// No description provided for @chatPhotoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Take a photo to send in chat'**
  String get chatPhotoPrompt;

  /// No description provided for @chatVideoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Record a video to send in chat'**
  String get chatVideoPrompt;

  /// No description provided for @liveOnlyPrompt.
  ///
  /// In en, this message translates to:
  /// **'🔒 Gallery uploads unavailable · Live capture only'**
  String get liveOnlyPrompt;

  /// No description provided for @liveVideoOnly.
  ///
  /// In en, this message translates to:
  /// **'Only live videos from 5 to 30 seconds are allowed'**
  String get liveVideoOnly;

  /// No description provided for @maxVideoDuration.
  ///
  /// In en, this message translates to:
  /// **'Record up to 30 seconds'**
  String get maxVideoDuration;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// No description provided for @callReviewGps.
  ///
  /// In en, this message translates to:
  /// **'Call review · GPS verification'**
  String get callReviewGps;

  /// No description provided for @photoMode.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoMode;

  /// No description provided for @videoMode.
  ///
  /// In en, this message translates to:
  /// **'Video · up to 30 seconds'**
  String get videoMode;

  /// No description provided for @chooseMedia.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo or video'**
  String get chooseMedia;

  /// No description provided for @pageUrlError.
  ///
  /// In en, this message translates to:
  /// **'The page could not be found. Try again or check your internet connection.'**
  String get pageUrlError;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL. Please try again.'**
  String get invalidUrl;

  /// No description provided for @exitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to exit the app?'**
  String get exitConfirm;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequired;

  /// No description provided for @updateMessage.
  ///
  /// In en, this message translates to:
  /// **'Update to the latest version for a better experience.'**
  String get updateMessage;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @updateContinueMessage.
  ///
  /// In en, this message translates to:
  /// **'You need to update to continue.'**
  String get updateContinueMessage;

  /// No description provided for @splashHeadline.
  ///
  /// In en, this message translates to:
  /// **'Discover Osaka.\nLive, right now.'**
  String get splashHeadline;

  /// No description provided for @splashSubhead.
  ///
  /// In en, this message translates to:
  /// **'Be here for this moment.'**
  String get splashSubhead;

  /// No description provided for @splashDescription.
  ///
  /// In en, this message translates to:
  /// **'Live video, real people, real places.\nSee what\'s happening and\nmake better plans.'**
  String get splashDescription;

  /// No description provided for @cameraNotFound.
  ///
  /// In en, this message translates to:
  /// **'No camera found on this device.'**
  String get cameraNotFound;

  /// No description provided for @cameraStartError.
  ///
  /// In en, this message translates to:
  /// **'Unable to start camera. Please try again.'**
  String get cameraStartError;

  /// No description provided for @recordStartError.
  ///
  /// In en, this message translates to:
  /// **'Unable to start recording.'**
  String get recordStartError;

  /// No description provided for @recordPauseError.
  ///
  /// In en, this message translates to:
  /// **'Unable to pause recording.'**
  String get recordPauseError;

  /// No description provided for @recordResumeError.
  ///
  /// In en, this message translates to:
  /// **'Unable to resume recording.'**
  String get recordResumeError;

  /// No description provided for @recordStopError.
  ///
  /// In en, this message translates to:
  /// **'Unable to stop recording.'**
  String get recordStopError;

  /// No description provided for @takePhotoError.
  ///
  /// In en, this message translates to:
  /// **'Unable to take photo. Please try again.'**
  String get takePhotoError;

  /// No description provided for @sendVideoError.
  ///
  /// In en, this message translates to:
  /// **'Unable to send video. Please try again.'**
  String get sendVideoError;

  /// No description provided for @downloadFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Could not save this file. Please try again.'**
  String get downloadFailedDetail;
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
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
