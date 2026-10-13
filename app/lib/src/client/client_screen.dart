import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/diagnostic_log.dart';
import '../core/wire.dart';
import 'client_service.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final RemoteClientService _service = RemoteClientService();
  List<SavedHost> _savedHosts = const [];
  bool _loadingHosts = true;
  Timer? _discoveryTimer;
  final TextEditingController _manualAddressController =
      TextEditingController();
  final TextEditingController _manualPortController = TextEditingController(
    text: '47652',
  );

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    unawaited(_loadHosts());
    unawaited(_loadManualEndpoint());
    unawaited(_discoverHosts());
    _discoveryTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      unawaited(_discoverHosts());
    });
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    _discoveryTimer?.cancel();
    _manualAddressController.dispose();
    _manualPortController.dispose();
    _service.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHosts() async {
    final hosts = await _service.loadSavedHosts();
    if (!mounted) return;
    setState(() {
      _savedHosts = hosts;
      _loadingHosts = false;
    });
  }

  Future<void> _loadManualEndpoint() async {
    final endpoint = await _service.loadManualEndpoint();
    if (!mounted || endpoint == null) return;
    _manualAddressController.text = endpoint['address'] as String;
    _manualPortController.text = '${endpoint['port']}';
  }

  Future<void> _discoverHosts({bool showError = false}) async {
    if (_service.isDiscovering ||
        _service.isConnecting ||
        _service.isConnected) {
      return;
    }
    try {
      await _service.discoverHosts();
    } catch (error) {
      if (showError && mounted) {
        _showMessage('Falha ao procurar PCs na rede: $error');
      }
    }
  }

  Future<void> _scanAndConnect() async {
    final rawValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _PairingScannerScreen()),
    );
    if (rawValue == null || !mounted) return;
    try {
      final pairing = PairingInfo.fromQr(rawValue);
      await _service.connectFromQr(pairing);
      await _loadHosts();
    } catch (error) {
      if (mounted) _showMessage(_service.lastError ?? error.toString());
    }
  }

  Future<void> _connectSaved(SavedHost host) async {
    try {
      await _service.connectSaved(host);
    } catch (error) {
      if (mounted) _showMessage(_service.lastError ?? error.toString());
    }
  }

  Future<void> _connectDiscovered(DiscoveredHost host) async {
    try {
      await _service.connectDiscovered(host);
      await _loadHosts();
    } catch (error) {
      if (mounted) _showMessage(_service.lastError ?? error.toString());
    }
  }

  Future<void> _connectManual() async {
    final port = int.tryParse(_manualPortController.text.trim());
    if (port == null) {
      _showMessage('Digite uma porta válida. O padrão é 47652.');
      return;
    }
    try {
      await _service.connectManual(
        address: _manualAddressController.text,
        port: port,
      );
      await _loadHosts();
    } catch (error) {
      if (mounted) _showMessage(_service.lastError ?? error.toString());
    }
  }

  Future<void> _copyDiagnostics() async {
    await Clipboard.setData(ClipboardData(text: await DiagnosticLog.export()));
    if (mounted)
      _showMessage('Diagnóstico copiado para a área de transferência.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_service.isConnected) {
      return RemoteControlScreen(service: _service);
    }
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                width < 600 ? 22 : 36,
                28,
                width < 600 ? 22 : 36,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ClientHeader(),
                  const SizedBox(height: 46),
                  Text(
                    'Controle seu PC\npelo Wi‑Fi.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      height: 1.06,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pareie com o servidor Windows e controle mouse, teclado e mídia no mesmo ambiente de rede.',
                    style: TextStyle(
                      color: Color(0xFF9BAEAE),
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.wifi_find_rounded,
                                color: Color(0xFF77E4D3),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _service.isConnecting
                                    ? 'Conectando ao computador…'
                                    : _service.isDiscovering
                                    ? 'Procurando PCs na rede Wi-Fi...'
                                    : 'Nenhum PC conectado',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'O app procura automaticamente PCs com o servidor ativo neste Wi-Fi.',
                            style: TextStyle(
                              color: Color(0xFF9BAEAE),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_service.discoveredHosts.isEmpty)
                            Text(
                              _service.isDiscovering
                                  ? 'Buscando computadores...'
                                  : 'Inicie o servidor no Windows para ele aparecer aqui.',
                              style: const TextStyle(
                                color: Color(0xFF9BAEAE),
                                height: 1.45,
                              ),
                            )
                          else ...[
                            Text(
                              'COMPUTADORES ENCONTRADOS',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: const Color(0xFF77E4D3),
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            ..._service.discoveredHosts.map((host) {
                              final paired = _savedHosts.any(
                                (saved) => saved.serverId == host.serverId,
                              );
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.desktop_windows_rounded,
                                  color: Color(0xFF77E4D3),
                                ),
                                title: Text(host.name),
                                subtitle: Text(
                                  paired
                                      ? 'Pareado  •  ${host.addresses.first}'
                                      : 'O Windows pedira aprovacao',
                                ),
                                trailing: FilledButton.tonal(
                                  onPressed: _service.isConnecting
                                      ? null
                                      : () => _connectDiscovered(host),
                                  child: Text(
                                    paired ? 'Conectar' : 'Solicitar',
                                  ),
                                ),
                              );
                            }),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Procurar novamente',
                              onPressed:
                                  _service.isConnecting ||
                                      _service.isDiscovering
                                  ? null
                                  : () => _discoverHosts(showError: true),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _service.isConnecting
                                  ? null
                                  : _scanAndConnect,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Parear por QR (alternativa)'),
                            ),
                          ),
                          if (_service.lastError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _service.lastError!,
                              style: const TextStyle(
                                color: Color(0xFFFFA79B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text('Conectar por IP local'),
                      subtitle: const Text(
                        'Configuração manual; porta padrão 47652.',
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _manualAddressController,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'IP do Windows',
                                  hintText: '192.168.1.20',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _manualPortController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Porta',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _service.isConnecting
                                ? null
                                : _connectManual,
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Conectar ao Windows'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_savedHosts.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'COMPUTADORES PAREADOS',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF77E4D3),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._savedHosts.map(
                      (host) => Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF1D3A36),
                            child: Icon(
                              Icons.desktop_windows_rounded,
                              color: Color(0xFF77E4D3),
                            ),
                          ),
                          title: Text(host.name),
                          subtitle: Text(host.addresses.join('  •  ')),
                          trailing: IconButton.filledTonal(
                            tooltip: 'Conectar',
                            onPressed: _service.isConnecting
                                ? null
                                : () => _connectSaved(host),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                    ),
                  ] else if (_loadingHosts) ...[
                    const SizedBox(height: 22),
                    const Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _ClientFeatureStrip(),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _copyDiagnostics,
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('Copiar diagnóstico de conexão'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key, required this.service});

  final RemoteClientService service;

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  int _selectedPage = 0;

  void _send(Future<void> operation) {
    unawaited(operation.catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(
              Icons.desktop_windows_rounded,
              color: Color(0xFF77E4D3),
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                service.connectedAddress == null
                    ? 'PC conectado'
                    : 'PC • ${service.connectedAddress}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Desconectar',
            onPressed: service.disconnect,
            icon: const Icon(Icons.link_off_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedPage,
          children: [
            _MouseControl(send: _send, service: service),
            _MediaControl(send: _send, service: service),
            _KeyboardControl(send: _send, service: service),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedPage,
        onDestinationSelected: (index) => setState(() => _selectedPage = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.touch_app_outlined),
            selectedIcon: Icon(Icons.touch_app_rounded),
            label: 'Mouse',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_outlined),
            selectedIcon: Icon(Icons.graphic_eq_rounded),
            label: 'Mídia',
          ),
          NavigationDestination(
            icon: Icon(Icons.keyboard_outlined),
            selectedIcon: Icon(Icons.keyboard_rounded),
            label: 'Teclado',
          ),
        ],
      ),
    );
  }
}

