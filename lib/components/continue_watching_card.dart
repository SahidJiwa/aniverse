import 'package:flutter/material.dart';
import '../anime_model.dart';
import '../continue_watching_model.dart';
import '../theme/aniverse_theme.dart';
import 'aniverse_button.dart';

class ContinueWatchingCard extends StatelessWidget {
  final ContinueWatchingModel item;
  final AnimeModel? anime;
  final VoidCallback onTap;

  const ContinueWatchingCard({
    super.key,
    required this.item,
    required this.anime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = item.watchProgress.clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    final title = item.animeTitle.isNotEmpty
        ? item.animeTitle
        : anime?.title ?? 'Unknown Anime';
    final thumbnail = item.thumbnailUrl.isNotEmpty
        ? item.thumbnailUrl
        : anime?.imageUrl ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 330,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AniVerseTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(AniVerseTheme.radiusXl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            ...AniVerseTheme.softShadow,
            ...AniVerseTheme.glowShadow(AniVerseTheme.primary, 0.14),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 124,
              height: double.infinity,
              child: thumbnail.isEmpty
                  ? const _ContinueFallback()
                  : Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _ContinueFallback(),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episode ${item.episodeNumber}',
                      style: const TextStyle(
                        color: AniVerseTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AniVerseTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.16,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AniVerseTheme.highlight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            color: AniVerseTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AniVerseButton(
                        label: 'Continue',
                        icon: Icons.play_arrow_rounded,
                        onPressed: onTap,
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
}

class _ContinueFallback extends StatelessWidget {
  const _ContinueFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AniVerseTheme.surface,
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 30),
      ),
    );
  }
}
