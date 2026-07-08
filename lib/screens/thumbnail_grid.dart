import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// A grid of page thumbnails. Tapping a page pops with its page number so the
/// viewer can jump to it.
class ThumbnailGridScreen extends StatefulWidget {
  final String filePath;
  final int pageCount;
  final int currentPage;

  const ThumbnailGridScreen({
    super.key,
    required this.filePath,
    required this.pageCount,
    required this.currentPage,
  });

  @override
  State<ThumbnailGridScreen> createState() => _ThumbnailGridScreenState();
}

class _ThumbnailGridScreenState extends State<ThumbnailGridScreen> {
  final Map<int, Uint8List> _thumbs = {}; // 1-based page -> png bytes
  bool _rendering = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      var page = 1;
      await for (final raster in Printing.raster(bytes, dpi: 24)) {
        final png = await raster.toPng();
        if (!mounted) return;
        setState(() => _thumbs[page] = png);
        page++;
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Pages (${widget.pageCount})'),
        actions: [
          if (_rendering)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Could not render pages: $_error'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widget.pageCount,
              itemBuilder: (context, index) {
                final page = index + 1;
                final png = _thumbs[page];
                final isCurrent = page == widget.currentPage;
                return InkWell(
                  onTap: () => Navigator.pop(context, page),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: isCurrent ? 3 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: png != null
                              ? Image.memory(png, fit: BoxFit.contain)
                              : const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$page',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? scheme.primary : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
