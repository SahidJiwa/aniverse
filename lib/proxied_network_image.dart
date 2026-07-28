// proxied_network_image.dart — AniVerse shared image-loading widget
//
// Extracted from jadwal_screen.dart so Home, Explore, and Jadwal all share
// ONE proxy-fallback chain and ONE image widget, instead of each screen
// re-solving (or never solving) the same CORS problem independently.
//
// BACKGROUND — why this exists at all:
// cdn.myanimelist.net (the source of every cover URL Jikan API returns)
// sends no Access-Control-Allow-Origin header, so Flutter Web's
// Image.network — which the browser treats as a normal cross-origin
// fetch — gets blocked outright by the browser's CORS policy. This is a
// MAL CDN limitation, not a bug in this app's code.
//
// CONFIRMED BY REAL TESTING (browser address-bar, tried directly against
// MAL URLs): wsrv.nl → 400, corsproxy.io → 403, images.weserv.nl → 400,
// allorigins.win → 522 (host down), corsproxy.org → domain repurposed (no
// longer an image proxy), proxy.cors.sh → 404 (requires an x-cors-api-key
// header for programmatic requests). proxy.corsfix.com worked but is a
// public proxy shared with every other app using it, so it's still
// subject to rate limits caused by traffic that has nothing to do with
// this app.
//
// Final fix: aniverse-proxy.tirtasisahid.workers.dev — a Cloudflare Worker
// under this project's own account (see worker.js), used only by
// AniVerse. No shared rate limit, no API key, no "is this proxy still
// alive" guessing, edge-cached for 24h, and free (Cloudflare's free tier
// is 100,000 requests/day — far more than this app needs). If this Worker
// ever needs to change, update _aniverseProxyBase below and redeploy.
//
// anilist.co (s4.anilist.co and similar) is a SEPARATE CDN from MAL's, and
// unlike MAL it already sends a permissive CORS header — every proxy
// candidate fails specifically for AniList URLs while the raw URL loads
// fine directly. So AniList URLs skip the proxy chain entirely rather than
// wasting 4 failed round-trips before falling through to the same raw URL
// that would have worked immediately.
//
// If MAL's CDN starts rejecting ALL of these public proxies consistently
// (which the comment history in jadwal_screen.dart already suggested was
// happening), the real long-term fix is a self-hosted proxy (e.g. a small
// Cloudflare Worker / Netlify Function that fetches the image server-side
// under your own domain) rather than adding a 5th public proxy to guess at.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'anime_api_service.dart';

const String _aniverseProxyBase =
    'https://aniverse-proxy.tirtasisahid.workers.dev';

/// Builds the ordered list of candidate URLs to try for a given source
/// [url]. Returns an empty list if [url] is null/empty (caller should show
/// its own fallback in that case), a single-element list if [url] is
/// already a local/proxied/AniList URL that needs no further wrapping, or
/// the full MAL-oriented proxy chain otherwise.
List<String> corsProxyCandidates(String? url) {
  if (url == null || url.isEmpty) return const [];
  final cleanUrl = url.trim().replaceAll(' ', '%20');

  if (!cleanUrl.startsWith('http') ||
      cleanUrl.startsWith('data:') ||
      cleanUrl.startsWith('blob:')) {
    return [cleanUrl];
  }

  // Already-proxied URLs shouldn't be double-wrapped — use as-is.
  if (cleanUrl.contains('wsrv.nl') ||
      cleanUrl.contains('weserv.nl') ||
      cleanUrl.contains('corsproxy.io') ||
      cleanUrl.contains('allorigins.win') ||
      cleanUrl.contains('proxy.cors.sh') ||
      cleanUrl.contains('proxy.corsfix.com') ||
      cleanUrl.contains('aniverse-proxy.tirtasisahid.workers.dev')) {
    return [cleanUrl];
  }

  // AniList's own CDN is already CORS-friendly — see file header. Skip the
  // MAL-oriented proxy chain entirely for these.
  if (cleanUrl.contains('anilist.co')) {
    return [cleanUrl];
  }

  if (cleanUrl.contains('placehold.co') || cleanUrl.endsWith('/default.jpg')) {
    return [cleanUrl];
  }

  // Self-hosted Worker /image endpoint — see file header for why this
  // replaced proxy.corsfix.com. Route MAL URLs through it first; if it
  // ever goes down, fall through to wsrv.nl and raw URLs.
  final candidates = <String>[
    '$_aniverseProxyBase/image?url=${Uri.encodeComponent(cleanUrl)}',
  ];

  // If URL ends with 'l.jpg' (often 404s on MAL CDN), also try without the 'l'
  final String? altUrl = cleanUrl.endsWith('l.jpg')
      ? '${cleanUrl.substring(0, cleanUrl.length - 5)}.jpg'
      : null;

  if (altUrl != null) {
    candidates.add('$_aniverseProxyBase/image?url=${Uri.encodeComponent(altUrl)}');
  }

  candidates.add('https://wsrv.nl/?url=${Uri.encodeComponent(cleanUrl)}');
  candidates.add(cleanUrl);

  if (altUrl != null) {
    candidates.add(altUrl);
  }

  return candidates;
}

