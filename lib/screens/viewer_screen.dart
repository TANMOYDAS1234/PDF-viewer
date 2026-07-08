import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../main.dart' show settingsStore;
import '../services/recent_files.dart';
import '../theme/app_theme.dart';
import 'thumbnail_grid.dart';

/// Full-featured PDF viewer: search, annotations, bookmarks, thumbnails,
/// night mode, zoom, layout modes, share and print.
class ViewerScreen extends StatefulWidget {
  final String filePath;
  const ViewerScreen({super.key, required this.filePath});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final GlobalKey<SfPdfViewerState> _viewerKey = GlobalKey();
  final PdfViewerController _controller = PdfViewerController();
  final UndoHistoryController _undoController = UndoHistoryController();
  final RecentFilesStore _recentStore = RecentFilesStore();
  final TextEditingController _searchField = TextEditingController();

  // Document state
  int _currentPage = 1;
  int _pageCount = 0;
  bool _loaded = false;
  String? _password;
  String? _loadError;

  // UI state
  bool _searchVisible = false;
  bool _nightMode = false;
  bool _horizontalScroll = false;
  bool _singlePageLayout = false;
  _AnnotTool _activeTool = _AnnotTool.none;
  Color _annotColor = const Color(0xFFFFEB3B); // yellow

  PdfTextSearchResult? _searchResult;

  // Read-aloud (text-to-speech)
  final FlutterTts _tts = FlutterTts();
  bool _ttsInited = false;
  bool _ttsActive = false; // control bar visible
  bool _ttsPlaying = false; // currently speaking
  double _ttsRate = 0.5;
  sfpdf.PdfDocument? _textDoc; // lazily loaded for text extraction

  String get _fileName {
    final parts = widget.filePath.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : widget.filePath;
  }

