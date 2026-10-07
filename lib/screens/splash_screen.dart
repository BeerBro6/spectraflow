// splash_screen.dart
//
// SpectraFlow splash screen — 100% faithful 1:1 implementation of
// 'SpectraFlow_Interactive_Studio.html' (and 'SpectraFlow Beam Reveal Splash.html').
//
// Stage & Row Architecture:
// The icon row is 62% of the stage width (centered at left: 19%), so that:
// 1. The incoming white beam enters from the left screen edge (left: 0, width: 19.6%)
//    and travels directly into the prism apex.
// 2. Contact flare burst occurs at left: 33.9%, top: 47.8%.
// 3. Prism glass refracts and lights up left-to-right via clip wipe.
// 4. Soft tri-color aura glow diffuses behind the prism.
// 5. Audio waveform emerges from the right edge of the prism (left: 80.6%, width: 19.4%)
//    and travels continuously all the way to the right screen edge.
// 6. Wordmark "SpectraFlow" with gradient, motto "HEAR EVERY BIT", and
//    optional personalized user name below ("Sarah ✨").

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class SpectraAnchors {
  // Screen/Row-relative horizontal fractions (where row width = 1.0)
  static const beamLeft = 0.0;
  static const beamWidth = 0.196;
  static const beamTop = 0.439; // Fraction of row height
  static const beamHeight = 0.010; // Fraction of stage

  static const iconLeft = 0.190;
  static const iconWidth = 0.620; // Exact square (height = row height)

  static const flareX = 0.339; // Fraction of row width
  static const flareY = 0.478; // Fraction of row height

  static const waveLeft = 0.806; // Fraction of row width
  static const waveWidth = 0.194; // Reaches 1.0 (screen edge)
  static const waveTop = 0.483; // Fraction of row height
  static const waveHeight = 0.034; // Fraction of stage
}

class SplashScreen extends StatefulWidget {
  final String iconAsset;
  final VoidCallback onFinished;
  final bool firstLaunch;
  final String? tagline;
  final String? userName;

