import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences (besides theme). Listenable so screens react.
class SettingsStore extends ChangeNotifier {
  static const _kTtsRate = 'tts_rate';
  static const _kGridView = 'home_grid_view';

  double _ttsRate = 0.5; // flutter_tts scale (0.5 == "normal")
  bool _gridView = true;

  double get ttsRate => _ttsRate;
  bool get gridView => _gridView;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _ttsRate = p.getDouble(_kTtsRate) ?? 0.5;
    _gridView = p.getBool(_kGridView) ?? true;
    notifyListeners();
  }

  Future<void> setTtsRate(double v) async {
    _ttsRate = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kTtsRate, v);
  }

  Future<void> setGridView(bool v) async {
    _gridView = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kGridView, v);
  }
}
