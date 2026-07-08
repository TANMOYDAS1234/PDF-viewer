// On-device verification of the platform-dependent tool paths (path_provider
// output dir + Printing.raster). Run:
//   flutter test integration_test/features_test.dart -d <deviceId>
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:pdf_viewer_pro/services/pdf_tools.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<String> makePdf(int pages) async {
    final doc = PdfDocument();
    for (var i = 0; i < pages; i++) {
      doc.pages.add().graphics.drawString(
            'Page ${i + 1}: hello export world',
            PdfStandardFont(PdfFontFamily.helvetica, 18),
            bounds: const Rect.fromLTWH(20, 20, 500, 40),
          );
    }
    final bytes = doc.saveSync();
    doc.dispose();
    final dir = await Directory.systemTemp.createTemp('feat');
    final path = '${dir.path}/src_${DateTime.now().microsecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  test('merge writes a real file to the output dir', () async {
    final a = await makePdf(2);
    final b = await makePdf(3);
    final out = await PdfTools.merge([a, b], 'it_merged.pdf');
    expect(File(out).existsSync(), true);
    expect(PdfTools.pageCount(out), 5);
  });

  test('PDF -> Text export', () async {
    final src = await makePdf(2);
    final out = await PdfTools.pdfToText(src, 'it_text');
    expect(out.endsWith('.txt'), true);
    expect((await File(out).readAsString()).contains('hello export world'),
        true);
  });

  test('PDF -> Images: one PNG file per page (on-device rasteriser)', () async {
    final src = await makePdf(3);
    final outs = await PdfTools.pdfToImages(src, 'it_imgs', dpi: 96);
    expect(outs.length, 3);
    expect(outs.every((p) => p.endsWith('.png') && File(p).existsSync()), true);

    final single = await PdfTools.pdfToImages(await makePdf(1), 'it_img1');
    expect(single.length, 1);
    expect(single.first.endsWith('.png'), true);
  });

  test('Bengali/CJK text -> PDF does not crash (universal renderer)', () async {
    final dir = await Directory.systemTemp.createTemp('lang');
    final txt = '${dir.path}/bn.txt';
    await File(txt).writeAsString('বাংলা লেখা 你好 مرحبا Hello', flush: true);
    final out = await PdfTools.textToPdf(txt, 'it_lang.pdf');
    expect(File(out).existsSync(), true);
    expect(PdfTools.pageCount(out), greaterThanOrEqualTo(1));
  });

  test('PDF -> Word (.docx) export, readable back', () async {
    final src = await makePdf(1);
    final out = await PdfTools.pdfToDocx(src, 'it_docx');
    expect(out.endsWith('.docx'), true);
    final back = await PdfTools.docxToPdfBytes(out);
    final d = PdfDocument(inputBytes: back);
    expect(d.pages.count, greaterThanOrEqualTo(1));
    d.dispose();
  });

  test('Word (.docx) -> PDF conversion writes a file', () async {
    final docxBytes = PdfTools.docxBytesFromText('Report line one\nLine two');
    final dir = await Directory.systemTemp.createTemp('conv');
    final docxPath = '${dir.path}/in.docx';
    await File(docxPath).writeAsBytes(docxBytes, flush: true);
    final out = await PdfTools.docxToPdf(docxPath, 'it_docx2pdf.pdf');
    expect(File(out).existsSync(), true);
    expect(PdfTools.pageCount(out), greaterThanOrEqualTo(1));
  });

  test('Protect then open with password', () async {
    final src = await makePdf(1);
    final locked = await PdfTools.protect(src, 'pw', 'it_locked.pdf');
    // Without password → throws.
    expect(
        () => PdfDocument(inputBytes: File(locked).readAsBytesSync()),
        throwsA(anything));
    // With password → opens.
    final d = PdfDocument(
        inputBytes: File(locked).readAsBytesSync(), password: 'pw');
    expect(d.pages.count, 1);
    d.dispose();
  });
}
