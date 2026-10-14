import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_remote_core/open_remote_core.dart';
import 'package:open_remote_control/l10n/app_localizations.dart';

import '../client_localization.dart';
import 'client_platform.dart';
import 'client_preferences.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.onComputers,
    required this.onTestMouse,
    required this.onDiagnostics,
  });
  final PreferencesController preferences;
  final VoidCallback onComputers, onTestMouse, onDiagnostics;

  void _open(BuildContext context, _Section section) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _SettingsSection(
            preferences: preferences,
            section: section,
            onTestMouse: onTestMouse,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final section in _Section.values)
          ListTile(
            leading: Icon(section.icon),
            title: Text(section.label(l10n)),
            subtitle: Text(section.description(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, section),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.computer_outlined),
          title: Text(l10n.manageComputers),
          onTap: onComputers,
        ),
        ListTile(
          leading: const Icon(Icons.copy_outlined),
          title: Text(l10n.copyDiagnostics),
          onTap: onDiagnostics,
        ),
        ListTile(
          leading: const Icon(Icons.restore_rounded),
          title: Text(l10n.restoreSettings),
          onTap: () async {
            final restore = await showDialog<bool>(
              context: context,
              builder: (context) {
                final dialogL10n = AppLocalizations.of(context)!;
                return AlertDialog(
                  title: Text(dialogL10n.restoreSettingsQuestion),
                  content: Text(dialogL10n.pairedComputersKept),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(dialogL10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(dialogL10n.restore),
                    ),
                  ],
                );
              },
            );
            if (restore == true) {
              await preferences.update(
                ClientPreferences().copyWith(
                  language: preferences.value.language,
                ),
              );
            }
          },
        ),
        ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => preferences.saveErrorCode == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.saveFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

enum _Section { mouse, connection, appearance }

extension on _Section {
  IconData get icon => switch (this) {
    _Section.mouse => Icons.mouse_outlined,
    _Section.connection => Icons.wifi_rounded,
    _Section.appearance => Icons.tune_rounded,
  };

  String label(AppLocalizations l10n) => switch (this) {
    _Section.mouse => l10n.mouseSettings,
    _Section.connection => l10n.connectionSettings,
    _Section.appearance => l10n.appearanceSettings,
  };

