import 'package:flutter/services.dart';

/// Bridge to the native Android intent handler (see MainActivity.kt).
///
/// Gives Flutter the PDF the app was launched or resumed with when the user
/// taps a PDF elsewhere and picks this app from the "Open with" list.
class AppIntent {
  AppIntent._();

  static const MethodChannel _channel =
      MethodChannel('com.tanmoy.pdf_viewer_pro/intent');

  /// The file the app was cold-started with, if any.
  static Future<String?> getInitialFile() async {
    try {
      return await _channel.invokeMethod<String>('getInitialFile');
    } catch (_) {
      return null;
    }
  }

  /// Fires when a PDF is opened while the app is already running (warm start).
  static void onOpenFile(void Function(String path) callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile' && call.arguments is String) {
        callback(call.arguments as String);
      }
      return null;
    });
  }
}
