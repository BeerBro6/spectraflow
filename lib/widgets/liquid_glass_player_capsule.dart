import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_player_service.dart';
import '../models/track.dart';
import 'track_artwork.dart';

/// Floating Liquid Glass Player Capsule matching the concept art
/// in liquid_glass_ui_1791451290858.jpg with ambient cyan-to-magenta neon glow,
/// circular glass transport controls, radiant liquid orb play/pause button,
/// and an interactive glowing audio waveform spectrum seeker.
class LiquidGlassPlayerCapsule extends StatelessWidget {
  const LiquidGlassPlayerCapsule({
    super.key,
    required this.playerService,
    this.track,
    this.isMini = false,
    this.onTap,
  });

  final AudioPlayerService playerService;
  final Track? track;
  final bool isMini;
  final VoidCallback? onTap;

  static const _cyan = Color(0xFF00F2FE);
  static const _magenta = Color(0xFFFF007F);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerService,
      builder: (context, _) {
        final position = playerService.position;
        final duration = playerService.duration;
        final isPlaying = playerService.isPlaying;
        final currentTrack = track ?? playerService.currentTrack;

        final posMs = position.inMilliseconds;
        final durMs = duration.inMilliseconds;
        final progress = (durMs > 0) ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
        final remaining = (durMs > posMs) ? Duration(milliseconds: durMs - posMs) : Duration.zero;

        if (isMini) {
          return _buildMiniPlayer(
            context: context,
            track: currentTrack,
            isPlaying: isPlaying,
            progress: progress,
          );
        }

        return _buildFullCapsule(
          context: context,
          track: currentTrack,
          isPlaying: isPlaying,
          position: position,
          remaining: remaining,
          progress: progress,
          durMs: durMs,
        );
      },
    );
  }

  /// Compact horizontal liquid glass mini player for Library / Search / Settings
  Widget _buildMiniPlayer({
    required BuildContext context,
    required Track? track,
    required bool isPlaying,
    required double progress,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _cyan.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(-4, 0),
            ),
            BoxShadow(
              color: _magenta.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.0,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    const Color(0xFF101422).withValues(alpha: 0.80),
                    const Color(0xFF070A14).withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.40, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Upper glass specular highlight
                  Positioned(
                    top: 0,
                    left: 24,
                    right: 24,
                    height: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.4),
                            _cyan.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        // Track thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.0,
                              ),
                            ),
                            child: TrackArtwork(
                              artworkUrl: track?.artworkUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title & Artist
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.title ?? 'No Track Playing',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track?.artist ?? 'SpectraFlow',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Previous button
                        _CircularGlassButton(
                          size: 34,
                          icon: Icons.skip_previous_rounded,
                          iconSize: 18,
                          tooltip: 'Previous',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            playerService.previousTrack();
                          },
                        ),
                        const SizedBox(width: 8),
                        // Play / Pause Orb
                        _RadiantPlayPauseButton(
                          size: 44,
                          isPlaying: isPlaying,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            playerService.togglePlayPause();
                          },
                        ),
                        const SizedBox(width: 8),
                        // Next button
                        _CircularGlassButton(
                          size: 34,
                          icon: Icons.skip_next_rounded,
                          iconSize: 18,
                          tooltip: 'Next',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            playerService.nextTrack();
                          },
                        ),
                      ],
                    ),
                  ),
                  // Progress line at bottom edge
                  Positioned(
                    bottom: 0,
                    left: 20,
                    right: 20,
                    height: 2.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                width: constraints.maxWidth,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              Container(
                                width: constraints.maxWidth * progress,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [_cyan, _magenta],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Full-size liquid glass player capsule for Now Playing Screen matching concept art
  Widget _buildFullCapsule({
    required BuildContext context,
    required Track? track,
    required bool isPlaying,
    required Duration position,
    required Duration remaining,
    required double progress,
    required int durMs,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.70),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            // Radiant Electric Cyan bloom on left edge
            BoxShadow(
              color: _cyan.withValues(alpha: 0.42),
              blurRadius: 36,
              spreadRadius: 1,
              offset: const Offset(-8, -2),
            ),
            // Radiant Hot Magenta bloom on right edge
            BoxShadow(
              color: _magenta.withValues(alpha: 0.42),
              blurRadius: 36,
              spreadRadius: 1,
              offset: const Offset(8, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(44),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    const Color(0xFF101422).withValues(alpha: 0.76),
                    const Color(0xFF070A14).withValues(alpha: 0.90),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Specular top light streak
                  Positioned(
                    top: 0,
                    left: 28,
                    right: 28,
                    height: 1.2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.45),
                            _cyan.withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Transport Buttons Row with Shuffle & Repeat integrated
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Shuffle Button
                          _GlassIconButton(
                            icon: Icons.shuffle_rounded,
                            isActive: playerService.isShuffle,
                            activeColor: _cyan,
                            tooltip: 'Shuffle: ${playerService.isShuffle ? "ON" : "OFF"}',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              playerService.toggleShuffle();
                            },
                          ),
                          // Previous Track Button
                          _CircularGlassButton(
                            size: 44,
                            icon: Icons.skip_previous_rounded,
                            iconSize: 24,
                            tooltip: 'Previous',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              playerService.previousTrack();
                            },
                          ),
                          // Radiant Elevated Play/Pause Glass Orb
                          _RadiantPlayPauseButton(
                            size: 60,
                            isPlaying: isPlaying,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              playerService.togglePlayPause();
                            },
                          ),
                          // Next Track Button
                          _CircularGlassButton(
                            size: 44,
                            icon: Icons.skip_next_rounded,
                            iconSize: 24,
                            tooltip: 'Next',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              playerService.nextTrack();
                            },
                          ),
                          // Repeat Button
                          _GlassIconButton(
                            icon: playerService.isRepeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                            isActive: playerService.isRepeat,
                            activeColor: _magenta,
                            tooltip: 'Repeat: ${playerService.isRepeat ? "Track" : "OFF"}',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              playerService.toggleRepeat();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Neon Waveform Spectrum Seeker Bar Row
                      Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NeonWaveformSeeker(
                              progress: progress,
                              onSeek: (p) {
                                final targetMs = (p * durMs).toInt();
                                playerService.seek(Duration(milliseconds: targetMs));
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            durMs > 0 ? '-${_formatDuration(remaining)}' : '00:00',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: _magenta.withValues(alpha: 0.90),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular frosted glass transport button with specular upper sheen
class _CircularGlassButton extends StatelessWidget {
  const _CircularGlassButton({
    required this.size,
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onTap,
  });

  final double size;
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: const Color(0xFF00F2FE).withValues(alpha: 0.25),
        highlightColor: Colors.white.withValues(alpha: 0.08),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Specular top highlight
              Positioned(
                top: 2,
                child: Container(
                  width: size * 0.62,
                  height: size * 0.28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.15),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.95),
                size: iconSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle circular glass icon button for secondary controls (Shuffle & Repeat)
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: activeColor.withValues(alpha: 0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? activeColor.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.45),
            size: 19,
          ),
        ),
      ),
    );
  }
}

