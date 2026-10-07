import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../services/eq_bridge.dart' as eq_bridge;
import '../theme/theme.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

enum EqPresetType { flat, carAudio, bassBoost, vocalClarity, custom }

/// Filter type used by the Web Audio API BiquadFilterNode.
/// PK = peaking bell, LSC = low shelf, HSC = high shelf.
enum EqFilterType { pk, lsc, hsc }

class EqBand {
  final double frequency;
  double gain;
  final double q;
  final String label;
  final EqFilterType filterType;

  EqBand({
    required this.frequency,
    required this.gain,
    required this.q,
    required this.label,
    this.filterType = EqFilterType.pk,
  });

  Map<String, dynamic> toJsMap() => {
        'frequency': frequency,
        'gain': gain,
        'q': q,
        'type': filterType.name.toUpperCase(), // 'PK', 'LSC', 'HSC'
      };
}

class EqPreset {
  final EqPresetType type;
  final String name;
  final String description;
  final IconData icon;
  final double preamp;
  final List<EqBand> bands;

  EqPreset({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.preamp,
    required this.bands,
  });
}

// ---------------------------------------------------------------------------
// EqService — wired to real audio processing bridge
// ---------------------------------------------------------------------------

class EqService extends ChangeNotifier {
  EqService._();
  static final EqService instance = EqService._();

  EqPreset? _currentPreset;
  bool _isEnabled = false;

  EqPreset? get currentPreset => _currentPreset;
  bool get isEnabled => _isEnabled;

  List<EqBand> customBands = [
    EqBand(frequency: 60, gain: 0, q: 0.8, label: '60Hz', filterType: EqFilterType.pk),
    EqBand(frequency: 250, gain: 0, q: 1.0, label: '250Hz', filterType: EqFilterType.pk),
    EqBand(frequency: 1000, gain: 0, q: 1.0, label: '1kHz', filterType: EqFilterType.pk),
    EqBand(frequency: 4000, gain: 0, q: 1.5, label: '4kHz', filterType: EqFilterType.pk),
    EqBand(frequency: 12000, gain: 0, q: 1.5, label: '12kHz', filterType: EqFilterType.pk),
  ];

  static List<EqPreset> get builtinPresets => [
        EqPreset(
          type: EqPresetType.flat,
          name: 'Flat',
          description: 'No EQ — pure original signal, uncoloured',
          icon: Icons.horizontal_rule_rounded,
          preamp: 0,
          bands: [
            EqBand(frequency: 60, gain: 0, q: 0.8, label: '60Hz'),
            EqBand(frequency: 250, gain: 0, q: 1.0, label: '250Hz'),
            EqBand(frequency: 1000, gain: 0, q: 1.0, label: '1kHz'),
            EqBand(frequency: 4000, gain: 0, q: 1.5, label: '4kHz'),
            EqBand(frequency: 12000, gain: 0, q: 1.5, label: '12kHz'),
          ],
        ),
        EqPreset(
          type: EqPresetType.carAudio,
          name: 'Car Audio',
          description: 'Acoustic cabin curve — overcomes vehicle road noise and cabin dampening',
          icon: Icons.directions_car_rounded,
          preamp: -1.5,
          bands: [
            EqBand(frequency: 60, gain: 7.0, q: 0.8, label: '60Hz', filterType: EqFilterType.pk),
            EqBand(frequency: 250, gain: 3.5, q: 1.0, label: '250Hz', filterType: EqFilterType.pk),
            EqBand(frequency: 1000, gain: 1.0, q: 1.0, label: '1kHz', filterType: EqFilterType.pk),
            EqBand(frequency: 4000, gain: 3.5, q: 1.5, label: '4kHz', filterType: EqFilterType.pk),
            EqBand(frequency: 12000, gain: 5.5, q: 1.5, label: '12kHz', filterType: EqFilterType.pk),
          ],
        ),
        EqPreset(
          type: EqPresetType.bassBoost,
          name: 'Bass Boost',
          description: 'Deep sub-bass & punchy low-end emphasis',
          icon: Icons.graphic_eq_rounded,
          preamp: -2.0,
          bands: [
            EqBand(frequency: 60, gain: 8.0, q: 0.8, label: '60Hz', filterType: EqFilterType.pk),
            EqBand(frequency: 250, gain: 4.0, q: 1.0, label: '250Hz', filterType: EqFilterType.pk),
            EqBand(frequency: 1000, gain: 0.0, q: 1.0, label: '1kHz', filterType: EqFilterType.pk),
            EqBand(frequency: 4000, gain: -1.0, q: 1.5, label: '4kHz', filterType: EqFilterType.pk),
            EqBand(frequency: 12000, gain: 1.0, q: 1.5, label: '12kHz', filterType: EqFilterType.pk),
          ],
        ),
        EqPreset(
          type: EqPresetType.vocalClarity,
          name: 'Vocal Clarity',
          description: 'Crisp mids & highs — vocals cut through the mix',
          icon: Icons.mic_rounded,
          preamp: -1.0,
          bands: [
            EqBand(frequency: 60, gain: -2.0, q: 0.8, label: '60Hz', filterType: EqFilterType.pk),
            EqBand(frequency: 250, gain: -1.0, q: 1.0, label: '250Hz', filterType: EqFilterType.pk),
            EqBand(frequency: 1000, gain: 3.5, q: 1.2, label: '1kHz', filterType: EqFilterType.pk),
            EqBand(frequency: 4000, gain: 6.0, q: 1.5, label: '4kHz', filterType: EqFilterType.pk),
            EqBand(frequency: 12000, gain: 4.0, q: 1.5, label: '12kHz', filterType: EqFilterType.pk),
          ],
        ),
      ];

