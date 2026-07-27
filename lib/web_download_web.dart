// web_download_web.dart — Flutter Web only
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser file download via a data URL.
void triggerWebDownload(String dataUrl, String filename) {
  html.AnchorElement(href: dataUrl)
    ..setAttribute('download', filename)
    ..click();
}
