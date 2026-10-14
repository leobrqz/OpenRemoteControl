import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:open_remote_core/open_remote_core.dart';

import '../repositories/preferences_repository.dart';

enum ControlPage {
  mouse(Icons.touch_app_outlined),
  media(Icons.graphic_eq_rounded),
  keyboard(Icons.keyboard_outlined);

  const ControlPage(this.icon);
  final IconData icon;
}

enum ControlLayout { tabs, drawer }

enum ScreenOrientation { automatic, portrait, landscape }

class ClientPreferences {
  const ClientPreferences({
    this.multiTouch = true,
    this.invertScroll = false,
    this.swapButtons = false,
    this.limitMouseUpdates = true,
    this.mouseUpdateRate = 60,
    this.pinchZoom = true,
    this.doubleTapDrag = false,
    this.pointerSensitivity = 1.55,
    this.scrollSensitivity = 1,
    this.automaticDiscovery = true,
    this.updateServerAddress = true,
    this.autoReconnect = true,
    this.keepConnectionInBackground = false,
    this.showConnectionErrors = true,
    this.themeMode = ThemeMode.dark,
    this.defaultControl = ControlPage.mouse,
    this.visibleControls = const {
      ControlPage.mouse,
      ControlPage.media,
      ControlPage.keyboard,
    },
    this.controlLayout = ControlLayout.tabs,
    this.orientation = ScreenOrientation.automatic,
    this.hapticFeedback = true,
    this.fullscreen = false,
    this.keepScreenAwake = false,
    this.swipeToOpenMenu = false,
    this.language = 'en-US',
  });

  final bool multiTouch, invertScroll, swapButtons, limitMouseUpdates;
  final int mouseUpdateRate;
  final bool pinchZoom, doubleTapDrag;
  final double pointerSensitivity, scrollSensitivity;
  final bool automaticDiscovery, updateServerAddress, autoReconnect;
  final bool keepConnectionInBackground, showConnectionErrors;
  final ThemeMode themeMode;
  final ControlPage defaultControl;
  final Set<ControlPage> visibleControls;
  final ControlLayout controlLayout;
  final ScreenOrientation orientation;
  final bool hapticFeedback, fullscreen, keepScreenAwake, swipeToOpenMenu;
  final String language;
  Locale get locale =>
      language == 'pt-BR' ? const Locale('pt', 'BR') : const Locale('en', 'US');

  ClientPreferences copyWith({
    bool? multiTouch,
    bool? invertScroll,
    bool? swapButtons,
    bool? limitMouseUpdates,
    int? mouseUpdateRate,
    bool? pinchZoom,
    bool? doubleTapDrag,
    double? pointerSensitivity,
    double? scrollSensitivity,
    bool? automaticDiscovery,
    bool? updateServerAddress,
    bool? autoReconnect,
    bool? keepConnectionInBackground,
    bool? showConnectionErrors,
    ThemeMode? themeMode,
    ControlPage? defaultControl,
    Set<ControlPage>? visibleControls,
    ControlLayout? controlLayout,
    ScreenOrientation? orientation,
    bool? hapticFeedback,
    bool? fullscreen,
    bool? keepScreenAwake,
    bool? swipeToOpenMenu,
    String? language,
  }) {
    final controls = Set<ControlPage>.unmodifiable(
      visibleControls == null || visibleControls.isEmpty
          ? this.visibleControls
          : visibleControls,
    );
    final initial = defaultControl ?? this.defaultControl;
    return ClientPreferences(
      multiTouch: multiTouch ?? this.multiTouch,
      invertScroll: invertScroll ?? this.invertScroll,
      swapButtons: swapButtons ?? this.swapButtons,
      limitMouseUpdates: limitMouseUpdates ?? this.limitMouseUpdates,
      mouseUpdateRate: const {30, 60, 120}.contains(mouseUpdateRate)
          ? mouseUpdateRate!
          : this.mouseUpdateRate,
      pinchZoom: pinchZoom ?? this.pinchZoom,
      doubleTapDrag: doubleTapDrag ?? this.doubleTapDrag,
      pointerSensitivity: (pointerSensitivity ?? this.pointerSensitivity)
          .clamp(0.25, 4)
          .toDouble(),
      scrollSensitivity: (scrollSensitivity ?? this.scrollSensitivity)
          .clamp(0.25, 4)
          .toDouble(),
      automaticDiscovery: automaticDiscovery ?? this.automaticDiscovery,
      updateServerAddress: updateServerAddress ?? this.updateServerAddress,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      keepConnectionInBackground:
          keepConnectionInBackground ?? this.keepConnectionInBackground,
      showConnectionErrors: showConnectionErrors ?? this.showConnectionErrors,
      themeMode: themeMode ?? this.themeMode,
      defaultControl: controls.contains(initial) ? initial : controls.first,
      visibleControls: controls,
      controlLayout: controlLayout ?? this.controlLayout,
      orientation: orientation ?? this.orientation,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      fullscreen: fullscreen ?? this.fullscreen,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      swipeToOpenMenu: swipeToOpenMenu ?? this.swipeToOpenMenu,
      language: language == 'pt-BR' || language == 'en-US'
          ? language!
          : this.language,
    );
  }

