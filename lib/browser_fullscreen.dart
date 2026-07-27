// browser_fullscreen.dart
//
// Import THIS file (not fullscreen_web.dart / fullscreen_stub.dart
// directly). Dart picks the right implementation at compile time:
// the real browser Fullscreen API on Web builds, and a harmless no-op
// everywhere else (Android/iOS/desktop), so the same watch_screen.dart
// code compiles cleanly on every platform.
export 'fullscreen_stub.dart' if (dart.library.html) 'fullscreen_web.dart';
