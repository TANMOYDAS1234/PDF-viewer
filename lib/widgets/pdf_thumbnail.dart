import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/thumbnail_service.dart';
import '../theme/app_theme.dart';

/// Shows a PDF's first-page thumbnail, falling back to a red "PDF" placeholder
/// while rendering or if the file can't be read.
class PdfThumbnail extends StatelessWidget {
  final String path;
  final bool exists;
  final BoxFit fit;

  const PdfThumbnail({
    super.key,
    required this.path,
    this.exists = true,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!exists) return _placeholder(scheme, broken: true);

    final cached = ThumbnailService.instance.cached(path);
    if (cached != null) return _image(cached);

    return FutureBuilder<Uint8List?>(
      future: ThumbnailService.instance.firstPage(path),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _placeholder(scheme, loading: true);
        }
        final bytes = snap.data;
        if (bytes == null) return _placeholder(scheme);
        return _image(bytes);
      },
    );
  }

  Widget _image(Uint8List bytes) =>
      Container(color: Colors.white, child: Image.memory(bytes, fit: fit));

  Widget _placeholder(ColorScheme scheme,
      {bool loading = false, bool broken = false}) {
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              broken
                  ? Icons.error_outline_rounded
                  : Icons.picture_as_pdf_rounded,
              color: broken ? scheme.error : AppColors.pdfRed,
              size: 34,
            ),
    );
  }
}

/// Small red "PDF" corner badge used on document cards.
class PdfBadge extends StatelessWidget {
  const PdfBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.pdfRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PDF',
        style: TextStyle(
          color: AppColors.pdfRed,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
