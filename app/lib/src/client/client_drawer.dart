import 'package:flutter/material.dart';

import 'client_destination.dart';
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
  });
  final ClientDestination destination;
  final ControlPage control;
  final ClientPreferences preferences;
  final bool hasSession;
  final void Function(ClientDestination, ControlPage?) select;

  @override
  Widget build(BuildContext context) => Drawer(
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
                  title: const Text('Computadores'),
                  selected: destination == ClientDestination.computers,
                  onTap: () => select(ClientDestination.computers, null),
                ),
                const Divider(),
                for (final page in ControlPage.values.where(
                  preferences.visibleControls.contains,
                ))
                  ListTile(
                    leading: Icon(page.icon),
                    title: Text(page.label),
                    enabled: hasSession,
                    selected:
                        destination == ClientDestination.controls &&
                        page == control,
                    onTap: () => select(ClientDestination.controls, page),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configurações'),
                  selected: destination == ClientDestination.settings,
                  onTap: () => select(ClientDestination.settings, null),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            selected: destination == ClientDestination.about,
            onTap: () => select(ClientDestination.about, null),
          ),
        ],
      ),
    ),
  );
}
