import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_tools.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'tool_result.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _path;
  String _name = '';
  String _size = '';
  int _pageCount = 0;

  final Map<int, Uint8List> _thumbs = {}; // 1-based
  final Set<int> _selected = {};
  RangeValues _range = const RangeValues(1, 1);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final f = result?.files.single;
    if (f?.path == null) {
      if (mounted && _path == null) Navigator.pop(context);
      return;
    }
    setState(() {
      _path = f!.path;
      _name = f.name;
      _size = _fmtSize(f.size);
      _thumbs.clear();
      _selected.clear();
    });
    try {
      final count = PdfTools.pageCount(_path!);
      setState(() {
        _pageCount = count;
        _range = RangeValues(1, count.toDouble());
        _selected.addAll(List.generate(count, (i) => i + 1));
      });
      _renderThumbs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read PDF: $e')));
      }
    }
  }

  Future<void> _renderThumbs() async {
    final bytes = await File(_path!).readAsBytes();
    var page = 1;
    await for (final raster in Printing.raster(bytes, dpi: 28)) {
      final png = await raster.toPng();
      if (!mounted) return;
      setState(() => _thumbs[page] = png);
      page++;
    }
  }

  void _applyRange(RangeValues v) {
    setState(() {
      _range = v;
      _selected
        ..clear()
        ..addAll(List.generate(
            (v.end - v.start).round() + 1, (i) => v.start.round() + i));
    });
  }

  Future<void> _split() async {
    if (_selected.isEmpty) return;
    setState(() => _busy = true);
    try {
      final base = _name.replaceAll('.pdf', '');
      final name = '${base}_extract.pdf';
      final path = await PdfTools.extractSelectedPages(
          _path!, _selected.toList(), name);
      if (mounted) showToolResult(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Split failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtSize(int b) => b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(0)} KB'
      : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
        actions: [
          IconButton(
              onPressed: _pick, icon: const Icon(Icons.folder_open_rounded)),
        ],
      ),
      body: _path == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _fileCard(scheme),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text('SELECT PAGES',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.8)),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _selected
                              ..clear()
                              ..addAll(
                                  List.generate(_pageCount, (i) => i + 1))),
                            child: const Text('Select All',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _rangeCard(scheme),
                      const SizedBox(height: 16),
                      _pageGrid(scheme),
                    ],
                  ),
                ),
                _bottomBar(scheme),
              ],
            ),
    );
  }

  Widget _fileCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.pdfRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.picture_as_pdf_rounded, color: AppColors.pdfRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text('$_size · $_pageCount Pages',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Custom Range',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('Pages ${_range.start.round()} - ${_range.end.round()}',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_pageCount > 1)
            RangeSlider(
              values: _range,
              min: 1,
              max: _pageCount.toDouble(),
              divisions: _pageCount - 1,
              labels: RangeLabels(
                  '${_range.start.round()}', '${_range.end.round()}'),
              onChanged: _applyRange,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('This PDF has a single page.',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _pageGrid(ColorScheme scheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.74,
      ),
      itemCount: _pageCount,
      itemBuilder: (context, i) {
        final page = i + 1;
        final selected = _selected.contains(page);
        final png = _thumbs[page];
        return GestureDetector(
          onTap: () => setState(() {
            selected ? _selected.remove(page) : _selected.add(page);
          }),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : scheme.outlineVariant,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: png != null
                      ? Image.memory(png, fit: BoxFit.contain)
                      : const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : scheme.outlineVariant),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : Center(
                          child: Text('$page',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_selected.length} pages selected',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            GradientButton(
              label: 'Split PDF',
              icon: Icons.content_cut_rounded,
              busy: _busy,
              onPressed: (_selected.isEmpty || _busy) ? null : _split,
            ),
          ],
        ),
      ),
    );
  }
}
