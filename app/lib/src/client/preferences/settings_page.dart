import 'dart:async';

import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: [
      for (final section in _Section.values)
        ListTile(
          leading: Icon(section.icon),
          title: Text(section.label),
          subtitle: Text(section.description),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, section),
        ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.computer_outlined),
        title: const Text('Gerenciar computadores'),
        onTap: onComputers,
      ),
      ListTile(
        leading: const Icon(Icons.copy_outlined),
        title: const Text('Copiar diagnóstico'),
        onTap: onDiagnostics,
      ),
      ListTile(
        leading: const Icon(Icons.restore_rounded),
        title: const Text('Restaurar configurações'),
        onTap: () async {
          final restore = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Restaurar configurações?'),
              content: const Text('Os computadores pareados serão mantidos.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Restaurar'),
                ),
              ],
            ),
          );
          if (restore == true) {
            await preferences.update(const ClientPreferences());
          }
        },
      ),
      ListenableBuilder(
        listenable: preferences,
        builder: (context, _) => preferences.saveError == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  preferences.saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
      ),
    ],
  );
}

enum _Section {
  mouse('Mouse', 'Gestos, sensibilidade e botões', Icons.mouse_outlined),
  connection(
    'Conexão',
    'Descoberta, reconexão e segundo plano',
    Icons.wifi_rounded,
  ),
  appearance(
    'Aparência e controles',
    'Tema, navegação e tela',
    Icons.tune_rounded,
  );

  const _Section(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
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
          const SnackBar(
            content: Text(
              'Permita as notificações para manter a conexão em segundo plano.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível ativar a conexão em segundo plano.',
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
    String title,
    T value,
    Map<T, String> choices,
    ValueChanged<T> changed,
  ) => ListTile(
    title: Text(title),
    subtitle: Text(choices[value]!),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      final selected = await showDialog<T>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            RadioGroup<T>(
              groupValue: value,
              onChanged: (choice) => Navigator.pop(context, choice),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in choices.entries)
                    RadioListTile<T>(
                      title: Text(entry.value),
                      value: entry.key,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
      if (selected != null && mounted) changed(selected);
    },
  );

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
            Text('${value.toStringAsFixed(2)}×'),
          ],
        ),
        Slider(
          value: value,
          min: 0.25,
          max: 4,
          divisions: 75,
          label: '${value.toStringAsFixed(2)}×',
          onChanged: changed,
        ),
      ],
    ),
  );

  List<Widget> _mouse(ClientPreferences p) => [
    _toggle(
      'Multi-touch',
      'Dois dedos para rolar; toque com dois dedos para o botão secundário.',
      p.multiTouch,
      (v) => _save(p.copyWith(multiTouch: v)),
    ),
    _toggle(
      'Inverter rolagem',
      null,
      p.invertScroll,
      (v) => _save(p.copyWith(invertScroll: v)),
    ),
    _toggle(
      'Inverter botões',
      'Trocar os botões primário e secundário.',
      p.swapButtons,
      (v) => _save(p.copyWith(swapButtons: v)),
    ),
    _toggle(
      'Limitar atualizações do mouse',
      null,
      p.limitMouseUpdates,
      (v) => _save(p.copyWith(limitMouseUpdates: v)),
    ),
    if (p.limitMouseUpdates)
      _choice(
        'Atualizações por segundo',
        p.mouseUpdateRate,
        const {30: '30', 60: '60', 120: '120'},
        (v) => _save(p.copyWith(mouseUpdateRate: v)),
      ),
    _toggle(
      'Zoom com gestos',
      'Pinça para ampliar ou reduzir.',
      p.pinchZoom,
      p.multiTouch ? (v) => _save(p.copyWith(pinchZoom: v)) : null,
    ),
    _sensitivity(
      'Sensibilidade do ponteiro',
      p.pointerSensitivity,
      (v) => _save(p.copyWith(pointerSensitivity: v)),
    ),
    _sensitivity(
      'Sensibilidade da rolagem',
      p.scrollSensitivity,
      (v) => _save(p.copyWith(scrollSensitivity: v)),
    ),
    _toggle(
      'Arrastar com toque duplo',
      'Toque duas vezes e mantenha o segundo toque para arrastar.',
      p.doubleTapDrag,
      (v) => _save(p.copyWith(doubleTapDrag: v)),
    ),
    _toggle(
      'Abrir menu deslizando',
      'Desative para evitar abrir o menu ao usar o mouse.',
      p.swipeToOpenMenu,
      (v) => _save(p.copyWith(swipeToOpenMenu: v)),
    ),
    ListTile(
      leading: const Icon(Icons.touch_app_outlined),
      title: const Text('Testar mouse'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        widget.onTestMouse();
      },
    ),
  ];

  List<Widget> _connection(ClientPreferences p) => [
    _toggle(
      'Descoberta automática',
      'Procurar computadores na rede Wi-Fi.',
      p.automaticDiscovery,
      (v) => _save(p.copyWith(automaticDiscovery: v)),
    ),
    _toggle(
      'Atualizar IP dos computadores',
      'Salvar o endereço encontrado quando o IP mudar.',
      p.updateServerAddress,
      (v) => _save(p.copyWith(updateServerAddress: v)),
    ),
    _toggle(
      'Reconectar automaticamente',
      'Tentar novamente quando a conexão cair.',
      p.autoReconnect,
      (v) => _save(p.copyWith(autoReconnect: v)),
    ),
    _toggle(
      'Manter conexão em segundo plano',
      'Exibir uma notificação enquanto o PC estiver conectado.',
      p.keepConnectionInBackground,
      _requestingBackground ? null : _background,
    ),
    _toggle(
      'Mostrar erros de conexão',
      null,
      p.showConnectionErrors,
      (v) => _save(p.copyWith(showConnectionErrors: v)),
    ),
  ];

  List<Widget> _appearance(ClientPreferences p) => [
    _choice('Tema', p.themeMode, const {
      ThemeMode.system: 'Sistema',
      ThemeMode.light: 'Claro',
      ThemeMode.dark: 'Escuro',
    }, (v) => _save(p.copyWith(themeMode: v))),
    _choice(
      'Controle inicial',
      p.defaultControl,
      {
        for (final page in ControlPage.values.where(p.visibleControls.contains))
          page: page.label,
      },
      (v) => _save(p.copyWith(defaultControl: v)),
    ),
    _choice(
      'Navegação dos controles',
      p.controlLayout,
      const {
        ControlLayout.tabs: 'Barra inferior',
        ControlLayout.drawer: 'Menu lateral',
      },
      (v) => _save(p.copyWith(controlLayout: v)),
    ),
    const Divider(),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        'Controles visíveis',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ),
    for (final page in ControlPage.values)
      CheckboxListTile(
        title: Text(page.label),
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
    _choice('Orientação da tela', p.orientation, const {
      ScreenOrientation.automatic: 'Automática',
      ScreenOrientation.portrait: 'Retrato',
      ScreenOrientation.landscape: 'Paisagem',
    }, (v) => _save(p.copyWith(orientation: v))),
    _toggle(
      'Retorno vibratório',
      'Vibrar ao clicar e enviar comandos.',
      p.hapticFeedback,
      (v) => _save(p.copyWith(hapticFeedback: v)),
    ),
    _toggle(
      'Tela inteira',
      'Ocultar as barras do sistema.',
      p.fullscreen,
      (v) => _save(p.copyWith(fullscreen: v)),
    ),
    _toggle(
      'Manter tela acesa',
      'Enquanto um controle estiver aberto.',
      p.keepScreenAwake,
      (v) => _save(p.copyWith(keepScreenAwake: v)),
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.section.label)),
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
