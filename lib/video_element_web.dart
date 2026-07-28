// video_element_web.dart — Flutter Web only
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

/// Registers an HTML5 <video> element as a platform view for Flutter Web.
void registerVideoElement(String url, String viewId) {
  final video = html.VideoElement()
    ..src = url
    ..controls = true
    ..autoplay = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain'
    ..style.background = '#000'
    ..setAttribute('controlsList', 'nodownload')
    ..setAttribute('playsinline', 'true')
    ..setAttribute('referrerpolicy', 'no-referrer');

  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => video,
  );
}
