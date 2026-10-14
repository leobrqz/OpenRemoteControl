import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../l10n/app_localizations.dart';

class PairingScannerScreen extends StatefulWidget {
  const PairingScannerScreen({super.key});

  @override
  State<PairingScannerScreen> createState() => PairingScannerScreenState();
}

class PairingScannerScreenState extends State<PairingScannerScreen> {
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairWithWindows)),
      body: MobileScanner(
        onDetect: _onDetect,
        errorBuilder: (context, error) =>
            PairingCameraError(code: error.errorCode),
        placeholderBuilder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.cameraStarting),
            ],
          ),
        ),
        overlayBuilder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF77E4D3),
                      width: 3,
                    ),
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
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    l10n.scanServerQr,
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PairingCameraError extends StatelessWidget {
  const PairingCameraError({super.key, required this.code});
  final MobileScannerErrorCode code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 40),
            const SizedBox(height: 16),
            Text(
              code == MobileScannerErrorCode.permissionDenied
                  ? l10n.cameraPermission
                  : l10n.cameraUnavailable,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
