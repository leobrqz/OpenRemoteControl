import 'package:qr/qr.dart';

class PairingQrSvg {
  PairingQrSvg._();

  static const _quietZone = 4;

  static String render(String payload) {
    final image = QrImage(
      QrCode.fromData(data: payload, errorCorrectLevel: QrErrorCorrectLevel.M),
    );
    final dimension = image.moduleCount + _quietZone * 2;
    final path = StringBuffer();

    for (var row = 0; row < image.moduleCount; row++) {
      for (var column = 0; column < image.moduleCount; column++) {
        if (!image.isDark(row, column)) continue;
        final x = column + _quietZone;
        final y = row + _quietZone;
        path.write('M$x,$y h1v1h-1z');
      }
    }

    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $dimension $dimension" role="img" aria-label="QR para parear celular" shape-rendering="crispEdges"><rect width="$dimension" height="$dimension" fill="#fff"/><path d="${path.toString()}" fill="#111"/></svg>';
  }
}
