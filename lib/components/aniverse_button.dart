import 'package:flutter/material.dart';
import '../theme/aniverse_theme.dart';

class AniVerseButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool secondary;

  const AniVerseButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = secondary ? AniVerseTheme.textPrimary : Colors.white;
    final background = secondary
        ? Colors.white.withValues(alpha: 0.12)
        : AniVerseTheme.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AniVerseTheme.radiusPill),
        boxShadow: secondary
            ? null
            : AniVerseTheme.glowShadow(AniVerseTheme.primary),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AniVerseTheme.radiusPill),
            side: secondary
                ? BorderSide(color: Colors.white.withValues(alpha: 0.14))
                : BorderSide.none,
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
