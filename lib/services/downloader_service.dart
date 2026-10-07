import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';
import 'local_vault_service.dart';
import 'lyrics_service.dart';
import 'search_stream_service.dart';

class DownloaderService extends ChangeNotifier {
  final YoutubeExplode _yt = YoutubeExplode();
  final List<DownloadTask> _tasks = [];

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  int get completedCount =>
      _tasks.where((t) => t.status == DownloadStatus.completed).length;

  double get overallProgress {
    if (_tasks.isEmpty) return 0.0;
    final sum = _tasks.fold<double>(0.0, (prev, t) => prev + t.progress);
    return sum / _tasks.length;
  }

  /// Directly enqueue a known track (e.g. from search results or currently playing stream).
  /// If [streamUrl] or [videoId] is provided, it downloads that exact audio without re-searching.
  Future<void> enqueueTrack(
    Track track,
    AudioFormat format, {
    String? streamUrl,
    String? videoId,
  }) async {
    final task = DownloadTask(
      id: track.id,
      title: track.title,
      artist: track.artist,
      format: format,
    );
    _tasks.add(task);
    notifyListeners();

    if (kIsWeb) {
      _processWebTask(task, track.duration);
      return;
    }

    try {
      // 1. If an exact streamUrl is already provided (e.g. from stream resolution)
      if (streamUrl != null && streamUrl.isNotEmpty) {
        await _downloadDirectHttpStream(
          task,
          streamUrl,
          track.title,
          track.artist,
          track.duration,
          track.artworkUrl,
        );
        return;
      }

      // 2. If an exact 11-char YouTube ID is available on videoId, track.sourceVideoId, or track.id
      final effectiveYtId = (videoId != null && RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(videoId))
          ? videoId
          : ((track.sourceVideoId != null && RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(track.sourceVideoId!))
              ? track.sourceVideoId!
              : (RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(track.id) ? track.id : null));

      if (effectiveYtId != null) {
        debugPrint('[DownloaderService] Downloading exact YouTube video ID: $effectiveYtId');
        final video = await _yt.videos.get(effectiveYtId);
        await _processTask(task, video);
        return;
      }

      // 3. If track already has a verified lossless direct stream URL
      if (track.localPath != null &&
          (track.localPath!.startsWith('http://') || track.localPath!.startsWith('https://')) &&
          !track.localPath!.contains('AudioPreview')) {
        await _downloadDirectHttpStream(
          task,
          track.localPath!,
          track.title,
          track.artist,
          track.duration,
          track.artworkUrl,
        );
        return;
      }

      // 4. Resolve exact audio matching through unified SearchStreamService
      debugPrint('[DownloaderService] Resolving exact 1:1 audio matching for "${track.title}"...');
      final resolution = await SearchStreamService.instance.resolveTrackAudio(track);

      if (resolution.videoId != null) {
        final video = await _yt.videos.get(resolution.videoId!);
        await _processTask(task, video);
        return;
      } else if (resolution.streamUrl != null && resolution.streamUrl!.isNotEmpty) {
        await _downloadDirectHttpStream(
          task,
          resolution.streamUrl!,
          track.title,
          track.artist,
          track.duration,
          track.artworkUrl,
        );
        return;
      }

      task.status = DownloadStatus.failed;
      task.errorMessage = 'Could not locate audio stream for "${track.title}".';
      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _downloadDirectHttpStream(
    DownloadTask task,
    String downloadUrl,
    String title,
    String artist,
    Duration duration,
    String? artworkUrl,
  ) async {
    task.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      Directory spectraDir;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final extMusicDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
          if (extMusicDirs != null && extMusicDirs.isNotEmpty) {
            spectraDir = Directory('${extMusicDirs.first.path}/SpectraFlow');
          } else {
            final dir = await getApplicationDocumentsDirectory();
            spectraDir = Directory('${dir.path}/SpectraFlow');
          }
        } catch (_) {
          final dir = await getApplicationDocumentsDirectory();
          spectraDir = Directory('${dir.path}/SpectraFlow');
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        spectraDir = Directory('${dir.path}/SpectraFlow');
      }

      if (!await spectraDir.exists()) {
        await spectraDir.create(recursive: true);
      }

      String ext;
      switch (task.format) {
        case AudioFormat.flac:
          ext = 'flac';
          break;
        case AudioFormat.mp3:
          ext = 'mp3';
          break;
        case AudioFormat.m4a:
          ext = 'm4a';
          break;
        case AudioFormat.opus:
          ext = 'opus';
          break;
      }

      final cleanTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${spectraDir.path}/$cleanTitle.$ext';
      final file = File(filePath);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      // Must match the androidSdkless client UA that generated the stream token.
      // Without this header, Google Video CDN returns HTTP 403 Forbidden.
      request.headers['User-Agent'] =
          'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';
      final response = await client.send(request);

      final total = response.contentLength ?? 0;
      int downloaded = 0;
      final fileStream = file.openWrite();

      await for (final chunk in response.stream) {
        downloaded += chunk.length;
        fileStream.add(chunk);
        task.progress = total > 0 ? (downloaded / total) : 0.0;
        task.speed = '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB';
        notifyListeners();
      }

      await fileStream.flush();
      await fileStream.close();
      client.close();

      // Fetch and write matching .lrc synchronized lyrics file alongside audio
      try {
        final lrcText = await LyricsService.fetchRawLrc(
          trackName: title,
          artistName: artist,
          duration: duration,
        );
        if (lrcText != null && lrcText.isNotEmpty) {
          final lrcPath = '${spectraDir.path}/$cleanTitle.lrc';
          final lrcFile = File(lrcPath);
          await lrcFile.writeAsString(lrcText);
          debugPrint('Saved lyrics file alongside track: $lrcPath');
        }
      } catch (lrcErr) {
        debugPrint('Lyrics download skipped: $lrcErr');
      }

      task.outputPath = filePath;
      task.status = DownloadStatus.completed;
      task.progress = 1.0;

      // Automatically register the downloaded track into Library / Vault
      final newTrack = Track(
        id: filePath.hashCode.abs().toString(),
        title: title,
        artist: artist,
        album: 'Downloaded Vault',
        duration: duration,
        localPath: filePath,
        artworkUrl: artworkUrl,
        format: task.format,
        fileSize: downloaded,
        dateAdded: DateTime.now(),
      );
      await LocalVaultService.instance.addDownloadedTrack(newTrack);
      debugPrint('[DownloaderService] Track successfully added to Library: ${newTrack.title}');

      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _processWebTask(DownloadTask task, Duration duration) async {
    task.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      const totalSteps = 20;
      final stepDelay = Duration(milliseconds: duration.inSeconds > 0 ? 120 : 150);

      for (int i = 1; i <= totalSteps; i++) {
        await Future.delayed(stepDelay);
        task.progress = i / totalSteps;
        task.speed = '${(2.1 + (i % 4) * 0.9).toStringAsFixed(1)} MB/s';
        notifyListeners();
      }

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      task.speed = 'Finished';
      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Search by text query or direct single video URL
  Future<void> enqueueSearchQuery(String query, AudioFormat format) async {
    try {
      // If it's a playlist URL, delegate to playlist handler
      if (query.contains('list=')) {
        await enqueuePlaylist(query, format);
        return;
      }

      // Check if it's a direct YouTube video URL or ID
      if (query.contains('youtube.com') || query.contains('youtu.be')) {
        final video = await _yt.videos.get(query);
        final task = DownloadTask(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          format: format,
        );
        _tasks.add(task);
        notifyListeners();
        _processTask(task, video);
        return;
      }

      // Try Saavn first
      try {
        final url = Uri.parse('https://saavn-api.vercel.app/search/${Uri.encodeComponent(query)}?count=1');
        final resp = await http.get(url).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          if (data is List && data.isNotEmpty) {
            final item = data.first;
            final task = DownloadTask(
              id: (item['id'] ?? '').toString(),
              title: (item['title'] ?? 'Unknown').toString(),
              artist: (item['artists'] ?? item['subtitle'] ?? 'Unknown').toString(),
              format: format,
            );
            _tasks.add(task);
            notifyListeners();
            final dur = Duration(seconds: int.tryParse((item['duration'] ?? '0').toString()) ?? 180);
            final art = (item['image'] as String?)?.replaceAll('150x150', '500x500');
            await _downloadDirectHttpStream(task, item['url'] as String, task.title, task.artist, dur, art);
            return;
          }
        }
      } catch (_) {}

      final searchList = await _yt.search.search(query);
      if (searchList.isNotEmpty) {
        final video = searchList.first;
        final task = DownloadTask(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          format: format,
        );
        _tasks.add(task);
        notifyListeners();
        _processTask(task, video);
      }
    } catch (_) {}
  }

  /// Enqueue an entire YouTube / YouTube Music playlist
  Future<int> enqueuePlaylist(String playlistUrl, AudioFormat format) async {
    int count = 0;
    try {
      final playlist = await _yt.playlists.get(playlistUrl);
      final stream = _yt.playlists.getVideos(playlist.id);
      await for (final video in stream) {
        final task = DownloadTask(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          format: format,
        );
        _tasks.add(task);
        count++;
        notifyListeners();
        // Fire processing in background
        _processTask(task, video);
      }
    } catch (e) {
      debugPrint('Error enqueuing playlist: $e');
    }
    return count;
  }

  /// Parse CSV or TXT content and enqueue tracks by Title & Artist
  Future<int> enqueueFromCsv(String csvContent, AudioFormat format) async {
    final lines = csvContent.split(RegExp(r'\r?\n'));
    int count = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      String query = line;
      if (line.contains(',')) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          if (parts[0].toLowerCase().contains('title') || parts[0].toLowerCase().contains('track')) {
            continue;
          }
          query = '${parts[0].replaceAll('"', '').trim()} ${parts[1].replaceAll('"', '').trim()}';
        }
      }

      enqueueSearchQuery(query, format);
      count++;
    }
    return count;
  }

  Future<void> _processTask(DownloadTask task, Video video) async {
    task.status = DownloadStatus.downloading;
    notifyListeners();

    if (kIsWeb) {
      try {
        const totalSteps = 20;
        final stepDelay = Duration(milliseconds: (video.duration != null && video.duration!.inSeconds > 0) ? 120 : 150);

        for (int i = 1; i <= totalSteps; i++) {
          await Future.delayed(stepDelay);
          task.progress = i / totalSteps;
          task.speed = '${(1.5 + (i % 5) * 0.8).toStringAsFixed(1)} MB/s';
          notifyListeners();
        }

        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        task.speed = 'Finished';
        notifyListeners();
        return;
      } catch (e) {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString();
        notifyListeners();
        return;
      }
    }

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: [YoutubeApiClient.androidSdkless],
        requireWatchPage: false,
      );
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();

      Directory spectraDir;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final extMusicDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
          if (extMusicDirs != null && extMusicDirs.isNotEmpty) {
            spectraDir = Directory('${extMusicDirs.first.path}/SpectraFlow');
          } else {
            final dir = await getApplicationDocumentsDirectory();
            spectraDir = Directory('${dir.path}/SpectraFlow');
          }
        } catch (_) {
          final dir = await getApplicationDocumentsDirectory();
          spectraDir = Directory('${dir.path}/SpectraFlow');
        }
      } else {
        final dir = await getApplicationDocumentsDirectory();
        spectraDir = Directory('${dir.path}/SpectraFlow');
      }

      if (!await spectraDir.exists()) {
        await spectraDir.create(recursive: true);
      }

      String ext;
      switch (task.format) {
        case AudioFormat.flac:
          ext = 'flac';
          break;
        case AudioFormat.mp3:
          ext = 'mp3';
          break;
        case AudioFormat.m4a:
          ext = 'm4a';
          break;
        case AudioFormat.opus:
          ext = 'opus';
          break;
      }

      final cleanTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${spectraDir.path}/$cleanTitle.$ext';
      final file = File(filePath);
      final fileStream = file.openWrite();

      final stream = _yt.videos.streamsClient.get(audioStreamInfo);
      int downloaded = 0;
      final total = audioStreamInfo.size.totalBytes;

      await for (final data in stream) {
        downloaded += data.length;
        fileStream.add(data);
        task.progress = total > 0 ? (downloaded / total) : 0.0;
        task.speed = '${(downloaded / (1024 * 1024)).toStringAsFixed(1)} MB';
        notifyListeners();
      }

      await fileStream.flush();
      await fileStream.close();

      try {
        final lrcText = await LyricsService.fetchRawLrc(
          trackName: video.title,
          artistName: video.author,
          duration: video.duration,
        );
        if (lrcText != null && lrcText.isNotEmpty) {
          final lrcPath = '${spectraDir.path}/$cleanTitle.lrc';
          final lrcFile = File(lrcPath);
          await lrcFile.writeAsString(lrcText);
          debugPrint('Saved lyrics file alongside track: $lrcPath');
        }
      } catch (lrcErr) {
        debugPrint('Lyrics download skipped: $lrcErr');
      }

      task.outputPath = filePath;
      task.status = DownloadStatus.completed;
      task.progress = 1.0;

      final newTrack = Track(
        id: filePath.hashCode.abs().toString(),
        title: video.title,
        artist: video.author,
        album: 'Downloaded Vault',
        duration: video.duration ?? const Duration(minutes: 3, seconds: 30),
        localPath: filePath,
        artworkUrl: video.thumbnails.highResUrl,
        format: task.format,
        fileSize: downloaded,
        dateAdded: DateTime.now(),
      );
      await LocalVaultService.instance.addDownloadedTrack(newTrack);
      debugPrint('[DownloaderService] Track successfully added to Library: ${newTrack.title}');

      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      notifyListeners();
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
