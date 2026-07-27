import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../anime_model.dart';
import '../anime_detail_screen.dart';
import '../app_theme.dart';
import '../anime_card.dart';
import '../anime_api_service.dart';
import '../app_theme.dart';

// ─── Theme tokens (mirrored from explore_screen.dart) ─────────────────────────
const _kPink = AppTheme.terracotta;
const _kBg = Color(0xFFFAFAFA);
const _kSurface = AppTheme.surfaceRaised;
final _kPinkGlow = AppTheme.terracotta.withValues(alpha: 0.20);
const _kPinkSubtle = AppTheme.border;
const _kPinkBorder = AppTheme.border;
const _kDark80 = Color(0xDD1A0A2E);
const _kDark60 = Color(0xAA4A3A5E);
const _kDark40 = Color(0x778C7D99);
const _kDark20 = AppTheme.border;
const _kDark10 = Color(0x18D9C4DA);
const _kDark06 = Color(0x12D9C4DA);

// ─── Universe Hub ────────────────────────────────────────────────────────────

class UniverseHub extends StatelessWidget {
  final int totalTitles;
  final ValueChanged<String?> onMoodTap;
  final VoidCallback onRadarTap;
  final VoidCallback onPulseTap;
  final VoidCallback onDropMapTap;
  final bool moodRadarUsed;
  final bool chatRoomJoined;

  const UniverseHub({
    super.key,
    required this.totalTitles,
    required this.onMoodTap,
    required this.onRadarTap,
    required this.onPulseTap,
    required this.onDropMapTap,
    required this.moodRadarUsed,
    required this.chatRoomJoined,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        label: 'Battle Gate',
        sub: 'Action',
        icon: Icons.flash_on_rounded,
        color: AppTheme.terracotta,
        onTap: () => onMoodTap('Action'),
        badge: null as Widget?,
      ),
      (
        label: 'Soft Escape',
        sub: 'Drama',
        icon: Icons.local_florist_rounded,
        color: const Color(0xFFFF7A6B),
        onTap: () => onMoodTap('Drama'),
        badge: null as Widget?,
      ),
      (
        label: 'Magic Route',
        sub: 'Fantasy',
        icon: Icons.auto_fix_high_rounded,
        color: const Color(0xFFA855F7),
        onTap: () => onMoodTap('Fantasy'),
        badge: null as Widget?,
      ),
      (
        label: 'Mood Radar',
        sub: 'Match vibe',
        icon: Icons.radar_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: onRadarTap,
        badge: !moodRadarUsed
            ? const _PulsingBadge(color: Color(0xFF8B5CF6), label: 'NEW')
            : null,
      ),
      (
        label: 'Fan Pulse',
        sub: 'Hot rooms',
        icon: Icons.groups_rounded,
        color: const Color(0xFFEC4899),
        onTap: onPulseTap,
        badge: !chatRoomJoined
            ? const _PulsingBadge(color: Color(0xFFEC4899), label: 'LIVE')
            : null,
      ),
      (
        label: 'Drop Map',
        sub: 'Rewards',
        icon: Icons.diamond_rounded,
        color: const Color(0xFFF59E0B),
        onTap: onDropMapTap,
        badge: (moodRadarUsed || chatRoomJoined)
            ? _PulsingBadge(
                color: Color(0xFFF59E0B),
                label: 'LOOT',
                isGolden: true,
              )
            : null,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceRaised.withOpacity(0.95),
            Color(0xFFFFF0F7).withOpacity(0.95),
            Color(0xFFF4EBFF).withOpacity(0.95),
          ],
        ),
        border: Border.all(
          color: AppTheme.terracotta.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.terracotta.withOpacity(0.08),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.terracotta, AppTheme.sage],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.terracotta.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: AppTheme.surfaceRaised,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Universe Hub',
                      style: TextStyle(
                        color: Color(0xFF2C2420),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalTitles titles available · explore modes',
                      style: TextStyle(
                        color: Color(0xFF7D6D8B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.terracotta.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.terracotta.withOpacity(0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulsingDot(color: AppTheme.terracotta),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppTheme.terracotta,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.98,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return _HubGridItem(
                label: item.label,
                sub: item.sub,
                icon: item.icon,
                color: item.color,
                onTap: item.onTap,
                badge: item.badge,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _HubGridItem extends StatefulWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget? badge;

  const _HubGridItem({
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  State<_HubGridItem> createState() => _HubGridItemState();
}

class _HubGridItemState extends State<_HubGridItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Widget gridContent = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withOpacity(_pressed ? 0.45 : 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_pressed ? 0.18 : 0.06),
                blurRadius: _pressed ? 14 : 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Full gradient icon bubble
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color,
                        widget.color.withOpacity(0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: AppTheme.surfaceRaised, size: 17),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF2C2420),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.sub,
                    style: TextStyle(
                      color: widget.color.withOpacity(0.70),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.badge != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          gridContent,
          Positioned(
            top: -4,
            right: -2,
            child: widget.badge!,
          ),
        ],
      );
    }

    return gridContent;
  }
}

class _PulsingBadge extends StatefulWidget {
  final Color color;
  final String label;
  final bool isGolden;

  const _PulsingBadge({
    required this.color,
    required this.label,
    this.isGolden = false,
  });

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
          decoration: BoxDecoration(
            color: widget.isGolden ? Color(0xFFFFD700) : widget.color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.surfaceRaised, width: 1),
            boxShadow: [
              BoxShadow(
                color: (widget.isGolden ? Color(0xFFFFD700) : widget.color).withOpacity(0.5),
                blurRadius: _glow.value + 2,
                spreadRadius: _glow.value / 3,
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isGolden ? Colors.black : AppTheme.surfaceRaised,
              fontSize: 6.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        );
      },
    );
  }
}

