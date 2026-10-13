import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
