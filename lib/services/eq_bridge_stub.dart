import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Native bridge for Android and Desktop via MethodChannel
const MethodChannel _eqChannel = MethodChannel('com.spectraflow/eq');

int? _activeSessionId;

void eqInitWithSession(int? sessionId) {
  if (kIsWeb || !Platform.isAndroid || sessionId == null || sessionId == 0) return;
  _activeSessionId = sessionId;
  try {
    _eqChannel.invokeMethod('init', {'sessionId': sessionId});
  } catch (e) {
    debugPrint('[EqBridge] eqInitWithSession error: $e');
  }
}

void eqInit() {
  if (_activeSessionId != null) {
    eqInitWithSession(_activeSessionId);
  }
}

void eqApplyBands(
  List<Map<String, dynamic>> bands,
  double preamp, [
  double bassBoost = 0.0,
  double virtualizer = 0.0,
  int reverbPreset = 0,
  int loudnessMb = 0,
  double reverbAmount = 0.0,
]) {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final sanitizedBands = bands.map((b) {
      final freq = (b['frequency'] ?? b['freqHz'] ?? 0.0) as num;
      final gain = (b['gain'] ?? b['gainDb'] ?? 0.0) as num;
      final q = (b['q'] ?? 1.0) as num;
      final type = b['type']?.toString() ?? 'PK';
      return <String, dynamic>{
        'frequency': freq.toDouble(),
        'freqHz': freq.toDouble(),
        'gain': gain.toDouble(),
        'gainDb': gain.toDouble(),
        'q': q.toDouble(),
        'type': type,
      };
    }).toList();

    _eqChannel.invokeMethod('applyBands', {
      'bands': sanitizedBands,
      'preamp': preamp.toDouble(),
      'bassBoost': bassBoost.toDouble(),
      'virtualizer': virtualizer.toDouble(),
      'reverbPreset': reverbPreset.toInt(),
      'reverbAmount': reverbAmount.toDouble(),
      'loudnessMb': loudnessMb.toInt(),
    });
  } catch (e) {
    debugPrint('[EqBridge] eqApplyBands error: $e');
  }
}

void eqSetReverbAmount(double amount) {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    _eqChannel.invokeMethod('setReverbAmount', {'amount': amount.toDouble()});
  } catch (e) {
    debugPrint('[EqBridge] eqSetReverbAmount error: $e');
  }
}

void eqSetEnabled(bool enabled) {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    _eqChannel.invokeMethod('setEnabled', {'enabled': enabled});
  } catch (e) {
    debugPrint('[EqBridge] eqSetEnabled error: $e');
  }
}

void eqReset() {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    _eqChannel.invokeMethod('reset');
  } catch (e) {
    debugPrint('[EqBridge] eqReset error: $e');
  }
}

