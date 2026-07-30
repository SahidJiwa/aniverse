// trailer_player.dart — AniVerse trailer background player
//
// Web: wraps the YouTube-embed platform view (youtube_trailer_web.dart /
// youtube_trailer_stub.dart, mirroring watch_screen.dart's existing
// video_element_web.dart / video_element_stub.dart split).
// Native (Android/iOS): youtube_player_flutter's WebView-backed player,
// since dart:html/HtmlElementView don't exist outside Flutter Web — that's
// why the trailer never played on the Android build even though it worked
// fine on web.
// Both paths share the URL -> video-ID extraction below.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'youtube_trailer_stub.dart'
    if (dart.library.html) 'youtube_trailer_web.dart';

/// Pulls the 11-character YouTube video ID out of any of the URL shapes
/// trailer_links.dart stores ("https://youtu.be/ID", "https://
/// www.youtube.com/watch?v=ID", or an embed URL that already just has the
/// ID at the end). Returns null if the URL doesn't look like a YouTube
/// link at all, so callers can fall back to the static poster instead of
/// trying to embed something that isn't YouTube.
String? extractYoutubeId(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;

  // youtu.be/VIDEOID — the whole path (minus leading slash) is the id.
  if (uri.host.contains('youtu.be')) {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return (id != null && id.isNotEmpty) ? id : null;
  }

  // youtube.com/watch?v=VIDEOID
  if (uri.host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;

    // youtube.com/embed/VIDEOID or youtube.com/shorts/VIDEOID — id is the
    // last path segment.
    if (uri.pathSegments.isNotEmpty &&
        (uri.pathSegments.contains('embed') ||
            uri.pathSegments.contains('shorts'))) {
      final id = uri.pathSegments.last;
      return id.isNotEmpty ? id : null;
    }
  }

  return null;
}

/// Renders an autoplaying, muted, looping YouTube trailer as a full-cover
/// background (for use behind a shrunken poster/thumbnail on the detail
/// screen). Falls back to [fallback] when:
///   - [trailerUrl] is null/empty,
///   - the URL doesn't resolve to a YouTube video ID, or
///   - running on a non-web platform (no iframe platform views there —
///     see youtube_trailer_stub.dart).
///
/// Usage:
///   TrailerPlayer(
///     trailerUrl: getTrailerUrl(anime.title),
///     fallback: heroPosterWidget,
///   )
class TrailerPlayer extends StatefulWidget {
  const TrailerPlayer({
    super.key,
    required this.trailerUrl,
    required this.fallback,
  });

  final String? trailerUrl;
  final Widget fallback;

  @override
  State<TrailerPlayer> createState() => _TrailerPlayerState();
}

class _TrailerPlayerState extends State<TrailerPlayer> {
  String? _viewId;
  bool _registered = false;
  YoutubePlayerController? _nativeController;

  @override
  void initState() {
    super.initState();
    _setUpIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TrailerPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerUrl != widget.trailerUrl) {
      _registered = false;
      _viewId = null;
      _nativeController?.dispose();
      _nativeController = null;
      _setUpIfNeeded();
    }
  }

  @override
  void dispose() {
    _nativeController?.dispose();
    super.dispose();
  }

  void _setUpIfNeeded() {
    final url = widget.trailerUrl;
    if (url == null || url.isEmpty) return;
    final videoId = extractYoutubeId(url);
    if (videoId == null) return;

    if (kIsWeb) {
      // Unique per (video, mount) so re-entering this screen for a
      // different anime — or re-registering after a hot reload — doesn't
      // collide with a previously-registered view of the same id.
      final viewId =
          'yt_trailer_${videoId}_${DateTime.now().millisecondsSinceEpoch}';
      registerYoutubeTrailerElement(videoId, viewId);
      _viewId = viewId;
      _registered = true;
    } else {
      // Native (Android/iOS): youtube_player_flutter drives an actual
      // WebView under the hood, so autoplay/mute/loop are controller
      // flags instead of query-string params the way the web iframe
      // does it in youtube_trailer_web.dart.
      _nativeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: true,
          loop: true,
          hideControls: true,
          disableDragSeek: true,
          hideThumbnail: true,
          controlsVisibleAtStart: false,
          enableCaption: false,
        ),
      );
      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) {
      return widget.fallback;
    }
    if (kIsWeb) {
      if (_viewId == null) return widget.fallback;
      return ClipRect(
        child: Transform.scale(
          scale: 1.35,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: IgnorePointer(
                child: HtmlElementView(viewType: _viewId!),
              ),
            ),
          ),
        ),
      );
    }
    if (_nativeController == null) return widget.fallback;
    return ClipRect(
      child: Transform.scale(
        scale: 1.08,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: IgnorePointer(
              child: YoutubePlayer(
                controller: _nativeController!,
                showVideoProgressIndicator: false,
                bottomActions: const [],
                topActions: const [],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
