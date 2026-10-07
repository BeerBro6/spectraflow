import 'package:flutter/material.dart';
import 'eq_bridge.dart' as eq_bridge;

enum AudioEngineMode {
  dspPreset,    // Pure Car DSP Unit Emulation (Pioneer, Alpine, Clarion, Rockford, Burmester, McIntosh)
  audiophileDac // Pure Audiophile Hardware DAC & Tube Emulation (NOS R2R / Linear / Min Phase + Tube Saturation + BS2B)
}

enum DacFilterMode {
  minimumPhase, // Zero pre-ringing, ultra-natural vocal attack & instrument pluck
  linearPhase,  // Maximum high-frequency extension & surgical imaging
  nosAnalog,    // Non-oversampling / R2R organic tape roll-off
}

enum TubeAmpMode {
  off,
  triode12AX7,   // Rich 2nd-order harmonic saturation (vocal warmth, acoustic body)
  pentodeEL34,   // 3rd-order harmonic presence (bite, dynamic punch, electric guitars)
}

class DexReverbProfile {
  final int code;
  final String name;
  final String description;
  final IconData icon;

  const DexReverbProfile({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
  });

  static const List<DexReverbProfile> builtInProfiles = [
    DexReverbProfile(
      code: 0,
      name: 'Dry (Off)',
      description: 'Zero reflections, dry bit-perfect studio acoustics',
      icon: Icons.power_settings_new_rounded,
    ),
    DexReverbProfile(
      code: 1,
      name: 'Studio',
      description: 'Controlled, intimate studio booth with tight early reflections',
      icon: Icons.mic_rounded,
    ),
    DexReverbProfile(
      code: 2,
      name: 'Live',
      description: 'Expansive live arena & stadium concert atmosphere',
      icon: Icons.stadium_rounded,
    ),
    DexReverbProfile(
      code: 3,
      name: 'Music',
      description: 'Warm natural acoustic balance suited for vocals and strings',
      icon: Icons.music_note_rounded,
    ),
    DexReverbProfile(
      code: 4,
      name: 'Party',
      description: 'High-energy reflections, dynamic room bounce and punch',
      icon: Icons.celebration_rounded,
    ),
    DexReverbProfile(
      code: 5,
      name: 'Small (Hall)',
      description: 'Warm recital hall acoustic decay and natural depth',
      icon: Icons.theater_comedy_rounded,
    ),
    DexReverbProfile(
      code: 6,
      name: 'Plate',
      description: 'Classic vintage bright metal plate resonance',
      icon: Icons.album_rounded,
    ),
    DexReverbProfile(
      code: 7,
      name: 'Custom',
      description: 'User customizable balanced acoustic space',
      icon: Icons.tune_rounded,
    ),
  ];
}

class LegendaryDspPreset {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final double preamp;
  final double bassBoost;
  final double virtualizer; // 0.0 to 1.0 stereo/spatial width
  final int reverbPreset;   // 0=None, 1=SmallRoom, 2=MediumRoom, 3=LargeRoom, 4=MediumHall, 5=LargeHall, 6=Plate
  final int loudnessMb;     // 0 to 1200 mB harmonic energy / Sound Retriever
  final Map<int, double> eqBands; // Frequency -> Gain dB

  const LegendaryDspPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.preamp = -1.5,
    this.bassBoost = 0.0,
    this.virtualizer = 0.0,
    this.reverbPreset = 0,
    this.loudnessMb = 0,
    required this.eqBands,
  });
}

class SpectraDacService extends ChangeNotifier {
  SpectraDacService._();
  static final SpectraDacService instance = SpectraDacService._();

  bool _isEnabled = false;
  AudioEngineMode _engineMode = AudioEngineMode.dspPreset;

  // DAC & Tube mode state
  DacFilterMode _dacFilter = DacFilterMode.minimumPhase;
  TubeAmpMode _tubeMode = TubeAmpMode.triode12AX7;
  double _tubeWarmthDrive = 0.45; // 0.0 to 1.0
  bool _bs2bCrossfeed = true;
  double _preampDb = 0.0;

  // Active DSP preset state - default to none / passthrough
  String _activePresetId = 'none';
  double _presetBassBoost = 0.0;
  double _presetVirtualizer = 0.0;
  int _presetReverb = 0;
  double _presetReverbAmount = 0.0;
  int _presetLoudnessMb = 0;

  // 10-Band ISO standard frequencies (Hz)
  static const List<int> isoFrequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

  final Map<int, double> _currentBands = {};

