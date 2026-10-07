import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Lightweight async semaphore used to cap the number of concurrent upstream
/// Range requests. Without this, when the car BT link flaps, ExoPlayer issues
/// a burst of overlapping chunk requests and each one spawns a fresh
/// HttpClient + upstream socket — heap pressure spikes and LMK kills
/// Android Auto's `gearhead:car` process, dropping the car stereo
/// projection. Keeping the in-flight count bounded keeps memory flat.
class _RequestGate {
  _RequestGate(this._max);
  final int _max;
  int _active = 0;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() body) async {
    if (_active >= _max) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _active++;
    try {
      return await body();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }
}

class CachedStreamInfo {
  final Uri url;
  final int totalSize;
  final String mimeType;
  final DateTime fetchedAt;

  const CachedStreamInfo({
    required this.url,
    required this.totalSize,
    required this.mimeType,
    required this.fetchedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) >= LocalAudioProxyService.cacheTtl;
}

/// In-app loopback HTTP proxy that serves online audio streams to ExoPlayer on Android.
///
/// Uses the VisionOS player client with a dynamically minted visitorData token.
/// This bypasses Google Video CDN's strict 1 MiB BotGuard / PO Token rate cap,
/// enabling continuous full-track playback without premature 403 Forbidden cuts.
class LocalAudioProxyService {
  static final LocalAudioProxyService instance = LocalAudioProxyService._internal();
  factory LocalAudioProxyService() => instance;
  LocalAudioProxyService._internal();

  static const Duration cacheTtl = Duration(minutes: 10);
  static const int chunkSize = 512 * 1024; // 512 KB
  static const String browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  HttpServer? _server;
  final HttpClient _httpClient = HttpClient()..idleTimeout = const Duration(seconds: 15);
  final YoutubeExplode _yt = YoutubeExplode();
  final _RequestGate _gate = _RequestGate(6);