  /// Call once after first track play to connect the Audio graph / Android Equalizer.
  void initBridge([int? sessionId]) {
    if (sessionId != null) {
      eq_bridge.eqInitWithSession(sessionId);
    } else {
      eq_bridge.eqInit();
    }
  }

  Future<void> applyPreset(EqPreset preset) async {
    _currentPreset = preset;
    _isEnabled = true;

    // Build JS-compatible band list
    final bandMaps = preset.bands.map((b) => b.toJsMap()).toList();

    if (preset.type == EqPresetType.flat) {
      // Flat: reset filter chain but keep graph connected (passthrough)
      eq_bridge.eqApplyBands([], preset.preamp);
    } else {
      eq_bridge.eqApplyBands(bandMaps, preset.preamp);
    }

    debugPrint('[EqService] "${preset.name}" applied — preamp ${preset.preamp}dB, ${preset.bands.length} bands');
    notifyListeners();
  }

  Future<void> applyCustom() async {
    final preset = EqPreset(
      type: EqPresetType.custom,
      name: 'Custom',
      description: 'Your personal EQ curve',
      icon: Icons.tune_rounded,
      preamp: 0,
      bands: List.generate(
        customBands.length,
        (i) => EqBand(
          frequency: customBands[i].frequency,
          gain: customBands[i].gain,
          q: customBands[i].q,
          label: customBands[i].label,
          filterType: customBands[i].filterType,
        ),
      ),
    );
    await applyPreset(preset);
  }

  void setEnabled(bool value) {
    _isEnabled = value;
    eq_bridge.eqSetEnabled(value);
    if (!value) _currentPreset = null;
    notifyListeners();
  }

  void resetFlat() {
    _currentPreset = null;
    _isEnabled = false;
    for (final b in customBands) {
      b.gain = 0;
    }
    eq_bridge.eqReset();
    notifyListeners();
  }