  bool get isEnabled => _isEnabled;
  AudioEngineMode get engineMode => _engineMode;
  DacFilterMode get dacFilter => _dacFilter;
  TubeAmpMode get tubeMode => _tubeMode;
  double get tubeWarmthDrive => _tubeWarmthDrive;
  bool get bs2bCrossfeed => _bs2bCrossfeed;
  double get preampDb => _preampDb;
  String get activePresetId => _activePresetId;
  double get presetBassBoost => _presetBassBoost;
  double get presetVirtualizer => _presetVirtualizer;
  int get presetReverb => _presetReverb;
  double get presetReverbAmount => _presetReverbAmount;
  int get presetLoudnessMb => _presetLoudnessMb;
  Map<int, double> get currentBands => Map.unmodifiable(_currentBands);

  static final List<LegendaryDspPreset> presets = [
    LegendaryDspPreset(
      id: 'pioneer_7600',
      name: 'Pioneer 7600 DSP',
      subtitle: 'Legendary Space Expand, Sound Retriever & Super-Bass',
      description: 'The real-world Pioneer acoustic signature: Space Expand early reflections, Sound Retriever harmonic restoration, and punchy V-EQ shimmer.',
      icon: Icons.disc_full_rounded,
      accentColor: const Color(0xFF00E5FF),
      preamp: -1.5,
      bassBoost: 9.0,
      virtualizer: 0.55,   // Space Expand cabin acoustic widening
      reverbPreset: 1,      // SmallRoom — car cabin early reflections
      loudnessMb: 500,      // Sound Retriever psychoacoustic restoration
      eqBands: {
        31: 7.0,
        62: 9.0,
        125: 4.0,
        250: -3.5,
        500: -1.0,
        1000: 2.0,
        2000: 3.5,
        4000: 6.0,
        8000: 8.5,
        16000: 7.0,
      },
    ),
    LegendaryDspPreset(
      id: 'alpine_f1',
      name: 'Alpine BassEngine Pro',
      subtitle: 'F#1 Status SQ Reference',
      description: 'Surgical studio imaging with zero reverb, tight acoustic damping, and BassEngine harmonic synthesis for articulated kick drums.',
      icon: Icons.speed_rounded,
      accentColor: const Color(0xFF00E676),
      preamp: 0.0,
      bassBoost: 5.0,
      virtualizer: 0.0,    // Pure direct stereo — zero widening for pinpoint accuracy
      reverbPreset: 0,     // No reverb — dry, pristine SQ
      loudnessMb: 600,     // BassEngine harmonic restoration
      eqBands: {
        31: 4.5,
        62: 5.5,
        125: 2.0,
        250: -1.5,
        500: 1.0,
        1000: 2.5,
        2000: 3.5,
        4000: 5.0,
        8000: 6.5,
        16000: 5.5,
      },
    ),
    LegendaryDspPreset(
      id: 'clarion_hxd2',
      name: 'Clarion HX-D2 Pure Analog',
      subtitle: 'Dual Burr-Brown DAC Masterpiece',
      description: 'Unprocessed direct signal path. Zero reverb, zero synthetic spatialization, zero digital enhancement — pure organic warmth.',
      icon: Icons.album_rounded,
      accentColor: const Color(0xFFFFB300),
      preamp: -1.0,
      bassBoost: 2.5,
      virtualizer: 0.0,    // Pure dual-DAC discrete stereo
      reverbPreset: 0,     // Zero reverb
      loudnessMb: 0,       // Zero processing
      eqBands: {
        31: 3.0,
        62: 4.5,
        125: 3.5,
        250: 2.0,
        500: 4.5,
        1000: 5.0,
        2000: 3.0,
        4000: 1.5,
        8000: 1.0,
        16000: 0.0,
      },
    ),
    LegendaryDspPreset(
      id: 'rockford_punch',
      name: 'Rockford Fosgate Punch EQ',
      subtitle: 'Heavy Power & Subwoofer Kick',
      description: 'Physical 45Hz subwoofer attack paired with plate transient snap. Maximum chest-thump dynamics without muddy reverb tails.',
      icon: Icons.electric_bolt_rounded,
      accentColor: const Color(0xFFFF1744),
      preamp: -2.0,
      bassBoost: 12.0,
      virtualizer: 0.40,   // Wall of sound dispersion
      reverbPreset: 6,     // Plate — snappy transient reflection, zero reverb mud
      loudnessMb: 750,     // High-energy dynamic punch
      eqBands: {
        31: 10.0,
        62: 12.0,
        125: 7.0,
        250: -2.0,
        500: -3.0,
        1000: -1.0,
        2000: 1.5,
        4000: 4.0,
        8000: 8.0,
        16000: 9.5,
      },
    ),
    LegendaryDspPreset(
      id: 'burmester_3d',
      name: 'Burmester 3D Reference',
      subtitle: 'Flagship Mercedes-Benz Luxury Soundstage',
      description: 'Immersive 3D binaural spatialization, expansive concert hall acoustic volume, and effortless, non-fatiguing high-frequency air.',
      icon: Icons.surround_sound_rounded,
      accentColor: const Color(0xFFD500F9),
      preamp: -1.0,
      bassBoost: 5.0,
      virtualizer: 0.90,   // Flagship 3D surround sound stage
      reverbPreset: 4,     // MediumHall — spacious luxury cabin acoustics
      loudnessMb: 200,     // Delicate high-detail shimmer
      eqBands: {
        31: 5.0,
        62: 6.5,
        125: 2.5,
        250: 0.0,
        500: 3.0,
        1000: 4.5,
        2000: 5.5,
        4000: 7.5,
        8000: 9.0,
        16000: 8.5,
      },
    ),
    LegendaryDspPreset(
      id: 'mcintosh_tube',
      name: 'McIntosh Blue Meter Tube',
      subtitle: 'Class-A 12AX7 Analog Staging',
      description: 'Silky vocal presence, sweet rolled-off highs, and organic 2nd-order triode warmth with intimate studio room acoustic depth.',
      icon: Icons.lightbulb_circle_rounded,
      accentColor: const Color(0xFF00B0FF),
      preamp: -1.5,
      bassBoost: 6.0,
      virtualizer: 0.50,   // Wide vintage stereo stage
      reverbPreset: 2,     // MediumRoom — warm intimate room atmosphere
      loudnessMb: 300,     // Warm harmonic energy
      eqBands: {
        31: 5.5,
        62: 7.5,
        125: 5.0,
        250: 3.5,
        500: 5.5,
        1000: 6.0,
        2000: 4.0,
        4000: 2.5,
        8000: 2.0,
        16000: 0.5,
      },
    ),
  ];