  final Map<String, CachedStreamInfo> _manifestCache = {};
  final Map<String, Future<bool>> _prefetchInFlight = {};
  String? _cachedVisitorData;
  DateTime? _visitorDataFetchedAt;

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// Starts the loopback HTTP server.
  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint('[LocalAudioProxy] Started on http://127.0.0.1:${_server!.port}');
      _server!.listen(
        _handleRequest,
        onError: (e) => debugPrint('[LocalAudioProxy] Server error: $e'),
      );
    } catch (e) {
      debugPrint('[LocalAudioProxy] Failed to bind local server: $e');
    }
  }

  /// Stops the loopback server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Returns the local proxy URL for a YouTube video ID.
  Future<String?> getProxyUrl(String videoId) async {
    if (_server == null) {
      await start();
    }
    if (_server == null) return null;
    return 'http://127.0.0.1:${_server!.port}/$videoId';
  }

  /// Pre-fetches and caches the audio stream manifest for [videoId].
  Future<bool> prefetchVideo(String videoId) async {
    final cached = _manifestCache[videoId];
    if (cached != null && !cached.isExpired) {
      return true;
    }

    if (_prefetchInFlight.containsKey(videoId)) {
      return await _prefetchInFlight[videoId]!;
    }

    final future = _fetchManifest(videoId);
    _prefetchInFlight[videoId] = future;
    try {
      return await future;
    } finally {
      _prefetchInFlight.remove(videoId);
    }
  }

  /// Retrieves a fresh visitorData token from YouTube ServiceWorker bootstrap.
  Future<String?> _getVisitorData() async {
    if (_cachedVisitorData != null &&
        _visitorDataFetchedAt != null &&
        DateTime.now().difference(_visitorDataFetchedAt!) < const Duration(hours: 1)) {
      return _cachedVisitorData;
    }

    try {
      final req = await _httpClient
          .getUrl(Uri.parse('https://www.youtube.com/sw.js_data'))
          .timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        final body = await utf8.decodeStream(resp);
        final cleanJson = body.replaceFirst(RegExp(r"^\)\]\}'\s*"), '');
        final dynamic parsed = jsonDecode(cleanJson);
        final visitor = parsed[0][2][0][0][13] as String?;
        if (visitor != null && visitor.isNotEmpty) {
          _cachedVisitorData = visitor;
          _visitorDataFetchedAt = DateTime.now();
          return visitor;
        }
      }
    } catch (e) {
      debugPrint('[LocalAudioProxy] Failed to fetch visitorData: $e');
    }
    return _cachedVisitorData;
  }

  Future<bool> _fetchManifest(String videoId) async {
    // 1. Try VisionOS player client with visitorData (unrestricted playback past 1MB)
    try {
      final visitor = await _getVisitorData();
      final playerReq = await _httpClient
          .postUrl(Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'))
          .timeout(const Duration(seconds: 8));
      playerReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      playerReq.headers.set('X-Youtube-Client-Name', '101');
      playerReq.headers.set('X-Youtube-Client-Version', '1.02');
      playerReq.headers.set('Origin', 'https://www.youtube.com');
      playerReq.headers.set(HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15');
      if (visitor != null) {
        playerReq.headers.set('X-Goog-Visitor-Id', visitor);
      }

      final clientContext = <String, dynamic>{
        'clientName': 'VISIONOS',
        'clientVersion': '1.02',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'userAgent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
        'osName': 'visionOS',
        'osVersion': '26.5.23O471',
        'hl': 'en',
      };
      if (visitor != null) {
        clientContext['visitorData'] = visitor;
      }

      final payload = {
        'context': {'client': clientContext},
        'videoId': videoId,
      };

      playerReq.write(jsonEncode(payload));
      final playerResp = await playerReq.close();
      if (playerResp.statusCode == HttpStatus.ok) {
        final playerBody = await utf8.decodeStream(playerResp);
        final playerData = jsonDecode(playerBody) as Map<String, dynamic>;
        final playability = playerData['playabilityStatus']?['status'];

        if (playability == 'OK') {
          final formats =
              (playerData['streamingData']?['adaptiveFormats'] as List<dynamic>?) ?? [];
          final audioFormats = formats
              .where((f) => (f['mimeType'] as String? ?? '').contains('audio'))
              .toList();

          if (audioFormats.isNotEmpty) {
            audioFormats.sort((a, b) =>
                ((b['bitrate'] as int?) ?? 0).compareTo((a['bitrate'] as int?) ?? 0));
            final best = audioFormats.first;
            final streamUrl = Uri.parse(best['url'] as String);
            final totalSize = int.tryParse(best['contentLength']?.toString() ?? '') ?? 0;
            final rawMime = best['mimeType'] as String? ?? 'audio/webm';
            final cleanMime = rawMime.split(';').first.trim();

            _manifestCache[videoId] = CachedStreamInfo(
              url: streamUrl,
              totalSize: totalSize,
              mimeType: cleanMime,
              fetchedAt: DateTime.now(),
            );
            debugPrint(
              '[LocalAudioProxy] Cached VisionOS stream for $videoId ($totalSize bytes, $cleanMime)',
            );
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalAudioProxy] VisionOS resolution failed for $videoId: $e');
    }

    // 2. Fallback to youtube_explode_dart androidSdkless
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidSdkless],
        requireWatchPage: false,
      );
      final audio = manifest.audioOnly.withHighestBitrate();
      final totalSize = audio.size.totalBytes;
      final mimeType = audio.codec.mimeType;

      _manifestCache[videoId] = CachedStreamInfo(
        url: audio.url,
        totalSize: totalSize,
        mimeType: mimeType,
        fetchedAt: DateTime.now(),
      );
      debugPrint(
        '[LocalAudioProxy] Cached androidSdkless manifest fallback for $videoId ($totalSize bytes, $mimeType)',
      );
      return true;
    } catch (e) {
      debugPrint('[LocalAudioProxy] Fallback manifest failed for $videoId: $e');
      return false;
    }
  }

  /// Handles incoming HTTP GET requests from ExoPlayer.
  ///
  /// Seeking robustness fixes (vs. previous version):
  /// * `response.bufferOutput = false` so `add()` writes directly to the socket.
  ///   When ExoPlayer seeks, the closed socket surfaces as an immediate
  ///   SocketException on the next `add()` instead of stalling on `flush()`.
  /// * Fresh `HttpClient` per request — no shared idle timer / keep-alive
  ///   socket can be poisoned by a previously-disconnected request.
  /// * No `await response.flush()` mid-stream — `close()` flushes once at the end.
  /// * Track `currentByte` by what we ACTUALLY sent, not by what we asked for.
  /// * On upstream non-2xx (esp. 403 from token expiration), re-resolve the
  ///   manifest once and retry, rather than breaking the loop silently and
  ///   leaving ExoPlayer to treat the early EOF as a truncated asset.
  /// * On unrecoverable upstream failure, return `502 Bad Gateway` so ExoPlayer
  ///   sees a clean HTTP error instead of a partial body that stops playback.
  void _handleRequest(HttpRequest request) async {
    HttpClient? upstreamClient;
    try {
      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }

      final path = request.uri.path.trim();
      final videoId = path.startsWith('/') ? path.substring(1) : path;

      if (videoId.isEmpty) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      CachedStreamInfo? maybeCached = _manifestCache[videoId];
      if (maybeCached == null || maybeCached.isExpired) {
        final ok = await prefetchVideo(videoId);
        if (ok) {
          maybeCached = _manifestCache[videoId];
        }
      }

      if (maybeCached == null) {
        debugPrint('[LocalAudioProxy] 404 - Could not resolve video $videoId');
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      // Non-null after the guard above; locally promoted so the seek-retry
      // branch can reassign without losing the type promotion.
      CachedStreamInfo cached = maybeCached;

      final totalSize = cached.totalSize;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      int rangeStart = 0;
      int rangeEnd = totalSize - 1;
      bool isPartial = false;

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        // ExoPlayer sends single-range requests. If anything ever sends a
        // multipart range, take the first range only — we don't support
        // multipart/byteranges.
        final rangeValue =
            rangeHeader.substring(6).trim().split(',').first.trim();
        final parts = rangeValue.split('-');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          rangeStart = int.tryParse(parts[0]) ?? 0;
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          rangeEnd = int.tryParse(parts[1]) ?? (totalSize - 1);
        }
        if (rangeStart < 0) rangeStart = 0;
        if (rangeStart >= totalSize) rangeStart = totalSize - 1;
        if (rangeEnd >= totalSize) rangeEnd = totalSize - 1;
        if (rangeEnd < rangeStart) rangeEnd = rangeStart;
        isPartial = true;
      }

      final contentLength = rangeEnd - rangeStart + 1;
      final response = request.response;
      // Disable Dart's internal write buffer so a closed client surfaces as
      // an immediate SocketException on `add()` instead of stalling flush().
      response.bufferOutput = false;
      response.statusCode =
          isPartial ? HttpStatus.partialContent : HttpStatus.ok;
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(HttpHeaders.contentTypeHeader, cached.mimeType);
      response.headers.set(
          HttpHeaders.contentLengthHeader, contentLength.toString());

      if (isPartial) {
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $rangeStart-$rangeEnd/$totalSize',
        );
      }

      if (request.method == 'HEAD') {
        await response.close();
        return;
      }

      // Fresh HttpClient per request — a stuck/rate-limited prior connection
      // can't poison this request's socket pool, idle timer, or keep-alive.
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 30);
      // Track it for the outer finally {} cleanup; the lambda below uses
      // the non-nullable local `client`.
      upstreamClient = client;

      int currentByte = rangeStart;
      int totalBytesSent = 0;
      bool manifestRetried = false;

      // Cap concurrent in-flight upstream requests so a BT/Wi-Fi Direct
      // reconnect storm from the car head unit can't drive heap usage up
      // far enough to trigger LMK on Android Auto's gearhead process.
      await _gate.run(() async {
        while (currentByte <= rangeEnd) {
        final chunkEnd =
            (currentByte + chunkSize - 1).clamp(currentByte, rangeEnd);

        final HttpClientRequest upstreamReq;
        try {
          upstreamReq = await client.getUrl(cached.url).timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw TimeoutException(
                    'Upstream open timeout for $videoId at $currentByte'),
              );
        } catch (e) {
          debugPrint(
              '[LocalAudioProxy] Upstream open failed at $currentByte: $e');
          try {
            response.statusCode = HttpStatus.badGateway;
            await response.close();
          } catch (_) {}
          return;
        }
        upstreamReq.headers.set(HttpHeaders.userAgentHeader, browserUserAgent);
        upstreamReq.headers.set(
            HttpHeaders.rangeHeader, 'bytes=$currentByte-$chunkEnd');

        final HttpClientResponse upstreamResp;
        try {
          upstreamResp = await upstreamReq.close();
        } catch (e) {
          debugPrint(
              '[LocalAudioProxy] Upstream close failed for $videoId: $e');
          try {
            response.statusCode = HttpStatus.badGateway;
            await response.close();
          } catch (_) {}
          return;
        }

        // 403 = the manifest URL's stream token has expired. Re-resolve once
        // and retry the same range with the fresh URL instead of silently
        // truncating ExoPlayer's response.
        if (upstreamResp.statusCode == HttpStatus.forbidden &&
            !manifestRetried) {
          manifestRetried = true;
          debugPrint(
              '[LocalAudioProxy] Upstream 403; re-resolving manifest for $videoId');
          try {
            await upstreamResp.drain<void>();
          } catch (_) {}
          final reok = await _fetchManifest(videoId);
          if (reok) {
            final fresh = _manifestCache[videoId];
            if (fresh != null) {
              cached = fresh;
              // DON'T advance currentByte — retry the same range with the new URL
              continue;
            }
          }
        }

        if (upstreamResp.statusCode != HttpStatus.partialContent &&
            upstreamResp.statusCode != HttpStatus.ok) {
          debugPrint(
            '[LocalAudioProxy] Upstream error ${upstreamResp.statusCode} for '
            '$videoId at $currentByte-$chunkEnd (totalSize=$totalSize)',
          );
          try {
            response.statusCode = HttpStatus.badGateway;
            await response.close();
          } catch (_) {}
          return;
        }

        int chunkBytesSent = 0;
        try {
          await for (final chunk in upstreamResp) {
            // add() writes straight to the socket (bufferOutput = false).
            // Throws SocketException immediately if ExoPlayer has disconnected.
            response.add(chunk);
            chunkBytesSent += chunk.length;
            totalBytesSent += chunk.length;
            // Defensive: never write past our advertised Content-Length.
            if (totalBytesSent >= contentLength) break;
          }
        } catch (e) {
          // ExoPlayer closed the socket — seek / pause / cancel. Normal.
          debugPrint(
              '[LocalAudioProxy] Client disconnected at $currentByte: $e');
          return;
        }

        if (chunkBytesSent == 0) {
          debugPrint(
              '[LocalAudioProxy] Upstream returned 0 bytes at $currentByte');
          try {
            await response.close();
          } catch (_) {}
          return;
        }

        // Advance by what we actually sent, not what we asked for.
        currentByte += chunkBytesSent;
      }
      }); // end _gate.run

      // All bytes written — close cleanly. close() flushes the socket; we
      // never call flush() mid-stream to avoid blocking on a slow client.
      await response.close();
    } catch (e, st) {
      debugPrint('[LocalAudioProxy] Unexpected handler error: $e\n$st');
      try {
        await request.response.close();
      } catch (_) {}
    } finally {
      try {
        upstreamClient?.close(force: true);
      } catch (_) {}
    }
  }

  void dispose() {
    stop();
    _yt.close();
    _httpClient.close(force: true);
  }
}
