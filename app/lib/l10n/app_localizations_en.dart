// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Open Remote';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get computers => 'Computers';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get mouse => 'Mouse';

  @override
  String get media => 'Media';

  @override
  String get keyboard => 'Keyboard';

  @override
  String forgetHostTitle(String name) {
    return 'Forget $name?';
  }

  @override
  String get forgetHostBody =>
      'You will need to authorize this phone again before connecting.';

  @override
  String get cancel => 'Cancel';

  @override
  String get forget => 'Forget';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get searchComputers => 'Search for computers';

  @override
  String get addComputer => 'Add computer';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get connectByIp => 'Connect by IP';

  @override
  String get computerOptions => 'Computer options';

  @override
  String get connected => 'Connected';

  @override
  String get paired => 'Paired';

  @override
  String get available => 'Available';

  @override
  String get openControls => 'Open controls';

  @override
  String get requestConnection => 'Request connection';

  @override
  String get forgetComputer => 'Forget computer';

  @override
  String get connecting => 'Connecting…';

  @override
  String get searchingComputers => 'Searching for computers…';

  @override
  String get noComputersFound => 'No computers found';

  @override
  String get startServerConnectWifi =>
      'Start the server on your PC and connect both devices to the same Wi-Fi network.';

  @override
  String get connect => 'Connect';

  @override
  String get computerIp => 'Computer IP address';

  @override
  String get localIpValidation => 'Enter a valid local IP address.';

  @override
  String get port => 'Port';

  @override
  String get portValidation => 'Use a port from 1024 to 65535.';

  @override
  String get pairWithWindows => 'Pair with Windows';

  @override
  String get scanServerQr =>
      'Point the camera at the QR code shown by the Windows server.';

  @override
  String get volume => 'Volume';

  @override
  String get decreaseVolume => 'Decrease';

  @override
  String get mute => 'Mute';

  @override
  String get increaseVolume => 'Increase';

  @override
  String get previousTrack => 'Previous';

  @override
  String get playPause => 'Play / pause';

  @override
  String get nextTrack => 'Next';

  @override
  String get stop => 'Stop';

  @override
  String get sendText => 'Send text';

  @override
  String get send => 'Send';

  @override
  String get space => 'Space';

  @override
  String get drag => 'Drag';

  @override
  String get leftClick => 'Left';

  @override
  String get middleClick => 'Middle';

  @override
  String get rightClick => 'Right';

  @override
  String get scroll => 'Scroll';

  @override
  String get touchpad => 'Touchpad';

  @override
  String get dragToSelect => 'Drag to select';

  @override
  String get swipeToMove => 'Swipe to move';

  @override
  String get tapToClick => 'Tap to click';

  @override
  String get manageComputers => 'Manage computers';

  @override
  String get copyDiagnostics => 'Copy diagnostics';

  @override
  String get restoreSettings => 'Restore settings';

  @override
  String get restoreSettingsQuestion => 'Restore settings?';

  @override
  String get pairedComputersKept => 'Paired computers will be kept.';

  @override
  String get restore => 'Restore';

  @override
  String get mouseSettings => 'Mouse';

  @override
  String get mouseSettingsDescription => 'Gestures, sensitivity and buttons';

  @override
  String get connectionSettings => 'Connection';

  @override
  String get connectionSettingsDescription =>
      'Discovery, reconnection and background';

  @override
  String get appearanceSettings => 'Appearance and controls';

  @override
  String get appearanceSettingsDescription => 'Theme, navigation and display';

  @override
  String get notificationPermissionBackground =>
      'Allow notifications to keep the connection running in the background.';

  @override
  String get backgroundConnectionFailed =>
      'Could not enable the background connection.';

  @override
  String get multiTouch => 'Multi-touch';

  @override
  String get multiTouchDescription =>
      'Use two fingers to scroll and tap with two fingers for right-click.';

  @override
  String get invertScroll => 'Invert scrolling';

  @override
  String get swapButtons => 'Swap buttons';

  @override
  String get swapButtonsDescription =>
      'Swap the primary and secondary buttons.';

  @override
  String get limitMouseUpdates => 'Limit mouse updates';

  @override
  String get updatesPerSecond => 'Updates per second';

  @override
  String get gestureZoom => 'Gesture zoom';

  @override
  String get gestureZoomDescription => 'Pinch to zoom in or out.';

  @override
  String get pointerSensitivity => 'Pointer sensitivity';

  @override
  String get scrollSensitivity => 'Scroll sensitivity';

  @override
  String get doubleTapDrag => 'Double-tap to drag';

  @override
  String get doubleTapDragDescription =>
      'Tap twice and hold the second tap to drag.';

  @override
  String get swipeToOpenMenu => 'Swipe to open menu';

  @override
  String get swipeToOpenMenuDescription =>
      'Turn this off to avoid opening the menu while using the mouse.';

  @override
  String get testMouse => 'Test mouse';

  @override
  String get automaticDiscovery => 'Automatic discovery';

  @override
  String get automaticDiscoveryDescription =>
      'Search for computers on the Wi-Fi network.';

  @override
  String get updateComputerIp => 'Update computer IP address';

  @override
  String get updateComputerIpDescription =>
      'Save the discovered address when the IP changes.';

  @override
  String get automaticReconnect => 'Automatic reconnection';

  @override
  String get automaticReconnectDescription =>
      'Try again when the connection drops.';

  @override
  String get keepBackgroundConnection => 'Keep connection in background';

  @override
  String get keepBackgroundConnectionDescription =>
      'Show a notification while the PC is connected.';

  @override
  String get showConnectionErrors => 'Show connection errors';

  @override
  String get theme => 'Theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get initialControl => 'Initial control';

  @override
  String get controlNavigation => 'Control navigation';

  @override
  String get bottomBar => 'Bottom bar';

  @override
  String get sideMenu => 'Side menu';

  @override
  String get visibleControls => 'Visible controls';

  @override
  String get screenOrientation => 'Screen orientation';

  @override
  String get automatic => 'Automatic';

  @override
  String get portrait => 'Portrait';

  @override
  String get landscape => 'Landscape';

  @override
  String get hapticFeedback => 'Haptic feedback';

  @override
  String get hapticFeedbackDescription =>
      'Vibrate when clicking and sending commands.';

  @override
  String get fullscreen => 'Full screen';

  @override
  String get fullscreenDescription => 'Hide the system bars.';

  @override
  String get keepScreenAwake => 'Keep screen awake';

  @override
  String get keepScreenAwakeDescription => 'While a control is open.';

  @override
  String get restoreFailedKeepPairings =>
      'Could not restore settings. Paired computers were kept.';

  @override
  String get restoreFailed => 'Could not restore settings.';

  @override
  String get aboutVersion => 'Version';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get platform => 'Platform';

  @override
  String get license => 'License';

  @override
  String get project => 'Project';

  @override
  String get credits => 'Credits';

  @override
  String get officialWebsite => 'Official website';

  @override
  String get personalGithub => 'Personal GitHub';

  @override
  String get openLinkFailed => 'Could not open the link.';

  @override
  String get diagnosticsCopied => 'Diagnostics copied.';

  @override
  String get connectToTestMouse => 'Connect to a computer to test the mouse.';

  @override
  String get forgetComputerFailed => 'Could not forget the computer.';

  @override
  String get discoverComputersFailed => 'Could not search for computers.';

  @override
  String get connectionFailed =>
      'Could not connect. Check that the PC is available on the network and try again.';

  @override
  String get noConnection => 'No computer is connected.';

  @override
  String get accessLocalNetwork =>
      'Allow local network access to connect to the PC.';

  @override
  String get serverPairApproval =>
      'Approve the connection request on the Windows computer.';

  @override
  String get savedAuthorizationRemoved =>
      'This PC removed this phone\'s authorization. Request a new connection.';

  @override
  String get savedComputerNeedsPairing =>
      'This computer needs to be paired again.';

  @override
  String get pairingQrExpired =>
      'The pairing QR code expired. Generate a new one on Windows.';

  @override
  String get accessDenied =>
      'Access was denied. Generate a new QR code or check that this phone is still paired.';

  @override
  String get serverRefusedPairing => 'The server refused pairing.';

  @override
  String get serverClosedConnection => 'The PC closed the connection.';

  @override
  String get connectionLost =>
      'Connection lost. Check the network and reconnect.';

  @override
  String get networkTimeout =>
      'The PC did not respond in time. Check the firewall and router client isolation.';

  @override
  String get networkFailure =>
      'Could not reach the PC. Check that the server is running and Windows Firewall allows the connection.';

  @override
  String get identityMismatch =>
      'The server identity does not match the scanned QR code.';

  @override
  String get handshakeInvalid =>
      'The server sent an invalid security response.';

  @override
  String get authenticationInvalid =>
      'The server sent an invalid authentication challenge.';

  @override
  String get serverDescriptorInvalid =>
      'The address did not respond as an Open Remote server.';

  @override
  String get serverIdentityInvalid =>
      'The server sent invalid identity information.';

  @override
  String get updateTitle => 'Updates';

  @override
  String installedVersion(String version) {
    return 'Installed version: $version';
  }

  @override
  String availableVersion(String version) {
    return 'Available version: $version';
  }

  @override
  String downloadSize(String size) {
    return 'Download: $size MB';
  }

  @override
  String get releaseNotes => 'Release notes';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get tryAgain => 'Try again';

  @override
  String get updateNow => 'Update';

  @override
  String get notNow => 'Not now';

  @override
  String get cancelUpdate => 'Cancel update';

  @override
  String get installUpdate => 'Install update';

  @override
  String get allowInstall => 'Allow installation';

  @override
  String get viewUpdate => 'View update';

  @override
  String updateAvailableNotice(String version) {
    return 'Update $version is available';
  }

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateUpToDate => 'You have the latest version for this device.';

  @override
  String get updateAvailable => 'An update is available.';

  @override
  String get updateDeferred =>
      'Update postponed until the app is opened again.';

  @override
  String get updateDownloading => 'Downloading update…';

  @override
  String get updateValidating => 'Validating the APK…';

  @override
  String get updateReady => 'APK validated. Ready to install.';

  @override
  String get updateInstalling => 'Confirm the update in the Android installer.';

  @override
  String get updateCancelled => 'Download cancelled.';

  @override
  String get updateInstallationCancelled =>
      'Installation cancelled. You can try again.';

  @override
  String get updatePermissionRequired =>
      'To install the update, allow Open Remote Control to install apps in Android settings. Then return here to continue.';

  @override
  String get updateNetworkError =>
      'Connection failed. Check your internet and try again.';

  @override
  String get updateUnavailableError =>
      'The update file is unavailable. Check again later.';

  @override
  String get updateStorageError =>
      'Not enough storage. Free up space and try again.';

  @override
  String get updateIntegrityError =>
      'The APK is incomplete or corrupted. Download it again.';

  @override
  String get updateIdentityError =>
      'This APK does not belong to this app. Installation was blocked.';

  @override
  String get updateSignatureError =>
      'The APK signature does not match the installed version. Installation was blocked.';

  @override
  String get updateIncompatibleError =>
      'This APK is not compatible with this device.';

  @override
  String get updateInvalidPackageError =>
      'Could not validate the APK. Download it again.';

  @override
  String get updatePermissionError =>
      'Installation was not authorized. You can keep using the app.';

  @override
  String get updateInstallerError => 'Could not start installation. Try again.';

  @override
  String get updateInterruptedError =>
      'The download was interrupted. Download it again to continue.';

  @override
  String get updateBusyError => 'An update is already in progress.';

  @override
  String get updateGenericError => 'Could not update. Try again.';

  @override
  String get notificationDownloading => 'Downloading update';

  @override
  String get notificationValidating => 'Validating update';

  @override
  String get notificationReady => 'Update ready to install';

  @override
  String get notificationChannel => 'App updates';

  @override
  String get rawError =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get pairingExpired =>
      'The pairing request expired. Generate a new QR code on Windows.';

  @override
  String get pairingLimit =>
      'The server has reached its pairing limit. Remove an old paired device on Windows and try again.';

  @override
  String get requestPending =>
      'A connection request is already waiting for approval on Windows.';

  @override
  String get pairingRejected =>
      'The connection request was rejected on Windows.';

  @override
  String get authorizationRevoked =>
      'This phone is no longer authorized. Request a new connection.';

  @override
  String get invalidAuthorization =>
      'The saved authorization is invalid. Pair this phone again.';

  @override
  String get invalidQr =>
      'This QR code is invalid or expired. Scan a current Open Remote pairing QR code.';

  @override
  String get secureConnectionFailed =>
      'A secure connection to the PC could not be established. Check that you selected the correct computer and try again.';

  @override
  String get preferencesReadFailed => 'Could not read preferences.';

  @override
  String get saveFailed => 'Could not save settings.';

  @override
  String get cameraStarting => 'Starting camera…';

  @override
  String get cameraPermission =>
      'Allow camera access in Android settings, then reopen the scanner.';

  @override
  String get cameraUnavailable =>
      'Could not open the camera. Try again, or connect to the PC by IP.';
}