typedef _SendOperation = void Function(Future<void> operation);

class _MouseControl extends StatefulWidget {
  const _MouseControl({required this.send, required this.service});

  final _SendOperation send;
  final RemoteClientService service;

  @override
  State<_MouseControl> createState() => _MouseControlState();
}

class _MouseControlState extends State<_MouseControl> {
  bool _dragMode = false;
  bool _dragging = false;

  void _startDrag() {
    if (!_dragMode || _dragging) return;
    _dragging = true;
    widget.send(widget.service.sendMouseButton('left', true));
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    widget.send(widget.service.sendMouseButton('left', false));
  }

  @override
  void dispose() {
    _endDrag();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => _startDrag(),
              onPanUpdate: (details) => widget.send(
                widget.service.sendMouseMove(
                  details.delta.dx * 1.55,
                  details.delta.dy * 1.55,
                ),
              ),
              onPanEnd: (_) => _endDrag(),
              onPanCancel: _endDrag,
              onTap: () => _click(widget.service, widget.send, 'left'),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF182225),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF344244)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      color: Color(0xFF77E4D3),
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _dragMode
                          ? 'Arraste para mover e selecionar'
                          : 'Deslize para mover o cursor',
                      style: const TextStyle(color: Color(0xFFB6C4C2)),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Toque para clicar',
                      style: TextStyle(color: Color(0xFF718584), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              avatar: const Icon(Icons.drag_indicator_rounded, size: 18),
              label: const Text('Arrastar para selecionar'),
              selected: _dragMode,
              onSelected: (selected) {
                if (!selected) _endDrag();
                setState(() => _dragMode = selected);
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _MouseButton(
                  icon: Icons.mouse_rounded,
                  label: 'Esquerdo',
                  onPressed: () => _click(widget.service, widget.send, 'left'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MouseButton(
                  icon: Icons.mouse_rounded,
                  label: 'Direito',
                  onPressed: () => _click(widget.service, widget.send, 'right'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 180,
            child: _MouseButton(
              icon: Icons.mouse_rounded,
              label: 'Meio',
              onPressed: () => _click(widget.service, widget.send, 'middle'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.send(widget.service.sendScroll(120)),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  label: const Text('Rolar para cima'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.send(widget.service.sendScroll(-120)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  label: const Text('Rolar para baixo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _click(
    RemoteClientService service,
    _SendOperation send,
    String button,
  ) {
    send(service.sendMouseButton(button, true));
    send(service.sendMouseButton(button, false));
  }
}

class _MouseButton extends StatelessWidget {
  const _MouseButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

class _MediaControl extends StatelessWidget {
  const _MediaControl({required this.send, required this.service});

  final _SendOperation send;
  final RemoteClientService service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Text(
            'Controles de mídia',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Volume e reprodução no computador',
            style: TextStyle(color: Color(0xFF9BAEAE)),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MediaButton(
                icon: Icons.volume_down_rounded,
                label: 'Diminuir',
                onPressed: () => send(service.sendMedia('volumeDown')),
              ),
              const SizedBox(width: 18),
              _MediaButton(
                icon: Icons.volume_off_rounded,
                label: 'Mudo',
                onPressed: () => send(service.sendMedia('volumeMute')),
              ),
              const SizedBox(width: 18),
              _MediaButton(
                icon: Icons.volume_up_rounded,
                label: 'Aumentar',
                onPressed: () => send(service.sendMedia('volumeUp')),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MediaButton(
                icon: Icons.skip_previous_rounded,
                label: 'Anterior',
                onPressed: () => send(service.sendMedia('previousTrack')),
              ),
              const SizedBox(width: 26),
              _MediaButton(
                icon: Icons.play_arrow_rounded,
                label: 'Pausar / tocar',
                prominent: true,
                onPressed: () => send(service.sendMedia('playPause')),
              ),
              const SizedBox(width: 26),
              _MediaButton(
                icon: Icons.skip_next_rounded,
                label: 'Próxima',
                onPressed: () => send(service.sendMedia('nextTrack')),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'Os comandos são enviados como teclas de mídia do Windows.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF718584), fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          iconSize: prominent ? 36 : 28,
          padding: EdgeInsets.all(prominent ? 20 : 15),
          icon: Icon(icon),
          style: prominent
              ? IconButton.styleFrom(
                  backgroundColor: const Color(0xFF77E4D3),
                  foregroundColor: const Color(0xFF101719),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9BAEAE), fontSize: 12),
        ),
      ],
    );
  }
}

class _KeyboardControl extends StatefulWidget {
  const _KeyboardControl({required this.send, required this.service});

  final _SendOperation send;
  final RemoteClientService service;

  @override
  State<_KeyboardControl> createState() => _KeyboardControlState();
}

class _KeyboardControlState extends State<_KeyboardControl> {
  final TextEditingController _controller = TextEditingController();
  final Set<String> _activeModifiers = {};

  @override
  void dispose() {
    for (final modifier in _activeModifiers) {
      widget.send(widget.service.sendModifier(modifier, false));
    }
    _controller.dispose();
    super.dispose();
  }

  void _sendText() {
    final text = _controller.text;
    if (text.isEmpty) return;
    widget.send(widget.service.sendText(text));
    _controller.clear();
  }

  void _setModifier(String key, bool pressed) {
    setState(() {
      if (pressed) {
        _activeModifiers.add(key);
      } else {
        _activeModifiers.remove(key);
      }
    });
    widget.send(widget.service.sendModifier(key, pressed));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      children: [
        Text(
          'Enviar texto',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Digite no celular e envie o texto para a janela ativa no Windows.',
          style: TextStyle(color: Color(0xFF9BAEAE), height: 1.4),
        ),
        const SizedBox(height: 18),
        const Text(
          'Mantenha um modificador ativo e toque numa tecla para atalhos.',
          style: TextStyle(color: Color(0xFF9BAEAE), height: 1.4),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 9,
          runSpacing: 8,
          children: [
            _ModifierChip(
              label: 'Ctrl',
              selected: _activeModifiers.contains('control'),
              onSelected: (pressed) => _setModifier('control', pressed),
            ),
            _ModifierChip(
              label: 'Alt',
              selected: _activeModifiers.contains('alt'),
              onSelected: (pressed) => _setModifier('alt', pressed),
            ),
            _ModifierChip(
              label: 'Shift',
              selected: _activeModifiers.contains('shift'),
              onSelected: (pressed) => _setModifier('shift', pressed),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
                decoration: const InputDecoration(
                  hintText: 'Digite aqui…',
                  prefixIcon: Icon(Icons.keyboard_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Enviar texto',
              onPressed: _sendText,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          'TECLAS RÁPIDAS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF77E4D3),
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _KeyChip('Enter', 'enter', widget.send, widget.service),
            _KeyChip('Backspace', 'backspace', widget.send, widget.service),
            _KeyChip('Tab', 'tab', widget.send, widget.service),
            _KeyChip('Esc', 'escape', widget.send, widget.service),
            _KeyChip('Espaço', 'space', widget.send, widget.service),
            _KeyChip('←', 'arrowLeft', widget.send, widget.service),
            _KeyChip('↑', 'arrowUp', widget.send, widget.service),
            _KeyChip('↓', 'arrowDown', widget.send, widget.service),
            _KeyChip('→', 'arrowRight', widget.send, widget.service),
            _KeyChip('Delete', 'delete', widget.send, widget.service),
            _KeyChip('Home', 'home', widget.send, widget.service),
            _KeyChip('End', 'end', widget.send, widget.service),
            _KeyChip('PgUp', 'pageUp', widget.send, widget.service),
            _KeyChip('PgDn', 'pageDown', widget.send, widget.service),
            _KeyChip('Insert', 'insert', widget.send, widget.service),
            _KeyChip('Caps', 'capsLock', widget.send, widget.service),
            ...List.generate(12, (index) {
              final number = index + 1;
              return _KeyChip(
                'F$number',
                'f$number',
                widget.send,
                widget.service,
              );
            }),
            ...List.generate(26, (index) {
              final keyName = String.fromCharCode(0x61 + index);
              return _KeyChip(
                keyName.toUpperCase(),
                keyName,
                widget.send,
                widget.service,
              );
            }),
            ...List.generate(10, (index) {
              final keyName = index.toString();
              return _KeyChip(keyName, keyName, widget.send, widget.service);
            }),
          ],
        ),
      ],
    );
  }
}

class _ModifierChip extends StatelessWidget {
  const _ModifierChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
  );
}

class _KeyChip extends StatelessWidget {
  const _KeyChip(this.label, this.keyName, this.send, this.service);

  final String label;
  final String keyName;
  final _SendOperation send;
  final RemoteClientService service;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label),
    onPressed: () => send(service.sendKey(keyName)),
  );
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF1D3A36),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.cast_connected_rounded,
          color: Color(0xFF77E4D3),
          size: 22,
        ),
      ),
      const SizedBox(width: 12),
      Text(
        'Open Remote',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const Spacer(),
      const _ClientChip(label: 'ANDROID'),
    ],
  );
}

class _ClientFeatureStrip extends StatelessWidget {
  const _ClientFeatureStrip();

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _ClientChip(label: 'MOUSE'),
      _ClientChip(label: 'TECLADO'),
      _ClientChip(label: 'VOLUME'),
      _ClientChip(label: 'MÍDIA'),
      _ClientChip(label: 'SEM BLUETOOTH'),
    ],
  );
}

class _ClientChip extends StatelessWidget {
  const _ClientChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF202A2C),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: const Color(0xFF344244)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9BAEAE),
          fontSize: 10,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _PairingScannerScreen extends StatefulWidget {
  const _PairingScannerScreen();

  @override
  State<_PairingScannerScreen> createState() => _PairingScannerScreenState();
}

class _PairingScannerScreenState extends State<_PairingScannerScreen> {
  bool _didScan = false;

  void _onDetect(BarcodeCapture capture) {
    if (_didScan) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere((value) => value.startsWith('{'), orElse: () => '');
    if (raw.isEmpty) return;
    _didScan = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parear com o Windows')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF77E4D3), width: 3),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xE6101719),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Aponte a câmera para o QR que aparece no servidor Windows.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
