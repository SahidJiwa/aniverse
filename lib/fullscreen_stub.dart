// fullscreen_stub.dart
//
// No-op implementation used on Android/iOS/desktop builds, where there's
// no browser and thus no Fullscreen API to call. Real device fullscreen on
// those platforms is handled separately via SystemChrome in watch_screen.dart
// (orientation lock + immersive system UI), which works natively there.
//
// This file is selected automatically by browser_fullscreen.dart's
// conditional export whenever dart:html is NOT available.

Future<void> enterBrowserFullscreen() async {}

Future<void> exitBrowserFullscreen() async {}

bool get isBrowserFullscreen => false;

Stream<bool> get browserFullscreenChanges => const Stream<bool>.empty();
