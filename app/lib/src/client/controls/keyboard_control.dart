import 'package:flutter/material.dart';

import 'remote_actions.dart';

class KeyboardControl extends StatefulWidget {
  const KeyboardControl({
    super.key,
    required this.actions,
    required this.active,
  });
  final RemoteActions actions;
  final bool active;
  @override
  State<KeyboardControl> createState() => _KeyboardControlState();
}

class _KeyboardControlState extends State<KeyboardControl> {
  final _controller = TextEditingController();
  final Set<String> _modifiers = {};

  void _release() {
    for (final modifier in _modifiers) {
      widget.actions.modifier(modifier, false);
    }
    _modifiers.clear();
  }

  @override
  void didUpdateWidget(KeyboardControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _release();
  }

  @override
  void dispose() {
    _release();
    _controller.dispose();
    super.dispose();
  }

  void _text() {
    if (_controller.text.isEmpty) return;
    widget.actions.text(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextField(
        controller: _controller,
        enabled: widget.active,
        maxLines: 3,
        minLines: 1,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => _text(),
        decoration: InputDecoration(
          labelText: 'Enviar texto',
          suffixIcon: IconButton(
            tooltip: 'Enviar',
            onPressed: widget.active ? _text : null,
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in const {
            'control': 'Ctrl',
            'alt': 'Alt',
            'shift': 'Shift',
          }.entries)
            FilterChip(
              label: Text(entry.value),
              selected: _modifiers.contains(entry.key),
              onSelected: widget.active
                  ? (pressed) {
                      setState(() {
                        if (pressed) {
                          _modifiers.add(entry.key);
                        } else {
                          _modifiers.remove(entry.key);
                        }
                      });
                      widget.actions.modifier(entry.key, pressed);
                    }
                  : null,
            ),
        ],
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in {
            'enter': 'Enter',
            'backspace': 'Backspace',
            'tab': 'Tab',
            'escape': 'Esc',
            'space': 'Espaço',
            'arrowLeft': '←',
            'arrowUp': '↑',
            'arrowDown': '↓',
            'arrowRight': '→',
            'delete': 'Delete',
            'home': 'Home',
            'end': 'End',
            'pageUp': 'PgUp',
            'pageDown': 'PgDn',
            'insert': 'Insert',
            'capsLock': 'Caps',
            for (var i = 1; i <= 12; i++) 'f$i': 'F$i',
            for (var i = 0; i < 26; i++)
              String.fromCharCode(97 + i): String.fromCharCode(65 + i),
            for (var i = 0; i < 10; i++) '$i': '$i',
          }.entries)
            ActionChip(
              label: Text(entry.value),
              onPressed: widget.active
                  ? () => widget.actions.key(entry.key)
                  : null,
            ),
        ],
      ),
    ],
  );
}