  void updateCustomBand(int index, double gain) {
    customBands[index].gain = gain;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// EQ Test Screen
// ---------------------------------------------------------------------------

class EqTestScreen extends StatefulWidget {
  final AudioPlayerService? playerService;
  const EqTestScreen({super.key, this.playerService});

  @override
  State<EqTestScreen> createState() => _EqTestScreenState();
}

class _EqTestScreenState extends State<EqTestScreen> {
  final EqService _eq = EqService.instance;
  EqPresetType _selectedType = EqPresetType.flat;

  @override
  void initState() {
    super.initState();
    _selectedType = _eq.currentPreset?.type ?? EqPresetType.flat;
    _eq.addListener(_rebuild);
    _eq.initBridge(widget.playerService?.androidAudioSessionId);
  }

  @override
  void dispose() {
    _eq.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Color _gainColor(double gain) {
    if (gain > 0) return SpectraTheme.cyanWave;
    if (gain < 0) return SpectraTheme.neonMagenta;
    return Colors.white24;
  }

  @override
  Widget build(BuildContext context) {
    final presets = EqService.builtinPresets;
    final isCustom = _selectedType == EqPresetType.custom;

    final displayBands = isCustom
        ? _eq.customBands
        : (presets
                .where((p) => p.type == _selectedType)
                .firstOrNull
                ?.bands ??
            presets.first.bands);

    return Scaffold(
      backgroundColor: SpectraTheme.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Audio EQ',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(
              kIsWeb
                  ? 'Test Mode (Browser)'
                  : 'Native — ${defaultTargetPlatform.name}',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text(
                  _eq.isEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: _eq.isEnabled
                        ? SpectraTheme.cyanWave
                        : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _eq.isEnabled,
                  activeTrackColor: SpectraTheme.cyanWave,
                  onChanged: _eq.setEnabled,
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Now playing card
          Builder(
            builder: (context) {
              final ps = widget.playerService;
              final track = ps?.currentTrack;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: SpectraTheme.darkSurface,
                      ),
                      child: const Icon(Icons.music_note_rounded,
                          color: SpectraTheme.cyanWave, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?.title ?? 'No track playing',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track?.artist ??
                                'Play a song first, then test EQ',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (_eq.currentPreset != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SpectraTheme.cyanWave
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: SpectraTheme.cyanWave
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _eq.currentPreset!.name,
                          style: const TextStyle(
                              color: SpectraTheme.cyanWave,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          const Text('PRESET',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 10),

          // Built-in preset cards
          ...presets.map((preset) => _PresetCard(
                preset: preset,
                isSelected: _selectedType == preset.type,
                onTap: () async {
                  setState(() => _selectedType = preset.type);
                  await _eq.applyPreset(preset);
                },
              )),

          // Custom card
          _CustomPresetCard(
            isSelected: isCustom,
            onTap: () => setState(() => _selectedType = EqPresetType.custom),
          ),

          const SizedBox(height: 20),

          // Band visualizer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('FREQUENCY BANDS',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        _eq.resetFlat();
                        setState(
                            () => _selectedType = EqPresetType.flat);
                      },
                      child: const Text('Reset Flat',
                          style: TextStyle(
                              color: SpectraTheme.neonMagenta,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: displayBands.asMap().entries.map((e) {
                    return _BandBar(
                      band: e.value,
                      isCustom: isCustom,
                      color: _gainColor(e.value.gain),
                      onChanged: isCustom
                          ? (val) {
                              _eq.updateCustomBand(e.key, val);
                              if (_eq.isEnabled) {
                                _eq.applyCustom();
                              }
                              setState(() {});
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Apply custom button
          if (isCustom)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpectraTheme.cyanWave,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Apply Custom EQ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await _eq.applyCustom();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Custom EQ applied ✓'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),

          const SizedBox(height: 24),

          // Platform info footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              kIsWeb
                  ? '⚗️  Browser test mode — EQ parameters logged to console.\n'
                      'Production: Android → AndroidEqualizer  |  Windows → media_kit (libmpv af filter)'
                  : '🎧  Native EQ active — ${defaultTargetPlatform.name}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PresetCard extends StatelessWidget {
  final EqPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? SpectraTheme.cyanWave.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? SpectraTheme.cyanWave.withValues(alpha: 0.55)
                : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? SpectraTheme.cyanWave.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(preset.icon,
                  color: isSelected
                      ? SpectraTheme.cyanWave
                      : Colors.white54,
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.name,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(preset.description,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: SpectraTheme.cyanWave, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CustomPresetCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomPresetCard(
      {required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = SpectraTheme.electricViolet;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.55)
                : Colors.white10,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.tune_rounded,
                  color: isSelected ? accent : Colors.white54,
                  size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Custom',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Drag each band to craft your own EQ curve',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BandBar extends StatelessWidget {
  final EqBand band;
  final bool isCustom;
  final Color color;
  final ValueChanged<double>? onChanged;

  const _BandBar({
    required this.band,
    required this.isCustom,
    required this.color,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const maxGain = 12.0;
    final normGain = (band.gain / maxGain).clamp(-1.0, 1.0);
    final barH = (normGain.abs() * 50).toDouble();

    return SizedBox(
      width: 54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${band.gain > 0 ? '+' : ''}${band.gain.toStringAsFixed(1)}',
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (isCustom)
            SizedBox(
              height: 110,
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9),
                    activeTrackColor: color,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: color,
                    overlayColor: color.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: band.gain,
                    min: -maxGain,
                    max: maxGain,
                    divisions: 48,
                    onChanged: onChanged,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Zero line
                  Positioned(
                    top: 55,
                    child: Container(
                        width: 22, height: 1, color: Colors.white24),
                  ),
                  // Gain bar
                  if (barH > 1)
                    Positioned(
                      top: normGain > 0 ? (55 - barH) : 56,
                      child: Container(
                        width: 22,
                        height: barH,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.45),
                                blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(band.label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }
}
