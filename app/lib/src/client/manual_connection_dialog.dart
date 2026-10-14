import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

import 'package:open_remote_core/open_remote_core.dart';

typedef ManualEndpoint = ({String address, int port});

class ManualConnectionDialog extends StatefulWidget {
  const ManualConnectionDialog({super.key, this.initial});
  final ManualEndpoint? initial;
  @override
  State<ManualConnectionDialog> createState() => _ManualConnectionDialogState();
}

class _ManualConnectionDialogState extends State<ManualConnectionDialog> {
  final _form = GlobalKey<FormState>();
  Locale? _lastLocale;
  bool _showValidationErrors = false;
  late final _address = TextEditingController(text: widget.initial?.address);
  late final _port = TextEditingController(
    text: '${widget.initial?.port ?? 47652}',
  );
  void _submit() {
    final valid = _form.currentState!.validate();
    _showValidationErrors = !valid;
    if (valid) {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.connectByIp),
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
                decoration: InputDecoration(
                  labelText: l10n.computerIp,
                  hintText: '192.168.1.2',
                ),
                validator: (value) => isPrivateIpv4(value?.trim() ?? '')
                    ? null
                    : l10n.localIpValidation,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _port,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l10n.port),
                validator: (value) {
                  final port = int.tryParse(value?.trim() ?? '');
                  return port != null && port >= 1024 && port <= 65535
                      ? null
                      : l10n.portValidation;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.connect)),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != locale && _showValidationErrors) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showValidationErrors) _form.currentState?.validate();
      });
    }
    _lastLocale = locale;
  }
}
