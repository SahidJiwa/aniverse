// youtube_trailer_stub.dart — non-web platforms
//
// Mirrors the video_element_stub.dart / video_element_web.dart pattern
// already used in watch_screen.dart for the episode player. YouTube iframe
// embedding is a browser-only concept (HtmlElementView + platformViewRegistry
// don't exist outside Flutter Web), so native builds get a no-op here and
// the trailer UI falls back to the static Ken Burns poster instead.

void registerYoutubeTrailerElement(
  String youtubeVideoId,
  String viewId, {
  bool muted = true,
}) {
  // No-op on non-web platforms.
}

/// No-op on non-web — url_launcher handles this on native.
void openUrlInBrowser(String url) {}

/// No-op on non-web — the web build posts a captions setOption command to
/// the YouTube iframe; native drives the YoutubePlayerController directly.
void disableYoutubeCaptions(String viewId) {}

/// No-op on non-web — the web build posts mute commands to the YouTube
/// iframe; native drives the YoutubePlayerController directly.
void setYoutubeTrailerMute(String viewId, bool muted) {}

/// No-op on non-web.
void disposeYoutubeTrailer(String viewId) {}

/// No-op on non-web.
void armAutoUnmute(void Function() onFirstGesture) {}