  String description(AppLocalizations l10n) => switch (this) {
    _Section.mouse => l10n.mouseSettingsDescription,
    _Section.connection => l10n.connectionSettingsDescription,
    _Section.appearance => l10n.appearanceSettingsDescription,
  };
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    required this.preferences,
    required this.section,
    required this.onTestMouse,
  });
  final PreferencesController preferences;
  final _Section section;
  final VoidCallback onTestMouse;
  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  bool _requestingBackground = false;
  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  void _save(ClientPreferences value) =>
      unawaited(widget.preferences.update(value));

  Future<void> _background(bool enabled) async {
    if (!enabled) {
      _save(
        widget.preferences.value.copyWith(keepConnectionInBackground: false),
      );
      return;
    }
    setState(() => _requestingBackground = true);
    try {
      final allowed = await ClientPlatform.requestBackgroundPermission();
      if (!mounted) return;
      if (allowed) {
        _save(
          widget.preferences.value.copyWith(keepConnectionInBackground: true),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(
                AppLocalizations.of(context)!.notificationPermissionBackground,
              ),
            ),
          ),
        );
      }
    } catch (error, stack) {
      try {
        await DiagnosticLog.record(
          'Android',
          'Failed to enable background connection.',
          error: error,
          stackTrace: stack,
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) => Text(
                AppLocalizations.of(context)!.backgroundConnectionFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingBackground = false);
    }
  }

  Widget _toggle(
    String title,
    String? description,
    bool value,
    ValueChanged<bool>? changed,
  ) => SwitchListTile(
    title: Text(title),
    subtitle: description == null ? null : Text(description),
    value: value,
    onChanged: changed,
  );

  Widget _choice<T>(
    String Function(AppLocalizations) titleFor,
    T value,
    Map<T, String> Function(AppLocalizations) choicesFor,
    ValueChanged<T> changed,
  ) {
    final title = titleFor(_l10n);
    final choices = choicesFor(_l10n);
    return ListTile(
      title: Text(title),
      subtitle: Text(choices[value]!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final selected = await showDialog<T>(
          context: context,
          builder: (dialogContext) {
            final dialogL10n = AppLocalizations.of(dialogContext)!;
            final dialogChoices = choicesFor(dialogL10n);
            return SimpleDialog(
              title: Text(titleFor(dialogL10n)),
              children: [
                RadioGroup<T>(
                  groupValue: value,
                  onChanged: (choice) => Navigator.pop(dialogContext, choice),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in dialogChoices.entries)
                        RadioListTile<T>(
                          title: Text(entry.value),
                          value: entry.key,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
        if (selected != null && mounted) changed(selected);
      },
    );
  }

  Widget _sensitivity(
    String title,
    double value,
    ValueChanged<double> changed,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(_multiplier(value)),
          ],
        ),
        Slider(
          value: value,
          min: 0.25,
          max: 4,
          divisions: 75,
          label: _multiplier(value),
          onChanged: changed,
        ),
      ],
    ),
  );

  String _multiplier(double value) =>
      '${NumberFormat.decimalPatternDigits(locale: _l10n.localeName, decimalDigits: 2).format(value)}\u00D7';

  List<Widget> _mouse(ClientPreferences p) => [
    _toggle(
      _l10n.multiTouch,
      _l10n.multiTouchDescription,
      p.multiTouch,
      (v) => _save(p.copyWith(multiTouch: v)),
    ),
    _toggle(
      _l10n.invertScroll,
      null,
      p.invertScroll,
      (v) => _save(p.copyWith(invertScroll: v)),
    ),
    _toggle(
      _l10n.swapButtons,
      _l10n.swapButtonsDescription,
      p.swapButtons,
      (v) => _save(p.copyWith(swapButtons: v)),
    ),
    _toggle(
      _l10n.limitMouseUpdates,
      null,
      p.limitMouseUpdates,
      (v) => _save(p.copyWith(limitMouseUpdates: v)),
    ),
    if (p.limitMouseUpdates)
      _choice(
        (l10n) => l10n.updatesPerSecond,
        p.mouseUpdateRate,
        (_) => const {30: '30', 60: '60', 120: '120'},
        (v) => _save(p.copyWith(mouseUpdateRate: v)),
      ),
    _toggle(
      _l10n.gestureZoom,
      _l10n.gestureZoomDescription,
      p.pinchZoom,
      p.multiTouch ? (v) => _save(p.copyWith(pinchZoom: v)) : null,
    ),
    _sensitivity(
      _l10n.pointerSensitivity,
      p.pointerSensitivity,
      (v) => _save(p.copyWith(pointerSensitivity: v)),
    ),
    _sensitivity(
      _l10n.scrollSensitivity,
      p.scrollSensitivity,
      (v) => _save(p.copyWith(scrollSensitivity: v)),
    ),
    _toggle(
      _l10n.doubleTapDrag,
      _l10n.doubleTapDragDescription,
      p.doubleTapDrag,
      (v) => _save(p.copyWith(doubleTapDrag: v)),
    ),
    _toggle(
      _l10n.swipeToOpenMenu,
      _l10n.swipeToOpenMenuDescription,
      p.swipeToOpenMenu,
      (v) => _save(p.copyWith(swipeToOpenMenu: v)),
    ),
    ListTile(
      leading: const Icon(Icons.touch_app_outlined),
      title: Text(_l10n.testMouse),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        widget.onTestMouse();
      },
    ),
  ];

  List<Widget> _connection(ClientPreferences p) => [
    _toggle(
      _l10n.automaticDiscovery,
      _l10n.automaticDiscoveryDescription,
      p.automaticDiscovery,
      (v) => _save(p.copyWith(automaticDiscovery: v)),
    ),
    _toggle(
      _l10n.updateComputerIp,
      _l10n.updateComputerIpDescription,
      p.updateServerAddress,
      (v) => _save(p.copyWith(updateServerAddress: v)),
    ),
    _toggle(
      _l10n.automaticReconnect,
      _l10n.automaticReconnectDescription,
      p.autoReconnect,
      (v) => _save(p.copyWith(autoReconnect: v)),
    ),
    _toggle(
      _l10n.keepBackgroundConnection,
      _l10n.keepBackgroundConnectionDescription,
      p.keepConnectionInBackground,
      _requestingBackground ? null : _background,
    ),
    _toggle(
      _l10n.showConnectionErrors,
      null,
      p.showConnectionErrors,
      (v) => _save(p.copyWith(showConnectionErrors: v)),
    ),
  ];

  List<Widget> _appearance(ClientPreferences p) => [
    _choice(
      (l10n) => l10n.theme,
      p.themeMode,
      (l10n) => {
        ThemeMode.system: l10n.system,
        ThemeMode.light: l10n.light,
        ThemeMode.dark: l10n.dark,
      },
      (v) => _save(p.copyWith(themeMode: v)),
    ),
    _choice(
      (l10n) => l10n.initialControl,
      p.defaultControl,
      (l10n) => {
        for (final page in ControlPage.values.where(p.visibleControls.contains))
          page: page.localizedLabel(l10n),
      },
      (v) => _save(p.copyWith(defaultControl: v)),
    ),
    _choice(
      (l10n) => l10n.controlNavigation,
      p.controlLayout,
      (l10n) => {
        ControlLayout.tabs: l10n.bottomBar,
        ControlLayout.drawer: l10n.sideMenu,
      },
      (v) => _save(p.copyWith(controlLayout: v)),
    ),
    const Divider(),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        _l10n.visibleControls,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
    for (final page in ControlPage.values)
      CheckboxListTile(
        title: Text(page.localizedLabel(_l10n)),
        secondary: Icon(page.icon),
        value: p.visibleControls.contains(page),
        onChanged:
            p.visibleControls.length == 1 && p.visibleControls.contains(page)
            ? null
            : (enabled) {
                final visible = {...p.visibleControls};
                if (enabled == true) {
                  visible.add(page);
                } else {
                  visible.remove(page);
                }
                _save(p.copyWith(visibleControls: visible));
              },
      ),
    const Divider(),
    _choice(
      (l10n) => l10n.screenOrientation,
      p.orientation,
      (l10n) => {
        ScreenOrientation.automatic: l10n.automatic,
        ScreenOrientation.portrait: l10n.portrait,
        ScreenOrientation.landscape: l10n.landscape,
      },
      (v) => _save(p.copyWith(orientation: v)),
    ),
    _toggle(
      _l10n.hapticFeedback,
      _l10n.hapticFeedbackDescription,
      p.hapticFeedback,
      (v) => _save(p.copyWith(hapticFeedback: v)),
    ),
    _toggle(
      _l10n.fullscreen,
      _l10n.fullscreenDescription,
      p.fullscreen,
      (v) => _save(p.copyWith(fullscreen: v)),
    ),
    _toggle(
      _l10n.keepScreenAwake,
      _l10n.keepScreenAwakeDescription,
      p.keepScreenAwake,
      (v) => _save(p.copyWith(keepScreenAwake: v)),
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.section.label(_l10n))),
    body: ListenableBuilder(
      listenable: widget.preferences,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: switch (widget.section) {
          _Section.mouse => _mouse(widget.preferences.value),
          _Section.connection => _connection(widget.preferences.value),
          _Section.appearance => _appearance(widget.preferences.value),
        },
      ),
    ),
  );
}
