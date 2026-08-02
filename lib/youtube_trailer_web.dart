// youtube_trailer_web.dart — Flutter Web only
//
// Embeds YouTube trailers as a raw <iframe> (HtmlElementView). Sound is
// enabled by *reloading* the embed with mute=0 — either when the viewer's
// first page interaction fires (see [armAutoUnmute]), since unmuted autoplay
// needs a real gesture. YouTube ignores postMessage mute/unMute on plain
// embeds, which is why tap-to-unmute must reload rather than message.
//
// Captions (incl. YouTube's auto-translate subtitles) can't be suppressed by
// URL params alone, but the IFrame API's postMessage `setOption` for the
// captions track IS honoured on a plain embed (unlike mute), so
// [disableYoutubeCaptions] kills them that way.
//
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'dart:convert';

/// Keeps a handle to every registered trailer iframe so the Flutter UI can
/// postMessage commands (mute/captions) to the YouTube player once loaded.
/// Keyed by the platform-view [viewId].
final Map<String, html.IFrameElement> _trailerIframes = {};

/// Registers a YouTube embed iframe (autoplay, muted, looping, no controls/
/// branding chrome) as a platform view for Flutter Web. [youtubeVideoId] is
/// the 11-character video ID (not the full URL). [muted] picks the initial
/// audio state; browsers block unmuted autoplay without a gesture.
void registerYoutubeTrailerElement(
  String youtubeVideoId,
  String viewId, {
  bool muted = true,
}) {
  final origin = Uri.base.origin;
  final params = StringBuffer()
    ..write('autoplay=1')
    ..write('&mute=${muted ? 1 : 0}')
    ..write('&controls=0&modestbranding=1')
    ..write(muted ? '&loop=1&playlist=$youtubeVideoId' : '')
    ..write('&playsinline=1&enablejsapi=1&origin=$origin'
        '&rel=0&showinfo=0&iv_load_policy=3&cc_load_policy=0');

  final iframe = html.IFrameElement()
    ..src = 'https://www.youtube.com/embed/$youtubeVideoId?$params'
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.pointerEvents = 'none'
    ..allow = 'autoplay; encrypted-media; picture-in-picture'
    ..allowFullscreen = false;

  _trailerIframes[viewId] = iframe;
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => iframe,
  );
}

/// Disable YouTube's captions / auto-translate subtitles on a registered
/// trailer. Sent via the IFrame API postMessage protocol (enablejsapi=1 is
/// always set); `setOption` for the captions track is honoured on plain
/// embeds, unlike mute/unMute. Sent twice (now + shortly after) in case the
/// player hasn't finished initialising on the first attempt.
void disableYoutubeCaptions(String viewId) {
  final iframe = _trailerIframes[viewId];
  if (iframe == null) return;
  void send() {
    iframe.contentWindow?.postMessage(
      jsonEncode({
        'event': 'command',
        'func': 'setOption',
        'args': const ['captions', 'track', <String, dynamic>{}],
      }),
      '*',
    );
  }

  send();
  Future.delayed(const Duration(milliseconds: 1000), send);
}

/// Toggle mute on a registered trailer iframe. Kept for parity; the UI
/// currently unmutes via [armAutoUnmute] + reload instead.
void setYoutubeTrailerMute(String viewId, bool muted) {
  final iframe = _trailerIframes[viewId];
  if (iframe == null) return;
  iframe.contentWindow?.postMessage(
    jsonEncode({
      'event': 'command',
      'func': muted ? 'mute' : 'unMute',
      'args': const <dynamic>[],
    }),
    '*',
  );
}

/// Drop the stored handle for a registered trailer view so repeated unmute
/// toggles don't leak detached iframes in the map.
void disposeYoutubeTrailer(String viewId) {
  _trailerIframes.remove(viewId);
}

/// Wire a one-time document gesture listener that fires [onFirstGesture] on
/// the user's first interaction anywhere on the page. That first real
/// gesture is the user-activation browsers require for unmuted autoplay, so
/// [TrailerPlayer] reloads the embed (gesture-initiated) with sound on.
void armAutoUnmute(void Function() onFirstGesture) {
  void handler(html.Event _) {
    html.document.removeEventListener('pointerdown', handler);
    onFirstGesture();
  }

  html.document.addEventListener('pointerdown', handler);
}

/// Opens [url] in a new browser tab. Web-only — stub does nothing on native.
void openUrlInBrowser(String url) {
  html.window.open(url, '_blank');
}
