// video_element_web.dart — Flutter Web only
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Registers an HTML5 <video> element as a platform view for Flutter Web.
///
/// Supports both direct MP4/WebM (plain <video src>) and HLS (.m3u8) streams
/// via hls.js (loaded in web/index.html). Native HLS (Safari/iOS) is used when
/// available; otherwise hls.js handles the playlist.
void registerVideoElement(String url, String viewId) {
  final video = html.VideoElement()
    ..controls = true
    ..autoplay = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain'
    ..style.background = '#000'
    ..setAttribute('controlsList', 'nodownload')
    ..setAttribute('playsinline', 'true')
    ..setAttribute('referrerpolicy', 'no-referrer');

  final isHls = url.contains('.m3u8');

  if (isHls) {
    // Defer HLS attach until the element is in the DOM, so hls.js can bind to it.
    video.onLoadedMetadata.listen((_) {});
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        // Give Flutter a frame to mount the element, then attach HLS.
        Future.delayed(const Duration(milliseconds: 50), () {
          _attachHls(video, url);
        });
        return video;
      },
    );
  } else {
    video.src = url;
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => video,
    );
  }
}

/// Calls the global helper defined in web/index.html (window.__aniverseAttachHls)
/// to wire up hls.js. Kept in Dart so we don't need allowInterop (unavailable
/// in this Flutter/Dart version).
void _attachHls(html.VideoElement video, String url) {
  try {
    final fn = js.context['__aniverseAttachHls'];
    if (fn != null) {
      fn(video, url);
    } else {
      // Fallback: native HLS (Safari/iOS) or nothing.
      video.src = url;
    }
  } catch (_) {
    try {
      video.src = url;
    } catch (_) {}
  }
}
