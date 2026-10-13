import 'package:flutter/material.dart';

import '../core/wire.dart';

typedef ManualEndpoint = ({String address, int port});

class ManualConnectionDialog extends StatefulWidget {
  const ManualConnectionDialog({super.key, this.initial});
  final ManualEndpoint? initial;
  @override
  State<ManualConnectionDialog> createState() => _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<ManualConnectionDialog> {
  final _form = GlobalKey<FormState>();
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _port = TextEditingController(
    text: '${widget.initial?.port ?? 47652}',
  );
  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, (
        address: _address.text.trim(),
        port: int.parse(_port.text.trim()),
      ));
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Conectar por IP'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _address,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'IP do computador',
                hintText: '192.168.1.2',
              ),
              validator: (value) => isPrivateIpv4(value?.trim() ?? '')
                  ? null
                  : 'Digite um IP local válido.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _port,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Porta'),
              validator: (value) {
                final port = int.tryParse(value?.trim() ?? '');
                return port != null && port >= 1024 && port <= 65535
                    ? null
                    : 'Use uma porta de 1024 a 65535.';
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Conectar')),
    ],
  );
}
