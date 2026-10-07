// lib/ui/eq/eq_screen.dart
//
// SpectraFlow equalizer screen. Theme: Android 14 Material 3 meets cyberpunk
// studio hardware.
//   - OLED #08080C with violet/cyan ambient glow (pass album-art colors in)
//   - frosted acrylic glass panels, 1px border at 15% white
//   - cyan #00F2FE + magenta #FF2E93 spectrum for the response curve
//   - brushed-metal pre-amp knob, matte circular buttons, neon LED dots
//   - Space Grotesk for text, mono for technical readouts
//
// The live response curve is the centerpiece; the metal knob is the one
// tactile object. Everything else stays quiet.
//
// Fonts: bundle Space Grotesk and Space Mono (or Inter / JetBrains Mono) in
// pubspec.yaml and match the names in [Prism.font] / [Prism.mono]. If they
// are missing, Flutter falls back to the platform fonts.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/autoeq_presets.dart';
import '../services/audio_dsp_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme tokens
// ─────────────────────────────────────────────────────────────────────────────

class Prism {
  static const bg = Color(0xFF08080C);
  static const cyan = Color(0xFF00F2FE);
  static const magenta = Color(0xFFFF2E93);
  static const violet = Color(0xFF8B5CF6);
  static const gold = Color(0xFFFFC857); // hi-res / bit-perfect badge
  static const text = Color(0xFFF2F3FA);
  static const textDim = Color(0xFF8A8CA3);
  static const stroke = Color(0x1AFFFFFF);
  static const glassStroke = Color(0x26FFFFFF); // 15% white
  static const matteHi = Color(0xFF262631);
  static const matteLo = Color(0xFF0D0D13);

  /// Set to null or your app's theme font.
  static const String font = 'SpaceGrotesk';
  static const String mono = 'SpaceMono';

  static const spectrum = LinearGradient(colors: [cyan, violet, magenta]);
}

Color _a(Color c, double opacity) =>
    c.withAlpha((opacity * 255).round().clamp(0, 255).toInt());

TextStyle _mono({
  double size = 11,
  Color color = Prism.textDim,
  FontWeight weight = FontWeight.w500,
}) =>
    TextStyle(
      fontFamily: Prism.mono,
      fontFamilyFallback: const ['monospace'],
      fontSize: size,
      color: color,
      fontWeight: weight,
    );

String _db(double v) {
  if (v.abs() < 0.05) return '0';
  final s = v == v.roundToDouble()
      ? v.toInt().abs().toString()
      : v.abs().toStringAsFixed(1);
  return '${v > 0 ? '+' : '−'}$s';
}

String _hz(double f) {
  if (f < 1000) return f.toInt().toString();
  final k = f / 1000;
  return '${k == k.roundToDouble() ? k.toInt() : k}k';
}

// ─────────────────────────────────────────────────────────────────────────────
// Model + response math (RBJ cookbook, same maths the native processor uses)
// ─────────────────────────────────────────────────────────────────────────────

enum EqFilterType { peaking, lowShelf, highShelf, highPass, lowPass }

class EqBand {
  const EqBand(this.type, this.freqHz, this.gainDb, [this.q = 1.0]);
  final EqFilterType type;
  final double freqHz, gainDb, q;

  /// For the MethodChannel: setBands(List<Map>).
  Map<String, dynamic> toMap() => {
        'type': type.name,
        'frequency': freqHz,
        'freqHz': freqHz,
        'gain': gainDb,
        'gainDb': gainDb,
        'q': q,
      };
}

class _Coefs {
  const _Coefs(this.b0, this.b1, this.b2, this.a1, this.a2);
  final double b0, b1, b2, a1, a2;
}

