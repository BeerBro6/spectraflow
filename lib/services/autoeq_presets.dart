// lib/services/autoeq_presets.dart
//
// Accurate AutoEq / Harman Target calibration profiles for popular audiophile
// headphones & IEMs, plus parsers for GraphicEQ strings and JamesDSP .conf files.

enum AutoEqDeviceType {
  overEar,
  inEar,
  earbuds,
}

class AutoEqFilterBand {
  final double frequency; // Hz
  final double gain;      // dB
  final double q;         // Quality factor
  final String type;      // PK (peaking), LSC (low shelf), HSC (high shelf)

  const AutoEqFilterBand({
    required this.frequency,
    required this.gain,
    this.q = 1.41,
    this.type = 'PK',
  });

  Map<String, dynamic> toMap() => {
        'frequency': frequency,
        'freqHz': frequency,
        'gain': gain,
        'gainDb': gain,
        'q': q,
        'type': type,
      };
}

class AutoEqProfile {
  final String id;
  final String model;
  final String brand;
  final AutoEqDeviceType deviceType;
  final String targetCurve; // e.g. "Harman Over-Ear 2018", "Harman In-Ear 2019"
  final double recommendedPreamp; // dB attenuation to prevent digital clipping
  final List<AutoEqFilterBand> bands;
  final String description;

  const AutoEqProfile({
    required this.id,
    required this.model,
    required this.brand,
    required this.deviceType,
    required this.targetCurve,
    required this.recommendedPreamp,
    required this.bands,
    required this.description,
  });

  String get displayName => '$brand $model';
}

