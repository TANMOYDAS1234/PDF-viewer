import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_tools.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'viewer_screen.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  String? _path;
  String _name = '';
  int _originalSize = 0;
  bool _busy = false;
  CompressResult? _result;

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
      _originalSize = f.size;
      _result = null;
    });
  }

  Future<void> _compress() async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final base = _name.replaceAll('.pdf', '');
      final res = await PdfTools.compress(_path!, '${base}_compressed.pdf');
      setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Compression failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(int b) => b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(0)} KB'
      : '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF'),
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
                const SizedBox(height: 20),
                if (_result == null) _intro(scheme) else _resultCard(scheme),
              ],
            ),
      bottomNavigationBar: _result == null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GradientButton(
                  label: 'Compress PDF',
                  icon: Icons.compress_rounded,
                  busy: _busy,
                  onPressed: _busy ? null : _compress,
                ),
              ),
            )
          : null,
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
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: AppColors.pdfRed),
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
                Text('Original size · ${_fmt(_originalSize)}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We\'ll re-pack the document with the best lossless compression to '
              'shrink its size without changing how it looks.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(ColorScheme scheme) {
    final r = _result!;
    final shrank = r.didShrink;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(
                  shrank
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  color: shrank ? AppColors.success : AppColors.primary,
                  size: 44),
              const SizedBox(height: 12),
              Text(
                shrank
                    ? 'Reduced by ${r.savedPercent.toStringAsFixed(0)}%'
                    : 'Already optimized',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sizePill('Before', _fmt(r.originalSize), scheme, false),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.primary),
                  _sizePill('After', _fmt(r.newSize), scheme, shrank),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Share.shareXFiles([XFile(r.path)]),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ViewerScreen(filePath: r.path)),
                ),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Open'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: _pick, child: const Text('Compress another')),
      ],
    );
  }

  Widget _sizePill(
      String label, String value, ColorScheme scheme, bool highlight) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.success : scheme.onSurface)),
      ],
    );
  }
}
