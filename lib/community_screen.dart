// community_screen.dart — AniVerse Community
// Ghibli-dark social feed: posts, clubs, trending, active users

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'theme/aniverse_theme.dart';
import 'room_screen.dart';


// ─── Palette (AniVerseTheme only, zero raw hex) ───────────────────────────────
const _kBg     = AniVerseTheme.background;
const _kSurface = AniVerseTheme.surface;
const _kCard   = AniVerseTheme.surface;
const _kBorder = AniVerseTheme.surfaceElevated;
const _kAccent = AniVerseTheme.accent;      // autumn orange — primary interactive
const _kHi     = AniVerseTheme.highlight;   // golden whisper — badges, highlights
const _kGlow   = AniVerseTheme.glow;        // ember warmth — depth / gradient pairs
// _kPrim was moss green (#A5B8A8) which competed with the warm orange/gold family.
// Remapped to _kGlow (ember) so gradient pairs like [_kAccent, _kPrim] now read
// as a single warm ramp (orange→ember) instead of orange→green.
const _kPrim   = AniVerseTheme.glow;        // ember warmth (was moss green)
const _kSucc   = AniVerseTheme.success;     // forest green — kept for actual success states
const _kTp     = AniVerseTheme.textPrimary;
const _kTs     = AniVerseTheme.textSecondary;

// ─── Mock data ────────────────────────────────────────────────────────────────
class _Post {
  final String userId, username, badge, rank, time, content;
  final String? tag, imageUrl;
  final int likes, comments, reposts;
  final List<String>? multiImages;
  final String? topComment, topCommentUser, topCommentBadge;
  final int? topCommentCount;
  final Color rankColor;
  final int level;

  const _Post({
    required this.userId,
    required this.username,
    required this.badge,
    required this.rank,
    required this.rankColor,
    required this.level,
    required this.time,
    required this.content,
    this.tag,
    this.imageUrl,
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
    this.multiImages,
    this.topComment,
    this.topCommentUser,
    this.topCommentBadge,
    this.topCommentCount,
  });
}

final _mockPosts = [
  const _Post(
    userId: 'hitaku7',
    username: 'HITAKU 🌸',
    badge: '✓',
    rank: 'Sakura Emperor',
    rankColor: AniVerseTheme.accent,
    level: 3000,
    time: '2 jam lalu',
    content:
        'Episode terbaru Solo Leveling gila banget! 🔥\nBerasa tiap minggu makin ga sabar nungguin 😩',
    tag: 'Solo Leveling',
    imageUrl:
        'https://cdn.myanimelist.net/images/anime/1887/117644l.jpg',
    likes: 2400,
    comments: 156,
    reposts: 89,
    topComment: 'Iyaaa ep ini ga main-main 🔥',
    topCommentUser: 'Shiroe',
    topCommentBadge: 'Mythic',
    topCommentCount: 156,
  ),
  const _Post(
    userId: 'aiko_chan',
    username: 'Aiko Chan',
    badge: '✓',
    rank: 'Legendary Collector',
    rankColor: AniVerseTheme.highlight,
    level: 2450,
    time: '5 jam lalu',
    content:
        'Siapa yang udah nonton movie terbaru Spy x Family?\nKecil banget Anya di movie ini wkwkwk 😂💕',
    tag: 'Spy x Family Code: White',
    multiImages: [
      'https://cdn.myanimelist.net/images/anime/1506/138982l.jpg',
      'https://cdn.myanimelist.net/images/anime/1506/138982l.jpg',
      'https://cdn.myanimelist.net/images/anime/1506/138982l.jpg',
    ],
    likes: 1800,
    comments: 98,
    reposts: 56,
    topComment: 'Anya selalu jadi mood booster 😊',
    topCommentUser: 'Ryuzen',
    topCommentBadge: 'Elite',
    topCommentCount: 98,
  ),
  const _Post(
    userId: 'kurumi_edit',
    username: 'Kurumi.',
    badge: '✓',
    rank: 'Top Contributor',
    rankColor: AniVerseTheme.success,
    level: 1820,
    time: '8 jam lalu',
    content:
        'Wallpaper Frieren yang aku edit dikit ✨\nSemoga kalian suka!',
    imageUrl:
        'https://cdn.myanimelist.net/images/anime/1015/138006l.jpg',
    likes: 945,
    comments: 44,
    reposts: 127,
    topComment: 'Masterpiece bestie 🙌',
    topCommentUser: 'Noel_v',
    topCommentBadge: 'Member',
    topCommentCount: 44,
  ),
];

final _clubs = [
  {'name': 'Java Anime Society', 'members': '18.2K', 'avatar': 'https://cdn.myanimelist.net/images/anime/1887/117644l.jpg'},
  {'name': 'One Piece Indonesia', 'members': '24.7K', 'avatar': 'https://cdn.myanimelist.net/images/anime/1244/138031l.jpg'},
  {'name': 'Wibu Santai', 'members': '15.6K', 'avatar': 'https://cdn.myanimelist.net/images/anime/1015/138006l.jpg'},
  {'name': 'Anime Quote ID', 'members': '12.3K', 'avatar': 'https://cdn.myanimelist.net/images/anime/1506/138982l.jpg'},
  {'name': 'Demon Slayer Corps', 'members': '20.1K', 'avatar': 'https://cdn.myanimelist.net/images/anime/1694/132347l.jpg'},
];

final _activeUsers = [
  {'name': 'Kirito_01', 'avatar': 'https://cdn.myanimelist.net/images/anime/1887/117644l.jpg'},
  {'name': 'Xyrenn', 'avatar': 'https://cdn.myanimelist.net/images/anime/1244/138031l.jpg'},
  {'name': 'Hana', 'avatar': 'https://cdn.myanimelist.net/images/anime/1015/138006l.jpg'},
  {'name': 'Zenn.', 'avatar': 'https://cdn.myanimelist.net/images/anime/1506/138982l.jpg'},
  {'name': 'Akame', 'avatar': 'https://cdn.myanimelist.net/images/anime/1694/132347l.jpg'},
];

final _trending = [
  {'title': 'Solo Leveling Ep 10', 'posts': '12.4K posts', 'up': true},
  {'title': 'Jujutsu Kaisen Season 2', 'posts': '8.7K posts', 'up': true},
  {'title': 'Demon Slayer Movie', 'posts': '7.1K posts', 'up': true},
  {'title': 'Kaiju No. 8', 'posts': '5.3K posts', 'up': true},
  {'title': 'Blue Lock Season 2', 'posts': '4.8K posts', 'up': false},
];

const _tabs = ['For You', 'Klan (Clan)', 'Following', 'Trending', 'Latest'];