  Map<String, Object?> toJson() => {
    'multiTouch': multiTouch,
    'invertScroll': invertScroll,
    'swapButtons': swapButtons,
    'limitMouseUpdates': limitMouseUpdates,
    'mouseUpdateRate': mouseUpdateRate,
    'pinchZoom': pinchZoom,
    'doubleTapDrag': doubleTapDrag,
    'pointerSensitivity': pointerSensitivity,
    'scrollSensitivity': scrollSensitivity,
    'automaticDiscovery': automaticDiscovery,
    'updateServerAddress': updateServerAddress,
    'autoReconnect': autoReconnect,
    'keepConnectionInBackground': keepConnectionInBackground,
    'showConnectionErrors': showConnectionErrors,
    'themeMode': themeMode.name,
    'defaultControl': defaultControl.name,
    'visibleControls': visibleControls.map((page) => page.name).toList(),
    'controlLayout': controlLayout.name,
    'orientation': orientation.name,
    'hapticFeedback': hapticFeedback,
    'fullscreen': fullscreen,
    'keepScreenAwake': keepScreenAwake,
    'swipeToOpenMenu': swipeToOpenMenu,
    'language': language,
  };

  factory ClientPreferences.fromJson(Map<String, dynamic> json) {
    bool? flag(String key) => json[key] is bool ? json[key] as bool : null;
    double? number(String key) =>
        json[key] is num && (json[key] as num).isFinite
        ? (json[key] as num).toDouble()
        : null;
    T? choice<T extends Enum>(String key, List<T> values) =>
        values.where((value) => value.name == json[key]).firstOrNull;
    final controls = json['visibleControls'];
    return const ClientPreferences().copyWith(
      multiTouch: flag('multiTouch'),
      invertScroll: flag('invertScroll'),
      swapButtons: flag('swapButtons'),
      limitMouseUpdates: flag('limitMouseUpdates'),
      mouseUpdateRate: json['mouseUpdateRate'] is int
          ? json['mouseUpdateRate'] as int
          : null,
      pinchZoom: flag('pinchZoom'),
      doubleTapDrag: flag('doubleTapDrag'),
      pointerSensitivity: number('pointerSensitivity'),
      scrollSensitivity: number('scrollSensitivity'),
      automaticDiscovery: flag('automaticDiscovery'),
      updateServerAddress: flag('updateServerAddress'),
      autoReconnect: flag('autoReconnect'),
      keepConnectionInBackground: flag('keepConnectionInBackground'),
      showConnectionErrors: flag('showConnectionErrors'),
      themeMode: choice('themeMode', ThemeMode.values),
      defaultControl: choice('defaultControl', ControlPage.values),
      visibleControls: controls is List
          ? ControlPage.values
                .where((page) => controls.contains(page.name))
                .toSet()
          : null,
      controlLayout: choice('controlLayout', ControlLayout.values),
      orientation: choice('orientation', ScreenOrientation.values),
      hapticFeedback: flag('hapticFeedback'),
      fullscreen: flag('fullscreen'),
      keepScreenAwake: flag('keepScreenAwake'),
      swipeToOpenMenu: flag('swipeToOpenMenu'),
      language: json['language'] == 'pt-BR' ? 'pt-BR' : 'en-US',
    );
  }
}

class PreferencesController extends ChangeNotifier {
  PreferencesController({
    FlutterSecureStorage? storage,
    PreferencesRepository? repository,
  }) : _repository =
           repository ?? SecurePreferencesRepository(storage: storage);

  static const storageKey = SecurePreferencesRepository.storageKey;
  final PreferencesRepository _repository;
  ClientPreferences _value = const ClientPreferences();
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;
  String? saveErrorCode;
  ClientPreferences get value => _value;

  Future<void> load() async {
    try {
      final raw = await _repository.read();
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        _value = ClientPreferences.fromJson(json);
      }
    } catch (error, stack) {
      await DiagnosticLog.record(
        'Android',
        'Não foi possível ler as preferências.',
        error: error,
        stackTrace: stack,
      );
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> update(ClientPreferences value) {
    _value = value;
    saveErrorCode = null;
    notifyListeners();
    final raw = jsonEncode(value.toJson());
    _writes = _writes.then((_) => _repository.write(raw)).catchError((
      Object error,
      StackTrace stack,
    ) async {
      saveErrorCode = 'saveFailed';
      await DiagnosticLog.record(
        'Android',
        'Failed to save client preferences.',
        error: error,
        stackTrace: stack,
      );
      if (!_disposed) notifyListeners();
    });
    return _writes;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
