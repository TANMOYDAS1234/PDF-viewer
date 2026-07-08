import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_tools.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

enum _Out { images, word, powerpoint, excel, text }

extension _OutInfo on _Out {
  String get label => switch (this) {
        _Out.images => 'Images',
        _Out.word => 'Word',
        _Out.powerpoint => 'PowerPoint',
        _Out.excel => 'Excel',
        _Out.text => 'Text',
      };
  String get sub => switch (this) {
        _Out.images => 'PNG in a ZIP',
        _Out.word => 'DOCX',
        _Out.powerpoint => 'PPTX',
        _Out.excel => 'XLSX',
        _Out.text => 'TXT',
      };
  IconData get icon => switch (this) {
        _Out.images => Icons.image_outlined,
        _Out.word => Icons.description_outlined,
        _Out.powerpoint => Icons.slideshow_outlined,
        _Out.excel => Icons.table_chart_outlined,
        _Out.text => Icons.text_snippet_outlined,
      };
  Color get tint => switch (this) {
        _Out.images => const Color(0xFFEA580C),
        _Out.word => const Color(0xFF2563EB),
        _Out.powerpoint => AppColors.pdfRed,
        _Out.excel => const Color(0xFF16A34A),
        _Out.text => const Color(0xFF6B7280),
      };
  bool get supported =>
      this == _Out.images || this == _Out.word || this == _Out.text;
}

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String? _path;
  String _name = '';
  String _size = '';
  int _pages = 0;
  _Out _out = _Out.images;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final f = result?.files.single;
    if (f?.path == null) {
      if (mounted && _path == null) Navigator.pop(context);
      return;
    }
    setState(() {
      _path = f!.path;
      _name = f.name;
      _size = f.size < 1024 * 1024
          ? '${(f.size / 1024).toStringAsFixed(0)} KB'
          : '${(f.size / (1024 * 1024)).toStringAsFixed(1)} MB';
    });
    try {
      final p = PdfTools.pageCount(_path!);
      setState(() => _pages = p);
    } catch (_) {}
  }

  Future<void> _export() async {
    if (_path == null || !_out.supported) return;
    setState(() => _busy = true);
    try {
      final base = _name.replaceAll('.pdf', '');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final out = '${base}_$stamp';
      final path = switch (_out) {
        _Out.images => await PdfTools.pdfToImagesZip(_path!, out),
        _Out.word => await PdfTools.pdfToDocx(_path!, out),
        _Out.text => await PdfTools.pdfToText(_path!, out),
        _ => '',
      };
      if (mounted && path.isNotEmpty) _showResult(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 44),
        title: Text('Exported to ${_out.label}'),
        content: Text('Saved to:\n$path', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(path)]);
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export PDF'),
        actions: [
          IconButton(
              onPressed: _pick, icon: const Icon(Icons.folder_open_rounded)),
        ],
      ),
      body: _path == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _fileCard(scheme),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                        child: Text('Select output format',
                            style: Theme.of(context).textTheme.titleLarge)),
                    const Text('Recommended: Images',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                _grid(scheme),
                if (!_out.supported) ...[
                  const SizedBox(height: 16),
                  _unsupportedNote(scheme),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Everything happens on your device — nothing is uploaded.',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      bottomNavigationBar: _path == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: GradientButton(
                  label: 'Export to ${_out.label}',
                  icon: Icons.arrow_forward_rounded,
                  busy: _busy,
                  onPressed:
                      (_out.supported && !_busy) ? _export : null,
                ),
              ),
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
            width: 52,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.pdfRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
                Text('$_size · $_pages Pages',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(ColorScheme scheme) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final o in _Out.values)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 40 - 14) / 2,
            child: _outCard(scheme, o),
          ),
      ],
    );
  }

  Widget _outCard(ColorScheme scheme, _Out o) {
    final selected = _out == o;
    return GestureDetector(
      onTap: () => setState(() => _out = o),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: o.tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(o.icon, color: o.tint),
            ),
            const SizedBox(height: 12),
            Text(o.label,
                style: Theme.of(context).textTheme.titleMedium),
            Text(o.sub,
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _unsupportedNote(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_out.label} export isn\'t supported offline — a PDF has no '
              '${_out == _Out.excel ? 'spreadsheet' : 'slide'} structure to rebuild. '
              'Export to Word, Text or Images instead.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
