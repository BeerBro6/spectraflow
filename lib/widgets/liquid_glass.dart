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
    this.blur = 16.0,
    this.tintColor,
    this.tintAlpha = 0.08,
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
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: r,
                border: customBorder ??
                    Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1.0,
                    ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effectiveTintColor.withValues(alpha: tintAlpha + 0.04),
                    effectiveTintColor.withValues(alpha: (tintAlpha * 0.4).clamp(0.01, 1.0)),
                  ],
                ),
              ),
              child: hasSheen
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: r,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.center,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        ?child,
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
                    ? color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.14),
                  width: 1.0,
                ),
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
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.0,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (tintColor ?? Colors.white).withValues(alpha: 0.09),
                        (tintColor ?? Colors.white).withValues(alpha: 0.025),
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

  Widget _glowOrb(Color color, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.28),
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
        const ColoredBox(color: SpectraTheme.obsidian),
        Positioned(
          top: -140,
          left: -120,
          child: _glowOrb(primaryOrb, 440),
        ),
        Positioned(
          bottom: -160,
          right: -130,
          child: _glowOrb(secondaryOrb, 460),
        ),
        ?child,
      ],
    );
  }
}
