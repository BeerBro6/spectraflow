import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/audio_player_service.dart';
import 'services/downloader_service.dart';
import 'theme/theme.dart';
import 'screens/library_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/feature_intro_screen.dart';
import 'screens/eq_screen.dart' show EqScreen;

import 'services/local_vault_service.dart';
import 'services/local_audio_proxy_service.dart';
import 'services/playlist_service.dart';
import 'services/permission_hub_service.dart';
import 'services/first_launch_service.dart';
import 'widgets/track_artwork.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.spectraflow.channel.audio',
      androidNotificationChannelName: 'SpectraFlow Audio Playback',
      androidNotificationChannelDescription: 'Displays playback controls, cover art, and progress on notification bar and lock screen',
      androidNotificationIcon: 'drawable/ic_notification',
      androidStopForegroundOnPause: false,
      notificationColor: const Color(0xFF00F2FE),
    );
    // The previous diagnosis showed the AudioService was bound but never
    // promoted to a foreground service, which caused Samsung's
    // AudioHardening policy to mute the app after a grace period. The
    // foreground service is now promoted by `JustAudioBackground.init()`
    // itself when the first `_broadcastState()` call updates
    // `playbackState.playing = true` (which happens automatically the moment
    // the user presses play). Nothing extra is needed here.
    await LocalAudioProxyService.instance.start();
  }
  await LocalVaultService.instance.init();
  await PlaylistService.instance.init();
  final isFirstLaunch = await FirstLaunchService.needsModeSelection();
  final savedUserName = await FirstLaunchService.readUserName();
  runApp(SpectraFlowApp(firstLaunch: isFirstLaunch, userName: savedUserName));
}

class SpectraFlowApp extends StatefulWidget {
  final bool firstLaunch;
  final String? userName;
  const SpectraFlowApp({super.key, this.firstLaunch = true, this.userName});

  @override
  State<SpectraFlowApp> createState() => _SpectraFlowAppState();
}

class _SpectraFlowAppState extends State<SpectraFlowApp> {
  bool _showSplash = true;
  bool _needsWelcome = false;
  bool _needsIntro = false;
  bool _bootstrapped = false;
  LibraryViewMode? _initialMode;

