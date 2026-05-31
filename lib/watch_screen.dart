import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'anime_model.dart';
import 'episode_model.dart';
import 'app_theme.dart';

// ─── Theme tokens ─────────────────────────────────────────────────────────────
const _kPink = AppTheme.sakuraPink;
const _kBg = AppTheme.backgroundDark;
const _kSurface = AppTheme.surfaceDark;
const _kPinkGlow = Color(0x33FF2D55);
const _kPinkSubtle = Color(0x1AFF2D55);
const _kPinkBorder = Color(0x55FF2D55);
const _kWhite80 = Color(0xCCFFFFFF);
const _kWhite60 = Color(0x99FFFFFF);
const _kWhite40 = Color(0x66FFFFFF);
const _kWhite10 = Color(0x1AFFFFFF);
const _kWhite06 = Color(0x0FFFFFFF);

// ─── Entry point ─────────────────────────────────────────────────────────────
class WatchScreen extends StatefulWidget {
  final AnimeModel anime;
  final int initialEpisodeIndex;

  const WatchScreen({
    super.key,
    required this.anime,
    this.initialEpisodeIndex = 0,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with TickerProviderStateMixin {
  late int _currentIndex;
  bool _isPlaying = false;
  bool _showControls = true;
  double _seekValue = 0.31;

  late AnimationController _controlsFade;
  late Animation<double> _controlsAnim;

  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  final ScrollController _episodeListController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialEpisodeIndex;

    _controlsFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _controlsAnim =
        CurvedAnimation(parent: _controlsFade, curve: Curves.easeInOut);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controlsFade.dispose();
    _pulse.dispose();
    _episodeListController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  EpisodeModel get _currentEpisode => widget.anime.episodes[_currentIndex];
  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext => _currentIndex < widget.anime.episodes.length - 1;

  void _goToEpisode(int index) {
    if (index < 0 || index >= widget.anime.episodes.length) return;
    setState(() {
      _currentIndex = index;
      _isPlaying = false;
      _seekValue = 0.0;
      _showControls = true;
      _controlsFade.value = 1.0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_episodeListController.hasClients) return;
      final offset = (index * 84.0)
          .clamp(0.0, _episodeListController.position.maxScrollExtent);
      _episodeListController.animateTo(
        offset,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
      );
    });
  }

  void _togglePlay() => setState(() => _isPlaying = !_isPlaying);

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsFade.forward();
    } else {
      _controlsFade.reverse();
    }
  }

