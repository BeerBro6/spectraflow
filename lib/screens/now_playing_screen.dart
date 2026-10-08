import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/local_vault_service.dart';
import '../services/lyrics_service.dart';
import '../services/playlist_service.dart';
import '../theme/theme.dart';
import '../widgets/track_artwork.dart';
import 'library_screen.dart' show LibraryViewMode;
import 'eq_test_screen.dart' show EqService, EqPresetType;
import 'eq_screen.dart' show EqScreen;
import '../widgets/liquid_glass.dart';

class NowPlayingScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final List<Track>? tracks;
  final VoidCallback? onBack;
  final bool showAudioSpecPill;
  final VoidCallback? onToggleAudioSpecPill;
  final bool showQueueDrawer;
  final VoidCallback? onToggleQueueDrawer;
  final LibraryViewMode viewMode;

  const NowPlayingScreen({
    super.key,
    required this.playerService,
    this.tracks,
    this.onBack,
    this.showAudioSpecPill = true,
    this.onToggleAudioSpecPill,
    this.showQueueDrawer = true,
    this.onToggleQueueDrawer,
    this.viewMode = LibraryViewMode.audiophileHybrid,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final PageController _pageController = PageController();
  final ScrollController _lyricsScrollController = ScrollController();
  List<LyricsLine> _lyrics = [];
  bool _isLoadingLyrics = false;
  int _activePageIndex = 0;
  String? _loadedTrackId;
  int _lastActiveLyricIdx = -1;

  // Dynamic Ambient Palette State & Cache
  static final Map<String, List<Color>> _paletteCache = {};
  List<Color>? _extractedPaletteColors;
  String? _lastExtractedArtworkUrl;

  static const List<Track> _defaultFallbackTracks = [
    Track(
      id: 'KCUhbjZxYlg',
      title: 'Sharp Shooter',
      artist: 'Masoom Sharma',
      album: 'Haryanvi Hits',
      duration: Duration(minutes: 3, seconds: 48),
      artworkUrl: 'https://c.saavncdn.com/236/Sharp-Shooter-Punjabi-2019-20190711174037-500x500.jpg',
      localPath: 'https://aac.saavncdn.com/236/57d1f2c1b2c7b98d84c5601a961800af_320.mp4',
    ),
    Track(
      id: 'CSw6cgJKBnY',
      title: 'Russian Bandana',
      artist: 'Dhanda Nyoliwala',
      album: 'Single',
      duration: Duration(minutes: 3, seconds: 26),
      artworkUrl: 'https://c.saavncdn.com/414/Russian-Bandana-Lo-Fi-Hindi-2024-20241016121647-500x500.jpg',
      localPath: 'https://aac.saavncdn.com/414/b86026bc4679346af3a69af0444d28e5_320.mp4',
    ),
    Track(
      id: 'OFoZCCReQXI',
      title: '295',
      artist: 'Sidhu Moose Wala',
      album: 'Moosetape',
      duration: Duration(minutes: 4, seconds: 30),
      artworkUrl: 'https://c.saavncdn.com/609/Moosetape-Punjabi-2021-20260626155141-500x500.jpg',
      localPath: 'https://aac.saavncdn.com/609/852628435c98083dfe217c1cfa731bb5_320.mp4',
    ),
    Track(
      id: 'HiZeHENWfFY',
      title: 'Gumaan',
      artist: 'Talha Anjum, Umair',
      album: 'Open Letter',
      duration: Duration(minutes: 5, seconds: 26),
      artworkUrl: 'https://c.saavncdn.com/314/Gumaan-Bhojpuri-2022-20220415113137-500x500.jpg',
      localPath: 'https://aac.saavncdn.com/314/342890291d101c9fc46f69a41a0dbb06_320.mp4',
    ),
    Track(
      id: 'GTsiUyN3UFc',
      title: 'Fouji Fojan',
      artist: 'Aamin Barodi',
      album: 'Haryanvi Single',
      duration: Duration(minutes: 3, seconds: 58),
      artworkUrl: 'https://c.saavncdn.com/290/Fouji-Fojan-Hindi-2025-20250917203321-500x500.jpg',
      localPath: 'https://aac.saavncdn.com/290/20efb33568acf109f0ed25551e9429a4_320.mp4',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ensurePlaylistInitialized();
    _loadLyrics();
  }

  void _ensurePlaylistInitialized() {
    // If a track is already playing or playlist already set, DO NOT reset to first track!
    if (widget.playerService.playlist.isNotEmpty) {
      return;
    }
    final vaultTracks = LocalVaultService.instance.tracks;
    final list = widget.tracks ?? (vaultTracks.isNotEmpty ? vaultTracks : _defaultFallbackTracks);
    final current = widget.playerService.currentTrack;
    if (current != null) {
      final startIdx = list.indexWhere((t) => t.id == current.id);
      if (startIdx != -1) {
        widget.playerService.setPlaylistSilent(list, startIndex: startIdx);
      } else {
        // Track was played externally (e.g. from SearchScreen streaming).
        // Prepend it to the playlist so queue controls work, without restarting audio playback!
        widget.playerService.setPlaylistSilent([current, ...list], startIndex: 0);
      }
    } else {
      // If no track is loaded yet, set the playlist silently so nextTrack() and controls know the queue!
      widget.playerService.setPlaylistSilent(list, startIndex: 0);
    }
  }

  void _loadLyrics() async {
    final track = widget.playerService.currentTrack ??
        (widget.playerService.playlist.isNotEmpty ? widget.playerService.playlist.first : null);
    if (track != null) {
      _loadedTrackId = track.id;
      setState(() {
        _isLoadingLyrics = true;
        _lyrics = [];
      });

      // 1. First check if a local companion .lrc file is stored alongside the audio file
      final localLrc = await LyricsService.loadLocalLrc(track.localPath);
      if (localLrc != null && localLrc.isNotEmpty) {
        if (mounted) {
          setState(() {
            _lyrics = localLrc;
            _isLoadingLyrics = false;
            _lastActiveLyricIdx = -1;
          });
        }
        return;
      }

      // 2. Otherwise fetch from online synchronized lyrics provider
      final lines = await LyricsService.fetchLyrics(
        trackName: track.title,
        artistName: track.artist,
        duration: track.duration,
      );
      if (mounted) {
        setState(() {
          _lyrics = lines;
          _isLoadingLyrics = false;
          _lastActiveLyricIdx = -1;
        });
      }
    }
  }

  void _checkAndRefreshLyrics(Track track) {
    if (_loadedTrackId != track.id) {
      _loadedTrackId = track.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLyrics();
      });
    }
  }

  void _scrollToActiveLyric(int idx) {
    if (idx != _lastActiveLyricIdx && _lyricsScrollController.hasClients) {
      _lastActiveLyricIdx = idx;
      final target = (idx * 55.0 - 120.0).clamp(0.0, _lyricsScrollController.position.maxScrollExtent);
      _lyricsScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleBack(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      if (_activePageIndex != 0) {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _showQueueBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: widget.playerService,
          builder: (context, _) {
            final playlist = widget.playerService.playlist;
            final currentTrack = widget.playerService.currentTrack;

            return LiquidGlassContainer(
              height: MediaQuery.of(context).size.height * 0.70,
              borderRadius: 28,
              blur: 20,
              tintColor: const Color(0xFF14171E),
              tintAlpha: 0.85,
              glowShadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 36,
                  offset: const Offset(0, -6),
                ),
              ],
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag Handle Indicator
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Playing Queue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: SpectraTheme.cyanWave.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${playlist.length} Tracks',
                                style: const TextStyle(
                                  color: SpectraTheme.cyanWave,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (playlist.length > 1)
                              IconButton(
                                tooltip: 'Clear Queue',
                                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54, size: 22),
                                onPressed: () {
                                  widget.playerService.clearQueue();
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  if (playlist.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Queue is empty',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: playlist.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIdx, newIdx) {
                          widget.playerService.reorderQueue(oldIdx, newIdx);
                        },
                        itemBuilder: (context, idx) {
                          final item = playlist[idx];
                          final isCurrentlyPlaying = item.id == currentTrack?.id;

                          return Dismissible(
                            key: ValueKey('${item.id}_$idx'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.redAccent.withValues(alpha: 0.25),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            ),
                            onDismissed: (_) {
                              widget.playerService.removeFromQueue(idx);
                            },
                            child: ListTile(
                              key: ValueKey('tile_${item.id}_$idx'),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: TrackArtwork(
                                      artworkUrl: item.artworkUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (isCurrentlyPlaying)
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.equalizer_rounded,
                                        color: SpectraTheme.cyanWave,
                                        size: 22,
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrentlyPlaying ? SpectraTheme.cyanWave : Colors.white,
                                  fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                item.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.white30,
                                size: 20,
                              ),
                              onTap: () {
                                widget.playerService.playTrack(item);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Extracts real dominant & vibrant tones from album artwork image, caching results
  void _extractPaletteColors(Track track) async {
    final artUrl = track.artworkUrl;
    if (artUrl == null || artUrl.isEmpty) {
      if (_extractedPaletteColors != null) {
        setState(() => _extractedPaletteColors = null);
      }
      return;
    }
    if (_lastExtractedArtworkUrl == artUrl) return;
    _lastExtractedArtworkUrl = artUrl;

    if (_paletteCache.containsKey(artUrl)) {
      setState(() => _extractedPaletteColors = _paletteCache[artUrl]);
      return;
    }

    try {
      ImageProvider? imgProvider;
      if (artUrl.startsWith('http://') || artUrl.startsWith('https://')) {
        imgProvider = NetworkImage(artUrl);
      } else if (artUrl.startsWith('assets/')) {
        imgProvider = AssetImage(artUrl);
      }

      if (imgProvider != null) {
        final generator = await PaletteGenerator.fromImageProvider(
          imgProvider,
          maximumColorCount: 16,
          timeout: const Duration(seconds: 4),
        );

        final c1 = generator.vibrantColor?.color ??
            generator.dominantColor?.color ??
            generator.darkVibrantColor?.color ??
            const Color(0xFF00F2FE);

        final c2 = generator.darkMutedColor?.color ??
            generator.mutedColor?.color ??
            generator.lightVibrantColor?.color ??
            const Color(0xFF9D4EDD);

        // Darken for OLED void harmony so text and controls remain ultra-readable
        final darkC1 = Color.lerp(c1, SpectraTheme.obsidian, 0.75)!;
        final darkC2 = Color.lerp(c2, SpectraTheme.obsidian, 0.80)!;

        final result = [darkC1, darkC2];
        _paletteCache[artUrl] = result;
        if (mounted && _lastExtractedArtworkUrl == artUrl) {
          setState(() => _extractedPaletteColors = result);
        }
      }
    } catch (e) {
      debugPrint('[NowPlayingScreen] Palette extraction error: $e');
    }
  }

  // Generate adaptive ambient background hues from artwork, or fallback to hash-based palette
  List<Color> _deriveAmbientColors(Track track) {
    if (_extractedPaletteColors != null) {
      return _extractedPaletteColors!;
    }
    final seed = '${track.title}_${track.artist}';
    final hash = seed.hashCode.abs();
    final palette = [
      [const Color(0xFF1E0734), const Color(0xFF072138)], // Violet / Cyan
      [const Color(0xFF340713), const Color(0xFF1B0734)], // Crimson / Purple
      [const Color(0xFF073034), const Color(0xFF071034)], // Teal / Deep Indigo
      [const Color(0xFF342307), const Color(0xFF220734)], // Amber / Violet
      [const Color(0xFF0B2D19), const Color(0xFF091C2E)], // Emerald / Navy
    ];
    return palette[hash % palette.length];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playerService,
      builder: (context, _) {
        final track = widget.playerService.currentTrack ??
            const Track(
              id: 'demo',
              title: 'Sharp Shooter',
              artist: 'Masoom Sharma',
              album: 'Single',
              duration: Duration(minutes: 3, seconds: 48),
            );

        final position = widget.playerService.position;
        final duration = widget.playerService.duration.inSeconds > 0
            ? widget.playerService.duration
            : track.duration;

        _extractPaletteColors(track);
        final ambientColors = _deriveAmbientColors(track);

        // Auto-refresh lyrics when track changes via next/previous/shuffle
        _checkAndRefreshLyrics(track);

        // Check if current lyrics are true synchronized .lrc timestamps or plain unsynced text
        final bool isSyncedLrc = _lyrics.isNotEmpty && _lyrics.any((l) => l.isSynced);

        // For true .lrc lyrics, apply 200ms anticipatory vocal lead offset so lines glow as the singer hits each lyric
        final adjustedPosition = isSyncedLrc ? position + const Duration(milliseconds: 200) : position;

        if (_activePageIndex == 1 && _lyrics.isNotEmpty && isSyncedLrc) {
          for (int i = 0; i < _lyrics.length; i++) {
            final isCurrent = adjustedPosition >= _lyrics[i].timestamp &&
                (i == _lyrics.length - 1 || adjustedPosition < _lyrics[i + 1].timestamp);
            if (isCurrent) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveLyric(i));
              break;
            }
          }
        }

        return Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (details) {
              // If dragging downward significantly (> 20px in a single frame), trigger minimize immediately
              if (details.delta.dy > 18) {
                _handleBack(context);
              }
            },
            onVerticalDragEnd: (details) {
              // Primary downward velocity > 150 indicates a deliberate downward swipe to minimize
              if (details.primaryVelocity != null && details.primaryVelocity! > 150) {
                _handleBack(context);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.40, 0.75, 1.0],
                  colors: [
                    ambientColors[0].withValues(alpha: 0.75),
                    const Color(0xFF0D101A),
                    ambientColors.length > 1
                        ? ambientColors[1].withValues(alpha: 0.35)
                        : const Color(0xFF0A1424),
                    ambientColors[0].withValues(alpha: 0.45),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  children: [
                    // Top App Bar with back button and lyrics toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 28),
                          tooltip: 'Minimize / Back',
                          onPressed: () => _handleBack(context),
                        ),
                        LiquidGlassPill(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          accentColor: SpectraTheme.cyanWave,
                          child: Text(
                            _activePageIndex == 0 ? 'NOW PLAYING' : 'LYRICS',
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, color: SpectraTheme.cyanWave, size: 22),
                              tooltip: 'DSP Equalizer',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EqScreen(
                                      ambientA: ambientColors[0],
                                      ambientB: ambientColors.length > 1 ? ambientColors[1] : SpectraTheme.cyanWave,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (widget.showQueueDrawer)
                              IconButton(
                                icon: const Icon(
                                  Icons.queue_music_rounded,
                                  color: Colors.white70,
                                ),
                                tooltip: 'Playing Queue',
                                onPressed: () => _showQueueBottomSheet(context),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // SWIPEABLE HERO AREA: Swipe between Album Art and Synced Lyrics
                    Expanded(
                      flex: 5,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (idx) => setState(() => _activePageIndex = idx),
                        children: [
                          // PAGE 1: Album Artwork with Liquid Glass Frame and glowing ambient backlight
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _pageController.animateToPage(
                                1,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOutCubic,
                              );
                            },
                            child: Center(
                              child: Container(
                                width: 296,
                                height: 296,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ambientColors[0].withValues(alpha: 0.55),
                                      blurRadius: 48,
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: ambientColors.length > 1
                                          ? ambientColors[1].withValues(alpha: 0.45)
                                          : SpectraTheme.cyanWave.withValues(alpha: 0.3),
                                      blurRadius: 56,
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: RepaintBoundary(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        TrackArtwork(
                                          key: ValueKey(track.artworkUrl ?? track.id),
                                          artworkUrl: track.artworkUrl,
                                          width: 296,
                                          height: 296,
                                          fit: BoxFit.cover,
                                        ),
                                        // Specular Liquid Glass refractive sheen
                                        IgnorePointer(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.24),
                                                width: 1.5,
                                              ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.white.withValues(alpha: 0.16),
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.22),
                                                ],
                                                stops: const [0.0, 0.45, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // PAGE 2: Synced Interactive Karaoke Lyrics in Liquid Glass Container
                          LiquidGlassContainer(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(16),
                            borderRadius: 24,
                            blur: 18,
                            tintColor: ambientColors[0],
                            tintAlpha: 0.08,
                            glowShadows: [
                              BoxShadow(
                                color: ambientColors[0].withValues(alpha: 0.25),
                                blurRadius: 28,
                                spreadRadius: -4,
                              ),
                            ],
                            child: _lyrics.isEmpty
                                ? Center(
                                    child: _isLoadingLyrics
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: SpectraTheme.cyanWave,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Searching synced lyrics for "${track.title}"...',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                '(Swipe left for album artwork)',
                                                style: TextStyle(color: Colors.white38, fontSize: 11),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.lyrics_outlined,
                                                size: 40,
                                                color: Colors.white24,
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Lyrics not available for this track',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'No synced or text lyrics found for "${track.title}"',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              ),
                                              const SizedBox(height: 16),
                                              OutlinedButton.icon(
                                                onPressed: _loadLyrics,
                                                icon: const Icon(Icons.refresh_rounded, size: 14, color: SpectraTheme.cyanWave),
                                                label: const Text(
                                                  'Retry Search',
                                                  style: TextStyle(color: SpectraTheme.cyanWave, fontSize: 12),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(color: SpectraTheme.cyanWave.withValues(alpha: 0.3)),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                ),
                                              ),
                                            ],
                                          ),
                                  )
                                : Column(
                                    children: [
                                      // Lyrics status pill (Synced Karaoke vs Unsynced Text)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isSyncedLrc ? Icons.graphic_eq_rounded : Icons.menu_book_rounded,
                                              size: 13,
                                              color: isSyncedLrc ? SpectraTheme.cyanWave : Colors.white38,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isSyncedLrc ? 'SYNCED KARAOKE' : 'UNSYNCED LYRICS',
                                              style: TextStyle(
                                                color: isSyncedLrc ? SpectraTheme.cyanWave : Colors.white38,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          controller: _lyricsScrollController,
                                          itemCount: _lyrics.length,
                                          itemBuilder: (context, idx) {
                                            final line = _lyrics[idx];
                                            final isCurrent = isSyncedLrc &&
                                                adjustedPosition >= line.timestamp &&
                                                (idx == _lyrics.length - 1 ||
                                                    adjustedPosition < _lyrics[idx + 1].timestamp);

                                            return GestureDetector(
                                              onTap: isSyncedLrc
                                                  ? () {
                                                      widget.playerService.seek(line.timestamp);
                                                    }
                                                  : null,
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 350),
                                                curve: Curves.easeOutCubic,
                                                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                                color: Colors.transparent,
                                                child: AnimatedDefaultTextStyle(
                                                  duration: const Duration(milliseconds: 300),
                                                  curve: Curves.easeOutCubic,
                                                  style: TextStyle(
                                                    fontSize: isCurrent
                                                        ? 22
                                                        : (isSyncedLrc ? 16 : 17),
                                                    fontWeight: isCurrent
                                                        ? FontWeight.w800
                                                        : (isSyncedLrc ? FontWeight.w500 : FontWeight.w600),
                                                    color: isCurrent
                                                        ? SpectraTheme.cyanWave
                                                        : (isSyncedLrc ? Colors.white30 : Colors.white70),
                                                    letterSpacing: 0.3,
                                                    height: 1.45,
                                                    shadows: isCurrent
                                                        ? [
                                                            Shadow(
                                                              color: SpectraTheme.cyanWave.withValues(alpha: 0.6),
                                                              blurRadius: 18,
                                                            ),
                                                            Shadow(
                                                              color: SpectraTheme.cyanWave.withValues(alpha: 0.3),
                                                              blurRadius: 32,
                                                            ),
                                                          ]
                                                        : null,
                                                  ),
                                                  child: Text(
                                                    line.text,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Dot Page Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: _activePageIndex == 0 ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _activePageIndex == 0 ? SpectraTheme.cyanWave : Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: _activePageIndex == 1 ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _activePageIndex == 1 ? SpectraTheme.cyanWave : Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Main track info row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      track.artist,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white60,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Interactive Favorite / Heart Button
                              ListenableBuilder(
                                listenable: PlaylistService.instance,
                                builder: (context, _) {
                                  final isLiked = PlaylistService.instance.isTrackLiked(track.id);
                                  return IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: isLiked ? const Color(0xFFFF2E93) : Colors.white60,
                                      size: 26,
                                    ),
                                    tooltip: isLiked ? 'Liked (Tap to remove)' : 'Like song',
                                    onPressed: () async {
                                      final nowLiked = await PlaylistService.instance.toggleLikeTrack(track.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(
                                                  nowLiked ? Icons.favorite_rounded : Icons.heart_broken_rounded,
                                                  color: nowLiked ? const Color(0xFFFF2E93) : Colors.white70,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    nowLiked
                                                        ? 'Saved to Liked Songs'
                                                        : 'Removed from Liked Songs',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: const Color(0xFF1B1E28),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          // Live Audio Spec Pill (Exclusively shown in Audiophile Studio Mode)
                          if (widget.viewMode == LibraryViewMode.audiophileHybrid && widget.showAudioSpecPill) ...[
                            const SizedBox(height: 8),
                            () {
                              final isFlac = track.format == AudioFormat.flac;
                              final isOpus = track.format == AudioFormat.opus;
                              final formatName = track.format.name.toUpperCase();
                              
                              // Dynamic audiophile technical specifications
                              final bitDepthStr = isFlac ? '24-BIT / 96kHz' : (isOpus ? '48kHz' : '16-BIT / 44.1kHz');
                              final bitrateStr = isFlac ? '920 kbps' : (isOpus ? '160 kbps' : '320 kbps');
                              final dacEngineStr = isFlac ? 'BIT-PERFECT DIRECT DAC' : 'HI-FI ENGINE';

                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: LiquidGlassContainer(
                                  borderRadius: 20,
                                  blur: 14,
                                  tintColor: isFlac ? SpectraTheme.cyanWave : Colors.white,
                                  tintAlpha: isFlac ? 0.15 : 0.06,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                  glowShadows: isFlac
                                      ? [
                                          BoxShadow(
                                            color: SpectraTheme.cyanWave.withValues(alpha: 0.22),
                                            blurRadius: 14,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isFlac ? const Color(0xFFFFB300) : SpectraTheme.cyanWave,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          formatName,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        '$bitDepthStr • $bitrateStr',
                                        style: TextStyle(
                                          color: isFlac ? SpectraTheme.cyanWave : Colors.white70,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Container(
                                        width: 3.5,
                                        height: 3.5,
                                        decoration: BoxDecoration(
                                          color: isFlac ? SpectraTheme.cyanWave : Colors.white30,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        dacEngineStr,
                                        style: TextStyle(
                                          color: isFlac ? const Color(0xFF69F0AE) : Colors.white38,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }(),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // FLOATING LIQUID GLASS CONTROLS DOCK
                    LiquidGlassContainer(
                      borderRadius: 28,
                      blur: 20,
                      tintColor: Colors.white,
                      tintAlpha: 0.05,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      glowShadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 26,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: ambientColors[0].withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 0),
                        ),
                      ],
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Seeker Bar
                          Slider(
                            value: position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                            max: duration.inMilliseconds.toDouble(),
                            onChanged: (val) {
                              widget.playerService.seek(Duration(milliseconds: val.toInt()));
                            },
                          ),

                          // Time Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                Text(_formatDuration(duration), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Playback Controls (Shuffle, Previous, Play/Pause, Next, Repeat)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Shuffle Toggle
                              IconButton(
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  color: widget.playerService.isShuffle ? SpectraTheme.cyanWave : Colors.white38,
                                  size: 24,
                                ),
                                tooltip: 'Shuffle: ${widget.playerService.isShuffle ? "ON" : "OFF"}',
                                onPressed: () => widget.playerService.toggleShuffle(),
                              ),

                              // Skip Previous
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                                tooltip: 'Previous Track',
                                onPressed: () => widget.playerService.previousTrack(),
                              ),

                              // Play/Pause Big Radiant Button
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [SpectraTheme.cyanWave, SpectraTheme.neonMagenta],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: SpectraTheme.cyanWave.withValues(alpha: 0.45),
                                      blurRadius: 22,
                                    )
                                  ],
                                ),
                                child: IconButton(
                                  iconSize: 38,
                                  icon: Icon(
                                    widget.playerService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                  ),
                                  tooltip: widget.playerService.isPlaying ? 'Pause' : 'Play',
                                  onPressed: () => widget.playerService.togglePlayPause(),
                                ),
                              ),

                              // Skip Next
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                                tooltip: 'Next Track',
                                onPressed: () => widget.playerService.nextTrack(),
                              ),

                              // Repeat Toggle
                              IconButton(
                                icon: Icon(
                                  widget.playerService.isRepeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                  color: widget.playerService.isRepeat ? SpectraTheme.neonMagenta : Colors.white38,
                                  size: 24,
                                ),
                                tooltip: 'Repeat: ${widget.playerService.isRepeat ? "Track" : "OFF"}',
                                onPressed: () => widget.playerService.toggleRepeat(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // --- PERSONA ADAPTIVE CONTROLS ---
                          if (widget.viewMode == LibraryViewMode.classic) ...[
                            // CLASSIC MINIMAL: 1-Tap Sound Presets
                            _buildClassicQuickPresetsBar(),
                          ] else ...[
                            // AUDIOPHILE STUDIO: Studio DSP quick metrics & shortcuts
                            _buildAudiophileStudioQuickBar(context),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  /// 1-Tap preset selector for Classic Mode in Liquid Glass
  Widget _buildClassicQuickPresetsBar() {
    final eq = EqService.instance;
    final activeType = eq.isEnabled && eq.currentPreset != null
        ? eq.currentPreset!.type
        : EqPresetType.flat;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPresetChip(
            label: 'Flat',
            icon: Icons.horizontal_rule_rounded,
            isSelected: activeType == EqPresetType.flat,
            onTap: () {
              final p = EqService.builtinPresets.firstWhere((p) => p.type == EqPresetType.flat);
              eq.applyPreset(p);
              setState(() {});
            },
          ),
          _buildPresetChip(
            label: '🚗 Car',
            icon: Icons.directions_car_rounded,
            isSelected: activeType == EqPresetType.carAudio,
            selectedColor: const Color(0xFF10B981),
            onTap: () {
              final p = EqService.builtinPresets.firstWhere((p) => p.type == EqPresetType.carAudio);
              eq.applyPreset(p);
              setState(() {});
            },
          ),
          _buildPresetChip(
            label: 'Bass',
            icon: Icons.graphic_eq_rounded,
            isSelected: activeType == EqPresetType.bassBoost,
            onTap: () {
              final p = EqService.builtinPresets.firstWhere((p) => p.type == EqPresetType.bassBoost);
              eq.applyPreset(p);
              setState(() {});
            },
          ),
          _buildPresetChip(
            label: 'Vocal',
            icon: Icons.mic_rounded,
            isSelected: activeType == EqPresetType.vocalClarity,
            onTap: () {
              final p = EqService.builtinPresets.firstWhere((p) => p.type == EqPresetType.vocalClarity);
              eq.applyPreset(p);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    Color selectedColor = SpectraTheme.cyanWave,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: selectedColor.withValues(alpha: 0.5), width: 1) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? selectedColor : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Audiophile quick DSP bar in Liquid Glass
  Widget _buildAudiophileStudioQuickBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: SpectraTheme.cyanWave.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.tune_rounded, size: 14, color: SpectraTheme.cyanWave),
              ),
              const SizedBox(width: 8),
              const Text(
                'STUDIO DSP ACTIVE',
                style: TextStyle(
                  color: SpectraTheme.cyanWave,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          Text(
            'BIT-PERFECT • GAPLESS',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
