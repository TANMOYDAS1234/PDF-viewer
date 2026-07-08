// On-device verification that Compress actually shrinks an image-heavy PDF.
// Run: flutter test integration_test/compress_test.dart -d <deviceId>
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:pdf_viewer_pro/services/pdf_tools.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('compress shrinks an image-heavy PDF', () async {
    // Build a high-entropy (photo-like) image so the source PDF is genuinely
    // large — this mimics a scanned/photographed document.
    final image = img.Image(width: 1400, height: 1900);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final v = (x * 374761393 + y * 668265263) ^ (x * y * 2246822519);
        image.setPixelRgb(x, y, v & 0xFF, (v >> 7) & 0xFF, (v >> 13) & 0xFF);
      }
    }
    final png = img.encodePng(image);

    final src = PdfDocument();
    src.pageSettings.margins.all = 0;
    for (var p = 0; p < 2; p++) {
      final page = src.pages.add();
      final s = page.getClientSize();
      page.graphics
          .drawImage(PdfBitmap(png), Rect.fromLTWH(0, 0, s.width, s.height));
    }
    final srcBytes = await src.save();
    src.dispose();

    final dir = await getTemporaryDirectory();
    final inPath = '${dir.path}/heavy_src_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(inPath).writeAsBytes(srcBytes, flush: true);

    // Compress at the "Balanced" level.
    final res = await PdfTools.compress(inPath, 'heavy_out.pdf',
        dpi: 110, quality: 55);

    // ignore: avoid_print
    print('COMPRESS: original=${res.originalSize} new=${res.newSize} '
        'saved=${res.savedPercent.toStringAsFixed(1)}%');

    expect(res.originalSize, srcBytes.length);
    expect(res.newSize, lessThan(res.originalSize),
        reason: 'compression should reduce the file');
    // The output must still be a valid, readable PDF with 3 pages.
    final outDoc =
        PdfDocument(inputBytes: File(res.path).readAsBytesSync());
    expect(outDoc.pages.count, 2);
    outDoc.dispose();
  });
}
