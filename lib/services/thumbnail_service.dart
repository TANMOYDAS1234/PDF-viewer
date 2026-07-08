import 'dart:io';
import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Renders and caches the first-page thumbnail of a PDF (for list/grid cards).
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  final Map<String, Uint8List?> _cache = {};
  final Map<String, Future<Uint8List?>> _inflight = {};

  /// Returns cached bytes immediately if available, else null.
  Uint8List? cached(String path) => _cache[path];

  Future<Uint8List?> firstPage(String path, {double dpi = 48}) {
    if (_cache.containsKey(path)) return Future.value(_cache[path]);
    return _inflight[path] ??= _render(path, dpi).then((bytes) {
      _cache[path] = bytes;
      _inflight.remove(path);
      return bytes;
    });
  }

  Future<Uint8List?> _render(String path, double dpi) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      await for (final page in Printing.raster(bytes, pages: [0], dpi: dpi)) {
        return await page.toPng();
      }
    } catch (_) {}
    return null;
  }
}
