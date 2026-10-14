import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

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
    Locale('en'),
    Locale('pt'),
    Locale('pt', 'BR'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Remote'**
  String get appTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get languagePortuguese;

  /// No description provided for @computers.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get computers;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @mouse.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get mouse;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @keyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get keyboard;

  /// No description provided for @forgetHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget {name}?'**
  String forgetHostTitle(String name);

  /// No description provided for @forgetHostBody.
  ///
  /// In en, this message translates to:
  /// **'You will need to authorize this phone again before connecting.'**
  String get forgetHostBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get reconnecting;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @searchComputers.
  ///
  /// In en, this message translates to:
  /// **'Search for computers'**
  String get searchComputers;

  /// No description provided for @addComputer.
  ///
  /// In en, this message translates to:
  /// **'Add computer'**
  String get addComputer;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQr;

  /// No description provided for @connectByIp.
  ///
  /// In en, this message translates to:
  /// **'Connect by IP'**
  String get connectByIp;

  /// No description provided for @computerOptions.
  ///
  /// In en, this message translates to:
  /// **'Computer options'**
  String get computerOptions;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @paired.
  ///
  /// In en, this message translates to:
  /// **'Paired'**
  String get paired;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @openControls.
  ///
  /// In en, this message translates to:
  /// **'Open controls'**
  String get openControls;

  /// No description provided for @requestConnection.
  ///
  /// In en, this message translates to:
  /// **'Request connection'**
  String get requestConnection;

  /// No description provided for @forgetComputer.
  ///
  /// In en, this message translates to:
  /// **'Forget computer'**
  String get forgetComputer;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @searchingComputers.
  ///
  /// In en, this message translates to:
  /// **'Searching for computers…'**
  String get searchingComputers;

  /// No description provided for @noComputersFound.
  ///
  /// In en, this message translates to:
  /// **'No computers found'**
  String get noComputersFound;

  /// No description provided for @startServerConnectWifi.
  ///
  /// In en, this message translates to:
  /// **'Start the server on your PC and connect both devices to the same Wi-Fi network.'**
  String get startServerConnectWifi;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @computerIp.
  ///
  /// In en, this message translates to:
  /// **'Computer IP address'**
  String get computerIp;

  /// No description provided for @localIpValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid local IP address.'**
  String get localIpValidation;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @portValidation.
  ///
  /// In en, this message translates to:
  /// **'Use a port from 1024 to 65535.'**
  String get portValidation;

  /// No description provided for @pairWithWindows.
  ///
  /// In en, this message translates to:
  /// **'Pair with Windows'**
  String get pairWithWindows;

  /// No description provided for @scanServerQr.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code shown by the Windows server.'**
  String get scanServerQr;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @decreaseVolume.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decreaseVolume;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @increaseVolume.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increaseVolume;

  /// No description provided for @previousTrack.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousTrack;

  /// No description provided for @playPause.
  ///
  /// In en, this message translates to:
  /// **'Play / pause'**
  String get playPause;

  /// No description provided for @nextTrack.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextTrack;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @sendText.
  ///
  /// In en, this message translates to:
  /// **'Send text'**
  String get sendText;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @space.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get space;

  /// No description provided for @drag.
  ///
  /// In en, this message translates to:
  /// **'Drag'**
  String get drag;

  /// No description provided for @leftClick.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftClick;

  /// No description provided for @middleClick.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get middleClick;

  /// No description provided for @rightClick.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get rightClick;

  /// No description provided for @scroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get scroll;

  /// No description provided for @touchpad.
  ///
  /// In en, this message translates to:
  /// **'Touchpad'**
  String get touchpad;

  /// No description provided for @dragToSelect.
  ///
  /// In en, this message translates to:
  /// **'Drag to select'**
  String get dragToSelect;

  /// No description provided for @swipeToMove.
  ///
  /// In en, this message translates to:
  /// **'Swipe to move'**
  String get swipeToMove;

  /// No description provided for @tapToClick.
  ///
  /// In en, this message translates to:
  /// **'Tap to click'**
  String get tapToClick;

  /// No description provided for @manageComputers.
  ///
  /// In en, this message translates to:
  /// **'Manage computers'**
  String get manageComputers;

  /// No description provided for @copyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get copyDiagnostics;

  /// No description provided for @restoreSettings.
  ///
  /// In en, this message translates to:
  /// **'Restore settings'**
  String get restoreSettings;

  /// No description provided for @restoreSettingsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Restore settings?'**
  String get restoreSettingsQuestion;

  /// No description provided for @pairedComputersKept.
  ///
  /// In en, this message translates to:
  /// **'Paired computers will be kept.'**
  String get pairedComputersKept;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @mouseSettings.
  ///
  /// In en, this message translates to:
  /// **'Mouse'**
  String get mouseSettings;

  /// No description provided for @mouseSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Gestures, sensitivity and buttons'**
  String get mouseSettingsDescription;

  /// No description provided for @connectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionSettings;

  /// No description provided for @connectionSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Discovery, reconnection and background'**
  String get connectionSettingsDescription;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance and controls'**
  String get appearanceSettings;

  /// No description provided for @appearanceSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Theme, navigation and display'**
  String get appearanceSettingsDescription;

  /// No description provided for @notificationPermissionBackground.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications to keep the connection running in the background.'**
  String get notificationPermissionBackground;

  /// No description provided for @backgroundConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not enable the background connection.'**
  String get backgroundConnectionFailed;

  /// No description provided for @multiTouch.
  ///
  /// In en, this message translates to:
  /// **'Multi-touch'**
  String get multiTouch;

  /// No description provided for @multiTouchDescription.
  ///
  /// In en, this message translates to:
  /// **'Use two fingers to scroll and tap with two fingers for right-click.'**
  String get multiTouchDescription;

  /// No description provided for @invertScroll.
  ///
  /// In en, this message translates to:
  /// **'Invert scrolling'**
  String get invertScroll;

  /// No description provided for @swapButtons.
  ///
  /// In en, this message translates to:
  /// **'Swap buttons'**
  String get swapButtons;

  /// No description provided for @swapButtonsDescription.
  ///
  /// In en, this message translates to:
  /// **'Swap the primary and secondary buttons.'**
  String get swapButtonsDescription;

  /// No description provided for @limitMouseUpdates.
  ///
  /// In en, this message translates to:
  /// **'Limit mouse updates'**
  String get limitMouseUpdates;

  /// No description provided for @updatesPerSecond.
  ///
  /// In en, this message translates to:
  /// **'Updates per second'**
  String get updatesPerSecond;

  /// No description provided for @gestureZoom.
  ///
  /// In en, this message translates to:
  /// **'Gesture zoom'**
  String get gestureZoom;

  /// No description provided for @gestureZoomDescription.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom in or out.'**
  String get gestureZoomDescription;

  /// No description provided for @pointerSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Pointer sensitivity'**
  String get pointerSensitivity;

  /// No description provided for @scrollSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Scroll sensitivity'**
  String get scrollSensitivity;

  /// No description provided for @doubleTapDrag.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to drag'**
  String get doubleTapDrag;

  /// No description provided for @doubleTapDragDescription.
  ///
  /// In en, this message translates to:
  /// **'Tap twice and hold the second tap to drag.'**
  String get doubleTapDragDescription;

  /// No description provided for @swipeToOpenMenu.
  ///
  /// In en, this message translates to:
  /// **'Swipe to open menu'**
  String get swipeToOpenMenu;

  /// No description provided for @swipeToOpenMenuDescription.
  ///
  /// In en, this message translates to:
  /// **'Turn this off to avoid opening the menu while using the mouse.'**
  String get swipeToOpenMenuDescription;

  /// No description provided for @testMouse.
  ///
  /// In en, this message translates to:
  /// **'Test mouse'**
  String get testMouse;

  /// No description provided for @automaticDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Automatic discovery'**
  String get automaticDiscovery;

  /// No description provided for @automaticDiscoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'Search for computers on the Wi-Fi network.'**
  String get automaticDiscoveryDescription;

  /// No description provided for @updateComputerIp.
  ///
  /// In en, this message translates to:
  /// **'Update computer IP address'**
  String get updateComputerIp;

  /// No description provided for @updateComputerIpDescription.
  ///
  /// In en, this message translates to:
  /// **'Save the discovered address when the IP changes.'**
  String get updateComputerIpDescription;

  /// No description provided for @automaticReconnect.
  ///
  /// In en, this message translates to:
  /// **'Automatic reconnection'**
  String get automaticReconnect;

  /// No description provided for @automaticReconnectDescription.
  ///
  /// In en, this message translates to:
  /// **'Try again when the connection drops.'**
  String get automaticReconnectDescription;

  /// No description provided for @keepBackgroundConnection.
  ///
  /// In en, this message translates to:
  /// **'Keep connection in background'**
  String get keepBackgroundConnection;

  /// No description provided for @keepBackgroundConnectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a notification while the PC is connected.'**
  String get keepBackgroundConnectionDescription;

  /// No description provided for @showConnectionErrors.
  ///
  /// In en, this message translates to:
  /// **'Show connection errors'**
  String get showConnectionErrors;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @initialControl.
  ///
  /// In en, this message translates to:
  /// **'Initial control'**
  String get initialControl;

  /// No description provided for @controlNavigation.
  ///
  /// In en, this message translates to:
  /// **'Control navigation'**
  String get controlNavigation;

  /// No description provided for @bottomBar.
  ///
  /// In en, this message translates to:
  /// **'Bottom bar'**
  String get bottomBar;

  /// No description provided for @sideMenu.
  ///
  /// In en, this message translates to:
  /// **'Side menu'**
  String get sideMenu;

  /// No description provided for @visibleControls.
  ///
  /// In en, this message translates to:
  /// **'Visible controls'**
  String get visibleControls;

  /// No description provided for @screenOrientation.
  ///
  /// In en, this message translates to:
  /// **'Screen orientation'**
  String get screenOrientation;

  /// No description provided for @automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automatic;

  /// No description provided for @portrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get portrait;

  /// No description provided for @landscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get landscape;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get hapticFeedback;

  /// No description provided for @hapticFeedbackDescription.
  ///
  /// In en, this message translates to:
  /// **'Vibrate when clicking and sending commands.'**
  String get hapticFeedbackDescription;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullscreen;

  /// No description provided for @fullscreenDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide the system bars.'**
  String get fullscreenDescription;

  /// No description provided for @keepScreenAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake'**
  String get keepScreenAwake;

  /// No description provided for @keepScreenAwakeDescription.
  ///
  /// In en, this message translates to:
  /// **'While a control is open.'**
  String get keepScreenAwakeDescription;

  /// No description provided for @restoreFailedKeepPairings.
  ///
  /// In en, this message translates to:
  /// **'Could not restore settings. Paired computers were kept.'**
  String get restoreFailedKeepPairings;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore settings.'**
  String get restoreFailed;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get aboutVersion;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @officialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get officialWebsite;

  /// No description provided for @personalGithub.
  ///
  /// In en, this message translates to:
  /// **'Personal GitHub'**
  String get personalGithub;

  /// No description provided for @openLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get openLinkFailed;

  /// No description provided for @diagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied.'**
  String get diagnosticsCopied;

  /// No description provided for @connectToTestMouse.
  ///
  /// In en, this message translates to:
  /// **'Connect to a computer to test the mouse.'**
  String get connectToTestMouse;

  /// No description provided for @forgetComputerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not forget the computer.'**
  String get forgetComputerFailed;

  /// No description provided for @discoverComputersFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not search for computers.'**
  String get discoverComputersFailed;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check that the PC is available on the network and try again.'**
  String get connectionFailed;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No computer is connected.'**
  String get noConnection;

  /// No description provided for @accessLocalNetwork.
  ///
  /// In en, this message translates to:
  /// **'Allow local network access to connect to the PC.'**
  String get accessLocalNetwork;

  /// No description provided for @serverPairApproval.
  ///
  /// In en, this message translates to:
  /// **'Approve the connection request on the Windows computer.'**
  String get serverPairApproval;

  /// No description provided for @savedAuthorizationRemoved.
  ///
  /// In en, this message translates to:
  /// **'This PC removed this phone\'s authorization. Request a new connection.'**
  String get savedAuthorizationRemoved;

  /// No description provided for @savedComputerNeedsPairing.
  ///
  /// In en, this message translates to:
  /// **'This computer needs to be paired again.'**
  String get savedComputerNeedsPairing;

  /// No description provided for @pairingQrExpired.
  ///
  /// In en, this message translates to:
  /// **'The pairing QR code expired. Generate a new one on Windows.'**
  String get pairingQrExpired;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access was denied. Generate a new QR code or check that this phone is still paired.'**
  String get accessDenied;

  /// No description provided for @serverRefusedPairing.
  ///
  /// In en, this message translates to:
  /// **'The server refused pairing.'**
  String get serverRefusedPairing;

  /// No description provided for @serverClosedConnection.
  ///
  /// In en, this message translates to:
  /// **'The PC closed the connection.'**
  String get serverClosedConnection;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Check the network and reconnect.'**
  String get connectionLost;

  /// No description provided for @networkTimeout.
  ///
  /// In en, this message translates to:
  /// **'The PC did not respond in time. Check the firewall and router client isolation.'**
  String get networkTimeout;

  /// No description provided for @networkFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the PC. Check that the server is running and Windows Firewall allows the connection.'**
  String get networkFailure;

  /// No description provided for @identityMismatch.
  ///
  /// In en, this message translates to:
  /// **'The server identity does not match the scanned QR code.'**
  String get identityMismatch;

  /// No description provided for @handshakeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server sent an invalid security response.'**
  String get handshakeInvalid;

  /// No description provided for @authenticationInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server sent an invalid authentication challenge.'**
  String get authenticationInvalid;

  /// No description provided for @serverDescriptorInvalid.
  ///
  /// In en, this message translates to:
  /// **'The address did not respond as an Open Remote server.'**
  String get serverDescriptorInvalid;

  /// No description provided for @serverIdentityInvalid.
  ///
  /// In en, this message translates to:
  /// **'The server sent invalid identity information.'**
  String get serverIdentityInvalid;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updateTitle;

  /// No description provided for @installedVersion.
  ///
  /// In en, this message translates to:
  /// **'Installed version: {version}'**
  String installedVersion(String version);

  /// No description provided for @availableVersion.
  ///
  /// In en, this message translates to:
  /// **'Available version: {version}'**
  String availableVersion(String version);

  /// No description provided for @downloadSize.
  ///
  /// In en, this message translates to:
  /// **'Download: {size} MB'**
  String downloadSize(String size);

  /// No description provided for @releaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get releaseNotes;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @cancelUpdate.
  ///
  /// In en, this message translates to:
  /// **'Cancel update'**
  String get cancelUpdate;

  /// No description provided for @installUpdate.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get installUpdate;

  /// No description provided for @allowInstall.
  ///
  /// In en, this message translates to:
  /// **'Allow installation'**
  String get allowInstall;

  /// No description provided for @viewUpdate.
  ///
  /// In en, this message translates to:
  /// **'View update'**
  String get viewUpdate;

  /// No description provided for @updateAvailableNotice.
  ///
  /// In en, this message translates to:
  /// **'Update {version} is available'**
  String updateAvailableNotice(String version);

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version for this device.'**
  String get updateUpToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'An update is available.'**
  String get updateAvailable;

  /// No description provided for @updateDeferred.
  ///
  /// In en, this message translates to:
  /// **'Update postponed until the app is opened again.'**
  String get updateDeferred;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update…'**
  String get updateDownloading;

  /// No description provided for @updateValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating the APK…'**
  String get updateValidating;

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'APK validated. Ready to install.'**
  String get updateReady;

  /// No description provided for @updateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Confirm the update in the Android installer.'**
  String get updateInstalling;

  /// No description provided for @updateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled.'**
  String get updateCancelled;

  /// No description provided for @updateInstallationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Installation cancelled. You can try again.'**
  String get updateInstallationCancelled;

  /// No description provided for @updatePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'To install the update, allow Open Remote Control to install apps in Android settings. Then return here to continue.'**
  String get updatePermissionRequired;

  /// No description provided for @updateNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed. Check your internet and try again.'**
  String get updateNetworkError;

  /// No description provided for @updateUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'The update file is unavailable. Check again later.'**
  String get updateUnavailableError;

  /// No description provided for @updateStorageError.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage. Free up space and try again.'**
  String get updateStorageError;

  /// No description provided for @updateIntegrityError.
  ///
  /// In en, this message translates to:
  /// **'The APK is incomplete or corrupted. Download it again.'**
  String get updateIntegrityError;

  /// No description provided for @updateIdentityError.
  ///
  /// In en, this message translates to:
  /// **'This APK does not belong to this app. Installation was blocked.'**
  String get updateIdentityError;

  /// No description provided for @updateSignatureError.
  ///
  /// In en, this message translates to:
  /// **'The APK signature does not match the installed version. Installation was blocked.'**
  String get updateSignatureError;

  /// No description provided for @updateIncompatibleError.
  ///
  /// In en, this message translates to:
  /// **'This APK is not compatible with this device.'**
  String get updateIncompatibleError;

  /// No description provided for @updateInvalidPackageError.
  ///
  /// In en, this message translates to:
  /// **'Could not validate the APK. Download it again.'**
  String get updateInvalidPackageError;

  /// No description provided for @updatePermissionError.
  ///
  /// In en, this message translates to:
  /// **'Installation was not authorized. You can keep using the app.'**
  String get updatePermissionError;

  /// No description provided for @updateInstallerError.
  ///
  /// In en, this message translates to:
  /// **'Could not start installation. Try again.'**
  String get updateInstallerError;

  /// No description provided for @updateInterruptedError.
  ///
  /// In en, this message translates to:
  /// **'The download was interrupted. Download it again to continue.'**
  String get updateInterruptedError;

  /// No description provided for @updateBusyError.
  ///
  /// In en, this message translates to:
  /// **'An update is already in progress.'**
  String get updateBusyError;

  /// No description provided for @updateGenericError.
  ///
  /// In en, this message translates to:
  /// **'Could not update. Try again.'**
  String get updateGenericError;

  /// No description provided for @notificationDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get notificationDownloading;

  /// No description provided for @notificationValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating update'**
  String get notificationValidating;

  /// No description provided for @notificationReady.
  ///
  /// In en, this message translates to:
  /// **'Update ready to install'**
  String get notificationReady;

  /// No description provided for @notificationChannel.
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get notificationChannel;

  /// No description provided for @rawError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Check your connection and try again.'**
  String get rawError;

  /// No description provided for @pairingExpired.
  ///
  /// In en, this message translates to:
  /// **'The pairing request expired. Generate a new QR code on Windows.'**
  String get pairingExpired;

  /// No description provided for @pairingLimit.
  ///
  /// In en, this message translates to:
  /// **'The server has reached its pairing limit. Remove an old paired device on Windows and try again.'**
  String get pairingLimit;

  /// No description provided for @requestPending.
  ///
  /// In en, this message translates to:
  /// **'A connection request is already waiting for approval on Windows.'**
  String get requestPending;

  /// No description provided for @pairingRejected.
  ///
  /// In en, this message translates to:
  /// **'The connection request was rejected on Windows.'**
  String get pairingRejected;

  /// No description provided for @authorizationRevoked.
  ///
  /// In en, this message translates to:
  /// **'This phone is no longer authorized. Request a new connection.'**
  String get authorizationRevoked;

  /// No description provided for @invalidAuthorization.
  ///
  /// In en, this message translates to:
  /// **'The saved authorization is invalid. Pair this phone again.'**
  String get invalidAuthorization;

  /// No description provided for @invalidQr.
  ///
  /// In en, this message translates to:
  /// **'This QR code is invalid or expired. Scan a current Open Remote pairing QR code.'**
  String get invalidQr;

  /// No description provided for @secureConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'A secure connection to the PC could not be established. Check that you selected the correct computer and try again.'**
  String get secureConnectionFailed;

  /// No description provided for @preferencesReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read preferences.'**
  String get preferencesReadFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save settings.'**
  String get saveFailed;

  /// No description provided for @cameraStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting camera…'**
  String get cameraStarting;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in Android settings, then reopen the scanner.'**
  String get cameraPermission;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera. Try again, or connect to the PC by IP.'**
  String get cameraUnavailable;
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
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