// ─── Stories mock data ────────────────────────────────────────────────────────
final _stories = [
  (userId: 'you',       name: 'Kamu',        hasStory: false, isLive: false,  color: AniVerseTheme.accent,   initial: '+'),
  (userId: 'hitaku7',   name: 'HITAKU',      hasStory: true,  isLive: true,   color: AniVerseTheme.accent,   initial: 'H'),
  (userId: 'aiko_chan', name: 'Aiko',        hasStory: true,  isLive: false,  color: AniVerseTheme.highlight, initial: 'A'),
  (userId: 'ryuzen',    name: 'Ryuzen',      hasStory: true,  isLive: false,  color: AniVerseTheme.glow,     initial: 'R'),
  (userId: 'kurumi',    name: 'Kurumi.',     hasStory: true,  isLive: false,  color: AniVerseTheme.success,  initial: 'K'),
  (userId: 'xyrenn',    name: 'Xyrenn',      hasStory: true,  isLive: true,   color: AniVerseTheme.accent,   initial: 'X'),
  (userId: 'zenn',      name: 'Zenn.',       hasStory: true,  isLive: false,  color: AniVerseTheme.highlight, initial: 'Z'),
  (userId: 'hana',      name: 'Hana',        hasStory: false, isLive: false,  color: AniVerseTheme.glow,     initial: 'H'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _scrollCtrl = ScrollController();
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _scrollCtrl.addListener(() {
      final collapsed = _scrollCtrl.offset > 100;
      if (collapsed != _headerCollapsed) {
        setState(() => _headerCollapsed = collapsed);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            Positioned(top: -50, left: -60,
              child: _blob(_kHi.withValues(alpha: 0.09), 220)),
            Positioned(top: 60, right: -70,
              child: _blob(_kAccent.withValues(alpha: 0.08), 260)),
            NestedScrollView(
          controller: _scrollCtrl,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _SliverCommunityHeader(collapsed: innerBoxIsScrolled),
          ],
          body: Column(
            children: [
              _TabBar(controller: _tabCtrl),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _ForYouTab(),
                    const _ClanTab(),
                    _PlaceholderTab('Following'),
                    _PlaceholderTab('Trending'),
                    _PlaceholderTab('Latest'),
                  ],
                ),
              ),
            ],
          ),
        ),
          ],
        ),
        floatingActionButton: _PostButton(),
      ),
    );
  }

  Widget _blob(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

// ─── Sliver header ────────────────────────────────────────────────────────────
class _SliverCommunityHeader extends StatelessWidget {
  final bool collapsed;
  const _SliverCommunityHeader({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        color: _kBg,
        padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: title + icons ────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RUANG KOMUNITAS',
                      style: TextStyle(fontFamily: 'MPLUSRounded1c',
                        color: _kHi,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Community',
                      style: TextStyle(fontFamily: 'ShipporiMinchoB1',
                        color: _kTp,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      'Explore. Share. Connect.',
                      style: TextStyle(
                        color: _kTs,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Search button
                _IconBtn(icon: Icons.search_rounded, onTap: () {}),
                const SizedBox(width: 8),
                // Notif button
                Stack(
                  children: [
                    _IconBtn(icon: Icons.notifications_outlined, onTap: () {}),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: _kAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '3',
                            style: TextStyle(
                            color: _kTp,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Event banner ─────────────────────────────────────────────
            _EventBanner(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _kTp,
          shape: BoxShape.circle,
          border: Border.all(
            color: _kBorder,
          ),
        ),
        child: Icon(icon, color: _kAccent, size: 20),
      ),
    );
  }
}

// ─── Event banner ─────────────────────────────────────────────────────────────
class _EventBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kGlow.withValues(alpha: 0.70),
            _kAccent.withValues(alpha: 0.55),
            _kHi.withValues(alpha: 0.30),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: _kHi.withValues(alpha: 0.40), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Larger, gold-tinted sakura petals
            ..._buildPetals(),
            // Decorative orb (right side)
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kHi.withValues(alpha: 0.28),
                      _kAccent.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: _kHi.withValues(alpha: 0.9), size: 32),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kHi.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kHi.withValues(alpha: 0.50)),
                    ),
                    child: Text('EVENT',
                        style: TextStyle(color: _kHi, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 110, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: _kHi, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'Sakura Spring Event',
                        style: TextStyle(
                          color: _kTp,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Post, comment, dan dapatkan reward eksklusif!',
                    style: TextStyle(
                      color: _kTp.withValues(alpha: 0.80),
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kTp.withValues(alpha: 0.15),
                        border: Border.all(color: _kTp.withValues(alpha: 0.40)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lihat Event',
                            style: TextStyle(color: _kTp, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: _kTp, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPetals() {
    final rng = math.Random(42);
    return List.generate(18, (i) {
      final x = rng.nextDouble() * 340;
      final y = rng.nextDouble() * 120;
      final size = 5.0 + rng.nextDouble() * 10;
      final opacity = 0.12 + rng.nextDouble() * 0.35;
      final isRound = i % 3 == 0;
      return Positioned(
        left: x,
        top: y,
        child: Transform.rotate(
          angle: rng.nextDouble() * math.pi,
          child: Container(
            width: isRound ? size : size * 1.6,
            height: size * 0.7,
            decoration: BoxDecoration(
              color: (i % 2 == 0 ? _kHi : _kTp).withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(isRound ? size : size * 0.4),
            ),
          ),
        ),
      );
    });
  }
}

// ─── Tab bar ──────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: Column(
        children: [
          TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: _kAccent,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelColor: _kAccent,
            unselectedLabelColor: _kTs,
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: _tabs.map((t) {
              final isFirst = t == 'For You';
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFirst)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(
                          Icons.home_rounded,
                          size: 14,
                          color: _kAccent.withValues(alpha: 0.8),
                        ),
                      ),
                    Text(t),
                  ],
                ),
              );
            }).toList(),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: _kBorder.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

// ─── For You tab ─────────────────────────────────────────────────────────────
class _ForYouTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Feed loops the mock posts to simulate an infinite, clean scroll —
    // sidebar widgets (Clubs / Active Users / Trending) were removed from
    // the middle of the feed per redesign vision #3. They now live only in
    // their dedicated tabs (Klan, Trending) and entry points.
    const feedLength = 30;
    return CustomScrollView(
      slivers: [
        // ── Stories bar ──────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _StoriesBar()),
        // ── Live rooms hub ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: const _AnimeRoomLiveHub(),
          ),
        ),
        // ── Feed posts — clean infinite scroll, thin separators only ─────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              if (i >= feedLength) {
                return const _FeedEndLoader();
              }
              final post = _mockPosts[i % _mockPosts.length];
              return Column(
                children: [
                  if (i > 0) const _PostSeparator(),
                  _PostCard(post: post),
                ],
              );
            },
            childCount: feedLength + 1,
          ),
        ),
      ],
    );
  }
}

// ─── Thin separator between feed posts (no header, no widget) ─────────────────
class _PostSeparator extends StatelessWidget {
  const _PostSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: _kBorder.withValues(alpha: 0.35),
    );
  }
}

