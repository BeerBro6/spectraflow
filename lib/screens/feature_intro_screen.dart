import 'package:flutter/material.dart';
import '../services/first_launch_service.dart';
import '../theme/theme.dart';

/// One-time swipeable tour of the major SpectraFlow features. Shown
/// immediately after the user picks a mode on first launch. Each page
/// highlights a single feature with an icon, a title, and a short body
/// description. Persisted completion via [FirstLaunchService].
class FeatureIntroScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const FeatureIntroScreen({super.key, required this.onComplete});

  @override
  State<FeatureIntroScreen> createState() => _FeatureIntroScreenState();
}

class _FeatureIntroScreenState extends State<FeatureIntroScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  bool _leaving = false;

  static const List<_IntroFeature> _features = [
    _IntroFeature(
      icon: Icons.library_music_rounded,
      title: 'Your Lossless Vault',
      body:
          'Point SpectraFlow at any folder of FLAC, MP3, M4A, OPUS, or WAV files and we index them automatically. Cover art, bit-depth, and sample-rate are extracted from each file.',
      accent: Color(0xFFFF9100),
    ),
    _IntroFeature(
      icon: Icons.flash_on_rounded,
      title: 'Quick Picks',
      body:
          'A swipeable carousel of recently-added favorites lives at the top of your library. Tap any tile to start playback instantly — no menus, no friction.',
      accent: SpectraTheme.cyanWave,
    ),
    _IntroFeature(
      icon: Icons.sort_rounded,
      title: 'Sort Your Way',
      body:
          'Sort tracks by Recently Added, Title, Artist, Album, or Longest. Switch category chips between All Songs, Playlists, Artists, and Albums.',
      accent: Color(0xFFFF2E93),
    ),
    _IntroFeature(
      icon: Icons.playlist_add_rounded,
      title: 'Build Playlists',
      body:
          'Tap the + on any track, or long-press for the full options sheet. Pin your favorites to Liked Songs for one-tap access from anywhere in the app.',
      accent: Color(0xFF00E676),
    ),
    _IntroFeature(
      icon: Icons.tune_rounded,
      title: 'DSP Equalizer',
      body:
          'In Audiophile Studio mode, unlock the 10-band parametric EQ, the live audio spec pill, and bit-perfect DAC routing for studio-grade playback.',
      accent: SpectraTheme.cyanWave,
    ),
    _IntroFeature(
      icon: Icons.search_rounded,
      title: 'Search Everywhere',
      body:
          'Find local files, saved playlists, and results from linked streaming services — all from one search bar at the bottom of the screen.',
      accent: Color(0xFFFFB300),
    ),
    _IntroFeature(
      icon: Icons.swipe_rounded,
      title: 'Long-press for Power',
      body:
          'Long-press any track to Remove it from your library or Delete it from device. Every destructive action asks for confirmation — nothing happens by accident.',
      accent: Color(0xFFAB47BC),
    ),
  ];

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    await FirstLaunchService.markIntroSeen();
    if (!mounted) return;
    widget.onComplete();
  }

  void _next() {
    if (_page < _features.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _features[_page];
    return Scaffold(
      backgroundColor: SpectraTheme.obsidian,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _leaving ? null : _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _features.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (ctx, idx) {
                    final fe = _features[idx];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fe.accent.withValues(alpha: 0.15),
                            border: Border.all(
                              color: fe.accent.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(fe.icon, color: fe.accent, size: 72),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          fe.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          fe.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_features.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? f.accent : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: f.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _leaving ? null : _next,
                  child: Text(
                    _page == _features.length - 1 ? 'Start Listening' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroFeature {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  const _IntroFeature({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
}