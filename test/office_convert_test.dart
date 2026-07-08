// Verifies docx/pptx/xlsx -> PDF by building minimal Office fixtures in memory
// and running the real converters (the *Bytes variants avoid path_provider).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:pdf_viewer_pro/services/pdf_tools.dart';

/// Zip a {name: xmlString} map into an Office file and write it to a temp path.
Future<String> _makeOffice(String ext, Map<String, String> files) async {
  final archive = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  final zipped = ZipEncoder().encode(archive);
  final dir = await Directory.systemTemp.createTemp('office_test');
  final path = '${dir.path}/fixture.$ext';
  await File(path).writeAsBytes(zipped, flush: true);
  return path;
}

int _pages(List<int> bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  final n = doc.pages.count;
  doc.dispose();
  return n;
}

const _contentTypes =
    '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('docx -> pdf extracts paragraphs', () async {
    const doc =
        '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>'
        '<w:p><w:r><w:t>Hello</w:t></w:r><w:r><w:t> World</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Second paragraph line</w:t></w:r></w:p>'
        '</w:body></w:document>';
    final path = await _makeOffice(
        'docx', {'[Content_Types].xml': _contentTypes, 'word/document.xml': doc});
    final bytes = await PdfTools.docxToPdfBytes(path);
    expect(_pages(bytes), greaterThanOrEqualTo(1));
    expect(bytes.length, greaterThan(400));
  });

  test('pptx -> pdf makes one page per slide', () async {
    String slide(String t) =>
        '<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<p:cSld><p:spTree><a:t>$t</a:t></p:spTree></p:cSld></p:sld>';
    final path = await _makeOffice('pptx', {
      '[Content_Types].xml': _contentTypes,
      'ppt/slides/slide1.xml': slide('First slide'),
      'ppt/slides/slide2.xml': slide('Second slide'),
    });
    final bytes = await PdfTools.pptxToPdfBytes(path);
    expect(_pages(bytes), 2);
  });

  test('pdf -> docx export is a valid docx (round-trips back to PDF)', () async {
    // Export path: build a .docx from text...
    final docxBytes = PdfTools.docxBytesFromText('Alpha line\nBeta line');
    final dir = await Directory.systemTemp.createTemp('docx_export');
    final path = '${dir.path}/exported.docx';
    await File(path).writeAsBytes(docxBytes, flush: true);

    // ...and confirm our own docx parser can read it back into a valid PDF.
    final pdfBytes = await PdfTools.docxToPdfBytes(path);
    expect(_pages(pdfBytes), greaterThanOrEqualTo(1));

    // Structure sanity: has the required OOXML parts.
    final archive = ZipDecoder().decodeBytes(docxBytes);
    expect(archive.files.any((f) => f.name == '[Content_Types].xml'), true);
    expect(archive.files.any((f) => f.name == 'word/document.xml'), true);
  });

  test('xlsx -> pdf renders the worksheet', () async {
    const sharedStrings =
        '<?xml version="1.0"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<si><t>Name</t></si><si><t>Score</t></si><si><t>Alice</t></si></sst>';
    const sheet =
        '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>'
        '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
        '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2"><v>95</v></c></row>'
        '</sheetData></worksheet>';
    final path = await _makeOffice('xlsx', {
      '[Content_Types].xml': _contentTypes,
      'xl/sharedStrings.xml': sharedStrings,
      'xl/worksheets/sheet1.xml': sheet,
    });
    final bytes = await PdfTools.xlsxToPdfBytes(path);
    expect(_pages(bytes), greaterThanOrEqualTo(1));
    expect(bytes.length, greaterThan(400));
  });
}
