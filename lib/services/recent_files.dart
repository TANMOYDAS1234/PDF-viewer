import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bumped whenever the recent-files list changes, so screens can refresh.
final ValueNotifier<int> recentsRevision = ValueNotifier<int>(0);

/// A single entry in the recent-files list.
class RecentFile {
  final String path;
  final String name;
  final int lastOpened; // epoch millis
  final int lastPage; // resume position

  RecentFile({
    required this.path,
    required this.name,
    required this.lastOpened,
    this.lastPage = 1,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpened': lastOpened,
        'lastPage': lastPage,
      };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        path: json['path'] as String,
        name: json['name'] as String,
        lastOpened: json['lastOpened'] as int? ?? 0,
        lastPage: json['lastPage'] as int? ?? 1,
      );
}

/// Persists recently-opened PDFs (most recent first).
class RecentFilesStore {
  static const _key = 'recent_files';
  static const _maxEntries = 40;

  Future<List<RecentFile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((s) {
          try {
            return RecentFile.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<RecentFile>()
        .toList();
  }

  Future<void> _save(List<RecentFile> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
    recentsRevision.value++;
  }

  /// Add or move a file to the top, updating its resume page.
  Future<List<RecentFile>> add(
    String path,
    String name, {
    int lastPage = 1,
    required int now,
  }) async {
    final items = await load();
    items.removeWhere((e) => e.path == path);
    items.insert(
      0,
      RecentFile(path: path, name: name, lastOpened: now, lastPage: lastPage),
    );
    if (items.length > _maxEntries) {
      items.removeRange(_maxEntries, items.length);
    }
    await _save(items);
    return items;
  }

  Future<List<RecentFile>> remove(String path) async {
    final items = await load();
    items.removeWhere((e) => e.path == path);
    await _save(items);
    return items;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    recentsRevision.value++;
  }
}
