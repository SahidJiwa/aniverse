import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../anime_api_service.dart';
import '../app_theme.dart';

class XpProgressBanner extends StatefulWidget {
  final bool moodRadarUsed;
  final bool chatRoomJoined;

  const XpProgressBanner({
    super.key,
    required this.moodRadarUsed,
    required this.chatRoomJoined,
  });

  @override
  State<XpProgressBanner> createState() => _XpProgressBannerState();
}

class _XpProgressBannerState extends State<XpProgressBanner>
    with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );

    if (!AnimeApiService.isTestMode) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int completedMissions =
        (widget.moodRadarUsed ? 1 : 0) + (widget.chatRoomJoined ? 1 : 0);
    const int totalMissions = 3; // checkin + radar + chat
    final double progress = (completedMissions + 0.1).clamp(0.0, 1.0) /
        totalMissions.toDouble();
    final String progressLabel = completedMissions == 0
        ? 'Complete daily missions to level up!'
        : completedMissions == 1
            ? '1/3 missions done — keep going!'
            : completedMissions == 2
                ? '2/3 missions done — almost there!'
                : 'All missions done! Claim your chest!';

    final isGold = completedMissions == totalMissions;

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF130624).withOpacity(0.96),
                Color(0xFF240E4C).withOpacity(0.96),
                Color(0xFF17082E).withOpacity(0.96),
              ],
            ),
            border: Border.all(
              color: isGold
                  ? Color(0xFFFFD700).withOpacity(0.35)
                  : AppTheme.terracotta.withOpacity(0.24),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isGold
                    ? Color(0xFFFFD700).withOpacity(0.12)
                    : AppTheme.sage.withOpacity(0.20),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isGold
                            ? [const Color(0xFFFFEA79), const Color(0xFFD4AF37)]
                            : [const Color(0xFFFF4D79), AppTheme.terracotta],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isGold ? Color(0xFFFFD700) : AppTheme.terracotta)
                              .withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isGold ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                      color: AppTheme.surfaceRaised,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isGold ? 'Daily Missions Complete!' : 'Explorer Rank Progress',
                          style: TextStyle(
                            color: AppTheme.surfaceRaised,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: (isGold ? Color(0xFFFFD700) : AppTheme.sage)
                                    .withOpacity(0.5),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          progressLabel,
                          style: TextStyle(
                            color: isGold ? Color(0xFFFFEA79).withOpacity(0.9) : Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.surfaceRaised.withValues(alpha: 0.10)),
                    ),
                    child: Text(
                      '$completedMissions/$totalMissions',
                      style: TextStyle(
                        color: isGold
                            ? const Color(0xFFFFD700)
                            : AppTheme.terracotta,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Container(
                      height: 10,
                      color: AppTheme.surfaceRaised.withOpacity(0.06),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: isGold
                                ? [Color(0xFFFFD700), const Color(0xFFFBBF24), const Color(0xFFFFEA79)]
                                : [AppTheme.terracotta, AppTheme.sage, AppTheme.terracotta.withValues(alpha: 0.35)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isGold ? Color(0xFFFFD700) : AppTheme.terracotta)
                                  .withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: _shimmerAnimation.value * constraints.maxWidth,
                                    width: constraints.maxWidth * 0.4,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.surfaceRaised.withOpacity(0.0),
                                            AppTheme.surfaceRaised.withOpacity(0.35),
                                            AppTheme.surfaceRaised.withOpacity(0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              // ── Daily reset countdown ──────────────────────────────────
              Builder(builder: (_) {
                final now = DateTime.now();
                final midnight = DateTime(now.year, now.month, now.day + 1);
                final diff = midnight.difference(now);
                final hh = diff.inHours.toString().padLeft(2, '0');
                final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
                final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: isGold ? Color(0xFFFFD700).withOpacity(0.4) : Colors.white24,
                      size: 11,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Resets in $hh:$mm:$ss',
                      style: TextStyle(
                        color: isGold ? Color(0xFFFFD700).withOpacity(0.4) : Colors.white24,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
