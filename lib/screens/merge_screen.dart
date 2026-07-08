import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/pdf_tools.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'tool_result.dart';

class _MergeItem {
  final String path;
  final String name;
  final int pages;
  final String size;
  _MergeItem(this.path, this.name, this.pages, this.size);
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<_MergeItem> _files = [];
  final _nameCtrl = TextEditingController(text: 'Merged_Document.pdf');
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path == null) continue;
      int pages = 0;
      try {
        pages = PdfTools.pageCount(f.path!);
      } catch (_) {}
      setState(() => _files.add(_MergeItem(
            f.path!,
            f.name,
            pages,
            _size(f.size),
          )));
    }
  }

  Future<void> _merge() async {
    if (_files.length < 2) return;
    setState(() => _busy = true);
    try {
      final name = _nameCtrl.text.trim().isEmpty
          ? 'Merged_Document.pdf'
          : _nameCtrl.text.trim();
      final path =
          await PdfTools.merge(_files.map((e) => e.path).toList(), name);
      if (mounted) showToolResult(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Merge failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDFs')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _dropzone(scheme),
                const SizedBox(height: 20),
                if (_files.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text('SELECTED FILES (${_files.length})',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.8)),
                      ),
                      GestureDetector(
                        onTap: () => setState(_files.clear),
                        child: const Text('Clear All',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (oldI, newI) => setState(() {
                      if (newI > oldI) newI--;
                      _files.insert(newI, _files.removeAt(oldI));
                    }),
                    children: [
                      for (var i = 0; i < _files.length; i++)
                        _fileCard(scheme, i),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Drag the handles to reorder files',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_files.length >= 2) _bottomBar(scheme),
        ],
      ),
    );
  }

  Widget _dropzone(ColorScheme scheme) {
    return GestureDetector(
      onTap: _pick,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 10),
            Text('Add Files',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppColors.primary)),
            const SizedBox(height: 2),
            Text('Upload PDF documents to merge',
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _fileCard(ColorScheme scheme, int i) {
    final f = _files[i];
    return Container(
      key: ValueKey(f.path),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: Icon(Icons.drag_indicator_rounded,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.pdfRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: AppColors.pdfRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 3),
                Text('${f.pages} Pages · ${f.size}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.pdfRed),
            onPressed: () => setState(() => _files.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
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
              decoration: InputDecoration(
                labelText: 'Output Name',
                labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                suffixIcon: const Icon(Icons.edit_rounded, size: 18),
              ),
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: 'Merge ${_files.length} PDFs',
              icon: Icons.merge_rounded,
              busy: _busy,
              onPressed: _busy ? null : _merge,
            ),
          ],
        ),
      ),
    );
  }
}
