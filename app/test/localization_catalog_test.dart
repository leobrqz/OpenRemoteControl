import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';
import 'package:open_remote_control/src/client/client_message.dart';
import 'package:open_remote_control/src/client/preferences/client_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('language defaults to en-US and persists both supported locales', () {
    const defaults = ClientPreferences();
    expect(defaults.language, 'en-US');
    expect(defaults.locale, const Locale('en', 'US'));
    expect(
      ClientPreferences.fromJson({}).language,
      'en-US',
      reason:
          'older saved preferences must use English regardless of device locale',
    );

    final portuguese = defaults.copyWith(language: 'pt-BR');
    expect(portuguese.locale, const Locale('pt', 'BR'));
    expect(ClientPreferences.fromJson(portuguese.toJson()).language, 'pt-BR');
    expect(defaults.copyWith(language: 'fr-FR').language, 'en-US');
  });

  test('message identifiers resolve to each language at presentation', () {
    const message = ClientMessage('pairingExpired');
    expect(
      message.localized(lookupAppLocalizations(const Locale('en', 'US'))),
      contains('pairing request expired'),
    );
    expect(
      message.localized(lookupAppLocalizations(const Locale('pt', 'BR'))),
      contains('pareamento expirou'),
    );
  });

  test(
    'English and Brazilian Portuguese catalogs have parity and clean UTF-8',
    () {
      final en = _readCatalog('app_en.arb');
      final pt = _readCatalog('app_pt_BR.arb');
      expect(pt.keys.toSet(), en.keys.toSet());
      for (final catalog in [en, pt]) {
        for (final value in catalog.values) {
          if (value is! String) continue;
          expect(value, isNot(contains('\u00c3')));
          expect(value, isNot(contains('\u00e2\u20ac\u00a6')));
          expect(value, isNot(contains('\ufffd')));
        }
      }
      expect(pt['languagePortuguese'], 'Portugu\u00eas (Brasil)');
      expect(pt['settings'], 'Configura\u00e7\u00f5es');
      expect(pt['media'], 'M\u00eddia');
    },
  );
}

Map<String, dynamic> _readCatalog(String name) {
  final file = File('lib/l10n/$name');
  final bytes = file.readAsBytesSync();
  expect(
    bytes.length < 3 ||
        bytes[0] != 0xEF ||
        bytes[1] != 0xBB ||
        bytes[2] != 0xBF,
    isTrue,
  );
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}
