import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF manipulation utilities built on syncfusion_flutter_pdf.
///
/// This version of the package has no direct `merge`, so pages are copied by
/// rendering each source page as a template onto the output document.
class PdfTools {
  PdfTools._();

  /// Directory where generated PDFs are written.
  static Future<Directory> _outputDir() async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/PDFViewerPro');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static void _copyPage(PdfDocument output, PdfPage source) {
    final template = source.createTemplate();
    output.pageSettings.size = template.size;
    final page = output.pages.add();
    page.graphics.drawPdfTemplate(template, Offset.zero);
  }

  /// Merge multiple PDFs (in the given order) into one file.
  static Future<String> merge(List<String> inputPaths, String outName) async {
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;
    try {
      for (final path in inputPaths) {
        final src = PdfDocument(inputBytes: File(path).readAsBytesSync());
        for (var i = 0; i < src.pages.count; i++) {
          _copyPage(output, src.pages[i]);
        }
        src.dispose();
      }
      final bytes = await output.save();
      return _write(outName, bytes);
    } finally {
      output.dispose();
    }
  }

  /// Extract a 1-based inclusive page range into a new PDF.
  static Future<String> extractPages(
    String inputPath,
    int startPage,
    int endPage,
    String outName,
  ) async {
    final src = PdfDocument(inputBytes: File(inputPath).readAsBytesSync());
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;
    try {
      final from = startPage.clamp(1, src.pages.count);
      final to = endPage.clamp(from, src.pages.count);
      for (var i = from - 1; i <= to - 1; i++) {
        _copyPage(output, src.pages[i]);
      }
      final bytes = await output.save();
      return _write(outName, bytes);
    } finally {
      src.dispose();
      output.dispose();
    }
  }

  /// Extract an arbitrary set of 1-based pages (in order) into a new PDF.
  static Future<String> extractSelectedPages(
    String inputPath,
    List<int> pages,
    String outName,
  ) async {
    final src = PdfDocument(inputBytes: File(inputPath).readAsBytesSync());
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;
    try {
      final sorted = pages.toSet().toList()..sort();
      for (final p in sorted) {
        if (p >= 1 && p <= src.pages.count) {
          _copyPage(output, src.pages[p - 1]);
        }
      }
      final bytes = await output.save();
      return _write(outName, bytes);
    } finally {
      src.dispose();
      output.dispose();
    }
  }

  /// Add a password to a PDF.
  static Future<String> protect(
    String inputPath,
    String password,
    String outName,
  ) async {
    final doc = PdfDocument(inputBytes: File(inputPath).readAsBytesSync());
    try {
      doc.security.userPassword = password;
      doc.security.ownerPassword = password;
      final bytes = await doc.save();
      return _write(outName, bytes);
    } finally {
      doc.dispose();
    }
  }

  /// Remove a password from a PDF (requires the current password).
  static Future<String> unlock(
    String inputPath,
    String password,
    String outName,
  ) async {
    final doc = PdfDocument(
      inputBytes: File(inputPath).readAsBytesSync(),
      password: password,
    );
    try {
      doc.security.userPassword = '';
      doc.security.ownerPassword = '';
      final bytes = await doc.save();
      return _write(outName, bytes);
    } finally {
      doc.dispose();
    }
  }

  /// Compress a PDF by re-rendering each page and re-encoding it as a JPEG at
  /// the given [dpi] and [quality]. This is effective for image/scanned PDFs
  /// (where most of the size lives). Pages become images, so text is no longer
  /// selectable — that's the standard trade-off for strong PDF compression.
  ///
  /// Falls back to the original file if the result isn't smaller (e.g. a PDF
  /// that is already efficient, or pure vector text).
  static Future<CompressResult> compress(
    String inputPath,
    String outName, {
    int dpi = 110,
    int quality = 60,
  }) async {
    final originalBytes = File(inputPath).readAsBytesSync();
    final output = PdfDocument();
    output.pageSettings.margins.all = 0;
    try {
      await for (final raster
          in Printing.raster(originalBytes, dpi: dpi.toDouble())) {
        final image = img.Image.fromBytes(
          width: raster.width,
          height: raster.height,
          bytes: raster.pixels.buffer,
          numChannels: 4,
        );
        final jpg = img.encodeJpg(image, quality: quality);

        final bitmap = PdfBitmap(jpg);
        // Keep the original physical page size (points = px * 72 / dpi).
        output.pageSettings.size =
            Size(raster.width * 72 / dpi, raster.height * 72 / dpi);
        final page = output.pages.add();
        final s = page.getClientSize();
        page.graphics
            .drawImage(bitmap, Rect.fromLTWH(0, 0, s.width, s.height));
      }

      final compressed = await output.save();
      // Never hand back something bigger than the original.
      final useOriginal =
          compressed.isEmpty || compressed.length >= originalBytes.length;
      final outBytes = useOriginal ? originalBytes : compressed;
      final path = await _write(outName, outBytes);
      return CompressResult(
        path: path,
        originalSize: originalBytes.length,
        newSize: outBytes.length,
      );
    } finally {
      output.dispose();
    }
  }

  /// Build a PDF from image files — one image per page, fit to A4 preserving
  /// aspect ratio.
  static Future<String> imagesToPdf(
    List<String> imagePaths,
    String outName,
  ) async {
    final doc = PdfDocument();
    try {
      for (final path in imagePaths) {
        final bitmap = PdfBitmap(File(path).readAsBytesSync());
        final page = doc.pages.add();
        final ps = page.getClientSize();
        final iw = bitmap.width.toDouble();
        final ih = bitmap.height.toDouble();
        final scale = math.min(ps.width / iw, ps.height / ih);
        final w = iw * scale;
        final h = ih * scale;
        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH((ps.width - w) / 2, (ps.height - h) / 2, w, h),
        );
      }
      final bytes = await doc.save();
      return _write(outName, bytes);
    } finally {
      doc.dispose();
    }
  }

  /// Build a PDF from a plain-text (.txt) file, auto-paginating the text.
  static Future<String> textToPdf(String txtPath, String outName) async {
    final text = File(txtPath).readAsStringSync();
    final doc = PdfDocument();
    try {
      final page = doc.pages.add();
      final size = page.getClientSize();
      const margin = 40.0;
      final element = PdfTextElement(
        text: text.isEmpty ? ' ' : text,
        font: PdfStandardFont(PdfFontFamily.helvetica, 12),
      );
      element.draw(
        page: page,
        bounds: Rect.fromLTWH(
            margin, margin, size.width - 2 * margin, size.height - 2 * margin),
        format: PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
          breakType: PdfLayoutBreakType.fitPage,
        ),
      );
      final bytes = await doc.save();
      return _write(outName, bytes);
    } finally {
      doc.dispose();
    }
  }

  /// How many pages a PDF has (used to validate split ranges).
  static int pageCount(String path) {
    final doc = PdfDocument(inputBytes: File(path).readAsBytesSync());
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }

  static Future<String> _write(String name, List<int> bytes) async {
    final dir = await _outputDir();
    final safe = name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf';
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

/// Result of a [PdfTools.compress] operation.
class CompressResult {
  final String path;
  final int originalSize;
  final int newSize;
  const CompressResult({
    required this.path,
    required this.originalSize,
    required this.newSize,
  });

  int get savedBytes => originalSize - newSize;
  double get savedPercent =>
      originalSize == 0 ? 0 : (savedBytes / originalSize) * 100;
  bool get didShrink => newSize < originalSize;
}