  @override
  void dispose() {
    _persistRecent();
    _searchResult?.removeListener(_onSearchChanged);
    _searchResult?.clear();
    _searchField.dispose();
    _undoController.dispose();
    _tts.stop();
    _textDoc?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _persistRecent() async {
    if (!_loaded) return;
    await _recentStore.add(
      widget.filePath,
      _fileName,
      lastPage: _currentPage,
      now: DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ---------------------------------------------------------------- search

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchResult?.clear();
        _searchResult = null;
        _searchField.clear();
      }
    });
  }

  void _runSearch(String text) {
    if (text.trim().isEmpty) return;
    _searchResult?.removeListener(_onSearchChanged);
    final result = _controller.searchText(text);
    result.addListener(_onSearchChanged);
    setState(() => _searchResult = result);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------- read aloud (TTS)

  Future<void> _initTts() async {
    if (_ttsInited) return;
    _ttsInited = true;
    _ttsRate = settingsStore.ttsRate; // use the user's default speed
    await _tts.setSpeechRate(_ttsRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // When a page finishes, advance and continue reading.
    _tts.setCompletionHandler(() {
      if (!mounted || !_ttsPlaying) return;
      if (_currentPage < _pageCount) {
        _controller.nextPage();
        _speakCurrentPage();
      } else {
        setState(() => _ttsPlaying = false);
      }
    });
  }

  Future<sfpdf.PdfDocument?> _ensureTextDoc() async {
    if (_textDoc != null) return _textDoc;
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      _textDoc = sfpdf.PdfDocument(inputBytes: bytes);
    } catch (_) {
      _textDoc = null;
    }
    return _textDoc;
  }

  String _pageText(int page) {
    final doc = _textDoc;
    if (doc == null || page < 1 || page > doc.pages.count) return '';
    try {
      return sfpdf.PdfTextExtractor(doc)
          .extractText(startPageIndex: page - 1, endPageIndex: page - 1)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _startReadAloud() async {
    await _initTts();
    await _ensureTextDoc();
    setState(() {
      _ttsActive = true;
      _ttsPlaying = true;
    });
    _speakCurrentPage();
  }

  /// Speak the current page; skip forward over pages that have no text.
  Future<void> _speakCurrentPage() async {
    if (!_ttsPlaying) return;
    var text = _pageText(_currentPage);
    // Skip empty (e.g. scanned image) pages.
    while (text.isEmpty && _currentPage < _pageCount && _ttsPlaying) {
      _controller.nextPage();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      text = _pageText(_currentPage);
    }
    if (text.isEmpty) {
      setState(() => _ttsPlaying = false);
      return;
    }
    await _tts.speak(text);
  }

  Future<void> _pauseReadAloud() async {
    await _tts.stop();
    setState(() => _ttsPlaying = false);
  }

  Future<void> _resumeReadAloud() async {
    setState(() => _ttsPlaying = true);
    _speakCurrentPage();
  }

  Future<void> _nextPageReadAloud() async {
    if (_currentPage >= _pageCount) return;
    await _tts.stop();
    _controller.nextPage();
    if (_ttsPlaying) {
      _speakCurrentPage();
    }
  }

  Future<void> _stopReadAloud() async {
    await _tts.stop();
    setState(() {
      _ttsActive = false;
      _ttsPlaying = false;
    });
  }

  Future<void> _setTtsRate(double rate) async {
    setState(() => _ttsRate = rate);
    await _tts.setSpeechRate(rate);
    // Apply immediately if currently reading.
    if (_ttsPlaying) {
      await _tts.stop();
      _speakCurrentPage();
    }
  }

  // ------------------------------------------------------------ annotations

  void _selectTool(_AnnotTool tool) {
    setState(() {
      _activeTool = _activeTool == tool ? _AnnotTool.none : tool;
      _controller.annotationMode = switch (_activeTool) {
        _AnnotTool.highlight => PdfAnnotationMode.highlight,
        _AnnotTool.underline => PdfAnnotationMode.underline,
        _AnnotTool.strikethrough => PdfAnnotationMode.strikethrough,
        _AnnotTool.squiggly => PdfAnnotationMode.squiggly,
        _AnnotTool.stickyNote => PdfAnnotationMode.stickyNote,
        _AnnotTool.none => PdfAnnotationMode.none,
      };
      _applyAnnotColor();
    });
  }

  void _applyAnnotColor() {
    // Set the default color for the active annotation tool.
    final s = _controller.annotationSettings;
    switch (_activeTool) {
      case _AnnotTool.highlight:
        s.highlight.color = _annotColor;
      case _AnnotTool.underline:
        s.underline.color = _annotColor;
      case _AnnotTool.strikethrough:
        s.strikethrough.color = _annotColor;
      case _AnnotTool.squiggly:
        s.squiggly.color = _annotColor;
      case _AnnotTool.stickyNote:
        s.stickyNote.color = _annotColor;
      case _AnnotTool.none:
        break;
    }
  }

  void _pickAnnotColor(Color color) {
    setState(() {
      _annotColor = color;
      _applyAnnotColor();
    });
  }

  // -------------------------------------------------------------- view opts

  void _toggleNightMode() => setState(() => _nightMode = !_nightMode);

  void _toggleScrollDirection() =>
      setState(() => _horizontalScroll = !_horizontalScroll);

  void _toggleLayout() =>
      setState(() => _singlePageLayout = !_singlePageLayout);

  void _zoom(double delta) {
    final next = (_controller.zoomLevel + delta).clamp(1.0, 5.0);
    _controller.zoomLevel = next;
  }

  Future<void> _jumpToPageDialog() async {
    final controller = TextEditingController();
    final page = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '1 – $_pageCount',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (page != null && page >= 1 && page <= _pageCount) {
      _controller.jumpToPage(page);
    }
  }

  // -------------------------------------------------------------- share/print

  Future<void> _share() async {
    await Share.shareXFiles([XFile(widget.filePath)], text: _fileName);
  }

  /// Save a copy of the current PDF to a user-chosen location on the device
  /// (Downloads, etc.) via the system Save dialog — needs no permission.
  Future<void> _saveToDevice() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF to device',
        fileName: _fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result == null ? 'Save cancelled' : 'Saved to device'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Future<void> _print() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print: $e')),
        );
      }
    }
  }

  // -------------------------------------------------------------- password

  Future<void> _promptPassword() async {
    final controller = TextEditingController();
    final pwd = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Password required'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter PDF password',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (pwd == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _password = pwd;
        _loadError = null;
      });
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: _searchVisible ? _searchAppBar(scheme) : _mainAppBar(scheme),
      body: Column(
        children: [
          if (_loadError != null)
            _errorBanner(scheme)
          else
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildViewer()),
                  if (_loaded)
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(child: _pagePill(scheme)),
                    ),
                ],
              ),
            ),
          if (_ttsActive && _loadError == null) _readAloudBar(scheme),
          if (_activeTool != _AnnotTool.none && _loadError == null)
            _annotationToolbar(scheme),
          // The dock hides while annotating (the annotation toolbar replaces it).
          if (_loaded && _loadError == null && _activeTool == _AnnotTool.none)
            _toolDock(scheme),
        ],
      ),
    );
  }

  /// Floating "‹ 3 of 24 ›" pill at the top of the page.
  Widget _pagePill(ColorScheme scheme) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left_rounded, size: 22),
              onPressed:
                  _currentPage > 1 ? () => _controller.previousPage() : null,
            ),
            GestureDetector(
              onTap: _jumpToPageDialog,
              child: Text('$_currentPage of $_pageCount',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right_rounded, size: 22),
              onPressed: _currentPage < _pageCount
                  ? () => _controller.nextPage()
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Persistent bottom tool dock: read-aloud, annotation tools, zoom.
  Widget _toolDock(ColorScheme scheme) {
    Widget tool(IconData icon, String tip, VoidCallback onTap,
        {bool active = false}) {
      return IconButton(
        tooltip: tip,
        icon: Icon(icon, size: 22),
        color: active ? AppColors.primary : scheme.onSurface,
        onPressed: onTap,
      );
    }

    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                tool(Icons.volume_up_rounded, 'Read aloud',
                    _ttsActive ? _stopReadAloud : _startReadAloud,
                    active: _ttsActive),
                _dockDivider(scheme),
                tool(Icons.brush_rounded, 'Highlight',
                    () => _selectTool(_AnnotTool.highlight),
                    active: _activeTool == _AnnotTool.highlight),
                tool(Icons.format_underlined_rounded, 'Underline',
                    () => _selectTool(_AnnotTool.underline),
                    active: _activeTool == _AnnotTool.underline),
                tool(Icons.sticky_note_2_outlined, 'Sticky note',
                    () => _selectTool(_AnnotTool.stickyNote),
                    active: _activeTool == _AnnotTool.stickyNote),
                tool(Icons.gesture_rounded, 'Squiggly',
                    () => _selectTool(_AnnotTool.squiggly),
                    active: _activeTool == _AnnotTool.squiggly),
                _dockDivider(scheme),
                tool(Icons.zoom_in_rounded, 'Zoom in', () => _zoom(0.25)),
                tool(Icons.zoom_out_rounded, 'Zoom out', () => _zoom(-0.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dockDivider(ColorScheme scheme) => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: scheme.outlineVariant,
      );

  Widget _buildViewer() {
    final viewer = SfPdfViewer.file(
      File(widget.filePath),
      key: ValueKey('${widget.filePath}|$_password'),
      controller: _controller,
      undoController: _undoController,
      password: _password,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      canShowPaginationDialog: false,
      enableTextSelection: true,
      enableDoubleTapZooming: true,
      pageLayoutMode: _singlePageLayout
          ? PdfPageLayoutMode.single
          : PdfPageLayoutMode.continuous,
      scrollDirection: _horizontalScroll
          ? PdfScrollDirection.horizontal
          : PdfScrollDirection.vertical,
      onDocumentLoaded: (details) {
        setState(() {
          _loaded = true;
          _pageCount = details.document.pages.count;
        });
        // Resume where we left off.
        _resumeIfPossible();
      },
      onDocumentLoadFailed: (details) {
        final desc = details.description.toLowerCase();
        if (desc.contains('password') || desc.contains('encrypted')) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _promptPassword());
        } else {
          setState(() => _loadError = details.description);
        }
      },
      onPageChanged: (details) {
        setState(() => _currentPage = details.newPageNumber);
      },
    );

    if (_nightMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255, //
          0, -1, 0, 0, 255, //
          0, 0, -1, 0, 255, //
          0, 0, 0, 1, 0, //
        ]),
        child: viewer,
      );
    }
    return viewer;
  }

  Future<void> _resumeIfPossible() async {
    final recents = await _recentStore.load();
    final match = recents.where((e) => e.path == widget.filePath);
    if (match.isNotEmpty && match.first.lastPage > 1) {
      final page = match.first.lastPage;
      if (page <= _pageCount) {
        _controller.jumpToPage(page);
      }
    }
  }

  Future<void> _openThumbnails() async {
    final page = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => ThumbnailGridScreen(
          filePath: widget.filePath,
          pageCount: _pageCount,
          currentPage: _currentPage,
        ),
      ),
    );
    if (page != null) _controller.jumpToPage(page);
  }

  // ------------------------------------------------------------- read-aloud UI

  Widget _readAloudBar(ColorScheme scheme) {
    return Material(
      elevation: 8,
      color: scheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.record_voice_over_rounded,
                  color: scheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text('Read aloud',
                  style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                tooltip: _ttsPlaying ? 'Pause' : 'Play',
                icon: Icon(_ttsPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded),
                iconSize: 34,
                color: scheme.primary,
                onPressed: _ttsPlaying ? _pauseReadAloud : _resumeReadAloud,
              ),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: _nextPageReadAloud,
              ),
              PopupMenuButton<double>(
                tooltip: 'Speed',
                icon: const Icon(Icons.speed_rounded),
                initialValue: _ttsRate,
                onSelected: _setTtsRate,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 0.25, child: Text('0.5×  Slow')),
                  PopupMenuItem(value: 0.5, child: Text('1×  Normal')),
                  PopupMenuItem(value: 0.75, child: Text('1.5×  Fast')),
                  PopupMenuItem(value: 1.0, child: Text('2×  Faster')),
                ],
              ),
              IconButton(
                tooltip: 'Stop',
                icon: const Icon(Icons.close_rounded),
                onPressed: _stopReadAloud,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- app bars

  PreferredSizeWidget _mainAppBar(ColorScheme scheme) {
    return AppBar(
      title: Text(_fileName, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          onPressed: _loaded ? _toggleSearch : null,
        ),
        IconButton(
          tooltip: 'Night mode',
          icon: Icon(_nightMode
              ? Icons.nightlight_round
              : Icons.nightlight_outlined),
          color: _nightMode ? scheme.primary : null,
          onPressed: _loaded ? _toggleNightMode : null,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            switch (value) {
              case 'thumbnails':
                _openThumbnails();
              case 'bookmarks':
                _viewerKey.currentState?.openBookmarkView();
              case 'read':
                _startReadAloud();
              case 'layout':
                _toggleLayout();
              case 'scroll':
                _toggleScrollDirection();
              case 'save':
                _saveToDevice();
              case 'share':
                _share();
              case 'print':
                _print();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'thumbnails',
              child: ListTile(
                leading: Icon(Icons.grid_view_rounded),
                title: Text('Thumbnails'),
              ),
            ),
            const PopupMenuItem(
              value: 'bookmarks',
              child: ListTile(
                leading: Icon(Icons.bookmarks_outlined),
                title: Text('Outline / Bookmarks'),
              ),
            ),
            const PopupMenuItem(
              value: 'read',
              child: ListTile(
                leading: Icon(Icons.record_voice_over_rounded),
                title: Text('Read aloud'),
              ),
            ),
            PopupMenuItem(
              value: 'layout',
              child: ListTile(
                leading: const Icon(Icons.auto_stories_rounded),
                title: Text(
                    _singlePageLayout ? 'Continuous scroll' : 'Single page'),
              ),
            ),
            PopupMenuItem(
              value: 'scroll',
              child: ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: Text(_horizontalScroll
                    ? 'Vertical scroll'
                    : 'Horizontal scroll'),
              ),
            ),
            const PopupMenuItem(
              value: 'save',
              child: ListTile(
                leading: Icon(Icons.download_rounded),
                title: Text('Save to device'),
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share_rounded),
                title: Text('Share'),
              ),
            ),
            const PopupMenuItem(
              value: 'print',
              child: ListTile(
                leading: Icon(Icons.print_rounded),
                title: Text('Print'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _searchAppBar(ColorScheme scheme) {
    final result = _searchResult;
    final hasResult = result != null && result.hasResult;
    final searching =
        result != null && !result.isSearchCompleted && !hasResult;
    final noResults = result != null &&
        result.isSearchCompleted &&
        !hasResult &&
        _searchField.text.trim().isNotEmpty;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _toggleSearch,
      ),
      title: TextField(
        controller: _searchField,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Search document…',
          border: InputBorder.none,
        ),
        onSubmitted: _runSearch,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        if (searching)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if (noResults)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('No results',
                  style: TextStyle(color: scheme.error)),
            ),
          )
        else if (hasResult)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${result.currentInstanceIndex}/${result.totalInstanceCount}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Previous',
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          onPressed: hasResult ? () => result.previousInstance() : null,
        ),
        IconButton(
          tooltip: 'Next',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: hasResult ? () => result.nextInstance() : null,
        ),
      ],
    );
  }

  // ----------------------------------------------------------- annotation bar

  Widget _annotationToolbar(ColorScheme scheme) {
    const palette = [
      Color(0xFFFFEB3B), // yellow
      Color(0xFF4CAF50), // green
      Color(0xFF2196F3), // blue
      Color(0xFFF44336), // red
      Color(0xFFFF9800), // orange
      Color(0xFF9C27B0), // purple
    ];
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _toolBtn(_AnnotTool.highlight, Icons.brush_rounded,
                        'Highlight', scheme),
                    _toolBtn(_AnnotTool.underline,
                        Icons.format_underlined_rounded, 'Underline', scheme),
                    _toolBtn(
                        _AnnotTool.strikethrough,
                        Icons.strikethrough_s_rounded,
                        'Strikethrough',
                        scheme),
                    _toolBtn(_AnnotTool.squiggly, Icons.waves_rounded,
                        'Squiggly', scheme),
                    _toolBtn(_AnnotTool.stickyNote,
                        Icons.sticky_note_2_outlined, 'Sticky note', scheme),
                    const VerticalDivider(width: 16),
                    IconButton(
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: () => _undoController.undo(),
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      icon: const Icon(Icons.redo_rounded),
                      onPressed: () => _undoController.redo(),
                    ),
                    IconButton(
                      tooltip: 'Done',
                      icon: Icon(Icons.check_circle_rounded,
                          color: scheme.primary),
                      onPressed: () => _selectTool(_activeTool),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  for (final c in palette)
                    GestureDetector(
                      onTap: () => _pickAnnotColor(c),
                      child: Container(
                        margin: const EdgeInsets.all(5),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _annotColor == c
                                ? scheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(
      _AnnotTool tool, IconData icon, String label, ColorScheme scheme) {
    final active = _activeTool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _selectTool(tool),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active ? scheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: active ? scheme.onPrimaryContainer : scheme.onSurface),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- error UI

  Widget _errorBanner(ColorScheme scheme) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded, size: 72, color: scheme.error),
              const SizedBox(height: 16),
              Text('Could not open this PDF',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_loadError ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AnnotTool { none, highlight, underline, strikethrough, squiggly, stickyNote }
