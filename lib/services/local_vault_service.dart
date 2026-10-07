import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track.dart';

class LocalVaultService extends ChangeNotifier {
  static final LocalVaultService instance = LocalVaultService._internal();
  LocalVaultService._internal();

  static String get defaultMusicPath {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return '/storage/emulated/0/Music';
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home${Platform.pathSeparator}Music${Platform.pathSeparator}SpectraFlow';
    }
    return '';
  }
  
  List<Track> _tracks = [];
  bool _isScanning = false;
  late String _activeVaultPath = defaultMusicPath;
  String _scanStatus = '';
  int _scannedCount = 0;
  int _totalToScan = 0;

  List<Track> get tracks => _tracks;
  bool get isScanning => _isScanning;
  String get activeVaultPath => _activeVaultPath;
  String get scanStatus => _scanStatus;
  int get scannedCount => _scannedCount;
  int get totalToScan => _totalToScan;

  /// Checks if a searched track matches any song in the local library/vault.
  /// Uses fuzzy cleaning (removing feat, official video, punctuation, and case normalization).
  Track? findLocalMatch(Track target) {
    if (_tracks.isEmpty) return null;

    // 1. Exact ID match
    for (final t in _tracks) {
      if (t.id == target.id) return t;
    }

    String normalize(String s) {
      var str = s.toLowerCase();
      // Remove bracketed info [Official Video], (feat. X), (Lyric Video), etc.
      str = str.replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), ' ');
      // Remove common noise terms
      str = str.replaceAll(RegExp(r'(?:official\s*(?:music)?\s*video|official\s*audio|visualizer|lyric\s*video|audio|video|ft\.?|feat\.?)', caseSensitive: false), ' ');
      // Strip punctuation & non-alphanumeric except spaces
      str = str.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
      // Collapse whitespace
      return str.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    final cleanSearchTitle = normalize(target.title);
    final cleanSearchArtist = normalize(target.artist);

    if (cleanSearchTitle.isEmpty) return null;

    for (final vaultTrack in _tracks) {
      final cleanVaultTitle = normalize(vaultTrack.title);
      final cleanVaultArtist = normalize(vaultTrack.artist);

      // Exact normalized title match
      if (cleanVaultTitle == cleanSearchTitle) {
        return vaultTrack;
      }

      // Title containment match (e.g. "rockstar" vs "rockstar 21 savage")
      if (cleanSearchTitle.length >= 3 && cleanVaultTitle.length >= 3) {
        if (cleanSearchTitle.contains(cleanVaultTitle) || cleanVaultTitle.contains(cleanSearchTitle)) {
          // If artist is also matched or not specified, confirm match
          if (cleanSearchArtist.isNotEmpty && cleanVaultArtist.isNotEmpty) {
            if (cleanSearchArtist.contains(cleanVaultArtist) ||
                cleanVaultArtist.contains(cleanSearchArtist) ||
                cleanSearchTitle.contains(cleanVaultArtist)) {
              return vaultTrack;
            }
          } else {
            return vaultTrack;
          }
        }
      }
    }

    return null;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      // Request audio, storage, and notification permissions
      final statuses = await [
        Permission.audio,
        Permission.storage,
        Permission.notification,
        Permission.manageExternalStorage,
      ].request();

      final audioGranted = statuses[Permission.audio]?.isGranted ?? false;
      final storageGranted = statuses[Permission.storage]?.isGranted ?? false;
      final manageGranted = statuses[Permission.manageExternalStorage]?.isGranted ?? false;
      return audioGranted || storageGranted || manageGranted;
    } catch (_) {
      return false;
    }
  }

  /// Resolves Android Storage Access Framework (SAF) URIs into physical storage paths
  static String resolveSafPath(String rawPath) {
    if (!Platform.isAndroid) return rawPath;

    var path = Uri.decodeFull(rawPath);

    // E.g. content://com.android.externalstorage.documents/tree/primary%3AMusic/document/primary%3AMusic...
    // or /tree/primary:Music
    if (path.contains('primary:')) {
      final sub = path.split('primary:').last;
      return '/storage/emulated/0/$sub';
    } else if (path.startsWith('content://')) {
      // Fall back to standard external music directory
      return '/storage/emulated/0/Music';
    }
    return path;
  }

  Future<void> init() async {
    if (kIsWeb) {
      // In web browser mode: load manifest generated from active music library
      try {
        final response = await http.get(Uri.parse('assets/vault_manifest.json'));
        if (response.statusCode == 200) {
          final List list = json.decode(response.body);
          _tracks = list.map((e) => Track.fromMap(e)).toList();
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    // 1. Resolve default music directory per platform
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        final androidMusicDir = Directory('/storage/emulated/0/Music');
        if (await androidMusicDir.exists()) {
          _activeVaultPath = androidMusicDir.path;
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          _activeVaultPath = docDir.path;
        }
      }
    }

    // 2. Try to load cached library first
    final cached = await _loadCache();
    if (cached.isNotEmpty) {
      _tracks = cached;
      notifyListeners();
    }

    // 3. If directory exists and cache was empty, automatically scan
    if (_tracks.isEmpty && !kIsWeb) {
      final dir = Directory(_activeVaultPath);
      if (await dir.exists()) {
        scanVault(_activeVaultPath);
      }
    }
  }

  Future<void> pickFolderAndScan() async {
    await requestPermissions();
    try {
      final selectedDir = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Music Library Folder',
        initialDirectory: _activeVaultPath,
      );
      if (selectedDir != null && selectedDir.isNotEmpty) {
        final resolvedPath = resolveSafPath(selectedDir);
        debugPrint('[LocalVaultService] Selected folder resolved: $resolvedPath');
        _activeVaultPath = resolvedPath;
        await scanVault(resolvedPath);
      }
    } catch (e) {
      debugPrint('[LocalVaultService] pickFolderAndScan error: $e');
    }
  }

  Future<void> scanVault([String? customPath]) async {
    if (kIsWeb) {
      await init();
      return;
    }
    await requestPermissions();
    final rawTarget = customPath ?? _activeVaultPath;
    final targetPath = resolveSafPath(rawTarget);
    _activeVaultPath = targetPath;
    final dir = Directory(targetPath);
    if (!await dir.exists()) {
      _scanStatus = 'Folder not found: $targetPath';
      notifyListeners();
      return;
    }

    _isScanning = true;
    _scanStatus = 'Scanning audio files in vault...';
    notifyListeners();

    try {
      final List<File> audioFiles = [];
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.path.toLowerCase();
          if (ext.endsWith('.flac') ||
              ext.endsWith('.mp3') ||
              ext.endsWith('.m4a') ||
              ext.endsWith('.wav') ||
              ext.endsWith('.ogg') ||
              ext.endsWith('.opus')) {
            audioFiles.add(entity);
          }
        }
      }

      _totalToScan = audioFiles.length;
      _scannedCount = 0;
      final List<Track> loadedTracks = [];

      final appCacheDir = await getApplicationSupportDirectory();
      final artDir = Directory('${appCacheDir.path}${Platform.pathSeparator}artworks');
      if (!await artDir.exists()) {
        await artDir.create(recursive: true);
      }

      for (final file in audioFiles) {
        _scannedCount++;
        _scanStatus = 'Indexing $_scannedCount of $_totalToScan files...';
        if (_scannedCount % 15 == 0) notifyListeners();

        try {
          final track = await _parseFileToTrack(file, artDir);
          loadedTracks.add(track);
        } catch (_) {
          // Continue indexing
        }
      }

      // Sort alphabetically by artist, then title
      loadedTracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      _tracks = loadedTracks;
      await _saveCache(loadedTracks);
    } catch (_) {
      // Graceful error recovery
    } finally {
      _isScanning = false;
      _scanStatus = 'Vault index complete (${_tracks.length} tracks).';
      notifyListeners();
    }
  }

  Future<Track> _parseFileToTrack(File file, Directory artDir) async {
    final fileName = file.uri.pathSegments.last;
    final nameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    String artist = 'Unknown Artist';
    String title = nameWithoutExt;

    // Pattern: "Artist - Title"
    if (nameWithoutExt.contains(' - ')) {
      final parts = nameWithoutExt.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    // Try extracting embedded cover art for FLAC files
    String? artworkPath;
    if (file.path.toLowerCase().endsWith('.flac')) {
      artworkPath = await _extractFlacCoverArt(file, artDir, nameWithoutExt);
    }

    final stat = await file.stat();
    final fileSize = stat.size;

    return Track(
      id: file.path.hashCode.abs().toString(),
      title: title,
      artist: artist,
      album: 'Lossless Vault',
      duration: const Duration(minutes: 3, seconds: 30), // Default approximate duration
      localPath: file.path,
      artworkUrl: artworkPath,
      format: _resolveFormat(file.path),
      fileSize: fileSize,
      dateAdded: stat.modified,
    );
  }

  AudioFormat _resolveFormat(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.flac')) return AudioFormat.flac;
    if (ext.endsWith('.opus')) return AudioFormat.opus;
    if (ext.endsWith('.m4a')) return AudioFormat.m4a;
    return AudioFormat.mp3;
  }

  // Pure Dart FLAC METADATA_BLOCK_PICTURE parser
  Future<String?> _extractFlacCoverArt(File file, Directory artDir, String baseName) async {
    try {
      final cleanBaseName = baseName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final outFile = File('${artDir.path}${Platform.pathSeparator}$cleanBaseName.jpg');
      if (await outFile.exists()) {
        return outFile.path;
      }

      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(4);
        // Verify 'fLaC' signature
        if (header.length < 4 ||
            header[0] != 0x66 ||
            header[1] != 0x4C ||
            header[2] != 0x61 ||
            header[3] != 0x43) {
          return null;
        }

        bool isLast = false;
        while (!isLast) {
          final blockHeader = await raf.read(4);
          if (blockHeader.length < 4) break;

          isLast = (blockHeader[0] & 0x80) != 0;
          final blockType = blockHeader[0] & 0x7F;
          final blockLength = (blockHeader[1] << 16) | (blockHeader[2] << 8) | blockHeader[3];

          if (blockType == 6) { // PICTURE block
            final pictureData = await raf.read(blockLength);
            if (pictureData.length >= 32) {
              final bd = ByteData.sublistView(pictureData);
              int offset = 4; // Skip picture type (4 bytes)
              final mimeLen = bd.getUint32(offset);
              offset += 4 + mimeLen;
              final descLen = bd.getUint32(offset);
              offset += 4 + descLen + 16; // Skip desc, width, height, depth, colors
              if (offset + 4 <= pictureData.length) {
                final picDataLen = bd.getUint32(offset);
                offset += 4;
                if (offset + picDataLen <= pictureData.length) {
                  final imgBytes = pictureData.sublist(offset, offset + picDataLen);
                  await outFile.writeAsBytes(imgBytes);
                  return outFile.path;
                }
              }
            }
            break;
          } else {
            await raf.setPosition(await raf.position() + blockLength);
          }
        }
      } finally {
        await raf.close();
      }
    } catch (_) {
      // Fallback gracefully
    }
    return null;
  }

  Future<List<Track>> _loadCache() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final cacheFile = File('${appDir.path}${Platform.pathSeparator}spectra_vault_cache.json');
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        final List list = json.decode(content);
        return list.map((e) => Track.fromMap(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> addDownloadedTrack(Track track) async {
    if (!_tracks.any((t) => t.localPath == track.localPath)) {
      _tracks.insert(0, track);
      await _saveCache(_tracks);
      notifyListeners();
    }
  }

  /// Removes a track from the in-memory library and the on-disk cache,
  /// but leaves the audio file untouched. The user can re-scan later to
  /// bring the track back.
  Future<void> removeTrack(String trackId) async {
    final initial = _tracks.length;
    _tracks.removeWhere((t) => t.id == trackId);
    if (_tracks.length != initial) {
      await _saveCache(_tracks);
      notifyListeners();
    }
  }

  /// Permanently deletes the audio file from disk and removes the track from
  /// the library index. Returns true if the file was deleted (or already
  /// missing) and the cache was updated; false if the track had no local
  /// file path or the deletion failed.
  Future<bool> deleteTrackFile(Track track) async {
    if (track.localPath == null) return false;
    bool deletedOk = true;
    try {
      final file = File(track.localPath!);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      deletedOk = false;
    }
    await removeTrack(track.id);
    return deletedOk;
  }

  Future<void> _saveCache(List<Track> tracks) async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final cacheFile = File('${appDir.path}${Platform.pathSeparator}spectra_vault_cache.json');
      final data = json.encode(tracks.map((t) => t.toMap()).toList());
      await cacheFile.writeAsString(data);
    } catch (_) {}
  }
}
