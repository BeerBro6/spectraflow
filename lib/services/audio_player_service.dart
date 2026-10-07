import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import '../models/track.dart';
import 'search_stream_service.dart';
import 'eq_bridge.dart' as eq_bridge;
import 'spectra_dac_service.dart';
import 'audio_dsp_service.dart';

class AudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer(
    userAgent: 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
    useProxyForRequestHeaders: false,
  );
  Track? _currentTrack;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<Track> _playlist = [];
  int _currentIndex = 0;
  bool _isShuffle = false;
  bool _isRepeat = false;

  // Track transition guards to prevent racing, interrupted loads, and infinite skip loops
  int _currentSessionId = 0;
  bool _isTransitioning = false;
  DateTime _lastTransitionTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _consecutiveErrors = 0;

  // When true, the currentIndexStream listener is silenced.
  // We set this during setAudioSources() because just_audio emits intermediate
  // index values (e.g. 0 or the old index) while initialising the new playlist,
  // which would otherwise overwrite _currentTrack back to the wrong song.
  bool _suppressIndexListener = false;

  AudioPlayerService() {
    _initAudioSession();

    // Automatically bind native hardware equalizer whenever audio session ID changes or initializes
    if (!kIsWeb) {
      _player.androidAudioSessionIdStream.listen((sessionId) {
        if (sessionId != null && sessionId > 0) {
          debugPrint('[AudioPlayerService] androidAudioSessionId changed: $sessionId');
          eq_bridge.eqInitWithSession(sessionId);
          AudioDspService.instance.rebindSession(sessionId);
          if (SpectraDacService.instance.isEnabled) {
            SpectraDacService.instance.resync();
          }
        }
      });
    }

    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (state.processingState == ProcessingState.completed) {
        _handlePlaybackCompleted();
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    // When the Android notification Prev/Next buttons are tapped,
    // just_audio_background calls seek(index) internally, which fires
    // currentIndexStream with the new index. We intercept that here and
    // call playTrack() to resolve a fresh, correct stream URL for the track.
    // Without this, just_audio would play the pre-built placeholder source
    // (the demo asset) for any track that didn't have a resolved URL loaded.
    //
    // _suppressIndexListener is set true during our own setAudioSources()
    // calls to block intermediate index events from interfering.
    _player.currentIndexStream.listen((index) {
      if (_suppressIndexListener) return;
      if (index == null) return;
      if (index == _currentIndex) return; // already in sync — we triggered this
      if (index < 0 || index >= _playlist.length) return;
      debugPrint('[AudioPlayerService] Notification jumped to index $index — resolving fresh stream');
      _currentIndex = index;
      playTrack(_playlist[index]); // resolves URL and updates UI correctly
    });
  }

  Future<void> _initAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Auto-pause when headphones are unplugged or Bluetooth disconnects
      session.becomingNoisyEventStream.listen((_) {
        debugPrint('[AudioPlayerService] Audio becoming noisy (headset unplugged) -> Auto-pausing');
        pause();
      });

      // Debounced handler for audio device changes (Bluetooth / Android Auto / wired).
      // Rapid changes during car projection connection can trigger multiple events
      // in milliseconds. Re-configuring the AudioSession repeatedly drops Android Auto
      // projection or crashes Gearhead. Debouncing ensures the audio route settles first.
      Timer? deviceChangeDebounce;
      session.devicesChangedEventStream.listen((event) {
        debugPrint('[AudioPlayerService] Audio devices changed (added=${event.devicesAdded.length}, removed=${event.devicesRemoved.length})');
        deviceChangeDebounce?.cancel();
        deviceChangeDebounce = Timer(const Duration(milliseconds: 1000), () async {
          // If a new device connected (e.g. car audio or Bluetooth headset)
          if (event.devicesAdded.isNotEmpty && _currentTrack != null) {
            try {
              // Only re-arm the session and resume if the player was interrupted
              // and halted, but the user's intent was to be playing.
              if (!_player.playing && _isPlaying) {
                debugPrint('[AudioPlayerService] Re-arming audio session after car/device connection...');
                await session.configure(const AudioSessionConfiguration.music());
                _player.play();
              }
            } catch (e) {
              debugPrint('[AudioPlayerService] Error restoring audio session on device change: $e');
            }
          }
        });
      });

      // Handle audio interruptions (incoming phone calls, transient notifications)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              // Optionally resume if desired, or stay paused
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('[AudioPlayerService] AudioSession init error: $e');
    }
  }

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isShuffle => _isShuffle;
  bool get isRepeat => _isRepeat;
  Duration get position => _position;
  Duration get duration => _duration;
  List<Track> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  int? get androidAudioSessionId => _player.androidAudioSessionId;

  void setPlaylist(List<Track> tracks, {int startIndex = 0}) {
    if (tracks.isEmpty) return;
    _consecutiveErrors = 0;
    _playlist = List<Track>.from(tracks);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    playTrack(_playlist[_currentIndex]);
  }

  /// Sets the playlist queue without interrupting or restarting the currently playing audio.
  void setPlaylistSilent(List<Track> tracks, {int startIndex = 0}) {
    if (tracks.isEmpty) return;
    _playlist = List<Track>.from(tracks);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    notifyListeners();
  }

  void _handlePlaybackCompleted() {
    // Guard: debounce accidental rapid completion events
    final now = DateTime.now();
    if (now.difference(_lastTransitionTime).inMilliseconds < 800) {
      debugPrint('[AudioPlayerService] Debouncing rapid completion event');
      return;
    }

    // If a transition is genuinely in progress, don't trigger another one
    if (_isTransitioning) {
      debugPrint('[AudioPlayerService] Ignoring completed event because player transition is already in progress');
      return;
    }

    // Guard: ensure track actually reached completion (allow a reasonable margin or zero duration)
    if (_duration > const Duration(seconds: 2)) {
      final remaining = _duration - _position;
      if (remaining > const Duration(seconds: 4)) {
        debugPrint('[AudioPlayerService] Ignoring premature completed event. Remaining: ${remaining.inSeconds}s');
        return;
      }
    }

    // Guard: don't auto-advance through consecutive failures
    if (_consecutiveErrors >= 3) {
      debugPrint('[AudioPlayerService] Halting auto-advance: consecutive error limit reached ($_consecutiveErrors).');
      seek(Duration.zero);
      pause();
      return;
    }

    _lastTransitionTime = now;

    if (_playlist.isEmpty) {
      debugPrint('[AudioPlayerService] Playlist is empty — stopping.');
      seek(Duration.zero);
      pause();
      return;
    }

    // 1. Respect repeat mode
    if (_isRepeat) {
      debugPrint('[AudioPlayerService] Replaying track [$_currentIndex] (repeat on): ${_currentTrack?.title}');
      seek(Duration.zero);
      _player.play();
      return;
    }

    // 2. Determine next track index
    int nextIdx;
    if (_isShuffle && _playlist.length > 1) {
      final random = math.Random();
      do {
        nextIdx = random.nextInt(_playlist.length);
      } while (nextIdx == _currentIndex);
    } else {
      nextIdx = _currentIndex + 1;
    }

    // 3. Safeguard: End of queue reached
    if (nextIdx >= _playlist.length || nextIdx == _currentIndex) {
      debugPrint('[AudioPlayerService] End of queue reached at index $_currentIndex — stopping.');
      seek(Duration.zero);
      pause();
      return;
    }

    // 4. Advance to next track
    final targetTrack = _playlist[nextIdx];
    debugPrint('[AudioPlayerService] Auto-advancing stream from [$_currentIndex] to [$nextIdx]: ${targetTrack.title}');
    _currentIndex = nextIdx;
    playTrack(targetTrack);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeat = !_isRepeat;
    notifyListeners();
  }

  void nextTrack({bool fromCompletion = false}) {
    if (_playlist.isEmpty) {
      if (_currentTrack != null) {
        seek(Duration.zero);
      }
      return;
    }

    // Prevent re-entrant rapid skips while an asynchronous load is pending
    if (_isTransitioning) {
      debugPrint('[AudioPlayerService] nextTrack ignored: transition already in progress');
      return;
    }

    final now = DateTime.now();
    if (!fromCompletion && now.difference(_lastTransitionTime).inMilliseconds < 400) {
      debugPrint('[AudioPlayerService] nextTrack debounced: user tapped too quickly');
      return;
    }
    _lastTransitionTime = now;

    if (_isShuffle && _playlist.length > 1) {
      int nextIdx;
      do {
        nextIdx = DateTime.now().millisecondsSinceEpoch % _playlist.length;
      } while (nextIdx == _currentIndex && _playlist.length > 1);
      _currentIndex = nextIdx;
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    final targetTrack = _playlist[_currentIndex];
    debugPrint('[AudioPlayerService] Advancing to [$_currentIndex]: ${targetTrack.title}');
    playTrack(targetTrack);
  }

  void previousTrack() {
    if (_position.inSeconds > 3) {
      seek(Duration.zero);
      return;
    }
    if (_playlist.isEmpty) {
      seek(Duration.zero);
      return;
    }
    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    playTrack(_playlist[_currentIndex]);
  }

  /// Builds an [AudioSource] for a track using its already-known URL or local path.
  /// This is used for playlist items that are NOT the currently-playing track — they get
  /// their CDN/local URL directly without an additional resolve call so that
  /// just_audio_background sees a full multi-item queue (enabling Prev/Next buttons).
  AudioSource _buildAudioSourceForTrack(Track t) {
    // Build artwork URI
    Uri? artUri;
    if (t.artworkUrl != null && t.artworkUrl!.isNotEmpty) {
      if (t.artworkUrl!.startsWith('http://') || t.artworkUrl!.startsWith('https://')) {
        artUri = Uri.tryParse(t.artworkUrl!);
      } else if (!kIsWeb) {
        artUri = Uri.file(t.artworkUrl!);
      }
    }
    final tag = MediaItem(
      id: t.id,
      album: t.album,
      title: t.title,
      artist: t.artist,
      artUri: artUri,
      duration: t.duration > Duration.zero ? t.duration : null,
    );

    // HTTP CDN tracks (Saavn, YouTube, etc.)
    if (t.localPath != null &&
        t.localPath!.isNotEmpty &&
        (t.localPath!.startsWith('http://') || t.localPath!.startsWith('https://'))) {
      return AudioSource.uri(
        Uri.parse(t.localPath!),
        tag: tag,
        headers: {
          // Must match the androidSdkless client UA that generated the stream token.
          // Chrome Mobile UA causes HTTP 403 Forbidden on Google Video CDN.
          'User-Agent':
              'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
        },
      );
    }
    // Native device file
    if (!kIsWeb && t.localPath != null && t.localPath!.isNotEmpty) {
      return AudioSource.file(t.localPath!, tag: tag);
    }
    // For tracks without a resolved stream URL yet, pass a silent source or valid remote placeholder
    // rather than non-existent local asset that crashes ExoPlayer instantly
    return AudioSource.uri(
      Uri.parse('https://audio-samples.github.io/samples/mp3/blip.mp3'),
      tag: tag,
    );
  }

  Future<void> playTrack(Track track, {String? streamUrl}) async {
    final sessionId = ++_currentSessionId;
    _isTransitioning = true;
    _currentTrack = track;
    _position = Duration.zero; // Immediately reset seeker and timer on UI
    _duration = track.duration;

    // Ensure playlist contains this track
    if (_playlist.isEmpty) {
      _playlist = [track];
      _currentIndex = 0;
    } else {
      if (_currentIndex >= 0 && _currentIndex < _playlist.length && _playlist[_currentIndex].id == track.id) {
        // Index is already accurate
      } else {
        final found = _playlist.indexWhere((t) => t.id == track.id);
        if (found != -1) {
          _currentIndex = found;
        } else {
          _playlist.add(track);
          _currentIndex = _playlist.length - 1;
        }
      }
    }
    _isLoading = true;
    // Suppress currentIndexStream for the ENTIRE async block (stop + setAudioSources).
    // _player.stop() causes just_audio to emit intermediate currentIndexStream
    // events (e.g. null → 0) which would trigger our listener and recursively
    // call playTrack() on the wrong track, hijacking the transition.
    // The sessionId mechanism handles any genuine racing new requests.
    _suppressIndexListener = true;
    _isTransitioning = false;
    notifyListeners();

    try {
      await _player.stop();

      // Check if a newer play request arrived while stopping
      if (sessionId != _currentSessionId) {
        debugPrint('[AudioPlayerService] Play request $sessionId superseded after stop');
        return;
      }

      // Safely resolve artUri for the current track
      Uri? artUri;
      if (track.artworkUrl != null && track.artworkUrl!.isNotEmpty) {
        if (track.artworkUrl!.startsWith('http://') || track.artworkUrl!.startsWith('https://')) {
          artUri = Uri.tryParse(track.artworkUrl!);
        } else if (!kIsWeb) {
          artUri = Uri.file(track.artworkUrl!);
        }
      }

      final mediaItem = MediaItem(
        id: track.id,
        album: track.album,
        title: track.title,
        artist: track.artist,
        artUri: artUri,
        duration: track.duration > Duration.zero ? track.duration : null,
      );

      // Eagerly resolve the URL only for the current track.
      // If the track is already a local disk file (not http), play it directly.
      // NEVER pass local music tracks to online stream resolution, which replaces
      // local audio with whatever random YouTube video happens to match the search query!
      String? resolvedUrl = streamUrl;
      final isLocalFile = !kIsWeb &&
          track.localPath != null &&
          track.localPath!.isNotEmpty &&
          !track.localPath!.startsWith('http://') &&
          !track.localPath!.startsWith('https://');

      if (!isLocalFile) {
        final isYouTubeTrack = track.sourceVideoId != null &&
            RegExp(r'^[0-9A-Za-z_-]{11}$').hasMatch(track.sourceVideoId!);

        if (isYouTubeTrack ||
            resolvedUrl == null ||
            resolvedUrl.isEmpty ||
            (track.localPath == null ||
                track.localPath!.isEmpty ||
                track.localPath!.startsWith('http'))) {
          // Always resolve fresh for YouTube tracks to avoid using expired CDN URLs.
          // Also resolve when no URL was passed and track has no local path.
          resolvedUrl = await SearchStreamService.instance
              .resolveAudioStreamUrl(track.sourceVideoId ?? track.id, track: track);
        }
      }

      if (sessionId != _currentSessionId) {
        debugPrint('[AudioPlayerService] Play request $sessionId superseded after stream resolution');
        return;
      }

      // Build the AudioSource for the current track using the freshly-resolved URL
      AudioSource currentSource;
      final effectiveUrl = (resolvedUrl != null && resolvedUrl.isNotEmpty)
          ? resolvedUrl
          : ((track.localPath != null &&
                  (track.localPath!.startsWith('http://') || track.localPath!.startsWith('https://')))
              ? track.localPath!
              : null);

      if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
        _currentTrack = track.copyWith(localPath: effectiveUrl);
        currentSource = AudioSource.uri(
          Uri.parse(effectiveUrl),
          tag: mediaItem,
          headers: {
            // Must match the androidSdkless client UA that generated the stream token.
            // Chrome Mobile UA causes HTTP 403 Forbidden on Google Video CDN.
            'User-Agent':
                'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
          },
        );
      } else if (!kIsWeb &&
          track.localPath != null &&
          track.localPath!.isNotEmpty &&
          !track.localPath!.startsWith('http')) {
        currentSource = AudioSource.file(track.localPath!, tag: mediaItem);
      } else {
        throw Exception('No playable audio stream available for "${track.title}"');
      }

      // -----------------------------------------------------------------------
      // Build the FULL playlist sources list so just_audio_background's
      // internal queue has multiple items → hasNext / hasPrevious = true →
      // Prev and Next buttons appear in the Android notification & lock screen.
      // -----------------------------------------------------------------------
      final List<AudioSource> allSources = List.generate(_playlist.length, (i) {
        if (i == _currentIndex) return currentSource; // use freshly-resolved source
        return _buildAudioSourceForTrack(_playlist[i]);
      });

      await _player.setAudioSources(allSources, initialIndex: _currentIndex);

      if (sessionId != _currentSessionId) {
        debugPrint('[AudioPlayerService] Play request $sessionId superseded after setting audio source');
        return;
      }

      // Transition is complete as soon as source is set and ready
      _isTransitioning = false;
      _isLoading = false;
      notifyListeners();

      // Start playback
      _player.play();
      _consecutiveErrors = 0;

      if (!kIsWeb && _player.androidAudioSessionId != null) {
        eq_bridge.eqInitWithSession(_player.androidAudioSessionId);
        AudioDspService.instance.rebindSession(_player.androidAudioSessionId);
        if (SpectraDacService.instance.isEnabled) {
          SpectraDacService.instance.resync();
        }
      }

      // --- AUDIOPHILE LOOKAHEAD ENGINE: Pre-cache Track N+1 in background ---
      if (_playlist.length > 1) {
        final nextIndex = (_currentIndex + 1) % _playlist.length;
        final nextTrackToPreload = _playlist[nextIndex];
        Future.delayed(const Duration(milliseconds: 600), () {
          SearchStreamService.instance.preloadNextTrack(nextTrackToPreload);
        });
      }
    } catch (e) {
      debugPrint('Error playing track ${track.title}: $e');
      final errStr = e.toString().toLowerCase();

      final isAborted = sessionId != _currentSessionId ||
          errStr.contains('loading interrupted') ||
          errStr.contains('abort') ||
          errStr.contains('interrupted');

      if (isAborted) {
        debugPrint('[AudioPlayerService] Load cancelled/interrupted for "${track.title}" - suppressing auto-advance');
      } else {
        _consecutiveErrors++;
        // Only auto-advance for local library tracks (localPath is a file path, not http).
        // For online search result streams, NEVER auto-advance — it would play a completely
        // unrelated song from the search results instead of showing an error to the user.
        final isOnlineStream = track.localPath == null ||
            track.localPath!.startsWith('http://') ||
            track.localPath!.startsWith('https://') ||
            track.sourceVideoId != null;

        if (!isOnlineStream && _consecutiveErrors < 3 && _playlist.length > 1) {
          debugPrint('[AudioPlayerService] Advancing to next track due to genuine playback error (count=$_consecutiveErrors)...');
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (sessionId == _currentSessionId) {
              nextTrack();
            }
          });
        } else {
          debugPrint('[AudioPlayerService] Halting auto-skip for online stream or consecutive error cap reached (count=$_consecutiveErrors).');
        }
      }
    } finally {
      _suppressIndexListener = false; // always re-enable notification listener
      if (sessionId == _currentSessionId) {
        _isTransitioning = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }



  Future<void> play() async {
    if (_player.audioSource == null && _currentTrack != null) {
      await playTrack(_currentTrack!);
    } else {
      await _player.play();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      if (_currentTrack == null && _playlist.isNotEmpty) {
        await playTrack(_playlist[_currentIndex.clamp(0, _playlist.length - 1)]);
      } else {
        await play();
      }
    }
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _playlist.length) return;
    if (newIndex < 0 || newIndex > _playlist.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final currentPlayingTrack = _currentTrack;
    final item = _playlist.removeAt(oldIndex);
    _playlist.insert(newIndex, item);
    if (currentPlayingTrack != null) {
      _currentIndex = _playlist.indexWhere((t) => t.id == currentPlayingTrack.id);
    }
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _playlist.length) return;
    final removingCurrent = index == _currentIndex;
    _playlist.removeAt(index);
    if (removingCurrent && _playlist.isNotEmpty) {
      _currentIndex = _currentIndex % _playlist.length;
      playTrack(_playlist[_currentIndex]);
    } else if (index < _currentIndex) {
      _currentIndex -= 1;
    }
    notifyListeners();
  }

  void clearQueue() {
    final currentPlayingTrack = _currentTrack;
    if (currentPlayingTrack != null) {
      _playlist = [currentPlayingTrack];
      _currentIndex = 0;
    } else {
      _playlist.clear();
      _currentIndex = 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
