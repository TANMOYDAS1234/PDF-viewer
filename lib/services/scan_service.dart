import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

enum ScanFilter { original, enhance, grayscale, blackWhite }

extension ScanFilterLabel on ScanFilter {
  String get label => switch (this) {
        ScanFilter.original => 'Original',
        ScanFilter.enhance => 'Auto',
        ScanFilter.grayscale => 'Grayscale',
        ScanFilter.blackWhite => 'B & W',
      };
}

/// Document scanning built on Google ML Kit's on-device document scanner
/// (auto edge-detection, perspective crop, enhancement, multi-page) plus a few
/// extra image filters applied locally.
class ScanService {
  ScanService._();

  /// Launch the camera scanner. Returns cropped/enhanced page image paths, or
  /// null if the user cancelled.
  static Future<List<String>?> scan({int maxPages = 50}) {
    return CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      androidScannerMode: AndroidScannerMode.full,
    );
  }

  /// Apply [filter] to [srcPath] and save the result; returns the new path
  /// (or the original path for [ScanFilter.original] / on error).
  static Future<String> applyFilter(String srcPath, ScanFilter filter) async {
    if (filter == ScanFilter.original) return srcPath;
    try {
      final raw = await File(srcPath).readAsBytes();
      var image = img.decodeImage(raw);
      if (image == null) return srcPath;

      switch (filter) {
        case ScanFilter.enhance:
          image = img.adjustColor(image,
              contrast: 1.15, brightness: 1.04, saturation: 1.08);
        case ScanFilter.grayscale:
          image = img.grayscale(image);
        case ScanFilter.blackWhite:
          image = img.grayscale(image);
          image = img.adjustColor(image, contrast: 1.5);
          for (final p in image) {
            final v = p.r > 128 ? 255 : 0;
            p.setRgb(v, v, v);
          }
        case ScanFilter.original:
          return srcPath;
      }

      final dir = await getTemporaryDirectory();
      final out =
          '${dir.path}/scan_${filter.name}_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(out).writeAsBytes(img.encodeJpg(image, quality: 88),
          flush: true);
      return out;
    } catch (_) {
      return srcPath;
    }
  }
}