_Coefs? _rbj(EqBand b, double fs) {
  if (b.freqHz >= 0.45 * fs) return null; // same Nyquist guard as the DSP
  final w0 = 2 * math.pi * b.freqHz / fs;
  final cw = math.cos(w0), sw = math.sin(w0);
  final A = math.pow(10, b.gainDb / 40).toDouble();
  final alpha = sw / (2 * b.q);
  double b0 = 1, b1 = 0, b2 = 0, a0 = 1, a1 = 0, a2 = 0;
  switch (b.type) {
    case EqFilterType.peaking:
      b0 = 1 + alpha * A;
      b1 = -2 * cw;
      b2 = 1 - alpha * A;
      a0 = 1 + alpha / A;
      a1 = -2 * cw;
      a2 = 1 - alpha / A;
    case EqFilterType.lowShelf:
      {
        final s = 2 * math.sqrt(A) * alpha;
        b0 = A * ((A + 1) - (A - 1) * cw + s);
        b1 = 2 * A * ((A - 1) - (A + 1) * cw);
        b2 = A * ((A + 1) - (A - 1) * cw - s);
        a0 = (A + 1) + (A - 1) * cw + s;
        a1 = -2 * ((A - 1) + (A + 1) * cw);
        a2 = (A + 1) + (A - 1) * cw - s;
      }
    case EqFilterType.highShelf:
      {
        final s = 2 * math.sqrt(A) * alpha;
        b0 = A * ((A + 1) + (A - 1) * cw + s);
        b1 = -2 * A * ((A - 1) + (A + 1) * cw);
        b2 = A * ((A + 1) + (A - 1) * cw - s);
        a0 = (A + 1) - (A - 1) * cw + s;
        a1 = 2 * ((A - 1) - (A + 1) * cw);
        a2 = (A + 1) - (A - 1) * cw - s;
      }
    case EqFilterType.highPass:
      b0 = (1 + cw) / 2;
      b1 = -(1 + cw);
      b2 = (1 + cw) / 2;
      a0 = 1 + alpha;
      a1 = -2 * cw;
      a2 = 1 - alpha;
    case EqFilterType.lowPass:
      b0 = (1 - cw) / 2;
      b1 = 1 - cw;
      b2 = (1 - cw) / 2;
      a0 = 1 + alpha;
      a1 = -2 * cw;
      a2 = 1 - alpha;
  }
  return _Coefs(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
}

/// Combined magnitude response (dB) of a list of biquads.
class EqResponse {
  EqResponse(List<EqBand> bands, {this.fs = 48000}) : _c = _build(bands, fs);

  final double fs;
  final List<_Coefs> _c;

  static List<_Coefs> _build(List<EqBand> bands, double fs) {
    final out = <_Coefs>[];
    for (final b in bands) {
      final c = _rbj(b, fs);
      if (c != null) out.add(c);
    }
    return out;
  }

  double db(double f) {
    final w = 2 * math.pi * f / fs;
    final c1 = math.cos(w), s1 = math.sin(w);
    final c2 = math.cos(2 * w), s2 = math.sin(2 * w);
    double total = 0;
    for (final k in _c) {
      final nr = k.b0 + k.b1 * c1 + k.b2 * c2;
      final ni = -(k.b1 * s1 + k.b2 * s2);
      final dr = 1 + k.a1 * c1 + k.a2 * c2;
      final di = -(k.a1 * s1 + k.a2 * s2);
      total += 10 * (math.log((nr * nr + ni * ni) / (dr * dr + di * di)) / math.ln10);
    }
    return total;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Presets
// ─────────────────────────────────────────────────────────────────────────────

class EqPreset {
  const EqPreset(this.id, this.name, this.bands);
  final String id, name;
  final List<EqBand> bands;
}

class EqPresets {
  /// True passthrough preset — no bands, all effects neutral. This is the
  /// default state: audio plays unmodified until the user picks a preset
  /// or adjusts a parameter.
  static const flat = EqPreset('flat', 'Passthrough', []);
  static const bassBoost = EqPreset('bass', 'Bass boost', [
    EqBand(EqFilterType.lowShelf, 90, 5, 0.71),
    EqBand(EqFilterType.peaking, 150, 2, 1.0),
  ]);
  static const vocalSmooth = EqPreset('vocal', 'Vocal smooth', [
    EqBand(EqFilterType.peaking, 1500, 1.5, 1.0),
    EqBand(EqFilterType.peaking, 4000, -2, 1.0),
    EqBand(EqFilterType.peaking, 7000, -2, 1.2),
  ]);
  static const trebleBoost = EqPreset('treble', 'Treble boost', [
    EqBand(EqFilterType.highShelf, 8000, 4, 0.71),
  ]);
  static const warm = EqPreset('warm', 'Warm', [
    EqBand(EqFilterType.lowShelf, 200, 2.5, 0.71),
    EqBand(EqFilterType.highShelf, 6000, -1.5, 0.71),
  ]);
  static const bright = EqPreset('bright', 'Bright', [
    EqBand(EqFilterType.highShelf, 5000, 3, 0.71),
    EqBand(EqFilterType.peaking, 10000, 1.5, 1.0),
  ]);
  static const loudness = EqPreset('loudness', 'Loudness', [
    EqBand(EqFilterType.lowShelf, 80, 4, 0.71),
    EqBand(EqFilterType.highShelf, 10000, 3, 0.71),
  ]);

  static const all = [flat, bassBoost, vocalSmooth, trebleBoost, warm, bright, loudness];

  static EqPreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => flat);
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller: the single object your service layer talks to
// ─────────────────────────────────────────────────────────────────────────────

class EqController extends ChangeNotifier {
  EqController({this.supported = true, this.sampleRate = 48000, this.onApply}) {
    syncFromDspService();
  }

  void syncFromDspService() {
    final dsp = AudioDspService.instance;
    bassBoostDb = dsp.bassBoostDb;
    virtualizer = dsp.virtualizer;
    reverbPreset = dsp.reverbPreset;
    reverbAmount = dsp.reverbAmount;
    loudnessMb = dsp.loudnessMb;
    preampDb = dsp.preampDb;
    enabled = dsp.isEnabled;
  }

  /// false on platforms without the DSP (e.g. Windows/iOS for now).
  final bool supported;

  /// Used only to draw the curve; the DSP recomputes per stream sample rate.
  final double sampleRate;

  /// Called after every change. Forward to your SpectraEqService:
  ///   enabled, effectiveBands (as maps), totalPreampDb.
  final void Function(EqController c)? onApply;

  static const graphicFreqs = <double>[31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
  static const fineRangeDb = 12.0;
  static const preampMin = -12.0, preampMax = 6.0;
  static const _fineQ = 1.41; // ~1 octave spacing

  bool enabled = true;
  // Default to the Passthrough preset — no bands, no effects, audio
  // unmodified until the user explicitly picks a preset or adjusts a knob.
  EqPreset preset = EqPresets.flat;
  final List<double> fine = List<double>.filled(10, 0);
  double preampDb = 0;
  double bassBoostDb = 0;
  double virtualizer = 0;
  int reverbPreset = 0;
  // Reverb wet mix starts at 0 so the default state is true passthrough.
  double reverbAmount = 0.0;
  int loudnessMb = 0;
  bool autoHeadroom = true;
  double _peakDb = 0;

  /// Preset filters + fine-tune sliders. Send this to the native processor.
  List<EqBand> get effectiveBands => [
        ...preset.bands,
        for (var i = 0; i < 10; i++)
          if (fine[i].abs() > 0.05)
            EqBand(EqFilterType.peaking, graphicFreqs[i], fine[i], _fineQ),
      ];

  double get headroomDb => autoHeadroom ? -math.max(0.0, _peakDb) : 0.0;
  double get totalPreampDb => preampDb + headroomDb;
  bool get isModified => fine.any((g) => g.abs() > 0.05);

  /// Text for the Now Playing spec badge. Reflects whether anything is
  /// actually being applied to the audio — Passthrough means the DSP
  /// system is on but no preset or effect is modifying the signal.
  String get statusLabel {
    if (!supported) return 'EQ unavailable';
    if (!enabled) return 'EQ off / bit-perfect';
    final isCleanPassthrough =
        preset.id == 'flat' && !isModified && reverbAmount < 0.01;
    return isCleanPassthrough
        ? 'EQ on / Passthrough'
        : 'EQ on / 32-bit float';
  }

  void selectPreset(EqPreset p) {
    preset = p;
    for (var i = 0; i < 10; i++) {
      fine[i] = 0;
    }
    _changed();
  }

  void selectAutoEqProfile(AutoEqProfile profile) {
    final newBands = profile.bands.map((b) {
      final t = b.type == 'LSC'
          ? EqFilterType.lowShelf
          : b.type == 'HSC'
              ? EqFilterType.highShelf
              : EqFilterType.peaking;
      return EqBand(t, b.frequency, b.gain, b.q);
    }).toList();

    preset = EqPreset(profile.id, profile.displayName, newBands);
    for (var i = 0; i < 10; i++) {
      fine[i] = 0;
    }
    preampDb = profile.recommendedPreamp;
    _changed();
  }

  void setBassBoost(double db) {
    bassBoostDb = db.clamp(0.0, 15.0).toDouble();
    _changed();
  }

  void setVirtualizer(double v) {
    virtualizer = v.clamp(0.0, 1.0).toDouble();
    _changed();
  }

  void setReverbPreset(int r) {
    if (reverbPreset == r) {
      reverbPreset = 0; // Toggle off / unselect
    } else {
      reverbPreset = r.clamp(0, 7);
    }
    _changed();
  }

  void setReverbAmount(double a) {
    reverbAmount = a.clamp(0.0, 1.0);
    AudioDspService.instance.setReverbAmount(reverbAmount);
    _changed();
  }

  void setLoudnessMb(int mb) {
    loudnessMb = mb.clamp(0, 1200);
    _changed();
  }

  void setFine(int i, double db) {
    fine[i] = db.clamp(-fineRangeDb, fineRangeDb).toDouble();
    _changed();
  }

  void setPreamp(double db) {
    preampDb = db.clamp(preampMin, preampMax).toDouble();
    _changed();
  }

  void setEnabled(bool v) {
    enabled = v;
    AudioDspService.instance.setEnabled(v);
    _changed();
  }

  void setAutoHeadroom(bool v) {
    autoHeadroom = v;
    _changed();
  }

  void reset() {
    preset = EqPresets.flat;
    for (var i = 0; i < 10; i++) {
      fine[i] = 0;
    }
    preampDb = 0;
    bassBoostDb = 0;
    virtualizer = 0;
    reverbPreset = 0;
    reverbAmount = 0.0;
    loudnessMb = 0;
    autoHeadroom = true;
    AudioDspService.instance.resetFlat();
    _changed();
  }

  // Persistence hooks (store as spectra_eq_config.json).
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'preset': preset.id,
        'fine': fine,
        'preamp': preampDb,
        'bassBoost': bassBoostDb,
        'virtualizer': virtualizer,
        'autoHeadroom': autoHeadroom,
      };

  void loadJson(Map<String, dynamic> j) {
    enabled = j['enabled'] as bool? ?? true;
    preset = EqPresets.byId(j['preset'] as String? ?? 'flat');
    final f = (j['fine'] as List?)?.cast<num>();
    for (var i = 0; i < 10; i++) {
      fine[i] = (f != null && i < f.length) ? f[i].toDouble() : 0;
    }
    preampDb = (j['preamp'] as num?)?.toDouble() ?? 0;
    bassBoostDb = (j['bassBoost'] as num?)?.toDouble() ?? 0;
    virtualizer = (j['virtualizer'] as num?)?.toDouble() ?? 0;
    autoHeadroom = j['autoHeadroom'] as bool? ?? true;
    _changed();
  }

  void _changed() {
    final r = EqResponse(effectiveBands, fs: sampleRate);
    var peak = -100.0;
    for (var i = 0; i <= 240; i++) {
      final f = 20 * math.pow(1000, i / 240).toDouble();
      peak = math.max(peak, r.db(f));
    }
    _peakDb = peak;
    if (onApply != null) {
      onApply!.call(this);
    } else {
      AudioDspService.instance.applyCustomBands(
        effectiveBands.map((b) => b.toMap()).toList(),
        presetName: preset.name,
        preamp: totalPreampDb,
        bassBoost: bassBoostDb,
        virtualizer: virtualizer,
        reverbPreset: reverbPreset,
        reverbAmount: reverbAmount,
        loudnessMb: loudnessMb,
      );
    }
    notifyListeners();
  }

  static final shared = EqController();
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class EqScreen extends StatelessWidget {
  const EqScreen({
    super.key,
    this.controller,
    this.ambientA = Prism.violet,
    this.ambientB = Prism.cyan,
  });

  final EqController? controller;

  EqController get effectiveController => controller ?? EqController.shared;

  /// Pass colors sampled from the current album art for the ambient glow.
  final Color ambientA, ambientB;

  @override
  Widget build(BuildContext context) {
    final ctrl = effectiveController;
    return Scaffold(
      backgroundColor: Prism.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _Ambient(a: ambientA, b: ambientB),
          SafeArea(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: Prism.font, color: Prism.text),
              child: ListenableBuilder(
                listenable: ctrl,
                builder: (context, _) => _EqBody(c: ctrl),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EqBody extends StatelessWidget {
  const _EqBody({required this.c});
  final EqController c;

  @override
  Widget build(BuildContext context) {
    final active = c.supported && c.enabled;
    final badgeColor = !c.supported
        ? Prism.textDim
        : c.enabled
            ? Prism.cyan
            : Prism.gold;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _MatteButton(
                size: 42,
                onTap: () => Navigator.maybePop(context),
                child: const _EmbossedIcon(Icons.arrow_back_ios_new_rounded, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Equalizer',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Prism.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SpecBadge(label: c.statusLabel, color: badgeColor),
                  ],
                ),
              ),
              if (c.supported)
                _MatteButton(
                  size: 50,
                  led: c.enabled ? Prism.cyan : null,
                  onTap: () => c.setEnabled(!c.enabled),
                  child: _EmbossedIcon(
                    Icons.power_settings_new_rounded,
                    size: 22,
                    color: c.enabled ? Prism.cyan : Prism.textDim,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          if (!c.supported)
            const _Banner(
              text: 'The equalizer runs on Android and web. '
                  'On this device your music plays untouched.',
            ),

          // Everything below dims and locks when EQ is off.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: active ? 1 : 0.4,
            child: IgnorePointer(
              ignoring: !active,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CurveCard(c: c, active: active),
                  const _Section('Genre Presets'),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: EqPresets.all.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = EqPresets.all[i];
                        return _PresetChip(
                          name: p.name,
                          selected: c.preset.id == p.id,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            c.selectPreset(p);
                          },
                        );
                      },
                    ),
                  ),
                  _Section(
                    'Headphone AutoEq / JamesDSP',
                    trailing: TextButton.icon(
                      onPressed: () => _showImportDialog(context, c),
                      icon: const Icon(Icons.file_download_outlined, size: 14, color: Prism.cyan),
                      label: Text('Import .conf', style: _mono(size: 11, color: Prism.cyan)),
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AutoEqDatabase.builtinProfiles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final profile = AutoEqDatabase.builtinProfiles[i];
                        return _AutoEqChip(
                          profile: profile,
                          selected: c.preset.id == profile.id,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            c.selectAutoEqProfile(profile);
                          },
                        );
                      },
                    ),
                  ),
                  _Section(
                    'Fine-tune (10-Band Graphic)',
                    trailing: c.isModified
                        ? Text('modified', style: _mono(color: Prism.magenta, size: 11))
                        : null,
                  ),
                  _BandsCard(c: c),
                  const _Section('Pre-amp'),
                  _PreampCard(c: c),
                  const _Section('Hardware DSP & Sound Effects'),
                  _HardwareEffectsCard(c: c),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: c.reset,
                      icon: const Icon(Icons.restart_alt_rounded,
                          size: 18, color: Prism.textDim),
                      label: const Text('Reset equalizer',
                          style: TextStyle(color: Prism.textDim)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background + glass
// ─────────────────────────────────────────────────────────────────────────────

class _Ambient extends StatelessWidget {
  const _Ambient({required this.a, required this.b});
  final Color a, b;

  Widget _glow(Color color, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [_a(color, 0.30), _a(color, 0)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Prism.bg),
        Positioned(top: -150, left: -130, child: _glow(a, 440)),
        Positioned(bottom: -170, right: -150, child: _glow(b, 480)),
      ],
    );
  }
}

/// Frosted acrylic panel: blurred backdrop, faint tint, 1px 15% white stroke.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding = EdgeInsets.zero, this.radius = 22});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Prism.glassStroke, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_a(Colors.white, 0.08), _a(Colors.white, 0.025)],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Response curve (the memorable element)
// ─────────────────────────────────────────────────────────────────────────────

class _CurveCard extends StatelessWidget {
  const _CurveCard({required this.c, required this.active});
  final EqController c;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4, bottom: 8),
            child: Row(
              children: [
                const Text('Frequency response',
                    style: TextStyle(color: Prism.textDim, fontSize: 12.5)),
                const Spacer(),
                Text('pre-amp ${_db(c.totalPreampDb)} dB',
                    style: _mono(
                      size: 11.5,
                      color: c.totalPreampDb < -0.05 ? Prism.cyan : Prism.textDim,
                      weight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1.9,
            child: CustomPaint(
              painter: EqCurvePainter(
                bands: c.effectiveBands,
                preampDb: c.totalPreampDb,
                active: active,
                fs: c.sampleRate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EqCurvePainter extends CustomPainter {
  EqCurvePainter({
    required this.bands,
    required this.preampDb,
    required this.active,
    required this.fs,
  });

  final List<EqBand> bands;
  final double preampDb, fs;
  final bool active;

  static const _range = 15.0;
  static const _gridFreqs = <double>[31, 125, 500, 2000, 8000, 16000];

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, bottom = 18.0;
    final plot = Rect.fromLTRB(left, 6, size.width - 6, size.height - bottom);

    double xOf(double f) =>
        plot.left + plot.width * (math.log(f / 20) / math.log(1000));
    double yOf(double db) =>
        plot.center.dy - (db.clamp(-_range, _range).toDouble() / _range) * (plot.height / 2);

    // Grid
    final gridPaint = Paint()
      ..color = Prism.stroke
      ..strokeWidth = 1;
    for (final f in _gridFreqs) {
      final x = xOf(f);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      _label(canvas, _hz(f), Offset(x, plot.bottom + 9), center: true);
    }
    for (final db in const [-12, -6, 0, 6, 12]) {
      final y = yOf(db.toDouble());
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        db == 0
            ? (Paint()
              ..color = _a(Colors.white, 0.24)
              ..strokeWidth = 1.2)
            : gridPaint,
      );
      _label(canvas, db == 0 ? '0' : _db(db.toDouble()), Offset(plot.left - 6, y),
          right: true);
    }

    // Curve
    final r = EqResponse(bands, fs: fs);
    const n = 220;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final f = 20 * math.pow(1000, i / n).toDouble();
      final y = yOf(active ? r.db(f) + preampDb : 0);
      final x = xOf(f);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.save();
    canvas.clipRect(plot.inflate(2));

    // Fill toward the zero line: cyan for boosts, magenta for cuts.
    final fillPath = Path.from(path)
      ..lineTo(plot.right, yOf(0))
      ..lineTo(plot.left, yOf(0))
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_a(Prism.cyan, 0.30), _a(Prism.violet, 0.03), _a(Prism.magenta, 0.30)],
          stops: const [0, 0.5, 1],
        ).createShader(plot),
    );

    final lineColors = active
        ? const [Prism.cyan, Prism.violet, Prism.magenta]
        : const [Prism.textDim, Prism.textDim];
    final lineShader = LinearGradient(colors: lineColors).createShader(plot);
    final glowShader =
        LinearGradient(colors: [for (final c in lineColors) _a(c, 0.55)]).createShader(plot);

    // Neon glow trail, then the crisp line.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..shader = glowShader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = lineShader,
    );
    canvas.restore();
  }

  void _label(Canvas c, String s, Offset o, {bool center = false, bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: _mono(size: 9.5, weight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? o.dx - tp.width / 2 : (right ? o.dx - tp.width : o.dx);
    tp.paint(c, Offset(dx, o.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant EqCurvePainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Presets
// ─────────────────────────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [selected ? Prism.matteHi : const Color(0xFF1A1A23), Prism.matteLo],
          ),
          border: Border.all(color: selected ? _a(Prism.cyan, 0.6) : Prism.stroke),
          boxShadow: selected
              ? [BoxShadow(color: _a(Prism.cyan, 0.20), blurRadius: 14)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Led(on: selected),
            const SizedBox(width: 9),
            Text(
              name,
              style: TextStyle(
                color: selected ? Prism.text : Prism.textDim,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoEqChip extends StatelessWidget {
  const _AutoEqChip({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final AutoEqProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = profile.deviceType == AutoEqDeviceType.inEar
        ? Icons.headphones_battery_rounded
        : Icons.headphones_rounded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [selected ? Prism.matteHi : const Color(0xFF1A1A23), Prism.matteLo],
          ),
          border: Border.all(color: selected ? _a(Prism.cyan, 0.7) : Prism.stroke),
          boxShadow: selected
              ? [BoxShadow(color: _a(Prism.cyan, 0.22), blurRadius: 14)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Prism.cyan : Prism.textDim),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: TextStyle(
                    color: selected ? Prism.text : Prism.textDim,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  '${profile.targetCurve.split(' ')[0]} • ${profile.bands.length} bands',
                  style: TextStyle(
                    color: selected ? Prism.cyan : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showImportDialog(BuildContext context, EqController c) {
  final textCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF131722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: Row(
        children: [
          const Icon(Icons.auto_fix_high_rounded, color: Prism.cyan, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Import DSP / AutoEq',
            style: TextStyle(color: Prism.text, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste any AutoEq "GraphicEQ:" string or JamesDSP configuration lines below:',
            style: TextStyle(color: Prism.textDim, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: textCtrl,
            maxLines: 5,
            style: _mono(size: 12, color: Prism.text),
            decoration: InputDecoration(
              hintText: 'GraphicEQ: 20 0; 25 0.5; 31.5 -1.2; ...\nOr preamp=0.0\neq_bands=...',
              hintStyle: _mono(size: 11, color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF0A0C12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Prism.cyan),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: Prism.textDim)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Prism.cyan,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final text = textCtrl.text.trim();
            if (text.isNotEmpty) {
              final profile = AutoEqDatabase.parseJamesDspConf(text) ??
                  AutoEqDatabase.parseGraphicEq(text);
              if (profile != null) {
                c.selectAutoEqProfile(profile);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Applied "${profile.displayName}" (${profile.bands.length} points)'),
                    backgroundColor: const Color(0xFF131722),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid format. Please supply "GraphicEQ: freq gain; ..." or JamesDSP lines.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          },
          child: const Text('Apply Preset', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

class _HardwareEffectsCard extends StatelessWidget {
  const _HardwareEffectsCard({required this.c});
  final EqController c;

  static const _reverbNames = [
    'Dry (Off)',
    'Studio',
    'Live Hall',
    'Music',
    'Club',
    'Small Hall',
    'Plate',
  ];

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bass Boost slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.speaker_rounded, size: 18, color: Prism.cyan),
                  SizedBox(width: 8),
                  Text('Hardware Bass Boost', style: TextStyle(color: Prism.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(
                c.bassBoostDb > 0 ? '+${c.bassBoostDb.toStringAsFixed(1)} dB' : 'Off',
                style: _mono(size: 12, color: c.bassBoostDb > 0 ? Prism.cyan : Prism.textDim),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Prism.cyan,
              inactiveTrackColor: Colors.white12,
              thumbColor: Prism.cyan,
              overlayColor: Prism.cyan.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: c.bassBoostDb,
              min: 0.0,
              max: 15.0,
              divisions: 30,
              onChanged: (val) => c.setBassBoost(val),
            ),
          ),
          const SizedBox(height: 8),

          // Stereo 3D Virtualizer slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.surround_sound_rounded, size: 18, color: Prism.violet),
                  SizedBox(width: 8),
                  Text('3D Spatializer / Virtualizer', style: TextStyle(color: Prism.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(
                c.virtualizer > 0 ? '${(c.virtualizer * 100).toInt()}%' : 'Off',
                style: _mono(size: 12, color: c.virtualizer > 0 ? Prism.violet : Prism.textDim),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Prism.violet,
              inactiveTrackColor: Colors.white12,
              thumbColor: Prism.violet,
              overlayColor: Prism.violet.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: c.virtualizer,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (val) => c.setVirtualizer(val),
            ),
          ),
          const SizedBox(height: 12),

          // Reverb selector
          const Text('Acoustic Reverb Space', style: TextStyle(color: Prism.textDim, fontSize: 12.5)),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _reverbNames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final isSelected = c.reverbPreset == i;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    c.setReverbPreset(i);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? Prism.cyan.withValues(alpha: 0.2) : const Color(0xFF161821),
                      border: Border.all(
                        color: isSelected ? Prism.cyan : Colors.white10,
                      ),
                    ),
                    child: Text(
                      _reverbNames[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Prism.cyan : Prism.textDim,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Reverb Wet / Mix Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.waves_rounded,
                    size: 18,
                    color: c.reverbPreset > 0 ? Prism.cyan : Prism.textDim,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reverb Level / Wet Mix',
                    style: TextStyle(
                      color: c.reverbPreset > 0 ? Prism.text : Prism.textDim,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.reverbPreset > 0
                      ? Prism.cyan.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  c.reverbPreset > 0
                      ? '${(c.reverbAmount * 100).toInt()}%'
                      : 'Off',
                  style: _mono(
                    size: 12,
                    color: c.reverbPreset > 0 ? Prism.cyan : Prism.textDim,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.reverbPreset > 0 ? Prism.cyan : Colors.white24,
              inactiveTrackColor: Colors.white12,
              thumbColor: c.reverbPreset > 0 ? Prism.cyan : Colors.white38,
              overlayColor: Prism.cyan.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: c.reverbPreset > 0 ? c.reverbAmount : 0.0,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: c.reverbPreset > 0
                  ? (val) => c.setReverbAmount(val)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fine-tune sliders (hardware-style faders)
// ─────────────────────────────────────────────────────────────────────────────

class _BandsCard extends StatelessWidget {
  const _BandsCard({required this.c});
  final EqController c;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 254,
      child: _Glass(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        child: Row(
          children: [
            for (var i = 0; i < 10; i++)
              Expanded(
                child: _BandSlider(
                  value: c.fine[i],
                  label: _hz(EqController.graphicFreqs[i]),
                  onChanged: (v) => c.setFine(i, v),
                  onReset: () => c.setFine(i, 0),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onReset,
  });

  final double value;
  final String label;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  static const _pad = 12.0;

  @override
  Widget build(BuildContext context) {
    final valueColor = value.abs() < 0.05
        ? Prism.textDim
        : (value > 0 ? Prism.cyan : Prism.magenta);
    return Column(
      children: [
        SizedBox(
          height: 16,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_db(value),
                style: _mono(size: 11, color: valueColor, weight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, cons) {
              final h = cons.maxHeight;
              void update(double dy) {
                final t = ((dy - _pad) / (h - 2 * _pad)).clamp(0.0, 1.0).toDouble();
                final raw = (0.5 - t) * 2 * EqController.fineRangeDb;
                final snapped = (raw * 2).round() / 2; // 0.5 dB steps
                if (snapped != value) {
                  if (snapped == 0) HapticFeedback.selectionClick();
                  onChanged(snapped);
                }
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => update(d.localPosition.dy),
                onVerticalDragUpdate: (d) => update(d.localPosition.dy),
                onDoubleTap: onReset,
                child: SizedBox.expand(
                  child: CustomPaint(
                      painter: _BandPainter(value, EqController.fineRangeDb)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: _mono(size: 10.5)),
      ],
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter(this.value, this.range);
  final double value, range;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = _BandSlider._pad;
    final cx = size.width / 2;
    final top = pad, bottom = size.height - pad, mid = (top + bottom) / 2;
    final y = mid - (value / range) * ((bottom - top) / 2);
    final zero = value.abs() < 0.05;
    final color = zero ? Prism.textDim : (value > 0 ? Prism.cyan : Prism.magenta);

    // Recessed track
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 2.5, top, cx + 2.5, bottom, const Radius.circular(2.5)),
      Paint()..color = _a(Colors.black, 0.55),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(cx - 2.5, top, cx + 2.5, bottom, const Radius.circular(2.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _a(Colors.white, 0.12),
    );
    // Zero tick
    canvas.drawLine(
      Offset(cx - 9, mid),
      Offset(cx + 9, mid),
      Paint()
        ..color = _a(Colors.white, 0.28)
        ..strokeWidth = 1.2,
    );
    // Lit segment from zero to thumb
    if (!zero) {
      final rect = Rect.fromLTRB(cx - 2, math.min(y, mid), cx + 2, math.max(y, mid));
      canvas.drawRect(
        rect,
        Paint()
          ..color = _a(color, 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = color,
      );
    }
    // Matte thumb with inner bevel and LED core
    final o = Offset(cx, y);
    canvas.drawCircle(
      o + const Offset(0, 3),
      10,
      Paint()
        ..color = _a(Colors.black, 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      o,
      10,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [Prism.matteHi, Prism.matteLo],
        ).createShader(Rect.fromCircle(center: o, radius: 10)),
    );
    canvas.drawCircle(
      o,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _a(Colors.white, 0.22),
    );
    canvas.drawCircle(
      o,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _a(Colors.black, 0.6),
    );
    if (!zero) {
      canvas.drawCircle(
        o,
        4,
        Paint()
          ..color = _a(color, 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    canvas.drawCircle(o, 2.4, Paint()..color = zero ? _a(Colors.white, 0.45) : color);
  }

  @override
  bool shouldRepaint(covariant _BandPainter old) => old.value != value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pre-amp: brushed-metal knob with an LED ring
// ─────────────────────────────────────────────────────────────────────────────

class _PreampCard extends StatelessWidget {
  const _PreampCard({required this.c});
  final EqController c;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              _MetalKnob(
                value: c.preampDb,
                min: EqController.preampMin,
                max: EqController.preampMax,
                onChanged: c.setPreamp,
                onReset: () => c.setPreamp(0),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gain',
                        style: TextStyle(color: Prism.textDim, fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text('${_db(c.preampDb)} dB',
                        style: _mono(
                            size: 28, color: Prism.text, weight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text('Output ${_db(c.totalPreampDb)} dB',
                        style: _mono(size: 12, color: Prism.cyan)),
                    const SizedBox(height: 10),
                    const Text('Drag the knob. Double-tap for 0 dB.',
                        style: TextStyle(
                            color: Prism.textDim, fontSize: 11.5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Prism.stroke, height: 28),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Auto headroom',
                        style: TextStyle(color: Prism.text, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      c.autoHeadroom
                          ? 'Lowering volume by ${c.headroomDb.abs().toStringAsFixed(1)} dB so boosts never clip'
                          : 'Off: strong boosts can clip on loud tracks',
                      style: const TextStyle(color: Prism.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _LedToggle(value: c.autoHeadroom, onChanged: c.setAutoHeadroom),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetalKnob extends StatefulWidget {
  const _MetalKnob({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onReset,
  });

  static const double size = 136;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  State<_MetalKnob> createState() => _MetalKnobState();
}

class _MetalKnobState extends State<_MetalKnob> {
  double _acc = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _acc = widget.value,
      onPanUpdate: (d) {
        final span = widget.max - widget.min;
        // Drag up or right to turn clockwise. ~200 px covers the full range.
        _acc = (_acc + (-d.delta.dy + d.delta.dx) * span / 200)
            .clamp(widget.min, widget.max)
            .toDouble();
        final snapped = (_acc * 2).round() / 2; // 0.5 dB steps
        if (snapped != widget.value) {
          if (snapped == snapped.roundToDouble()) HapticFeedback.selectionClick();
          widget.onChanged(snapped);
        }
      },
      onDoubleTap: widget.onReset,
      child: SizedBox(
        width: _MetalKnob.size,
        height: _MetalKnob.size,
        child: CustomPaint(
          painter: _KnobPainter(widget.value, widget.min, widget.max),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter(this.value, this.min, this.max);
  final double value, min, max;

  // 270-degree sweep from bottom-left, over the top, to bottom-right.
  static double _angle(double t) => 3 * math.pi / 4 + t * 3 * math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ringR = size.width / 2 - 8;
    final r = size.width / 2 - 26;
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();

    // LED ring: one dot per dB, lit up to the current value.
    const n = 19;
    final unityIndex = (((0 - min) / (max - min)) * (n - 1)).round();
    for (var i = 0; i < n; i++) {
      final ti = i / (n - 1);
      final a = _angle(ti);
      final p = c + Offset(math.cos(a), math.sin(a)) * ringR;
      final lit = ti <= t + 1e-6;
      final isUnity = i == unityIndex;
      if (lit) {
        canvas.drawCircle(
          p,
          5,
          Paint()
            ..color = _a(Prism.cyan, 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawCircle(
        p,
        isUnity ? 3.1 : 2.3,
        Paint()
          ..color = lit
              ? Prism.cyan
              : _a(Colors.white, isUnity ? 0.38 : 0.14),
      );
    }

    // Body shadow + bezel
    canvas.drawCircle(
      c + const Offset(0, 6),
      r + 3,
      Paint()
        ..color = _a(Colors.black, 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      c,
      r + 4,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3C3D47), Color(0xFF0A0A0F)],
        ).createShader(Rect.fromCircle(center: c, radius: r + 4)),
    );

    // Brushed-metal face: conic sheen + fine concentric grain.
    final face = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF9EA0AC),
            Color(0xFF383944),
            Color(0xFFBDBFCB),
            Color(0xFF2C2D36),
            Color(0xFFA4A6B2),
            Color(0xFF383944),
            Color(0xFF9EA0AC),
          ],
        ).createShader(face),
    );
    for (var k = 1; k <= 22; k++) {
      canvas.drawCircle(
        c,
        r * k / 23,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = k.isEven ? _a(Colors.white, 0.07) : _a(Colors.black, 0.12),
      );
    }
    // Soft top-left highlight
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 0.9,
          colors: [_a(Colors.white, 0.22), _a(Colors.white, 0)],
        ).createShader(face),
    );
    // Edge bevel
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _a(Colors.black, 0.55),
    );
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _a(Colors.white, 0.18),
    );

    // Illuminated indicator line
    final a = _angle(t);
    final dir = Offset(math.cos(a), math.sin(a));
    final p0 = c + dir * (r * 0.42);
    final p1 = c + dir * (r - 7);
    canvas.drawLine(
      p0,
      p1,
      Paint()
        ..color = _a(Prism.cyan, 0.9)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      p0,
      p1,
      Paint()
        ..color = Prism.cyan
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _KnobPainter old) => old.value != value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared pieces
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Prism.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Mono audio-spec badge, like the "FLAC 24-bit / 96kHz Lossless" pill.
class _SpecBadge extends StatelessWidget {
  const _SpecBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _a(color, 0.08),
        border: Border.all(color: _a(color, 0.40)),
      ),
      child: Text(label, style: _mono(size: 11, color: color, weight: FontWeight.w600)),
    );
  }
}

class _Led extends StatelessWidget {
  const _Led({required this.on, this.color = Prism.cyan, this.size = 6});
  final bool on;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? color : _a(Colors.white, 0.16),
        boxShadow: on ? [BoxShadow(color: _a(color, 0.85), blurRadius: 8)] : null,
      ),
    );
  }
}

class _EmbossedIcon extends StatelessWidget {
  const _EmbossedIcon(this.icon, {this.size = 20, this.color = Prism.textDim});
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      shadows: [
        Shadow(color: _a(Colors.white, 0.14), offset: const Offset(0, 1)),
        Shadow(color: _a(Colors.black, 0.85), offset: const Offset(0, -1)),
      ],
    );
  }
}

/// Circular matte button with an inner bevel and an optional LED dot.
class _MatteButton extends StatelessWidget {
  const _MatteButton({
    required this.child,
    required this.onTap,
    this.size = 44,
    this.led,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final Color? led;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.45),
            colors: [Prism.matteHi, Prism.matteLo],
          ),
          border: Border.all(color: _a(Colors.white, 0.10)),
          boxShadow: [
            BoxShadow(
                color: _a(Colors.black, 0.6), blurRadius: 10, offset: const Offset(0, 4)),
            if (led != null) BoxShadow(color: _a(led!, 0.26), blurRadius: 16),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _a(Colors.black, 0.55)),
              ),
            ),
            child,
            if (led != null)
              Positioned(top: 5, child: _Led(on: true, color: led!, size: 4)),
          ],
        ),
      ),
    );
  }
}

class _LedToggle extends StatelessWidget {
  const _LedToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: _a(Colors.black, 0.55),
          border: Border.all(color: value ? _a(Prism.cyan, 0.5) : Prism.stroke),
          boxShadow:
              value ? [BoxShadow(color: _a(Prism.cyan, 0.22), blurRadius: 12)] : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.3, -0.45),
                colors: [Prism.matteHi, Prism.matteLo],
              ),
              border: Border.all(color: _a(Colors.white, 0.18)),
            ),
            child: _Led(on: value, size: 6),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _Glass(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Prism.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: Prism.text, fontSize: 13, height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}
