import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';
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

  /// Re-save the PDF with best stream compression. Returns the output path and
  /// the before/after byte sizes so the UI can show the saving.
  static Future<CompressResult> compress(
    String inputPath,
    String outName,
  ) async {
    final originalBytes = File(inputPath).readAsBytesSync();
    final doc = PdfDocument(inputBytes: originalBytes);
    try {
      doc.compressionLevel = PdfCompressionLevel.best;
      final bytes = await doc.save();
      // Never hand back a bigger file than the original.
      final useOriginal = bytes.length >= originalBytes.length;
      final outBytes = useOriginal ? originalBytes : bytes;
      final path = await _write(outName, outBytes);
      return CompressResult(
        path: path,
        originalSize: originalBytes.length,
        newSize: outBytes.length,
      );
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
