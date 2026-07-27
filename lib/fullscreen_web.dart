// fullscreen_web.dart
//
// Real Fullscreen API implementation for Flutter Web. SystemChrome (used
// for native Android/iOS fullscreen) has no effect in a browser tab — the
// browser itself owns the concept of "fullscreen", so we have to call its
// actual Fullscreen API via dart:html instead.
//
// This file is selected automatically by browser_fullscreen.dart's
// conditional export whenever dart:library.html is available (web builds).

import 'dart:async';
import 'dart:html' as html;

final StreamController<bool> _fullscreenController =
    StreamController<bool>.broadcast();
bool _listenerAttached = false;

// Browsers fire fullscreenchange not just when OUR button is pressed, but
// also when the user exits via the browser's own UI (Esc key, F11, etc) —
// this listener is what keeps our UI's "is fullscreen" state in sync with
// reality in that case, instead of only trusting our own button taps.
void _ensureListener() {
  if (_listenerAttached) return;
  _listenerAttached = true;
  html.document.onFullscreenChange.listen((_) {
    _fullscreenController.add(html.document.fullscreenElement != null);
  });
}

Future<void> enterBrowserFullscreen() async {
  html.document.documentElement?.requestFullscreen();
}

Future<void> exitBrowserFullscreen() async {
  if (html.document.fullscreenElement != null) {
    html.document.exitFullscreen();
  }
}

bool get isBrowserFullscreen => html.document.fullscreenElement != null;

Stream<bool> get browserFullscreenChanges {
  _ensureListener();
  return _fullscreenController.stream;
}