  /// Switch cleanly between DSP Preset Mode and Audiophile DAC Mode
  void setEngineMode(AudioEngineMode mode) {
    if (_engineMode == mode) return;
    _engineMode = mode;
    _syncToDsp();
    notifyListeners();
  }

  void applyPreset(LegendaryDspPreset preset) {
    if (_activePresetId == preset.id && _engineMode == AudioEngineMode.dspPreset) {
      unselectPreset();
      return;
    }
    _isEnabled = true; // Auto-enable DSP chain when a preset is explicitly selected
    _engineMode = AudioEngineMode.dspPreset; // Always switches to pure DSP mode
    _activePresetId = preset.id;
    _preampDb = preset.preamp;
    _presetBassBoost = preset.bassBoost;
    _presetVirtualizer = preset.virtualizer;
    _presetReverb = preset.reverbPreset;
    _presetReverbAmount = preset.reverbPreset > 0 ? 0.35 : 0.0;
    _presetLoudnessMb = preset.loudnessMb;

    _currentBands.clear();
    _currentBands.addAll(preset.eqBands);

    _syncToDsp();
    notifyListeners();
  }

  void unselectPreset() {
    _activePresetId = 'none';
    _preampDb = 0.0;
    _presetBassBoost = 0.0;
    _presetVirtualizer = 0.0;
    _presetReverb = 0;
    _presetReverbAmount = 0.0;
    _presetLoudnessMb = 0;
    _currentBands.clear();
    _isEnabled = false;
    eq_bridge.eqReset();
    notifyListeners();
    debugPrint('[SpectraDacService] Unselected car DSP preset -> Returned to flat reference sound');
  }

  void setBandGain(int freq, double gain) {
    _currentBands[freq] = gain;
    _activePresetId = 'custom';
    _isEnabled = true;
    _syncToDsp();
    notifyListeners();
  }

  void setTubeWarmth(TubeAmpMode mode, double drive) {
    _isEnabled = true;
    _engineMode = AudioEngineMode.audiophileDac; // Switching tube changes to DAC mode
    _tubeMode = mode;
    _tubeWarmthDrive = drive;
    _syncToDsp();
    notifyListeners();
  }

  void setDacFilter(DacFilterMode mode) {
    _isEnabled = true;
    _engineMode = AudioEngineMode.audiophileDac; // Switching filter changes to DAC mode
    _dacFilter = mode;
    _syncToDsp();
    notifyListeners();
  }

  void setReverbPreset(int presetCode) {
    _presetReverb = presetCode;
    if (presetCode == 0) {
      _presetReverbAmount = 0.0;
    } else if (_presetReverbAmount == 0.0) {
      _presetReverbAmount = 0.35;
    }
    _syncToDsp();
    notifyListeners();
  }

  void setReverbAmount(double amount) {
    _presetReverbAmount = amount.clamp(0.0, 1.0);
    if (_isEnabled && _presetReverb > 0) {
      eq_bridge.eqSetReverbAmount(_presetReverbAmount);
    }
    notifyListeners();
  }

