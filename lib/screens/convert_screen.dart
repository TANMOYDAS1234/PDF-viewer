import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/pdf_tools.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'export_screen.dart';
import 'tool_result.dart';

enum _Format { images, word, powerpoint, excel, text }

extension _FormatInfo on _Format {
  String get label => switch (this) {
        _Format.images => 'Images',
        _Format.word => 'Word',
        _Format.powerpoint => 'PowerPoint',
        _Format.excel => 'Excel',
        _Format.text => 'Text',
      };

  IconData get icon => switch (this) {
        _Format.images => Icons.image_outlined,
        _Format.word => Icons.description_outlined,
        _Format.powerpoint => Icons.slideshow_outlined,
        _Format.excel => Icons.table_chart_outlined,
        _Format.text => Icons.text_snippet_outlined,
      };

  Color get tint => switch (this) {
        _Format.images => AppColors.primary,
        _Format.word => const Color(0xFF2563EB),
        _Format.powerpoint => const Color(0xFFEA580C),
        _Format.excel => const Color(0xFF16A34A),
        _Format.text => const Color(0xFF6B7280),
      };

  bool get isOffice =>
      this == _Format.word || this == _Format.powerpoint || this == _Format.excel;

  List<String> get extensions => switch (this) {
        _Format.images => [
            'jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp', 'tif', 'tiff', 'tga',
            'ico'
          ],
        _Format.text => ['txt', 'md', 'csv', 'log', 'json', 'xml', 'yaml'],
        _Format.word => ['docx'],
        _Format.powerpoint => ['pptx'],
        _Format.excel => ['xlsx'],
      };
}

/// "Convert to PDF" — Images and Text convert fully offline; Office formats are
/// honestly shown as needing an online engine.
class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  _Format _format = _Format.images;
  final List<PlatformFile> _files = [];
  bool _busy = false;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _format.extensions,
      allowMultiple: _format == _Format.images,
    );
    if (result == null) return;
    setState(() {
      if (_format != _Format.images) _files.clear();
      _files.addAll(result.files.where((f) => f.path != null));
    });
  }

  Future<void> _convert() async {
    if (_files.isEmpty) return;
    setState(() => _busy = true);
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final first = _files.first.path!;
      final base = _files.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      final out = '${base}_$stamp.pdf';
      final path = switch (_format) {
        _Format.images => await PdfTools.imagesToPdf(
            _files.map((e) => e.path!).toList(), 'images_$stamp.pdf'),
        _Format.text => await PdfTools.textToPdf(first, out),
        _Format.word => await PdfTools.docxToPdf(first, out),
        _Format.powerpoint => await PdfTools.pptxToPdf(first, out),
        _Format.excel => await PdfTools.xlsxToPdf(first, out),
      };
      if (mounted) {
        setState(_files.clear);
        showToolResult(context, path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExportScreen())),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.ios_share_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Have a PDF? Export it to images, Word or text',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              Text('Select source format',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _formatGrid(scheme),
              const SizedBox(height: 24),
              _dropzone(scheme),
              if (_format.isOffice) ...[
                const SizedBox(height: 12),
                _officeNote(scheme),
              ],
              if (_files.isNotEmpty) ...[
                const SizedBox(height: 16),
                _fileList(scheme),
              ],
            ],
          ),
        ),
        if (_files.isNotEmpty)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: GradientButton(
                label: 'Convert to PDF',
                icon: Icons.bolt_rounded,
                busy: _busy,
                onPressed: _busy ? null : _convert,
              ),
            ),
          ),
      ],
    );
  }

  Widget _formatGrid(ColorScheme scheme) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final f in _Format.values)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 40 - 14) / 2,
            child: _formatCard(scheme, f),
          ),
      ],
    );
  }

  Widget _formatCard(ColorScheme scheme, _Format f) {
    final selected = _format == f;
    return GestureDetector(
      onTap: () => setState(() {
        _format = f;
        _files.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: f.tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(f.icon, color: f.tint),
            ),
            const SizedBox(height: 10),
            Text(f.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _dropzone(ColorScheme scheme) {
    return GestureDetector(
      onTap: _pick,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.upload_file_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: 14),
            Text('Tap to select ${_format.label.toLowerCase()}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _format == _Format.images
                  ? 'JPG, PNG, WEBP · you can pick several'
                  : 'A .txt file',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _officeNote(ColorScheme scheme) {
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
              'Text and tables are extracted into the PDF on-device. Images and '
              'complex layouts are simplified. Works with .${_format.extensions.first} files.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileList(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECTED (${_files.length})',
            style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
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
              Container(
                key: ValueKey(_files[i].path),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    if (_format == _Format.images)
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(Icons.drag_indicator_rounded,
                            color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(width: 6),
                    Icon(_format.icon, color: _format.tint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_files[i].name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _files.removeAt(i)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(_format == _Format.images ? 'Add more' : 'Change file'),
          ),
        ),
      ],
    );
  }
}
