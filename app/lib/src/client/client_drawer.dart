import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'client_destination.dart';
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
  });
  final ClientDestination destination;
  final ControlPage control;
  final ClientPreferences preferences;
  final bool hasSession;
  final void Function(ClientDestination, ControlPage?) select;
  final String language;
  final ValueChanged<String> onLanguageChanged;

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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language),
                      const SizedBox(width: 16),
                      Expanded(child: Text(l10n.language)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: language,
                      isExpanded: true,
                      itemHeight: null,
                      items: [
                        DropdownMenuItem(
                          value: 'en-US',
                          child: Text(
                            l10n.languageEnglish,
                            maxLines: 2,
                            softWrap: true,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'pt-BR',
                          child: Text(
                            l10n.languagePortuguese,
                            maxLines: 2,
                            softWrap: true,
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onLanguageChanged(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
