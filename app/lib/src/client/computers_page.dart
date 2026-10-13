import 'package:flutter/material.dart';

import '../core/wire.dart';
import 'client_service.dart';

class ComputersPage extends StatelessWidget {
  const ComputersPage({
    super.key,
    required this.service,
    required this.savedHosts,
    required this.loading,
    required this.showErrors,
    required this.onConnectSaved,
    required this.onConnectDiscovered,
    required this.onOpenControls,
    required this.onForget,
    required this.onAdd,
  });
  final RemoteClientService service;
  final List<SavedHost> savedHosts;
  final bool loading, showErrors;
  final ValueChanged<SavedHost> onConnectSaved, onForget;
  final ValueChanged<DiscoveredHost> onConnectDiscovered;
  final VoidCallback onOpenControls, onAdd;

  Widget _computer(
    BuildContext context, {
    required String id,
    required String name,
    required String address,
    required bool paired,
    required VoidCallback connect,
    SavedHost? saved,
  }) {
    final connected =
        service.isConnected && service.currentHost?.serverId == id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Icon(
            Icons.computer_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${connected
                ? 'Conectado'
                : paired
                ? 'Pareado'
                : 'Disponível'} · $address',
          ),
          onTap: service.isConnecting
              ? null
              : connected
              ? onOpenControls
              : connect,
          trailing: PopupMenuButton<String>(
            tooltip: 'Opções do computador',
            enabled: !service.isConnecting,
            onSelected: (choice) {
              if (choice == 'forget' && saved != null) {
                onForget(saved);
              } else {
                connected ? onOpenControls() : connect();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'connect',
                child: Text(
                  connected
                      ? 'Abrir controles'
                      : paired
                      ? 'Conectar'
                      : 'Solicitar conexão',
                ),
              ),
              if (saved != null)
                const PopupMenuItem(
                  value: 'forget',
                  child: Text('Esquecer computador'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final found = service.discoveredHosts;
    final unseen = savedHosts.where(
      (saved) => !found.any((host) => host.serverId == saved.serverId),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (service.isDiscovering || service.isConnecting || loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                service.isConnecting
                    ? 'Conectando…'
                    : 'Procurando computadores…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            if (found.isEmpty && savedHosts.isEmpty && !loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.computer_outlined, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum computador encontrado',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inicie o servidor no PC e conecte os dois à mesma rede Wi-Fi.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar computador'),
                    ),
                  ],
                ),
              ),
            for (final host in found)
              _computer(
                context,
                id: host.serverId,
                name: host.name,
                address: host.addresses.first,
                paired: savedHosts.any(
                  (saved) => saved.serverId == host.serverId,
                ),
                saved: savedHosts
                    .where((saved) => saved.serverId == host.serverId)
                    .firstOrNull,
                connect: () => onConnectDiscovered(host),
              ),
            for (final host in unseen)
              _computer(
                context,
                id: host.serverId,
                name: host.name,
                address: host.addresses.first,
                paired: true,
                saved: host,
                connect: () => onConnectSaved(host),
              ),
            if (showErrors && service.lastError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  service.lastError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