// ─── Mood Radar Scanner ──────────────────────────────────────────────────────

void showMoodRadarSheet(
  BuildContext context,
  List<AnimeModel> allAnimes, {
  VoidCallback? onScanComplete,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => _MoodRadarSheet(
      allAnimes: allAnimes,
      onScanComplete: onScanComplete,
    ),
  );
}

class _MoodRadarSheet extends StatefulWidget {
  final List<AnimeModel> allAnimes;
  final VoidCallback? onScanComplete;
  const _MoodRadarSheet({required this.allAnimes, this.onScanComplete});

  @override
  State<_MoodRadarSheet> createState() => _MoodRadarSheetState();
}

class _MoodRadarSheetState extends State<_MoodRadarSheet> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _scanProgressCtrl;
  bool _scanning = true;
  List<Map<String, dynamic>> _matchedData = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scanProgressCtrl = AnimationController(
      vsync: this,
      duration: AnimeApiService.isTestMode
          ? Duration.zero
          : const Duration(milliseconds: 2500),
    );

    _scanProgressCtrl.addListener(() {
      setState(() {});
    });

    _scanProgressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onScanComplete();
      }
    });

    _runScan();
  }

  void _runScan() {
    setState(() {
      _scanning = true;
      _matchedData = [];
    });
    _scanProgressCtrl.forward(from: 0.0);
  }

  void _onScanComplete() {
    if (!mounted) return;
    final list = List<AnimeModel>.from(widget.allAnimes);
    if (list.isEmpty) {
      setState(() {
        _scanning = false;
      });
      return;
    }
    list.shuffle();
    final selected = list.take(3).toList();

    setState(() {
      _scanning = false;
      _matchedData = [
        {
          'anime': selected[0],
          'percent': 95 + math.Random().nextInt(5), // 95 - 99
          'vibe': 'Epic Action & Lore ⚔️',
        },
        if (selected.length > 1)
          {
            'anime': selected[1],
            'percent': 85 + math.Random().nextInt(10), // 85 - 94
            'vibe': 'High Thrills & Depth 🌪️',
          },
        if (selected.length > 2)
          {
            'anime': selected[2],
            'percent': 70 + math.Random().nextInt(15), // 70 - 84
            'vibe': 'Mysterious & Emotional 🔮',
          },
      ];
    });
    HapticFeedback.mediumImpact();
    widget.onScanComplete?.call();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scanProgressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: AppTheme.terracotta.withValues(alpha: 0.20), width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.radar_rounded, color: AppTheme.terracotta, size: 22),
              SizedBox(width: 8),
              Text(
                'Mood Radar Scanner',
                style: TextStyle(
                  color: AppTheme.surfaceRaised,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_scanning) ...[
            SizedBox(
              width: 160,
              height: 160,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RadarSweepPainter(
                            angle: _ctrl.value * 2 * math.pi,
                            color: AppTheme.terracotta,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: _scanProgressCtrl.value,
                          color: AppTheme.terracotta.withOpacity(0.6),
                          backgroundColor: Colors.white12,
                          strokeWidth: 2,
                        ),
                      ),
                      Text(
                        '${(_scanProgressCtrl.value * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppTheme.surfaceRaised,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _scanProgressCtrl.value < 0.3
                  ? 'Initializing frequency sweep...'
                  : _scanProgressCtrl.value < 0.7
                      ? 'Analyzing anime timelines...'
                      : 'Syncing your temporal vibe...',
              style: TextStyle(
                color: AppTheme.surfaceRaised.withValues(alpha: 0.70),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aligning portal coordinates to your vibe',
              style: TextStyle(
                color: AppTheme.surfaceRaised.withValues(alpha: 0.38),
                fontSize: 11,
              ),
            ),
          ] else ...[
            const Text(
              'Radar Scan Successful!',
              style: TextStyle(
                color: AppTheme.terracotta,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We found 3 titles matching your current frequency:',
              style: TextStyle(
                color: AppTheme.surfaceRaised.withValues(alpha: 0.70),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 185,
              child: Row(
                children: _matchedData.map((data) {
                  final anime = data['anime'] as AnimeModel;
                  final percent = data['percent'] as int;
                  final vibe = data['vibe'] as String;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnimeDetailScreen(anime: anime),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.terracotta.withOpacity(0.3), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.terracotta.withOpacity(0.08),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                            image: DecorationImage(
                              image: NetworkImage(anime.imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.9),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.terracotta,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.terracotta.withOpacity(0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$percent% Match',
                                    style: const TextStyle(
                                      color: AppTheme.surfaceRaised,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      anime.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.surfaceRaised,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      vibe,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.terracotta.withOpacity(0.95),
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _runScan,
                    style: TextButton.styleFrom(
                      backgroundColor: Color(0x1AFF2D55),
                      foregroundColor: AppTheme.terracotta,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: AppTheme.terracotta.withValues(alpha: 0.20)),
                      ),
                    ),
                    child: const Text(
                      'Scan Again',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                      foregroundColor: AppTheme.surfaceRaised,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Close Portal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double angle;
  final Color color;

  _RadarSweepPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.66, paint);
    canvas.drawCircle(center, radius * 0.33, paint);

    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), paint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [color.withOpacity(0.4), Colors.transparent],
        stops: const [0.0, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) => old.angle != angle || old.color != color;
}

// ─── Fan Pulse ───────────────────────────────────────────────────────────────

void showFanPulseSheet(BuildContext context, {VoidCallback? onRoomJoined}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => _FanPulseSheet(onRoomJoined: onRoomJoined),
  );
}

class _FanPulseSheet extends StatefulWidget {
  final VoidCallback? onRoomJoined;
  const _FanPulseSheet({super.key, this.onRoomJoined});

  @override
  State<_FanPulseSheet> createState() => _FanPulseSheetState();
}

class _FanPulseSheetState extends State<_FanPulseSheet> {
  final Map<int, bool> _joining = {};

  final List<Map<String, dynamic>> _rooms = [
    {
      'id': 1,
      'title': 'Dandadan Live Hub 👾',
      'desc': 'Membahas episode terbaru alien & yokai!',
      'online': 148,
      'color': AppTheme.terracotta,
      'avatarColors': [Colors.orange, Colors.blue, Colors.pink],
      'avatarInitials': ['H', 'K', 'S'],
      'messages': [
        '@hitaku: Dandadan eps 12 gokil parah animasinya! 👾',
        '@okaru: aliennya makin aneh-aneh aja wkwk',
        '@momo: suka banget sama hubungan momo & okaru',
        '@seiko: nenek turbo emang the best! 🔥',
      ],
    },
    {
      'id': 2,
      'title': 'Solo Leveling Raid Chat ⚔️',
      'desc': 'Tempat kumpul para hunter tier-S.',
      'online': 96,
      'color': const Color(0xFF8B5CF6),
      'avatarColors': [Colors.blue, Colors.purple, Colors.teal],
      'avatarInitials': ['J', 'C', 'T'],
      'messages': [
        '@hunter_s: solo leveling raid kali ini seru abis! ⚔️',
        '@jinwoo: sung jin woo rise up!',
        '@cha_in: cha hae-in emang waifu idaman',
        '@thomas: hunter tier-S kumpul di sini',
      ],
    },
    {
      'id': 3,
      'title': 'Jujutsu High Lounge 👹',
      'desc': 'Diskusi teori kelanjutan Gojo & Sukuna.',
      'online': 74,
      'color': const Color(0xFF06B6D4),
      'avatarColors': [Colors.cyan, Colors.indigo, Colors.red],
      'avatarInitials': ['G', 'Y', 'M'],
      'messages': [
        '@gojo: ryomen sukuna vs gojo satoru! 👹',
        '@yuji: yuji & todo chemistry-nya dapet banget',
        '@megumi: kasihan megumi jiwanya kejebak',
        '@nobara: nobara kapan balik ya?',
      ],
    },
  ];

  void _joinRoom(int id, String title) {
    setState(() => _joining[id] = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _joining[id] = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppTheme.surfaceRaised, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Berhasil bergabung ke $title! Enjoy!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.surfaceRaised,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        HapticFeedback.mediumImpact();
        widget.onRoomJoined?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFFE8D5EA), width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Icon(Icons.groups_rounded, color: Color(0xFFEC4899), size: 22),
              SizedBox(width: 8),
              Text(
                'Fan Pulse Live Rooms',
                style: TextStyle(
                  color: Color(0xFF2C2420),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Connect and chat with other fans in real-time rooms.',
            style: TextStyle(
              color: Color(0xFF7D6D8B),
              fontSize: 12,
            ),
          ),
          SizedBox(height: 20),
          ..._rooms.map((room) {
            final isJoining = _joining[room['id']] ?? false;
            final Color accent = room['color'];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  _EqualizerBars(color: AppTheme.surfaceRaised),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: AppTheme.surfaceRaised,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                room['title'],
                                style: const TextStyle(
                                  color: Color(0xFF2C2420),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          room['desc'],
                          style: const TextStyle(
                            color: Color(0xFF7D6D8B),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ChatPreview(messages: room['messages'] as List<String>),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _AvatarStack(
                              colors: room['avatarColors'] as List<Color>,
                              initials: room['avatarInitials'] as List<String>,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${room['online']} online',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 38,
                    width: 76,
                    child: ElevatedButton(
                      onPressed: isJoining ? null : () => _joinRoom(room['id'], room['title']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: AppTheme.surfaceRaised,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isJoining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.surfaceRaised,
                              ),
                            )
                          : const Text(
                              'Join',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _EqualizerBars extends StatefulWidget {
  final Color color;
  const _EqualizerBars({required this.color});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
      builder: (context, child) {
        return SizedBox(
          width: 14,
          height: 10,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final progress = _controller.value;
              final heightMultiplier = (math.sin((progress * 2 * math.pi) + (index * 1.5)) + 1.0) / 2.0;
              final barHeight = 2.0 + 8.0 * heightMultiplier;
              return Container(
                width: 2.2,
                height: barHeight,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<Color> colors;
  final List<String> initials;

  const _AvatarStack({required this.colors, required this.initials});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 20,
      child: Stack(
        children: List.generate(colors.length, (index) {
          return Positioned(
            left: index * 12.0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors[index],
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surfaceRaised, width: 1.5),
              ),
              child: Center(
                child: Text(
                  initials[index],
                  style: const TextStyle(
                    color: AppTheme.surfaceRaised,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChatPreview extends StatefulWidget {
  final List<String> messages;
  const _ChatPreview({required this.messages});

  @override
  State<_ChatPreview> createState() => _ChatPreviewState();
}

class _ChatPreviewState extends State<_ChatPreview> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && widget.messages.isNotEmpty) {
        setState(() {
          _idx = (_idx + 1) % widget.messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) return const SizedBox.shrink();
    final msg = widget.messages[_idx];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey<int>(_idx),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          msg,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Drop Map ────────────────────────────────────────────────────────────────

void showDropMapSheet(
  BuildContext context, {
  bool moodRadarUsed = false,
  bool chatRoomJoined = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => _DropMapSheet(
      moodRadarUsed: moodRadarUsed,
      chatRoomJoined: chatRoomJoined,
    ),
  );
}

class _DropMapSheet extends StatefulWidget {
  final bool moodRadarUsed;
  final bool chatRoomJoined;
  const _DropMapSheet({
    this.moodRadarUsed = false,
    this.chatRoomJoined = false,
  });

  @override
  State<_DropMapSheet> createState() => _DropMapSheetState();
}

class _DropMapSheetState extends State<_DropMapSheet> {
  int _userGems = 12480;
  bool _claimedCheckIn = false;
  bool _claimedRadar = false;
  bool _claimedChat = false;
  bool _claimedGrand = false;
  bool _loading = true;

  final Map<int, bool> _claiming = {};

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userGems = prefs.getInt('aniverse_vault_gems') ?? 12480;
      _claimedCheckIn = prefs.getBool('aniverse_check_in_claimed') ?? false;
      _claimedRadar = prefs.getBool('aniverse_radar_claimed') ?? false;
      _claimedChat = prefs.getBool('aniverse_chat_claimed') ?? false;
      _claimedGrand = prefs.getBool('aniverse_grand_claimed') ?? false;
      _loading = false;
    });
  }

  Future<void> _claimMission(int id, int gemsReward, String title) async {
    setState(() => _claiming[id] = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    final prefs = await SharedPreferences.getInstance();

    int newGems = _userGems + gemsReward;
    await prefs.setInt('aniverse_vault_gems', newGems);

    String key = '';
    if (id == 1) {
      key = 'aniverse_check_in_claimed';
    } else if (id == 2) {
      key = 'aniverse_radar_claimed';
    } else if (id == 3) {
      key = 'aniverse_chat_claimed';
    }
    await prefs.setBool(key, true);

    if (!mounted) return;
    setState(() {
      _userGems = newGems;
      _claiming[id] = false;
      if (id == 1) _claimedCheckIn = true;
      if (id == 2) _claimedRadar = true;
      if (id == 3) _claimedChat = true;
    });

    HapticFeedback.mediumImpact();
    _showLootDialog(gemsReward, title);
  }

  Future<void> _claimGrandChest() async {
    setState(() => _claiming[99] = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    final prefs = await SharedPreferences.getInstance();

    int newGems = _userGems + 200;
    await prefs.setInt('aniverse_vault_gems', newGems);
    await prefs.setBool('aniverse_grand_claimed', true);

    if (!mounted) return;
    setState(() {
      _userGems = newGems;
      _claiming[99] = false;
      _claimedGrand = true;
    });

    HapticFeedback.heavyImpact();
    _showGrandLootDialog(200);
  }

  void _showLootDialog(int amount, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFFD700).withOpacity(0.12),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Color(0xFFFFD700).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.diamond_rounded,
                  color: Color(0xFFFFD700),
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Loot Claimed!',
                style: TextStyle(
                  color: AppTheme.surfaceRaised,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kamu mendapatkan +$amount Gems dari misi "$title"!',
                style: TextStyle(
                  color: AppTheme.surfaceRaised.withValues(alpha: 0.70),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Awesome',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGrandLootDialog(int amount) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Color(0xFFFFD700), width: 2),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFFD700).withOpacity(0.2),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFFFD700), Colors.transparent],
                    stops: [0.3, 1.0],
                  ),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppTheme.surfaceRaised,
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'GRAND CHEST OPENED!',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selamat! Kamu berhasil menyelesaikan semua misi hari ini dan mendapatkan Grand Loot:\n\n+$amount Gems 💎',
                style: TextStyle(
                  color: AppTheme.surfaceRaised.withValues(alpha: 0.70),
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'CLAIM & CLOSE',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 350,
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final claimedCount = (_claimedCheckIn ? 1 : 0) +
        (_claimedRadar ? 1 : 0) +
        (_claimedChat ? 1 : 0);

    final showGrandClaimable = claimedCount == 3 && !_claimedGrand;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Color(0xFFE8D5EA), width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.diamond_rounded, color: Color(0xFFF59E0B), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Universe Drop Map',
                    style: TextStyle(
                      color: Color(0xFF2C2420),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.surfaceRaised, Color(0xFF1F0D3D)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFFFD700).withOpacity(0.4), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.diamond_rounded, color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_userGems Gems',
                      style: const TextStyle(
                        color: AppTheme.surfaceRaised,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Lengkapi misi harian untuk mendapatkan loot premium.',
            style: TextStyle(
              color: Color(0xFF7D6D8B),
              fontSize: 12,
            ),
          ),
          SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFFD700).withOpacity(0.05),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Row(
              children: [
                _ShakingChest(
                  active: showGrandClaimable,
                  claimed: _claimedGrand,
                  loading: _claiming[99] ?? false,
                  onTap: _claimGrandChest,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _claimedGrand
                            ? 'GRAND LOOT CLAIMED!'
                            : showGrandClaimable
                                ? 'GRAND CHEST READY!'
                                : 'DAILY PROGRESS ($claimedCount/3)',
                        style: TextStyle(
                          color: _claimedGrand
                              ? Colors.white54
                              : showGrandClaimable
                                  ? const Color(0xFFFFD700)
                                  : AppTheme.surfaceRaised,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: claimedCount / 3.0,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            showGrandClaimable ? const Color(0xFFFFD700) : AppTheme.terracotta,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _claimedGrand
                            ? 'Kembali lagi besok untuk loot baru!'
                            : showGrandClaimable
                                ? 'Tap peti untuk mengambil 200 Gems!'
                                : 'Selesaikan semua misi untuk membuka peti.',
                        style: TextStyle(
                          color: AppTheme.surfaceRaised.withValues(alpha: 0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildMissionRow(
            id: 1,
            title: 'Daily Portal Check-In',
            rewardGems: 50,
            isCompleted: true,
            isClaimed: _claimedCheckIn,
            progressText: '1/1',
            icon: Icons.calendar_today_rounded,
          ),
          _buildMissionRow(
            id: 2,
            title: 'Scan the Mood Radar',
            rewardGems: 100,
            isCompleted: widget.moodRadarUsed,
            isClaimed: _claimedRadar,
            progressText: widget.moodRadarUsed ? '1/1' : '0/1',
            icon: Icons.radar_rounded,
          ),
          _buildMissionRow(
            id: 3,
            title: 'Join a Live Chat Room',
            rewardGems: 150,
            isCompleted: widget.chatRoomJoined,
            isClaimed: _claimedChat,
            progressText: widget.chatRoomJoined ? '1/1' : '0/1',
            icon: Icons.chat_bubble_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMissionRow({
    required int id,
    required String title,
    required int rewardGems,
    required bool isCompleted,
    required bool isClaimed,
    required String progressText,
    required IconData icon,
  }) {
    final bool isClaiming = _claiming[id] ?? false;
    final bool canClaim = isCompleted && !isClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isClaimed
              ? Colors.black12
              : canClaim
                  ? Color(0xFFF59E0B).withOpacity(0.24)
                  : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isClaimed
                  ? Colors.grey.withOpacity(0.08)
                  : Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isClaimed ? Colors.grey : const Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isClaimed ? Colors.grey : Color(0xFF2C2420),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    decoration: isClaimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reward: $rewardGems Gems',
                  style: TextStyle(
                    color: isClaimed ? Colors.grey : const Color(0xFF7D6D8B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isClaimed)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Claimed',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else if (canClaim)
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: isClaiming ? null : () => _claimMission(id, rewardGems, title),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: AppTheme.surfaceRaised,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isClaiming
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.surfaceRaised,
                        ),
                      )
                    : Text(
                        'Claim',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                progressText,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShakingChest extends StatefulWidget {
  final bool active;
  final bool claimed;
  final bool loading;
  final VoidCallback onTap;

  const _ShakingChest({
    required this.active,
    required this.claimed,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_ShakingChest> createState() => _ShakingChestState();
}

class _ShakingChestState extends State<_ShakingChest>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  Timer? _shakeTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _anim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    if (widget.active && !widget.claimed) {
      _startTimer();
    }
  }

  void _startTimer() {
    _shakeTimer?.cancel();
    if (AnimeApiService.isTestMode) {
      return;
    }
    _shakeTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!widget.active || widget.claimed) {
        timer.cancel();
        return;
      }
      _ctrl.forward(from: 0.0);
    });
  }

  @override
  void didUpdateWidget(_ShakingChest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !widget.claimed) {
      if (_shakeTimer == null || !_shakeTimer!.isActive) {
        _startTimer();
      }
    } else {
      _shakeTimer?.cancel();
      _shakeTimer = null;
    }
  }

  @override
  void dispose() {
    _shakeTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return SizedBox(
        width: 54,
        height: 54,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFD700),
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (widget.claimed) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.drafts_rounded,
          color: AppTheme.surfaceRaised.withValues(alpha: 0.30),
          size: 28,
        ),
      );
    }

    final Widget chestIcon = GestureDetector(
      onTap: widget.active ? widget.onTap : null,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: widget.active
              ? Color(0xFFFFD700).withOpacity(0.2)
              : AppTheme.surfaceRaised.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.active ? Color(0xFFFFD700) : Colors.transparent,
            width: widget.active ? 1.5 : 0,
          ),
          boxShadow: widget.active
              ? [
                  BoxShadow(
                    color: Color(0xFFFFD700).withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.card_giftcard_rounded,
          color: widget.active ? const Color(0xFFFFD700) : Colors.white24,
          size: 28,
        ),
      ),
    );

    if (widget.active) {
      return AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          return Transform.rotate(
            angle: _anim.value * math.pi / 180,
            child: child,
          );
        },
        child: chestIcon,
      );
    }

    return chestIcon;
  }
}

// ─── Gacha Sheet Content ─────────────────────────────────────────────────────

void showGachaSheet(BuildContext context, List<AnimeModel> animes) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _GachaSheetContent(animes: animes),
  );
}

class _GachaSheetContent extends StatefulWidget {
  final List<AnimeModel> animes;
  const _GachaSheetContent({required this.animes});

  @override
  State<_GachaSheetContent> createState() => _GachaSheetContentState();
}

class _GachaSheetContentState extends State<_GachaSheetContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  AnimeModel? _selectedAnime;
  bool _isSpinning = false;
  String _rarityText = '';
  Color _rarityColor = AppTheme.surfaceRaised;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _rollGacha() async {
    if (_isSpinning) return;
    
    if (AnimeApiService.isTestMode) {
      final finalAnime = widget.animes.isNotEmpty ? widget.animes.first : null;
      if (finalAnime != null) {
        setState(() {
          _selectedAnime = finalAnime;
          _isSpinning = false;
          _rarityText = 'EPIC';
          _rarityColor = const Color(0xFFA855F7);
        });
      }
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isSpinning = true;
      _selectedAnime = null;
    });

    final random = math.Random();
    for (int i = 0; i < 12; i++) {
      await Future.delayed(Duration(milliseconds: 50 + i * 20));
      if (!mounted) return;
      setState(() {
        _selectedAnime = widget.animes[random.nextInt(widget.animes.length)];
      });
      HapticFeedback.lightImpact();
    }

    final finalAnime = widget.animes[random.nextInt(widget.animes.length)];
    String rarity = 'COMMON';
    Color rarityColor = Colors.grey;

    if (finalAnime.rating >= 9.3) {
      rarity = 'LEGENDARY';
      rarityColor = const Color(0xFFFFD700);
    } else if (finalAnime.rating >= 8.8) {
      rarity = 'EPIC';
      rarityColor = const Color(0xFFA855F7);
    } else if (finalAnime.rating >= 8.2) {
      rarity = 'RARE';
      rarityColor = const Color(0xFF3B82F6);
    } else {
      rarity = 'COMMON';
      rarityColor = Colors.white70;
    }

    if (!mounted) return;
    setState(() {
      _selectedAnime = finalAnime;
      _isSpinning = false;
      _rarityText = rarity;
      _rarityColor = rarityColor;
    });

    _pulseController.forward(from: 0.0);
    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(
          color: AppTheme.terracotta.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.casino_rounded,
                color: AppTheme.terracotta,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Anime Gacha Roll',
                style: TextStyle(
                  color: AppTheme.surfaceRaised,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Spin the legendary wheel for a premium recommendations card!',
            style: TextStyle(color: AppTheme.surfaceRaised.withValues(alpha: 0.38), fontSize: 11),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _selectedAnime != null && !_isSpinning
                    ? _rarityColor.withOpacity(0.3)
                    : Color(0xFF2C1B4E),
                width: 1.5,
              ),
            ),
            child: Center(
              child: _selectedAnime == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          color: AppTheme.terracotta.withOpacity(0.3),
                          size: 64,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ready to Roll!',
                          style: TextStyle(
                            color: AppTheme.surfaceRaised.withValues(alpha: 0.70),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isSpinning) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _rarityColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _rarityColor.withOpacity(0.5),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _rarityColor.withOpacity(0.1),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _rarityText,
                                  style: TextStyle(
                                    color: _rarityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: 80,
                              height: 110,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: PosterImage(
                                  title: _selectedAnime!.title,
                                  fallbackUrl: _selectedAnime!.imageUrl,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedAnime!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.surfaceRaised,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (!_isSpinning) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedAnime!.rating.toString(),
                                    style: TextStyle(
                                      color: AppTheme.surfaceRaised.withValues(alpha: 0.70),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSpinning ? null : _rollGacha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    foregroundColor: AppTheme.surfaceRaised,
                    disabledBackgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: AppTheme.terracotta.withOpacity(0.5),
                    elevation: _isSpinning ? 0 : 8,
                  ),
                  child: Text(
                    _isSpinning ? 'SPINNING...' : 'ROLL GACHA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              if (_selectedAnime != null && !_isSpinning) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AnimeDetailScreen(anime: _selectedAnime!),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: AppTheme.surfaceRaised,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppTheme.surfaceRaised.withOpacity(0.12),
                        ),
                      ),
                    ),
                    child: const Text(
                      'VIEW INFO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class PosterImage extends StatelessWidget {
  final String title;
  final String fallbackUrl;

  const PosterImage({
    super.key,
    required this.title,
    required this.fallbackUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      fallbackUrl,
      fit: BoxFit.cover,
      cacheWidth: 160,
      cacheHeight: 220,
      errorBuilder: (_, __, ___) => Container(
        color: AppTheme.surfaceDark,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 24),
        ),
      ),
    );
  }
}