class AutoEqDatabase {
  static const List<AutoEqProfile> builtinProfiles = [
    // ────────── SENNHEISER ──────────
    AutoEqProfile(
      id: 'sennheiser_hd600',
      brand: 'Sennheiser',
      model: 'HD 600',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018 (Oratory1990)',
      recommendedPreamp: -6.4,
      description: 'Extends sub-bass roll-off and smooths 3.5kHz forwardness for reference studio flatness.',
      bands: [
        AutoEqFilterBand(frequency: 31, gain: 6.0, q: 0.7, type: 'LSC'),
        AutoEqFilterBand(frequency: 90, gain: 2.5, q: 1.2, type: 'PK'),
        AutoEqFilterBand(frequency: 180, gain: -1.2, q: 1.0, type: 'PK'),
        AutoEqFilterBand(frequency: 1200, gain: -1.5, q: 1.8, type: 'PK'),
        AutoEqFilterBand(frequency: 3500, gain: -2.0, q: 2.5, type: 'PK'),
        AutoEqFilterBand(frequency: 5800, gain: 2.0, q: 2.0, type: 'PK'),
        AutoEqFilterBand(frequency: 8200, gain: -1.8, q: 3.0, type: 'PK'),
        AutoEqFilterBand(frequency: 10000, gain: 1.5, q: 0.7, type: 'HSC'),
      ],
    ),
    AutoEqProfile(
      id: 'sennheiser_hd650',
      brand: 'Sennheiser',
      model: 'HD 650 / 6XX',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018 (Oratory1990)',
      recommendedPreamp: -7.0,
      description: 'Lifts deep sub-bass and brings air to the relaxed Sennheiser veil.',
      bands: [
        AutoEqFilterBand(frequency: 30, gain: 6.8, q: 0.65, type: 'LSC'),
        AutoEqFilterBand(frequency: 110, gain: -1.5, q: 1.4, type: 'PK'),
        AutoEqFilterBand(frequency: 1200, gain: -1.8, q: 1.6, type: 'PK'),
        AutoEqFilterBand(frequency: 3200, gain: -1.6, q: 2.4, type: 'PK'),
        AutoEqFilterBand(frequency: 5600, gain: 2.8, q: 2.2, type: 'PK'),
        AutoEqFilterBand(frequency: 9500, gain: 3.0, q: 1.8, type: 'PK'),
      ],
    ),
    AutoEqProfile(
      id: 'sennheiser_hd560s',
      brand: 'Sennheiser',
      model: 'HD 560S',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018',
      recommendedPreamp: -4.5,
      description: 'Tames slight 4.5kHz glare while restoring warm bass punch.',
      bands: [
        AutoEqFilterBand(frequency: 45, gain: 4.2, q: 0.8, type: 'LSC'),
        AutoEqFilterBand(frequency: 1400, gain: -1.8, q: 2.0, type: 'PK'),
        AutoEqFilterBand(frequency: 4400, gain: -3.5, q: 3.0, type: 'PK'),
        AutoEqFilterBand(frequency: 7200, gain: 1.8, q: 2.2, type: 'PK'),
      ],
    ),

    // ────────── SONY ──────────
    AutoEqProfile(
      id: 'sony_wh1000xm5',
      brand: 'Sony',
      model: 'WH-1000XM5',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018 (Rtings)',
      recommendedPreamp: -5.8,
      description: 'Cuts muddy mid-bass boom (150-300Hz), opens up vocal clarity and sparkle.',
      bands: [
        AutoEqFilterBand(frequency: 40, gain: 1.5, q: 0.8, type: 'PK'),
        AutoEqFilterBand(frequency: 180, gain: -4.8, q: 1.1, type: 'PK'),
        AutoEqFilterBand(frequency: 450, gain: -2.2, q: 1.5, type: 'PK'),
        AutoEqFilterBand(frequency: 1300, gain: 2.5, q: 1.4, type: 'PK'),
        AutoEqFilterBand(frequency: 3100, gain: 3.8, q: 1.8, type: 'PK'),
        AutoEqFilterBand(frequency: 6200, gain: -2.5, q: 2.5, type: 'PK'),
        AutoEqFilterBand(frequency: 10000, gain: 2.0, q: 0.7, type: 'HSC'),
      ],
    ),
    AutoEqProfile(
      id: 'sony_wh1000xm4',
      brand: 'Sony',
      model: 'WH-1000XM4',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018 (Oratory1990)',
      recommendedPreamp: -6.2,
      description: 'Removes thick lower-mid congestion, delivering crisp modern audiophile balance.',
      bands: [
        AutoEqFilterBand(frequency: 45, gain: 1.2, q: 0.9, type: 'PK'),
        AutoEqFilterBand(frequency: 170, gain: -5.5, q: 0.9, type: 'PK'),
        AutoEqFilterBand(frequency: 700, gain: 2.0, q: 1.5, type: 'PK'),
        AutoEqFilterBand(frequency: 2800, gain: 4.2, q: 1.6, type: 'PK'),
        AutoEqFilterBand(frequency: 6500, gain: -3.0, q: 2.2, type: 'PK'),
      ],
    ),

    // ────────── APPLE ──────────
    AutoEqProfile(
      id: 'apple_airpods_pro_2',
      brand: 'Apple',
      model: 'AirPods Pro 2',
      deviceType: AutoEqDeviceType.inEar,
      targetCurve: 'Harman In-Ear 2019 (Crinacle)',
      recommendedPreamp: -3.2,
      description: 'Refines already stellar tonal balance with deeper sub-bass extension and air.',
      bands: [
        AutoEqFilterBand(frequency: 35, gain: 2.5, q: 0.8, type: 'LSC'),
        AutoEqFilterBand(frequency: 250, gain: -1.2, q: 1.4, type: 'PK'),
        AutoEqFilterBand(frequency: 2400, gain: -1.5, q: 2.0, type: 'PK'),
        AutoEqFilterBand(frequency: 6500, gain: 2.2, q: 2.5, type: 'PK'),
        AutoEqFilterBand(frequency: 11000, gain: 2.8, q: 1.2, type: 'HSC'),
      ],
    ),
    AutoEqProfile(
      id: 'apple_airpods_max',
      brand: 'Apple',
      model: 'AirPods Max',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018 (Oratory1990)',
      recommendedPreamp: -4.0,
      description: 'Corrects upper-mid dip to bring vocal presence forward with transparent treble.',
      bands: [
        AutoEqFilterBand(frequency: 120, gain: -1.8, q: 1.2, type: 'PK'),
        AutoEqFilterBand(frequency: 2200, gain: 3.2, q: 1.4, type: 'PK'),
        AutoEqFilterBand(frequency: 4500, gain: -2.0, q: 2.2, type: 'PK'),
        AutoEqFilterBand(frequency: 7800, gain: 2.5, q: 2.0, type: 'PK'),
      ],
    ),

    // ────────── AUDIOPHILE IEMS ──────────
    AutoEqProfile(
      id: 'moondrop_blessing_3',
      brand: 'Moondrop',
      model: 'Blessing 3',
      deviceType: AutoEqDeviceType.inEar,
      targetCurve: 'Harman In-Ear 2019 (Crinacle)',
      recommendedPreamp: -3.5,
      description: 'Adds impactful sub-bass warmth to complement surgical dual-dynamic resolution.',
      bands: [
        AutoEqFilterBand(frequency: 60, gain: 3.5, q: 0.7, type: 'LSC'),
        AutoEqFilterBand(frequency: 220, gain: 1.2, q: 1.2, type: 'PK'),
        AutoEqFilterBand(frequency: 3200, gain: -1.5, q: 2.5, type: 'PK'),
        AutoEqFilterBand(frequency: 6000, gain: -2.0, q: 3.0, type: 'PK'),
      ],
    ),
    AutoEqProfile(
      id: 'moondrop_aria',
      brand: 'Moondrop',
      model: 'Aria / Chu II',
      deviceType: AutoEqDeviceType.inEar,
      targetCurve: 'Harman In-Ear 2019 (Oratory1990)',
      recommendedPreamp: -4.0,
      description: 'Tames 5.5kHz peak while tightening punchy mid-bass decay.',
      bands: [
        AutoEqFilterBand(frequency: 40, gain: 2.0, q: 0.8, type: 'PK'),
        AutoEqFilterBand(frequency: 200, gain: -1.4, q: 1.2, type: 'PK'),
        AutoEqFilterBand(frequency: 2800, gain: 1.8, q: 2.0, type: 'PK'),
        AutoEqFilterBand(frequency: 5600, gain: -3.5, q: 2.8, type: 'PK'),
        AutoEqFilterBand(frequency: 9000, gain: 2.0, q: 1.5, type: 'PK'),
      ],
    ),
    AutoEqProfile(
      id: 'crinacle_zero2',
      brand: '7Hz x Crinacle',
      model: 'Zero:2',
      deviceType: AutoEqDeviceType.inEar,
      targetCurve: 'Harman In-Ear 2019',
      recommendedPreamp: -2.5,
      description: 'Studio-flat IEM calibration with rich sub-bass rumble.',
      bands: [
        AutoEqFilterBand(frequency: 35, gain: 1.8, q: 0.7, type: 'LSC'),
        AutoEqFilterBand(frequency: 180, gain: -1.0, q: 1.2, type: 'PK'),
        AutoEqFilterBand(frequency: 4500, gain: -1.8, q: 2.4, type: 'PK'),
        AutoEqFilterBand(frequency: 8500, gain: 1.5, q: 2.0, type: 'PK'),
      ],
    ),

    // ────────── STUDIO ICONS ──────────
    AutoEqProfile(
      id: 'audiotechnica_m50x',
      brand: 'Audio-Technica',
      model: 'ATH-M50x',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018 (Oratory1990)',
      recommendedPreamp: -5.5,
      description: 'Tames V-shaped sharpness and boomy bass for accurate mixing neutrality.',
      bands: [
        AutoEqFilterBand(frequency: 45, gain: -2.5, q: 0.8, type: 'PK'),
        AutoEqFilterBand(frequency: 200, gain: -3.8, q: 1.2, type: 'PK'),
        AutoEqFilterBand(frequency: 1000, gain: 1.8, q: 1.5, type: 'PK'),
        AutoEqFilterBand(frequency: 3800, gain: -2.2, q: 2.5, type: 'PK'),
        AutoEqFilterBand(frequency: 9200, gain: -4.5, q: 2.8, type: 'PK'),
      ],
    ),
    AutoEqProfile(
      id: 'beyerdynamic_dt770',
      brand: 'Beyerdynamic',
      model: 'DT 770 Pro (80Ω)',
      deviceType: AutoEqDeviceType.overEar,
      targetCurve: 'Harman Over-Ear 2018 (Oratory1990)',
      recommendedPreamp: -6.0,
      description: 'Eliminates notorious 6kHz Beyer-peak and tightens sub-bass extension.',
      bands: [
        AutoEqFilterBand(frequency: 60, gain: -1.5, q: 0.9, type: 'PK'),
        AutoEqFilterBand(frequency: 220, gain: -2.8, q: 1.1, type: 'PK'),
        AutoEqFilterBand(frequency: 3200, gain: 3.5, q: 1.6, type: 'PK'),
        AutoEqFilterBand(frequency: 5900, gain: -5.8, q: 3.2, type: 'PK'),
        AutoEqFilterBand(frequency: 8400, gain: -2.5, q: 2.2, type: 'PK'),
      ],
    ),
  ];

