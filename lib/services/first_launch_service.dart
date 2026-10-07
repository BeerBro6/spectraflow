import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/library_screen.dart' show LibraryViewMode;

/// Persists first-launch state (mode selection + feature intro completion)
/// in a JSON document under the app support directory. This mirrors the
/// existing persistence pattern used by [PlaylistService] and [LocalVaultService]
/// so no new package is required.
class FirstLaunchService {
  static const String _fileName = 'sf_first_launch.json';

  static Future<Map<String, dynamic>> _read() async {
    if (kIsWeb) return {};
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = json.decode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _write(Map<String, dynamic> data) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      await file.writeAsString(json.encode(data));
    } catch (_) {
      // Storage failures here are non-fatal — the worst case is the user
      // sees the welcome / intro flow again on next launch.
    }
  }

  static Future<bool> needsModeSelection() async {
    final data = await _read();
    return data['mode_selected'] != true;
  }

  static Future<bool> needsIntro() async {
    final data = await _read();
    return data['intro_seen'] != true;
  }

  static Future<LibraryViewMode?> readSelectedMode() async {
    final data = await _read();
    final name = data['selected_mode'];
    if (name == LibraryViewMode.classic.name) return LibraryViewMode.classic;
    if (name == LibraryViewMode.audiophileHybrid.name) {
      return LibraryViewMode.audiophileHybrid;
    }
    return null;
  }

  static Future<void> markModeSelected(LibraryViewMode mode) async {
    final data = await _read();
    data['mode_selected'] = true;
    data['selected_mode'] = mode.name;
    await _write(data);
  }

  static Future<void> markIntroSeen() async {
    final data = await _read();
    data['intro_seen'] = true;
    await _write(data);
  }

  static Future<String?> readUserName() async {
    final data = await _read();
    final name = data['user_name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return null;
  }

  static Future<void> setUserName(String name) async {
    final data = await _read();
    data['user_name'] = name.trim();
    await _write(data);
  }

  /// Reset everything — used by a future "Replay Onboarding" action in
  /// settings, or for QA. Wipes flags.
  static Future<void> reset() async {
    await _write(<String, dynamic>{});
  }
}