import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/pdf_tools.dart';
import '../theme/app_theme.dart';
import 'compress_screen.dart';
import 'convert_screen.dart';
import 'export_screen.dart';
import 'merge_screen.dart';
import 'split_screen.dart';
import 'tool_result.dart';

/// The "Toolbox" tab — Optimize / Convert / Security tools.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Toolbox',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 4),
                    Text('Powerful tools to handle any document task.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Optimize'),
                  Tab(text: 'Convert'),
                  Tab(text: 'Security'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _OptimizeTab(),
                    ConvertScreen(),
                    _SecurityTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- shared cards

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String action;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(description,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(action,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _MiniTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: scheme.onSurface, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Optimize

class _OptimizeTab extends StatelessWidget {
  const _OptimizeTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _FeatureCard(
          icon: Icons.merge_rounded,
          title: 'Merge PDFs',
          description:
              'Combine multiple PDF documents into a single, organized file in seconds.',
          action: 'START MERGING',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MergeScreen())),
        ),
        _FeatureCard(
          icon: Icons.content_cut_rounded,
          title: 'Split PDF',
          description:
              'Extract specific pages or divide a large document into smaller files.',
          action: 'SELECT PAGES',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SplitScreen())),
        ),
        _FeatureCard(
          icon: Icons.ios_share_rounded,
          title: 'Export PDF',
          description:
              'Turn a PDF into page images, an editable Word document or plain text.',
          action: 'EXPORT PDF',
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ExportScreen())),
        ),
        Row(
          children: [
            Expanded(
                child: _MiniTile(
                    icon: Icons.compress_rounded,
                    label: 'Compress',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const CompressScreen())))),
            const SizedBox(width: 14),
            Expanded(
                child: _MiniTile(
                    icon: Icons.splitscreen_rounded,
                    label: 'Extract',
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SplitScreen())))),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- Security

class _SecurityTab extends StatelessWidget {
  const _SecurityTab();

  Future<void> _run(BuildContext context,
      {required bool protect}) async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    final pwd = await _askPassword(context, protect: protect);
    if (!context.mounted) return;
    if (pwd == null || pwd.isEmpty) return;

    try {
      final base = (result!.files.single.name).replaceAll('.pdf', '');
      final out = protect ? '${base}_protected.pdf' : '${base}_unlocked.pdf';
      final savedPath = protect
          ? await PdfTools.protect(path, pwd, out)
          : await PdfTools.unlock(path, pwd, out);
      if (context.mounted) showToolResult(context, savedPath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(protect
                ? 'Could not protect: $e'
                : 'Wrong password or failed: $e')));
      }
    }
  }

  Future<String?> _askPassword(BuildContext context,
      {required bool protect}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(protect ? 'Set a password' : 'Enter current password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Password'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(protect ? 'Protect' : 'Unlock')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _FeatureCard(
          icon: Icons.lock_rounded,
          title: 'Protect PDF',
          description:
              'Add a password so only people you trust can open the document.',
          action: 'ADD PASSWORD',
          onTap: () => _run(context, protect: true),
        ),
        _FeatureCard(
          icon: Icons.lock_open_rounded,
          title: 'Unlock PDF',
          description:
              'Remove a password from a PDF you own by entering its current password.',
          action: 'REMOVE PASSWORD',
          onTap: () => _run(context, protect: false),
        ),
      ],
    );
  }
}
