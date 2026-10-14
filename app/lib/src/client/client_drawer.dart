import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'client_destination.dart';
import 'client_language_flag.dart';
import 'client_localization.dart';
import 'preferences/client_preferences.dart';

export 'client_destination.dart';

class ClientDrawer extends StatelessWidget {
  const ClientDrawer({
    super.key,
    required this.destination,
    required this.control,
    required this.preferences,
    required this.hasSession,
    required this.select,
    required this.language,
    required this.onLanguageChanged,
    this.version,
  });
  final ClientDestination destination;
  final ControlPage control;
  final ClientPreferences preferences;
  final bool hasSession;
  final void Function(ClientDestination, ControlPage?) select;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 24),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Image.asset(
                            'assets/branding/mark.png',
                            excludeFromSemantics: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Open Remote',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.computer_outlined),
                    title: Text(l10n.computers),
                    selected: destination == ClientDestination.computers,
                    onTap: () => select(ClientDestination.computers, null),
                  ),
                  const Divider(),
                  for (final page in ControlPage.values.where(
                    preferences.visibleControls.contains,
                  ))
                    ListTile(
                      leading: Icon(page.icon),
                      title: Text(page.localizedLabel(l10n)),
                      enabled: hasSession,
                      selected:
                          destination == ClientDestination.controls &&
                          page == control,
                      onTap: () => select(ClientDestination.controls, page),
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(l10n.settings),
                    selected: destination == ClientDestination.settings,
                    onTap: () => select(ClientDestination.settings, null),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.about),
              selected: destination == ClientDestination.about,
              onTap: () => select(ClientDestination.about, null),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Semantics(
                container: true,
                label: l10n.language,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LanguageOption(
                      language: 'pt-BR',
                      name: l10n.languagePortuguese,
                      selected: language == 'pt-BR',
                      flag: const BrazilFlagPainter(),
                      onTap: () => onLanguageChanged('pt-BR'),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: ExcludeSemantics(child: Text('|')),
                    ),
                    _LanguageOption(
                      language: 'en-US',
                      name: l10n.languageEnglish,
                      selected: language == 'en-US',
                      flag: const UnitedStatesFlagPainter(),
                      onTap: () => onLanguageChanged('en-US'),
                    ),
                  ],
                ),
              ),
            ),
            if (version != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    'v$version',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.name,
    required this.selected,
    required this.flag,
    required this.onTap,
  });

  final String language;
  final String name;
  final bool selected;
  final CustomPainter flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: Tooltip(
        message: name,
        child: InkWell(
          key: ValueKey('language-$language'),
          borderRadius: BorderRadius.circular(8),
          onTap: selected ? null : onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: CustomPaint(size: const Size(20, 14), painter: flag),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 18,
                  height: 2,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