/// Minimal shimmer placeholder used while an image loads or while this
/// widget is advancing through failed candidates. Kept self-contained here
/// (rather than importing a shared ShimmerBox from elsewhere) so this file
/// has no dependency on any particular screen's widget library.
class ImageShimmerPlaceholder extends StatefulWidget {
  const ImageShimmerPlaceholder({super.key});

  @override
  State<ImageShimmerPlaceholder> createState() => _ImageShimmerPlaceholderState();
}

class _ImageShimmerPlaceholderState extends State<ImageShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [
                Colors.white.withOpacity(0.04),
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
            color: Colors.white.withOpacity(0.05),
          ),
        );
      },
    );
  }
}

/// Network image widget that walks through [corsProxyCandidates] (or a
/// caller-supplied candidate list) in order, advancing to the next
/// candidate whenever one fails to load, and falling back to [fallback]
/// (or a blank box) once every candidate has failed.
///
/// Usage:
///   ProxiedNetworkImage.forUrl(
///     url: anime.imageUrl,
///     width: 120,
///     height: 160,
///   )
class ProxiedNetworkImage extends StatefulWidget {
  const ProxiedNetworkImage({
    super.key,
    required this.candidates,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.colorFilterColor,
    this.colorBlendMode,
    this.fallback,
    this.borderRadius,
    this.title,
  });

  /// Convenience constructor — builds the candidate list from a single
  /// source [url] via [corsProxyCandidates], so call sites don't need to
  /// call that function themselves.
  factory ProxiedNetworkImage.forUrl({
    Key? key,
    required String? url,
    required double? width,
    required double? height,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    Color? colorFilterColor,
    BlendMode? colorBlendMode,
    Widget? fallback,
    BorderRadius? borderRadius,
    String? title,
  }) {
    return ProxiedNetworkImage(
      key: key,
      candidates: corsProxyCandidates(url),
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      colorFilterColor: colorFilterColor,
      colorBlendMode: colorBlendMode,
      fallback: fallback,
      borderRadius: borderRadius,
      title: title,
    );
  }

  final List<String> candidates;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final Color? colorFilterColor;
  final BlendMode? colorBlendMode;
  final Widget? fallback;
  final BorderRadius? borderRadius;

  /// Anime title used as a last-resort fallback: if every URL in
  /// [candidates] fails to load, this widget calls
  /// [AnimeApiService.fetchCoverByTitle] to look up a replacement cover
  /// (AniList first, Jikan second) and appends it as one final candidate.
  /// Optional — if null/empty, the widget just falls through to
  /// [fallback] once [candidates] is exhausted, same as before.
  final String? title;

  @override
  State<ProxiedNetworkImage> createState() => _ProxiedNetworkImageState();
}

class _ProxiedNetworkImageState extends State<ProxiedNetworkImage> {
  // Shared across all instances (static) so we're not constructing a new
  // Random() per widget per rebuild — cheap either way, but there's no
  // reason not to share it.
  static final Random _rng = Random();

  // ── Global concurrency gate ──────────────────────────────────────────
  // Home renders many sections at once (hero, continue-watching, several
  // horizontal rails, a genre grid...), each with several
  // ProxiedNetworkImage instances, all mounting in the same initial frame.
  // When the public CORS proxies are failing hard (as during a proxy
  // outage), EVERY one of those instances starts advancing through its
  // candidate chain near-simultaneously — dozens of concurrent
  // Image.network attempts plus dozens of concurrent AniList
  // title-fallback requests, all firing setState in overlapping frames.
  // That's what was overwhelming the framework on Home specifically
  // (Jadwal/other screens render far fewer posters per frame, so they
  // never hit this ceiling).
  //
  // This caps how many ProxiedNetworkImage instances app-wide are allowed
  // to have an active in-flight Image.network attempt at once. Instances
  // beyond the cap simply wait their turn (show the shimmer) instead of
  // all firing together — same eventual result, far gentler ramp-up.
  static int _activeSlots = 0;
  static const int _maxConcurrent = 6;
  static final List<VoidCallback> _waitQueue = [];