  /// Find profile by ID or model name
  static AutoEqProfile? find(String query) {
    final q = query.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '').trim();
    for (final p in builtinProfiles) {
      final cleanId = p.id.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
      final cleanModel = p.model.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
      final cleanDisplay = p.displayName.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
      if (cleanId.contains(q) || cleanModel.contains(q) || cleanDisplay.contains(q)) {
        return p;
      }
    }
    return null;
  }

  /// Parses standard AutoEq GraphicEQ string:
  /// e.g. "GraphicEQ: 20 0; 25 0.5; 31.5 -1.2; 40 -2.0; 50 1.5; ..."
  static AutoEqProfile? parseGraphicEq(String text, {String name = 'Custom AutoEq'}) {
    try {
      final clean = text.replaceAll('GraphicEQ:', '').trim();
      final tokens = clean.split(';');
      final List<AutoEqFilterBand> bands = [];
      double maxPositiveGain = 0.0;

      for (final tok in tokens) {
        final parts = tok.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final freq = double.tryParse(parts[0]);
          final gain = double.tryParse(parts[1]);
          if (freq != null && gain != null && freq >= 20.0 && freq <= 20000.0) {
            bands.add(AutoEqFilterBand(
              frequency: freq,
              gain: gain,
              q: 1.41,
              type: 'PK',
            ));
            if (gain > maxPositiveGain) maxPositiveGain = gain;
          }
        }
      }

      if (bands.isEmpty) return null;

      // Recommended negative preamp to prevent clipping
      final preamp = maxPositiveGain > 0 ? -(maxPositiveGain + 0.5) : 0.0;

      return AutoEqProfile(
        id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
        model: name,
        brand: 'Imported',
        deviceType: AutoEqDeviceType.overEar,
        targetCurve: 'User GraphicEQ',
        recommendedPreamp: preamp,
        bands: bands,
        description: 'Imported from GraphicEQ string (${bands.length} points)',
      );
    } catch (_) {
      return null;
    }
  }

  /// Parses JamesDSP configuration string / .conf file
  static AutoEqProfile? parseJamesDspConf(String confText, {String name = 'JamesDSP Preset'}) {
    try {
      final lines = confText.split(RegExp(r'[\r\n]+'));

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('#') || trimmed.isEmpty) continue;

        if (trimmed.startsWith('eq_bands=') || trimmed.startsWith('graphiceq=')) {
          final eqData = trimmed.split('=')[1].trim();
          final profile = parseGraphicEq(eqData, name: name);
          if (profile != null) return profile;
        }
      }

      // If no direct graphiceq key, check if lines contain "freq gain"
      return parseGraphicEq(confText, name: name);
    } catch (_) {
      return null;
    }
  }
}
