// youtube_trailer_web.dart — Flutter Web only
//
// Same conditional-import pattern as video_element_web.dart, but for
// YouTube trailers specifically: YouTube URLs can't be played by a plain
// HTML5 <video> tag (that's what video_element_web.dart is for — direct
// .mp4/embed episode sources), they need YouTube's own iframe embed player.
//
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

/// Registers a YouTube embed iframe (autoplay, muted, looping, no controls/
/// branding chrome) as a platform view for Flutter Web, for use as a
/// background trailer behind the shrunken poster on the anime detail
/// screen.
///
/// [youtubeVideoId] is just the 11-character video ID (e.g. "Iwr1aLEDpe4"),
/// not the full watch URL — see extractYoutubeId() in trailer_links.dart's
/// call site for how that's pulled out of the stored watch/short URL.
///
/// Autoplay is muted (mute=1) because browsers block unmuted autoplay
/// unless it's a direct user gesture — a background trailer that starts
/// itself as soon as the detail screen opens counts as "not a user
/// gesture" to the browser, so muted autoplay is the only version that
/// reliably starts on its own. loop=1 + playlist={id} is YouTube's
/// (slightly odd) required combo for looping a single video, since loop=1
/// alone only works for actual playlists.
void registerYoutubeTrailerElement(String youtubeVideoId, String viewId) {
  final iframe = html.IFrameElement()
    ..src = 'https://www.youtube.com/embed/$youtubeVideoId'
        '?autoplay=1&mute=1&controls=0&loop=1&playlist=$youtubeVideoId'
        '&playsinline=1&enablejsapi=1&rel=0&showinfo=0&iv_load_policy=3'
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.pointerEvents = 'none'
    ..allow = 'autoplay; encrypted-media; picture-in-picture'
    ..allowFullscreen = false;

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => iframe,
  );
}

/// Opens [url] in a new browser tab. Web-only — stub does nothing on native.
void openUrlInBrowser(String url) {
  html.window.open(url, '_blank');
}
