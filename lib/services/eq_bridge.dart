// Conditional import: routes to web implementation on Flutter Web,
// and the no-op stub on Android / Windows / other native targets.
export 'eq_bridge_stub.dart'
    if (dart.library.html) 'eq_bridge_web.dart';