// ─── Infinite-scroll loading footer ────────────────────────────────────────────
class _FeedEndLoader extends StatelessWidget {
  const _FeedEndLoader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(_kAccent.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 10),
            Text('Memuat post lainnya…',
                style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Stories bar ──────────────────────────────────────────────────────────────
class _StoriesBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: _stories.length,
        itemBuilder: (_, i) {
          final s = _stories[i];
          final isMe = s.userId == 'you';
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => HapticFeedback.lightImpact(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ring + avatar
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Story ring
                      if (s.hasStory)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: s.isLive
                                  ? [_kAccent, _kGlow, _kHi]
                                  : [s.color, s.color.withValues(alpha: 0.4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      // Avatar
                      Container(
                        width: s.hasStory ? 54 : 58,
                        height: s.hasStory ? 54 : 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isMe
                              ? _kSurface
                              : s.color.withValues(alpha: 0.18),
                          border: Border.all(
                            color: isMe ? _kAccent : _kBg,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            s.initial,
                            style: TextStyle(
                              color: isMe ? _kAccent : s.color,
                              fontSize: isMe ? 22 : 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      // LIVE badge
                      if (s.isLive)
                        Positioned(
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('LIVE',
                                style: TextStyle(
                                    color: _kTp,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      s.name,
                      style: TextStyle(
                        color: s.hasStory ? _kTp : _kTs,
                        fontSize: 10,
                        fontWeight: s.hasStory ? FontWeight.w700 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Feed section divider ─────────────────────────────────────────────────────
class _FeedDivider extends StatelessWidget {
  final String label;
  const _FeedDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(width: 3, height: 14,
              decoration: BoxDecoration(
                  color: _kAccent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: _kTp, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
          const Spacer(),
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBorder.withValues(alpha: 0.5), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Post card ────────────────────────────────────────────────────────────────
class _AnimeRoomLiveHub extends StatelessWidget {
  const _AnimeRoomLiveHub();

  @override
  Widget build(BuildContext context) {
    final rooms = [
      (title: 'Solo Leveling Watch Party', live: '4.291 live', icon: Icons.play_circle_rounded, color: _kAccent, bgPath: 'asset/images/room_bg_library.jpg'),
      (title: 'Frieren Soft Talk', live: '812 online', icon: Icons.local_florist_rounded, color: _kSucc, bgPath: 'asset/images/room_bg_garden.jpg'),
      (title: 'JJK Spoiler Room', live: '1.8K debat', icon: Icons.bolt_rounded, color: _kPrim, bgPath: ''),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kSurface, _kBorder, _kBg],
        ),
        border: Border.all(color: _kHi.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_kAccent, _kPrim]),
                  boxShadow: [
                    BoxShadow(color: _kAccent.withValues(alpha: 0.28), blurRadius: 18),
                  ],
                ),
                child: const Icon(Icons.groups_2_rounded, color: _kTp),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Anime Room Live',
                        style: TextStyle(
                            color: _kTp,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Nonton, ngobrol, flex kosmetik, dan farm XP bareng.',
                        style: TextStyle(
                            color: _kTs,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('+20% XP',
                    style: TextStyle(
                        color: _kAccent, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rooms.map((room) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kTp.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kHi.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: room.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(room.icon, color: room.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: _kTp,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(room.live,
                              style: TextStyle(
                                  color: _kTs,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RoomScreen(
                              roomTitle: room.title,
                              roomColor: room.color,
                              roomBgPath: room.bgPath.isEmpty ? null : room.bgPath,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _kAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Masuk',
                            style: TextStyle(
                                color: _kTp,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              )),
          Row(
            children: const [
              _RoomPerk(icon: Icons.diamond_rounded, label: 'Border Drop'),
              SizedBox(width: 8),
              _RoomPerk(icon: Icons.mic_rounded, label: 'Voice Chat'),
              SizedBox(width: 8),
              _RoomPerk(icon: Icons.emoji_events_rounded, label: 'Guild Rank'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomPerk extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoomPerk({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: _kBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kHi.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kAccent, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _kTp,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Post card ────────────────────────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final _Post post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  bool _bookmarked = false;
  late AnimationController _likeCtrl;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _likeScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    super.dispose();
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return n.toString();
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() => _liked = !_liked);
    _likeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final hasImage = p.imageUrl != null || p.multiImages != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
      decoration: BoxDecoration(
        color: _kCard.withValues(alpha: 0.98),
        border: Border(
          bottom: BorderSide(color: _kBorder.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => HapticFeedback.selectionClick(),
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [p.rankColor, p.rankColor.withValues(alpha: 0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(color: p.rankColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: CircleAvatar(
                        backgroundColor: _kSurface,
                        child: Text(p.username[0],
                            style: TextStyle(color: p.rankColor, fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(p.username,
                            style: TextStyle(color: _kTp, fontSize: 14, fontWeight: FontWeight.w800)),
                        if (p.badge.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 15, height: 15,
                            decoration: const BoxDecoration(color: _kHi, shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: _kTp, size: 9),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.rankColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: p.rankColor.withValues(alpha: 0.25)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.auto_awesome_rounded, color: p.rankColor, size: 9),
                            const SizedBox(width: 3),
                            Text(p.rank, style: TextStyle(color: p.rankColor, fontSize: 10, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        Text('Lv.${p.level}', style: TextStyle(color: _kTs, fontSize: 10)),
                        const SizedBox(width: 4),
                        Text('·', style: TextStyle(color: _kTs, fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(p.time, style: TextStyle(color: _kTs, fontSize: 10)),
                      ]),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => HapticFeedback.selectionClick(),
                  child: Icon(Icons.more_horiz_rounded, color: _kTs, size: 20),
                ),
              ],
            ),
          ),

          // ── Content text ──────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, hasImage ? 10 : 0),
            child: Text(p.content,
                style: TextStyle(color: _kTp, fontSize: 14, height: 1.55, fontWeight: FontWeight.w400)),
          ),

          // ── Tag chip (when no image) ───────────────────────────────────────
          if (p.tag != null && !hasImage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.22)),
                  ),
                  child: Text('# ${p.tag!}',
                      style: TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ),

          // ── Image full-width (double-tap to like) ─────────────────────────
          if (p.imageUrl != null && p.multiImages == null)
            GestureDetector(
              onDoubleTap: _toggleLike,
              child: Stack(children: [
                Image.network(
                  p.imageUrl!,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _ImagePlaceholder(height: 260),
                ),
                if (p.tag != null)
                  Positioned(
                    bottom: 10, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kBg.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kAccent.withValues(alpha: 0.35)),
                      ),
                      child: Text('# ${p.tag!}',
                          style: TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),

          // ── Multi-image grid ──────────────────────────────────────────────
          if (p.multiImages != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  children: p.multiImages!.asMap().entries.map((e) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: e.key == 0 ? 0 : 3),
                      child: Image.network(
                        e.value, height: 150, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ImagePlaceholder(height: 150),
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),

          // ── Action bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              // Like with bounce animation
              GestureDetector(
                onTap: _toggleLike,
                child: AnimatedBuilder(
                  animation: _likeScale,
                  builder: (_, __) => Transform.scale(
                    scale: _likeScale.value,
                    child: Row(children: [
                      Icon(
                        _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _liked ? Colors.redAccent : _kTs,
                        size: 22,
                      ),
                      const SizedBox(width: 5),
                      Text(_fmt(p.likes + (_liked ? 1 : 0)),
                          style: TextStyle(
                              color: _liked ? Colors.redAccent : _kTs,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Comment
              GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: Row(children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: _kTs, size: 20),
                  const SizedBox(width: 5),
                  Text(_fmt(p.comments),
                      style: TextStyle(color: _kTs, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 20),
              // Repost
              GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: Row(children: [
                  Icon(Icons.repeat_rounded, color: _kTs, size: 20),
                  const SizedBox(width: 5),
                  Text(_fmt(p.reposts),
                      style: TextStyle(color: _kTs, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
              const Spacer(),
              // Bookmark
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _bookmarked = !_bookmarked);
                },
                child: Icon(
                  _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _bookmarked ? _kHi : _kTs,
                  size: 22,
                ),
              ),
            ]),
          ),

          // ── Top comment preview ───────────────────────────────────────────
          if (p.topComment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: GestureDetector(
                onTap: () => HapticFeedback.selectionClick(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kAccent.withValues(alpha: 0.15),
                        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
                      ),
                      child: Center(
                        child: Text((p.topCommentUser ?? 'U')[0],
                            style: TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(p.topCommentUser ?? '',
                                style: TextStyle(color: _kTp, fontSize: 12, fontWeight: FontWeight.w700)),
                            if (p.topCommentBadge != null) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _kHi.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(p.topCommentBadge!,
                                    style: TextStyle(color: _kHi, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 2),
                          Text(p.topComment!,
                              style: TextStyle(color: _kTs, fontSize: 12, height: 1.4),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (p.topCommentCount != null)
                      Text('${_fmt(p.topCommentCount!)} balasan',
                          style: TextStyle(color: _kAccent, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}


class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double height;
  const _ImagePlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: _kSurface,
      child: Icon(Icons.image_outlined,
          color: _kTs, size: 32),
    );
  }
}

// ─── Sidebar widgets ──────────────────────────────────────────────────────────
class _SidebarCard extends StatelessWidget {
  final String title, actionLabel;
  final Widget child;

  const _SidebarCard({
    required this.title,
    required this.actionLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHi.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _kTp,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$actionLabel ›',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ClubRow extends StatefulWidget {
  final Map<String, String> club;
  const _ClubRow({required this.club});

  @override
  State<_ClubRow> createState() => _ClubRowState();
}

class _ClubRowState extends State<_ClubRow> {
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              club['avatar']!,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 38,
                height: 38,
                color: _kAccent.withValues(alpha: 0.15),
                child: Icon(Icons.groups_rounded, color: _kAccent, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club['name']!, style: TextStyle(color: _kTp, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${club['members']} members', style: TextStyle(color: _kTs, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _joined = !_joined),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: _joined
                    ? null
                    : LinearGradient(colors: [_kAccent, _kGlow]),
                color: _joined ? _kBorder.withValues(alpha: 0.60) : null,
                borderRadius: BorderRadius.circular(20),
                border: _joined
                    ? Border.all(color: _kTs.withValues(alpha: 0.30))
                    : null,
                boxShadow: _joined
                    ? []
                    : [BoxShadow(color: _kAccent.withValues(alpha: 0.30), blurRadius: 8)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_joined) ...[
                    Icon(Icons.check_rounded, color: _kTs, size: 12),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _joined ? 'Bergabung' : 'Join',
                    style: TextStyle(
                      color: _joined ? _kTs : _kTp,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveUserRow extends StatelessWidget {
  final Map<String, String> user;
  const _ActiveUserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kAccent.withValues(alpha: 0.18),
                child: Text(
                  user['name']![0],
                  style: TextStyle(
                    color: _kAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _kSucc,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: _kCard.withValues(alpha: 0.95), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name']!,
                  style: TextStyle(
                    color: _kTp,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    color: _kSucc.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kHi.withValues(alpha: 0.18)),
            ),
            child: Icon(Icons.add_rounded,
                color: _kTs, size: 16),
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;
  const _TrendRow({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final isHot = rank <= 3;
    final title = item['title'] as String;
    // Derive a matching post tag from the trending title (best-effort mapping).
    final tag = _mockPosts
        .map((p) => p.tag)
        .whereType<String>()
        .firstWhere((t) => title.toLowerCase().contains(t.toLowerCase()), orElse: () => title);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _TopicFeedScreen(tag: tag, postsLabel: item['posts'] as String),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isHot ? _kAccent : _kTs,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _kTp,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item['posts'] as String,
                    style: TextStyle(
                      color: _kTs,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              (item['up'] as bool)
                  ? Icons.north_east_rounded
                  : Icons.south_east_rounded,
              color: (item['up'] as bool) ? _kSucc : _kAccent,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Topic feed — filtered feed pushed when a trending topic is tapped ────────
class _TopicFeedScreen extends StatelessWidget {
  final String tag;
  final String? postsLabel;
  const _TopicFeedScreen({required this.tag, this.postsLabel});

  @override
  Widget build(BuildContext context) {
    final filtered = _mockPosts.where((p) => p.tag == tag).toList();

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: _kBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: _kTp, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('#$tag',
                    style: TextStyle(color: _kTp, fontSize: 15, fontWeight: FontWeight.w900)),
                if (postsLabel != null)
                  Text(postsLabel!, style: TextStyle(color: _kTs, fontSize: 11)),
              ],
            ),
          ),
          // ── Topic banner ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kAccent.withValues(alpha: 0.16), _kGlow.withValues(alpha: 0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.local_fire_department_rounded, color: _kAccent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${filtered.length} post ditemukan',
                            style: TextStyle(color: _kTp, fontSize: 13, fontWeight: FontWeight.w800)),
                        Text('Post terbaru dengan tag #$tag',
                            style: TextStyle(color: _kTs, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Filtered posts ──────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, color: _kTs.withValues(alpha: 0.5), size: 40),
                    const SizedBox(height: 12),
                    Text('Belum ada post untuk #$tag',
                        style: TextStyle(color: _kTs, fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  if (i >= filtered.length) return const SizedBox(height: 100);
                  return _PostCard(post: filtered[i]);
                },
                childCount: filtered.length + 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommunityRules extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const rules = [
      'Bersikap sopan dan saling menghargai',
      'No spoiler tanpa tag spoiler',
      'No SARA, politik, atau konten negatif',
      'Gunakan bahasa yang baik',
      'Laporkan konten yang melanggar',
    ];
    return Container(
      decoration: BoxDecoration(
        color: _kCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHi.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _kSucc.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kSucc.withValues(alpha: 0.30)),
                ),
                child: Icon(Icons.shield_rounded, color: _kSucc, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Aturan Komunitas',
                style: TextStyle(
                  color: _kTp,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: _kAccent.withValues(alpha: 0.7), size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(
                          color: _kTs,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          GestureDetector(
            child: Row(
              children: [
                Text(
                  'Baca selengkapnya',
                  style: TextStyle(
                    color: _kAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.arrow_forward_rounded, color: _kAccent, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FAB "Buat Post" ─────────────────────────────────────────────────────────
class _PostButton extends StatefulWidget {
  @override
  State<_PostButton> createState() => _PostButtonState();
}

class _PostButtonState extends State<_PostButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    HapticFeedback.mediumImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ComposeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTap: _onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kAccent, AniVerseTheme.glow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.50),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: _kGlow.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.edit_rounded, color: _kTp, size: 16),
                SizedBox(width: 7),
                Text(
                  'Buat Post',
                  style: TextStyle(
                      color: _kTp,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();
  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedTag;
  String? _selectedMood;
  bool _posting = false;
  bool _showImagePreview = false;

  static const _tags = ['Solo Leveling', 'Frieren', 'JJK', 'Spy x Family', 'Mushoku Tensei', 'Chainsaw Man', 'Dandadan', 'Blue Lock'];
  static const _moods = [('🔥', 'Hype'), ('😭', 'Baper'), ('🤯', 'Mindblown'), ('😂', 'Ngakak'), ('💕', 'Wholesome'), ('🤔', 'Theory')];

  static const _maxChars = 280;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
    // Auto-focus after sheet animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _charCount => _ctrl.text.length;
  bool get _canPost => _charCount > 0 && _charCount <= _maxChars;
  double get _charProgress => (_charCount / _maxChars).clamp(0.0, 1.0);
  Color get _charColor {
    if (_charProgress >= 1.0) return Colors.redAccent;
    if (_charProgress >= 0.8) return Colors.orange;
    return _kAccent;
  }

  void _submitPost() async {
    if (!_canPost) return;
    HapticFeedback.mediumImpact();
    setState(() => _posting = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _kAccent.withValues(alpha: 0.25), width: 1.5)),
        boxShadow: [
          BoxShadow(color: _kAccent.withValues(alpha: 0.10), blurRadius: 30, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle + top bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: _kTs.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                // Avatar
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_kAccent, _kGlow]),
                    boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.35), blurRadius: 10)],
                  ),
                  child: const Center(
                    child: Text('H', style: TextStyle(color: _kTp, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('HITAKU', style: TextStyle(color: _kTp, fontSize: 14, fontWeight: FontWeight.w800)),
                  Text('Sakura Emperor · Lv.3000',
                      style: TextStyle(color: _kTs, fontSize: 10)),
                ]),
                const Spacer(),
                // Char counter ring
                SizedBox(
                  width: 32, height: 32,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                      value: _charProgress,
                      backgroundColor: _kBorder.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation(_charColor),
                      strokeWidth: 2.5,
                    ),
                    if (_charCount > 0)
                      Text(
                        _maxChars - _charCount > 20 ? '' : '${_maxChars - _charCount}',
                        style: TextStyle(color: _charColor, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                  ]),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _kBorder.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: _kTs, size: 16),
                  ),
                ),
              ]),
            ]),
          ),

          // ── Mood selector ─────────────────────────────────────────────
          if (_selectedMood == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                Text('Mood:', style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moods.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final m = _moods[i];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedMood = m.$1);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kBorder.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _kTs.withValues(alpha: 0.15)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(m.$1, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(m.$2, style: TextStyle(color: _kTs, fontSize: 10, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ]),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: GestureDetector(
                onTap: () => setState(() => _selectedMood = null),
                child: Row(children: [
                  Text('Mood:', style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_selectedMood!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Icon(Icons.close_rounded, color: _kAccent, size: 12),
                    ]),
                  ),
                ]),
              ),
            ),

          // ── Text field ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              maxLines: 6,
              minLines: 3,
              style: TextStyle(color: _kTp, fontSize: 15, height: 1.55),
              decoration: InputDecoration(
                hintText: 'Ceritain anime terbaru yang bikin kamu baper...',
                hintStyle: TextStyle(color: _kTs.withValues(alpha: 0.50), fontSize: 14, height: 1.55),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // ── Image preview placeholder ─────────────────────────────────
          if (_showImagePreview)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Stack(children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: _kBorder.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.image_rounded, color: _kAccent, size: 32),
                      const SizedBox(height: 6),
                      Text('Tap untuk pilih gambar', style: TextStyle(color: _kTs, fontSize: 11)),
                    ]),
                  ),
                ),
                Positioned(top: 6, right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _showImagePreview = false),
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: _kSurface, shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, color: _kTs, size: 12),
                    ),
                  ),
                ),
              ]),
            ),

          // ── Tag chips ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [
              Text('# Tag:', style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _tags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final tag = _tags[i];
                      final sel = tag == _selectedTag;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTag = sel ? null : tag);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? _kAccent : _kBorder.withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? _kAccent : _kTs.withValues(alpha: 0.15),
                            ),
                            boxShadow: sel ? [BoxShadow(color: _kAccent.withValues(alpha: 0.3), blurRadius: 8)] : [],
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: sel ? _kTp : _kTs,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ]),
          ),

          // ── Bottom action bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(children: [
              // Image
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showImagePreview = !_showImagePreview);
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _showImagePreview ? _kAccent.withValues(alpha: 0.15) : _kBorder.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _showImagePreview ? _kAccent.withValues(alpha: 0.4) : Colors.transparent),
                  ),
                  child: Icon(Icons.image_outlined, color: _showImagePreview ? _kAccent : _kTs, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              // Poll placeholder
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kBorder.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, color: _kTs, size: 18),
              ),
              const SizedBox(width: 10),
              // Mention
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kBorder.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.alternate_email_rounded, color: _kTs, size: 18),
              ),
              const Spacer(),
              // Post button
              GestureDetector(
                onTap: _canPost && !_posting ? _submitPost : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: _canPost && !_posting
                        ? LinearGradient(colors: [_kAccent, _kGlow])
                        : LinearGradient(colors: [_kBorder, _kBorder]),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _canPost && !_posting
                        ? [BoxShadow(color: _kAccent.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: _posting
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: _kTp, strokeWidth: 2))
                      : Text('Posting',
                          style: TextStyle(
                            color: _canPost ? _kTp : _kTs,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          )),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Placeholder tabs ─────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab(this.label);

  @override
  Widget build(BuildContext context) {
    switch (label) {
      case 'Following': return _FollowingTab();
      case 'Trending':  return _TrendingTab();
      case 'Latest':    return _LatestTab();
      case 'Hashtag':   return _HashtagTab();
      default: return const SizedBox.shrink();
    }
  }
}

// ── Following ─────────────────────────────────────────────────────────────────
class _FollowingTab extends StatelessWidget {
  final _followingPosts = const [
    (user: 'Xyrenn', rank: 'Elite', time: '12 mnt lalu', content: 'Frieren ep terbaru bikin mewek lagi 😭 penulis emang gila sih narasinya', tag: 'Frieren', level: 1850, likes: 340, comments: 28),
    (user: 'Hana', rank: 'Sakura Emperor', time: '1 jam lalu', content: 'Solo Leveling season 2 konfirmasi! Sung Jin-Woo balik!!! 🔥🔥🔥', tag: 'Solo Leveling', level: 3100, likes: 890, comments: 67),
    (user: 'Zenn.', rank: 'Mythic', time: '3 jam lalu', content: 'Baru selesai marathon Mushoku Tensei dari awal. Rudy character development-nya salah satu terbaik yang pernah aku tonton.', tag: 'Mushoku Tensei', level: 2780, likes: 512, comments: 43),
    (user: 'Akame', rank: 'Legendary Collector', time: '5 jam lalu', content: 'OST Chainsaw Man masih hits sampai sekarang. KICKBACK forever 🎵', tag: 'Chainsaw Man', level: 2450, likes: 278, comments: 19),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── "Who to follow" strip ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kHi.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.people_alt_rounded, color: _kAccent, size: 16),
                  const SizedBox(width: 7),
                  Text('Siapa yang belum kamu follow?',
                      style: TextStyle(color: _kTp, fontSize: 13, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _activeUsers.length,
                    itemBuilder: (_, i) {
                      final u = _activeUsers[i];
                      final colors = [_kAccent, _kHi, _kGlow, AniVerseTheme.success, _kAccent];
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [colors[i], colors[i].withValues(alpha: 0.3)]),
                              boxShadow: [BoxShadow(color: colors[i].withValues(alpha: 0.3), blurRadius: 8)],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircleAvatar(
                                backgroundColor: _kSurface,
                                child: Text(u['name']![0], style: TextStyle(color: colors[i], fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(u['name']!, style: TextStyle(color: _kTp, fontSize: 10, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
                            ),
                            child: Text('Follow', style: TextStyle(color: _kAccent, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Feed from followed users ──────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i >= _followingPosts.length) return const SizedBox(height: 100);
              final p = _followingPosts[i];
              final colors = [_kAccent, _kHi, _kGlow, AniVerseTheme.success];
              return _SimplePostCard(
                username: p.user,
                rank: p.rank,
                time: p.time,
                content: p.content,
                tag: p.tag,
                level: p.level,
                rankColor: colors[i % colors.length],
                likes: p.likes,
                comments: p.comments,
              );
            },
            childCount: _followingPosts.length + 1,
          ),
        ),
      ],
    );
  }
}

// ── Trending ──────────────────────────────────────────────────────────────────
class _TrendingTab extends StatelessWidget {
  final _trendingTopics = const [
    (title: 'Solo Leveling Ep 10', posts: '12.4K', heat: 0.98, tag: 'Solo Leveling', emoji: '🔥'),
    (title: 'Jujutsu Kaisen S2', posts: '8.7K', heat: 0.82, tag: 'JJK', emoji: '⚡'),
    (title: 'Demon Slayer Movie', posts: '7.1K', heat: 0.74, tag: 'Kimetsu', emoji: '🗡️'),
    (title: 'Kaiju No. 8', posts: '5.3K', heat: 0.61, tag: 'Kaiju', emoji: '💥'),
    (title: 'Blue Lock Season 2', posts: '4.8K', heat: 0.55, tag: 'Blue Lock', emoji: '⚽'),
  ];

  final _trendingPosts = const [
    (user: 'HITAKU', rank: 'Sakura Emperor', time: '2 jam lalu', content: 'Episode terbaru Solo Leveling gila banget! 🔥 Berasa tiap minggu makin ga sabar nungguin 😤', tag: 'Solo Leveling', level: 3000, likes: 2400, comments: 156),
    (user: 'Aiko Chan', rank: 'Legendary Collector', time: '5 jam lalu', content: 'Siapa yang udah nonton movie terbaru Spy x Family? Kecil banget Anya di movie ini wkwkwk 😂💕', tag: 'Spy x Family', level: 2450, likes: 1800, comments: 98),
    (user: 'Ryuzen', rank: 'Elite', time: '8 jam lalu', content: 'Frieren itu bukan anime biasa. Dia ngajarin cara ngeliat waktu dan perpisahan dari perspektif yang berbeda banget.', tag: 'Frieren', level: 1920, likes: 1200, comments: 74),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Heat chart — trending topics visual ───────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_kAccent, _kGlow]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_fire_department_rounded, color: _kTp, size: 12),
                      const SizedBox(width: 4),
                      Text('TRENDING SEKARANG', style: TextStyle(color: _kTp, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text('Diperbarui 5 mnt lalu', style: TextStyle(color: _kTs, fontSize: 10)),
                ]),
                const SizedBox(height: 12),
                ..._trendingTopics.asMap().entries.map((e) {
                  final t = e.value;
                  final rank = e.key + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _TopicFeedScreen(
                              tag: t.tag,
                              postsLabel: '${t.posts} posts',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kBorder.withValues(alpha: 0.5)),
                        ),
                        child: Row(children: [
                          // Rank number
                          SizedBox(
                            width: 32,
                            child: Text('#$rank',
                                style: TextStyle(
                                    color: rank == 1 ? _kAccent : _kTs,
                                    fontSize: rank == 1 ? 20 : 16,
                                    fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 8),
                          // Info
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t.emoji}  ${t.title}',
                                  style: TextStyle(color: _kTp, fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              // Heat bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: t.heat,
                                  minHeight: 4,
                                  backgroundColor: _kBorder.withValues(alpha: 0.4),
                                  valueColor: AlwaysStoppedAnimation(
                                    rank == 1 ? _kAccent : _kGlow.withValues(alpha: 0.7)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('${t.posts} posts · # ${t.tag}',
                                  style: TextStyle(color: _kTs, fontSize: 10)),
                            ],
                          )),
                          Icon(Icons.trending_up_rounded,
                              color: rank <= 2 ? _kAccent : _kTs, size: 18),
                        ]),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        // ── Divider ───────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _FeedDivider(label: 'Post Terpopuler')),
        // ── Trending posts ────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i >= _trendingPosts.length) return const SizedBox(height: 100);
              final p = _trendingPosts[i];
              return _SimplePostCard(
                username: p.user,
                rank: p.rank,
                time: p.time,
                content: p.content,
                tag: p.tag,
                level: p.level,
                rankColor: [_kAccent, _kHi, _kGlow][i % 3],
                likes: p.likes,
                comments: p.comments,
                showTrendingBadge: true,
                trendingRank: i + 1,
              );
            },
            childCount: _trendingPosts.length + 1,
          ),
        ),
      ],
    );
  }
}

// ── Latest ────────────────────────────────────────────────────────────────────
class _LatestTab extends StatelessWidget {
  final _latestPosts = const [
    (user: 'Kirito_01', rank: 'Member', time: '2 mnt lalu', content: 'Baru mulai nonton Vinland Saga, udah ep 3, ini seriusan bagus banget ya plotnya', tag: 'Vinland Saga', level: 980, likes: 12, comments: 3),
    (user: 'Xyrenn', rank: 'Elite', time: '8 mnt lalu', content: 'Rekomendasi anime isekai terbaru dong yang bukan generic? Udah abis list aku 😭', tag: null, level: 1850, likes: 45, comments: 22),
    (user: 'Hana', rank: 'Sakura Emperor', time: '15 mnt lalu', content: 'Baru nonton opening Dandadan live action... ini real atau hoax? 🤔', tag: 'Dandadan', level: 3100, likes: 230, comments: 41),
    (user: 'Kurumi', rank: 'Mythic', time: '23 mnt lalu', content: 'Attack on Titan ending masih traumatizing sampai sekarang ngl 💀', tag: 'Attack on Titan', level: 2100, likes: 189, comments: 35),
    (user: 'Zenn.', rank: 'Mythic', time: '31 mnt lalu', content: 'JJK chapter baru drop, siap-siap mental breakdown lagi wkwk', tag: 'JJK', level: 2780, likes: 156, comments: 28),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Live pulse indicator ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: _kAccent, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.5), blurRadius: 6)]),
              ),
              const SizedBox(width: 7),
              Text('Live · Post terbaru dari komunitas',
                  style: TextStyle(color: _kTp, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.refresh_rounded, color: _kAccent, size: 16),
            ]),
          ),
        ),
        // ── Latest posts in chronological order ───────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i >= _latestPosts.length) return const SizedBox(height: 100);
              final p = _latestPosts[i];
              final colors = [_kAccent, _kGlow, _kHi, AniVerseTheme.success, _kAccent];
              return _SimplePostCard(
                username: p.user,
                rank: p.rank,
                time: p.time,
                content: p.content,
                tag: p.tag,
                level: p.level,
                rankColor: colors[i % colors.length],
                likes: p.likes,
                comments: p.comments,
                showTimestamp: true,
              );
            },
            childCount: _latestPosts.length + 1,
          ),
        ),
      ],
    );
  }
}

// ── Hashtag ───────────────────────────────────────────────────────────────────
class _HashtagTab extends StatefulWidget {
  @override
  State<_HashtagTab> createState() => _HashtagTabState();
}

class _HashtagTabState extends State<_HashtagTab> {
  String? _active;

  static const _hashtags = [
    ('#SoloLeveling', 12400),
    ('#Frieren', 9800),
    ('#JJK', 8700),
    ('#DemonSlayer', 7100),
    ('#SpyFamily', 5900),
    ('#Dandadan', 5300),
    ('#BlueLock', 4800),
    ('#ChainSawMan', 4200),
    ('#MushokoTensei', 3600),
    ('#AttackOnTitan', 3100),
  ];

  static const _hashtagPosts = [
    (user: 'HITAKU', content: 'Episode terbaru gila banget! Rating 10/10 🔥', time: '2j lalu', level: 3000),
    (user: 'Ryuzen', content: 'Arc terbaru lebih seru dari yang aku kira. Plotnya dense banget!', time: '4j lalu', level: 1920),
    (user: 'Aiko Chan', content: 'Fan art baru udah aku upload, gas check guys 🎨', time: '6j lalu', level: 2450),
  ];

  String _formatK(int n) => n >= 1000 ? '${(n/1000).toStringAsFixed(1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trending Hashtag', style: TextStyle(color: _kTp, fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hashtags.map((h) {
                    final sel = h.$1 == _active;
                    return GestureDetector(
                      onTap: () => setState(() => _active = sel ? null : h.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: sel ? LinearGradient(colors: [_kAccent, _kGlow]) : null,
                          color: sel ? null : _kBorder.withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? _kAccent : _kTs.withValues(alpha: 0.20)),
                          boxShadow: sel ? [BoxShadow(color: _kAccent.withValues(alpha: 0.30), blurRadius: 10)] : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(h.$1, style: TextStyle(color: sel ? _kTp : _kAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 5),
                            Text(_formatK(h.$2), style: TextStyle(color: sel ? _kTp.withValues(alpha: 0.70) : _kTs, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                if (_active != null) ...[
                  Text('Post dengan $_active', style: TextStyle(color: _kTs, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SimplePostCard(
                  username: _hashtagPosts[i % _hashtagPosts.length].user,
                  rank: 'Anggota',
                  time: _hashtagPosts[i % _hashtagPosts.length].time,
                  content: _hashtagPosts[i % _hashtagPosts.length].content,
                  tag: _active?.replaceAll('#', ''),
                  level: _hashtagPosts[i % _hashtagPosts.length].level,
                  rankColor: [_kAccent, _kHi, _kGlow][i % 3],
                ),
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared simple post card for sub-tabs ──────────────────────────────────────
class _SimplePostCard extends StatefulWidget {
  final String username, rank, time, content;
  final String? tag;
  final int level;
  final Color rankColor;
  final int likes;
  final int comments;
  final bool showTrendingBadge;
  final int trendingRank;
  final bool showTimestamp;

  const _SimplePostCard({
    required this.username,
    required this.rank,
    required this.time,
    required this.content,
    required this.tag,
    required this.level,
    required this.rankColor,
    this.likes = 0,
    this.comments = 0,
    this.showTrendingBadge = false,
    this.trendingRank = 0,
    this.showTimestamp = false,
  });

  @override
  State<_SimplePostCard> createState() => _SimplePostCardState();
}

class _SimplePostCardState extends State<_SimplePostCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  bool _bookmarked = false;
  late AnimationController _likeCtrl;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _likeScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    super.dispose();
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 1),
      decoration: BoxDecoration(
        color: _kCard.withValues(alpha: 0.97),
        border: Border(
          bottom: BorderSide(color: _kBorder.withValues(alpha: 0.35), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [widget.rankColor, widget.rankColor.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: widget.rankColor.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: _kSurface,
                  child: Text(widget.username[0],
                      style: TextStyle(color: widget.rankColor, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.username,
                    style: TextStyle(color: _kTp, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.rankColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.rank,
                        style: TextStyle(color: widget.rankColor, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 5),
                  Text('Lv.${widget.level}', style: TextStyle(color: _kTs, fontSize: 9)),
                  if (widget.showTimestamp) ...[
                    const SizedBox(width: 4),
                    Text('·', style: TextStyle(color: _kTs, fontSize: 11)),
                    const SizedBox(width: 4),
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 3),
                    Text(widget.time, style: TextStyle(color: _kAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ]),
            ),
            if (widget.showTrendingBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_kAccent, _kGlow]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('#${widget.trendingRank} 🔥',
                    style: TextStyle(color: _kTp, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            if (!widget.showTimestamp && !widget.showTrendingBadge)
              Text(widget.time, style: TextStyle(color: _kTs, fontSize: 10)),
            const SizedBox(width: 4),
            Icon(Icons.more_horiz_rounded, color: _kTs, size: 18),
          ]),

          const SizedBox(height: 10),

          // Content
          Text(widget.content, style: TextStyle(color: _kTp, fontSize: 13, height: 1.55)),

          // Tag
          if (widget.tag != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.22)),
                ),
                child: Text('# ${widget.tag!}',
                    style: TextStyle(color: _kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Action bar
          Row(children: [
            // Like
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _liked = !_liked);
                _likeCtrl.forward(from: 0);
              },
              child: AnimatedBuilder(
                animation: _likeScale,
                builder: (_, __) => Transform.scale(
                  scale: _likeScale.value,
                  child: Row(children: [
                    Icon(
                      _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _liked ? Colors.redAccent : _kTs, size: 19,
                    ),
                    const SizedBox(width: 4),
                    Text(_fmt(widget.likes + (_liked ? 1 : 0)),
                        style: TextStyle(
                            color: _liked ? Colors.redAccent : _kTs,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 18),
            // Comment
            GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: Row(children: [
                Icon(Icons.chat_bubble_outline_rounded, color: _kTs, size: 18),
                const SizedBox(width: 4),
                Text(_fmt(widget.comments),
                    style: TextStyle(color: _kTs, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 18),
            // Share
            GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: Icon(Icons.share_outlined, color: _kTs, size: 18),
            ),
            const Spacer(),
            // Bookmark
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _bookmarked = !_bookmarked);
              },
              child: Icon(
                _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _bookmarked ? _kHi : _kTs, size: 20,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ClanTab extends StatefulWidget {
  const _ClanTab();

  @override
  State<_ClanTab> createState() => _ClanTabState();
}

class _ClanTabState extends State<_ClanTab> {
  bool _claimedQuest = false;
  int _guildCoins = 1450;
  List<Map<String, dynamic>> _recommendedClans = [
    {
      'name': 'Straw Hat Fleet',
      'motto': 'Menjadi raja bajak laut bebas bersama!',
      'level': 15,
      'members': 29,
      'maxMembers': 30,
      'trophies': 24150,
      'emblemLogo': Icons.sailing_rounded,
      'emblemColor': const Color(0xFFFFB800),
      'status': 'Join',
    },
    {
      'name': 'Demon Slayer Corps',
      'motto': 'Basmi iblis sampai tetes darah terakhir ⚔️',
      'level': 10,
      'members': 25,
      'maxMembers': 30,
      'trophies': 15600,
      'emblemLogo': Icons.shield_rounded,
      'emblemColor': const Color(0xFFFF2D87),
      'status': 'Join',
    },
    {
      'name': 'Fairy Tail',
      'motto': 'Keluarga penyihir terkuat dan terhangat!',
      'level': 12,
      'members': 28,
      'maxMembers': 30,
      'trophies': 19800,
      'emblemLogo': Icons.auto_awesome_rounded,
      'emblemColor': const Color(0xFF9D4EDD),
      'status': 'Join',
    },
  ];

  void _claimQuestReward() {
    if (_claimedQuest) return;
    Feedback.forTap(context);
    setState(() {
      _claimedQuest = true;
      _guildCoins += 250;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AniVerseTheme.surfaceElevated.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AniVerseTheme.highlight.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AniVerseTheme.highlight.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QUEST BERHASIL DITUNTUT!',
                      style: TextStyle(color: AniVerseTheme.highlight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Mendapatkan +250 Guild Coins & +100 XP Klan!',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _joinClan(int index) {
    Feedback.forTap(context);
    final clan = _recommendedClans[index];
    if (clan['status'] != 'Join') return;

    setState(() {
      _recommendedClans[index] = {
        ...clan,
        'status': 'Pending',
        'members': clan['members'] + 1,
      };
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withOpacity(0.5), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_empty_rounded, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Permintaan bergabung ke ${clan['name']} telah dikirim!',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateClanDialog() {
    Feedback.forTap(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CreateClanSheet(),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _guildCoins -= 500;
          _recommendedClans.insert(0, {
            'name': result['name'],
            'motto': result['motto'],
            'level': 1,
            'members': 1,
            'maxMembers': 30,
            'trophies': 100,
            'emblemLogo': result['emblemLogo'],
            'emblemColor': result['emblemColor'],
            'status': 'Owner',
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildGuildCoinsBar(),
              const SizedBox(height: 14),
              _buildMyClanCard(),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cari & Gabung Klan',
                    style: TextStyle(color: _kTp, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  TextButton.icon(
                    onPressed: _showCreateClanDialog,
                    icon: const Icon(Icons.add_circle_outline_rounded, color: _kAccent, size: 16),
                    label: const Text('Buat Klan', style: TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...List.generate(_recommendedClans.length, (index) => _buildClanRow(index)),
              const SizedBox(height: 20),
              const Text(
                'Peringkat Klan Teratas',
                style: TextStyle(color: _kTp, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _buildRankingsCard(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildGuildCoinsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kHi.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GUILD COINS KAMU', style: TextStyle(color: _kTs, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(
                    '$_guildCoins GP',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              Feedback.forTap(context);
            },
            icon: const Icon(Icons.shopping_bag_outlined, size: 14, color: _kAccent),
            label: const Text('Toko Klan', style: TextStyle(color: _kTp, fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent.withOpacity(0.12),
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _kAccent.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMyClanCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            _kCard,
            _kBorder.withOpacity(0.8),
            const Color(0xFF13131F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _kHi.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF9D4EDD).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9D4EDD), width: 2),
                ),
                child: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF9D4EDD), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Shadow Garden', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                        SizedBox(width: 6),
                        Icon(Icons.verified_rounded, color: _kHi, size: 14),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text('"We operate in the shadows..."', style: TextStyle(color: _kTs, fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9D4EDD).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Lv. 12', style: TextStyle(color: Color(0xFFD8B4FE), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildClanStat('Anggota', '28 / 30', Icons.people_outline_rounded),
              _buildClanStat('Trophy Server', '18.290 🏆', Icons.emoji_events_outlined),
              _buildClanStat('Peringkat', '#4 Global', Icons.leaderboard_outlined),
            ],
          ),
          const SizedBox(height: 16),
          // ── XP progress — immersive glow bar ────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome_rounded, color: Color(0xFF9D4EDD), size: 12),
                        SizedBox(width: 4),
                        Text('EXP Klan', style: TextStyle(color: _kTs, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('9.200', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                        Text(' / 12.000 XP', style: TextStyle(color: _kTs, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 10,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 9200 / 12000),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF9D4EDD), Color(0xFFD8B4FE)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9D4EDD).withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: _kSucc, size: 11),
                    const SizedBox(width: 3),
                    Text('2.800 XP lagi ke Lv. 13', style: TextStyle(color: _kTs, fontSize: 9.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined, color: _kHi, size: 14),
              const SizedBox(width: 6),
              const Text('Misi Klan Aktif', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(_claimedQuest ? '1/1 Selesai' : '0/1 Selesai', style: const TextStyle(color: _kTs, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Misi Harian: Nonton bersama di Live Room 20 menit', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text('+100 XP klan', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('+250 GP', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _claimedQuest ? null : _claimQuestReward,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _claimedQuest ? Colors.grey.withOpacity(0.2) : _kHi,
                    foregroundColor: Colors.black,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    _claimedQuest ? 'Klaim' : 'Tuntut',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClanStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _kTs, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: _kTs, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildClanRow(int index) {
    final clan = _recommendedClans[index];
    final isPending = clan['status'] == 'Pending';
    final isOwner = clan['status'] == 'Owner';
    final emblemColor = clan['emblemColor'] as Color;
    final members = clan['members'] as int;
    final maxMembers = clan['maxMembers'] as int;
    final capacity = members / maxMembers;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOwner ? emblemColor.withOpacity(0.4) : _kHi.withOpacity(0.12),
        ),
        boxShadow: isOwner
            ? [BoxShadow(color: emblemColor.withOpacity(0.15), blurRadius: 14, spreadRadius: 1)]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Emblem with glow ring ──────────────────────────────────────
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [emblemColor, emblemColor.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: emblemColor.withOpacity(0.35), blurRadius: 10, spreadRadius: 0.5),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _kBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: emblemColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(clan['emblemLogo'] as IconData, color: emblemColor, size: 19),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clan['name'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Lv.${clan['level']}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(clan['motto'] as String, style: const TextStyle(color: _kTs, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // ── Member capacity bar ─────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.people_alt_rounded, color: _kTs.withOpacity(0.6), size: 10),
                    const SizedBox(width: 3),
                    Text('$members/$maxMembers', style: const TextStyle(color: _kTs, fontSize: 10)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: capacity,
                          minHeight: 4,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation(
                            capacity > 0.9 ? _kAccent : emblemColor.withOpacity(0.8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.emoji_events_rounded, color: Colors.amber.withOpacity(0.8), size: 10),
                    const SizedBox(width: 3),
                    Text('${clan['trophies']}', style: const TextStyle(color: _kTs, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _joinClan(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isPending || isOwner
                    ? null
                    : const LinearGradient(colors: [_kAccent, _kGlow]),
                color: isPending ? Colors.white.withOpacity(0.08) : (isOwner ? const Color(0xFF9D4EDD).withOpacity(0.2) : null),
                borderRadius: BorderRadius.circular(16),
                border: isPending
                    ? Border.all(color: Colors.white10)
                    : (isOwner ? Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.5)) : null),
              ),
              child: Text(
                isPending ? 'Pending' : (isOwner ? 'Owner' : 'Gabung'),
                style: TextStyle(
                  color: isPending ? _kTs : (isOwner ? const Color(0xFFD8B4FE) : Colors.white),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingsCard() {
    final rankingClans = [
      (rank: 1, name: 'Straw Hat Fleet', trophies: 24150, lvl: 15, emblemColor: const Color(0xFFFFB800), emblem: Icons.sailing_rounded),
      (rank: 2, name: 'Gotei 13 Soul', trophies: 21900, lvl: 14, emblemColor: Colors.blueAccent, emblem: Icons.shield_outlined),
      (rank: 3, name: 'Fairy Tail', trophies: 19800, lvl: 12, emblemColor: const Color(0xFF9D4EDD), emblem: Icons.auto_awesome_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _kCard.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kHi.withOpacity(0.12)),
      ),
      child: Column(
        children: rankingClans.map((rc) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: rc.rank == 1 ? const Color(0xFFFFB800).withOpacity(0.05) : null,
            border: rc.rank < 3 ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))) : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '#${rc.rank}',
                  style: TextStyle(
                    color: rc.rank == 1 ? const Color(0xFFFFB800) : (rc.rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32)),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: rc.emblemColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(rc.emblem, color: rc.emblemColor, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(rc.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Text('Lv.${rc.lvl}', style: TextStyle(color: _kTs, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 12),
                  const SizedBox(width: 4),
                  Text('${rc.trophies}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _CreateClanSheet extends StatefulWidget {
  const _CreateClanSheet();

  @override
  State<_CreateClanSheet> createState() => _CreateClanSheetState();
}

class _CreateClanSheetState extends State<_CreateClanSheet> {
  final _nameCtrl = TextEditingController();
  final _mottoCtrl = TextEditingController();

  Color _selectedColor = const Color(0xFFFFB800);
  IconData _selectedLogo = Icons.shield_rounded;

  final List<Color> _colors = [
    const Color(0xFFFFB800),
    const Color(0xFFFF2D87),
    const Color(0xFF9D4EDD),
    const Color(0xFF00E5FF),
    const Color(0xFF4CAF50),
  ];

  final List<IconData> _logos = [
    Icons.shield_rounded,
    Icons.sailing_rounded,
    Icons.auto_awesome_rounded,
    Icons.bolt_rounded,
    Icons.remove_red_eye_rounded,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mottoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _kHi.withOpacity(0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kTs.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_circle_outline_rounded, color: _kAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Buat Klan Baru', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded, color: _kTs, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Nama Klan', style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Masukkan nama klan yang keren...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Slogan / Motto Klan', style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _mottoCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Tulis slogan klan kamu...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Pilih Warna Emblem', style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: _colors.map((color) {
              final isSel = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
                    boxShadow: isSel ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)] : [],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Pilih Logo Emblem', style: TextStyle(color: _kTs, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: _logos.map((logo) {
              final isSel = logo == _selectedLogo;
              return GestureDetector(
                onTap: () => setState(() => _selectedLogo = logo),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSel ? _selectedColor.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: isSel ? Border.all(color: _selectedColor, width: 1.5) : Border.all(color: Colors.transparent),
                  ),
                  child: Icon(logo, color: isSel ? _selectedColor : Colors.white30, size: 18),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () {
              final name = _nameCtrl.text.trim();
              final motto = _mottoCtrl.text.trim();
              if (name.isEmpty || motto.isEmpty) return;

              Feedback.forTap(context);
              Navigator.pop(context, {
                'name': name,
                'motto': motto,
                'emblemColor': _selectedColor,
                'emblemLogo': _selectedLogo,
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_kAccent, _kGlow]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Center(
                child: Text(
                  'Buat Klan (Biaya: 500 GP)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