  const SplashScreen({
    super.key,
    this.iconAsset = 'assets/images/logo_prism_music.png',
    required this.onFinished,
    this.firstLaunch = true,
    this.tagline,
    this.userName,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Exact intervals & cubic curves from SpectraFlow_Interactive_Studio.html:
  // 0% -> 9% : dimmed icon fade-in and scale 0.96 -> 1.0
  static const _iconFadeIn = Interval(0.00, 0.09, curve: Curves.easeOut);
  // 4% -> 18% : incoming beam draw with cubic-bezier(.4, 0, .2, 1)
  static const _beamDraw = Interval(0.04, 0.18, curve: Cubic(0.4, 0.0, 0.2, 1.0));
  // 17% -> 46% : soft background aura fade-in
  static const _auraIn = Interval(0.17, 0.46, curve: Curves.easeInOut);
  // 17% -> 46% : lit icon copy reveals left-to-right with cubic-bezier(.5, 0, .4, 1)
  static const _iconLitWipe = Interval(0.17, 0.46, curve: Cubic(0.5, 0.0, 0.4, 1.0));
  // 17% -> 21% : flare burst (scale 0.3 -> 1.5, opacity 0 -> 1)
  static const _flareBurst = Interval(0.17, 0.21, curve: Curves.easeOut);
  // 21% -> 32% : flare settle (scale 1.5 -> 1.0, opacity 1 -> 0.45)
  static const _flareSettle = Interval(0.21, 0.32, curve: Curves.easeIn);
  // 42% -> 54% : waveform draw across the right edge
  static const _waveDraw = Interval(0.42, 0.54, curve: Curves.easeOut);
  // 50% -> 62% : wordmark and tagline fade up
  static const _textIn = Interval(0.50, 0.62, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    // 3200ms for a buttery smooth cinematic reveal matching the studio preview pace
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();

    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) widget.onFinished();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Center stage matching the studio layout
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = math.min(constraints.maxWidth, 400.0);
                final rowWidth = screenWidth;
                final rowHeight = rowWidth * 0.62;

                return SizedBox(
                  width: screenWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated stage row
                      SizedBox(
                        width: rowWidth,
                        height: rowHeight,
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) {
                            final t = _c.value;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 1. Soft aura behind the icon
                                _buildAura(rowWidth, rowHeight, _auraIn.transform(t)),
                                // 2. Dimmed copy of the icon
                                _buildDimIcon(rowWidth, rowHeight, _iconFadeIn.transform(t)),
                                // 3. Lit copy of the icon revealed by clip wipe left-to-right
                                _buildLitIcon(rowWidth, rowHeight, _iconLitWipe.transform(t)),
                                // 4. White beam entering from left screen edge
                                _buildBeam(rowWidth, rowHeight, _beamDraw.transform(t)),
                                // 5. Contact flare burst and settle at prism entrance point
                                _buildFlare(
                                  rowWidth,
                                  rowHeight,
                                  _flareBurst.transform(t),
                                  _flareSettle.transform(t),
                                ),
                                // 6. Dispersed audio waveform exiting to right screen edge
                                _buildWave(rowWidth, rowHeight, _waveDraw.transform(t)),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 34),
                      // Wordmark, motto, and personalized name
                      AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) => _buildWordmark(_textIn.transform(_c.value)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 1. Soft Aura
  Widget _buildAura(double rw, double rh, double t) {
    if (t <= 0) return const SizedBox.shrink();
    final iconSize = rh;
    final iconLeft = rw * SpectraAnchors.iconLeft;

    return Positioned(
      left: iconLeft,
      top: 0,
      width: iconSize,
      height: iconSize,
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 1.25,
          child: Stack(
            children: [
              _auraSpot(const Alignment(-0.4, 0.1), const Color(0x598A5CFF), 0.65),
              _auraSpot(const Alignment(0.64, -0.04), const Color(0x4D00F2FE), 0.55),
              _auraSpot(const Alignment(0.1, 1.0), const Color(0x52FF2E93), 0.45),
            ],
          ),
        ),
      ),
    );
  }

  Widget _auraSpot(Alignment alignment, Color color, double radius) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: alignment,
            radius: radius,
            colors: [color, Colors.transparent],
            stops: const [0.0, 0.70],
          ),
        ),
      ),
    );
  }

  // 2. Dim Icon
  Widget _buildDimIcon(double rw, double rh, double t) {
    final opacity = t.clamp(0.0, 1.0);
    final scale = 0.96 + 0.04 * opacity;
    final iconSize = rh;
    final iconLeft = rw * SpectraAnchors.iconLeft;

    return Positioned(
      left: iconLeft,
      top: 0,
      width: iconSize,
      height: iconSize,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.135, 0.193, 0.022, 0, 0,
              0.057, 0.271, 0.022, 0, 0,
              0.057, 0.193, 0.100, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: Image.asset(widget.iconAsset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // 3. Lit Icon with left-to-right reveal wipe (pinned strictly to 0,0)
  Widget _buildLitIcon(double rw, double rh, double t) {
    if (t <= 0) return const SizedBox.shrink();
    final iconSize = rh;
    final iconLeft = rw * SpectraAnchors.iconLeft;
    final progress = t.clamp(0.0, 1.0);

    return Positioned(
      left: iconLeft,
      top: 0,
      width: iconSize,
      height: iconSize,
      child: ClipRect(
        clipper: _LeftToRightClipper(progress),
        child: SizedBox(
          width: iconSize,
          height: iconSize,
          child: Image.asset(widget.iconAsset, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // 4. Beam entering from screen left edge (0%) to icon edge (19.6%)
  Widget _buildBeam(double rw, double rh, double t) {
    if (t <= 0) return const SizedBox.shrink();
    final bw = rw * SpectraAnchors.beamWidth;
    const bh = 14.0; // Padded for drop shadow glow
    final top = rh * SpectraAnchors.beamTop - (bh / 2);
    final progress = t.clamp(0.0, 1.0);

    return Positioned(
      left: 0,
      top: top,
      width: bw,
      height: bh,
      child: ClipRect(
        clipper: _LeftToRightClipper(progress),
        child: CustomPaint(
          size: Size(bw, bh),
          painter: _TaperedBeamPainter(),
        ),
      ),
    );
  }

  // 5. Flare at the prism impact point (left: 33.9%, top: 47.8%)
  Widget _buildFlare(double rw, double rh, double burstT, double settleT) {
    double opacity, scale;
    if (burstT > 0 && burstT < 1.0) {
      opacity = burstT;
      scale = 0.3 + 1.2 * burstT; // 0.3 -> 1.5
    } else if (settleT > 0) {
      final s = settleT.clamp(0.0, 1.0);
      opacity = 1.0 - 0.55 * s; // 1.0 -> 0.45
      scale = 1.5 - 0.5 * s; // 1.5 -> 1.0
    } else {
      return const SizedBox.shrink();
    }

    const size = 64.0;
    final left = rw * SpectraAnchors.flareX - (size / 2);
    final top = rh * SpectraAnchors.flareY - (size / 2);

    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
              gradient: RadialGradient(
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.85),
                  const Color(0x6600F2FE),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.20, 0.45, 0.70],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 6. Waveform emerging from right edge of icon (80.6%) to screen right edge (100%)
  Widget _buildWave(double rw, double rh, double t) {
    if (t <= 0) return const SizedBox.shrink();
    final ww = rw * SpectraAnchors.waveWidth;
    const wh = 48.0; // Padded for glow
    final top = rh * SpectraAnchors.waveTop - (wh / 2);
    final progress = t.clamp(0.0, 1.0);

    return Positioned(
      left: rw * SpectraAnchors.waveLeft,
      top: top,
      width: ww,
      height: wh,
      child: ClipRect(
        clipper: _LeftToRightClipper(progress),
        child: CustomPaint(
          size: Size(ww, wh),
          painter: _WaveformSvgPainter(),
        ),
      ),
    );
  }

  // Wordmark + Motto ("HEAR EVERY BIT") + Space for User Name Below
  Widget _buildWordmark(double t) {
    final hasUserName = widget.userName != null && widget.userName!.trim().isNotEmpty;

    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1.0 - t.clamp(0.0, 1.0)) * 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF00F2FE),
                  Color(0xFF8A5CFF),
                  Color(0xFFFF2E93),
                  Colors.white,
                  Colors.white,
                ],
                stops: [0.0, 0.35, 0.60, 0.62, 1.0],
              ).createShader(bounds),
              child: const Text(
                'SpectraFlow',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.tagline ?? 'HEAR EVERY BIT',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 4.0,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            if (hasUserName) ...[
              const SizedBox(height: 6),
              Text(
                widget.userName!.trim(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: SpectraTheme.cyanWave,
                  shadows: [
                    Shadow(
                      color: SpectraTheme.cyanWave.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// CustomClipper that reveals children strictly from left to right [0.0 .. 1.0]
/// without shifting the internal alignment or image coordinates.
class _LeftToRightClipper extends CustomClipper<Rect> {
  final double progress;
  const _LeftToRightClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);
  }

  @override
  bool shouldReclip(_LeftToRightClipper oldClipper) => oldClipper.progress != progress;
}

/// CustomPainter for the tapered incoming laser beam (polygon 0 42%, 100% 0, 100% 100%, 0 58%)
/// with dual white bloom matching the CSS drop-shadows.
class _TaperedBeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Center the beam vertically inside the padded height
    const beamThickness = 6.0;
    final topOffset = (size.height - beamThickness) / 2.0;

    final path = Path()
      ..moveTo(0, topOffset + beamThickness * 0.42)
      ..lineTo(size.width, topOffset)
      ..lineTo(size.width, topOffset + beamThickness)
      ..lineTo(0, topOffset + beamThickness * 0.58)
      ..close();

    // Outer bloom glow (drop-shadow(0 0 14px rgba(255,255,255,.8)))
    final bloomPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF)],
        stops: [0.0, 0.70],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(path, bloomPaint);

    // Inner sharp beam
    final corePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00FFFFFF), Colors.white],
        stops: [0.0, 0.70],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter reproducing the SVG path from the HTML:
/// d="M0 0 L4 0 C7 -9 9 9 12 0 C15 -5 17 5 20 0 C24 -3 26 3 29 0 C33 -1.5 35 1.5 38 0 L100 0"
/// in viewBox="0 -17 100 34" with cyan outer bloom.
class _WaveformSvgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 34.0;
    final centerY = size.height / 2.0;

    final path = Path()
      ..moveTo(0 * scaleX, centerY)
      ..lineTo(4 * scaleX, centerY)
      ..cubicTo(
        7 * scaleX, centerY - 9 * scaleY,
        9 * scaleX, centerY + 9 * scaleY,
        12 * scaleX, centerY,
      )
      ..cubicTo(
        15 * scaleX, centerY - 5 * scaleY,
        17 * scaleX, centerY + 5 * scaleY,
        20 * scaleX, centerY,
      )
      ..cubicTo(
        24 * scaleX, centerY - 3 * scaleY,
        26 * scaleX, centerY + 3 * scaleY,
        29 * scaleX, centerY,
      )
      ..cubicTo(
        33 * scaleX, centerY - 1.5 * scaleY,
        35 * scaleX, centerY + 1.5 * scaleY,
        38 * scaleX, centerY,
      )
      ..lineTo(100 * scaleX, centerY);

    // Outer cyan bloom glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..shader = const LinearGradient(
        colors: [
          Color(0x997FF8FF),
          Color(0x8000F2FE),
          Color(0x0000F2FE),
        ],
        stops: [0.0, 0.60, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, glowPaint);

    // Sharp foreground waveform line
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF7FF8FF),
          Color(0xFF00F2FE),
          Color(0x0000F2FE),
        ],
        stops: [0.0, 0.60, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}