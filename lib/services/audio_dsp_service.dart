// lib/services/audio_dsp_service.dart
//
// Centralized DSP Service managing the entire SpectraFlow audio effect chain:
// - Hardware Equalizer (Graphic & AutoEq Parametric Bands)
// - Hardware BassBoost (0 - 15 dB)
// - Stereo Spatializer / Virtualizer (0.0 - 1.0)
// - Reverb Acoustics (Studio, Live, Music, Party, Hall, Plate)
// - Loudness / Dynamic Range Enhancer (0 - 12 dB)
// - Preamp Gain & Auto-Headroom Protection
//
// Guarantees persistence across track changes, seamless rebinding on audio session ID updates,
// and real-time auditioning from any screen.

import 'package:flutter/foundation.dart';
import 'autoeq_presets.dart';
import 'eq_bridge.dart' as eq_bridge;

class AudioDspService extends ChangeNotifier {
  static final AudioDspService instance = AudioDspService._internal();

  AudioDspService._internal();

  bool _isEnabled = true;
  AutoEqProfile? _activeAutoEq;
  String _activePresetName = 'Passthrough';

  List<Map<String, dynamic>> _currentBands = [];
  double _preampDb = 0.0;
  double _bassBoostDb = 0.0;
  double _virtualizer = 0.0;
  int _reverbPreset = 0;
  // Default state is true passthrough: no bands, all effects neutral,
  // reverb wet mix at 0. The DSP system is "on" so the power toggle works,
  // but nothing modifies the audio until the user explicitly picks a
  // preset or adjusts a parameter.
  double _reverbAmount = 0.0;
  int _loudnessMb = 0;
  bool _autoHeadroom = true;
  int? _activeSessionId;

  // Getters
  bool get isEnabled => _isEnabled;
  AutoEqProfile? get activeAutoEq => _activeAutoEq;
  String get activePresetName => _activePresetName;
  int? get activeSessionId => _activeSessionId;
  List<Map<String, dynamic>> get currentBands => List.unmodifiable(_currentBands);
  double get preampDb => _preampDb;
  double get bassBoostDb => _bassBoostDb;
  double get virtualizer => _virtualizer;
  int get reverbPreset => _reverbPreset;
  double get reverbAmount => _reverbAmount;
  int get loudnessMb => _loudnessMb;
  bool get autoHeadroom => _autoHeadroom;

  double get effectivePreamp {
    if (!_autoHeadroom) return _preampDb;

    // Calculate maximum boost in bands or bass boost
    double maxBoost = 0.0;
    for (final b in _currentBands) {
      final gain = (b['gain'] ?? b['gainDb'] ?? 0.0) as num;
      if (gain > maxBoost) maxBoost = gain.toDouble();
    }
    if (_bassBoostDb > maxBoost) maxBoost = _bassBoostDb;

    final headroom = maxBoost > 2.0 ? -(maxBoost - 2.0) * 0.5 : 0.0;
    return _preampDb + headroom;
  }

  /// Rebind DSP chain to newly allocated native audio session (called on track changes)
  void rebindSession(int? sessionId) {
    if (sessionId == null || sessionId <= 0) return;
    _activeSessionId = sessionId;
    debugPrint('[AudioDspService] Rebinding session $sessionId...');
    eq_bridge.eqInitWithSession(sessionId);
    _pushToNative();
  }