  void setCrossfeed(bool enabled) {
    _bs2bCrossfeed = enabled;
    _syncToDsp();
    notifyListeners();
  }

  void setPreamp(double db) {
    _preampDb = db;
    _syncToDsp();
    notifyListeners();
  }

  void setEnabled(bool val) {
    _isEnabled = val;
    eq_bridge.eqSetEnabled(val);
    if (val) {
      _syncToDsp();
    } else {
      eq_bridge.eqReset();
    }
    notifyListeners();
  }

  /// Explicitly push current profile to the audio hardware DSP
  void resync() {
    _syncToDsp();
  }

  void _syncToDsp() {
    if (!_isEnabled) return;

    final List<Map<String, dynamic>> bandMaps = [];

    if (_engineMode == AudioEngineMode.dspPreset) {
      // ────────── PURE CAR DSP PRESET MODE ──────────
      // Zero DAC filtering, zero tube distortion added. Only exact preset EQ, Virtualizer, Reverb, & Loudness.
      _currentBands.forEach((freq, gain) {
        bandMaps.add({
          'frequency': freq.toDouble(),
          'gain': gain,
          'q': 1.2,
          'type': 'PK',
        });
      });

      // Calculate dynamic digital headroom compensation (Poweramp DVC safeguard).
      // If bands or bass boost have high positive gain, automatically reduce preamp to prevent clipping.
      double maxPositiveGain = 0.0;
      _currentBands.forEach((_, gain) {
        if (gain > maxPositiveGain) maxPositiveGain = gain;
      });
      if (_presetBassBoost > 0) {
        maxPositiveGain = maxPositiveGain > _presetBassBoost ? maxPositiveGain : _presetBassBoost;
      }
      final double headroomAtten = maxPositiveGain > 3.0 ? -((maxPositiveGain - 3.0) * 0.4) : 0.0;
      final double safePreamp = _preampDb + headroomAtten;

      eq_bridge.eqApplyBands(
        bandMaps,
        safePreamp,
        _presetBassBoost,
        _presetVirtualizer,
        _presetReverb,
        _presetLoudnessMb,
        _presetReverb > 0 ? _presetReverbAmount : 0.0,
      );

      debugPrint('[SpectraDacService] Applied DSP MODE: $_activePresetId | SafePreamp: $safePreamp dB (Headroom: $headroomAtten dB) | BassBoost: $_presetBassBoost dB | Virt: $_presetVirtualizer | Reverb: $_presetReverb (Amt: $_presetReverbAmount) | Loudness: $_presetLoudnessMb mB');

    } else {
      // ────────── PURE AUDIOPHILE DAC MODE ──────────
      // No car preset EQ curves. Flat reference + pure DAC filter curve & Tube saturation.
      for (final freq in isoFrequencies) {
        double gain = 0.0;

        // DAC reconstruction filter frequency curve
        if (_dacFilter == DacFilterMode.nosAnalog) {
          // Organic gentle tape roll-off on top end
          if (freq == 8000) gain -= 1.5;
          if (freq == 16000) gain -= 3.5;
          if (freq == 62 || freq == 125) gain += 1.0;
        } else if (_dacFilter == DacFilterMode.linearPhase) {
          // Flat ruler extension with micro-detail air
          if (freq >= 8000) gain += 0.5;
        } else if (_dacFilter == DacFilterMode.minimumPhase) {
          // Natural analog impulse with warm presence
          if (freq == 250 || freq == 500) gain += 0.5;
        }

        // Tube harmonics
        if (_tubeMode == TubeAmpMode.triode12AX7 && (freq == 125 || freq == 250)) {
          gain += (_tubeWarmthDrive * 2.5); // Warm vocal body
        } else if (_tubeMode == TubeAmpMode.pentodeEL34 && (freq == 1000 || freq == 2000)) {
          gain += (_tubeWarmthDrive * 2.0); // Dynamic bite
        }

        bandMaps.add({
          'frequency': freq.toDouble(),
          'gain': gain,
          'q': 1.0,
          'type': 'PK',
        });
      }

      // In DAC mode: Zero car reverb, zero synthetic loudness, virtualizer only if BS2B is on
      final double virt = _bs2bCrossfeed ? 0.35 : 0.0;
      eq_bridge.eqApplyBands(
        bandMaps,
        _preampDb,
        0.0,   // Clean bass (no boost)
        virt,  // Subtle crossfeed width
        0,     // Zero reverb in DAC mode
        0,     // Zero artificial loudness in DAC mode
        0.0,   // Zero reverb amount in DAC mode
      );

      debugPrint('[SpectraDacService] Applied DAC MODE: Filter: ${_dacFilter.name} | Tube: ${_tubeMode.name} (Drive: $_tubeWarmthDrive) | Crossfeed: $_bs2bCrossfeed');
    }
  }
}
