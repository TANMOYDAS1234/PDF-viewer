import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

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
        final raw = File(path).readAsBytesSync();
        // PdfBitmap natively reads JPG/PNG; decode anything else (webp, gif,
        // tiff, bmp, ico, …) via the image package and re-encode to PNG.
        final lower = path.toLowerCase();
        List<int> data = raw;
        if (!(lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.png'))) {
          final decoded = img.decodeImage(raw);
          if (decoded != null) data = img.encodePng(decoded);
        }
        final bitmap = PdfBitmap(data);
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
    return _write(outName, await _textPdfBytes(text));
  }

  /// Render plain text into auto-paginated PDF bytes (shared by txt/docx/pptx).
  static Future<List<int>> _textPdfBytes(String text) async {
    final doc = PdfDocument();
    try {
      final page = doc.pages.add();
      final size = page.getClientSize();
      const margin = 40.0;
      PdfTextElement(
        text: text.trim().isEmpty ? '(No extractable text found)' : text,
        font: PdfStandardFont(PdfFontFamily.helvetica, 12),
      ).draw(
        page: page,
        bounds: Rect.fromLTWH(
            margin, margin, size.width - 2 * margin, size.height - 2 * margin),
        format: PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
          breakType: PdfLayoutBreakType.fitPage,
        ),
      );
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  // ------------------------------------------------------------- Office → PDF
  // Office files are ZIP archives of XML. We extract their text/tables and lay
  // them into a PDF entirely on-device. Complex layouts/images are simplified.

  static Archive _unzip(String path) =>
      ZipDecoder().decodeBytes(File(path).readAsBytesSync());

  static String _entryText(Archive archive, String name) {
    final entry = archive.files.where((f) => f.name == name);
    if (entry.isEmpty) return '';
    return utf8.decode(entry.first.content as List<int>);
  }

  /// Word (.docx) → PDF: extract paragraph text in document order.
  static Future<String> docxToPdf(String path, String outName) async =>
      _write(outName, await docxToPdfBytes(path));

  static Future<List<int>> docxToPdfBytes(String path) async {
    final xmlStr = _entryText(_unzip(path), 'word/document.xml');
    final buffer = StringBuffer();
    if (xmlStr.isNotEmpty) {
      final doc = XmlDocument.parse(xmlStr);
      for (final p in doc.findAllElements('p', namespace: '*')) {
        buffer.writeln(
            p.findAllElements('t', namespace: '*').map((e) => e.innerText).join());
      }
    }
    return _textPdfBytes(buffer.toString().trim());
  }

  /// PowerPoint (.pptx) → PDF: one page per slide with the slide's text.
  static Future<String> pptxToPdf(String path, String outName) async =>
      _write(outName, await pptxToPdfBytes(path));

  static Future<List<int>> pptxToPdfBytes(String path) async {
    final archive = _unzip(path);
    final slides = archive.files
        .where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((a, b) => _numIn(a.name).compareTo(_numIn(b.name)));

    final output = PdfDocument();
    try {
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      for (var i = 0; i < slides.length; i++) {
        final xmlStr = utf8.decode(slides[i].content as List<int>);
        final doc = XmlDocument.parse(xmlStr);
        final text = doc
            .findAllElements('t', namespace: '*')
            .map((e) => e.innerText)
            .where((t) => t.trim().isNotEmpty)
            .join('\n');
        final page = output.pages.add();
        final size = page.getClientSize();
        PdfTextElement(text: 'Slide ${i + 1}\n\n$text', font: font).draw(
          page: page,
          bounds:
              Rect.fromLTWH(40, 40, size.width - 80, size.height - 80),
          format: PdfLayoutFormat(
            layoutType: PdfLayoutType.paginate,
            breakType: PdfLayoutBreakType.fitPage,
          ),
        );
      }
      if (slides.isEmpty) output.pages.add();
      return await output.save();
    } finally {
      output.dispose();
    }
  }

  /// Excel (.xlsx) → PDF: render the first worksheet as a table.
  static Future<String> xlsxToPdf(String path, String outName) async =>
      _write(outName, await xlsxToPdfBytes(path));

  static Future<List<int>> xlsxToPdfBytes(String path) async {
    final archive = _unzip(path);

    // Shared strings table.
    final shared = <String>[];
    final ss = _entryText(archive, 'xl/sharedStrings.xml');
    if (ss.isNotEmpty) {
      for (final si in XmlDocument.parse(ss).findAllElements('si', namespace: '*')) {
        shared.add(
            si.findAllElements('t', namespace: '*').map((e) => e.innerText).join());
      }
    }

    // First worksheet.
    final sheet = archive.files
        .where((f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((a, b) => _numIn(a.name).compareTo(_numIn(b.name)));

    final rows = <Map<int, String>>[];
    var maxCols = 0;
    if (sheet.isNotEmpty) {
      final doc = XmlDocument.parse(utf8.decode(sheet.first.content as List<int>));
      for (final row in doc.findAllElements('row', namespace: '*')) {
        final cells = <int, String>{};
        for (final c in row.findAllElements('c', namespace: '*')) {
          final col = _colIndex(c.getAttribute('r') ?? '');
          final t = c.getAttribute('t');
          final v = c.findAllElements('v', namespace: '*');
          String value;
          if (t == 's') {
            final idx = int.tryParse(v.isNotEmpty ? v.first.innerText : '') ?? -1;
            value = (idx >= 0 && idx < shared.length) ? shared[idx] : '';
          } else if (t == 'inlineStr') {
            value = c
                .findAllElements('t', namespace: '*')
                .map((e) => e.innerText)
                .join();
          } else {
            value = v.isNotEmpty ? v.first.innerText : '';
          }
          cells[col] = value;
          maxCols = math.max(maxCols, col + 1);
        }
        rows.add(cells);
      }
    }

    final doc = PdfDocument();
    try {
      final page = doc.pages.add();
      final grid = PdfGrid();
      grid.columns.add(count: maxCols == 0 ? 1 : maxCols);
      for (final row in rows) {
        final gr = grid.rows.add();
        for (var c = 0; c < gr.cells.count; c++) {
          gr.cells[c].value = row[c] ?? '';
        }
      }
      grid.style = PdfGridStyle(
        font: PdfStandardFont(PdfFontFamily.helvetica, 9),
        cellPadding: PdfPaddings(left: 2, right: 2, top: 1, bottom: 1),
      );
      final size = page.getClientSize();
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(20, 20, size.width - 40, size.height - 40),
        format: PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
          breakType: PdfLayoutBreakType.fitPage,
        ),
      );
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static int _numIn(String name) =>
      int.tryParse(RegExp(r'(\d+)').firstMatch(name.split('/').last)?.group(1) ??
          '0') ??
      0;

  /// Excel column reference letters ("B", "AA") → 0-based index.
  static int _colIndex(String ref) {
    final m = RegExp(r'^([A-Z]+)').firstMatch(ref);
    if (m == null) return 0;
    var idx = 0;
    for (final ch in m.group(1)!.codeUnits) {
      idx = idx * 26 + (ch - 64);
    }
    return idx - 1;
  }

  // ---------------------------------------------------------- PDF → export

  /// PDF → plain text (.txt).
  static Future<String> pdfToText(String pdfPath, String outName) async {
    final doc = PdfDocument(inputBytes: File(pdfPath).readAsBytesSync());
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return _writeRaw(_ext(outName, 'txt'), utf8.encode(text));
  }

  /// PDF → a ZIP of one PNG per page (rendered at [dpi]).
  static Future<String> pdfToImagesZip(String pdfPath, String outName,
      {int dpi = 150}) async {
    final bytes = await File(pdfPath).readAsBytes();
    final archive = Archive();
    var i = 1;
    await for (final raster in Printing.raster(bytes, dpi: dpi.toDouble())) {
      final png = await raster.toPng();
      archive.addFile(ArchiveFile(
          'page_${i.toString().padLeft(3, '0')}.png', png.length, png));
      i++;
    }
    return _writeRaw(_ext(outName, 'zip'), ZipEncoder().encode(archive));
  }

  /// PDF → Word (.docx): extracts the text into a real, editable document.
  /// Layout, images and styling are not reconstructed.
  static Future<String> pdfToDocx(String pdfPath, String outName) async {
    final doc = PdfDocument(inputBytes: File(pdfPath).readAsBytesSync());
    final text = PdfTextExtractor(doc).extractText();
    doc.dispose();
    return _writeRaw(_ext(outName, 'docx'), docxBytesFromText(text));
  }

  /// Build a minimal valid .docx from plain text (exposed for testing).
  static List<int> docxBytesFromText(String text) {
    final body = (text.trim().isEmpty ? ' ' : text)
        .split('\n')
        .map((p) =>
            '<w:p><w:r><w:t xml:space="preserve">${_xmlEscape(p)}</w:t></w:r></w:p>')
        .join();
    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body<w:sectPr/></w:body></w:document>';
    return _zipStrings({
      '[Content_Types].xml': _docxContentTypes,
      '_rels/.rels': _docxRootRels,
      'word/document.xml': document,
    });
  }

  static String _ext(String name, String ext) =>
      name.toLowerCase().endsWith('.$ext') ? name : '$name.$ext';

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static List<int> _zipStrings(Map<String, String> files) {
    final archive = Archive();
    files.forEach((name, content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    });
    return ZipEncoder().encode(archive);
  }

  static Future<String> _writeRaw(String name, List<int> bytes) async {
    final dir = await _outputDir();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static const _docxContentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  static const _docxRootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      '</Relationships>';

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
