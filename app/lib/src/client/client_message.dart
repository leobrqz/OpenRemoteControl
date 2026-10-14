import 'dart:async';
import 'dart:io';

import '../../l10n/app_localizations.dart';

class ClientMessage {
  const ClientMessage(this.key, {this.detail});

  final String key;
  final Object? detail;

  String localized(AppLocalizations l10n) => switch (key) {
    'diagnosticsCopied' => l10n.diagnosticsCopied,
    'connectToTestMouse' => l10n.connectToTestMouse,
    'forgetComputerFailed' => l10n.forgetComputerFailed,
    'discoverComputersFailed' => l10n.discoverComputersFailed,
    'backgroundConnectionFailed' => l10n.backgroundConnectionFailed,
    'connectionFailed' => l10n.connectionFailed,
    'noConnection' => l10n.noConnection,
    'connected' => l10n.connected,
    'disconnected' => l10n.disconnected,
    'networkFailure' => l10n.networkFailure,
    'networkTimeout' => l10n.networkTimeout,
    'pairingExpired' => l10n.pairingExpired,
    'pairingLimit' => l10n.pairingLimit,
    'requestPending' => l10n.requestPending,
    'pairingRejected' => l10n.pairingRejected,
    'authorizationRevoked' => l10n.authorizationRevoked,
    'invalidAuthorization' => l10n.invalidAuthorization,
    'invalidQr' => l10n.invalidQr,
    'secureConnectionFailed' => l10n.secureConnectionFailed,
    'serverPairApproval' => l10n.serverPairApproval,
    'accessDenied' => l10n.accessDenied,
    'serverRefusedPairing' => l10n.serverRefusedPairing,
    'serverClosedConnection' => l10n.serverClosedConnection,
    'connectionLost' => l10n.connectionLost,
    'accessLocalNetwork' => l10n.accessLocalNetwork,
    'serverDescriptorInvalid' => l10n.serverDescriptorInvalid,
    'serverIdentityInvalid' => l10n.serverIdentityInvalid,
    'identityMismatch' => l10n.identityMismatch,
    'handshakeInvalid' => l10n.handshakeInvalid,
    'authenticationInvalid' => l10n.authenticationInvalid,
    'localIpValidation' => l10n.localIpValidation,
    'portValidation' => l10n.portValidation,
    _ => l10n.connectionFailed,
  };

  static ClientMessage fromError(
    Object error, {
    String fallback = 'connectionFailed',
  }) {
    if (error is ClientMessageException) return error.message;
    if (error is TimeoutException) {
      return ClientMessage('networkTimeout', detail: error);
    }
    if (error is SocketException || error is WebSocketException) {
      return ClientMessage('networkFailure', detail: error);
    }
    return ClientMessage(fallback, detail: error);
  }
}

class ClientMessageException implements Exception {
  const ClientMessageException(this.message);
  final ClientMessage message;

  @override
  String toString() => 'Remote client failure (${message.key})';
}
