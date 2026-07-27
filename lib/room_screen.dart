// room_screen.dart — AniVerse Interactive Room & Live Chat
// AAA-grade Cosmic-Neon / Fantasy-Ghibli isometric layout with dynamic backgrounds,
// zone-based avatar movements, speech bubbles, and XP rewards.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'theme/aniverse_theme.dart';
import 'mock_data_service.dart';

class RoomZone {
  final String id;
  final String name;
  final String description;
  final double x; // Normalized X (0.0 - 1.0)
  final double y; // Normalized Y (0.0 - 1.0)
  final Color glowColor;
  final IconData icon;

  const RoomZone({
    required this.id,
    required this.name,
    required this.description,
    required this.x,
    required this.y,
    required this.glowColor,
    required this.icon,
  });
}

class RoomUser {
  final String id;
  final String name;
  final String avatarUrl;
  final String? borderId;
  final Color borderGradientStart;
  final Color borderGradientEnd;
  final bool isMuted;
  final bool isDeafened;
  final bool isTalking;
  final String currentZoneId;
  final String? activeMessage;

  const RoomUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.borderId,
    required this.borderGradientStart,
    required this.borderGradientEnd,
    this.isMuted = false,
    this.isDeafened = false,
    this.isTalking = false,
    required this.currentZoneId,
    this.activeMessage,
  });

  RoomUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? borderId,
    Color? borderGradientStart,
    Color? borderGradientEnd,
    bool? isMuted,
    bool? isDeafened,
    bool? isTalking,
    String? currentZoneId,
    String? activeMessage,
  }) {
    return RoomUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      borderId: borderId ?? this.borderId,
      borderGradientStart: borderGradientStart ?? this.borderGradientStart,
      borderGradientEnd: borderGradientEnd ?? this.borderGradientEnd,
      isMuted: isMuted ?? this.isMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      isTalking: isTalking ?? this.isTalking,
      currentZoneId: currentZoneId ?? this.currentZoneId,
      activeMessage: activeMessage ?? this.activeMessage,
    );
  }
}

class RoomChatMessage {
  final String id;
  final String senderName;
  final String senderAvatar;
  final String message;
  final DateTime timestamp;
  final bool isSystem;
  final Color? senderColor;

  const RoomChatMessage({
    required this.id,
    required this.senderName,
    required this.senderAvatar,
    required this.message,
    required this.timestamp,
    this.isSystem = false,
    this.senderColor,
  });
}

class FloatingReaction {
  final String emoji;
  final Offset startOffset;
  final double randomSeed;
  final double scale;
  final DateTime createdAt;

  const FloatingReaction({
    required this.emoji,
    required this.startOffset,
    required this.randomSeed,
    required this.scale,
    required this.createdAt,
  });
}

class AmbientParticle {
  final double x;      // normalized 0.0–1.0
  final double y;      // normalized 0.0–1.0
  final double speed;  // drift speed
  final double size;
  final double phase;  // sine phase offset for organic movement
  final Color color;

  const AmbientParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.phase,
    required this.color,
  });
}

class FloatingXPToast {
  final String text;
  final Offset position;
  final DateTime createdAt;

  const FloatingXPToast({
    required this.text,
    required this.position,
    required this.createdAt,
  });
}


class RoomScreen extends StatefulWidget {
  final String roomTitle;
  final Color roomColor;
  final String? roomBgPath;