  String _formatTime(double fraction) {
    const totalSec = 22 * 60 + 10;
    final elapsed = (fraction * totalSec).round();
    final m = elapsed ~/ 60;
    final s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: isWide ? _wideLayout(context) : _narrowLayout(context),
      ),
    );
  }

  // ─── Narrow (phone) ───────────────────────────────────────────────────────

  Widget _narrowLayout(BuildContext context) {
    return Column(
      children: [
        _videoPlayer(context),
        _controlsBar(),
        _episodeHeader(),
        Expanded(child: _episodeList()),
        _infoBarCompact(),
      ],
    );
  }

  // ─── Wide (tablet) ────────────────────────────────────────────────────────

  Widget _wideLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _videoPlayer(context),
              _controlsBar(),
              _infoSectionWide(context),
            ],
          ),
        ),
        Container(width: 0.5, color: _kWhite06),
        SizedBox(
          width: 310,
          child: Column(
            children: [
              _episodeHeader(),
              Expanded(child: _episodeList()),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Premium Video Player ─────────────────────────────────────────────────

  Widget _videoPlayer(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _thumbnail(),
              _vignette(),
              _bottomGradient(),
              FadeTransition(
                opacity: _controlsAnim,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _topBar(context),
                    _centerPlayButton(),
                    _bottomOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    return Image.network(
      _currentEpisode.thumbnailUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.network(
        widget.anime.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _kSurface,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.movie_creation_outlined,
                    color: _kWhite40, size: 52),
                const SizedBox(height: 10),
                Text(
                  widget.anime.title,
                  style: const TextStyle(color: _kWhite40, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vignette() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.4,
          colors: [Colors.transparent, Color(0x99000000)],
        ),
      ),
    );
  }

  Widget _bottomGradient() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 160,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.88),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar inside player ─────────────────────────────────────────────────

  Widget _topBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.anime.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _currentEpisode.title,
                    style: const TextStyle(color: _kWhite60, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.airplay_rounded,
                  color: _kWhite60, size: 20),
              onPressed: () {},
              tooltip: 'Cast',
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: _kWhite60, size: 20),
              onPressed: () {},
              tooltip: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  // ── Center Play/Pause ─────────────────────────────────────────────────────

  Widget _centerPlayButton() {
    return Center(
      child: GestureDetector(
        onTap: _togglePlay,
        child: AnimatedBuilder(
          animation:
              _isPlaying ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
          builder: (_, child) => Transform.scale(
            scale: _isPlaying ? _pulseAnim.value : 1.0,
            child: child,
          ),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPink,
              boxShadow: [
                BoxShadow(
                  color: _kPink.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom overlay: episode pill + seek + controls ────────────────────────

  Widget _bottomOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kPink,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'EP ${_currentEpisode.number}  ·  ${_currentEpisode.title}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatTime(_seekValue),
                  style: const TextStyle(
                    color: _kWhite80,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: _PremiumSeekBar(
                    value: _seekValue,
                    onChanged: (v) => setState(() => _seekValue = v),
                  ),
                ),
                const Text(
                  '22:10',
                  style: TextStyle(color: _kWhite60, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _PlayerIconBtn(
                  icon: Icons.skip_previous_rounded,
                  enabled: _hasPrev,
                  onTap: () => _goToEpisode(_currentIndex - 1),
                ),
                const SizedBox(width: 4),
                _PlayerIconBtn(
                  icon: Icons.skip_next_rounded,
                  enabled: _hasNext,
                  onTap: () => _goToEpisode(_currentIndex + 1),
                ),
                const Spacer(),
                _PlayerIconBtn(
                    icon: Icons.closed_caption_off_rounded, onTap: () {}),
                const SizedBox(width: 4),
                _PlayerIconBtn(icon: Icons.speed_rounded, onTap: () {}),
                const SizedBox(width: 4),
                _PlayerIconBtn(icon: Icons.fullscreen_rounded, onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Controls bar (below player) ─────────────────────────────────────────

  Widget _controlsBar() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.skip_previous_rounded,
            label: 'Prev',
            enabled: _hasPrev,
            onTap: () => _goToEpisode(_currentIndex - 1),
          ),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.skip_next_rounded,
            label: 'Next',
            enabled: _hasNext,
            onTap: () => _goToEpisode(_currentIndex + 1),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currentEpisode.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                _currentEpisode.duration,
                style: const TextStyle(color: _kWhite40, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Episode list header ──────────────────────────────────────────────────

  Widget _episodeHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kWhite06)),
      ),
      child: Row(
        children: [
          const Text(
            'Episodes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _kPinkSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPinkBorder, width: 0.5),
            ),
            child: Text(
              '${widget.anime.episodes.length}',
              style: const TextStyle(
                color: _kPink,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kWhite06,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.anime.genre,
              style: const TextStyle(color: _kWhite60, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Episode list ─────────────────────────────────────────────────────────

  Widget _episodeList() {
    return ListView.builder(
      controller: _episodeListController,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: widget.anime.episodes.length,
      itemBuilder: (context, index) {
        final ep = widget.anime.episodes[index];
        final isSelected = index == _currentIndex;
        return _EpisodeTile(
          episode: ep,
          isSelected: isSelected,
          // Pass cover image so thumbnail can use it as fallback
          animeCoverUrl: widget.anime.imageUrl,
          onTap: () => _goToEpisode(index),
        );
      },
    );
  }

  // ─── Info section (wide layout) ──────────────────────────────────────────

  Widget _infoSectionWide(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.anime.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${widget.anime.rating}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                _InfoPill(widget.anime.genre),
                const SizedBox(width: 6),
                _InfoPill('${widget.anime.episodes.length} Episodes'),
                const SizedBox(width: 6),
                const _InfoPill('HD'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.anime.description,
              style: const TextStyle(
                color: _kWhite60,
                fontSize: 13,
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Compact info bar (narrow layout) ────────────────────────────────────

  Widget _infoBarCompact() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kWhite06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.anime.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.anime.rating}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _InfoPill(widget.anime.genre, small: true),
                    const SizedBox(width: 5),
                    _InfoPill('${widget.anime.episodes.length} Eps',
                        small: true),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kWhite10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bookmark_border_rounded,
                color: _kWhite60, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Premium Seek Bar ─────────────────────────────────────────────────────────

class _PremiumSeekBar extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _PremiumSeekBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const _GlowThumbShape(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: _kPink,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
        thumbColor: Colors.white,
        overlayColor: _kPinkGlow,
        secondaryActiveTrackColor: Colors.white.withValues(alpha: 0.35),
      ),
      child: Slider(
        value: value,
        secondaryTrackValue: (value + 0.18).clamp(0.0, 1.0),
        onChanged: onChanged,
      ),
    );
  }
}

class _GlowThumbShape extends SliderComponentShape {
  const _GlowThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(14, 14);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 10,
        Paint()
          ..color = _kPink.withValues(alpha: 0.30)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(center, 6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(center, 3,
        Paint()
          ..color = _kPink
          ..style = PaintingStyle.fill);
  }
}

// ─── Player icon button (inside video) ───────────────────────────────────────

class _PlayerIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _PlayerIconBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.25),
          size: 22,
        ),
      ),
    );
  }
}

// ─── Nav button (below player) ────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        foregroundColor:
            enabled ? Colors.white : Colors.white.withValues(alpha: 0.22),
        backgroundColor: enabled ? _kWhite10 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 19),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Episode tile ─────────────────────────────────────────────────────────────

class _EpisodeTile extends StatelessWidget {
  final EpisodeModel episode;
  final bool isSelected;
  final String animeCoverUrl;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    required this.isSelected,
    required this.animeCoverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: _kPinkSubtle,
      highlightColor: _kPinkSubtle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? _kPinkSubtle : Colors.transparent,
          border: isSelected
              ? const Border(left: BorderSide(color: _kPink, width: 3))
              : const Border(
                  left: BorderSide(color: Colors.transparent, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        child: Row(
          children: [
            _EpisodeThumbnail(
              thumbnailUrl: episode.thumbnailUrl,
              fallbackUrl: animeCoverUrl,
              episodeNumber: episode.number,
              isSelected: isSelected,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EP ${episode.number}',
                        style: TextStyle(
                          color: isSelected ? _kPink : _kWhite40,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 11, color: Color(0x44FFFFFF)),
                          const SizedBox(width: 3),
                          Text(
                            episode.duration,
                            style: const TextStyle(
                                color: Color(0x44FFFFFF), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    episode.title,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xCCFFFFFF),
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: 0.31,
                        minHeight: 2.5,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_kPink),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Episode thumbnail ────────────────────────────────────────────────────────

class _EpisodeThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final String fallbackUrl;
  final int episodeNumber;
  final bool isSelected;

  const _EpisodeThumbnail({
    required this.thumbnailUrl,
    required this.fallbackUrl,
    required this.episodeNumber,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 104,
        height: 60,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image: episode thumbnail → anime cover → solid fallback ──
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.network(
                fallbackUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: _kSurface),
              ),
            ),

            // ── Dark overlay — always present, stronger when selected ────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isSelected
                      ? [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.72),
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.50),
                        ],
                ),
              ),
            ),

            // ── Episode number badge (top-left) ──────────────────────────
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? _kPink : Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 0.5,
                        ),
                ),
                child: Text(
                  'EP $episodeNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),

            // ── Playing indicator (center, only when selected) ───────────
            if (isSelected)
              const Center(child: _PlayingIndicator()),
          ],
        ),
      ),
    );
  }
}

// ─── Animated playing bars indicator ─────────────────────────────────────────

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _bars;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _bars = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
      )..repeat(reverse: true),
    );
    _anims = _bars
        .map((c) => Tween<double>(begin: 0.25, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
    Future.delayed(const Duration(milliseconds: 150),
        () { if (mounted) _bars[1].forward(); });
    Future.delayed(const Duration(milliseconds: 300),
        () { if (mounted) _bars[2].forward(); });
    _bars[0].forward();
  }

  @override
  void dispose() {
    for (final c in _bars) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            width: 3.5,
            height: 16 * _anims[i].value,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _kPink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Info pill ────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final String label;
  final bool small;

  const _InfoPill(this.label, {this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _kWhite06,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _kWhite10, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _kWhite60,
          fontSize: small ? 11 : 12,
        ),
      ),
    );
  }
}
