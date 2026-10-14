import 'package:flutter/material.dart';
import 'package:open_remote_core/open_remote_core.dart';
import '../../l10n/app_localizations.dart';

import 'about_service.dart';
import 'updates/android_update_card.dart';
import 'updates/android_update_controller.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    this.service,
    this.updates,
    required this.enabled,
  });

  final AboutService? service;
  final bool enabled;
  final AndroidUpdateController? updates;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final AboutService _service = widget.service ?? const AboutService();
  Future<String>? _version;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _loadVersion();
  }

  @override
  void didUpdateWidget(covariant AboutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) _loadVersion();
  }

  void _loadVersion() => _version = _service.installedVersion();

  Future<void> _open(Uri uri) async {
    try {
      if (await _service.openExternal(uri)) return;
    } catch (error, stackTrace) {
      // Show the same useful recovery message for a missing handler or error.
      await DiagnosticLog.record(
        'Android',
        'Failed to open an external link.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Builder(
            builder: (context) =>
                Text(AppLocalizations.of(context)!.openLinkFailed),
          ),
        ),
      );
  }

  Widget _link(String label, Uri uri, IconData icon) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.open_in_new, size: 18),
    onTap: () => _open(uri),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Image.asset(
                    'assets/branding/mark.png',
                    width: 64,
                    height: 64,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open Remote Control',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.aboutVersion),
                  subtitle: FutureBuilder<String>(
                    future: _version,
                    builder: (context, snapshot) => Text(
                      snapshot.data ??
                          (snapshot.hasError ? l10n.unavailable : '—'),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.phone_android),
                  title: Text(l10n.platform),
                  subtitle: Text('Android'),
                ),
                ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text(l10n.license),
                  subtitle: Text('GPL-3.0-only'),
                ),
              ],
            ),
          ),
          if (widget.updates != null) ...[
            const SizedBox(height: 12),
            AndroidUpdateCard(controller: widget.updates!),
          ],
          const SizedBox(height: 12),
          Text(l10n.project, style: Theme.of(context).textTheme.titleMedium),
          _link(
            l10n.officialWebsite,
            Uri.parse('https://openremotecontrol.sourceforge.io/'),
            Icons.language,
          ),
          _link(
            'GitHub',
            Uri.parse('https://github.com/leobrqz/OpenRemoteControl'),
            Icons.code,
          ),
          _link(
            'SourceForge',
            Uri.parse('https://sourceforge.net/projects/openremotecontrol/'),
            Icons.download_outlined,
          ),
          const SizedBox(height: 8),
          Text(l10n.credits, style: Theme.of(context).textTheme.titleMedium),
          const ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Leonardo Briquezi aka devpatok'),
          ),
          _link(
            'leonardobriquezi.me',
            Uri.parse('https://leonardobriquezi.me'),
            Icons.language,
          ),
          _link(
            l10n.personalGithub,
            Uri.parse('https://github.com/leobrqz'),
            Icons.code,
          ),
        ],
      ),
    );
  }
}
