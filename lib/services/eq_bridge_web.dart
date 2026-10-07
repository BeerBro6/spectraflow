// Web implementation of the EQ bridge using dart:js_interop.
// Calls into window.SpectraEq (defined in web/eq_bridge.js).
// Only compiled when targeting Flutter Web.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

JSObject? _getSpectraEq() {
  final val = web.window.getProperty('SpectraEq'.toJS);
  if (val.isUndefinedOrNull) return null;
  return val as JSObject;
}

void eqInitWithSession(int? sessionId) {
  eqInit();
}

void eqInit() {
  try {
    _getSpectraEq()?.callMethod('init'.toJS);
  } catch (_) {}
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
  try {
    final eq = _getSpectraEq();
    if (eq == null) return;

    // Build JS array via JSON round-trip through jsify
    final dartList = bands
        .map((b) => <String, Object>{
              'frequency': ((b['frequency'] ?? b['freqHz'] ?? 0.0) as num).toDouble(),
              'gain': ((b['gain'] ?? b['gainDb'] ?? 0.0) as num).toDouble(),
              'q': ((b['q'] ?? 1.0) as num).toDouble(),
              'type': (b['type']?.toString() ?? 'PK'),
            })
        .toList();
    final jsVal = dartList.jsify();

    eq.callMethod('applyBands'.toJS, jsVal, preamp.toDouble().toJS);
  } catch (_) {}
}

void eqSetReverbAmount(double amount) {
  // No-op on web
}

void eqSetEnabled(bool enabled) {
  try {
    _getSpectraEq()?.callMethod('setEnabled'.toJS, enabled.toJS);
  } catch (_) {}
}

void eqReset() {
  try {
    _getSpectraEq()?.callMethod('reset'.toJS);
  } catch (_) {}
}
