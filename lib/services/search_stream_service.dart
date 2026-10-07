import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';
import 'local_audio_proxy_service.dart';

/// Service for searching online music tracks and resolving high-fidelity audio stream URLs.
///
/// On Android, YouTube streams are routed through the [LocalAudioProxyService] loopback proxy
/// to avoid Google Video CDN 403 Forbidden errors.
class SearchStreamService {
  static final SearchStreamService instance = SearchStreamService._internal();
  factory SearchStreamService() => instance;
  SearchStreamService._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  static const Duration _cacheTtl = Duration(minutes: 3);
  final Map<String, ({String url, DateTime timestamp})> _resolvedCache = {};

  static final RegExp _ytIdRegex = RegExp(r'^[0-9A-Za-z_-]{11}$');

  bool _isYtId(String str) => _ytIdRegex.hasMatch(str.trim());

  /// Searches tracks on YouTube.
  ///
  /// For short or special-character queries (e.g. 'a&t'), falls back to '$query audio'.
  /// Immediately pre-warms the manifest cache in [LocalAudioProxyService] for returned tracks.
  Future<List<Track>> searchTracks(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      var searchResults = await _executeYtSearch(cleanQuery);
      if (searchResults.isEmpty) {
        searchResults = await _executeYtSearch('$cleanQuery audio');
      }

      final List<Track> tracks = [];
      for (final video in searchResults.take(15)) {
        final videoId = video.id.value;
        tracks.add(
          Track(
            id: videoId,
            sourceVideoId: videoId,
            title: video.title,
            artist: video.author,
            album: 'YouTube Stream',
            duration: video.duration ?? Duration.zero,
            artworkUrl: video.thumbnails.highResUrl,
          ),
        );

        // Pre-warm proxy manifest cache in background so tapping play is instant
        unawaited(LocalAudioProxyService.instance.prefetchVideo(videoId));
      }
      return tracks;
    } catch (e) {
      debugPrint('[SearchStreamService] Search error for "$cleanQuery": $e');
      return [];
    }
  }

  Future<List<Video>> _executeYtSearch(String query) async {
    try {
      final res = await _yt.search.search(query).timeout(const Duration(seconds: 12));
      return res.toList();
    } catch (_) {
      try {
        final fallback = await _yt.search.search('$query song').timeout(const Duration(seconds: 12));
        return fallback.toList();
      } catch (_) {
        return <Video>[];
      }
    }
  }

  /// Resolves an audio stream URL for playback.
  ///
  /// For YouTube tracks (11-character video ID or [track.sourceVideoId]), this returns
  /// a local proxy URL `http://127.0.0.1:<port>/<videoId>`.
  Future<String?> resolveAudioStreamUrl(String trackIdOrUrl, {Track? track}) async {
    final cacheKey = track?.sourceVideoId ?? track?.id ?? trackIdOrUrl;
    final cached = _resolvedCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached.url;
    }

    // 1. Check if track has a known YouTube video ID
    String? ytVideoId;
    if (track?.sourceVideoId != null && _isYtId(track!.sourceVideoId!)) {
      ytVideoId = track.sourceVideoId;
    } else if (_isYtId(trackIdOrUrl)) {
      ytVideoId = trackIdOrUrl;
    } else if (track != null && _isYtId(track.id)) {
      ytVideoId = track.id;
    }

    if (ytVideoId != null) {
      debugPrint('[SearchStreamService] Resolving YouTube video $ytVideoId via proxy...');
      final prefetchSuccess =
          await LocalAudioProxyService.instance.prefetchVideo(ytVideoId);
      if (prefetchSuccess) {
        final proxyUrl =
            await LocalAudioProxyService.instance.getProxyUrl(ytVideoId);
        if (proxyUrl != null) {
          _resolvedCache[cacheKey] = (url: proxyUrl, timestamp: DateTime.now());
          debugPrint('[SearchStreamService] Resolved proxy URL: $proxyUrl');
          return proxyUrl;
        }
      }
      debugPrint('[SearchStreamService] Failed to resolve stream for YouTube ID $ytVideoId');
      return null;
    }

    // 2. If track already has an HTTP stream URL that is not an expired/placeholder preview
    if (track?.localPath != null &&
        (track!.localPath!.startsWith('http://') ||
            track.localPath!.startsWith('https://')) &&
        !track.localPath!.contains('AudioPreview')) {
      return track.localPath;
    }

    // 3. Fallback: Search YouTube for title + artist
    final query = '${track?.artist ?? ''} ${track?.title ?? trackIdOrUrl}'.trim();
    if (query.isNotEmpty) {
      try {
        final searchResults = await _executeYtSearch(query);
        if (searchResults.isNotEmpty) {
          final matchedVideo = searchResults.first;
          final vidId = matchedVideo.id.value;
          final ok = await LocalAudioProxyService.instance.prefetchVideo(vidId);
          if (ok) {
            final proxyUrl =
                await LocalAudioProxyService.instance.getProxyUrl(vidId);
            if (proxyUrl != null) {
              _resolvedCache[cacheKey] = (url: proxyUrl, timestamp: DateTime.now());
              return proxyUrl;
            }
          }
        }
      } catch (e) {
        debugPrint('[SearchStreamService] Fallback search error: $e');
      }
    }

    return null;
  }

  /// Resolves the underlying YouTube video ID or direct stream URL for a track to download.
  Future<({String? videoId, String? streamUrl})> resolveTrackAudio(Track track) async {
    // 1. Check known YouTube video ID
    if (track.sourceVideoId != null && _isYtId(track.sourceVideoId!)) {
      return (videoId: track.sourceVideoId, streamUrl: null);
    }
    if (_isYtId(track.id)) {
      return (videoId: track.id, streamUrl: null);
    }

    // 2. Direct HTTP stream
    if (track.localPath != null &&
        (track.localPath!.startsWith('http://') || track.localPath!.startsWith('https://')) &&
        !track.localPath!.contains('AudioPreview')) {
      return (videoId: null, streamUrl: track.localPath);
    }

    // 3. Search YouTube for matching title + artist
    final query = '${track.artist} ${track.title}'.trim();
    if (query.isNotEmpty) {
      try {
        final results = await _executeYtSearch(query);
        if (results.isNotEmpty) {
          return (videoId: results.first.id.value, streamUrl: null);
        }
      } catch (e) {
        debugPrint('[SearchStreamService] resolveTrackAudio search error: $e');
      }
    }

    return (videoId: null, streamUrl: null);
  }

  /// Audiophile lookahead engine: Pre-warms the cache for the next track in queue.
  void preloadNextTrack(Track track) {
    final ytVideoId = track.sourceVideoId ??
        (_isYtId(track.id) ? track.id : null);
    if (ytVideoId != null) {
      unawaited(LocalAudioProxyService.instance.prefetchVideo(ytVideoId));
    }
  }

  void dispose() {
    _yt.close();
  }
}
