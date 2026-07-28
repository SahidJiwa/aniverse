import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'voice_actor_model.dart';
import 'widgets/liquid_glass.dart';

// ---------------------------------------------------------------------------
// VoiceActorsSection — bold redesign
// ---------------------------------------------------------------------------
// Drop this widget into AnimeDetailScreen between the Characters section
// and the Reviews section:
//
//   ...
//   CharactersSection(...),
//   VoiceActorsSection(
//     voiceActors: _voiceActors,
//     isLoading: _isLoadingVoiceActors,
//     error: _voiceActorsError,
//   ),
//   ReviewsSection(...),
//   ...
//
// Redesign notes: circular glowing avatar (matches the app's cinematic
// premium identity), a floating language ribbon instead of an inline pill,
// press-scale tap feedback, and a richer detail dialog with a soft glass
// backdrop instead of a flat card.
// ---------------------------------------------------------------------------

class VoiceActorsSection extends StatelessWidget {
  final List<VoiceActorModel> voiceActors;
  final bool isLoading;
  final String? error;

  const VoiceActorsSection({
    super.key,
    required this.voiceActors,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.accent, AppTheme.highlight],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Voice Actors',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (isLoading)
          _LoadingRow()
        else if (error != null)
          _ErrorMessage(message: error!)
        else if (voiceActors.isEmpty)
          _EmptyMessage()
        else
          SizedBox(
            height: 190,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: voiceActors.length,
              itemBuilder: (context, index) => _VoiceActorCard(
                voiceActor: voiceActors[index],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _VoiceActorCard — circular glowing avatar with floating language ribbon
// ---------------------------------------------------------------------------

class _VoiceActorCard extends StatefulWidget {
  final VoiceActorModel voiceActor;

  const _VoiceActorCard({required this.voiceActor});

  @override
  State<_VoiceActorCard> createState() => _VoiceActorCardState();
}

class _VoiceActorCardState extends State<_VoiceActorCard> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.94 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final va = widget.voiceActor;
    return GestureDetector(
      onTap: () => _showVoiceActorDialog(context, va),
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 108,
          margin: const EdgeInsets.only(right: 14),
          child: Column(
            children: [
              // ── Circular avatar with glow ring + language ribbon ──────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.accent.withOpacity(0.9),
                          AppTheme.highlight.withOpacity(0.7),
                        ],
                      ),
                      boxShadow: AppTheme.glowShadow(AppTheme.accent, 0.20),
                    ),
                    child: ClipOval(
                      child: _NetworkImageWithFallback(
                        url: va.imageUrl,
                        width: 87,
                        height: 87,
                      ),
                    ),
                  ),
                  // Language ribbon, floating bottom-center of the avatar.
                  // NOT migrated to LiquidGlassPill: at this size (9px
                  // text, tight padding) the pill's neutral-white tint
                  // reads as washed-out over a colorful avatar photo — the
                  // darker AppTheme.background fill + highlight-colored
                  // border here is a deliberate contrast choice, not an
                  // oversight.
                  Positioned(
                    bottom: -6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.background.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(
                                color: AppTheme.highlight.withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              va.language,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.highlight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Name ────────────────────────────────────────────────
              Text(
                va.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              // ── Character name ─────────────────────────────────────
              Text(
                'as ${va.characterName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _showVoiceActorDialog — glass-card detail dialog
// ---------------------------------------------------------------------------

void _showVoiceActorDialog(BuildContext context, VoiceActorModel va) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (context) => _VoiceActorDialog(voiceActor: va),
  );
}

class _VoiceActorDialog extends StatelessWidget {
  final VoiceActorModel voiceActor;

  const _VoiceActorDialog({required this.voiceActor});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.glowShadow(AppTheme.accent, 0.18),
        ),
        child: LiquidGlassPill(
          borderRadius: AppTheme.radiusXl,
          padding: EdgeInsets.zero,
          alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            // ── Actor avatar — circular, centered, glowing ─────────────
            Container(
              width: 108,
              height: 108,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.accent, AppTheme.highlight],
                ),
                boxShadow: AppTheme.glowShadow(AppTheme.accent, 0.25),
              ),
              child: ClipOval(
                child: _NetworkImageWithFallback(
                  url: voiceActor.imageUrl,
                  width: 102,
                  height: 102,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Details ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // Name
                  Text(
                    voiceActor.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ShipporiMinchoB1',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Language badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language_rounded,
                            size: 14, color: AppTheme.accent),
                        const SizedBox(width: 5),
                        Text(
                          voiceActor.language,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Divider(color: AppTheme.textSecondary.withOpacity(0.15)),
                  const SizedBox(height: 16),

                  // Character voiced section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CHARACTER VOICED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary.withOpacity(0.7),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Character thumbnail
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          boxShadow: AppTheme.glowShadow(AppTheme.highlight, 0.15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          child: _NetworkImageWithFallback(
                            url: voiceActor.characterImageUrl,
                            width: 56,
                            height: 56,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          voiceActor.characterName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.highlight,
                        backgroundColor: AppTheme.highlight.withOpacity(0.08),
                        side: BorderSide(
                          color: AppTheme.highlight.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
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
}

// ---------------------------------------------------------------------------
// States — shimmer loading row, error, empty
// ---------------------------------------------------------------------------

class _LoadingRow extends StatefulWidget {
  @override
  State<_LoadingRow> createState() => _LoadingRowState();
}

class _LoadingRowState extends State<_LoadingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          width: 108,
          margin: const EdgeInsets.only(right: 14),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      AppTheme.surfaceElevated,
                      AppTheme.surface,
                      _ctrl.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 10,
                width: 70,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;
  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        'No voice actor data available.',
        style: TextStyle(
          color: AppTheme.textSecondary.withOpacity(0.7),
          fontSize: 13,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NetworkImageWithFallback
// ---------------------------------------------------------------------------

class _NetworkImageWithFallback extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;

  const _NetworkImageWithFallback({
    required this.url,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _Placeholder(width: width, height: height);
    }
    // Clean URL
    final cleanUrl = url.trim();
    return Image.network(
      cleanUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _Placeholder(width: width, height: height),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.highlight,
            ),
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double? width;
  final double? height;

  const _Placeholder({this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E2638),
            const Color(0xFF111622),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.mic_external_on_rounded,
          color: AppTheme.highlight.withOpacity(0.7),
          size: (width != null && width! < 60) ? 22 : 36,
        ),
      ),
    );
  }
}