/// Radiant Elevated Play/Pause Glass Orb with radiant neon halo bloom,
/// gradient border, and specular glass dome
class _RadiantPlayPauseButton extends StatelessWidget {
  const _RadiantPlayPauseButton({
    required this.size,
    required this.isPlaying,
    required this.onTap,
  });

  final double size;
  final bool isPlaying;
  final VoidCallback onTap;

  static const _cyan = Color(0xFF00F2FE);
  static const _magenta = Color(0xFFFF007F);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: _cyan.withValues(alpha: 0.35),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Radiant neon bloom
              BoxShadow(
                color: _cyan.withValues(alpha: 0.50),
                blurRadius: 22,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: _magenta.withValues(alpha: 0.45),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _cyan,
                  Color(0xFF9D00FF),
                  _magenta,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            padding: const EdgeInsets.all(2.5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.30),
                    const Color(0xFF121828).withValues(alpha: 0.88),
                    const Color(0xFF080C16).withValues(alpha: 0.96),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Upper glass specular sheen
                  Positioned(
                    top: 2,
                    child: Container(
                      width: size * 0.65,
                      height: size * 0.30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.2),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.60),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: size * 0.54,
                    shadows: [
                      Shadow(
                        color: Colors.white.withValues(alpha: 0.85),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Waveform Spectrum Seeker: undulating audio spectrum bars with a glowing
/// Cyan-to-Magenta gradient up to the current playback position.
class _NeonWaveformSeeker extends StatelessWidget {
  const _NeonWaveformSeeker({
    required this.progress,
    required this.onSeek,
  });

  final double progress;
  final ValueChanged<double> onSeek;

  // Normalized heights for 44 waveform bars matching the concept art spectrum
  static const _barHeights = <double>[
    0.25, 0.40, 0.35, 0.55, 0.75, 0.90, 0.65, 0.45,
    0.80, 1.00, 0.85, 0.60, 0.75, 0.95, 0.70, 0.50,
    0.75, 0.90, 0.65, 0.45, 0.60, 0.80, 0.95, 0.85,
    0.60, 0.75, 0.90, 0.70, 0.55, 0.85, 0.65, 0.95,
    0.80, 0.60, 0.75, 0.85, 0.65, 0.50, 0.70, 0.55,
    0.40, 0.50, 0.35, 0.20,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const h = 26.0;

        void handleTouch(double dx) {
          final p = (dx / w).clamp(0.0, 1.0);
          HapticFeedback.selectionClick();
          onSeek(p);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => handleTouch(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => handleTouch(d.localPosition.dx),
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(
              painter: _WaveformSeekerPainter(
                progress: progress,
                barHeights: _barHeights,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformSeekerPainter extends CustomPainter {
  _WaveformSeekerPainter({
    required this.progress,
    required this.barHeights,
  });

  final double progress;
  final List<double> barHeights;

  static const _cyan = Color(0xFF00F2FE);
  static const _magenta = Color(0xFFFF007F);

  @override
  void paint(Canvas canvas, Size size) {
    final count = barHeights.length;
    if (count == 0) return;

    final barWidth = (size.width / count) * 0.65;
    final spacing = size.width / count;
    final midY = size.height / 2.0;
    final progressX = size.width * progress;

    final gradientShader = const LinearGradient(
      colors: [_cyan, Color(0xFF9D00FF), _magenta],
      stops: [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0; i < count; i++) {
      final x = (i + 0.5) * spacing;
      final h = barHeights[i] * size.height;
      final isPlayed = x <= progressX;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, midY), width: barWidth, height: h),
        Radius.circular(barWidth / 2.0),
      );

      if (isPlayed) {
        // Glowing neon halo
        canvas.drawRRect(
          rect,
          Paint()
            ..shader = gradientShader
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );
        // Crisp lit core
        canvas.drawRRect(
          rect,
          Paint()..shader = gradientShader,
        );
      } else {
        // Unplayed bar
        canvas.drawRRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: 0.18),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformSeekerPainter old) =>
      old.progress != progress;
}
