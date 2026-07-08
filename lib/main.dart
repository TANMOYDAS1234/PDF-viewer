import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_core/core.dart'; // for SyncfusionLicense

import 'services/app_intent.dart';
import 'services/settings_store.dart';
import 'services/theme_controller.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/splash_screen.dart';
import 'screens/viewer_screen.dart';

/// Global controllers (kept simple — no external state package).
final themeController = ThemeController();
final settingsStore = SettingsStore();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Syncfusion Community License (free). Paste your key below to remove the
  // trial banner:  https://www.syncfusion.com/products/communitylicense
  // SyncfusionLicense.registerLicense('YOUR_LICENSE_KEY');

  // Monetization (ads + "Remove Ads" purchase) is disabled for personal use.
  // To re-enable before publishing, follow monetization_disabled/README.md.

  runApp(const PdfViewerApp());
}

class PdfViewerApp extends StatefulWidget {
  const PdfViewerApp({super.key});

  @override
  State<PdfViewerApp> createState() => _PdfViewerAppState();
}

class _PdfViewerAppState extends State<PdfViewerApp> {
  final _navKey = GlobalKey<NavigatorState>();
  bool _splashDone = false;
  String? _pendingFile;

  @override
  void initState() {
    super.initState();
    themeController.load();
    settingsStore.load();
    _initIntents();
  }

  Future<void> _initIntents() async {
    // Cold start: app launched by opening a PDF — open once splash finishes.
    final initial = await AppIntent.getInitialFile();
    if (initial != null) {
      if (_splashDone) {
        _openViewer(initial);
      } else {
        _pendingFile = initial;
      }
    }
    // Warm start: another PDF opened while running.
    AppIntent.onOpenFile(_openViewer);
  }

  void _onSplashDone() {
    setState(() => _splashDone = true);
    final pending = _pendingFile;
    _pendingFile = null;
    if (pending != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openViewer(pending));
    }
  }

  void _openViewer(String path) {
    if (!_splashDone) {
      _pendingFile = path;
      return;
    }
    final nav = _navKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(builder: (_) => ViewerScreen(filePath: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navKey,
          title: 'PDF Viewer Pro',
          debugShowCheckedModeBanner: false,
          themeMode: themeController.mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: _splashDone
              ? const MainShell()
              : SplashScreen(onComplete: _onSplashDone),
        );
      },
    );
  }
}