  const RoomScreen({
    super.key,
    required this.roomTitle,
    required this.roomColor,
    this.roomBgPath,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _bobbingCtrl;
  late AnimationController _reactionTicker;
  final _scrollCtrl = ScrollController();
  final _chatInputCtrl = TextEditingController();
  final List<RoomChatMessage> _messages = [];
  final List<FloatingReaction> _reactions = [];
  final List<AmbientParticle> _ambientParticles = [];
  late AnimationController _ambientCtrl;
  final List<FloatingXPToast> _xpToasts = [];
  String? _typingBotName;


  bool _isMuted = false;
  bool _isDeafened = false;
  bool _isScreenSharing = false;

  late List<RoomZone> _zones;
  late List<RoomUser> _users;
  Timer? _botChatTimer;
  Timer? _botMoveTimer;

  // Selected zone details overlay
  RoomZone? _selectedZone;

  // Available reaction emojis
  static const _emojiList = ['❤️', '🔥', '👍', '😂', '🎉', '🌸', '✨', '😭'];

  // Bot chat libraries based on anime topics
  static const _botReplies = [
    'Solo Leveling episode 10 animation was top tier! 🔥',
    'Frieren makes me emotional every single time... 🍃',
    'Cyberpunk Edgerunners ost still hurts 😭',
    'I equipped my Sakura Emperor border today, it glows so nicely!',
    'Who is up for watching Demon Slayer later tonight?',
    'Should we do an OST watch party?',
    'Anya is literally the cutest character ever wkwkwk',
    'This room has a really cozy Ghibli vibe 🌸',
    'Is anyone going to level up their Premium Pass today?',
    'Just got some crystals from my daily mission!',
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _bobbingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _reactionTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _reactionTicker.addListener(() {
      _updateReactions();
      _updateXPToasts();
    });

    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Generate ambient particles depending on room type
    final rng = math.Random(42); // fixed seed for deterministic layout
    if (widget.roomBgPath != null && widget.roomBgPath!.contains('garden')) {
      // Fireflies — warm orange/yellow/green dots
      for (int i = 0; i < 28; i++) {
        _ambientParticles.add(AmbientParticle(
          x: rng.nextDouble(),
          y: rng.nextDouble() * 0.75,
          speed: 0.3 + rng.nextDouble() * 0.5,
          size: 2.0 + rng.nextDouble() * 2.5,
          phase: rng.nextDouble() * math.pi * 2,
          color: [const Color(0xFFFFD54F), const Color(0xFFA5D6A7), const Color(0xFFFFB300)]
              [rng.nextInt(3)],
        ));
      }
    } else if (widget.roomBgPath != null && widget.roomBgPath!.contains('library')) {
      // Crystal sparkles — blue/purple/pink motes
      for (int i = 0; i < 24; i++) {
        _ambientParticles.add(AmbientParticle(
          x: rng.nextDouble(),
          y: rng.nextDouble() * 0.80,
          speed: 0.2 + rng.nextDouble() * 0.35,
          size: 1.5 + rng.nextDouble() * 2.0,
          phase: rng.nextDouble() * math.pi * 2,
          color: [const Color(0xFF80DEEA), const Color(0xFFCE93D8), const Color(0xFF90CAF9)]
              [rng.nextInt(3)],
        ));
      }
    } else {
      // Neon motes for cyber room — cyan/pink/purple
      for (int i = 0; i < 20; i++) {
        _ambientParticles.add(AmbientParticle(
          x: rng.nextDouble(),
          y: rng.nextDouble() * 0.85,
          speed: 0.4 + rng.nextDouble() * 0.6,
          size: 1.5 + rng.nextDouble() * 2.0,
          phase: rng.nextDouble() * math.pi * 2,
          color: [const Color(0xFF00E5FF), const Color(0xFFFF2D87), const Color(0xFF9D4EDD)]
              [rng.nextInt(3)],
        ));
      }
    }

    // Initialize zones list based on background
    if (widget.roomBgPath != null && widget.roomBgPath!.contains('garden')) {
      _zones = const [
        RoomZone(
          id: 'campfire',
          name: 'Campfire Circle',
          description: 'Gather around the warm campfire',
          x: 0.50,
          y: 0.68,
          glowColor: Color(0xFFFF5722),
          icon: Icons.local_fire_department_rounded,
        ),
        RoomZone(
          id: 'ancient_tree',
          name: 'Ancient Tree Shade',
          description: 'Relax under the giant leaves',
          x: 0.48,
          y: 0.43,
          glowColor: Color(0xFF4CAF50),
          icon: Icons.eco_rounded,
        ),
        RoomZone(
          id: 'adventurer_hut',
          name: 'Adventurer Guild Hut',
          description: 'Order potions or craft gear',
          x: 0.16,
          y: 0.46,
          glowColor: Color(0xFF9C27B0),
          icon: Icons.home_rounded,
        ),
        RoomZone(
          id: 'gazebo',
          name: 'Flower Gazebo',
          description: 'Talk with a sunset lake view',
          x: 0.86,
          y: 0.50,
          glowColor: Color(0xFFE91E63),
          icon: Icons.deck_rounded,
        ),
        RoomZone(
          id: 'board',
          name: 'Quest Notice Board',
          description: 'Accept daily hunter quests',
          x: 0.88,
          y: 0.74,
          glowColor: Color(0xFF00BCD4),
          icon: Icons.assignment_rounded,
        ),
      ];
    } else if (widget.roomBgPath != null && widget.roomBgPath!.contains('library')) {
      _zones = const [
        RoomZone(
          id: 'sofa_pit',
          name: 'Central Sofa Pit',
          description: 'Discuss tactics in the circular lounge',
          x: 0.50,
          y: 0.63,
          glowColor: Color(0xFF9D4EDD),
          icon: Icons.weekend_rounded,
        ),
        RoomZone(
          id: 'alchemy_bench',
          name: 'Artifact Workbench',
          description: 'Inspect scrolls and ancient maps',
          x: 0.38,
          y: 0.38,
          glowColor: Color(0xFF00E5FF),
          icon: Icons.science_rounded,
        ),
        RoomZone(
          id: 'fountain',
          name: 'Crystal Fountain',
          description: 'Listen to the glowing mineral water',
          x: 0.84,
          y: 0.64,
          glowColor: Color(0xFFFF2D87),
          icon: Icons.opacity_rounded,
        ),
        RoomZone(
          id: 'study_nook',
          name: 'Guild Library',
          description: 'Read reports and check quest items',
          x: 0.15,
          y: 0.66,
          glowColor: Color(0xFFFFB800),
          icon: Icons.menu_book_rounded,
        ),
        RoomZone(
          id: 'balcony',
          name: 'Dungeon View Balcony',
          description: 'Look out at the starry twin moons',
          x: 0.15,
          y: 0.34,
          glowColor: Color(0xFF10B981),
          icon: Icons.wb_sunny_rounded,
        ),
      ];
    } else {
      _zones = const [
        RoomZone(
          id: 'sofa',
          name: 'Watch Party Couch',
          description: 'Relax and watch anime together',
          x: 0.50,
          y: 0.58,
          glowColor: Color(0xFFFF2D87),
          icon: Icons.tv_rounded,
        ),
        RoomZone(
          id: 'gaming',
          name: 'Battlestation Desks',
          description: 'High performance gaming & chat',
          x: 0.18,
          y: 0.42,
          glowColor: Color(0xFF00E5FF),
          icon: Icons.sports_esports_rounded,
        ),
        RoomZone(
          id: 'dj',
          name: 'Lo-Fi DJ Deck',
          description: 'Listening to anime soundtracks',
          x: 0.50,
          y: 0.28,
          glowColor: Color(0xFF9D4EDD),
          icon: Icons.music_note_rounded,
        ),
        RoomZone(
          id: 'tatami',
          name: 'Tatami Lounge',
          description: 'Cozy Ghibli tea table chat',
          x: 0.82,
          y: 0.46,
          glowColor: Color(0xFF10B981),
          icon: Icons.local_cafe_rounded,
        ),
        RoomZone(
          id: 'bar',
          name: 'Ramen & Snack Bar',
          description: 'Mock food and drink chat corner',
          x: 0.30,
          y: 0.76,
          glowColor: Color(0xFFFFB800),
          icon: Icons.restaurant_rounded,
        ),
      ];
    }

    String mapZoneId(String originalId) {
      if (widget.roomBgPath != null && widget.roomBgPath!.contains('garden')) {
        switch (originalId) {
          case 'sofa': return 'campfire';
          case 'dj': return 'ancient_tree';
          case 'gaming': return 'adventurer_hut';
          case 'tatami': return 'gazebo';
          case 'bar': return 'board';
        }
      } else if (widget.roomBgPath != null && widget.roomBgPath!.contains('library')) {
        switch (originalId) {
          case 'sofa': return 'sofa_pit';
          case 'dj': return 'alchemy_bench';
          case 'gaming': return 'study_nook';
          case 'tatami': return 'fountain';
          case 'bar': return 'balcony';
        }
      }
      return originalId;
    }

    // Set initial selected zone
    _selectedZone = _zones.first;

    // Initial users setup (Player + bots)
    _users = [
      RoomUser(
        id: 'player',
        name: 'HITAKU (Kamu)',
        avatarUrl: 'https://i.pravatar.cc/150?img=11',
        borderId: 'frame_sakura',
        borderGradientStart: const Color(0xFFFF2D87),
        borderGradientEnd: const Color(0xFFFFB800),
        currentZoneId: mapZoneId('sofa'),
      ),
      RoomUser(
        id: 'bot_shiroe',
        name: 'Shiroe 👓',
        avatarUrl: 'https://i.pravatar.cc/150?img=3',
        borderId: 'frame_neon',
        borderGradientStart: const Color(0xFF9D4EDD),
        borderGradientEnd: const Color(0xFF00E5FF),
        currentZoneId: mapZoneId('dj'),
      ),
      RoomUser(
        id: 'bot_aiko',
        name: 'Aiko Chan 🌸',
        avatarUrl: 'https://i.pravatar.cc/150?img=47',
        borderGradientStart: const Color(0xFFFF2D87),
        borderGradientEnd: const Color(0xFFFF6EB4),
        currentZoneId: mapZoneId('sofa'),
      ),
      RoomUser(
        id: 'bot_kurumi',
        name: 'Kurumi.',
        avatarUrl: 'https://i.pravatar.cc/150?img=44',
        borderGradientStart: const Color(0xFF10B981),
        borderGradientEnd: const Color(0xFFA5B8A8),
        currentZoneId: mapZoneId('tatami'),
      ),
      RoomUser(
        id: 'bot_miku',
        name: 'Hana-Miku',
        avatarUrl: 'https://i.pravatar.cc/150?img=49',
        borderGradientStart: const Color(0xFF00E5FF),
        borderGradientEnd: const Color(0xFF9D4EDD),
        currentZoneId: mapZoneId('gaming'),
      ),
      RoomUser(
        id: 'bot_ryuzen',
        name: 'Ryuzen 🐉',
        avatarUrl: 'https://i.pravatar.cc/150?img=8',
        borderGradientStart: const Color(0xFFFFB800),
        borderGradientEnd: const Color(0xFFFF2D87),
        currentZoneId: mapZoneId('bar'),
      ),
    ];

    // Seed initial message list
    _messages.addAll([
      RoomChatMessage(
        id: 'sys_1',
        senderName: 'SYSTEM',
        senderAvatar: '',
        message: 'Selamat datang di "${widget.roomTitle}". Ketuk area mana saja untuk memindahkan avatar Anda!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isSystem: true,
      ),
      RoomChatMessage(
        id: 'm_1',
        senderName: 'Aiko Chan 🌸',
        senderAvatar: 'https://i.pravatar.cc/150?img=47',
        message: 'Halo! Baru gabung ya?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        senderColor: const Color(0xFFFF2D87),
      ),
      RoomChatMessage(
        id: 'm_2',
        senderName: 'Shiroe 👓',
        senderAvatar: 'https://i.pravatar.cc/150?img=3',
        message: 'Lagi nyantai sambil ngobrol nih, adem bener.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        senderColor: const Color(0xFF9D4EDD),
      ),
    ]);

    // Start Bot Chat Simulation (dynamic live messages)
    _botChatTimer = Timer.periodic(const Duration(seconds: 14), (timer) {
      _simulateBotChat();
    });

    // Start Bot Movement Simulation (bots changing positions occasionally)
    _botMoveTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      _simulateBotMovement();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _bobbingCtrl.dispose();
    _reactionTicker.dispose();
    _ambientCtrl.dispose();
    _scrollCtrl.dispose();
    _chatInputCtrl.dispose();
    _botChatTimer?.cancel();
    _botMoveTimer?.cancel();
    super.dispose();
  }

  void _updateReactions() {
    if (_reactions.isEmpty) return;
    final now = DateTime.now();
    setState(() {
      _reactions.removeWhere((r) => now.difference(r.createdAt).inMilliseconds > 1500);
    });
  }

  void _simulateBotChat() {
    final activeBots = _users.where((u) => u.id != 'player').toList();
    if (activeBots.isEmpty) return;

    final randomBot = activeBots[math.Random().nextInt(activeBots.length)];
    final messageText = _botReplies[math.Random().nextInt(_botReplies.length)];

    setState(() {
      _typingBotName = randomBot.name;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _typingBotName = null;
        _users = _users.map((u) {
          if (u.id == randomBot.id) {
            return u.copyWith(isTalking: true, activeMessage: messageText);
          }
          return u;
        }).toList();

        _messages.add(RoomChatMessage(
          id: 'bot_m_${DateTime.now().millisecondsSinceEpoch}',
          senderName: randomBot.name,
          senderAvatar: randomBot.avatarUrl,
          message: messageText,
          timestamp: DateTime.now(),
          senderColor: randomBot.borderGradientStart,
        ));
      });

      _scrollToBottom();

      // Turn off talking state & speech bubble after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _users = _users.map((u) {
              if (u.id == randomBot.id) {
                return u.copyWith(isTalking: false, activeMessage: null);
              }
              return u;
            }).toList();
          });
        }
      });
    });
  }

  void _simulateBotMovement() {
    final activeBots = _users.where((u) => u.id != 'player').toList();
    if (activeBots.isEmpty) return;

    final randomBot = activeBots[math.Random().nextInt(activeBots.length)];
    final availableZones = _zones.where((z) => z.id != randomBot.currentZoneId).toList();
    if (availableZones.isEmpty) return;

    final nextZone = availableZones[math.Random().nextInt(availableZones.length)];

    setState(() {
      _users = _users.map((u) {
        if (u.id == randomBot.id) {
          return u.copyWith(currentZoneId: nextZone.id);
        }
        return u;
      }).toList();

      _messages.add(RoomChatMessage(
        id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'SYSTEM',
        senderAvatar: '',
        message: '${randomBot.name} berpindah ke ${nextZone.name}.',
        timestamp: DateTime.now(),
        isSystem: true,
      ));
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _movePlayerToZone(String zoneId) {
    Feedback.forTap(context);
    setState(() {
      _users = _users.map((u) {
        if (u.id == 'player') {
          return u.copyWith(currentZoneId: zoneId);
        }
        return u;
      }).toList();

      _selectedZone = _zones.firstWhere((z) => z.id == zoneId);
    });

    MockDataService.earnXP(5, reason: 'Pindah Area Room');
    
    // Trigger floating XP toast over avatar
    final screenWidth = MediaQuery.of(context).size.width;
    final px = _selectedZone!.x * screenWidth;
    final py = _selectedZone!.y * 330.0;
    _triggerXPToast('+5 XP', Offset(px, py - 40));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Anda masuk ke ${_selectedZone!.name}! +5 XP diperoleh.'),
        duration: const Duration(seconds: 2),
        backgroundColor: widget.roomColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _sendChatMessage() {
    final text = _chatInputCtrl.text.trim();
    if (text.isEmpty) return;

    Feedback.forTap(context);
    _chatInputCtrl.clear();

    final player = _users.firstWhere((u) => u.id == 'player');

    setState(() {
      _messages.add(RoomChatMessage(
        id: 'user_m_${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'HITAKU (Kamu)',
        senderAvatar: player.avatarUrl,
        message: text,
        timestamp: DateTime.now(),
        senderColor: player.borderGradientStart,
      ));

      _users = _users.map((u) {
        if (u.id == 'player') return u.copyWith(isTalking: true, activeMessage: text);
        return u;
      }).toList();
    });

    _scrollToBottom();

    MockDataService.earnXP(10, reason: 'Chat Komunitas');

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _users = _users.map((u) {
            if (u.id == 'player') return u.copyWith(isTalking: false, activeMessage: null);
            return u;
          }).toList();
        });
      }
    });
  }

  void _triggerReaction(String emoji) {
    Feedback.forTap(context);
    final player = _users.firstWhere((u) => u.id == 'player');
    final playerZone = _zones.firstWhere((z) => z.id == player.currentZoneId);

    final screenWidth = MediaQuery.of(context).size.width;
    final roomHeight = 330.0;

    final zoneX = playerZone.x * screenWidth;
    final zoneY = playerZone.y * roomHeight;

    final offset = Offset(zoneX - 10, zoneY - 45);

    setState(() {
      _reactions.add(FloatingReaction(
        emoji: emoji,
        startOffset: offset,
        randomSeed: math.Random().nextDouble(),
        scale: 0.8 + math.Random().nextDouble() * 0.4,
        createdAt: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AniVerseTheme.background,
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, safeTop + 10, 16, 10),
            decoration: BoxDecoration(
              color: AniVerseTheme.surface.withOpacity(0.85),
              border: Border(
                bottom: BorderSide(
                  color: AniVerseTheme.surfaceElevated.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.roomTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_users.length} Wibu di Room',
                            style: TextStyle(
                              color: AniVerseTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isScreenSharing)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.roomColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.roomColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.screen_share_rounded, color: widget.roomColor, size: 12),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE SCREEN',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Main Screen Split: Isometric/Fantasy Canvas (Top) & Live Chat (Bottom)
          Expanded(
            child: Column(
              children: [
                // ── Room Canvas ──
                Container(
                  height: 330,
                  width: double.infinity,
                  color: const Color(0xFF141919),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulseCtrl, _bobbingCtrl, _ambientCtrl]),
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Dynamic background image (if loaded) or deep space backdrop
                          if (widget.roomBgPath != null)
                            Positioned.fill(
                              child: Image.asset(
                                widget.roomBgPath!,
                                fit: BoxFit.cover,
                              ),
                            ),

                          // 1b. Cinematic dark vignette scrim over background for depth & readability
                          if (widget.roomBgPath != null)
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.30),
                                      Colors.black.withOpacity(0.08),
                                      Colors.black.withOpacity(0.08),
                                      Colors.black.withOpacity(0.55),
                                    ],
                                    stops: const [0.0, 0.25, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),

                          // 2. Custom Painter for overlays (volumetric spotlights, grid overlay, 3D structures)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _RoomIsometricPainter(
                                zones: _zones,
                                pulseVal: _pulseCtrl.value,
                                selectedZoneId: _selectedZone?.id,
                                hasBgImage: widget.roomBgPath != null,
                              ),
                            ),
                          ),

                          // 2b. Zone label pills rendered directly on canvas above each pedestal
                          ..._buildZoneLabels(),

                          // Holographic screen (only shown if not in organic Garden room)
                          if (widget.roomBgPath == null || !widget.roomBgPath!.contains('garden'))
                            _buildHologramScreen(),

                          // Tap targets for each room zone
                          ..._zones.map((zone) => _buildZoneTapTarget(zone)),

                          // Floating User Avatars & Speech Bubbles
                          ..._buildUserAvatarsAndBubbles(),

                          // Zone user count badges
                          ..._buildZoneUserCountBadges(),

                          // Ambient floating particles (fireflies/crystals/neon)
                          ..._buildAmbientParticles(),

                          // Floating Emoji Reaction particles
                          ..._buildFloatingReactions(),

                          // Floating XP Toasts (+5 XP badges)
                          ..._buildFloatingXPToasts(),
                        ],
                      );
                    },
                  ),
                ),

                // Control status and description bar
                _buildActiveZoneStatus(),

                // ── Live Chat Panel ──
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AniVerseTheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildControlBar(),

                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            itemCount: _messages.length,
                            itemBuilder: (context, idx) {
                              final m = _messages[idx];
                              return _buildChatMessageRow(m);
                            },
                          ),
                        ),

                        _buildTypingIndicatorOverlay(),
                        _buildEmojiReactionDrawer(),
                        _buildTextInputField(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Ambient floating particles — fireflies for garden, crystals for library, neon for cyber
  List<Widget> _buildAmbientParticles() {
    final screenWidth = MediaQuery.of(context).size.width;
    const roomHeight = 330.0;
    final t = _ambientCtrl.value; // 0.0 to 1.0 cycling

    return _ambientParticles.map((p) {
      // Organic sine-wave drift
      final driftX = math.sin(t * math.pi * 2 * p.speed + p.phase) * 18.0;
      final driftY = math.cos(t * math.pi * 2 * p.speed * 0.7 + p.phase) * 12.0;

      final px = (p.x * screenWidth) + driftX;
      final py = (p.y * roomHeight) + driftY;

      // Twinkle opacity
      final opacity = 0.35 + 0.55 * math.sin(t * math.pi * 2 * p.speed + p.phase).abs();

      return Positioned(
        left: px - p.size / 2,
        top: py - p.size / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: p.size,
              height: p.size,
              decoration: BoxDecoration(
                color: p.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.color.withOpacity(0.8),
                    blurRadius: p.size * 2.5,
                    spreadRadius: p.size * 0.5,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // Zone user count badge — shows how many users are in each zone
  List<Widget> _buildZoneUserCountBadges() {
    final screenWidth = MediaQuery.of(context).size.width;
    const roomHeight = 330.0;

    // Count users per zone
    final Map<String, int> zoneCount = {};
    for (final u in _users) {
      zoneCount[u.currentZoneId] = (zoneCount[u.currentZoneId] ?? 0) + 1;
    }

    final List<Widget> badges = [];
    for (final zone in _zones) {
      final count = zoneCount[zone.id] ?? 0;
      if (count == 0) continue;

      final cx = zone.x * screenWidth;
      final cy = zone.y * roomHeight;

      badges.add(
        Positioned(
          left: cx + 10,
          top: cy - 32,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: zone.glowColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: zone.glowColor.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 8),
                  const SizedBox(width: 2),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return badges;
  }

  // Zone name pill labels shown directly on the canvas above each pedestal
  List<Widget> _buildZoneLabels() {
    final screenWidth = MediaQuery.of(context).size.width;
    const roomHeight = 330.0;
    final List<Widget> widgets = [];

    for (final zone in _zones) {
      final cx = zone.x * screenWidth;
      final cy = zone.y * roomHeight;
      final isSelected = _selectedZone?.id == zone.id;

      widgets.add(
        Positioned(
          left: cx - 52,
          top: cy + 12,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? zone.glowColor.withOpacity(0.85)
                    : Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: zone.glowColor.withOpacity(isSelected ? 1.0 : 0.45),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: zone.glowColor.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    zone.icon,
                    color: isSelected ? Colors.white : zone.glowColor,
                    size: 9,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    zone.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildAvatarImage(String url, String name, Color fallbackColor, {double size = 44}) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        color: fallbackColor.withOpacity(0.15),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fallbackColor, fallbackColor.withOpacity(0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _triggerXPToast(String text, Offset position) {
    setState(() {
      _xpToasts.add(FloatingXPToast(
        text: text,
        position: position,
        createdAt: DateTime.now(),
      ));
    });
  }

  void _updateXPToasts() {
    if (_xpToasts.isEmpty) return;
    final now = DateTime.now();
    setState(() {
      _xpToasts.removeWhere((t) => now.difference(t.createdAt).inMilliseconds > 1200);
    });
  }

  List<Widget> _buildFloatingXPToasts() {
    final now = DateTime.now();
    return _xpToasts.map((toast) {
      final elapsed = now.difference(toast.createdAt).inMilliseconds;
      final progress = (elapsed / 1200.0).clamp(0.0, 1.0);

      // Drift upward and scale slightly
      final double dy = -50.0 * progress;
      final double scale = 0.8 + 0.4 * math.sin(progress * math.pi);
      final double opacity = 1.0 - progress;

      return Positioned(
        left: toast.position.dx - 30,
        top: toast.position.dy + dy,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.white, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      toast.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTypingIndicatorOverlay() {
    if (_typingBotName == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _buildTypingDotsAnimation(),
          const SizedBox(width: 8),
          Text(
            '$_typingBotName sedang mengetik...',
            style: TextStyle(
              color: AniVerseTheme.textSecondary.withOpacity(0.7),
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDotsAnimation() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final delay = index * 0.3;
        final val = math.sin((_bobbingCtrl.value * math.pi * 2) + delay).abs();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: widget.roomColor.withOpacity(0.3 + 0.7 * val),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  void _showUserProfilePopup(RoomUser user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (context) {
        final zoneIndex = _zones.indexWhere((z) => z.id == user.currentZoneId);
        final zoneName = zoneIndex != -1 ? _zones[zoneIndex].name : 'Area';
        final zoneColor = zoneIndex != -1 ? _zones[zoneIndex].glowColor : widget.roomColor;

        return Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161F20).withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: user.borderGradientStart.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: user.borderGradientStart.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [user.borderGradientStart, user.borderGradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: user.borderGradientStart.withOpacity(0.4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _buildAvatarImage(user.avatarUrl, user.name, user.borderGradientStart, size: 68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: user.borderGradientStart.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: user.borderGradientStart.withOpacity(0.4), width: 1),
                    ),
                    child: Text(
                      user.id == 'player' ? 'LEVEL 5 (Wibu Elite)' : 'BOT LEVEL 24',
                      style: TextStyle(
                        color: user.borderGradientStart,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_rounded, color: zoneColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Di Area: ',
                        style: TextStyle(color: AniVerseTheme.textSecondary, fontSize: 11),
                      ),
                      Text(
                        zoneName,
                        style: TextStyle(color: zoneColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendSystemGreet(user);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Sapa', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            MockDataService.earnXP(10, reason: 'Kirim Hadiah');
                            _triggerXPToast('+10 XP', Offset(MediaQuery.of(context).size.width / 2, 160));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: user.borderGradientStart,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Kirim XP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _sendSystemGreet(RoomUser user) {
    if (user.id == 'player') return;
    setState(() {
      _messages.add(RoomChatMessage(
        id: 'greet_${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'HITAKU (Kamu)',
        senderAvatar: _users.firstWhere((u) => u.id == 'player').avatarUrl,
        message: 'Halo ${user.name}! Salam kenal 👋',
        timestamp: DateTime.now(),
        senderColor: const Color(0xFFFF2D87),
      ));
    });
    _scrollToBottom();
  }

  List<Widget> _buildUserAvatarsAndBubbles() {
    final screenWidth = MediaQuery.of(context).size.width;
    final roomHeight = 330.0;
    final List<Widget> widgets = [];

    // Group users by zone to compute offset scatter
    final Map<String, List<RoomUser>> usersByZone = {};
    for (final u in _users) {
      usersByZone.putIfAbsent(u.currentZoneId, () => []).add(u);
    }

    usersByZone.forEach((zoneId, list) {
      // Safety check: if zone is not found in active list, default to first zone
      final zoneIndex = _zones.indexWhere((z) => z.id == zoneId);
      final zone = zoneIndex != -1 ? _zones[zoneIndex] : _zones.first;
      final cx = zone.x * screenWidth;
      final cy = zone.y * roomHeight;

      for (int i = 0; i < list.length; i++) {
        final user = list[i];

        double ox = 0;
        double oy = 0;
        if (list.length > 1) {
          final angle = (2 * math.pi / list.length) * i;
          const radius = 22.0;
          ox = math.cos(angle) * radius;
          oy = math.sin(angle) * radius;
        }

        final bobbingOffset = math.sin((_bobbingCtrl.value * math.pi * 2) + (i * 0.5)) * 4.0;

        widgets.add(
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
            left: cx + ox - 22,
            top: cy + oy - 22 + bobbingOffset,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildAvatarBubble(user),

                if (user.isTalking && user.activeMessage != null)
                  Positioned(
                    top: -55,
                    left: -58,
                    child: Container(
                      width: 160,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: user.borderGradientStart.withOpacity(0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: user.borderGradientStart.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              color: user.borderGradientStart,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.activeMessage!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.normal,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    });

    return widgets;
  }

  Widget _buildAvatarBubble(RoomUser user) {
    final bool isPlayer = user.id == 'player';

    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);
        _showUserProfilePopup(user);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (user.isTalking)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: user.borderGradientStart.withOpacity(0.6 * _pulseCtrl.value),
                    blurRadius: 10 * _pulseCtrl.value,
                    spreadRadius: 4 * _pulseCtrl.value,
                  ),
                ],
              ),
            ),

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [user.borderGradientStart, user.borderGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: _buildAvatarImage(user.avatarUrl, user.name, user.borderGradientStart, size: 39),
            ),
          ),

          if (user.isMuted || isPlayer && _isMuted)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 8),
              ),
            )
          else if (user.isDeafened || isPlayer && _isDeafened)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volume_off_rounded, color: Colors.white, size: 8),
              ),
            ),

          Positioned(
            top: -14,
            left: -18,
            right: -18,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPlayer ? 'Kamu' : user.name.split(' ').first,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHologramScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final px = 0.50 * screenWidth;
    final py = (widget.roomBgPath != null && widget.roomBgPath!.contains('library'))
        ? 0.42 * 330 // Place higher for Library
        : 0.38 * 330;

    return Positioned(
      left: px - 65,
      top: py - 40,
      child: IgnorePointer(
        child: Container(
          width: 130,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF0F171A).withOpacity(0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.roomColor.withOpacity(0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.roomColor.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Glowing grid pattern background
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScannerLinesPainter(pulseVal: _pulseCtrl.value, neonColor: widget.roomColor),
                  ),
                ),
                // Live equalizer bars
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: CustomPaint(
                      painter: _HologramVisualizerPainter(
                        pulseVal: _pulseCtrl.value,
                        accentColor: widget.roomColor,
                      ),
                    ),
                  ),
                ),
                // Top Overlay Status bar
                Positioned(
                  top: 4,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _pulseCtrl.value > 0.5 ? Colors.red : Colors.red.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 2.5),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'CH-${widget.roomTitle.split(' ').first.toUpperCase()}',
                        style: TextStyle(
                          color: widget.roomColor.withOpacity(0.8),
                          fontSize: 6.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Play overlay
                Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white.withOpacity(0.4),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneTapTarget(RoomZone zone) {
    final screenWidth = MediaQuery.of(context).size.width;
    final roomHeight = 330.0;
    final cx = zone.x * screenWidth;
    final cy = zone.y * roomHeight;

    return Positioned(
      left: cx - 25,
      top: cy - 25,
      child: GestureDetector(
        onTap: () => _movePlayerToZone(zone.id),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveZoneStatus() {
    final player = _users.firstWhere((u) => u.id == 'player');
    final activeZoneIndex = _zones.indexWhere((z) => z.id == player.currentZoneId);
    final activeZone = activeZoneIndex != -1 ? _zones[activeZoneIndex] : _zones.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161F1F),
        border: Border(
          bottom: BorderSide(
            color: AniVerseTheme.surfaceElevated.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activeZone.glowColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: activeZone.glowColor.withOpacity(0.4), width: 1),
            ),
            child: Icon(activeZone.icon, color: activeZone.glowColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Area Kamu:',
                      style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      activeZone.name,
                      style: TextStyle(color: activeZone.glowColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  activeZone.description,
                  style: TextStyle(color: AniVerseTheme.textSecondary, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildControlIconButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: _isMuted ? Colors.red : Colors.green,
            label: _isMuted ? 'Muted' : 'Mic Active',
            onTap: () {
              Feedback.forTap(context);
              setState(() => _isMuted = !_isMuted);
            },
          ),
          _buildControlIconButton(
            icon: _isDeafened ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: _isDeafened ? Colors.orange : Colors.blue,
            label: _isDeafened ? 'Deafened' : 'Sound On',
            onTap: () {
              Feedback.forTap(context);
              setState(() => _isDeafened = !_isDeafened);
            },
          ),
          _buildControlIconButton(
            icon: _isScreenSharing ? Icons.screen_share_rounded : Icons.stop_screen_share_rounded,
            color: _isScreenSharing ? Colors.pink : Colors.grey,
            label: _isScreenSharing ? 'Sharing' : 'Share Screen',
            onTap: () {
              Feedback.forTap(context);
              setState(() => _isScreenSharing = !_isScreenSharing);
            },
          ),
          GestureDetector(
            onTap: () {
              Feedback.forTap(context);
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.5), width: 1.2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Keluar',
                    style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlIconButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: AniVerseTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageRow(RoomChatMessage m) {
    if (m.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                m.message,
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: m.senderColor?.withOpacity(0.8) ?? Colors.white24, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: _buildAvatarImage(m.senderAvatar, m.senderName, m.senderColor ?? Colors.white70, size: 29),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m.senderName,
                      style: TextStyle(
                        color: m.senderColor ?? Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: AniVerseTheme.textSecondary.withOpacity(0.5),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Text(
                    m.message,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiReactionDrawer() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.black.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _emojiList.map((emoji) {
          return GestureDetector(
            onTap: () => _triggerReaction(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AniVerseTheme.surfaceElevated.withOpacity(0.2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                controller: _chatInputCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan obrolan...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendChatMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send_rounded, color: widget.roomColor, size: 20),
            onPressed: _sendChatMessage,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingReactions() {
    final List<Widget> widgets = [];
    final now = DateTime.now();

    for (final r in _reactions) {
      final elapsed = now.difference(r.createdAt).inMilliseconds;
      if (elapsed > 1600) continue;

      final t = elapsed / 1600.0;

      // Physics burst scatter simulation
      // Spread angle biased upwards (-pi/2 +/- spread)
      final biasedAngle = -math.pi / 2 + (r.randomSeed - 0.5) * (math.pi * 0.65);
      final speed = 90.0 + r.randomSeed * 100.0;
      final gravity = 70.0; // downward acceleration

      // Horizontal displacement
      final dx = math.cos(biasedAngle) * speed * t;
      // Vertical displacement (upward initial velocity + downward gravity accumulation)
      final dy = math.sin(biasedAngle) * speed * t + 0.5 * gravity * t * t * 80;

      final opacity = t < 0.65 ? 1.0 : (1.0 - (t - 0.65) / 0.35);

      widgets.add(
        Positioned(
          left: r.startOffset.dx + dx,
          top: r.startOffset.dy + dy,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: r.scale * (1.0 + t * 0.4),
              child: Text(
                r.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

class _RoomIsometricPainter extends CustomPainter {
  final List<RoomZone> zones;
  final double pulseVal;
  final String? selectedZoneId;
  final bool hasBgImage;

  const _RoomIsometricPainter({
    required this.zones,
    required this.pulseVal,
    this.selectedZoneId,
    required this.hasBgImage,
  });

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  void _drawIsoBox(
    Canvas canvas,
    Offset o,
    double sx,
    double sy,
    double sz,
    Color color,
    Offset vx,
    Offset vy,
    Offset vz,
  ) {
    final p1 = o + vx * sx;
    final p2 = o + vy * sy;
    final p3 = o + vx * sx + vy * sy;

    final oT = o + vz * sz;
    final p1T = p1 + vz * sz;
    final p2T = p2 + vz * sz;
    final p3T = p3 + vz * sz;

    final paintTop = Paint()..color = _lighten(color, 0.05);
    final paintLeft = Paint()..color = _darken(color, 0.12);
    final paintRight = Paint()..color = _darken(color, 0.25);

    final pathLeft = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p1T.dx, p1T.dy)
      ..lineTo(oT.dx, oT.dy)
      ..close();
    canvas.drawPath(pathLeft, paintLeft);

    final pathRight = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p2T.dx, p2T.dy)
      ..lineTo(oT.dx, oT.dy)
      ..close();
    canvas.drawPath(pathRight, paintRight);

    final pathTop = Path()
      ..moveTo(oT.dx, oT.dy)
      ..lineTo(p1T.dx, p1T.dy)
      ..lineTo(p3T.dx, p3T.dy)
      ..lineTo(p2T.dx, p2T.dy)
      ..close();
    canvas.drawPath(pathTop, paintTop);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawPath(pathLeft, linePaint);
    canvas.drawPath(pathRight, linePaint);
    canvas.drawPath(pathTop, linePaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Skip drawing procedural environment structure if we are overlaying on a beautiful background image
    if (!hasBgImage) {
      final bgPaint = Paint()..color = const Color(0xFF0F1515);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

      final topWallCorner = Offset(w / 2, h * 0.14);
      final leftWallCorner = Offset(w * 0.05, h * 0.44);
      final rightWallCorner = Offset(w * 0.95, h * 0.44);
      final bottomFloorCorner = Offset(w / 2, h * 0.88);

      final leftWallPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1E2828), Color(0xFF131A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w / 2, h));

      final rightWallPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF172020), Color(0xFF0F1414)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(w / 2, 0, w / 2, h));

      final leftWallPath = Path()
        ..moveTo(0, 0)
        ..lineTo(w / 2, 0)
        ..lineTo(w / 2, topWallCorner.dy)
        ..lineTo(leftWallCorner.dx, leftWallCorner.dy)
        ..lineTo(0, leftWallCorner.dy)
        ..close();
      canvas.drawPath(leftWallPath, leftWallPaint);

      final rightWallPath = Path()
        ..moveTo(w, 0)
        ..lineTo(w / 2, 0)
        ..lineTo(w / 2, topWallCorner.dy)
        ..lineTo(rightWallCorner.dx, rightWallCorner.dy)
        ..lineTo(w, rightWallCorner.dy)
        ..close();
      canvas.drawPath(rightWallPath, rightWallPaint);

      final floorPaint = Paint()..color = const Color(0xFF161E1E);
      final floorPath = Path()
        ..moveTo(topWallCorner.dx, topWallCorner.dy)
        ..lineTo(rightWallCorner.dx, rightWallCorner.dy)
        ..lineTo(bottomFloorCorner.dx, bottomFloorCorner.dy)
        ..lineTo(leftWallCorner.dx, leftWallCorner.dy)
        ..close();
      canvas.drawPath(floorPath, floorPaint);

      final neonBeamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF9D4EDD).withOpacity(0.65 + 0.15 * math.sin(pulseVal * math.pi));
      canvas.drawLine(Offset(0, 10), Offset(w / 2, topWallCorner.dy - 35), neonBeamPaint);
      canvas.drawLine(Offset(w / 2, topWallCorner.dy - 35), Offset(w, 10), neonBeamPaint);

      final dotLightPaint = Paint()..color = const Color(0xFF00E5FF).withOpacity(0.8);
      canvas.drawCircle(Offset(w / 2, topWallCorner.dy - 35), 4, dotLightPaint);

      final shelfColor = const Color(0xFF3E2723);
      final vx = Offset(-w * 0.45, h * 0.22);
      final vy = Offset(w * 0.45, h * 0.22);
      final vz = Offset(0, -h * 0.18);

      final shelf1Origin = Offset.lerp(leftWallCorner, topWallCorner, 0.3)! + const Offset(15, -45);
      _drawIsoBox(canvas, shelf1Origin, 0.04, 0.24, 0.02, shelfColor, vx, vy, vz);
      final plant1Origin = shelf1Origin + vy * 0.1 - vz * 0.02;
      _drawIsoBox(canvas, plant1Origin, 0.03, 0.03, 0.04, const Color(0xFF4CAF50), vx, vy, vz);

      final shelf2Origin = Offset.lerp(leftWallCorner, topWallCorner, 0.65)! + const Offset(15, -40);
      _drawIsoBox(canvas, shelf2Origin, 0.04, 0.20, 0.02, shelfColor, vx, vy, vz);
      final plant2Origin = shelf2Origin + vy * 0.08 - vz * 0.02;
      _drawIsoBox(canvas, plant2Origin, 0.03, 0.03, 0.05, const Color(0xFF81C784), vx, vy, vz);

      final swordRackOrigin = Offset.lerp(topWallCorner, rightWallCorner, 0.35)! + const Offset(-15, -35);
      _drawIsoBox(canvas, swordRackOrigin, 0.20, 0.03, 0.12, const Color(0xFF2C3E50), vx, vy, vz);
      final swordPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(
        swordRackOrigin + vz * 0.06 - vx * 0.08,
        swordRackOrigin + vz * 0.06 + vx * 0.08,
        swordPaint,
      );

      final nanoleafPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFF2D87).withOpacity(0.5 + 0.3 * pulseVal);
      final leaf1 = Path()
        ..moveTo(w * 0.14, h * 0.18)
        ..lineTo(w * 0.19, h * 0.15)
        ..lineTo(w * 0.21, h * 0.21)
        ..close();
      canvas.drawPath(leaf1, nanoleafPaint);

      final leaf2 = Path()
        ..moveTo(w * 0.21, h * 0.21)
        ..lineTo(w * 0.26, h * 0.18)
        ..lineTo(w * 0.24, h * 0.25)
        ..close();
      canvas.drawPath(leaf2, nanoleafPaint);

      final heartPaint = Paint()
        ..color = const Color(0xFFFF007F).withOpacity(0.6 + 0.25 * math.cos(pulseVal * math.pi))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final heartCenter = Offset.lerp(topWallCorner, rightWallCorner, 0.7)! + const Offset(-20, -50);
      final heartPath = Path()
        ..moveTo(heartCenter.dx, heartCenter.dy - 10)
        ..lineTo(heartCenter.dx - 10, heartCenter.dy - 20)
        ..lineTo(heartCenter.dx - 20, heartCenter.dy - 15)
        ..lineTo(heartCenter.dx, heartCenter.dy + 5)
        ..lineTo(heartCenter.dx + 20, heartCenter.dy - 15)
        ..lineTo(heartCenter.dx + 10, heartCenter.dy - 20)
        ..close();
      canvas.drawPath(heartPath, heartPaint);

      final floorGridPaint = Paint()
        ..color = Colors.white.withOpacity(0.035)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      const gridLines = 10;
      for (int i = 1; i < gridLines; i++) {
        final t = i / gridLines;
        canvas.drawLine(
          Offset.lerp(leftWallCorner, topWallCorner, t)!,
          Offset.lerp(bottomFloorCorner, rightWallCorner, t)!,
          floorGridPaint,
        );
        canvas.drawLine(
          Offset.lerp(topWallCorner, rightWallCorner, t)!,
          Offset.lerp(leftWallCorner, bottomFloorCorner, t)!,
          floorGridPaint,
        );
      }

      final sofaOrigin = Offset(w * 0.5 - 28, h * 0.65);
      _drawIsoBox(canvas, sofaOrigin, 0.16, 0.32, 0.04, const Color(0xFF2C3E50), vx, vy, vz);
      _drawIsoBox(canvas, sofaOrigin + vz * 0.04 + vx * 0.03 + vy * 0.02, 0.12, 0.28, 0.05, const Color(0xFF2980B9), vx, vy, vz);
      _drawIsoBox(canvas, sofaOrigin + vx * 0.13, 0.03, 0.32, 0.18, const Color(0xFF1F2C39), vx, vy, vz);
      _drawIsoBox(canvas, sofaOrigin, 0.16, 0.03, 0.10, const Color(0xFF1F2C39), vx, vy, vz);
      _drawIsoBox(canvas, sofaOrigin + vy * 0.29, 0.16, 0.03, 0.10, const Color(0xFF1F2C39), vx, vy, vz);

      final gamingDeskOrigin = Offset(w * 0.14, h * 0.44);
      _drawIsoBox(canvas, gamingDeskOrigin, 0.12, 0.22, 0.12, const Color(0xFF111111), vx, vy, vz);
      final pcTowerOrigin = gamingDeskOrigin + vy * 0.16 - vz * 0.12;
      _drawIsoBox(canvas, pcTowerOrigin, 0.04, 0.05, 0.09, const Color(0xFF00E5FF), vx, vy, vz);
      final monitorLeft = gamingDeskOrigin + vy * 0.02 - vz * 0.12 + vx * 0.02;
      _drawIsoBox(canvas, monitorLeft, 0.01, 0.12, 0.08, const Color(0xFF1F2D3D), vx, vy, vz);
      final monitorGlow = Paint()
        ..color = const Color(0xFF00E5FF).withOpacity(0.7)
        ..style = PaintingStyle.fill;
      final monitorScr = Path()
        ..moveTo(monitorLeft.dx - 1, monitorLeft.dy - 12)
        ..lineTo(monitorLeft.dx - 1 + vy.dx * 0.10, monitorLeft.dy - 12 + vy.dy * 0.10)
        ..lineTo(monitorLeft.dx - 1 + vy.dx * 0.10 + vz.dx * 0.07, monitorLeft.dy - 12 + vy.dy * 0.10 + vz.dy * 0.07)
        ..lineTo(monitorLeft.dx - 1 + vz.dx * 0.07, monitorLeft.dy - 12 + vz.dy * 0.07)
        ..close();
      canvas.drawPath(monitorScr, monitorGlow);

      final djBoothOrigin = Offset(w * 0.5 - 20, h * 0.31);
      _drawIsoBox(canvas, djBoothOrigin, 0.10, 0.20, 0.13, const Color(0xFF1C2833), vx, vy, vz);
      final spkLeftOrigin = Offset(w * 0.35, h * 0.32);
      _drawIsoBox(canvas, spkLeftOrigin, 0.05, 0.05, 0.22, const Color(0xFF17202A), vx, vy, vz);
      final wooferPaint = Paint()..color = const Color(0xFF9D4EDD).withOpacity(0.8);
      canvas.drawCircle(spkLeftOrigin + vz * 0.16 + vy * 0.025, 4, wooferPaint);
      canvas.drawCircle(spkLeftOrigin + vz * 0.06 + vy * 0.025, 6, wooferPaint);

      final spkRightOrigin = Offset(w * 0.60, h * 0.32);
      _drawIsoBox(canvas, spkRightOrigin, 0.05, 0.05, 0.22, const Color(0xFF17202A), vx, vy, vz);
      canvas.drawCircle(spkRightOrigin + vz * 0.16 + vy * 0.025, 4, wooferPaint);
      canvas.drawCircle(spkRightOrigin + vz * 0.06 + vy * 0.025, 6, wooferPaint);

      final tatamiOrigin = Offset(w * 0.76, h * 0.48);
      final tatamiBasePaint = Paint()
        ..color = const Color(0xFF2E7D32).withOpacity(0.5)
        ..style = PaintingStyle.fill;
      final tatamiPath = Path()
        ..moveTo(tatamiOrigin.dx, tatamiOrigin.dy)
        ..lineTo(tatamiOrigin.dx + vy.dx * 0.3, tatamiOrigin.dy + vy.dy * 0.3)
        ..lineTo(tatamiOrigin.dx + vy.dx * 0.3 + vx.dx * 0.22, tatamiOrigin.dy + vy.dy * 0.3 + vx.dy * 0.22)
        ..lineTo(tatamiOrigin.dx + vx.dx * 0.22, tatamiOrigin.dy + vx.dy * 0.22)
        ..close();
      canvas.drawPath(tatamiPath, tatamiBasePaint);
      _drawIsoBox(canvas, tatamiOrigin + vy * 0.1 + vx * 0.08, 0.08, 0.08, 0.05, const Color(0xFF5D4037), vx, vy, vz);

      final barOrigin = Offset(w * 0.22, h * 0.74);
      _drawIsoBox(canvas, barOrigin, 0.06, 0.24, 0.16, const Color(0xFF78281F), vx, vy, vz);
      _drawIsoBox(canvas, barOrigin - vz * 0.16, 0.06, 0.24, 0.01, const Color(0xFFFFB800), vx, vy, vz);
    }

    // ── Spotlight cones & floor pedestals overlay on both Image and CustomPaint backdrops ──
    for (final zone in zones) {
      final cx = zone.x * w;
      final cy = zone.y * h;
      final isSelected = zone.id == selectedZoneId;
      final coneColor = zone.glowColor;

      // Draw Volumetric Spotlight Cone
      final spotlightCeiling = Offset(cx, h * 0.04);
      final beamPath = Path()
        ..moveTo(spotlightCeiling.dx, spotlightCeiling.dy)
        ..lineTo(cx - 28, cy + 5)
        ..lineTo(cx + 28, cy + 5)
        ..close();

      final beamGradient = LinearGradient(
        colors: [
          coneColor.withOpacity(isSelected ? 0.24 : 0.07),
          coneColor.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(cx - 28, spotlightCeiling.dy, cx + 28, cy + 5));

      canvas.drawPath(beamPath, Paint()..shader = beamGradient);

      // Floor Pedestal Indicator Ring
      final scaleFactor = isSelected ? (1.0 + pulseVal * 0.08) : 1.0;
      final padPaint = Paint()
        ..color = coneColor.withOpacity(isSelected ? 0.35 : 0.14)
        ..style = PaintingStyle.fill;
      final padStroke = Paint()
        ..color = coneColor.withOpacity(isSelected ? 0.9 : 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.2;

      final rx = 18.0 * scaleFactor;
      final ry = 9.0 * scaleFactor;

      final rect = Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry);
      canvas.drawOval(rect, padPaint);
      canvas.drawOval(rect, padStroke);

      if (isSelected) {
        // Draw 2 expanding concentric sonar ripples
        for (int ri = 1; ri <= 2; ri++) {
          final rippleFactor = (pulseVal + ri * 0.5) % 1.0;
          final rScale = scaleFactor + rippleFactor * 0.6;
          final ripplePaint = Paint()
            ..color = coneColor.withOpacity(0.55 * (1.0 - rippleFactor))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8 * (1.0 - rippleFactor);
          canvas.drawOval(
            Rect.fromLTRB(cx - 18.0 * rScale, cy - 9.0 * rScale, cx + 18.0 * rScale, cy + 9.0 * rScale),
            ripplePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RoomIsometricPainter old) =>
      old.pulseVal != pulseVal ||
      old.selectedZoneId != selectedZoneId ||
      old.hasBgImage != hasBgImage;
}

class _ScannerLinesPainter extends CustomPainter {
  final double pulseVal;
  final Color neonColor;

  const _ScannerLinesPainter({
    required this.pulseVal,
    required this.neonColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final scanY = pulseVal * h;
    final linePaint = Paint()
      ..color = neonColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(0, scanY), Offset(w, scanY), linePaint);

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [neonColor.withOpacity(0.25), Colors.transparent],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, scanY - 15, w, 15))
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, scanY - 15, w, 15), glowPaint);

    final gridPaint = Paint()
      ..color = neonColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final dotSpacing = 8.0;
    for (double x = 0; x < w; x += dotSpacing) {
      for (double y = 0; y < h; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), 0.5, gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ScannerLinesPainter old) => old.pulseVal != pulseVal;
}

class _HologramVisualizerPainter extends CustomPainter {
  final double pulseVal;
  final Color accentColor;

  _HologramVisualizerPainter({required this.pulseVal, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withOpacity(0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final barCount = 14;
    final spacing = size.width / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      // Calculate a pseudo-random animated height for each frequency bar
      final math.Random rand = math.Random(i * 31);
      final speedFactor = 0.5 + rand.nextDouble() * 1.5;
      final scaleFactor = 0.4 + rand.nextDouble() * 0.6;
      
      // Sine wave oscillation using pulseVal + speedFactor
      final heightFactor = (math.sin((pulseVal * math.pi * 2 * speedFactor) + i) + 1.0) / 2.0;
      final barHeight = (size.height - 16) * heightFactor * scaleFactor;
      
      final x = spacing * (i + 1);
      final yStart = size.height - 8;
      final yEnd = (yStart - barHeight).clamp(8.0, size.height - 8);

      // Draw glowing shadow
      canvas.drawLine(
        Offset(x, yStart),
        Offset(x, yEnd),
        Paint()
          ..color = accentColor.withOpacity(0.35)
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round,
      );

      // Draw main line
      canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HologramVisualizerPainter oldDelegate) =>
      oldDelegate.pulseVal != pulseVal || oldDelegate.accentColor != accentColor;
}