  Future<void> _onSplashComplete() async {
    // Resolve first-launch state once the splash animation has finished.
    final needsMode = await FirstLaunchService.needsModeSelection();
    final needsIntro = await FirstLaunchService.needsIntro();
    final savedMode = await FirstLaunchService.readSelectedMode();
    if (!mounted) return;
    setState(() {
      _showSplash = false;
      _needsWelcome = needsMode;
      _needsIntro = !needsMode && needsIntro;
      _initialMode = savedMode;
      _bootstrapped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_showSplash) {
      home = SplashScreen(
        iconAsset: 'assets/images/logo_prism_music.png',
        userName: widget.userName,
        onFinished: _onSplashComplete,
        firstLaunch: widget.firstLaunch,
      );
    } else if (_needsWelcome) {
      home = WelcomeScreen(
        onModeChosen: (mode) {
          if (!mounted) return;
          setState(() {
            _needsWelcome = false;
            _needsIntro = true;
            _initialMode = mode;
          });
        },
      );
    } else if (_needsIntro) {
      home = FeatureIntroScreen(
        onComplete: () {
          if (!mounted) return;
          setState(() => _needsIntro = false);
        },
      );
    } else {
      // First launch complete (or returning user) — if the splash hasn't
      // finished resolving first-launch state, show a transient scaffold
      // rather than a flash of the main UI.
      home = _bootstrapped
          ? MainNavigationShell(initialMode: _initialMode)
          : const _BootstrapSplash();
    }
    return MaterialApp(
      title: 'SpectraFlow',
      debugShowCheckedModeBanner: false,
      theme: SpectraTheme.darkTheme,
      home: home,
    );
  }
}

/// Transient scaffold shown between splash and the first screen when
/// first-launch state is still resolving. Prevents a flash of the main UI.
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: SpectraTheme.obsidian,
      body: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: SpectraTheme.cyanWave),
        ),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final LibraryViewMode? initialMode;
  const MainNavigationShell({super.key, this.initialMode});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0; // Starts on Library
  LibraryViewMode _viewMode = LibraryViewMode.audiophileHybrid;
  bool _showAudioSpecPill = true; // Live Audio Spec Pill
  bool _showQueueDrawer = true; // Queue Drawer
  bool _showMiniPlayer = true; // Floating Mini-Player Pill
  late final AudioPlayerService _playerService;
  late final DownloaderService _downloaderService;

  @override
  void initState() {
    super.initState();
    if (widget.initialMode != null) {
      _viewMode = widget.initialMode!;
    }
    _playerService = AudioPlayerService();
    _downloaderService = DownloaderService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });
  }

  void _checkNotificationPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted && mounted) {
        // Show polite explanatory dialog before system prompt
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF141720),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white12),
            ),
            title: const Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: SpectraTheme.cyanWave),
                SizedBox(width: 10),
                Text('Playback Controls', style: TextStyle(color: Colors.white, fontSize: 17)),
              ],
            ),
            content: const Text(
              'Allow notifications so SpectraFlow can display music playback controls, artwork, and seeker on your Lock Screen and Notification Bar.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Not Now', style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpectraTheme.cyanWave,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await PermissionHubService.instance.requestNotificationPermission();
                },
                child: const Text('Enable Controls', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      await PermissionHubService.instance.refresh();
    }
  }

  @override
  void dispose() {
    _playerService.dispose();
    _downloaderService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      LibraryScreen(
        playerService: _playerService,
        viewMode: _viewMode,
        onOpenNowPlaying: () => setState(() => _currentIndex = 1),
      ),
      NowPlayingScreen(
        playerService: _playerService,
        viewMode: _viewMode,
        showAudioSpecPill: _showAudioSpecPill,
        onToggleAudioSpecPill: () => setState(() => _showAudioSpecPill = !_showAudioSpecPill),
        showQueueDrawer: _showQueueDrawer,
        onToggleQueueDrawer: () => setState(() => _showQueueDrawer = !_showQueueDrawer),
        onBack: () => setState(() => _currentIndex = 0),
      ),
      SearchScreen(
        playerService: _playerService,
        downloaderService: _downloaderService,
        onOpenNowPlaying: () => setState(() => _currentIndex = 1),
      ),
      SettingsScreen(
        currentMode: _viewMode,
        onModeChanged: (mode) => setState(() => _viewMode = mode),
        showAudioSpecPill: _showAudioSpecPill,
        onShowAudioSpecPillChanged: (val) => setState(() => _showAudioSpecPill = val),
        showQueueDrawer: _showQueueDrawer,
        onShowQueueDrawerChanged: (val) => setState(() => _showQueueDrawer = val),
        showMiniPlayer: _showMiniPlayer,
        onShowMiniPlayerChanged: (val) => setState(() => _showMiniPlayer = val),
        playerService: _playerService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      // Sleek floating bottom capsule menu with floating mini-player
      bottomNavigationBar: Container(
        color: SpectraTheme.obsidian,
        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 18, top: 4),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating Mini-Player capsule
              if (_showMiniPlayer && _currentIndex != 1)
                ListenableBuilder(
                  listenable: _playerService,
                  builder: (context, _) {
                    final track = _playerService.currentTrack;
                    if (track == null) return const SizedBox.shrink();
                    return _buildFloatingMiniPlayer(track);
                  },
                ),
              // Main navigation pill (4 items)
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF161A22), // Soft matte dark capsule
                  borderRadius: BorderRadius.circular(32), // Full capsule round pill
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(icon: Icons.grid_view_rounded, index: 0, label: 'Library'),
                    _buildNavItem(icon: Icons.equalizer_rounded, index: 1, label: 'Player'),
                    _buildNavItem(icon: Icons.search_rounded, index: 2, label: 'Search'),
                    _buildNavItem(icon: Icons.settings_rounded, index: 3, label: 'Settings'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMiniPlayer(dynamic track) {
    final isPlaying = _playerService.isPlaying;
    final position = _playerService.position;
    final duration = _playerService.duration;
    final progress = (duration.inMilliseconds > 0)
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F29), // Rich frosted dark capsule
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: SpectraTheme.cyanWave.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _currentIndex = 1),
            splashColor: SpectraTheme.cyanWave.withValues(alpha: 0.15),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Track Artwork thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: TrackArtwork(
                            artworkUrl: track.artworkUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // DSP Equalizer shortcut
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EqScreen()),
                        ),
                        iconSize: 22,
                        color: SpectraTheme.cyanWave,
                        splashRadius: 18,
                        tooltip: 'DSP Equalizer',
                        icon: const Icon(Icons.tune_rounded),
                      ),
                      // Play / Pause toggle
                      IconButton(
                        onPressed: () => _playerService.togglePlayPause(),
                        iconSize: 28,
                        color: Colors.white,
                        splashRadius: 22,
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                // Micro live progress indicator bar across the bottom
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(SpectraTheme.cyanWave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index, required String label}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white38,
          size: 24,
        ),
      ),
    );
  }
}
