import 'dart:io';

import 'package:flutter/material.dart';

import '../services/pdf_tools.dart';
import '../services/scan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'tool_result.dart';

class _Page {
  final String original;
  String current;
  _Page(this.original) : current = original;
}

class ScanReviewScreen extends StatefulWidget {
  final List<String> imagePaths;
  const ScanReviewScreen({super.key, required this.imagePaths});

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final List<_Page> _pages =
      widget.imagePaths.map((p) => _Page(p)).toList();
  final _nameCtrl = TextEditingController(
      text: 'Scan_${DateTime.now().millisecondsSinceEpoch}.pdf');
  ScanFilter _filter = ScanFilter.original;
  bool _busy = false;
  bool _applying = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _setFilter(ScanFilter f) async {
    if (_applying) return;
    setState(() {
      _filter = f;
      _applying = true;
    });
    for (final p in _pages) {
      p.current = await ScanService.applyFilter(p.original, f);
    }
    if (mounted) setState(() => _applying = false);
  }

  Future<void> _addPages() async {
    final more = await ScanService.scan();
    if (more == null || more.isEmpty) return;
    final added = more.map((p) => _Page(p)).toList();
    if (_filter != ScanFilter.original) {
      for (final p in added) {
        p.current = await ScanService.applyFilter(p.original, _filter);
      }
    }
    if (mounted) setState(() => _pages.addAll(added));
  }

  Future<void> _save() async {
    if (_pages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final name = _nameCtrl.text.trim().isEmpty
          ? 'Scan_${DateTime.now().millisecondsSinceEpoch}.pdf'
          : _nameCtrl.text.trim();
      final path = await PdfTools.imagesToPdf(
          _pages.map((p) => p.current).toList(), name);
      if (mounted) showToolResult(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Review · ${_pages.length} page${_pages.length == 1 ? '' : 's'}'),
        actions: [
          IconButton(
            tooltip: 'Add pages',
            onPressed: _addPages,
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterBar(scheme),
          Expanded(
            child: _pages.isEmpty
                ? const Center(child: Text('No pages'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _pages.length,
                    onReorder: (oldI, newI) => setState(() {
                      if (newI > oldI) newI--;
                      _pages.insert(newI, _pages.removeAt(oldI));
                    }),
                    itemBuilder: (context, i) => _pageCard(scheme, i),
                  ),
          ),
          _bottomBar(scheme),
        ],
      ),
    );
  }

  Widget _filterBar(ColorScheme scheme) {
    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final f in ScanFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) => _setFilter(f),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: _filter == f
                            ? Colors.white
                            : scheme.onSurface,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (_applying)
            Positioned.fill(
              child: Container(
                color: scheme.surface.withValues(alpha: 0.5),
                alignment: Alignment.center,
                child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pageCard(ColorScheme scheme, int i) {
    final page = _pages[i];
    return Container(
      key: ValueKey(page.original),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(page.current),
                width: 64, height: 84, fit: BoxFit.cover,
                gaplessPlayback: true),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Page ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.pdfRed),
            onPressed: () => setState(() => _pages.removeAt(i)),
          ),
          ReorderableDragStartListener(
            index: i,
            child: Icon(Icons.drag_indicator_rounded,
                color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'File name',
                suffixIcon: Icon(Icons.edit_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: 'Save as PDF',
              icon: Icons.picture_as_pdf_rounded,
              busy: _busy,
              onPressed: (_pages.isEmpty || _busy) ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
