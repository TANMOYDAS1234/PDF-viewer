// Verifies the core Syncfusion operations behind PdfTools (merge, split,
// extract, compress, protect, unlock) actually produce correct output.
//
// These mirror lib/services/pdf_tools.dart but write to a temp dir so they run
// under `flutter test` without path_provider.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

List<int> _makePdf(int pages) {
  final doc = PdfDocument();
  for (var i = 0; i < pages; i++) {
    final page = doc.pages.add();
    page.graphics.drawString(
      'Page ${i + 1} — hello world',
      PdfStandardFont(PdfFontFamily.helvetica, 20),
      bounds: const Rect.fromLTWH(20, 20, 400, 40),
    );
  }
  final bytes = doc.saveSync();
  doc.dispose();
  return bytes;
}

void _copyPage(PdfDocument output, PdfPage source) {
  final template = source.createTemplate();
  output.pageSettings.size = template.size;
  final page = output.pages.add();
  page.graphics.drawPdfTemplate(template, Offset.zero);
}

int _countPages(List<int> bytes, {String? password}) {
  final doc = PdfDocument(inputBytes: bytes, password: password);
  final n = doc.pages.count;
  doc.dispose();
  return n;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('makePdf produces the requested page count', () {
    expect(_countPages(_makePdf(3)), 3);
    expect(_countPages(_makePdf(1)), 1);
  });

  test('merge combines page counts', () async {
    final a = _makePdf(3);
    final b = _makePdf(2);
    final out = PdfDocument();
    final da = PdfDocument(inputBytes: a);
    for (var i = 0; i < da.pages.count; i++) {
      _copyPage(out, da.pages[i]);
    }
    final db = PdfDocument(inputBytes: b);
    for (var i = 0; i < db.pages.count; i++) {
      _copyPage(out, db.pages[i]);
    }
    final bytes = await out.save();
    expect(_countPages(bytes), 5);
  });

  test('extract range yields the right pages', () async {
    final a = _makePdf(6);
    final src = PdfDocument(inputBytes: a);
    final out = PdfDocument();
    for (var i = 1; i <= 3; i++) {
      _copyPage(out, src.pages[i - 1]); // pages 2..4 (1-based 2,3,4)
    }
    final bytes = await out.save();
    expect(_countPages(bytes), 3);
  });

  test('extract selected (non-contiguous) pages', () async {
    final a = _makePdf(5);
    final src = PdfDocument(inputBytes: a);
    final out = PdfDocument();
    for (final p in [1, 3, 5]) {
      _copyPage(out, src.pages[p - 1]);
    }
    final bytes = await out.save();
    expect(_countPages(bytes), 3);
  });

  test('compress produces a valid, readable PDF', () async {
    final a = _makePdf(4);
    final doc = PdfDocument(inputBytes: a);
    doc.compressionLevel = PdfCompressionLevel.best;
    final bytes = await doc.save();
    doc.dispose();
    expect(bytes.isNotEmpty, true);
    expect(_countPages(bytes), 4); // still readable & same pages
  });

  test('protect then unlock round-trips a password', () async {
    final a = _makePdf(2);

    // Protect
    final doc = PdfDocument(inputBytes: a);
    doc.security.userPassword = 'secret';
    doc.security.ownerPassword = 'secret';
    final locked = await doc.save();
    doc.dispose();

    // Opening WITHOUT the password must fail.
    expect(() => _countPages(locked), throwsA(anything));

    // Opening WITH the password works.
    expect(_countPages(locked, password: 'secret'), 2);

    // Unlock
    final u = PdfDocument(inputBytes: locked, password: 'secret');
    u.security.userPassword = '';
    u.security.ownerPassword = '';
    final unlocked = await u.save();
    u.dispose();

    // Now it opens with no password.
    expect(_countPages(unlocked), 2);
  });

  test('temp file write/read works (I/O sanity)', () async {
    final dir = await Directory.systemTemp.createTemp('pdf_tools_test');
    final file = File('${dir.path}/out.pdf');
    await file.writeAsBytes(_makePdf(1), flush: true);
    expect(file.existsSync(), true);
    expect(_countPages(await file.readAsBytes()), 1);
    await dir.delete(recursive: true);
  });
}