  /// Master switch to enable/disable all DSP processing
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    eq_bridge.eqSetEnabled(enabled);
    if (enabled) {
      _pushToNative();
    }
    notifyListeners();
  }

  /// Apply an accurate AutoEq headphone/IEM calibration profile
  void applyAutoEq(AutoEqProfile profile) {
    _activeAutoEq = profile;
    _activePresetName = profile.displayName;
    _currentBands = profile.bands.map((b) => b.toMap()).toList();
    _preampDb = profile.recommendedPreamp;
    _pushToNative();
    notifyListeners();
    debugPrint('[AudioDspService] Applied AutoEq: "${profile.displayName}" (${_currentBands.length} bands, preamp: $_preampDb dB)');
  }

  /// Apply custom parametric/graphic bands and audio effects
  void applyCustomBands(
    List<Map<String, dynamic>> bands, {
    String presetName = 'Custom',
    double? preamp,
    double? bassBoost,
    double? virtualizer,
    int? reverbPreset,
    double? reverbAmount,
    int? loudnessMb,
  }) {
    _activeAutoEq = null;
    _activePresetName = presetName;
    _currentBands = List.from(bands);

    if (preamp != null) _preampDb = preamp;
    if (bassBoost != null) _bassBoostDb = bassBoost;
    if (virtualizer != null) _virtualizer = virtualizer;
    if (reverbPreset != null) _reverbPreset = reverbPreset;
    if (reverbAmount != null) _reverbAmount = reverbAmount;
    if (loudnessMb != null) _loudnessMb = loudnessMb;

    _pushToNative();
    notifyListeners();
  }

  /// Adjust BassBoost in real-time (0.0 to 15.0 dB)
  void setBassBoost(double db) {
    _bassBoostDb = db.clamp(0.0, 15.0);
    _pushToNative();
    notifyListeners();
  }

  /// Adjust Stereo Virtualizer / Spatializer in real-time (0.0 to 1.0)
  void setVirtualizer(double strength) {
    _virtualizer = strength.clamp(0.0, 1.0);
    _pushToNative();
    notifyListeners();
  }

  /// Adjust Reverb Profile (0=None, 1=Studio, 2=Live, 3=Music, 4=Party, 5=SmallHall, 6=Plate)
  void setReverbPreset(int preset) {
    _reverbPreset = preset.clamp(0, 7);
    _pushToNative();
    notifyListeners();
  }

  /// Adjust Reverb Intensity / Wet Mix (0.0 to 1.0)
  void setReverbAmount(double amount) {
    _reverbAmount = amount.clamp(0.0, 1.0);
    eq_bridge.eqSetReverbAmount(_reverbAmount);
    notifyListeners();
  }

  /// Adjust Loudness Enhancer (0 to 1200 mB)
  void setLoudnessMb(int mb) {
    _loudnessMb = mb.clamp(0, 1200);
    _pushToNative();
    notifyListeners();
  }

  /// Adjust Preamp gain (-12.0 to +6.0 dB)
  void setPreamp(double db) {
    _preampDb = db.clamp(-12.0, 6.0);
    _pushToNative();
    notifyListeners();
  }

  /// Toggle Auto-Headroom protection
  void setAutoHeadroom(bool autoHeadroom) {
    _autoHeadroom = autoHeadroom;
    _pushToNative();
    notifyListeners();
  }

  /// Reset to true passthrough — no bands, no effects, audio unmodified.
  /// Use this when the user wants to remove all EQ and DSP processing
  /// without disabling the DSP system entirely.
  void resetFlat() {
    _activeAutoEq = null;
    _activePresetName = 'Passthrough';
    _currentBands = [];
    _preampDb = 0.0;
    _bassBoostDb = 0.0;
    _virtualizer = 0.0;
    _reverbPreset = 0;
    _reverbAmount = 0.0;
    _loudnessMb = 0;
    eq_bridge.eqReset();
    notifyListeners();
    debugPrint('[AudioDspService] Reset to passthrough (no DSP applied)');
  }

  void _pushToNative() {
    if (!_isEnabled) {
      eq_bridge.eqSetEnabled(false);
      return;
    }
    eq_bridge.eqSetEnabled(true);
    eq_bridge.eqApplyBands(
      _currentBands,
      effectivePreamp,
      _bassBoostDb,
      _virtualizer,
      _reverbPreset,
      _loudnessMb,
      _reverbAmount,
    );
  }
}
