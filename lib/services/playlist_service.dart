import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CustomPlaylist {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final List<String> trackIds; // List of track IDs

  CustomPlaylist({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    required this.trackIds,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'trackIds': trackIds,
      };

  factory CustomPlaylist.fromMap(Map<String, dynamic> map) => CustomPlaylist(
        id: map['id'] ?? '',
        title: map['title'] ?? 'Untitled Playlist',
        description: map['description'] ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        trackIds: List<String>.from(map['trackIds'] ?? []),
      );

  CustomPlaylist copyWith({
    String? title,
    String? description,
    List<String>? trackIds,
  }) {
    return CustomPlaylist(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      trackIds: trackIds ?? this.trackIds,
    );
  }
}

class PlaylistService extends ChangeNotifier {
  static final PlaylistService instance = PlaylistService._internal();
  PlaylistService._internal();

  static const String likedSongsPlaylistId = 'playlist_liked_songs';

  final List<CustomPlaylist> _playlists = [];

  List<CustomPlaylist> get playlists => List.unmodifiable(_playlists);

  CustomPlaylist get likedSongsPlaylist {
    final idx = _playlists.indexWhere((p) => p.id == likedSongsPlaylistId);
    if (idx != -1) return _playlists[idx];
    return CustomPlaylist(
      id: likedSongsPlaylistId,
      title: 'Liked Songs',
      description: 'Your favorite tracks',
      createdAt: DateTime.now(),
      trackIds: [],
    );
  }

  bool isTrackLiked(String trackId) {
    final idx = _playlists.indexWhere((p) => p.id == likedSongsPlaylistId);
    if (idx == -1) return false;
    return _playlists[idx].trackIds.contains(trackId);
  }

  Future<bool> toggleLikeTrack(String trackId) async {
    int idx = _playlists.indexWhere((p) => p.id == likedSongsPlaylistId);
    if (idx == -1) {
      final likedPl = CustomPlaylist(
        id: likedSongsPlaylistId,
        title: 'Liked Songs',
        description: 'Your favorite tracks',
        createdAt: DateTime.now(),
        trackIds: [trackId],
      );
      _playlists.insert(0, likedPl);
      notifyListeners();
      await _saveToDisk();
      return true;
    } else {
      final current = _playlists[idx];
      final isLiked = current.trackIds.contains(trackId);
      final updatedList = List<String>.from(current.trackIds);
      if (isLiked) {
        updatedList.remove(trackId);
      } else {
        updatedList.insert(0, trackId);
      }
      _playlists[idx] = current.copyWith(trackIds: updatedList);
      notifyListeners();
      await _saveToDisk();
      return !isLiked;
    }
  }

  Future<void> init() async {
    await _loadFromDisk();
    // Ensure Liked Songs playlist exists
    if (!_playlists.any((p) => p.id == likedSongsPlaylistId)) {
      _playlists.insert(
        0,
        CustomPlaylist(
          id: likedSongsPlaylistId,
          title: 'Liked Songs',
          description: 'Your favorite tracks',
          createdAt: DateTime.now(),
          trackIds: [],
        ),
      );
      await _saveToDisk();
    }
  }

  Future<void> createPlaylist(String title, {String description = '', List<String>? trackIds}) async {
    final cleanTitle = title.trim().isEmpty ? 'My Playlist' : title.trim();
    final newPlaylist = CustomPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: cleanTitle,
      description: description.trim(),
      createdAt: DateTime.now(),
      trackIds: trackIds ?? [],
    );
    _playlists.insert(0, newPlaylist);
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final current = _playlists[idx];
      if (!current.trackIds.contains(trackId)) {
        final updatedList = List<String>.from(current.trackIds)..add(trackId);
        _playlists[idx] = current.copyWith(trackIds: updatedList);
        notifyListeners();
        await _saveToDisk();
      }
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final current = _playlists[idx];
      final updatedList = List<String>.from(current.trackIds)..remove(trackId);
      _playlists[idx] = current.copyWith(trackIds: updatedList);
      notifyListeners();
      await _saveToDisk();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> deleteMultiplePlaylists(Set<String> playlistIds) async {
    _playlists.removeWhere((p) => playlistIds.contains(p.id));
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> deleteAllPlaylists() async {
    _playlists.clear();
    notifyListeners();
    await _saveToDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      if (kIsWeb) {
        return;
      }
      final appDir = await getApplicationSupportDirectory();
      final file = File('${appDir.path}${Platform.pathSeparator}spectra_playlists.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List list = json.decode(content);
        _playlists.clear();
        _playlists.addAll(list.map((e) => CustomPlaylist.fromMap(e)));
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    try {
      if (kIsWeb) return;
      final appDir = await getApplicationSupportDirectory();
      final file = File('${appDir.path}${Platform.pathSeparator}spectra_playlists.json');
      final data = json.encode(_playlists.map((p) => p.toMap()).toList());
      await file.writeAsString(data);
    } catch (_) {}
  }
}