  bool _holdingSlot = false;

  void _acquireSlot() {
    if (_activeSlots < _maxConcurrent) {
      _activeSlots++;
      _holdingSlot = true;
    } else {
      _waitQueue.add(() {
        if (mounted) {
          _holdingSlot = true;
          setState(() {});
        } else {
          _releaseSlot();
        }
      });
    }
  }

  void _releaseSlot() {
    if (!_holdingSlot) return;
    _holdingSlot = false;
    _activeSlots--;
    if (_waitQueue.isNotEmpty && _activeSlots < _maxConcurrent) {
      final next = _waitQueue.removeAt(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => next());
    }
  }

  int _index = 0;

  // Title-fallback state: once every URL in widget.candidates has failed,
  // we ask AnimeApiService.fetchCoverByTitle for a replacement cover (if a
  // title was supplied) and, when found, treat it as one final candidate
  // appended after the original list.
  bool _titleFallbackRequested = false;
  // True from the moment the AniList request is kicked off until it
  // resolves (success or failure). THIS IS THE FIX for a race that made
  // covers vanish even when AniList had a perfectly good image: build()
  // used to decide "give up, show widget.fallback" purely from
  // `_titleFallbackRequested` being true, with no way to tell "still
  // waiting for the network" apart from "already got an answer and it was
  // empty". Any rebuild that landed in that in-between window (e.g. a
  // sibling poster's own setState, or ListView recycling) permanently
  // latched the fallback UI — the AniList response arriving moments later
  // was silently dropped because nothing re-checked it. Gating the "give
  // up" branch on `!_titleFallbackPending` instead keeps showing the
  // shimmer for as long as the request is genuinely still in flight.
  bool _titleFallbackPending = false;
  String? _titleFallbackUrl;

  // Some public proxies (observed with api.allorigins.win before it was
  // dropped from the chain, and possibly others under load) don't fail
  // outright — they hang without ever calling errorBuilder. A per-candidate
  // watchdog timer forces an advance to the next candidate after a short
  // wait, so one slow/hanging proxy can't stall the whole fallback chain
  // (and, transitively, delay reaching the AniList title-fallback).
  Timer? _watchdog;
  String? _watchdogCandidate;

  void _armWatchdog(String candidateUrl) {
    // Guard against re-arming on every rebuild (e.g. a parent animation
    // ticking setState every frame) — that would keep resetting the timer
    // before it ever gets a chance to fire, silently defeating the whole
    // point of the watchdog. Only (re)arm when we're actually starting a
    // new candidate.
    if (_watchdogCandidate == candidateUrl && _watchdog != null) return;
    _watchdog?.cancel();
    _watchdogCandidate = candidateUrl;
    _watchdog = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      // Only advance if we're still waiting on the same candidate — if the
      // image already loaded or the widget moved on, this timer is stale.
      if (_index < _effectiveCandidates.length &&
          _effectiveCandidates[_index] == candidateUrl) {
        _releaseSlot();
        setState(() => _index++);
      }
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _releaseSlot();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProxiedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different anime/image means a different candidate list — reset to
    // the first candidate rather than keep whatever index we'd advanced to
    // for the previous image.
    final oldFirst = oldWidget.candidates.isNotEmpty ? oldWidget.candidates.first : null;
    final newFirst = widget.candidates.isNotEmpty ? widget.candidates.first : null;
    if (oldFirst != newFirst) {
      _watchdog?.cancel();
      _watchdogCandidate = null;
      _index = 0;
      _titleFallbackRequested = false;
      _titleFallbackPending = false;
      _titleFallbackUrl = null;
    }
  }

  /// Full candidate list including the title-fallback URL, once resolved.
  List<String> get _effectiveCandidates {
    if (_titleFallbackUrl == null) return widget.candidates;
    return [...widget.candidates, _titleFallbackUrl!];
  }

  // Title-based AniList/Jikan fallback (used to live here as
  // _requestTitleFallback) has been removed entirely — see the comment on
  // the `_index >= effective.length` branch in build() below for why: it
  // was the source of a request avalanche that made Home unusable whenever
  // several cards failed their MAL/Worker candidate at once. A single
  // failed image now just shows widget.fallback with no extra network
  // call.

