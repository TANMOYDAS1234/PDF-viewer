import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../services/recent_files.dart';
import '../services/scan_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/pdf_thumbnail.dart';
import 'scan_review_screen.dart';
import 'viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = RecentFilesStore();
  final _scrollController = ScrollController();
  final _allDocsKey = GlobalKey();
  List<RecentFile> _recents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    recentsRevision.addListener(_refresh);
  }

  @override
  void dispose() {
    recentsRevision.removeListener(_refresh);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final items = await _store.load();
    if (!mounted) return;
    setState(() {
      _recents = items;
      _loading = false;
    });
  }

  Future<void> _pickAndOpen() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path != null) _openFile(path);
  }

  Future<void> _openFile(String path) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewerScreen(filePath: path)),
    );
    _refresh();
  }

  Future<void> _scan() async {
    try {
      final images = await ScanService.scan();
      if (images == null || images.isEmpty || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ScanReviewScreen(imagePaths: images)),
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Scanner unavailable. Update Google Play services and try again.')),
        );
      }
    }
  }

  void _viewAll() {
    final ctx = _allDocsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    const Text('WELCOME BACK',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text('Your Library',
                        style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: 18),
                    GradientButton(
                      label: 'Open File',
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: _pickAndOpen,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _scan,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('Scan Document'),
                        style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_recents.isEmpty)
                      _emptyState()
                    else ...[
                      _recentActivity(),
                      const SizedBox(height: 28),
                      _allDocuments(),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text('PDF Pro',
            style: Theme.of(context).appBarTheme.titleTextStyle),
        const Spacer(),
        IconButton(
          tooltip: 'Search',
          onPressed: _recents.isEmpty
              ? null
              : () => showSearch(
                    context: context,
                    delegate: _RecentSearchDelegate(_recents, _openFile),
                  ),
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- recent activity

  Widget _recentActivity() {
    final recent = _recents.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent Activity',
            action: 'View All', onAction: _viewAll),
        const SizedBox(height: 12),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) => _recentCard(recent[i]),
          ),
        ),
      ],
    );
  }

  Widget _recentCard(RecentFile file) {
    final scheme = Theme.of(context).colorScheme;
    final exists = File(file.path).existsSync();
    return GestureDetector(
      onTap: () => _openFile(file.path),
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: double.infinity,
                      child: PdfThumbnail(path: file.path, exists: exists),
                    ),
                  ),
                  if (exists)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('Page ${file.lastPage}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              exists
                  ? 'Edited ${_relativeTime(file.lastOpened)} · ${_fileSize(file.path)}'
                  : 'File not available',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: exists ? scheme.onSurfaceVariant : scheme.error),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ all documents

  Widget _allDocuments() {
    return Column(
      key: _allDocsKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('All Documents',
                    style: Theme.of(context).textTheme.titleLarge)),
            AnimatedBuilder(
              animation: settingsStore,
              builder: (context, _) => Row(
                children: [
                  _viewToggle(Icons.grid_view_rounded, settingsStore.gridView,
                      () => settingsStore.setGridView(true)),
                  const SizedBox(width: 4),
                  _viewToggle(Icons.view_agenda_outlined,
                      !settingsStore.gridView,
                      () => settingsStore.setGridView(false)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: settingsStore,
          builder: (context, _) =>
              settingsStore.gridView ? _grid() : _list(),
        ),
      ],
    );
  }

  Widget _viewToggle(IconData icon, bool active, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 20,
            color: active ? AppColors.primary : scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _grid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: _recents.length + 1,
      itemBuilder: (context, i) {
        if (i == _recents.length) return _importTile();
        return _gridCard(_recents[i]);
      },
    );
  }

  Widget _gridCard(RecentFile file) {
    final scheme = Theme.of(context).colorScheme;
    final exists = File(file.path).existsSync();
    return GestureDetector(
      onTap: () => _openFile(file.path),
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                      child: PdfThumbnail(path: file.path, exists: exists)),
                  const Positioned(right: 8, top: 8, child: PdfBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return Column(
      children: [
        for (final file in _recents) _listTile(file),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickAndOpen,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  style: BorderStyle.solid),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_upload_outlined,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Import New',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listTile(RecentFile file) {
    final scheme = Theme.of(context).colorScheme;
    final exists = File(file.path).existsSync();
    return Dismissible(
      key: ValueKey(file.path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_rounded, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => _store.remove(file.path),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                  width: 46,
                  height: 58,
                  child: PdfThumbnail(path: file.path, exists: exists)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    exists
                        ? 'Page ${file.lastPage} · ${_relativeTime(file.lastOpened)}'
                        : 'File not available',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _openFile(file.path),
            ),
          ],
        ),
      ),
    );
  }

  Widget _importTile() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _pickAndOpen,
      child: DottedBorderBox(
        color: scheme.outlineVariant,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_upload_outlined,
                color: scheme.onSurfaceVariant, size: 30),
            const SizedBox(height: 8),
            Text('Import New',
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- empty state

  Widget _emptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded,
              size: 90, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No documents yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Open a PDF from your device, or tap any PDF elsewhere and choose PDF Viewer Pro.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- helpers

  Widget _sectionHeader(String title,
      {String? action, VoidCallback? onAction}) {
    return Row(
      children: [
        Expanded(
            child:
                Text(title, style: Theme.of(context).textTheme.titleLarge)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  String _relativeTime(int epochMillis) {
    if (epochMillis == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(date);
  }

  String _fileSize(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }
}

/// Simple dashed-border container for the "Import New" tile.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  const DottedBorderBox({super.key, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color),
      child: Center(child: child),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    const dash = 6.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
            metric.extractPath(dist, dist + dash), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ----------------------------------------------------------------- search

class _RecentSearchDelegate extends SearchDelegate<void> {
  final List<RecentFile> files;
  final void Function(String path) onOpen;
  _RecentSearchDelegate(this.files, this.onOpen);

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final matches = files
        .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (matches.isEmpty) {
      return const Center(child: Text('No matching documents'));
    }
    return ListView(
      children: [
        for (final f in matches)
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                  width: 40,
                  height: 50,
                  child: PdfThumbnail(
                      path: f.path, exists: File(f.path).existsSync())),
            ),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('Page ${f.lastPage}'),
            onTap: () {
              close(context, null);
              onOpen(f.path);
            },
          ),
      ],
    );
  }
}
