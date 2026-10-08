import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Reusable Liquid Glass container providing frosted glassmorphism,
/// refractive specular gradient borders, and optional ambient backlight glow.
/// Wrapped in a [RepaintBoundary] to isolate blur repaints from high-frequency
/// playback position stream ticks.
class LiquidGlassContainer extends StatelessWidget {
  final Widget? child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? tintColor;
  final double tintAlpha;
  final double? width;
  final double? height;
  final List<BoxShadow>? glowShadows;
  final bool hasSheen;
  final Border? customBorder;

  const LiquidGlassContainer({
    super.key,
    this.child,
    this.borderRadius = 22.0,
    this.padding,
    this.margin,
    this.blur = 18.0,
    this.tintColor,
    this.tintAlpha = 0.04,
    this.width,
    this.height,
    this.glowShadows,
    this.hasSheen = true,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTintColor = tintColor ?? Colors.white;
    final r = BorderRadius.circular(borderRadius);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: glowShadows,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              alignment: Alignment.center,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: r,
                border: customBorder ??
                    Border.all(
                      color: Colors.white.withValues(alpha: 0.025),
                      width: 0.5,
                    ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effectiveTintColor.withValues(alpha: tintAlpha + 0.02),
                    effectiveTintColor.withValues(alpha: (tintAlpha * 0.25).clamp(0.005, 1.0)),
                  ],
                ),
              ),
              child: hasSheen
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: r,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.035),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.35],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (child != null) Center(child: child),
                      ],
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A capsule-shaped Liquid Glass Pill, ideal for audio spec tags,
/// transport badges, and status pills.
class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final double blur;
  final VoidCallback? onTap;
  final bool isSelected;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.margin,
    this.accentColor,
    this.blur = 14.0,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? SpectraTheme.cyanWave;
    final r = BorderRadius.circular(999.0);

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: r,
                color: isSelected
                    ? color.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.05),
                border: isSelected
                    ? Border.all(
                        color: color.withValues(alpha: 0.70),
                        width: 1.0,
                      )
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// Interactive Liquid Glass Card with tap feedback.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final List<BoxShadow>? glowShadows;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 18.0,
    this.padding = const EdgeInsets.all(12.0),
    this.margin,
    this.tintColor,
    this.glowShadows,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: glowShadows,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: r,
                onTap: onTap,
                splashColor: (tintColor ?? SpectraTheme.cyanWave).withValues(alpha: 0.15),
                highlightColor: Colors.white.withValues(alpha: 0.05),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    borderRadius: r,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.02),
                      width: 0.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (tintColor ?? Colors.white).withValues(alpha: 0.05),
                        (tintColor ?? Colors.white).withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient fluid underglow backdrop: renders diffuse chromatic orbs
/// behind glass surfaces for refractive depth.
class LiquidGlassBackdrop extends StatelessWidget {
  final Color primaryOrb;
  final Color secondaryOrb;
  final Widget? child;

  const LiquidGlassBackdrop({
    super.key,
    this.primaryOrb = SpectraTheme.cyanWave,
    this.secondaryOrb = SpectraTheme.neonMagenta,
    this.child,
  });

  Widget _glowOrb(Color color, double size, [double opacity = 0.28]) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Rich deep indigo/obsidian gradient base instead of flat pitch black
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F121D),
                Color(0xFF090A11),
                Color(0xFF0D0E17),
              ],
            ),
          ),
        ),
        // Top-left luminous cyan diffuse aura
        Positioned(
          top: -40,
          left: -40,
          child: _glowOrb(primaryOrb, 440, 0.38),
        ),
        // Central-right radiant magenta / purple neon aura
        Positioned(
          top: 240,
          right: -60,
          child: _glowOrb(secondaryOrb, 420, 0.34),
        ),
        // Mid-left electric sapphire / violet aura
        Positioned(
          top: 520,
          left: -50,
          child: _glowOrb(const Color(0xFF0077B6), 380, 0.30),
        ),
        // Bottom-center luminous teal underglow for floating dock
        Positioned(
          bottom: -40,
          left: 20,
          child: _glowOrb(primaryOrb, 400, 0.32),
        ),
        // Bottom-right chromatic magenta aura
        Positioned(
          bottom: 40,
          right: -40,
          child: _glowOrb(secondaryOrb, 340, 0.28),
        ),
        ?child,
      ],
    );
  }
}