  @override
  Widget build(BuildContext context) {
    // NOTE: deliberately NOT an early-return on widget.candidates.isEmpty —
    // that used to skip straight to widget.fallback, which meant any URL
    // that corsProxyCandidates() maps to an empty list (e.g. placehold.co,
    // see that function's comment) could never reach the title-based
    // fallback below even when a title was supplied. Falling through to the
    // same effective-candidates/_index logic used for a non-empty list
    // means an empty candidates list is treated as "zero candidates tried,
    // zero failed" — i.e. immediately eligible for the title lookup.
    final effective = _effectiveCandidates;

    if (_index >= effective.length) {
      // Every known MAL/Worker candidate has failed. Title-based fallback
      // is disabled (see _requestTitleFallback's doc comment) — go
      // straight to widget.fallback instead of shimmering forever or
      // firing another network request.
      return widget.fallback ?? const SizedBox.shrink();
    }

    // Arm (or re-arm) the watchdog for whichever candidate we're about to
    // try — build() runs again each time _index changes, so this always
    // tracks the current attempt without needing to hook into loadingBuilder.
    _armWatchdog(effective[_index]);

    // Gate the actual network attempt behind the global concurrency slot
    // (see _acquireSlot/_maxConcurrent above). Without this, Home's several
    // simultaneous poster rails all start their Image.network attempts in
    // the same frame — this queues the excess ones behind a shimmer instead
    // of letting every instance app-wide race at once.
    if (!_holdingSlot) {
      _acquireSlot();
      if (!_holdingSlot) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const ImageShimmerPlaceholder(),
        );
      }
    }

    Widget image = Image.network(
      effective[_index],
      key: ValueKey(effective[_index]),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      color: widget.colorFilterColor,
      colorBlendMode: widget.colorBlendMode,
      cacheWidth: (widget.width != null && widget.width!.isFinite)
          ? (widget.width! * 2).round()
          : null,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) {
          // Loaded successfully — this candidate is done, cancel its
          // watchdog so it can't fire and skip past a working image.
          _watchdog?.cancel();
          // _releaseSlot() can hand our freed slot straight to a waiting
          // widget via its onReady callback, which calls that widget's
          // setState() synchronously. loadingBuilder runs DURING this
          // widget's own build, so that cascading setState throws
          // ("setState() or markNeedsBuild() called during build") — it's
          // a sibling being marked dirty mid-build, not a descendant, so
          // the framework doesn't allow it. Deferring to a post-frame
          // callback lets it happen right after the current build finishes
          // instead.
          WidgetsBinding.instance.addPostFrameCallback((_) => _releaseSlot());
          return child;
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const ImageShimmerPlaceholder(),
        );
      },
      errorBuilder: (_, error, __) {
        // ignore: avoid_print
        print(
          '[ProxiedNetworkImage] candidate $_index failed: '
          '${effective[_index]} — $error',
        );
        _watchdog?.cancel();
        // See the loadingBuilder comment above — deferred for the same
        // reason (releasing our slot can synchronously setState() a
        // sibling widget, which isn't allowed mid-build).
        WidgetsBinding.instance.addPostFrameCallback((_) => _releaseSlot());
        // Schedule the retry-with-next-candidate for after this build
        // completes — calling setState synchronously inside errorBuilder
        // (which itself runs during build) throws.
        //
        // A small randomized delay (rather than an immediate
        // addPostFrameCallback) is deliberate: when many
        // ProxiedNetworkImage instances on screen (e.g. a whole grid of
        // posters) fail at nearly the same moment — as happens when the
        // public CORS proxies are rate-limiting or rejecting everything —
        // an immediate post-frame setState from every one of them lands in
        // the SAME frame, causing a simultaneous rebuild storm across the
        // whole grid on every single retry step. Spreading each widget's
        // advance over a few dozen milliseconds of jitter turns that storm
        // into a trickle, which is what was overwhelming the framework
        // (seen as repeated mouse_tracker.dart assertion failures / a
        // frozen-looking blank Home screen) even though each individual
        // failure is harmless on its own.
        final jitterMs = 30 + _rng.nextInt(120);
        Future.delayed(Duration(milliseconds: jitterMs), () {
          if (mounted) setState(() => _index++);
        });
        // Show a shimmer placeholder while we advance, rather than a
        // jarring flash of the broken-image icon between each failed
        // attempt.
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const ImageShimmerPlaceholder(),
        );
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }
}
