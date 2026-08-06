// trailer_player.dart — AniVerse trailer background player
//
// Web: wraps the YouTube-embed platform view (youtube_trailer_web.dart /
// youtube_trailer_stub.dart, mirroring watch_screen.dart's existing
// videoElementWeb / videoElementStub split).
// Native (Android/iOS): youtube_player_flutter's WebView-backed player,
// since dart:html/HtmlElementView don't exist outside Flutter Web.
// Both paths share the URL -> video-ID extraction below.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'youtube_trailer_stub.dart'
    if (dart.library.html) 'youtube_trailer_web.dart';

/// Global flag: true = detail screen is the top route (trailer allowed to
/// play). WatchScreen sets this to false on init (and back to true on
/// dispose) so any trailer iframe left alive underneath is paused + removed
/// from the DOM — that's what kills trailer audio bleeding into the episode.
/// Defined here (not in the web-only file) so both web & native builds see it.
final trailerAllowedNotifier = ValueNotifier<bool>(true);
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
/// Starts muted (browsers block unmuted autoplay without a user gesture),
/// then auto-unmutes on the viewer's first interaction anywhere on the page
/// via [armAutoUnmute] — no visible control, no extra tap. YouTube's own
/// chrome (title, logo) is masked by the caller's scrim + a bottom crop, and
/// its auto-translate subtitles are disabled via [disableYoutubeCaptions].
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
    this.playWithSound = false,
  });

  final String? trailerUrl;
  final Widget fallback;
  final bool playWithSound;

  @override
  State<TrailerPlayer> createState() => _TrailerPlayerState();
}

class _TrailerPlayerState extends State<TrailerPlayer> {
  String? _viewId;
  bool _registered = false;
  YoutubePlayerController? _nativeController;
  bool _muted = true;
  // Ensures the first-gesture auto-unmute listener is armed only once.
  bool _autoUnmuteArmed = false;
  // Cancellation untuk listener global (biar bisa di-remove pas dispose).
  void Function()? _cancelAutoUnmute;
  // Listener notifier global: pas false (WatchScreen active di atas),
  // trailer harus di-pause + cabut dari DOM biar audio gak nembus.
  void _onTrailerAllowedChange() {
    if (!trailerAllowedNotifier.value && _viewId != null) {
      disposeYoutubeTrailer(_viewId!);
      _viewId = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _muted = !widget.playWithSound;
    trailerAllowedNotifier.addListener(_onTrailerAllowedChange);
    _setUpIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TrailerPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailerUrl != widget.trailerUrl) {
      _cancelAutoUnmute?.call();
      _cancelAutoUnmute = null;
      _autoUnmuteArmed = false;
      if (_viewId != null) disposeYoutubeTrailer(_viewId!);
      _registered = false;
      _viewId = null;
      _nativeController?.dispose();
      _nativeController = null;
      _muted = !widget.playWithSound;
      _autoUnmuteArmed = false;
      _setUpIfNeeded();
    }
  }

  @override
  void dispose() {
    // Stop global gesture listener biar suara trailer gak overlap di
    // WatchScreen (root cause: listener gak di-remove → trailer reload
    // di background + suara nembus video anime).
    trailerAllowedNotifier.removeListener(_onTrailerAllowedChange);
    _cancelAutoUnmute?.call();
    _cancelAutoUnmute = null;
    _autoUnmuteArmed = false;
    if (_viewId != null) {
      disposeYoutubeTrailer(_viewId!);
      _viewId = null;
    }
    _nativeController?.dispose();
    _nativeController = null;
    super.dispose();
  }

  /// Registers the trailer platform view (web) or builds the native
  /// controller. The web viewId is unique per (video, mount, mute-state) so
  /// re-entering for a different anime — or re-registering after a hot
  /// reload / unmute toggle — doesn't collide with a prior view.
  void _setUpIfNeeded({bool? muted}) {
    final url = widget.trailerUrl;
    if (url == null || url.isEmpty) return;
    final videoId = extractYoutubeId(url);
    if (videoId == null) return;

    final wantMuted = muted ?? !widget.playWithSound;

    if (kIsWeb) {
      final viewId =
          'yt_trailer_${videoId}_${wantMuted ? 'm' : 's'}_${DateTime.now().millisecondsSinceEpoch}';
      registerYoutubeTrailerElement(videoId, viewId, muted: wantMuted);
      // Kill YouTube's auto-translate subtitles (URL params can't).
      disableYoutubeCaptions(viewId);
      _viewId = viewId;
      _registered = true;
      if (!_autoUnmuteArmed) {
        _autoUnmuteArmed = true;
        _cancelAutoUnmute = armAutoUnmute(_autoUnmute);
      }
    } else {
      // Native (Android/iOS): youtube_player_flutter drives an actual
      // WebView under the hood; autoplay/mute/loop are controller flags.
      _nativeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: !widget.playWithSound,
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

  /// Called by the web helper [armAutoUnmute] on the user's first
  /// interaction anywhere on the page. A real gesture is exactly what
  /// browsers require to permit unmuted autoplay, so we reload the embed
  /// (gesture-initiated) with sound on — no visible tap needed.
  void _autoUnmute() {
    if (!_muted) return;
    _muted = false;
    if (_viewId != null) disposeYoutubeTrailer(_viewId!);
    _setUpIfNeeded(muted: false);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_registered) return widget.fallback;
    final player = kIsWeb ? _webPlayer() : _nativePlayer();
    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        // Top scrim masks YouTube's persistent title overlay — controls=0
        // alone doesn't suppress it — without touching the Flutter back
        // button drawn above this layer.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 96,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Trailer di-render di box 1920×1080 (16:9 / 1080p) lalu di-scale ke
  // container hero. Pakai BoxFit.cover (bukan contain) biar fill penuh
  // layar kayak background YouTube — di HP portrait gak ada bar hitam
  // letterbox, crop sisi video aja. Scrim atas (di build()) tetep nutupin
  // title YouTube, crop cover tetep sembunyiin logo bawah.
  Widget _webPlayer() => ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: IgnorePointer(
              child: HtmlElementView(
                viewType: _viewId!,
                key: ValueKey<String>(_viewId!),
              ),
            ),
          ),
        ),
      );

  Widget _nativePlayer() => ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
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
      );
}
